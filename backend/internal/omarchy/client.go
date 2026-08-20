package omarchy

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
	return c.runThemeSetUntilCritical(themeName, logPath, []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=0",
	}, 10*time.Second)
}

func (c *Client) runThemeSetUntilCritical(theme, logPath string, environment []string, timeoutDuration time.Duration) (int, bool, error) {
	current, err := c.CurrentTheme()
	if err == nil && current == theme {
		return 0, true, nil
	}

	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}
	lockFile, err := os.OpenFile(filepath.Join(runtimeDir, "omarchy-theme-set.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return 0, false, fmt.Errorf("open theme-set lock: %w", err)
	}
	defer lockFile.Close()

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return 0, false, fmt.Errorf("open theme-set log: %w", err)
	}

	cmd := exec.Command("omarchy", "theme", "set", theme)
	cmd.Env = replaceEnvironment(os.Environ(), environment...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		_ = logFile.Close()
		return 0, false, fmt.Errorf("start omarchy theme set %q: %w", theme, err)
	}
	pid := cmd.Process.Pid
	_ = logFile.Close()

	waitCh := make(chan error, 1)
	go func() { waitCh <- cmd.Wait() }()
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
			currentTheme, err := c.CurrentTheme()
			if err != nil || currentTheme != theme || !themeSetLockFree(lockFile) {
				continue
			}
			return pid, false, nil
		case <-timeout.C:
			_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
			return pid, false, fmt.Errorf("timed out waiting for theme %q critical apply", theme)
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
