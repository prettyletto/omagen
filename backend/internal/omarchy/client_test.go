package omarchy

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestSafeRelativePath(t *testing.T) {
	for _, path := range []string{"", ".", "/absolute", "..", "../escape"} {
		if safeRelativePath(path) {
			t.Errorf("accepted unsafe path %q", path)
		}
	}
	for _, path := range []string{"bg.png", "nested/bg.png"} {
		if !safeRelativePath(path) {
			t.Errorf("rejected safe path %q", path)
		}
	}
}

func TestCurrentThemeAndBackground(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	current := filepath.Join(home, ".local/state/omarchy/current")
	themeRoot := filepath.Join(current, "theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("  nord\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"colors.toml", "shell.toml"} {
		if err := os.WriteFile(filepath.Join(themeRoot, name), []byte("[section]\nvalue = true\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	background := filepath.Join(themeRoot, "bg.png")
	if err := os.WriteFile(background, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(background, filepath.Join(current, "background")); err != nil {
		t.Fatal(err)
	}
	c := NewClient(nil)
	if theme, err := c.CurrentTheme(); err != nil || theme != "nord" {
		t.Fatalf("theme=%q err=%v", theme, err)
	}
	got, err := c.CurrentBackground()
	if err != nil || got != (session.BackgroundRef{Kind: "theme", Path: "bg.png"}) {
		t.Fatalf("background=%#v err=%v", got, err)
	}
	if evidence, err := c.VerifyNativeState("nord"); err != nil || !strings.Contains(evidence, "colors.toml=read") || !strings.Contains(evidence, "shell.toml=read") {
		t.Fatalf("native evidence=%q err=%v", evidence, err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := c.CurrentTheme(); err == nil {
		t.Fatal("expected empty theme error")
	}
}

func TestListThemesSkipsEphemeralPreviewAliases(t *testing.T) {
	home := t.TempDir()
	commandBin := t.TempDir()
	stockThemes := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("OMARCHY_PATH", stockThemes)
	t.Setenv("PATH", commandBin+string(os.PathListSeparator)+os.Getenv("PATH"))

	if err := os.MkdirAll(filepath.Join(stockThemes, "themes", "nord"), 0o755); err != nil {
		t.Fatal(err)
	}
	command := filepath.Join(commandBin, "omarchy")
	contents := `#!/bin/sh
if [ "$1" = "theme" ] && [ "$2" = "list" ]; then
    printf '%s\n' 'Nord' 'Omagen Preview Session 123 Source Colors abcdef0123456789' 'Nord'
    exit 0
fi
if [ "$1" = "theme" ] && [ "$2" = "dir" ] && [ "$3" = "nord" ]; then
    printf '%s\n' "$OMARCHY_PATH/themes/nord"
    exit 0
fi
exit 1
`
	if err := os.WriteFile(command, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}

	themes, err := NewClient(nil).ListThemes()
	if err != nil {
		t.Fatal(err)
	}
	if len(themes) != 1 {
		t.Fatalf("themes=%#v, want only the installed theme", themes)
	}
	if themes[0].ID != "nord" || themes[0].Name != "Nord" {
		t.Fatalf("theme=%#v, want Nord", themes[0])
	}
}

func TestResolveBackground(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path := filepath.Join(home, ".local/state/omarchy/current/theme/bg.png")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	c := NewClient(nil)
	got, err := c.resolveBackground(session.BackgroundRef{Kind: "theme", Path: "bg.png"})
	if err != nil || got != path {
		t.Fatalf("got=%q err=%v", got, err)
	}
	external := filepath.Join(t.TempDir(), "bg.png")
	if err := os.WriteFile(external, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	got, err = c.resolveBackground(session.BackgroundRef{Kind: "external", Path: external})
	if err != nil || got != external {
		t.Fatalf("got=%q err=%v", got, err)
	}
	for _, ref := range []session.BackgroundRef{{Kind: "theme", Path: "../x"}, {Kind: "external", Path: "relative"}, {Kind: "other", Path: "x"}} {
		if _, err := c.resolveBackground(ref); err == nil {
			t.Errorf("accepted %#v", ref)
		}
	}
}

func TestRestoreThemeAlreadyApplied(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(path, "theme.name"), []byte("theme\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := NewClient(nil).RestoreThemeFast("theme", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	lock, err := os.CreateTemp(t.TempDir(), "lock")
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if !themeSetLockFree(lock) {
		t.Fatal("expected lock to be free")
	}
}

func TestOmarchyCommandErrors(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("PATH", t.TempDir())
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := NewClient(nil).RestoreThemeFast("new", t.TempDir()); err == nil {
		t.Fatal("expected missing command error")
	}
	if err := NewClient(nil).RestoreBackground(session.BackgroundRef{Kind: "other"}); err == nil {
		t.Fatal("expected background resolution error")
	}
}

func TestRestoreCommands(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	script := filepath.Join(bin, "omarchy")
	contents := "#!/bin/sh\nif [ \"$2\" = \"set\" ]; then printf '%s\\n' \"$3\" > \"$HOME/.local/state/omarchy/current/theme.name\"; else exit 0; fi\n"
	if err := os.WriteFile(script, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	refreshScript := filepath.Join(bin, "omarchy-shell")
	refreshContents := "#!/bin/sh\nprintf '%s %s %s %s\\n' \"$1\" \"$2\" \"$3\" \"$4\" > \"$HOME/refresh.log\"\n"
	if err := os.WriteFile(refreshScript, []byte(refreshContents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(filepath.Join(current, "theme"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	client := NewClient(&bytes.Buffer{})
	if err := client.RestoreThemeFast("new", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	background := filepath.Join(t.TempDir(), "bg.png")
	if err := os.WriteFile(background, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := client.RestoreBackground(session.BackgroundRef{Kind: "external", Path: background}); err != nil {
		t.Fatal(err)
	}
	refreshLog, err := os.ReadFile(filepath.Join(home, "refresh.log"))
	if err != nil {
		t.Fatal(err)
	}
	if got := string(refreshLog); got != "background setInstant "+background+" \n" {
		t.Fatalf("forced background command = %q", got)
	}
}

func TestRestoreThemeReturnsAtCriticalThemeState(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	contents := "#!/bin/sh\nif [ \"$2\" = \"set\" ]; then printf '%s\\n' \"$3\" > \"$HOME/.local/state/omarchy/current/theme.name\"; /usr/bin/sleep 0.20; printf done > \"$HOME/theme-set-finished\"; fi\n"
	if err := os.WriteFile(filepath.Join(bin, "omarchy"), []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	started := time.Now()
	if err := NewClient(nil).RestoreThemeFast("new", t.TempDir()); err != nil {
		t.Fatal(err)
	}
	if elapsed := time.Since(started); elapsed >= 150*time.Millisecond {
		t.Fatalf("RestoreThemeFast waited for post-commit completion: %v", elapsed)
	}
	if _, err := os.Stat(filepath.Join(home, "theme-set-finished")); err == nil {
		t.Fatal("restore returned only after theme-set completion marker")
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, err := os.Stat(filepath.Join(home, "theme-set-finished")); err == nil {
			break
		}
		if !time.Now().Before(deadline) {
			t.Fatal("theme-set did not finish after critical restore returned")
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestApplyThemePreviewWaitsForCriticalThemeApply(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	themeSet := filepath.Join(bin, "omarchy")
	contents := "#!/bin/sh\nif [ \"$2\" = \"set\" ]; then /usr/bin/sleep 0.15; printf '%s\\n' \"$3\" > \"$HOME/.local/state/omarchy/current/theme.name\"; /usr/bin/sleep 0.30; printf done > \"$HOME/theme-set-finished\"; fi\n"
	if err := os.WriteFile(themeSet, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	reload := filepath.Join(bin, "omarchy-restart-terminal")
	if err := os.WriteFile(reload, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	previewLogs := filepath.Join(t.TempDir(), "preview-logs")
	if err := os.MkdirAll(previewLogs, 0o755); err != nil {
		t.Fatal(err)
	}
	logPath := filepath.Join(previewLogs, "preview.log")
	if _, already, err := NewClient(nil).ApplyThemePreview("new", logPath); err != nil || already {
		t.Fatalf("preview apply already=%v err=%v", already, err)
	}
	data, err := os.ReadFile(filepath.Join(current, "theme.name"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(string(data)) != "new" {
		t.Fatalf("theme after preview=%q", strings.TrimSpace(string(data)))
	}
	if _, err := os.Stat(filepath.Join(previewLogs, terminalReloadPendingFile)); err != nil {
		t.Fatalf("preview did not persist terminal reload marker: %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, "theme-set-finished")); !os.IsNotExist(err) {
		t.Fatalf("preview waited for full theme-set completion, err=%v", err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, err := os.Stat(filepath.Join(home, "theme-set-finished")); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("preview theme-set process did not finish")
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestApplyThemePreviewUsesStudioDriverWithNoHookPolicy(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	driver := filepath.Join(bin, "studio-theme-set")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$HOME/studio-driver-args\"\nprintf '%s\\n' \"$OMAGEN_ACTIVATION_ID\" > \"$HOME/studio-driver-activation\"\nprintf '%s\\n' \"$2\" > \"$HOME/.local/state/omarchy/current/theme.name\"\n"
	if err := os.WriteFile(driver, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("OMAGEN_STUDIO_THEME_SET", driver)

	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	logPath := filepath.Join(t.TempDir(), "preview.log")
	if _, already, err := NewClient(nil).ApplyThemePreview("new", logPath); err != nil || already {
		t.Fatalf("preview apply already=%v err=%v", already, err)
	}
	args, err := os.ReadFile(filepath.Join(home, "studio-driver-args"))
	if err != nil {
		t.Fatal(err)
	}
	if got := string(args); got != "preview\nnew\n--no-hooks\n" {
		t.Fatalf("studio driver args=%q", got)
	}
	activation, err := os.ReadFile(filepath.Join(home, "studio-driver-activation"))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(activation)); got != "preview.log" {
		t.Fatalf("activation id=%q", got)
	}
	data, err := os.ReadFile(filepath.Join(current, "theme.name"))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(data)); got != "new" {
		t.Fatalf("theme after preview=%q", got)
	}
}

func TestApplyThemePreviewReleasesLogFileAfterDriverExits(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("checks Linux process descriptors")
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	driver := filepath.Join(bin, "studio-theme-set")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$2\" > \"$HOME/.local/state/omarchy/current/theme.name\"\nprintf done > \"$HOME/driver-finished\"\n"
	if err := os.WriteFile(driver, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("OMAGEN_STUDIO_THEME_SET", driver)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	logPath := filepath.Join(t.TempDir(), "preview.log")
	if _, _, err := NewClient(nil).ApplyThemePreview("new", logPath); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, err := os.Stat(filepath.Join(home, "driver-finished")); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("preview driver did not exit")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if err := os.Remove(logPath); err != nil {
		t.Fatal(err)
	}
	for time.Now().Before(deadline) {
		if !hasOpenDeletedPath(logPath) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("preview log remains open after driver exit: %s", logPath)
}

func hasOpenDeletedPath(path string) bool {
	entries, err := os.ReadDir("/proc/self/fd")
	if err != nil {
		return false
	}
	for _, entry := range entries {
		target, err := os.Readlink(filepath.Join("/proc/self/fd", entry.Name()))
		if err == nil && target == path+" (deleted)" {
			return true
		}
	}
	return false
}

func TestApplyThemePreviewPassesNonUIRetintPolicy(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	driver := filepath.Join(bin, "studio-theme-set")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$HOME/studio-driver-args\"\nprintf '%s\\n' \"$2\" > \"$HOME/.local/state/omarchy/current/theme.name\"\n"
	if err := os.WriteFile(driver, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("OMAGEN_STUDIO_THEME_SET", driver)
	t.Setenv("OMAGEN_STUDIO_PREVIEW_APPS", "terminal,browser")

	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, already, err := NewClient(nil).ApplyThemePreview("new", filepath.Join(t.TempDir(), "preview.log")); err != nil || already {
		t.Fatalf("preview apply already=%v err=%v", already, err)
	}
	args, err := os.ReadFile(filepath.Join(home, "studio-driver-args"))
	if err != nil {
		t.Fatal(err)
	}
	if got := string(args); got != "preview\nnew\n--no-hooks\n--run\nterminal,browser\n" {
		t.Fatalf("studio driver args=%q", got)
	}
}

func TestStudioThemeSetLogIsBounded(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	driver := filepath.Join(bin, "studio-theme-set")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$2\" > \"$HOME/.local/state/omarchy/current/theme.name\"\n/usr/bin/dd if=/dev/zero bs=1048576 count=2 2>/dev/null\n"
	if err := os.WriteFile(driver, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	terminal := filepath.Join(bin, "omarchy-restart-terminal")
	if err := os.WriteFile(terminal, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	t.Setenv("OMAGEN_STUDIO_THEME_SET", driver)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	logPath := filepath.Join(t.TempDir(), "bounded.log")
	if _, _, err := NewClient(nil).ApplyThemePreview("new", logPath); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() > maxStudioLogBytes+128 {
		t.Fatalf("log size=%d, want at most %d", info.Size(), maxStudioLogBytes+128)
	}
	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "log truncated") {
		t.Fatal("bounded log did not record truncation marker")
	}
}

func TestApplyThemeWithPolicyUsesStudioDriverWithoutHooks(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	bin := t.TempDir()
	driver := filepath.Join(bin, "studio-theme-set")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$HOME/studio-driver-args\"\nprintf '%s\\n' \"$2\" > \"$HOME/.local/state/omarchy/current/theme.name\"\nsleep 1\nprintf finished > \"$HOME/studio-driver-finished\"\n"
	if err := os.WriteFile(driver, []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("OMAGEN_STUDIO_THEME_SET", driver)

	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := NewClient(nil).ApplyThemeWithPolicy("new", filepath.Join(t.TempDir(), "apply.log"), "", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(home, "studio-driver-finished")); !os.IsNotExist(err) {
		t.Fatalf("Apply waited for post-commit driver work, stat err=%v", err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		if _, err := os.Stat(filepath.Join(home, "studio-driver-finished")); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("Studio driver did not finish post-commit work")
		}
		time.Sleep(10 * time.Millisecond)
	}
	args, err := os.ReadFile(filepath.Join(home, "studio-driver-args"))
	if err != nil {
		t.Fatal(err)
	}
	if got := string(args); got != "apply\nnew\n--no-hooks\n" {
		t.Fatalf("studio driver args=%q", got)
	}
}

func TestFinalizePreviewThemeWritesPermanentNameOnly(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(filepath.Join(current, "theme"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("omagen-preview-session-generation-source\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := NewClient(nil).FinalizePreviewTheme("permanent-theme"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(current, "theme.name"))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(data)); got != "permanent-theme" {
		t.Fatalf("finalized theme=%q", got)
	}

	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("ryu\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := NewClient(nil).FinalizePreviewTheme("another-theme"); err == nil {
		t.Fatal("expected non-preview finalization to fail")
	}
}

func TestAppendOmarchyEnvironmentPrefersConfiguredPath(t *testing.T) {
	home := t.TempDir()
	configured := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("OMARCHY_PATH", configured)

	for _, root := range []string{configured, filepath.Join(home, ".local", "share", "omarchy")} {
		if err := os.MkdirAll(filepath.Join(root, "shell"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(root, "shell", "shell.qml"), []byte("Item {}\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	resolved := appendOmarchyEnvironment([]string{"PATH=/usr/bin", "OMARCHY_PATH=" + configured})
	for _, value := range resolved {
		if value == "OMARCHY_PATH="+configured {
			return
		}
	}
	t.Fatalf("configured OMARCHY_PATH was not preserved: %v", resolved)
}

func TestStudioThemeSetPreviewUsesAllowlistWithoutHooks(t *testing.T) {
	home := t.TempDir()
	omarchyPath := t.TempDir()
	commandBin := t.TempDir()
	runtimeDir := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("OMARCHY_PATH", omarchyPath)
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)
	t.Setenv("OMARCHY_THEME_SKIP_BACKGROUND", "1")
	t.Setenv("PATH", commandBin+":"+os.Getenv("PATH"))

	if err := os.MkdirAll(filepath.Join(omarchyPath, "shell"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(omarchyPath, "shell/shell.qml"), []byte("Item {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	candidate := filepath.Join(home, ".config/omarchy/themes/candidate")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	for path, contents := range map[string]string{
		filepath.Join(candidate, "colors.toml"):        "[colors]\nprimary = '#ffffff'\n",
		filepath.Join(candidate, "shell.toml"):         "[bar]\n",
		filepath.Join(candidate, "backgrounds/bg.png"): "not-an-image-but-a-theme-asset\n",
		filepath.Join(omarchyPath, "themes/.keep"):     "\n",
	} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	writeCommand := func(name, body string) {
		t.Helper()
		path := filepath.Join(commandBin, name)
		if err := os.WriteFile(path, []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	writeCommand("omarchy-theme-set-templates", "exit 0")
	writeCommand("omarchy-shell", "printf '%s\\n' \"$@\" >> \"$HOME/commands.log\"")
	writeCommand("omarchy-restart-terminal", "printf terminal >> \"$HOME/allowlist.log\"; (sleep 0.50; printf finished > \"$HOME/post-commit-finished\") & exit 1")
	writeCommand("omarchy-theme-set-browser", "printf browser >> \"$HOME/allowlist.log\"")
	writeCommand("omarchy-hook", "printf hook >> \"$HOME/disallowed.log\"")
	writeCommand("omarchy-restart-hyprctl", "printf hyprctl >> \"$HOME/disallowed.log\"")
	postCommitLog := filepath.Join(home, "post-commit.log")
	t.Setenv("OMAGEN_STUDIO_POST_COMMIT_LOG", postCommitLog)

	_, currentFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test source path")
	}
	driver := filepath.Join(filepath.Dir(currentFile), "../../../bin/studio-theme-set")
	started := time.Now()
	output, err := exec.Command(driver, "preview", "candidate", "--no-hooks", "--run", "terminal,browser", "--skip", "hyprland").CombinedOutput()
	if err != nil {
		t.Fatalf("studio-theme-set preview: %v: %s", err, output)
	}
	if elapsed := time.Since(started); elapsed >= 400*time.Millisecond {
		t.Fatalf("critical preview waited for detached post-commit work: %v", elapsed)
	}

	activeTheme, err := os.ReadFile(filepath.Join(home, ".local/state/omarchy/current/theme.name"))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(activeTheme)); got != "candidate" {
		t.Fatalf("active theme=%q", got)
	}
	allowlist, err := os.ReadFile(filepath.Join(home, "allowlist.log"))
	if err != nil || !strings.Contains(string(allowlist), "terminal") || !strings.Contains(string(allowlist), "browser") {
		t.Fatalf("allowlist log=%q err=%v", allowlist, err)
	}
	if _, err := os.Stat(filepath.Join(home, "disallowed.log")); !os.IsNotExist(err) {
		t.Fatalf("disallowed command ran, err=%v", err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		logData, logErr := os.ReadFile(postCommitLog)
		_, finishedErr := os.Stat(filepath.Join(home, "post-commit-finished"))
		if logErr == nil && strings.Contains(string(logData), "adapter=terminal status=failed") && finishedErr == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("detached post-commit work did not finish: log=%q logErr=%v markerErr=%v", logData, logErr, finishedErr)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestStudioThemeSetPreviewAllowsOwnedPreviewAlias(t *testing.T) {
	home := t.TempDir()
	omarchyPath := t.TempDir()
	commandBin := t.TempDir()
	runtimeDir := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("OMARCHY_PATH", omarchyPath)
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local/state"))
	t.Setenv("PATH", commandBin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("OMARCHY_THEME_HEADLESS", "1")

	if err := os.MkdirAll(filepath.Join(omarchyPath, "shell"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(omarchyPath, "shell/shell.qml"), []byte("Item {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(omarchyPath, "themes"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(commandBin, "omarchy-theme-set-templates"), []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}

	previewName := "omagen-preview-edit-session-generation-1-source-colors-0123456789abcdef"
	candidate := filepath.Join(home, ".local/state/omagen/sessions/edit-session/generations/generation-1/source")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	for path, contents := range map[string]string{
		filepath.Join(candidate, "colors.toml"):        "[colors]\nprimary = '#ffffff'\n",
		filepath.Join(candidate, "shell.toml"):         "[bar]\n",
		filepath.Join(candidate, "backgrounds/bg.png"): "preview-asset\n",
	} {
		if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	userThemes := filepath.Join(home, ".config/omarchy/themes")
	if err := os.MkdirAll(userThemes, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(candidate, filepath.Join(userThemes, previewName)); err != nil {
		t.Fatal(err)
	}
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(filepath.Join(current, "theme"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	_, currentFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test source path")
	}
	driver := filepath.Join(filepath.Dir(currentFile), "../../../bin/studio-theme-set")
	output, err := exec.Command(driver, "preview", previewName, "--no-hooks", "--scope", "theme", "--wait", "none", "--run", "none").CombinedOutput()
	if err != nil {
		t.Fatalf("studio-theme-set rejected owned preview alias: %v: %s", err, output)
	}
	activeTheme, err := os.ReadFile(filepath.Join(current, "theme.name"))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(activeTheme)); got != previewName {
		t.Fatalf("active theme=%q, want %q", got, previewName)
	}

	if err := os.Remove(filepath.Join(userThemes, previewName)); err != nil {
		t.Fatal(err)
	}
	external := filepath.Join(home, "outside-preview-target")
	if err := os.MkdirAll(external, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(external, filepath.Join(userThemes, previewName)); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	output, err = exec.Command(driver, "preview", previewName, "--no-hooks", "--scope", "theme", "--wait", "none", "--run", "none").CombinedOutput()
	if err == nil || !strings.Contains(string(output), "refusing symlinked theme directory") {
		t.Fatalf("studio-theme-set accepted external preview alias: err=%v output=%s", err, output)
	}
}

func TestStudioThemeSetPreviewUsesInstantBackgroundHandoff(t *testing.T) {
	home := t.TempDir()
	omarchyPath := t.TempDir()
	commandBin := t.TempDir()
	runtimeDir := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("OMARCHY_PATH", omarchyPath)
	t.Setenv("XDG_RUNTIME_DIR", runtimeDir)
	t.Setenv("PATH", commandBin+string(os.PathListSeparator)+os.Getenv("PATH"))

	if err := os.MkdirAll(filepath.Join(omarchyPath, "shell"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(omarchyPath, "shell/shell.qml"), []byte("Item {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(omarchyPath, "themes"), 0o755); err != nil {
		t.Fatal(err)
	}

	current := filepath.Join(home, ".local/state/omarchy/current")
	candidate := filepath.Join(home, ".config/omarchy/themes/candidate")
	for _, root := range []string{
		filepath.Join(current, "theme/backgrounds"),
		filepath.Join(candidate, "backgrounds"),
	} {
		if err := os.MkdirAll(root, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	for _, root := range []string{filepath.Join(current, "theme"), candidate} {
		if err := os.WriteFile(filepath.Join(root, "colors.toml"), []byte("[colors]\nprimary = '#ffffff'\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(root, "shell.toml"), []byte("[bar]\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(current, "theme/backgrounds/bg.png"), []byte("old-background"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds/bg.png"), []byte("new-background"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(current, "theme/backgrounds/bg.png"), filepath.Join(current, "background")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	writeCommand := func(name, body string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(commandBin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	writeCommand("omarchy-theme-set-templates", "exit 0")
	writeCommand("omarchy-shell", "printf '%s\\n' \"$@\" >> \"$HOME/commands.log\"")

	_, currentFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test source path")
	}
	driver := filepath.Join(filepath.Dir(currentFile), "../../../bin/studio-theme-set")
	started := time.Now()
	output, err := exec.Command(driver, "preview", "candidate", "--no-hooks", "--scope", "theme,shell,background", "--wait", "none", "--run", "none").CombinedOutput()
	if err != nil {
		t.Fatalf("studio-theme-set preview: %v: %s", err, output)
	}
	if elapsed := time.Since(started); elapsed >= 400*time.Millisecond {
		t.Fatalf("unchanged-background preview took %v", elapsed)
	}
	commands, err := os.ReadFile(filepath.Join(home, "commands.log"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(commands), "shell\napplyTheme\n") {
		t.Fatalf("preview did not use direct shell theme apply: %q", commands)
	}
	if !strings.Contains(string(commands), "background\nsetInstant\n") {
		t.Fatalf("preview did not use instant background handoff: %q", commands)
	}
	if strings.Contains(string(commands), "background\nthemeTransition\n") {
		t.Fatalf("preview started an unchanged-background transition: %q", commands)
	}
}

func TestApplyThemeSkipsCacheWarmupsAndCleansShims(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	tmp := t.TempDir()
	t.Setenv("TMPDIR", tmp)
	bin := t.TempDir()
	contents := "#!/bin/sh\nif [ \"$2\" = \"set\" ]; then printf '%s\\n' \"$3\" > \"$HOME/.local/state/omarchy/current/theme.name\"; omarchy-theme-switcher; omarchy-theme-bg-cache; /usr/bin/sleep 0.15; printf done > \"$HOME/theme-set-finished\"; fi\n"
	if err := os.WriteFile(filepath.Join(bin, "omarchy"), []byte(contents), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, command := range cacheWarmupCommands {
		path := filepath.Join(bin, command)
		if err := os.WriteFile(path, []byte("#!/bin/sh\nprintf ran > \"$HOME/cache-warmup-ran\"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin)
	current := filepath.Join(home, ".local/state/omarchy/current")
	if err := os.MkdirAll(current, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(current, "theme.name"), []byte("old\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	started := time.Now()
	if err := NewClient(nil).ApplyTheme("new", filepath.Join(t.TempDir(), "apply.log")); err != nil {
		t.Fatal(err)
	}
	if elapsed := time.Since(started); elapsed < 100*time.Millisecond {
		t.Fatalf("ApplyTheme returned before theme-set completion: %v", elapsed)
	}
	if _, err := os.Stat(filepath.Join(home, "theme-set-finished")); err != nil {
		t.Fatalf("ApplyTheme returned before theme-set wrote its completion marker: %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, "cache-warmup-ran")); !os.IsNotExist(err) {
		t.Fatalf("cache warmup command ran, err=%v", err)
	}
	entries, err := os.ReadDir(tmp)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("cache warmup shim directory still exists: %v", entries)
	}
}

func TestTerminalReloadSyncCanBeConsumedByDemo(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	bin := t.TempDir()
	realCommand := filepath.Join(bin, "omarchy-restart-terminal")
	if err := os.WriteFile(realCommand, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, command := range cacheWarmupCommands {
		path := filepath.Join(bin, command)
		if err := os.WriteFile(path, []byte("#!/bin/sh\nprintf 'executed' > \"$HOME/preview-cache-command-ran\"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin)

	sessionDir := t.TempDir()
	previewLogs := filepath.Join(sessionDir, "preview-logs")
	if err := os.MkdirAll(previewLogs, 0o755); err != nil {
		t.Fatal(err)
	}
	sync, err := newTerminalReloadSync(filepath.Join(previewLogs, "preview.log"))
	if err != nil {
		t.Fatal(err)
	}
	defer sync.close()
	shimDirectory := sync.directory

	cmd := exec.Command("/bin/bash", "-lc", "omarchy-restart-terminal")
	cmd.Env = append(os.Environ(), sync.environment()...)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("run shim: %v: %s", err, output)
	}
	if err := sync.persist(); err != nil {
		t.Fatal(err)
	}
	for _, command := range cacheWarmupCommands {
		cmd := exec.Command("/bin/bash", "-lc", command)
		cmd.Env = append(os.Environ(), sync.environment()...)
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("run preview cache shim %s: %v: %s", command, err, output)
		}
	}
	if _, err := os.Stat(filepath.Join(home, "preview-cache-command-ran")); !os.IsNotExist(err) {
		t.Fatalf("preview cache command ran, err=%v", err)
	}
	if err := WaitForPendingTerminalReload(sessionDir); err != nil {
		t.Fatalf("wait for demo: %v", err)
	}
	if _, err := os.Stat(filepath.Join(previewLogs, terminalReloadPendingFile)); !os.IsNotExist(err) {
		t.Fatalf("pending marker still exists, err=%v", err)
	}
	if _, err := os.Stat(shimDirectory); !os.IsNotExist(err) {
		t.Fatalf("preview shim directory still exists, err=%v", err)
	}
}

func TestTerminalReloadSyncCloseCleansPendingMarkerAndShims(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "omarchy-restart-terminal"), []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)

	previewLogs := filepath.Join(t.TempDir(), "preview-logs")
	if err := os.MkdirAll(previewLogs, 0o755); err != nil {
		t.Fatal(err)
	}
	sync, err := newTerminalReloadSync(filepath.Join(previewLogs, "preview.log"))
	if err != nil {
		t.Fatal(err)
	}
	if err := sync.persist(); err != nil {
		t.Fatal(err)
	}
	if err := sync.close(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(previewLogs, terminalReloadPendingFile)); !os.IsNotExist(err) {
		t.Fatalf("pending marker still exists after close, err=%v", err)
	}
	if _, err := os.Stat(sync.directory); !os.IsNotExist(err) {
		t.Fatalf("preview shim directory still exists after close, err=%v", err)
	}
}

func TestNewTerminalReloadSyncRemovesOrphanedShimDirectories(t *testing.T) {
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "omarchy-restart-terminal"), []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)

	previewLogs := filepath.Join(t.TempDir(), "preview-logs")
	if err := os.MkdirAll(filepath.Join(previewLogs, ".terminal-reload-orphan"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(previewLogs, ".terminal-reload-orphan", "omarchy-theme-bg-cache"), []byte("stale"), 0o644); err != nil {
		t.Fatal(err)
	}
	sync, err := newTerminalReloadSync(filepath.Join(previewLogs, "preview.log"))
	if err != nil {
		t.Fatal(err)
	}
	defer sync.close()
	if _, err := os.Stat(filepath.Join(previewLogs, ".terminal-reload-orphan")); !os.IsNotExist(err) {
		t.Fatalf("orphaned shim directory still exists, err=%v", err)
	}
}
