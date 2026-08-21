package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteShellEmitsSurfaceAndDetailOverrides(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "layered", "edge", "light", "comfortable", "accent"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{"[bar]", `background = "#222426"`, "size-horizontal = 30", "size-vertical = 32", `active = "#aa33cc"`, "[menu]", `selected-background = "#334455"`, `selected-border-width = "0 0 0 3"`} {
		if !strings.Contains(text, want) {
			t.Errorf("generated shell.toml missing %q:\n%s", want, text)
		}
	}
	if strings.Count(text, "[controls]") != 1 {
		t.Fatalf("expected one controls table:\n%s", text)
	}
	if strings.Count(text, "[bar]") != 1 {
		t.Fatalf("expected one bar table:\n%s", text)
	}
	if _, err := os.Stat(filepath.Join(dir, "shell.bar.toml")); !os.IsNotExist(err) {
		t.Fatalf("unexpected shell.bar.toml sidecar: %v", err)
	}

	if err := WriteShell(dir, p, "flat", "native", "native", "native", "semantic"); err != nil {
		t.Fatal(err)
	}
	data, err = os.ReadFile(filepath.Join(dir, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "[bar]") || strings.Contains(string(data), "[popups]") {
		t.Fatalf("native shell style emitted unexpected overrides:\n%s", data)
	}
}

func TestWriteShellUsesActualAccentForBarSurface(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Background: "#101112", DarkBackground: "#08090a", DarkerBackground: "#050607", LighterBackground: "#222426", Selection: "#334455", Accent: "#aa33cc"}
	if err := WriteShell(dir, p, "flat", "native", "accent", "compact", "semantic"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{`background = "#aa33cc"`, "size-horizontal = 22", "size-vertical = 24"} {
		if !strings.Contains(text, want) {
			t.Errorf("generated shell.toml missing %q:\n%s", want, text)
		}
	}
}
