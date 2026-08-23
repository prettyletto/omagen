package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/session"
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
	if err := WriteHyprland(dir, p, "solid", -1, "native", "native", "native", "native"); err != nil {
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

func TestWriteHyprlandCanRemoveBorderExplicitly(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc"}
	if err := WriteHyprland(dir, p, "solid", 0, "native", "native", "native", "native"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "border_size = 0") {
		t.Fatalf("explicit border removal was not written:\n%s", data)
	}
}

func TestWriteHyprlandMapsFiveShapePresets(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc"}
	for _, style := range []struct {
		name string
		want string
	}{
		{name: "native", want: ""},
		{name: "subtle", want: "rounding = 2, rounding_power = 3"},
		{name: "soft", want: "rounding = 4, rounding_power = 3"},
		{name: "rounded", want: "rounding = 8, rounding_power = 3"},
		{name: "pill", want: "rounding = 16, rounding_power = 3"},
	} {
		t.Run(style.name, func(t *testing.T) {
			dir := t.TempDir()
			if err := WriteHyprland(dir, p, "solid", 0, style.name, "native", "native", "native"); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
			if err != nil {
				t.Fatal(err)
			}
			text := string(data)
			if style.want == "" {
				if strings.Contains(text, "rounding =") {
					t.Fatalf("native shape unexpectedly overrides rounding:\n%s", text)
				}
				return
			}
			if !strings.Contains(text, style.want) {
				t.Fatalf("shape preset missing %q:\n%s", style.want, text)
			}
		})
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

func TestWriteHyprlandUsesConfiguredSpinSpeed(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	if err := WriteHyprland(dir, p, "spin", 2, "native", "native", "native", "native", 48); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`hl.animation({ leaf = "borderangle", enabled = true, speed = 48, bezier = "linear", style = "loop" })`,
		`_omagen_border_angle = (_omagen_border_angle + 7.5000) % 360`,
		`timeout = 100, type = "repeat"`,
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
		{name: "shadow_only", want: []string{"color_inactive = \"rgba(05060788)\""}},
		{name: "frosted_light", want: []string{"dim_inactive = true, dim_strength = 0.12", "blur = { enabled = true, size = 10, passes = 2, ignore_opacity = true, new_optimizations = true }", "hl.layer_rule({ name = \"omagen-live-canvas-backdrop-blur\", match = { namespace = \"^omagen-live-canvas$\" }, blur = true, blur_popups = true, ignore_alpha = 0.20 })"}},
		{name: "frosted_balanced", want: []string{"dim_inactive = true, dim_strength = 0.26", "blur = { enabled = true, size = 18, passes = 3, ignore_opacity = true, new_optimizations = true }"}},
		{name: "frosted_rich", want: []string{"dim_inactive = true, dim_strength = 0.34", "blur = { enabled = true, size = 24, passes = 4, ignore_opacity = true, new_optimizations = true }"}},
		{name: "blur", want: []string{"dim_inactive = true, dim_strength = 0.26", "blur = { enabled = true, size = 18, passes = 3, ignore_opacity = true, new_optimizations = true }"}},
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

	dir := t.TempDir()
	if err := WriteHyprland(dir, p, "solid", 2, "native", "native", "native", "shadow_only"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "dim_inactive = true") {
		t.Fatal("shadow_only must not dim inactive windows")
	}
	if strings.Contains(string(data), "inactive_opacity =") {
		t.Fatal("shadow_only must preserve the existing inactive opacity policy")
	}

	dir = t.TempDir()
	if err := WriteHyprland(dir, p, "solid", 2, "native", "native", "native", "native"); err != nil {
		t.Fatal(err)
	}
	data, err = os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "omagen-live-canvas-backdrop-blur") {
		t.Fatal("native inactive style must not install the Live Canvas blur layer rule")
	}
}

func TestWriteHyprlandSeparatesActiveInactiveBlurAndAnimations(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	animations := session.AnimationsStyle{Window: "snappy", Workspace: "smooth", Border: "static", BorderSpeed: 48}
	if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "native", "native", "native", "frosted_light", "frosted_rich", 48, animations); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		"dim_inactive = true, dim_strength = 0.34",
		"blur = { enabled = true, size = 24, passes = 4, ignore_opacity = true, new_optimizations = true }",
		`hl.animation({ leaf = "windows", enabled = true, speed = 5.5, bezier = "quick" })`,
		`hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("generated split window/animation config missing %q:\n%s", want, text)
		}
	}
}
