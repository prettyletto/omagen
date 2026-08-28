package theme

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/runtime"
)

var generatedShellFiles = []string{
	"shell.toml",
	"shell.bar.toml",
	"shell.popups.toml",
	"shell.menu.toml",
	"shell.launcher.toml",
	"shell.controls.toml",
	"shell.tooltip.toml",
	"shell.notifications.toml",
	"shell.font.toml",
	"shell.spacing.toml",
	"shell.polkit.toml",
	"shell.lock.toml",
	"shell.image-picker.toml",
}

var generatedOmagenFiles = []string{"omagen.bar.toml", "omagen.bar.json", "omagen.bar.spec.json", "omagen.look-feel.json", "omagen.terminal.json", runtime.ManifestFileName}

type shellSection struct {
	name string
	body strings.Builder
}

// WriteShell emits Quattro's section-level shell overrides. Section sidecars
// are retained as staging/debug artifacts, while shell.toml is materialized
// as the runtime reader consumed by the installed Quattro shell.
func WriteShell(themeDir string, palette Palette, surface, detail, tooltip, notificationStyle, barSurface, barDensity, barAttention, barForm, barVisibility string) error {
	return WriteShellWithOverrides(themeDir, palette, surface, detail, tooltip, notificationStyle, barSurface, barDensity, barAttention, barForm, barVisibility, nil)
}

// WriteBarProfile writes the optional theme-bounded bar contract. The profile
// is deliberately separate from shell.toml: Quattro reads shell.json for bar
// layout, so only the reversible Omagen adapter may apply this file.
func WriteBarProfile(themeDir string, profile barprofile.Profile) error {
	profile = profile.Normalize()
	if err := profile.Validate(); err != nil {
		return err
	}
	data, err := json.MarshalIndent(profile, "", "  ")
	if err != nil {
		return fmt.Errorf("encode bar profile: %w", err)
	}
	data = append(data, '\n')
	return fsutil.AtomicWriteFile(filepath.Join(themeDir, "omagen.bar.json"), data, 0o644)
}

// WriteBarSpec records the normalized compiler decision alongside the theme
// output. It is intentionally separate from omagen.bar.json, which remains
// the legacy reversible profile consumed by the adapter during migration.
func WriteBarSpec(themeDir string, spec bar.BarSpec) error {
	compiled, err := bar.Compile(spec)
	if err != nil {
		return fmt.Errorf("compile bar spec: %w", err)
	}
	data, err := json.MarshalIndent(compiled, "", "  ")
	if err != nil {
		return fmt.Errorf("encode bar spec: %w", err)
	}
	data = append(data, '\n')
	return fsutil.AtomicWriteFile(filepath.Join(themeDir, "omagen.bar.spec.json"), data, 0o644)
}

// WriteShellWithOverrides emits the normal additive composition sidecars and
// a merged shell.toml for the installed Quattro reader. The sidecars remain
// headerless compiler inputs for compatibility, but they are never treated as
// independently loaded runtime files.
func WriteShellWithOverrides(themeDir string, palette Palette, surface, detail, tooltip, notificationStyle, barSurface, barDensity, barAttention, barForm, barVisibility string, overrides map[string]string) error {
	return WriteShellWithOverridesAndSpec(themeDir, palette, surface, detail, tooltip, notificationStyle, barSurface, barDensity, barAttention, barForm, barVisibility, overrides, nil)
}

// WriteShellWithOverridesAndSpec keeps the legacy API stable while allowing
// the BarSpec compiler to add native Quattro token changes. Advanced fields
// remain in the spec artifact and are consumed by the additive DockedBarSurface
// adapter without taking ownership of native widget layout or input.
func WriteShellWithOverridesAndSpec(themeDir string, palette Palette, surface, detail, tooltip, notificationStyle, barSurface, barDensity, barAttention, barForm, barVisibility string, overrides map[string]string, spec *bar.BarSpec) error {
	if !validChoice(surface, "native", "flat", "layered", "contrast", "accent") {
		return fmt.Errorf("invalid shell surface %q", surface)
	}
	if !validChoice(detail, "native", "framed", "edge", "focus") {
		return fmt.Errorf("invalid shell detail %q", detail)
	}
	if !validChoice(tooltip, "native", "accent") || !validChoice(notificationStyle, "native", "accent") {
		return fmt.Errorf("invalid shell feedback style")
	}
	if !validChoice(barSurface, "native", "dark", "light", "accent") ||
		!validChoice(barDensity, "native", "compact", "comfortable") ||
		!validChoice(barAttention, "semantic", "accent") ||
		!validChoice(barForm, "continuous", "docked") ||
		!validChoice(barVisibility, "native", "islands") {
		return fmt.Errorf("invalid bar style")
	}

	if err := clearGeneratedThemeFiles(themeDir); err != nil {
		return err
	}

	popups := shellSection{name: "popups"}
	menu := shellSection{name: "menu"}
	launcher := shellSection{name: "launcher"}
	controls := shellSection{name: "controls"}
	notifications := shellSection{name: "notifications"}
	tooltipSection := shellSection{name: "tooltip"}
	barSection := shellSection{name: "bar"}
	font := shellSection{name: "font"}
	spacing := shellSection{name: "spacing"}
	polkit := shellSection{name: "polkit"}
	lock := shellSection{name: "lock"}
	imagePicker := shellSection{name: "image-picker"}

	// Surface composition distributes the generated neutral ramp across the
	// shell's existing surfaces; it does not change transparency or layout.
	popup, control, selected := palette.Background, palette.LighterBackground, palette.Selection
	switch surface {
	case "layered":
		popup, control = palette.DarkBackground, palette.LighterBackground
	case "contrast":
		popup, control, selected = palette.LighterBackground, palette.LighterBackground, palette.Accent
	case "accent":
		// Accent is a state treatment, not a full-bleed surface. The shell
		// keeps its neutral card background while using the generated accent for
		// selected rows and focus chrome below.
		popup, control, selected = palette.DarkBackground, palette.LighterBackground, palette.Accent
	}
	if surface != "flat" {
		fmt.Fprintf(&popups.body, "background = %q\n", popup)
		fmt.Fprintf(&menu.body, "background = %q\nselected-background = %q\n", popup, selected)
		if surface == "accent" {
			fmt.Fprintf(&menu.body, "selected-background-alpha = 0.18\nselected-text = %q\n", palette.Accent)
		}
		if detail == "edge" {
			menu.body.WriteString("selected-border-width = \"0 0 0 3\"\n")
		}
		if detail == "focus" {
			menu.body.WriteString("selected-border-width = 1\n")
		}
		fmt.Fprintf(&launcher.body, "background = %q\nselected-background = %q\n", popup, selected)
		if surface == "accent" {
			fmt.Fprintf(&launcher.body, "selected-background-alpha = 0.18\nselected-text = %q\n", palette.Accent)
		}
		fmt.Fprintf(&controls.body, "normal-color = %q\nnormal-fill-alpha = 1.0\nselected-color = %q\n", control, selected)
		if surface == "accent" {
			fmt.Fprintf(&controls.body, "selected-fill-alpha = 0.18\nselected-border = %q\nselected-border-alpha = 0.78\n", palette.Accent)
		} else {
			controls.body.WriteString("selected-fill-alpha = 1.0\n")
		}
	}

	// Detail changes border language only; Quattro's existing colors and
	// interaction states remain intact.
	switch detail {
	case "framed":
		controls.body.WriteString("normal-border-width = 1\nhover-cursor-border-width = 1\nfocus-border-width = 1\nselected-border-width = 1\n")
		popups.body.WriteString("border-width = 1\n")
		if surface == "flat" {
			menu.body.WriteString("border-width = 1\n")
			notifications.body.WriteString("border-width = 1\n")
		}
	case "edge":
		controls.body.WriteString("normal-border-width = 0\nselected-border-width = \"0 0 0 3\"\n")
		if surface == "flat" {
			menu.body.WriteString("selected-border-width = \"0 0 0 3\"\n")
			notifications.body.WriteString("border-width = \"0 0 0 3\"\n")
		}
	case "focus":
		controls.body.WriteString("normal-border-width = 0\nhover-cursor-border-width = 0\nfocus-border-width = 1\nselected-border-width = 1\n")
		if surface == "native" {
			notifications.body.WriteString("border-width = 0\n")
		}
	}

	if tooltip == "accent" {
		tooltipSection.body.WriteString("border = \"accent\"\nborder-alpha = 1.0\n")
	}
	if notificationStyle == "accent" {
		notifications.body.WriteString("border = \"accent\"\nborder-alpha = 1.0\ncountdown = \"accent\"\n")
	}

	if err := appendBarOverrides(&barSection.body, palette, barSurface, barDensity, barAttention, barForm); err != nil {
		return err
	}
	if spec != nil {
		compiled, err := bar.Compile(*spec)
		if err != nil {
			return fmt.Errorf("compile bar spec: %w", err)
		}
		if compiled.Native {
			appendNativeBarSpec(&barSection.body, palette, compiled.Spec)
		} else {
			// Advanced shapes are rendered by the click-through adapter beneath
			// native widgets. Expose that decoration without changing widget
			// placement or input ownership.
			barSection.body.WriteString("background-alpha = 0.0\n")
		}
	}
	if err := appendShellOverrides(map[string]*shellSection{
		"bar": &barSection, "popups": &popups, "menu": &menu, "launcher": &launcher,
		"controls": &controls, "tooltip": &tooltipSection, "notifications": &notifications,
		"font": &font, "spacing": &spacing, "polkit": &polkit, "lock": &lock,
		"image-picker": &imagePicker,
	}, overrides); err != nil {
		return err
	}
	if barForm == "docked" {
		metadata := "# Generated by Omagen.\nform = \"docked\"\n"
		if barVisibility == "islands" {
			metadata += "visibility = \"islands\"\n"
		}
		if err := fsutil.AtomicWriteFile(filepath.Join(themeDir, "omagen.bar.toml"), []byte(metadata), 0o644); err != nil {
			return fmt.Errorf("write omagen.bar.toml: %w", err)
		}
		profile := barprofile.Profile{
			SchemaVersion:  barprofile.SchemaVersion,
			Ownership:      barprofile.OwnershipOverlay,
			Implementation: barprofile.ImplementationAdapter,
			Behavior:       barprofile.Behavior{Form: "dock", Visibility: "always", Reveal: "edge", Expansion: "none", Workspace: "native", Islands: barVisibility == "islands"},
		}
		profileData, err := json.MarshalIndent(profile, "", "  ")
		if err != nil {
			return fmt.Errorf("encode bar profile: %w", err)
		}
		profileData = append(profileData, '\n')
		if err := fsutil.AtomicWriteFile(filepath.Join(themeDir, "omagen.bar.json"), profileData, 0o644); err != nil {
			return fmt.Errorf("write omagen.bar.json: %w", err)
		}
	}

	sections := []*shellSection{&barSection, &popups, &menu, &launcher, &controls, &tooltipSection, &notifications, &font, &spacing, &polkit, &lock, &imagePicker}
	var merged strings.Builder
	for _, section := range sections {
		body := dedupeTOMLBody(section.body.String())
		if body == "" {
			continue
		}
		content := "# Generated by Omagen.\n" + body
		path := filepath.Join(themeDir, "shell."+section.name+".toml")
		if err := fsutil.AtomicWriteFile(path, []byte(content), 0o644); err != nil {
			return fmt.Errorf("write shell.%s.toml: %w", section.name, err)
		}
		merged.WriteString("[")
		merged.WriteString(section.name)
		merged.WriteString("]\n")
		merged.WriteString(body)
		merged.WriteByte('\n')
	}
	if merged.Len() > 0 {
		content := "# Generated by Omagen.\n" + merged.String()
		if err := fsutil.AtomicWriteFile(filepath.Join(themeDir, "shell.toml"), []byte(content), 0o644); err != nil {
			return fmt.Errorf("write merged shell.toml: %w", err)
		}
	}
	return nil
}

func appendNativeBarSpec(b *strings.Builder, p Palette, spec bar.BarSpec) {
	surface := spec.Surface
	switch surface.Role {
	case "background":
		fmt.Fprintf(b, "background = %q\n", p.Background)
	case "dark":
		fmt.Fprintf(b, "background = %q\n", p.DarkBackground)
	case "light":
		fmt.Fprintf(b, "background = %q\n", p.Foreground)
	case "accent":
		fmt.Fprintf(b, "background = %q\ntext = %q\n", p.Accent, p.Background)
	case "transparent":
		b.WriteString("background-alpha = 0.0\n")
	}
	if surface.Opacity >= 0 && surface.Opacity < 1 {
		fmt.Fprintf(b, "background-alpha = %.3f\n", surface.Opacity)
	}
	if spec.Geometry.Thickness > 0 {
		fmt.Fprintf(b, "size-horizontal = %d\nsize-vertical = %d\n", spec.Geometry.Thickness, spec.Geometry.Thickness)
	} else {
		switch spec.Geometry.Density {
		case "compact":
			b.WriteString("size-horizontal = 22\nsize-vertical = 24\n")
		case "comfortable":
			b.WriteString("size-horizontal = 30\nsize-vertical = 32\n")
		}
	}
	if spec.Attention.Mode == "accent" {
		fmt.Fprintf(b, "active = %q\n", p.Accent)
	}
}

// dedupeTOMLBody keeps the last assignment for each simple key. The writer
// intentionally layers compatibility values, BarSpec values, and explicit
// overrides; collapsing the final body makes the result valid TOML while
// preserving that precedence (explicit overrides are last).
func dedupeTOMLBody(body string) string {
	lines := strings.Split(body, "\n")
	seen := make(map[string]int)
	for index, line := range lines {
		trimmed := strings.TrimSpace(line)
		equal := strings.IndexByte(trimmed, '=')
		if equal <= 0 {
			continue
		}
		key := strings.TrimSpace(trimmed[:equal])
		if !validShellKey(key) {
			continue
		}
		if previous, ok := seen[key]; ok {
			lines[previous] = ""
		}
		seen[key] = index
	}
	filtered := make([]string, 0, len(lines))
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			filtered = append(filtered, line)
		}
	}
	if len(filtered) == 0 {
		return ""
	}
	return strings.Join(filtered, "\n") + "\n"
}

func appendShellOverrides(sections map[string]*shellSection, overrides map[string]string) error {
	keys := make([]string, 0, len(overrides))
	for key := range overrides {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		value := overrides[key]
		parts := strings.SplitN(key, ".", 2)
		if len(parts) != 2 || sections[parts[0]] == nil || !validShellKey(parts[1]) {
			return fmt.Errorf("invalid shell override key %q", key)
		}
		if strings.ContainsAny(value, "\r\n") {
			return fmt.Errorf("invalid shell override value for %q", key)
		}
		// QML and the shell parser intentionally carry values as strings. TOML
		// quoting keeps colors, semantic tokens, widths, numbers, and booleans
		// lossless while the native readers coerce them at consumption time.
		fmt.Fprintf(&sections[parts[0]].body, "%s = %q\n", parts[1], value)
	}
	return nil
}

func validShellKey(value string) bool {
	if value == "" {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_') {
			return false
		}
	}
	return true
}

func clearGeneratedThemeFiles(themeDir string) error {
	for _, name := range append(generatedShellFiles, generatedOmagenFiles...) {
		if err := fsutil.RemoveFileAndSync(filepath.Join(themeDir, name)); err != nil {
			return fmt.Errorf("remove old %s: %w", name, err)
		}
	}
	return nil
}

func validChoice(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}
