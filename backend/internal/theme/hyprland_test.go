package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteHyprlandMapsWindowControlsToHyprland(t *testing.T) {
	dir := t.TempDir()
	p := Palette{
		Background:       "#101112",
		Foreground:       "#e5e7eb",
		DarkForeground:   "#72767d",
		DarkerBackground: "#050607",
		Accent:           "#aa33cc",
		Blue:             "#4488dd",
		Magenta:          "#cc55ee",
	}
	if err := WriteHyprland(dir, p, "blend", "rounded", "airy", "shadow"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`colors = { "rgb(aa33cc)", "rgb(4488dd)" }, angle = 135`,
		"gaps_in = 8, gaps_out = 14",
		"rounding = 8, rounding_power = 3",
		"shadow = { enabled = true, render_power = 3, range = 18, color = \"rgba(050607e6)\" }",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("generated hyprland.lua missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandUsesTopAndBottomGradientDirections(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc"}
	for _, style := range []struct {
		name string
		want string
	}{
		{name: "split_top", want: `colors = { "rgb(aa33cc)", "rgb(e5e7eb)" }, angle = 90`},
		{name: "split_bottom", want: `colors = { "rgb(e5e7eb)", "rgb(aa33cc)" }, angle = 90`},
	} {
		t.Run(style.name, func(t *testing.T) {
			dir := t.TempDir()
			if err := WriteHyprland(dir, p, style.name, "native", "native", "native"); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(data), style.want) {
				t.Errorf("generated hyprland.lua missing %q:\n%s", style.want, data)
			}
		})
	}
}
