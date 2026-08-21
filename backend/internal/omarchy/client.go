package omarchy

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/prettyletto/omagen/backend/internal/session"
)

type Client struct {
	stderr io.Writer
}

func NewClient(stderr io.Writer) *Client {
	return &Client{stderr: stderr}
}

func (c *Client) CurrentTheme() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(filepath.Join(home, ".local", "state", "omarchy", "current", "theme.name"))
	if err != nil {
		return "", err
	}
	theme := strings.TrimSpace(string(data))
	if theme == "" {
		return "", fmt.Errorf("theme.name is empty")
	}
	return theme, nil
}

func (c *Client) CurrentBackground() (session.BackgroundRef, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return session.BackgroundRef{}, err
	}
	currentRoot := filepath.Join(home, ".local", "state", "omarchy", "current")
	themeRoot := filepath.Join(currentRoot, "theme")
	backgroundLink := filepath.Join(currentRoot, "background")

	resolved, err := filepath.EvalSymlinks(backgroundLink)
	if err != nil {
		return session.BackgroundRef{}, err
	}
	resolved, err = filepath.Abs(resolved)
	if err != nil {
		return session.BackgroundRef{}, err
	}
	themeRoot, err = filepath.Abs(themeRoot)
	if err != nil {
		return session.BackgroundRef{}, err
	}

	relative, err := filepath.Rel(themeRoot, resolved)
	if err == nil && safeRelativePath(relative) {
		return session.BackgroundRef{Kind: "theme", Path: relative}, nil
	}
	return session.BackgroundRef{Kind: "external", Path: resolved}, nil
}

func (c *Client) RestoreThemeFast(theme, sessionDir string) error {
	_, _, err := c.runThemeSetUntilCritical(theme, filepath.Join(sessionDir, "theme-set.log"), []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=1",
	}, 10*time.Second)
	return err
}

func (c *Client) ApplyThemePreview(themeName, logPath string) (int, bool, error) {
	current, currentErr := c.CurrentTheme()
	if currentErr == nil && current == themeName {
		return 0, true, nil
	}

	reloadSync, err := newTerminalReloadSync(logPath)
	if err != nil {
		return 0, false, err
	}

	environment := []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=0",
	}
	environment = append(environment, reloadSync.environment()...)
	pid, _, err := c.runThemeSetUntilCritical(themeName, logPath, environment, 10*time.Second)
	if err != nil {
		_ = reloadSync.close()
		return pid, false, err
	}
	if err := reloadSync.persist(); err != nil {
		_ = reloadSync.close()
		return pid, false, err
	}
	return pid, false, nil
}

func (c *Client) ApplyTheme(themeName, logPath string) error {
	cacheWarmupSkip, err := newCacheWarmupSkip()
	if err != nil {
		return err
	}
	environment := []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=0",
	}
	environment = append(environment, cacheWarmupSkip.environment()...)
	_, _, err = c.runThemeSetToCompletionWithCleanup(themeName, logPath, environment, 30*time.Second, func() {
		_ = cacheWarmupSkip.close()
	})
	return err
}

func (c *Client) runThemeSetUntilCritical(theme, logPath string, environment []string, timeoutDuration time.Duration) (int, bool, error) {
	return c.runThemeSetUntilCriticalWithCleanup(theme, logPath, environment, timeoutDuration, nil)
}

func (c *Client) runThemeSetUntilCriticalWithCleanup(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func()) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, cleanup, false)
}

func (c *Client) runThemeSetToCompletionWithCleanup(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func()) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, cleanup, true)
}

func (c *Client) runThemeSet(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func(), waitForCompletion bool) (int, bool, error) {
	var cleanupOnce sync.Once
	waitTarget := "critical apply"
	if waitForCompletion {
		waitTarget = "theme-set completion"
	}
	clean := func() {
		if cleanup != nil {
			cleanupOnce.Do(cleanup)
		}
	}

	current, err := c.CurrentTheme()
	if err == nil && current == theme {
		clean()
		return 0, true, nil
	}

	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}
	lockFile, err := os.OpenFile(filepath.Join(runtimeDir, "omarchy-theme-set.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		clean()
		return 0, false, fmt.Errorf("open theme-set lock: %w", err)
	}
	defer lockFile.Close()

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		clean()
		return 0, false, fmt.Errorf("open theme-set log: %w", err)
	}

	cmd := exec.Command("omarchy", "theme", "set", theme)
	cmd.Env = replaceEnvironment(os.Environ(), environment...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		_ = logFile.Close()
		clean()
		return 0, false, fmt.Errorf("start omarchy theme set %q: %w", theme, err)
	}
	pid := cmd.Process.Pid
	_ = logFile.Close()

	waitCh := make(chan error, 1)
	go func() {
		err := cmd.Wait()
		clean()
		waitCh <- err
	}()
	ticker := time.NewTicker(25 * time.Millisecond)
	defer ticker.Stop()
	timeout := time.NewTimer(timeoutDuration)
	defer timeout.Stop()

	for {
		select {
		case err := <-waitCh:
			currentTheme, readErr := c.CurrentTheme()
			if err == nil && readErr == nil && currentTheme == theme && themeSetLockFree(lockFile) {
				return pid, false, nil
			}
			logData, _ := os.ReadFile(logPath)
			return pid, false, fmt.Errorf("theme set exited before critical apply completed: %v: %s", err, strings.TrimSpace(string(logData)))
		case <-ticker.C:
			if waitForCompletion {
				continue
			}
			currentTheme, err := c.CurrentTheme()
			if err != nil || currentTheme != theme || !themeSetLockFree(lockFile) {
				continue
			}
			return pid, false, nil
		case <-timeout.C:
			_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
			select {
			case <-waitCh:
			case <-time.After(2 * time.Second):
				_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
				<-waitCh
			}
			return pid, false, fmt.Errorf("timed out waiting for theme %q %s", theme, waitTarget)
		}
	}
}

func replaceEnvironment(base []string, replacements ...string) []string {
	values := make(map[string]string, len(base)+len(replacements))
	order := make([]string, 0, len(base)+len(replacements))
	put := func(entry string) {
		key, value, ok := strings.Cut(entry, "=")
		if !ok {
			return
		}
		if _, exists := values[key]; !exists {
			order = append(order, key)
		}
		values[key] = value
	}
	for _, entry := range base {
		put(entry)
	}
	for _, entry := range replacements {
		put(entry)
	}
	result := make([]string, 0, len(order))
	for _, key := range order {
		result = append(result, key+"="+values[key])
	}
	return result
}

func (c *Client) RestoreBackground(background session.BackgroundRef) error {
	path, err := c.resolveBackground(background)
	if err != nil {
		return err
	}
	cmd := exec.Command("omarchy", "theme", "bg", "set", path)
	cmd.Stdout = c.stderr
	cmd.Stderr = c.stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("omarchy theme bg set %q: %w", path, err)
	}
	// Theme restoration can put the current/background symlink back at the
	// same path that the preview used. The shell's normal background IPC
	// deliberately ignores an unchanged path, even when the symlink now
	// points at a different inode. Force a fresh image load so Cancel cannot
	// leave the preview bitmap cached on screen.
	if _, err := exec.LookPath("omarchy-shell"); err != nil {
		return nil
	}
	refresh := exec.Command("omarchy-shell", "-q", "background", "setInstant", path)
	refresh.Stdout = c.stderr
	refresh.Stderr = c.stderr
	if err := refresh.Run(); err != nil {
		return fmt.Errorf("refresh restored background %q: %w", path, err)
	}
	return nil
}

func (c *Client) resolveBackground(background session.BackgroundRef) (string, error) {
	switch background.Kind {
	case "theme":
		if !safeRelativePath(background.Path) {
			return "", fmt.Errorf("invalid theme background path")
		}
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		path := filepath.Join(home, ".local", "state", "omarchy", "current", "theme", background.Path)
		if _, err := os.Stat(path); err != nil {
			return "", fmt.Errorf("restored theme background does not exist: %w", err)
		}
		return path, nil
	case "external":
		if !filepath.IsAbs(background.Path) {
			return "", fmt.Errorf("external background path is not absolute")
		}
		if _, err := os.Stat(background.Path); err != nil {
			return "", fmt.Errorf("external background does not exist: %w", err)
		}
		return background.Path, nil
	default:
		return "", fmt.Errorf("unknown background kind: %q", background.Kind)
	}
}

func safeRelativePath(path string) bool {
	if path == "" || path == "." || filepath.IsAbs(path) {
		return false
	}
	clean := filepath.Clean(path)
	return clean != ".." && !strings.HasPrefix(clean, ".."+string(filepath.Separator))
}

func themeSetLockFree(lockFile *os.File) bool {
	if err := syscall.Flock(int(lockFile.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return false
	}
	_ = syscall.Flock(int(lockFile.Fd()), syscall.LOCK_UN)
	return true
}
