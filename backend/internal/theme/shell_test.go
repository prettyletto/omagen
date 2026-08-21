package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func readShellSection(t *testing.T, dir, section string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(dir, "shell."+section+".toml"))
	if err != nil {
		t.Fatalf("read shell.%s.toml: %v", section, err)
	}
	text := string(data)
	if strings.Contains(text, "["+section+"]") {
		t.Fatalf("shell.%s.toml should be a headerless sidecar:\n%s", section, text)
	}
	return text
}

func assertNoRootShell(t *testing.T, dir string) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(dir, "shell.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected generated root shell.toml: %v", err)
	}
}

func assertNoShellOutputs(t *testing.T, dir string) {
	t.Helper()
	for _, name := range generatedShellFiles {
		if _, err := os.Stat(filepath.Join(dir, name)); !os.IsNotExist(err) {
			t.Fatalf("unexpected generated shell output %s: %v", name, err)
		}
	}
}

func TestWriteShellEmitsSurfaceAndDetailOverrides(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "layered", "edge", "light", "comfortable", "accent", "continuous"); err != nil {
		t.Fatal(err)
	}
	assertNoRootShell(t, dir)

	for section, wants := range map[string][]string{
		"bar":      {`background = "#e5e7eb"`, `text = "#101112"`, "size-horizontal = 30", "size-vertical = 32", `active = "#aa33cc"`},
		"popups":   {`background = "#08090a"`},
		"menu":     {`selected-background = "#334455"`, `selected-border-width = "0 0 0 3"`},
		"launcher": {`selected-background = "#334455"`},
		"controls": {`normal-color = "#222426"`, `selected-color = "#334455"`},
	} {
		text := readShellSection(t, dir, section)
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "shell.notifications.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected notifications sidecar for layered edge style: %v", err)
	}

	if err := WriteShell(dir, p, "flat", "native", "native", "native", "semantic", "continuous"); err != nil {
		t.Fatal(err)
	}
	assertNoShellOutputs(t, dir)
}

func TestWriteShellUsesActualAccentForBarSurface(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "accent", "compact", "semantic", "continuous"); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{`background = "#aa33cc"`, `text = "#101112"`, "size-horizontal = 22", "size-vertical = 24"} {
		if !strings.Contains(text, want) {
			t.Errorf("shell.bar.toml missing %q:\n%s", want, text)
		}
	}
}

func TestWriteShellKeepsAccentSurfaceRestrained(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "accent", "focus", "native", "native", "semantic", "continuous"); err != nil {
		t.Fatal(err)
	}
	for section, wants := range map[string][]string{
		"menu":     {`selected-background = "#aa33cc"`, "selected-background-alpha = 0.18"},
		"launcher": {`selected-background = "#aa33cc"`, "selected-background-alpha = 0.18"},
		"controls": {`selected-border = "#aa33cc"`, "selected-fill-alpha = 0.18"},
	} {
		text := readShellSection(t, dir, section)
		for _, want := range wants {
			if !strings.Contains(text, want) {
				t.Errorf("shell.%s.toml missing %q:\n%s", section, want, text)
			}
		}
	}
}

func TestWriteShellEmitsDockedBarFormWithoutChangingOtherBarOptions(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", Foreground: "#e5e7eb", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "dark", "comfortable", "semantic", "docked"); err != nil {
		t.Fatal(err)
	}
	text := readShellSection(t, dir, "bar")
	for _, want := range []string{`form = "docked"`, "background-alpha = 0.0", `background = "#08090a"`, `text = "#e5e7eb"`, "size-horizontal = 30", "size-vertical = 32"} {
		if !strings.Contains(text, want) {
			t.Errorf("shell.bar.toml missing %q:\n%s", want, text)
		}
	}
}
