package omarchy

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const terminalReloadWatchdog = 5 * time.Second
const terminalReloadPendingFile = "terminal-reload.pending"
const terminalReloadDirectoryPrefix = ".terminal-reload-"

var cacheWarmupCommands = []string{
	"omarchy-theme-switcher",
	"omarchy-theme-bg-cache",
}

type terminalReloadSync struct {
	directory string
	marker    string
	shim      string
	path      string
}

func newTerminalReloadSync(logPath string) (*terminalReloadSync, error) {
	realCommand, err := exec.LookPath("omarchy-restart-terminal")
	if err != nil {
		return nil, fmt.Errorf("resolve omarchy terminal reload: %w", err)
	}
	parent := filepath.Dir(logPath)
	if err := clearPendingTerminalReload(parent); err != nil {
		return nil, fmt.Errorf("clear previous terminal reload marker: %w", err)
	}
	if err := cleanupTerminalReloadDirectories(parent); err != nil {
		return nil, fmt.Errorf("remove stale terminal reload directories: %w", err)
	}
	directory, err := os.MkdirTemp(parent, terminalReloadDirectoryPrefix)
	if err != nil {
		return nil, fmt.Errorf("create terminal reload marker directory: %w", err)
	}
	sync := &terminalReloadSync{
		directory: directory,
		marker:    filepath.Join(directory, "complete"),
		shim:      filepath.Join(directory, "omarchy-restart-terminal"),
		path:      realCommand,
	}
	const shim = `#!/bin/bash
"$OMAGEN_REAL_TERMINAL_RELOAD" "$@"
status=$?
: > "$OMAGEN_TERMINAL_RELOAD_MARKER"
exit "$status"
`
	if err := os.WriteFile(sync.shim, []byte(shim), 0755); err != nil {
		_ = os.RemoveAll(directory)
		return nil, fmt.Errorf("write terminal reload marker shim: %w", err)
	}
	if err := writeCacheWarmupShims(directory); err != nil {
		_ = os.RemoveAll(directory)
		return nil, err
	}
	return sync, nil
}

type cacheWarmupSkip struct {
	directory string
}

func newCacheWarmupSkip() (*cacheWarmupSkip, error) {
	directory, err := os.MkdirTemp("", ".omagen-cache-warmup-")
	if err != nil {
		return nil, fmt.Errorf("create cache warmup shim directory: %w", err)
	}
	if err := writeCacheWarmupShims(directory); err != nil {
		_ = os.RemoveAll(directory)
		return nil, err
	}
	return &cacheWarmupSkip{directory: directory}, nil
}

func writeCacheWarmupShims(directory string) error {
	const skip = "#!/bin/sh\nexit 0\n"
	for _, command := range cacheWarmupCommands {
		if err := os.WriteFile(filepath.Join(directory, command), []byte(skip), 0755); err != nil {
			return fmt.Errorf("write cache warmup shim %s: %w", command, err)
		}
	}
	return nil
}

func (s *cacheWarmupSkip) environment() []string {
	return []string{"PATH=" + s.directory + string(os.PathListSeparator) + os.Getenv("PATH")}
}

func (s *cacheWarmupSkip) close() error {
	if s == nil || strings.TrimSpace(s.directory) == "" {
		return nil
	}
	return os.RemoveAll(s.directory)
}

func (s *terminalReloadSync) environment() []string {
	return []string{
		"OMAGEN_REAL_TERMINAL_RELOAD=" + s.path,
		"OMAGEN_TERMINAL_RELOAD_MARKER=" + s.marker,
		"PATH=" + s.directory + string(os.PathListSeparator) + os.Getenv("PATH"),
	}
}

func (s *terminalReloadSync) wait() error {
	deadline := time.Now().Add(terminalReloadWatchdog)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(s.marker); err == nil {
			return nil
		} else if !os.IsNotExist(err) {
			return fmt.Errorf("inspect terminal reload marker: %w", err)
		}
		time.Sleep(25 * time.Millisecond)
	}
	return fmt.Errorf("timed out waiting for Omarchy terminal reload completion marker")
}

func (s *terminalReloadSync) persist() error {
	pendingPath := pendingTerminalReloadPath(filepath.Dir(s.directory))
	if err := os.WriteFile(pendingPath, []byte(s.marker+"\n"), 0600); err != nil {
		return fmt.Errorf("persist terminal reload marker: %w", err)
	}
	return nil
}

// WaitForPendingTerminalReload is intentionally called by Demo, not Preview.
// Preview can return as soon as the theme is critically applied; Demo is the
// operation that needs to wait before it creates new terminal windows.
func WaitForPendingTerminalReload(sessionDir string) error {
	parent := filepath.Join(sessionDir, "preview-logs")
	pendingPath := pendingTerminalReloadPath(parent)
	data, err := os.ReadFile(pendingPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read terminal reload marker: %w", err)
	}
	marker := strings.TrimSpace(string(data))
	if marker == "" {
		return fmt.Errorf("terminal reload marker is empty")
	}
	if err := validateMarkerPath(parent, marker); err != nil {
		return err
	}
	sync := &terminalReloadSync{directory: filepath.Dir(marker), marker: marker}
	waitErr := sync.wait()
	clearErr := clearPendingTerminalReload(parent)
	cleanupErr := cleanupTerminalReloadDirectories(parent)
	return errors.Join(waitErr, clearErr, cleanupErr)
}

func clearPendingTerminalReload(parent string) error {
	pendingPath := pendingTerminalReloadPath(parent)
	data, err := os.ReadFile(pendingPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	marker := strings.TrimSpace(string(data))
	if marker != "" {
		if err := validateMarkerPath(parent, marker); err != nil {
			return err
		}
		if err := os.RemoveAll(filepath.Dir(marker)); err != nil {
			return err
		}
	}
	return os.Remove(pendingPath)
}

func pendingTerminalReloadPath(parent string) string {
	return filepath.Join(parent, terminalReloadPendingFile)
}

func cleanupTerminalReloadDirectories(parent string) error {
	entries, err := os.ReadDir(parent)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	var errs []error
	for _, entry := range entries {
		if !entry.IsDir() || !strings.HasPrefix(entry.Name(), terminalReloadDirectoryPrefix) {
			continue
		}
		if err := os.RemoveAll(filepath.Join(parent, entry.Name())); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func validateMarkerPath(parent, marker string) error {
	parent, err := filepath.Abs(parent)
	if err != nil {
		return fmt.Errorf("resolve terminal reload marker directory: %w", err)
	}
	marker, err = filepath.Abs(marker)
	if err != nil {
		return fmt.Errorf("resolve terminal reload marker: %w", err)
	}
	relative, err := filepath.Rel(parent, marker)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return fmt.Errorf("terminal reload marker escapes preview directory")
	}
	return nil
}

func (s *terminalReloadSync) close() error {
	if s == nil || strings.TrimSpace(s.directory) == "" {
		return nil
	}
	var errs []error
	pendingPath := pendingTerminalReloadPath(filepath.Dir(s.directory))
	if data, err := os.ReadFile(pendingPath); err == nil && filepath.Clean(strings.TrimSpace(string(data))) == filepath.Clean(s.marker) {
		if err := os.Remove(pendingPath); err != nil && !errors.Is(err, os.ErrNotExist) {
			errs = append(errs, err)
		}
	} else if err != nil && !errors.Is(err, os.ErrNotExist) {
		errs = append(errs, err)
	}
	if err := os.RemoveAll(s.directory); err != nil {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}
