package omarchy

import (
	"bytes"
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

type ThemeInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Kind        string `json:"kind"`
	PreviewPath string `json:"preview_path,omitempty"`
	StockPath   string `json:"stock_path,omitempty"`
	UserPath    string `json:"user_path,omitempty"`
}

const maxStudioLogBytes int64 = 1 << 20

type Client struct {
	stderr               io.Writer
	studioPreviewCommand string
}

type studioOptionsAware interface {
	ApplyThemePreviewWithOptions(themeName, logPath, retintRun, retintSkip, scope, waitMode string, allowTrustedHooks bool) (pid int, alreadyActive bool, err error)
	ApplyThemeWithOptions(themeName, logPath, retintRun, retintSkip, scope, waitMode string, allowTrustedHooks bool) error
}

func NewClient(stderr io.Writer) *Client {
	return &Client{stderr: stderr, studioPreviewCommand: resolveStudioPreviewCommand()}
}

func resolveStudioPreviewCommand() string {
	if configured := strings.TrimSpace(os.Getenv("OMAGEN_STUDIO_THEME_SET")); configured != "" {
		if info, err := os.Stat(configured); err == nil && info.Mode().IsRegular() && info.Mode()&0o111 != 0 {
			return configured
		}
		return ""
	}
	executable, err := os.Executable()
	if err != nil {
		return ""
	}
	configured := filepath.Join(filepath.Dir(executable), "studio-theme-set")
	info, err := os.Stat(configured)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&0o111 == 0 {
		return ""
	}
	return configured
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

// ListThemes delegates discovery to Omarchy so stock and user-installed
// themes follow the same precedence rules as the native switcher.
func (c *Client) ListThemes() ([]ThemeInfo, error) {
	command := exec.Command("omarchy", "theme", "list")
	var output bytes.Buffer
	command.Stdout = &output
	command.Stderr = c.stderr
	command.Env = appendOmarchyEnvironment(os.Environ())
	if err := command.Run(); err != nil {
		return nil, fmt.Errorf("list Omarchy themes: %w", err)
	}
	lines := strings.Split(strings.ReplaceAll(output.String(), "\r\n", "\n"), "\n")
	result := make([]ThemeInfo, 0, len(lines))
	seen := make(map[string]struct{})
	for _, line := range lines {
		name := strings.TrimSpace(line)
		if name == "" {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		id := themeSlug(name)
		path, err := c.ThemeDir(id)
		if err != nil {
			return nil, fmt.Errorf("resolve Omarchy theme %q: %w", name, err)
		}
		stockPath, userPath := c.themeRoots(id)
		kind := "stock"
		if userPath != "" && stockPath != "" {
			kind = "user-overlay"
		} else if userPath != "" {
			kind = "user"
		}
		previewPath := firstThemeAsset("preview.png", userPath, stockPath, path)
		result = append(result, ThemeInfo{ID: id, Name: name, Path: path, Kind: kind, PreviewPath: previewPath, StockPath: stockPath, UserPath: userPath})
	}
	return result, nil
}

// firstThemeAsset follows native overlay precedence while keeping the catalog
// response useful to visual consumers. A missing preview is valid; the picker
// renders a deliberate placeholder instead of hiding the theme.
func firstThemeAsset(name string, roots ...string) string {
	for _, root := range roots {
		if strings.TrimSpace(root) == "" {
			continue
		}
		candidate := filepath.Join(root, name)
		info, err := os.Stat(candidate)
		if err == nil && info.Mode().IsRegular() && info.Size() > 0 {
			return candidate
		}
	}
	return ""
}

func (c *Client) ThemeDir(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" || strings.ContainsAny(name, "\r\n") {
		return "", fmt.Errorf("invalid theme name")
	}
	command := exec.Command("omarchy", "theme", "dir", name)
	var output bytes.Buffer
	command.Stdout = &output
	command.Stderr = c.stderr
	command.Env = appendOmarchyEnvironment(os.Environ())
	if err := command.Run(); err != nil {
		return "", fmt.Errorf("resolve Omarchy theme directory: %w", err)
	}
	path := strings.TrimSpace(output.String())
	if !filepath.IsAbs(path) || path == "/" {
		return "", fmt.Errorf("Omarchy returned an invalid theme directory")
	}
	path, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("theme directory is not a directory")
	}
	return path, nil
}

func themeKind(path string) string {
	home, err := os.UserHomeDir()
	if err == nil {
		userRoot := filepath.Join(home, ".config", "omarchy", "themes")
		if relative, relErr := filepath.Rel(userRoot, path); relErr == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return "user"
		}
	}
	return "stock"
}

func themeSlug(name string) string {
	name = strings.ToLower(strings.TrimSpace(name))
	var b strings.Builder
	dash := false
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			if dash && b.Len() > 0 {
				b.WriteByte('-')
			}
			b.WriteRune(r)
			dash = false
		} else {
			dash = b.Len() > 0
		}
	}
	return strings.Trim(b.String(), "-")
}

func (c *Client) themeRoots(slug string) (stockPath, userPath string) {
	home, homeErr := os.UserHomeDir()
	if homeErr == nil {
		candidate := filepath.Join(home, ".config", "omarchy", "themes", slug)
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			userPath = candidate
		}
	}
	root := strings.TrimSpace(os.Getenv("OMARCHY_PATH"))
	if root == "" {
		if home, err := os.UserHomeDir(); err == nil {
			candidate := filepath.Join(home, ".local", "share", "omarchy")
			if _, err := os.Stat(filepath.Join(candidate, "themes")); err == nil {
				root = candidate
			}
		}
	}
	if root == "" {
		root = "/usr/share/omarchy"
	}
	candidate := filepath.Join(root, "themes", slug)
	if info, err := os.Stat(candidate); err == nil && info.IsDir() {
		stockPath = candidate
	}
	return stockPath, userPath
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

// VerifyNativeState checks the files and readers that form the stable native
// evidence available without inventing a shell-specific IPC query. It is
// deliberately conservative: theme.name, the promoted theme directory,
// colors.toml, shell.toml, and the current background link must be readable.
func (c *Client) VerifyNativeState(expectedTheme string) (string, error) {
	current, err := c.CurrentTheme()
	if err != nil {
		return "", fmt.Errorf("verify active theme: %w", err)
	}
	if current != expectedTheme {
		return "", fmt.Errorf("verify active theme: expected %q, got %q", expectedTheme, current)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	themeRoot := filepath.Join(home, ".local", "state", "omarchy", "current", "theme")
	for _, name := range []string{"colors.toml", "shell.toml"} {
		info, statErr := os.Stat(filepath.Join(themeRoot, name))
		if statErr != nil {
			return "", fmt.Errorf("verify native reader input %s: %w", name, statErr)
		}
		if !info.Mode().IsRegular() || info.Size() == 0 {
			return "", fmt.Errorf("verify native reader input %s: not a non-empty regular file", name)
		}
	}
	background, err := c.CurrentBackground()
	if err != nil {
		return "", fmt.Errorf("verify current background: %w", err)
	}
	return fmt.Sprintf("theme.name=%s colors.toml=read shell.toml=read background=%s:%s", current, background.Kind, background.Path), nil
}

func (c *Client) RestoreThemeFast(theme, sessionDir string) error {
	// Rollback is the fast path: the session has already closed its owned Demo
	// windows before this call, so it only needs to wait until Omarchy has
	// promoted the original theme and released its transaction lock. Native
	// terminal, Hyprland, and other post-commit adapters may continue after that
	// point; waiting for all of them here makes Restore & close unnecessarily
	// block the UI and is not part of the rollback transaction.
	_, _, err := c.runThemeSetUntilCritical(theme, filepath.Join(sessionDir, "theme-set.log"), []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=1",
	}, 30*time.Second)
	return err
}

func (c *Client) ApplyThemePreview(themeName, logPath string) (int, bool, error) {
	return c.ApplyThemePreviewWithPolicy(themeName, logPath, "", "")
}

func (c *Client) ApplyThemePreviewWithPolicy(themeName, logPath, retintRun, retintSkip string) (int, bool, error) {
	return c.ApplyThemePreviewWithOptions(themeName, logPath, retintRun, retintSkip, "", "", false)
}

func (c *Client) ApplyThemePreviewWithOptions(themeName, logPath, retintRun, retintSkip, scope, waitMode string, allowTrustedHooks bool) (int, bool, error) {
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
	environment = appendStudioOptions(environment, scope, waitMode, allowTrustedHooks)
	environment = append(environment, "OMAGEN_STUDIO_POST_COMMIT_LOG="+logPath+".post-commit")
	environment = append(environment, reloadSync.environment()...)
	pid, _, err := c.runStudioThemeSetUntilCriticalWithPolicy(themeName, logPath, environment, 10*time.Second, retintRun, retintSkip)
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

func (c *Client) ApplyThemeWithPolicy(themeName, logPath, retintRun, retintSkip string) error {
	return c.ApplyThemeWithOptions(themeName, logPath, retintRun, retintSkip, "", "", false)
}

func (c *Client) ApplyThemeWithOptions(themeName, logPath, retintRun, retintSkip, scope, waitMode string, allowTrustedHooks bool) error {
	if c.studioPreviewCommand == "" {
		return fmt.Errorf("Studio theme driver is not installed")
	}
	environment := []string{
		"OMARCHY_THEME_HEADLESS=0", "OMARCHY_THEME_OFFLINE=0", "OMARCHY_THEME_SKIP_BACKGROUND=0",
	}
	environment = appendStudioOptions(environment, scope, waitMode, allowTrustedHooks)
	environment = append(environment, "OMAGEN_STUDIO_POST_COMMIT_LOG="+logPath+".post-commit")
	// The core theme transaction is committed once the active theme and the
	// shared theme-set lock are settled. Retint adapters are post-commit work;
	// waiting for every application helper here can strand the UI if one hangs.
	// The Studio driver remains alive to finish those adapters in parallel.
	_, _, err := c.runStudioThemeSetApplyUntilCriticalWithPolicy(themeName, logPath, environment, 30*time.Second, retintRun, retintSkip)
	return err
}

func appendStudioOptions(environment []string, scope, waitMode string, allowTrustedHooks bool) []string {
	if scope != "" {
		environment = append(environment, "OMAGEN_STUDIO_SCOPE="+scope)
	}
	if waitMode != "" {
		environment = append(environment, "OMAGEN_STUDIO_WAIT="+waitMode)
	}
	if allowTrustedHooks {
		environment = append(environment, "OMAGEN_STUDIO_ALLOW_TRUSTED_HOOKS=1")
	}
	return environment
}

// FinalizePreviewTheme promotes an already-live Studio preview to its
// permanent theme name without repeating the theme transaction or retinting
// applications. The caller verifies the preview provenance before invoking
// this method; this guard prevents accidentally renaming an unrelated active
// theme.
func (c *Client) FinalizePreviewTheme(themeName string) error {
	if strings.TrimSpace(themeName) == "" || strings.ContainsAny(themeName, "\r\n") {
		return fmt.Errorf("invalid finalized theme name")
	}
	current, err := c.CurrentTheme()
	if err != nil {
		return err
	}
	if !strings.HasPrefix(current, "omagen-preview-") {
		return fmt.Errorf("active theme %q is not an Omagen preview", current)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	currentDir := filepath.Join(home, ".local", "state", "omarchy", "current")
	temp, err := os.CreateTemp(currentDir, ".theme.name-*.tmp")
	if err != nil {
		return fmt.Errorf("stage finalized theme name: %w", err)
	}
	tempPath := temp.Name()
	defer os.Remove(tempPath)
	if _, err := temp.WriteString(themeName + "\n"); err != nil {
		_ = temp.Close()
		return fmt.Errorf("write finalized theme name: %w", err)
	}
	if err := temp.Sync(); err != nil {
		_ = temp.Close()
		return fmt.Errorf("sync finalized theme name: %w", err)
	}
	if err := temp.Close(); err != nil {
		return fmt.Errorf("close finalized theme name: %w", err)
	}
	if err := os.Rename(tempPath, filepath.Join(currentDir, "theme.name")); err != nil {
		return fmt.Errorf("promote finalized theme name: %w", err)
	}
	directory, err := os.Open(currentDir)
	if err != nil {
		return fmt.Errorf("open current theme directory: %w", err)
	}
	defer directory.Close()
	if err := directory.Sync(); err != nil {
		return fmt.Errorf("sync current theme directory: %w", err)
	}
	return nil
}

func (c *Client) runThemeSetUntilCritical(theme, logPath string, environment []string, timeoutDuration time.Duration) (int, bool, error) {
	return c.runThemeSetUntilCriticalWithCleanup(theme, logPath, environment, timeoutDuration, nil)
}

func (c *Client) runThemeSetUntilCriticalWithCleanup(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func()) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, cleanup, false, "", "", "")
}

func (c *Client) runStudioThemeSetUntilCritical(theme, logPath string, environment []string, timeoutDuration time.Duration) (int, bool, error) {
	return c.runStudioThemeSetUntilCriticalWithPolicy(theme, logPath, environment, timeoutDuration, "", "")
}

func (c *Client) runStudioThemeSetUntilCriticalWithCleanup(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func()) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, cleanup, false, "preview", "", "")
}

func (c *Client) runStudioThemeSetUntilCriticalWithPolicy(theme, logPath string, environment []string, timeoutDuration time.Duration, retintRun, retintSkip string) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, nil, false, "preview", retintRun, retintSkip)
}

func (c *Client) runStudioThemeSetApplyUntilCriticalWithPolicy(theme, logPath string, environment []string, timeoutDuration time.Duration, retintRun, retintSkip string) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, nil, false, "apply", retintRun, retintSkip)
}

func (c *Client) runThemeSetToCompletionWithCleanup(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func()) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, cleanup, true, "", "", "")
}

func (c *Client) runStudioThemeSetToCompletionWithPolicy(theme, logPath string, environment []string, timeoutDuration time.Duration, retintRun, retintSkip string) (int, bool, error) {
	return c.runThemeSet(theme, logPath, environment, timeoutDuration, nil, true, "apply", retintRun, retintSkip)
}

func (c *Client) runThemeSet(theme, logPath string, environment []string, timeoutDuration time.Duration, cleanup func(), waitForCompletion bool, studioMode, retintRun, retintSkip string) (int, bool, error) {
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
	// The log path is session-scoped and unique per operation. Pass a stable
	// activation token to Studio so deferred adapters can fence themselves when
	// a newer theme intent supersedes this one.
	activationID := filepath.Base(logPath)
	environment = append(environment, "OMAGEN_ACTIVATION_ID="+activationID)

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

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		clean()
		return 0, false, fmt.Errorf("open theme-set log: %w", err)
	}
	logReader, logWriter, err := os.Pipe()
	if err != nil {
		_ = logFile.Close()
		clean()
		return 0, false, fmt.Errorf("prepare bounded theme-set log: %w", err)
	}
	logDone := make(chan error, 1)
	go func() {
		writer := &boundedLogWriter{dst: logFile, remaining: maxStudioLogBytes}
		_, copyErr := io.Copy(writer, logReader)
		if writer.truncated {
			_, _ = io.WriteString(logFile, "\n[omagen] log truncated at 1048576 bytes\n")
		}
		if syncErr := logFile.Sync(); copyErr == nil {
			copyErr = syncErr
		}
		_ = logReader.Close()
		_ = logFile.Close()
		logDone <- copyErr
	}()

	command := "omarchy"
	arguments := []string{"theme", "set", theme}
	if studioMode != "" && c.studioPreviewCommand != "" {
		command = c.studioPreviewCommand
		arguments = []string{studioMode, theme, "--no-hooks"}
		if retintRun != "" {
			arguments = append(arguments, "--run", retintRun)
		}
		if retintSkip != "" {
			arguments = append(arguments, "--skip", retintSkip)
		}
		if retintRun == "" && retintSkip == "" {
			if policy := strings.TrimSpace(os.Getenv("OMAGEN_STUDIO_PREVIEW_APPS")); policy != "" {
				arguments = append(arguments, "--run", policy)
			}
		}
	}
	cmd := exec.Command(command, arguments...)
	cmd.Env = replaceEnvironment(appendOmarchyEnvironment(os.Environ()), environment...)
	cmd.Stdout = logWriter
	cmd.Stderr = logWriter
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		_ = logWriter.Close()
		_ = logReader.Close()
		<-logDone
		clean()
		return 0, false, fmt.Errorf("start omarchy theme set %q: %w", theme, err)
	}
	pid := cmd.Process.Pid
	closeLog := func() error {
		if err := logWriter.Close(); err != nil {
			return err
		}
		return <-logDone
	}

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
			logErr := closeLog()
			currentTheme, readErr := c.CurrentTheme()
			if err == nil && readErr == nil && currentTheme == theme && themeSetLockFree(lockFile) {
				if logErr != nil {
					return pid, false, fmt.Errorf("persist theme-set log: %w", logErr)
				}
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
			_ = closeLog()
			return pid, false, fmt.Errorf("timed out waiting for theme %q %s", theme, waitTarget)
		}
	}
}

type boundedLogWriter struct {
	dst       io.Writer
	remaining int64
	truncated bool
}

func (w *boundedLogWriter) Write(data []byte) (int, error) {
	if w.remaining <= 0 {
		w.truncated = true
		return len(data), nil
	}
	limit := int64(len(data))
	if limit > w.remaining {
		limit = w.remaining
		w.truncated = true
	}
	n, err := w.dst.Write(data[:limit])
	w.remaining -= int64(n)
	if err != nil {
		return n, err
	}
	if n < len(data) {
		return len(data), nil
	}
	return n, nil
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
	cmd.Env = appendOmarchyEnvironment(os.Environ())
	cmd.Stdout = c.stderr
	cmd.Stderr = c.stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("omarchy theme bg set %q: %w", path, err)
	}
	// Theme restoration can put the current/background symlink back at the
	// same path that the preview used. Quattro's normal `set` and `refresh`
	// paths compare the path string, so they can ignore a changed symlink that
	// points at a different image. setInstant is the native reader's explicit
	// force path and makes the live wallpaper reread the restored target.
	if _, err := exec.LookPath("omarchy-shell"); err != nil {
		return nil
	}
	var lastErr error
	for attempt := 0; attempt < 6; attempt++ {
		force := exec.Command("omarchy-shell", "background", "setInstant", path)
		force.Env = appendOmarchyEnvironment(os.Environ())
		force.Stdout = c.stderr
		force.Stderr = c.stderr
		if err := force.Run(); err == nil {
			return nil
		} else {
			lastErr = err
		}
		if attempt < 5 {
			time.Sleep(500 * time.Millisecond)
		}
	}
	return fmt.Errorf("force restored background through shell IPC: %w", lastErr)
}

// appendOmarchyEnvironment follows Omarchy's official OMARCHY_PATH first.
// A valid user-local checkout remains a fallback for callers launched without
// the session environment, followed by the packaged system path.
func appendOmarchyEnvironment(environment []string) []string {
	path := ""
	if configured := strings.TrimSpace(os.Getenv("OMARCHY_PATH")); configured != "" {
		if info, statErr := os.Stat(filepath.Join(configured, "shell", "shell.qml")); statErr == nil && info.Mode().IsRegular() {
			path = configured
		}
	}
	if path == "" {
		if home, err := os.UserHomeDir(); err == nil {
			candidate := filepath.Join(home, ".local", "share", "omarchy")
			if info, statErr := os.Stat(filepath.Join(candidate, "shell", "shell.qml")); statErr == nil && info.Mode().IsRegular() {
				path = candidate
			}
		}
	}
	if path == "" {
		candidate := "/usr/share/omarchy"
		if info, statErr := os.Stat(filepath.Join(candidate, "shell", "shell.qml")); statErr == nil && info.Mode().IsRegular() {
			path = candidate
		}
	}
	if path == "" {
		return environment
	}
	return replaceEnvironment(environment, "OMARCHY_PATH="+path)
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
