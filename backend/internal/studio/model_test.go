package studio

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

func TestLoadPaletteUsesThemeValuesAndFallbacks(t *testing.T) {
	path := filepath.Join(t.TempDir(), "colors.toml")
	if err := os.WriteFile(path, []byte("accent = \"#ABCDEF\"\nred = \"#123456\"\ninvalid = \"not-a-color\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	palette := LoadPalette(path)
	if palette["accent"] != "#abcdef" || palette["red"] != "#123456" {
		t.Fatalf("palette values = %#v", palette)
	}
	if palette["foreground"] != paletteFallbacks["foreground"] {
		t.Fatalf("foreground fallback = %q", palette["foreground"])
	}
}

func TestRenderIsCenteredAndResponsive(t *testing.T) {
	model := NewModelFromCurrentTheme()
	for _, size := range []struct{ width, height int }{{60, 24}, {80, 30}, {120, 40}, {160, 48}} {
		model.width, model.height = size.width, size.height
		output := model.render()
		for _, line := range strings.Split(output, "\n") {
			if got := lipgloss.Width(line); got > size.width {
				t.Fatalf("size %dx%d line width=%d: %q", size.width, size.height, got, line)
			}
		}
		plain := ansi.Strip(output)
		if strings.Contains(plain, "╭") || strings.Contains(plain, "╮") || strings.Contains(plain, "╰") || strings.Contains(plain, "╯") {
			t.Fatalf("size %dx%d still renders an inner container: %q", size.width, size.height, output)
		}
		if (!strings.Contains(plain, "OMAGEN") && !strings.Contains(plain, "██████")) ||
			(!strings.Contains(plain, "STUDIO") && !strings.Contains(plain, "███████")) ||
			!strings.Contains(plain, "> COLORS <") {
			t.Fatalf("size %dx%d missing branded content: %q", size.width, size.height, output)
		}
	}
}

func TestUpdateResizesAndQuits(t *testing.T) {
	model := NewModelFromCurrentTheme()
	updated, command := model.Update(tea.WindowSizeMsg{Width: 91, Height: 37})
	if command != nil || updated.(Model).width != 91 || updated.(Model).height != 37 {
		t.Fatalf("resize update = %#v, command=%v", updated, command)
	}
	_, command = model.Update(tea.KeyPressMsg(tea.Key{Text: "q"}))
	if command == nil {
		t.Fatal("q did not return a quit command")
	}
}

func TestUpdateReloadsPaletteWhenPreviewFileChanges(t *testing.T) {
	path := filepath.Join(t.TempDir(), "colors.toml")
	if err := os.WriteFile(path, []byte("accent = \"#111111\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	model := NewModelAtPath(LoadPalette(path), path)
	if model.palette["accent"] != "#111111" {
		t.Fatalf("initial accent = %q", model.palette["accent"])
	}
	if err := os.WriteFile(path, []byte("accent = \"#abcdef\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	updated, command := model.Update(palettePollMsg{path: path, palette: LoadPalette(path), signature: "changed"})
	if command == nil {
		t.Fatal("palette poll did not schedule the next poll")
	}
	if updated.(Model).palette["accent"] != "#abcdef" {
		t.Fatalf("reloaded accent = %q", updated.(Model).palette["accent"])
	}
}
