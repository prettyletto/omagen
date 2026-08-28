package theme

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/bar"
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
	if luac, err := exec.LookPath("luac"); err == nil {
		if output, err := exec.Command(luac, "-p", filepath.Join(dir, "hyprland.lua")).CombinedOutput(); err != nil {
			t.Fatalf("generated Cyberpunk Glitch Lua is invalid: %v\n%s", err, output)
		}
	}
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

func TestWriteHyprlandActiveBlurWinsOverStrongerInactiveBlurAndPreservesAnimations(t *testing.T) {
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
		"blur = { enabled = true, size = 10, passes = 2, ignore_opacity = true, new_optimizations = true }",
		`hl.animation({ leaf = "windows", enabled = true, speed = 5.5, bezier = "quick" })`,
		`hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("generated split window/animation config missing %q:\n%s", want, text)
		}
	}
	if strings.Contains(text, "blur = { enabled = true, size = 24, passes = 4") {
		t.Fatal("stronger inactive blur must not strengthen the frosted active window")
	}
}

func TestWriteHyprlandGlassPresetAddsSubtleTranslucency(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", Accent: "#aa33cc"}
	if err := WriteHyprlandWithAnimationsAndShell(dir, p, "solid", 2, "rounded", "airy", "shadow", "frosted_light", "frosted_light", 36, session.DefaultAnimationsStyle(), session.ShellPresetGlass); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		"active_opacity = 0.72",
		"inactive_opacity = 0.72",
		"blur = { enabled = true, size = 10, passes = 2, ignore_opacity = true, new_optimizations = true }",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("Glass preset output missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandScopesBarGlassBlurToBothBarOwners(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	spec := bar.Default()
	spec.Surface.Treatment = "glass"
	spec.Surface.Role = "background"
	spec.Surface.Opacity = 0.72
	spec.Surface.Blur = 1
	if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "native", "native", "native", "native", "native", 36, session.DefaultAnimationsStyle(), &spec); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`hl.layer_rule({ name = "omagen-native-bar-backdrop-blur"`,
		`namespace = "^omarchy-bar$"`,
		`hl.layer_rule({ name = "omagen-replacement-bar-backdrop-blur"`,
		`namespace = "^pretty-omagen-bar$"`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("bar glass layer rule missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandScopesShellGlassBlurToNativeSurfacesAndDemo(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	if err := WriteHyprlandWithAnimationsAndShell(dir, p, "solid", 2, "native", "native", "native", "native", "native", 36, session.DefaultAnimationsStyle(), session.ShellPresetGlass); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`omagen-shell-glass-backdrop-blur`,
		`namespace = "^((omarchy-(bar|menu|image-selector|emojis|clipboard|keyboard-panel|notifications|osd|polkit|lock-preview|network-qr|reminders))|omagen-shell-demo|omagen-live-canvas)$"`,
		`blur = true, blur_popups = true, ignore_alpha = 0.20`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("Shell Glass layer rule missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandDefaultDoesNotAddShellGlassBlur(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	if err := WriteHyprlandWithAnimationsAndShell(dir, p, "solid", 2, "native", "native", "native", "native", "native", 36, session.DefaultAnimationsStyle(), session.ShellPresetDefault); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "omagen-shell-glass-backdrop-blur") {
		t.Fatal("Default Shell preset must not add a compositor blur rule")
	}
}

func TestWriteHyprlandCompilesMotionLabDocument(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	animations := session.MotionPreset("spring")
	animations.WindowAmount = 78
	animations.WorkspaceAxis = "vertical"
	animations.WorkspaceTravel = 22
	animations.Special = "fade"
	if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "native", "native", "native", "native", "native", 36, animations); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`hl.curve("omagenSpring", { type = "spring", mass = 1, stiffness = 85, dampening = 17 })`,
		`style = "popin 78%"`,
		`hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "omagenSpring" })`,
		`style = "slidefadevert 22%"`,
		`hl.animation({ leaf = "specialWorkspace", enabled = true`,
		`hl.animation({ leaf = "fadeSwitch", enabled = true`,
		`hl.animation({ leaf = "layersIn", enabled = true`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("Motion Lab output missing %q:\n%s", want, text)
		}
	}
}

func TestWriteHyprlandCompilesDistinctLookFeelMotionIdentities(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#72767d", DarkerBackground: "#050607", Accent: "#aa33cc", Blue: "#4488dd", Magenta: "#cc55ee"}
	tests := []struct {
		name   string
		motion string
		wants  []string
	}{
		{
			name:   "glass",
			motion: "smooth",
			wants: []string{
				`hl.curve("omagenGlass"`,
				`leaf = "windowsIn", enabled = true, speed = 4, bezier = "omagenGlass", style = "popin 82%"`,
				`leaf = "workspaces", enabled = true, speed = 3.8, bezier = "omagenGlass", style = "slidefade 22%"`,
				`leaf = "fadeSwitch", enabled = true, speed = 2.6, bezier = "omagenGlass"`,
			},
		},
		{
			name:   "focused",
			motion: "snappy",
			wants: []string{
				`hl.curve("omagenPrecision"`,
				`leaf = "windowsIn", enabled = true, speed = 1, bezier = "omagenPrecision", style = "popin 97%"`,
				`leaf = "workspaces", enabled = true, speed = 1.2, bezier = "omagenPrecision", style = "fade"`,
				`leaf = "windowsMove", enabled = true, speed = 1.2, bezier = "omagenPrecision"`,
			},
		},
		{
			name:   "cyberpunk",
			motion: "cyberpunk",
			wants: []string{
				`hl.curve("omagenDigital"`,
				`leaf = "windowsIn", enabled = true, speed = 2, bezier = "omagenDigital", style = "gnomed"`,
				`leaf = "windowsOut", enabled = true, speed = 1.1, bezier = "omagenDigital", style = "slide"`,
				`leaf = "border", enabled = true, speed = 0.7, bezier = "omagenDigital"`,
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			dir := t.TempDir()
			if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "rounded", "native", "shadow", "native", "shadow_only", 36, session.MotionPreset(test.motion)); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
			if err != nil {
				t.Fatal(err)
			}
			for _, want := range test.wants {
				if !strings.Contains(string(data), want) {
					t.Errorf("%s motion missing %q:\n%s", test.name, want, data)
				}
			}
		})
	}
}

func TestWriteHyprlandCompilesScopedCyberpunkSignal(t *testing.T) {
	dir := t.TempDir()
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#202030", DarkerBackground: "#050607", Accent: "#ff28d7", Blue: "#29d9ff", Magenta: "#ff28d7"}
	animations := session.MotionPreset("cyberpunk")
	if err := WriteHyprlandWithAnimations(dir, p, "neon", 4, "rounded", "native", "shadow", "native", "shadow_only", 28, animations); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{
		`hl.curve("omagenDigital", { type = "bezier", points = { { 0.05, 0.92 }, { 0.12, 1 } } })`,
		`hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "omagenDigital" })`,
		`hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "omagenDigital", style = "gnomed" })`,
		`hl.animation({ leaf = "fadeIn", enabled = false })`,
		`hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.1, bezier = "omagenDigital", style = "slide" })`,
		`hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.6, bezier = "omagenDigital" })`,
		`hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "omagenDigital", style = "slide 12%" })`,
		`hl.animation({ leaf = "border", enabled = true, speed = 0.7, bezier = "omagenDigital" })`,
		`hl.animation({ leaf = "layersIn", enabled = true, speed = 1.8, bezier = "omagenDigital", style = "slide" })`,
		`match = { tag = "omagen-materializing" }`,
		`opacity = "0.82 override 0.82 override 0.82 override"`,
		`hl.dispatch(hl.dsp.window.tag({ tag = "+omagen-materializing", window = selector }))`,
		`hl.dispatch(hl.dsp.window.tag({ tag = "-omagen-materializing", window = selector }))`,
		`hl.on("window.open", function(window) _omagen_window_opacity_handshake(window) end)`,
		`end, { timeout = 110, type = "repeat" })`,
		"Cyberpunk signal: event-triggered whole-desktop glitch, idle-off.",
		`local _omagen_glitch_flash_border = { colors = { "rgb(ff28d7)", "rgb(29d9ff)", "rgb(ff28d7)" }, angle = 90 }`,
		`local _omagen_glitch_shader = (os.getenv("HOME") or "") .. "/.local/state/omarchy/current/theme/omagen-cyberpunk-glitch.frag"`,
		`decoration = { screen_shader = _omagen_glitch_shader }`,
		`debug = { damage_tracking = 0 }`,
		`decoration = { screen_shader = _omagen_glitch_base_screen_shader }`,
		`debug = { damage_tracking = _omagen_glitch_base_damage_tracking }`,
		`hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "linear", style = "loop" })`,
		`hl.animation({ leaf = "borderangle", enabled = false })`,
		`_omagen_glitch_timer:set_enabled(false)`,
		`_omagen_glitch_timer:set_enabled(true)`,
		`if _omagen_glitch_cleanup then _omagen_glitch_cleanup() end`,
		`hl.on("window.open", function() _omagen_glitch_burst() end)`,
		`hl.on("window.close", function() _omagen_glitch_burst() end)`,
		`hl.on("window.urgent", function() _omagen_glitch_burst() end)`,
		`hl.on("workspace.active", function() _omagen_glitch_burst() end)`,
		`hl.on("layer.opened", function(layer) if _omagen_native_shell_signal(layer) then _omagen_glitch_burst() end end)`,
		`["omagen-notification-signal"] = true`,
		`string.find(namespace, "omagen-notification-signal-", 1, true) == 1`,
		`["omagen-background-signal"] = true`,
		`string.find(namespace, "omagen-background-signal-", 1, true) == 1`,
		`hl.layer_rule({ name = "omagen-cyberpunk-native-shell-motion", match = { namespace = "^omarchy-(menu|image-selector|emojis|clipboard|keyboard-panel|notifications|osd|polkit|network-qr|reminders|lock-preview)$" }, no_anim = false, animation = "slide" })`,
		`end, { timeout = 1250, type = "repeat" })`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("Cyberpunk Glitch output missing %q:\n%s", want, text)
		}
	}
	if strings.Contains(text, "_omagen_border_angle_timer = hl.timer") {
		t.Fatal("Cyberpunk signal should not add a continuous border spinner")
	}
	for _, unwanted := range []string{"window.active", "layer.closed", "paths.state_home", `animation = "slidefade" })`} {
		if strings.Contains(text, unwanted) {
			t.Fatalf("Cyberpunk signal must not emit %q:\n%s", unwanted, text)
		}
	}
	shader, err := os.ReadFile(filepath.Join(dir, "omagen-cyberpunk-glitch.frag"))
	if err != nil {
		t.Fatalf("Cyberpunk signal should generate a whole-screen shader: %v", err)
	}
	for _, want := range []string{"#version 300 es", "uniform sampler2D tex;", "uniform float time;", "float pulse", "step(0.68, noise)", "tear * 0.010", "vec2(0.0041 * pulse", "0.78 * pulse", "0.020 * sin"} {
		if !strings.Contains(string(shader), want) {
			t.Errorf("Cyberpunk shader missing %q:\n%s", want, shader)
		}
	}
	if strings.Contains(string(shader), "__OMAGEN_") {
		t.Fatalf("Cyberpunk shader still contains template markers:\n%s", shader)
	}
	if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "native", "native", "native", "native", "native", 36, session.MotionPreset("native")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "omagen-cyberpunk-glitch.frag")); !os.IsNotExist(err) {
		t.Fatalf("theme regeneration should remove the legacy glitch shader, stat err=%v", err)
	}
}

func TestWriteHyprlandBuildsDistinctRGBTearStrengths(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#202030", DarkerBackground: "#050607", Accent: "#ff28d7", Blue: "#29d9ff", Magenta: "#ff28d7"}
	profiles := []struct {
		level string
		want  string
	}{
		{level: "low", want: "tear * 0.006"},
		{level: "medium", want: "tear * 0.010"},
		{level: "strong", want: "tear * 0.014"},
	}
	for _, profile := range profiles {
		t.Run(profile.level, func(t *testing.T) {
			dir := t.TempDir()
			animations := session.MotionPreset("cyberpunk")
			animations.Glitch = profile.level
			if err := WriteHyprlandWithAnimations(dir, p, "neon", 4, "rounded", "native", "shadow", "native", "shadow_only", 28, animations); err != nil {
				t.Fatal(err)
			}
			shader, err := os.ReadFile(filepath.Join(dir, "omagen-cyberpunk-glitch.frag"))
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(shader), profile.want) {
				t.Fatalf("%s RGB tear missing %q:\n%s", profile.level, profile.want, shader)
			}
		})
	}
}

func TestWriteHyprlandBuildsFiniteAlternativeScreenEffects(t *testing.T) {
	p := Palette{Foreground: "#e5e7eb", DarkForeground: "#202030", DarkerBackground: "#050607", Accent: "#7bcf8e", Blue: "#62aee8", Magenta: "#c889d6"}
	tests := []struct {
		name, id, file string
		duration       int
		shaderWants    []string
		luaWants       []string
	}{
		{name: "spectral", id: "spectral-shift", file: "omagen-spectral-shift.frag", duration: 500,
			shaderWants: []string{"time / 0.500", "0.0032 * envelope", "0.65 * envelope"},
			luaWants:    []string{"finite event signal, idle-off", "omagen-spectral-shift.frag", "timeout = 500", `hl.on("workspace.active"`}},
		{name: "phosphor", id: "phosphor-scan", file: "omagen-phosphor-scan.frag", duration: 850,
			shaderWants: []string{"time / 0.850", "0.0024 * syncBand", "0.026 * envelope", "0.055 * envelope"},
			luaWants:    []string{"omagen-phosphor-scan.frag", "timeout = 850", `hl.on("window.urgent"`, "_omagen_screen_effect_layers", `string.find(namespace, "omagen-background-signal-", 1, true) == 1`}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			dir := t.TempDir()
			motion := session.MotionPreset("minimal")
			motion.ScreenEffect = &session.ScreenEffect{ID: test.id, Strength: "medium", DurationMs: test.duration, Triggers: []string{"window-open", "window-close", "workspace", "panel", "notification", "urgent"}, Coalesce: true}
			if err := WriteHyprlandWithAnimations(dir, p, "solid", 2, "soft", "native", "shadow", "native", "shadow_only", 36, motion); err != nil {
				t.Fatal(err)
			}
			shader, err := os.ReadFile(filepath.Join(dir, test.file))
			if err != nil {
				t.Fatal(err)
			}
			for _, want := range test.shaderWants {
				if !strings.Contains(string(shader), want) {
					t.Errorf("shader missing %q:\n%s", want, shader)
				}
			}
			lua, err := os.ReadFile(filepath.Join(dir, "hyprland.lua"))
			if err != nil {
				t.Fatal(err)
			}
			for _, want := range test.luaWants {
				if !strings.Contains(string(lua), want) {
					t.Errorf("Lua missing %q:\n%s", want, lua)
				}
			}
			if strings.Contains(string(lua), "_omagen_glitch_flash_border") || strings.Contains(string(lua), `leaf = "borderangle", enabled = true`) {
				t.Fatalf("alternative screen effect inherited Cyberpunk border behavior:\n%s", lua)
			}
		})
	}
}
