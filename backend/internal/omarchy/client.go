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
	current, err := c.CurrentTheme()
	if err == nil && current == theme {
		return nil
	}

	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}
	lockFile, err := os.OpenFile(filepath.Join(runtimeDir, "omarchy-theme-set.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return fmt.Errorf("open theme-set lock: %w", err)
	}
	defer lockFile.Close()

	logPath := filepath.Join(sessionDir, "theme-set.log")
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open theme-set log: %w", err)
	}

	cmd := exec.Command("omarchy", "theme", "set", theme)
	cmd.Env = append(os.Environ(), "OMARCHY_THEME_SKIP_BACKGROUND=1")
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		_ = logFile.Close()
		return fmt.Errorf("start omarchy theme set %q: %w", theme, err)
	}
	_ = logFile.Close()

	waitCh := make(chan error, 1)
	go func() { waitCh <- cmd.Wait() }()
	ticker := time.NewTicker(25 * time.Millisecond)
	defer ticker.Stop()
	timeout := time.NewTimer(10 * time.Second)
	defer timeout.Stop()

	for {
		select {
		case err := <-waitCh:
			currentTheme, readErr := c.CurrentTheme()
			if err == nil && readErr == nil && currentTheme == theme && themeSetLockFree(lockFile) {
				return nil
			}
			logData, _ := os.ReadFile(logPath)
			return fmt.Errorf("theme set exited before critical apply completed: %v: %s", err, strings.TrimSpace(string(logData)))
		case <-ticker.C:
			currentTheme, err := c.CurrentTheme()
			if err != nil || currentTheme != theme || !themeSetLockFree(lockFile) {
				continue
			}
			return nil
		case <-timeout.C:
			_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
			return fmt.Errorf("timed out waiting for theme %q to apply", theme)
		}
	}
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
