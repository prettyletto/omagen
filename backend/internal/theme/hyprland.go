package theme

import (
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

//go:embed cyberpunk_glitch.frag
var cyberpunkGlitchShader string

//go:embed spectral_shift.frag
var spectralShiftShader string

//go:embed phosphor_scan.frag
var phosphorScanShader string

// Keep the signal long enough to be visible while leaving the shader fully
// disabled between compositor events.
const cyberpunkGlitchDurationMs = 1250

// removeCyberpunkGlitchShader removes the generated event shader whenever a
// theme is regenerated without the Cyberpunk signal. This also cleans up the
// same filename emitted by the earlier experimental implementation.
func removeScreenEffectShaders(themeDir string) error {
	for _, name := range []string{"omagen-cyberpunk-glitch.frag", "omagen-spectral-shift.frag", "omagen-phosphor-scan.frag"} {
		err := fsutil.RemoveFileAndSync(filepath.Join(themeDir, name))
		if err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

type cyberpunkGlitchProfile struct {
	tearThreshold string
	tearDistance  string
	chroma        string
	mix           string
	scanline      string
}

func cyberpunkGlitchProfileFor(level string) cyberpunkGlitchProfile {
	switch level {
	case "low":
		return cyberpunkGlitchProfile{"0.78", "0.006", "0.0024", "0.48", "0.012"}
	case "strong":
		return cyberpunkGlitchProfile{"0.58", "0.014", "0.0062", "0.96", "0.030"}
	default:
		// Medium is exactly the original curated Cyberpunk treatment.
		return cyberpunkGlitchProfile{"0.68", "0.010", "0.0041", "0.78", "0.020"}
	}
}

func cyberpunkGlitchEnabled(level string) bool {
	return level == "low" || level == "medium" || level == "strong"
}

func renderCyberpunkGlitchShader(level string) string {
	profile := cyberpunkGlitchProfileFor(level)
	replacer := strings.NewReplacer(
		"__OMAGEN_TEAR_THRESHOLD__", profile.tearThreshold,
		"__OMAGEN_TEAR_DISTANCE__", profile.tearDistance,
		"__OMAGEN_CHROMA_DISTANCE__", profile.chroma,
		"__OMAGEN_CHROMA_MIX__", profile.mix,
		"__OMAGEN_SCANLINE__", profile.scanline,
	)
	return replacer.Replace(cyberpunkGlitchShader)
}

func writeCyberpunkGlitchShader(themeDir, level string) error {
	return fsutil.AtomicWriteFile(filepath.Join(themeDir, "omagen-cyberpunk-glitch.frag"), []byte(renderCyberpunkGlitchShader(level)), 0o644)
}

func renderSpectralShiftShader(effect session.ScreenEffect) string {
	offset, mix := "0.0032", "0.65"
	switch effect.Strength {
	case "low":
		offset, mix = "0.0018", "0.45"
	case "strong":
		offset, mix = "0.0050", "0.82"
	}
	return strings.NewReplacer(
		"__OMAGEN_DURATION_SECONDS__", fmt.Sprintf("%.3f", float64(effect.DurationMs)/1000),
		"__OMAGEN_SPECTRAL_OFFSET__", offset,
		"__OMAGEN_SPECTRAL_MIX__", mix,
	).Replace(spectralShiftShader)
}

func renderPhosphorScanShader(effect session.ScreenEffect) string {
	syncOffset, scanline, phosphor := "0.0024", "0.026", "0.055"
	switch effect.Strength {
	case "low":
		syncOffset, scanline, phosphor = "0.0012", "0.014", "0.030"
	case "strong":
		syncOffset, scanline, phosphor = "0.0042", "0.042", "0.085"
	}
	return strings.NewReplacer(
		"__OMAGEN_DURATION_SECONDS__", fmt.Sprintf("%.3f", float64(effect.DurationMs)/1000),
		"__OMAGEN_SYNC_OFFSET__", syncOffset,
		"__OMAGEN_SCANLINE__", scanline,
		"__OMAGEN_PHOSPHOR__", phosphor,
	).Replace(phosphorScanShader)
}

func writeScreenEffectShader(themeDir string, effect session.ScreenEffect) (string, error) {
	effect = effect.Normalize()
	var name, source string
	switch effect.ID {
	case "rgb-tear":
		name, source = "omagen-cyberpunk-glitch.frag", renderCyberpunkGlitchShader(effect.Strength)
	case "spectral-shift":
		name, source = "omagen-spectral-shift.frag", renderSpectralShiftShader(effect)
	case "phosphor-scan":
		name, source = "omagen-phosphor-scan.frag", renderPhosphorScanShader(effect)
	default:
		return "", nil
	}
	return name, fsutil.AtomicWriteFile(filepath.Join(themeDir, name), []byte(source), 0o644)
}

// WriteHyprland preserves the existing window-level theme output. Shell
// extras are deliberately written separately by WriteShell.
func WriteHyprland(themeDir string, p Palette, borderStyle string, borderSize int, shape, spacing, depth, inactive string, borderSpeed ...int) error {
	animations := session.DefaultAnimationsStyle()
	if len(borderSpeed) > 0 && borderSpeed[0] != 0 {
		animations.BorderSpeed = borderSpeed[0]
	}
	return WriteHyprlandWithAnimations(themeDir, p, borderStyle, borderSize, shape, spacing, depth, "native", inactive, animations.BorderSpeed, animations)
}

func WriteHyprlandWithAnimations(themeDir string, p Palette, borderStyle string, borderSize int, shape, spacing, depth, active, inactive string, borderSpeed int, animations session.AnimationsStyle, barSpecs ...*bar.BarSpec) error {
	return WriteHyprlandWithAnimationsAndShell(themeDir, p, borderStyle, borderSize, shape, spacing, depth, active, inactive, borderSpeed, animations, session.ShellPresetDefault, barSpecs...)
}

// WriteHyprlandWithAnimationsAndShell keeps compositor-level Shell effects in
// the same generated theme transaction as the Window and Animations output.
// The optional-looking wrapper above preserves the legacy API for callers that
// do not provide a Shell preset.
func WriteHyprlandWithAnimationsAndShell(themeDir string, p Palette, borderStyle string, borderSize int, shape, spacing, depth, active, inactive string, borderSpeed int, animations session.AnimationsStyle, shellPreset string, barSpecs ...*bar.BarSpec) error {
	animations = session.NormalizeAnimationsStyle(animations)
	if shellPreset == "" {
		shellPreset = session.ShellPresetDefault
	}
	if !validChoice(shellPreset, session.ShellPresetDefault, session.ShellPresetGlass) {
		return fmt.Errorf("invalid shell preset %q", shellPreset)
	}
	spinSpeed := 36
	if borderSpeed != 0 {
		spinSpeed = borderSpeed
	} else if animations.BorderSpeed != 0 {
		spinSpeed = animations.BorderSpeed
	}
	if inactive == "shadow_full" {
		inactive = "shadow_only"
	}
	if !validChoice(borderStyle, "solid", "split", "split_top", "split_bottom", "blend", "neon", "spin") || borderSize < -1 || borderSize > 24 || spinSpeed < 10 || spinSpeed > 100 || !validChoice(shape, "native", "subtle", "soft", "rounded", "pill") || !validChoice(spacing, "native", "compact", "airy") || !validChoice(depth, "native", "flat", "shadow") || !validChoice(active, "native", "frosted_light", "frosted_balanced", "frosted_rich", "blur") || !validChoice(inactive, "native", "shadow", "shadow_only", "blur", "frosted_light", "frosted_balanced", "frosted_rich") {
		return fmt.Errorf("invalid desktop style")
	}
	if active == "blur" {
		active = "frosted_balanced"
	}
	if inactive == "blur" {
		inactive = "frosted_balanced"
	}
	if err := removeScreenEffectShaders(themeDir); err != nil {
		return fmt.Errorf("remove generated screen-effect shaders: %w", err)
	}
	screenEffect := animations.EffectiveScreenEffect()
	screenEffectShaderName, err := writeScreenEffectShader(themeDir, screenEffect)
	if err != nil {
		return fmt.Errorf("write %s screen-effect shader: %w", screenEffect.ID, err)
	}
	activeFrosted, activeProfile := frostedBackdropProfile(active)
	inactiveFrosted, inactiveProfile := frostedBackdropProfile(inactive)
	glassPreset := shellPreset == session.ShellPresetGlass
	accent, fg := hyprColor(p.Accent), hyprColor(p.Foreground)
	activeBorder := fmt.Sprintf("%q", accent)
	switch borderStyle {
	case "split", "split_top":
		activeBorder = gradientLua(accent, fg, 90)
	case "split_bottom":
		activeBorder = gradientLua(fg, accent, 90)
	case "blend":
		activeBorder = gradientLua(accent, hyprColor(p.Blue), 135)
	case "neon":
		activeBorder = gradientLua(accent, hyprColor(p.Magenta), 0)
	case "spin":
		// A two-stop accent/blue gradient can be nearly monochromatic in
		// extracted palettes. Add a contrasting magenta stop and repeat the
		// accent so the loop has an obvious moving seam.
		activeBorder = gradientLuaColors(0, accent, hyprColor(p.Blue), hyprColor(p.Magenta), accent)
	}
	var b strings.Builder
	fmt.Fprintf(&b, "-- Generated by Omagen. Window style: border=%s border_size=%d shape=%s spacing=%s depth=%s active=%s inactive=%s.\nlocal active_border_color = %s\nlocal inactive_border_color = %q\n", borderStyle, borderSize, shape, spacing, depth, active, inactive, activeBorder, hyprColor(p.DarkForeground))
	b.WriteString("if _omagen_border_angle_timer then _omagen_border_angle_timer:set_enabled(false) end\n")
	b.WriteString("if _omagen_glitch_timer then _omagen_glitch_timer:set_enabled(false) end\n")
	b.WriteString("if _omagen_glitch_cleanup then _omagen_glitch_cleanup() end\n")
	b.WriteString("if _omagen_window_opacity_cleanup then _omagen_window_opacity_cleanup() end\n")
	b.WriteString("if _omagen_window_opacity_rule then _omagen_window_opacity_rule:set_enabled(false) end\n")
	// Existing event callbacks resolve this global when they fire. Reset it for
	// every generated theme so a later non-Cyberpunk theme cannot revive an
	// earlier effect.
	b.WriteString("_omagen_glitch_burst = function() end\n")
	b.WriteString("_omagen_window_opacity_handshake = function() end\n")
	if borderStyle == "neon" {
		fmt.Fprintf(&b, "local active_shadow_color = %q\nlocal inactive_shadow_color = %q\nlocal active_glow_color = %q\nlocal inactive_glow_color = %q\n", hyprRGBA(p.Accent, "d0"), hyprRGBA(p.DarkForeground, "55"), hyprRGBA(p.Accent, "d0"), hyprRGBA(p.DarkForeground, "35"))
	}
	b.WriteString("\nhl.config({\n  general = {\n    col = { active_border = active_border_color, inactive_border = inactive_border_color },\n")
	if borderSize >= 0 {
		fmt.Fprintf(&b, "    border_size = %d,\n", borderSize)
	}
	if spacing == "compact" {
		b.WriteString("    gaps_in = 4, gaps_out = 5,\n")
	}
	if spacing == "airy" {
		b.WriteString("    gaps_in = 8, gaps_out = 14,\n")
	}
	b.WriteString("  },\n  group = { col = { border_active = active_border_color, border_inactive = inactive_border_color }, },\n")
	if shape != "native" || depth != "native" || borderStyle == "neon" || active != "native" || inactive != "native" {
		b.WriteString("  decoration = {\n")
		switch shape {
		case "subtle":
			b.WriteString("    rounding = 2, rounding_power = 3,\n")
		case "soft":
			b.WriteString("    rounding = 4, rounding_power = 3,\n")
		case "rounded":
			b.WriteString("    rounding = 8, rounding_power = 3,\n")
		case "pill":
			b.WriteString("    rounding = 16, rounding_power = 3,\n")
		}
		shadowEnabled := depth == "shadow" || borderStyle == "neon" || inactive == "shadow" || inactive == "shadow_only"
		if depth == "flat" && !shadowEnabled {
			b.WriteString("    shadow = { enabled = false },\n")
		}
		if shadowEnabled {
			activeShadow := fmt.Sprintf("%q", hyprRGBA(p.DarkerBackground, "e6"))
			inactiveShadow := fmt.Sprintf("%q", hyprRGBA(p.DarkerBackground, "b8"))
			if borderStyle == "neon" {
				activeShadow = "active_shadow_color"
				inactiveShadow = "inactive_shadow_color"
			}
			if inactive == "shadow" && borderStyle != "neon" {
				inactiveShadow = fmt.Sprintf("%q", hyprRGBA(p.DarkerBackground, "d0"))
			}
			if inactive == "shadow_only" && borderStyle != "neon" {
				// Keep this shadow visibly transparent so the active Omarchy and
				// application opacity policy remains visible underneath it.
				inactiveShadow = fmt.Sprintf("%q", hyprRGBA(p.DarkerBackground, "88"))
			}
			rangePx := 18
			if borderStyle == "neon" {
				rangePx = 24
			}
			fmt.Fprintf(&b, "    shadow = { enabled = true, render_power = 3, range = %d, color = %s, color_inactive = %s },\n", rangePx, activeShadow, inactiveShadow)
		}
		if borderStyle == "neon" {
			b.WriteString("    glow = { enabled = true, range = 16, render_power = 3, color = active_glow_color, color_inactive = inactive_glow_color },\n")
		}
		if inactive == "shadow" {
			b.WriteString("    dim_inactive = true, dim_strength = 0.32,\n")
		}
		if activeFrosted || inactiveFrosted {
			// This is compositor background blur through a translucent window. It
			// cannot blur opaque client pixels such as application text.
			if glassPreset && activeFrosted {
				fmt.Fprintf(&b, "    active_opacity = %.2f,\n", frostedWindowOpacity)
			}
			if inactiveFrosted {
				if glassPreset {
					fmt.Fprintf(&b, "    inactive_opacity = %.2f,\n", frostedWindowOpacity)
				}
				fmt.Fprintf(&b, "    dim_inactive = true, dim_strength = %.2f,\n", inactiveProfile.dim)
			}
			// Hyprland exposes one global blur kernel for normal windows, not
			// separate active/inactive size and pass values. Prefer the focused
			// window's profile whenever it is frosted so selecting a stronger
			// inactive profile cannot silently strengthen the active window too.
			// If only the inactive path is frosted, use that path's profile so the
			// requested inactive treatment still has a compositor blur.
			profile := sharedFrostedProfile(activeFrosted, activeProfile, inactiveFrosted, inactiveProfile)
			// Keep inactive opacity as part of the frosted look without letting it
			// suppress the backdrop sample. Otherwise opaque client themes are
			// merely dimmed and the result reads as a shadow instead of glass blur.
			fmt.Fprintf(&b, "    blur = { enabled = true, size = %d, passes = %d, ignore_opacity = true, new_optimizations = true },\n", profile.size, profile.passes)
		}
		b.WriteString("  },\n")
	}
	b.WriteString("})\n")
	if len(barSpecs) > 0 && barSpecs[0] != nil {
		barSpec := barSpecs[0].Normalize()
		if barSpec.Surface.Blur > 0 {
			// Layer blur is scoped to both possible bar owners. Continuous bars
			// stay native; replacement presets use the second namespace. The
			// layer rule enables blur without changing the user's window blur
			// policy globally.
			b.WriteString("\n-- Blur the translucent Omagen bar pane surfaces.\n")
			b.WriteString("hl.layer_rule({ name = \"omagen-native-bar-backdrop-blur\", match = { namespace = \"^omarchy-bar$\" }, blur = true, blur_popups = true, ignore_alpha = 0.20 })\n")
			b.WriteString("hl.layer_rule({ name = \"omagen-replacement-bar-backdrop-blur\", match = { namespace = \"^pretty-omagen-bar$\" }, blur = true, blur_popups = true, ignore_alpha = 0.20 })\n")
		}
	}
	if activeFrosted || inactiveFrosted {
		// Live Canvas is a Quickshell layer surface, not a managed window. The
		// window decoration blur above cannot affect it, so scope a layer rule
		// to the panel's namespace as well. The panel itself remains translucent
		// in QML so Hyprland can sample and blur the backdrop behind it.
		b.WriteString("\n-- Blur the translucent Omagen Live Canvas layer surface.\n")
		b.WriteString("hl.layer_rule({ name = \"omagen-live-canvas-backdrop-blur\", match = { namespace = \"^omagen-live-canvas$\" }, blur = true, blur_popups = true, ignore_alpha = 0.20 })\n")
	}
	if shellPreset == session.ShellPresetGlass {
		// Shell surfaces are layer-shell windows, so Window decoration blur does
		// not reach them. Keep this rule narrow: it enables compositor backdrop
		// blur for native Quattro surfaces and the Omagen Shell Demo without
		// changing the user's global application blur policy.
		b.WriteString("\n-- Blur translucent native Quickshell surfaces for the Shell Glass preset.\n")
		b.WriteString("hl.layer_rule({ name = \"omagen-shell-glass-backdrop-blur\", match = { namespace = \"^((omarchy-(bar|menu|image-selector|emojis|clipboard|keyboard-panel|notifications|osd|polkit|lock-preview|network-qr|reminders))|omagen-shell-demo|omagen-live-canvas)$\" }, blur = true, blur_popups = true, ignore_alpha = 0.20 })\n")
	}
	// A custom curve is meaningful even when every motion family is still
	// Native. Keep it in the writer gate so a curve-only edit is not silently
	// treated as the untouched native document.
	if animations.Window != "native" || animations.WindowOpen != "popin" || animations.WindowClose != "popin" || animations.WindowAmount != 87 || animations.WindowOpacity != 100 || animations.WindowSpeed != 4 || animations.Workspace != "native" || animations.Special != "inherit" || animations.Focus != "native" || animations.Layers != "native" || animations.WindowMove != "native" || animations.Glitch != "none" || animations.ScreenEffect != nil || animations.ReducedMotion || animations.Curve != "bezier" {
		writeAnimationSettings(&b, animations, p, screenEffect, screenEffectShaderName)
	}
	if (borderStyle == "spin" || borderStyle == "neon") && animations.Border != "static" && !animations.ReducedMotion {
		b.WriteString("\n-- Keep the accent gradient moving around the focused pane.\n")
		// Hyprland measures animation speed in deciseconds (1 = 100 ms).
		// The timer below also updates the angle so a theme switch can start
		// spinning existing windows whose border callback was created while
		// borderangle was disabled.
		speed := spinSpeed
		if borderStyle == "neon" {
			speed = 30
		}
		fmt.Fprintf(&b, "hl.animation({ leaf = \"borderangle\", enabled = true, speed = %d, bezier = \"linear\", style = \"loop\" })\n", speed)
		b.WriteString("local _omagen_border_angle = 0\n")
		fmt.Fprintf(&b, "_omagen_border_angle_timer = hl.timer(function()\n  _omagen_border_angle = (_omagen_border_angle + %0.4f) %% 360\n  hl.config({ general = { col = { active_border = { colors = active_border_color.colors, angle = _omagen_border_angle } } } })\nend, { timeout = 100, type = \"repeat\" })\n", 360.0/float64(speed))
	}
	return fsutil.AtomicWriteFile(filepath.Join(themeDir, "hyprland.lua"), []byte(b.String()), 0644)
}

func writeAnimationSettings(b *strings.Builder, animations session.AnimationsStyle, p Palette, screenEffect session.ScreenEffect, screenEffectShaderName string) {
	legacyCompact := animations.Preset == "native" && animations.WindowOpen == "popin" && animations.WindowClose == "popin" && animations.WindowMove == "native" && animations.WindowAmount == 87 && animations.WindowOpacity == 100 && animations.WindowSpeed == 4 && animations.WorkspaceAxis == "horizontal" && animations.WorkspaceTravel == 18 && animations.Special == "inherit" && animations.Focus == "native" && animations.Layers == "native" && animations.Curve == "bezier"
	motionCurve := "easeOutQuint"
	if animations.Curve == "glass" {
		motionCurve = "omagenGlass"
		b.WriteString("hl.curve(\"omagenGlass\", { type = \"bezier\", points = { { 0.16, 1 }, { 0.30, 1 } } })\n")
	}
	if animations.Curve == "precision" || animations.WindowMove == "quick" {
		if animations.Curve == "precision" {
			motionCurve = "omagenPrecision"
		}
		b.WriteString("hl.curve(\"omagenPrecision\", { type = \"bezier\", points = { { 0.22, 0.78 }, { 0.18, 1 } } })\n")
	}
	if animations.Curve == "digital" || animations.Window == "digital" || animations.WindowMove == "digital" || animations.Focus == "digital" {
		if animations.Curve == "digital" {
			motionCurve = "omagenDigital"
		}
		b.WriteString("hl.curve(\"omagenDigital\", { type = \"bezier\", points = { { 0.05, 0.92 }, { 0.12, 1 } } })\n")
	}
	if animations.ReducedMotion || animations.Window == "none" {
		b.WriteString("hl.animation({ leaf = \"windows\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"windowsIn\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"windowsOut\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"windowsMove\", enabled = false })\n")
	} else if legacyCompact && (animations.Window == "smooth" || animations.Window == "snappy") {
		speed, bezier := "3.79", "easeOutQuint"
		if animations.Window == "snappy" {
			speed, bezier = "5.5", "quick"
		}
		fmt.Fprintf(b, "hl.animation({ leaf = \"windows\", enabled = true, speed = %s, bezier = %q })\n", speed, bezier)
		fmt.Fprintf(b, "hl.animation({ leaf = \"windowsIn\", enabled = true, speed = %s, bezier = %q, style = \"popin 87%%\" })\n", speed, bezier)
		fmt.Fprintf(b, "hl.animation({ leaf = \"windowsOut\", enabled = true, speed = %s, bezier = \"linear\", style = \"popin 87%%\" })\n", speed)
	} else if animations.Window != "native" || !legacyCompact {
		// Preset documents carry their actual response value. Do not replace a
		// Cyberpunk or Focused value with a family-wide hardcoded speed: that made
		// different recipes serialize differently while rendering the same motion.
		speed := fmt.Sprintf("%d", animations.WindowSpeed)
		bezier := motionCurve
		closeSpeed := "1.5"
		fadeInSpeed, fadeOutSpeed := "1.7", "1.3"
		switch animations.Curve {
		case "glass":
			closeSpeed, fadeInSpeed, fadeOutSpeed = "2.8", "2.4", "2.0"
		case "precision":
			closeSpeed, fadeInSpeed, fadeOutSpeed = "0.8", "0.8", "0.6"
		case "digital":
			closeSpeed, fadeInSpeed, fadeOutSpeed = "1.1", "0.7", "0.5"
		}
		style := animations.WindowOpen
		if style == "" {
			style = "popin"
		}
		if style == "popin" {
			style = fmt.Sprintf("popin %d%%", animations.WindowAmount)
		}
		closeStyle := animations.WindowClose
		if closeStyle == "" {
			closeStyle = "popin"
		}
		if closeStyle == "popin" {
			closeStyle = fmt.Sprintf("popin %d%%", animations.WindowAmount)
		}
		if animations.Curve == "spring" || animations.Window == "spring" || animations.WindowMove == "spring" {
			b.WriteString("hl.curve(\"omagenSpring\", { type = \"spring\", mass = 1, stiffness = 85, dampening = 17 })\n")
			fmt.Fprintf(b, "hl.animation({ leaf = \"windows\", enabled = true, speed = %s, spring = \"omagenSpring\" })\n", speed)
		} else {
			fmt.Fprintf(b, "hl.animation({ leaf = \"windows\", enabled = true, speed = %s, bezier = %q })\n", speed, bezier)
		}
		if animations.WindowOpen == "fade" {
			b.WriteString("hl.animation({ leaf = \"windowsIn\", enabled = false })\n")
		} else if animations.Curve == "spring" || animations.Window == "spring" || animations.WindowMove == "spring" {
			fmt.Fprintf(b, "hl.animation({ leaf = \"windowsIn\", enabled = true, speed = %s, spring = \"omagenSpring\", style = %q })\n", speed, style)
		} else {
			fmt.Fprintf(b, "hl.animation({ leaf = \"windowsIn\", enabled = true, speed = %s, bezier = %q, style = %q })\n", speed, bezier, style)
		}
		if animations.WindowClose == "fade" {
			b.WriteString("hl.animation({ leaf = \"windowsOut\", enabled = false })\n")
		} else if animations.Curve == "spring" || animations.Window == "spring" || animations.WindowMove == "spring" {
			fmt.Fprintf(b, "hl.animation({ leaf = \"windowsOut\", enabled = true, speed = %s, spring = \"omagenSpring\", style = %q })\n", closeSpeed, closeStyle)
		} else {
			fmt.Fprintf(b, "hl.animation({ leaf = \"windowsOut\", enabled = true, speed = %s, bezier = %q, style = %q })\n", closeSpeed, bezier, closeStyle)
		}
		if animations.WindowOpacity < 100 {
			// The scoped per-window handshake below owns the Cyberpunk entrance
			// opacity. Disable the generic 0 -> 100 fade so the window actually
			// materializes from the requested percentage instead of from zero.
			b.WriteString("hl.animation({ leaf = \"fadeIn\", enabled = false })\n")
		} else {
			fmt.Fprintf(b, "hl.animation({ leaf = \"fadeIn\", enabled = true, speed = %s, bezier = %q })\n", fadeInSpeed, bezier)
		}
		fmt.Fprintf(b, "hl.animation({ leaf = \"fadeOut\", enabled = true, speed = %s, bezier = %q })\n", fadeOutSpeed, bezier)
	}
	if !animations.ReducedMotion {
		switch animations.WindowMove {
		case "none":
			b.WriteString("hl.animation({ leaf = \"windowsMove\", enabled = false })\n")
		case "smooth":
			speed, curve := "3.4", motionCurve
			if animations.Curve == "bezier" {
				curve = "easeOutQuint"
			}
			fmt.Fprintf(b, "hl.animation({ leaf = \"windowsMove\", enabled = true, speed = %s, bezier = %q })\n", speed, curve)
		case "quick":
			b.WriteString("hl.animation({ leaf = \"windowsMove\", enabled = true, speed = 1.2, bezier = \"omagenPrecision\" })\n")
		case "digital":
			b.WriteString("hl.animation({ leaf = \"windowsMove\", enabled = true, speed = 1.6, bezier = \"omagenDigital\" })\n")
		case "spring":
			b.WriteString("hl.curve(\"omagenSpring\", { type = \"spring\", mass = 1, stiffness = 85, dampening = 17 })\n")
			b.WriteString("hl.animation({ leaf = \"windowsMove\", enabled = true, speed = 4, spring = \"omagenSpring\" })\n")
		}
	}
	if animations.ReducedMotion || animations.Workspace == "none" {
		b.WriteString("hl.animation({ leaf = \"workspaces\", enabled = false })\n")
	} else if legacyCompact && animations.Workspace == "snappy" {
		b.WriteString("hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5, bezier = \"quick\", style = \"slide\" })\n")
	} else if legacyCompact && animations.Workspace == "smooth" {
		b.WriteString("hl.animation({ leaf = \"workspaces\", enabled = true, speed = 3, bezier = \"easeOutQuint\", style = \"slide\" })\n")
	} else if animations.Workspace != "native" {
		style := animations.Workspace
		if style == "spring" {
			style = "slidefade"
		}
		if style == "slide" && animations.WorkspaceAxis == "vertical" {
			style = "slidevert"
		}
		if style == "slidefade" && animations.WorkspaceAxis == "vertical" {
			style = "slidefadevert"
		}
		workspaceSpeed := "3"
		switch animations.Curve {
		case "glass":
			workspaceSpeed = "3.8"
		case "precision":
			workspaceSpeed = "1.2"
		case "digital":
			workspaceSpeed = "2"
		}
		if style == "fade" {
			fmt.Fprintf(b, "hl.animation({ leaf = \"workspaces\", enabled = true, speed = %s, bezier = %q, style = \"fade\" })\n", workspaceSpeed, motionCurve)
		} else {
			curve := motionCurve
			if animations.Curve == "spring" || animations.Workspace == "spring" {
				b.WriteString("hl.curve(\"omagenSpring\", { type = \"spring\", mass = 1, stiffness = 85, dampening = 17 })\n")
				fmt.Fprintf(b, "hl.animation({ leaf = \"workspaces\", enabled = true, speed = 4, spring = \"omagenSpring\", style = %q })\n", fmt.Sprintf("%s %d%%", style, animations.WorkspaceTravel))
			} else {
				fmt.Fprintf(b, "hl.animation({ leaf = \"workspaces\", enabled = true, speed = %s, bezier = %q, style = %q })\n", workspaceSpeed, curve, fmt.Sprintf("%s %d%%", style, animations.WorkspaceTravel))
			}
		}
	}
	if animations.ReducedMotion || animations.Special == "none" {
		b.WriteString("hl.animation({ leaf = \"specialWorkspace\", enabled = false })\n")
	} else if animations.Special != "inherit" {
		curve := motionCurve
		speed := "3"
		if animations.Curve == "glass" {
			speed = "3.6"
		} else if animations.Curve == "precision" {
			speed = "1.2"
		} else if animations.Curve == "digital" {
			speed = "1.8"
		}
		style := animations.Special
		if style == "slide" && animations.WorkspaceAxis == "vertical" {
			style = "slidevert"
		}
		fmt.Fprintf(b, "hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = %s, bezier = %q, style = %q })\n", speed, curve, style)
	}
	if animations.ReducedMotion || animations.Focus == "none" {
		b.WriteString("hl.animation({ leaf = \"fadeSwitch\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"fadeShadow\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"fadeDim\", enabled = false })\n")
	} else if animations.Focus == "quick" || animations.Focus == "smooth" || animations.Focus == "digital" {
		speed, curve := "1.2", "quick"
		if animations.Focus == "smooth" {
			speed, curve = "2.4", motionCurve
			if animations.Curve == "glass" {
				speed = "2.6"
			}
		}
		if animations.Focus == "digital" {
			speed, curve = "0.7", "omagenDigital"
		}
		fmt.Fprintf(b, "hl.animation({ leaf = \"border\", enabled = true, speed = %s, bezier = %q })\n", speed, curve)
		fmt.Fprintf(b, "hl.animation({ leaf = \"fadeSwitch\", enabled = true, speed = %s, bezier = %q })\n", speed, curve)
		fmt.Fprintf(b, "hl.animation({ leaf = \"fadeShadow\", enabled = true, speed = %s, bezier = %q })\n", speed, curve)
		fmt.Fprintf(b, "hl.animation({ leaf = \"fadeDim\", enabled = true, speed = %s, bezier = %q })\n", speed, curve)
	}
	if animations.ReducedMotion || animations.Layers == "none" {
		b.WriteString("hl.animation({ leaf = \"layers\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"fadeLayersIn\", enabled = false })\n")
		b.WriteString("hl.animation({ leaf = \"fadeLayersOut\", enabled = false })\n")
	} else if animations.Layers == "fade" || animations.Layers == "slide" {
		style := animations.Layers
		inSpeed, outSpeed, curve := "4", "1.5", motionCurve
		if animations.Curve == "glass" {
			inSpeed, outSpeed = "3.6", "2.2"
		} else if animations.Curve == "precision" {
			inSpeed, outSpeed = "1.2", "0.8"
		} else if animations.Curve == "digital" {
			inSpeed, outSpeed = "1.8", "0.9"
		}
		fmt.Fprintf(b, "hl.animation({ leaf = \"layers\", enabled = true, speed = %s, bezier = %q })\n", inSpeed, curve)
		fmt.Fprintf(b, "hl.animation({ leaf = \"layersIn\", enabled = true, speed = %s, bezier = %q, style = %q })\n", inSpeed, curve, style)
		fmt.Fprintf(b, "hl.animation({ leaf = \"layersOut\", enabled = true, speed = %s, bezier = %q, style = %q })\n", outSpeed, curve, style)
	}
	if animations.WindowOpacity < 100 && !animations.ReducedMotion {
		// Hyprland's fadeIn leaf always begins at zero opacity. This scoped
		// property handshake instead starts only the newly opened window at the
		// recipe value, then releases the override so fadeSwitch settles it to the
		// user's normal active/inactive opacity. Window addresses keep unrelated
		// windows and user rules untouched.
		b.WriteString("\n-- Per-window materialization: scoped entrance opacity, then restore user ownership.\n")
		b.WriteString("_omagen_window_opacity_pending = _omagen_window_opacity_pending or {}\n")
		fmt.Fprintf(b, `_omagen_window_opacity_rule = hl.window_rule({
  name = "omagen-window-materialization",
  match = { tag = "omagen-materializing" },
  opacity = "%.2f override %.2f override %.2f override",
})
local _omagen_window_opacity_release = function(selector)
  hl.dispatch(hl.dsp.window.tag({ tag = "-omagen-materializing", window = selector }))
end

_omagen_window_opacity_cleanup = function()
  for selector, timer in pairs(_omagen_window_opacity_pending) do
    if timer then timer:set_enabled(false) end
    _omagen_window_opacity_release(selector)
  end
  _omagen_window_opacity_pending = {}
end

`, float64(animations.WindowOpacity)/100.0, float64(animations.WindowOpacity)/100.0, float64(animations.WindowOpacity)/100.0)
		b.WriteString(`_omagen_window_opacity_handshake = function(window)
  if not window or not window.address then return end
  local selector = "address:" .. tostring(window.address)
  if _omagen_window_opacity_pending[selector] then return end
  hl.dispatch(hl.dsp.window.tag({ tag = "+omagen-materializing", window = selector }))
  local timer
  timer = hl.timer(function()
    timer:set_enabled(false)
    _omagen_window_opacity_release(selector)
    _omagen_window_opacity_pending[selector] = nil
  end, { timeout = 110, type = "repeat" })
  _omagen_window_opacity_pending[selector] = timer
end
hl.on("window.open", function(window) _omagen_window_opacity_handshake(window) end)
`)
	}
	if screenEffect.ID == "rgb-tear" && screenEffectShaderName != "" && !animations.ReducedMotion {
		// The whole-desktop shader is deliberately event-triggered. It is loaded
		// for a short signal burst and removed again by the timer, so the desktop
		// is not continuously re-rendered when nothing is happening.
		b.WriteString("\n-- Cyberpunk signal: event-triggered whole-desktop glitch, idle-off.\n")
		fmt.Fprintf(b, "local _omagen_glitch_flash_border = %s\n", gradientLuaColors(90, hyprColor(p.Magenta), hyprColor(p.Blue), hyprColor(p.Accent)))
		b.WriteString("local _omagen_glitch_shader = (os.getenv(\"HOME\") or \"\") .. \"/.local/state/omarchy/current/theme/omagen-cyberpunk-glitch.frag\"\n")
		b.WriteString("local _omagen_glitch_configured_shader = select(1, hl.get_config(\"decoration.screen_shader\"))\n")
		b.WriteString("local _omagen_glitch_base_screen_shader = _omagen_glitch_configured_shader\n")
		b.WriteString("if type(_omagen_glitch_base_screen_shader) ~= \"string\" then _omagen_glitch_base_screen_shader = \"\" end\n")
		b.WriteString("local _omagen_glitch_configured_damage_tracking = select(1, hl.get_config(\"debug.damage_tracking\"))\n")
		b.WriteString("local _omagen_glitch_base_damage_tracking = tonumber(_omagen_glitch_configured_damage_tracking) or 2\n")
		b.WriteString("_omagen_glitch_owned = false\n")
		b.WriteString(`
-- The shader's time uniform needs full damage tracking while it is active.
_omagen_glitch_cleanup = function()
  if _omagen_glitch_timer then _omagen_glitch_timer:set_enabled(false) end
  if _omagen_glitch_owned then
    hl.animation({ leaf = "borderangle", enabled = false })
    hl.config({
      general = { col = { active_border = active_border_color } },
      group = { col = { border_active = active_border_color } },
      decoration = { screen_shader = _omagen_glitch_base_screen_shader },
      debug = { damage_tracking = _omagen_glitch_base_damage_tracking },
    })
    _omagen_glitch_owned = false
  end
end

_omagen_glitch_burst = function()
  if _omagen_glitch_owned then
    -- Window creation can immediately produce related workspace, panel, or
    -- notification signals. Coalesce them into the active pulse instead of
    -- repeatedly restarting its strongest attack and trapping the display in
    -- continuous distortion.
    return
  end
  hl.config({
    general = { col = { active_border = _omagen_glitch_flash_border } },
    group = { col = { border_active = _omagen_glitch_flash_border } },
    decoration = { screen_shader = _omagen_glitch_shader },
    debug = { damage_tracking = 0 },
  })
  hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "linear", style = "loop" })
  _omagen_glitch_owned = true
  if _omagen_glitch_timer then _omagen_glitch_timer:set_enabled(true) end
end

`)
		// The shader's timer is a one-shot in behavior even though repeat is the
		// supported timer mode here: cleanup disables it on the first tick.
		fmt.Fprintf(b, "_omagen_glitch_timer = hl.timer(function()\n  if _omagen_glitch_cleanup then _omagen_glitch_cleanup() end\nend, { timeout = %d, type = \"repeat\" })\n", screenEffect.DurationMs)
		b.WriteString("_omagen_glitch_timer:set_enabled(false)\n")
		b.WriteString("hl.on(\"window.open\", function() _omagen_glitch_burst() end)\n")
		b.WriteString("hl.on(\"window.close\", function() _omagen_glitch_burst() end)\n")
		b.WriteString("hl.on(\"window.urgent\", function() _omagen_glitch_burst() end)\n")
		b.WriteString("hl.on(\"workspace.active\", function() _omagen_glitch_burst() end)\n")
		b.WriteString("local _omagen_native_shell_signal_namespaces = { [\"omarchy-menu\"] = true, [\"omarchy-image-selector\"] = true, [\"omarchy-emojis\"] = true, [\"omarchy-clipboard\"] = true, [\"omarchy-keyboard-panel\"] = true, [\"omarchy-notifications\"] = true, [\"omarchy-osd\"] = true, [\"omarchy-polkit\"] = true, [\"omarchy-network-qr\"] = true, [\"omarchy-reminders\"] = true, [\"omarchy-lock-preview\"] = true, [\"omagen-notification-signal\"] = true, [\"omagen-background-signal\"] = true }\n")
		b.WriteString("local _omagen_native_shell_signal = function(layer)\n  if not layer then return false end\n  if _omagen_native_shell_signal_namespaces[layer.namespace] == true then return true end\n  local namespace = tostring(layer.namespace or \"\")\n  if string.find(namespace, \"omagen-notification-signal-\", 1, true) == 1 then return true end\n  return string.find(namespace, \"omagen-background-signal-\", 1, true) == 1\nend\n")
		b.WriteString("hl.on(\"layer.opened\", function(layer) if _omagen_native_shell_signal(layer) then _omagen_glitch_burst() end end)\n")
		// Omarchy's stock layer rules intentionally disable compositor animation
		// for shell popups. Cyberpunk opts those native surfaces back into the
		// generated layer motion while keeping the bar's always-mapped surface
		// stable and avoiding a fullscreen overlay.
		b.WriteString("hl.layer_rule({ name = \"omagen-cyberpunk-native-shell-motion\", match = { namespace = \"^omarchy-(menu|image-selector|emojis|clipboard|keyboard-panel|notifications|osd|polkit|network-qr|reminders|lock-preview)$\" }, no_anim = false, animation = \"slide\" })\n")
	} else if screenEffect.ID != "none" && screenEffectShaderName != "" && !animations.ReducedMotion {
		b.WriteString("\n-- Omagen screen effect: finite event signal, idle-off.\n")
		fmt.Fprintf(b, "local _omagen_glitch_shader = (os.getenv(\"HOME\") or \"\") .. \"/.local/state/omarchy/current/theme/%s\"\n", screenEffectShaderName)
		b.WriteString("local _omagen_glitch_configured_shader = select(1, hl.get_config(\"decoration.screen_shader\"))\n")
		b.WriteString("local _omagen_glitch_base_screen_shader = _omagen_glitch_configured_shader\n")
		b.WriteString("if type(_omagen_glitch_base_screen_shader) ~= \"string\" then _omagen_glitch_base_screen_shader = \"\" end\n")
		b.WriteString("local _omagen_glitch_configured_damage_tracking = select(1, hl.get_config(\"debug.damage_tracking\"))\n")
		b.WriteString("local _omagen_glitch_base_damage_tracking = tonumber(_omagen_glitch_configured_damage_tracking) or 2\n")
		b.WriteString("_omagen_glitch_owned = false\n")
		b.WriteString(`_omagen_glitch_cleanup = function()
  if _omagen_glitch_timer then _omagen_glitch_timer:set_enabled(false) end
  if _omagen_glitch_owned then
    hl.config({
      decoration = { screen_shader = _omagen_glitch_base_screen_shader },
      debug = { damage_tracking = _omagen_glitch_base_damage_tracking },
    })
    _omagen_glitch_owned = false
  end
end

_omagen_glitch_burst = function()
`)
		if screenEffect.Coalesce {
			b.WriteString("  if _omagen_glitch_owned then return end\n")
		} else {
			b.WriteString("  if _omagen_glitch_owned and _omagen_glitch_cleanup then _omagen_glitch_cleanup() end\n")
		}
		b.WriteString(`  hl.config({
    decoration = { screen_shader = _omagen_glitch_shader },
    debug = { damage_tracking = 0 },
  })
  _omagen_glitch_owned = true
  if _omagen_glitch_timer then _omagen_glitch_timer:set_enabled(true) end
end

`)
		fmt.Fprintf(b, "_omagen_glitch_timer = hl.timer(function()\n  if _omagen_glitch_cleanup then _omagen_glitch_cleanup() end\nend, { timeout = %d, type = \"repeat\" })\n", screenEffect.DurationMs)
		b.WriteString("_omagen_glitch_timer:set_enabled(false)\n")
		if screenEffectHasTrigger(screenEffect, "window-open") {
			b.WriteString("hl.on(\"window.open\", function() _omagen_glitch_burst() end)\n")
		}
		if screenEffectHasTrigger(screenEffect, "window-close") {
			b.WriteString("hl.on(\"window.close\", function() _omagen_glitch_burst() end)\n")
		}
		if screenEffectHasTrigger(screenEffect, "urgent") {
			b.WriteString("hl.on(\"window.urgent\", function() _omagen_glitch_burst() end)\n")
		}
		if screenEffectHasTrigger(screenEffect, "workspace") {
			b.WriteString("hl.on(\"workspace.active\", function() _omagen_glitch_burst() end)\n")
		}
		if screenEffectHasTrigger(screenEffect, "panel") || screenEffectHasTrigger(screenEffect, "notification") {
			b.WriteString("local _omagen_screen_effect_layers = { [\"omarchy-menu\"] = true, [\"omarchy-image-selector\"] = true, [\"omarchy-emojis\"] = true, [\"omarchy-clipboard\"] = true, [\"omarchy-keyboard-panel\"] = true, [\"omarchy-notifications\"] = true, [\"omarchy-osd\"] = true, [\"omarchy-polkit\"] = true, [\"omarchy-network-qr\"] = true, [\"omarchy-reminders\"] = true, [\"omarchy-lock-preview\"] = true, [\"omagen-notification-signal\"] = true, [\"omagen-background-signal\"] = true }\n")
			b.WriteString("hl.on(\"layer.opened\", function(layer) if layer then local namespace = tostring(layer.namespace or \"\"); if _omagen_screen_effect_layers[layer.namespace] == true or string.find(namespace, \"omagen-notification-signal-\", 1, true) == 1 or string.find(namespace, \"omagen-background-signal-\", 1, true) == 1 then _omagen_glitch_burst() end end end)\n")
		}
	}
}

func screenEffectHasTrigger(effect session.ScreenEffect, trigger string) bool {
	for _, candidate := range effect.Triggers {
		if candidate == trigger {
			return true
		}
	}
	return false
}

type frostedProfile struct {
	dim    float64
	size   int
	passes int
}

const frostedWindowOpacity = 0.72

func frostedBackdropProfile(style string) (bool, frostedProfile) {
	switch style {
	case "blur", "frosted_balanced":
		// Balanced favours a visible backdrop over the old shadow-heavy dim.
		return true, frostedProfile{dim: 0.26, size: 18, passes: 3}
	case "frosted_light":
		return true, frostedProfile{dim: 0.12, size: 10, passes: 2}
	case "frosted_rich":
		return true, frostedProfile{dim: 0.34, size: 24, passes: 4}
	default:
		return false, frostedProfile{}
	}
}

// sharedFrostedProfile resolves the one normal-window blur kernel available
// in Hyprland. The active profile wins whenever it is frosted; otherwise the
// inactive profile supplies the kernel. This preserves the focused window's
// selected blur strength instead of letting a stronger inactive choice leak
// into it.
func sharedFrostedProfile(activeFrosted bool, activeProfile frostedProfile, inactiveFrosted bool, inactiveProfile frostedProfile) frostedProfile {
	if activeFrosted {
		return activeProfile
	}
	if inactiveFrosted {
		return inactiveProfile
	}
	return frostedProfile{}
}

func gradientLua(first, second string, angle int) string {
	return fmt.Sprintf("{ colors = { %q, %q }, angle = %d }", first, second, angle)
}

func gradientLuaColors(angle int, colors ...string) string {
	quoted := make([]string, len(colors))
	for i, color := range colors {
		quoted[i] = fmt.Sprintf("%q", color)
	}
	return fmt.Sprintf("{ colors = { %s }, angle = %d }", strings.Join(quoted, ", "), angle)
}
func hyprColor(hex string) string {
	if len(hex) == 7 {
		return "rgb(" + hex[1:] + ")"
	}
	return "rgb(ffffff)"
}
func hyprRGBA(hex, alpha string) string {
	if len(hex) == 7 {
		return fmt.Sprintf("rgba(%s%s)", hex[1:], alpha)
	}
	return "rgba(ffffff" + alpha + ")"
}
