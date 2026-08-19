package omarchy

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

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
	if err := os.WriteFile(filepath.Join(current, "theme.name"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := c.CurrentTheme(); err == nil {
		t.Fatal("expected empty theme error")
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
	bin := t.TempDir()
	script := filepath.Join(bin, "omarchy")
	contents := "#!/bin/sh\nif [ \"$2\" = \"set\" ]; then printf '%s\\n' \"$3\" > \"$HOME/.local/state/omarchy/current/theme.name\"; else exit 0; fi\n"
	if err := os.WriteFile(script, []byte(contents), 0o755); err != nil {
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
}
