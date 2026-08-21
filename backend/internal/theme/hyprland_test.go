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
	if err := WriteHyprland(dir, p, "blend", 4, "rounded", "airy", "shadow", "native"); err != nil {
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
		"border_size = 4",
		"rounding = 8, rounding_power = 3",
		"shadow = { enabled = true, render_power = 3, range = 18, color = \"rgba(050607e6)\", color_inactive = \"rgba(050607b8)\" }",
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
			if err := WriteHyprland(dir, p, style.name, 0, "native", "native", "native", "native"); err != nil {
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

func TestWriteHyprlandLeavesNativeBorderSizeUnchanged(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc"}
	if err := WriteHyprland(dir, p, "solid", 0, "native", "native", "native", "native"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "border_size =") {
		t.Fatalf("native border size must not override Omarchy's value:\n%s", data)
	}
}

func TestWriteHyprlandSpinsAccentGradient(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	if err := WriteHyprland(dir, p, "spin", 2, "native", "native", "native", "native"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`colors = { "rgb(aa33cc)", "rgb(4488dd)", "rgb(cc55ee)", "rgb(aa33cc)" }, angle = 0`,
		`hl.animation({ leaf = "borderangle", enabled = true, speed = 36, bezier = "linear", style = "loop" })`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("generated spinning hyprland.lua missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandNeonAddsFocusedWindowGlow(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc", Magenta: "#cc55ee"}
	if err := WriteHyprland(dir, p, "neon", 2, "native", "native", "native", "native"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`local active_glow_color = "rgba(aa33ccd0)"`,
		`shadow = { enabled = true, render_power = 3, range = 24, color = active_shadow_color, color_inactive = inactive_shadow_color }`,
		`glow = { enabled = true, range = 16, render_power = 3, color = active_glow_color, color_inactive = inactive_glow_color }`,
		`hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "loop" })`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("generated neon hyprland.lua missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandInactiveModes(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc"}
	for _, style := range []struct {
		name string
		want []string
	}{
		{name: "shadow", want: []string{"dim_inactive = true, dim_strength = 0.32", "color_inactive = \"rgba(050607d0)\""}},
		{name: "blur", want: []string{"inactive_opacity = 0.58, dim_inactive = true, dim_strength = 0.62", "blur = { enabled = true, size = 16, passes = 3, ignore_opacity = false, new_optimizations = true }"}},
	} {
		t.Run(style.name, func(t *testing.T) {
			dir := t.TempDir()
			if err := WriteHyprland(dir, p, "solid", 2, "native", "native", "native", style.name); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
			if err != nil {
				t.Fatal(err)
			}
			text := string(data)
			for _, want := range style.want {
				if !strings.Contains(text, want) {
					t.Errorf("generated inactive %s style missing %q:\n%s", style.name, want, text)
				}
			}
		})
	}
}
