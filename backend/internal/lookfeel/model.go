// Package lookfeel owns complete Look & Feel compositions. A composition is
// deliberately above the four existing styling engines: it resolves their
// current documents and supporting adapter intent without moving compiler or
// runtime ownership out of those packages.
package lookfeel

import (
	"encoding/json"
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/session"
)

const SchemaVersion = 1

const (
	PresetNative    = "omarchy-native"
	PresetGlassBlur = "glass-blur"
	PresetFocused   = "focused"
	PresetCyberpunk = "cyberpunk-glitch"
	PresetSpectral  = "spectral-shift"
	PresetPhosphor  = "phosphor-terminal"
	PresetMonolith  = "monolith"
	PresetOrbit     = "elastic-orbit"
	PresetNature    = "nature"
	PresetOriental  = "oriental"
)

const (
	TerminalModePreserve = "preserve"
	TerminalModePreset   = "preset"
	TerminalModeCustom   = "custom"

	TerminalCellBackground = "background"
	TerminalCellPainted    = "painted"
)

// TerminalTranslucency is supporting adapter intent, not a fifth styling
// engine. The terminal materializer translates this bounded contract into
// Ghostty, Alacritty, Kitty, and Foot theme files.
type TerminalTranslucency = session.TerminalTranslucency

func DefaultTerminalTranslucency() TerminalTranslucency {
	return session.DefaultTerminalTranslucency()
}

// Composition is the resolved, deterministic output of a Look & Feel
// preset. The four style documents remain the inputs to their current
// compilers. Customized records are reserved for the next slice, but are
// included now so the on-disk contract is stable before the UI edits it.
type Composition struct {
	SchemaVersion  int                     `json:"schema_version"`
	Preset         string                  `json:"preset"`
	PresetRevision int                     `json:"preset_revision"`
	Customized     map[string]bool         `json:"customized"`
	Window         session.DesktopStyle    `json:"window"`
	Shell          session.ShellStyle      `json:"shell"`
	Bar            session.BarStyle        `json:"bar"`
	Animations     session.AnimationsStyle `json:"animations"`
	Terminal       TerminalTranslucency    `json:"terminal"`
}

type CatalogEntry struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Revision    int    `json:"revision"`
}

func (c Composition) LookFeelDocument() session.LookFeelDocument {
	return session.LookFeelDocument{
		SchemaVersion:  c.SchemaVersion,
		Preset:         c.Preset,
		PresetRevision: c.PresetRevision,
		Customized:     c.Customized,
	}
}

func Catalog() []CatalogEntry {
	return []CatalogEntry{
		{ID: PresetNative, Name: "Omarchy Native", Description: "Preserve native Omarchy surfaces and terminal opacity", Revision: 1},
		{ID: PresetGlassBlur, Name: "Glass Blur", Description: "Soft frosted depth, floating glass, dot workspaces, and gliding motion", Revision: 7},
		{ID: PresetFocused, Name: "Focused", Description: "Grounded windows, numbered workspaces, a practical dock, and immediate motion", Revision: 2},
		{ID: PresetCyberpunk, Name: "Cyberpunk Glitch", Description: "Readable dark glass, orbital bar geometry, Roman workspaces, digital motion, and event-bound RGB tearing", Revision: 7},
		{ID: PresetSpectral, Name: "Spectral Shift", Description: "Prismatic shell signals, lettered workspaces, and cinematic refraction", Revision: 1},
		{ID: PresetPhosphor, Name: "Phosphor Terminal", Description: "Compact instrumentation, terminal workspaces, and finite CRT synchronization", Revision: 1},
		{ID: PresetMonolith, Name: "Monolith", Description: "Architectural geometry, minimal motion, and a quiet workspace rail", Revision: 1},
		{ID: PresetOrbit, Name: "Elastic Orbit", Description: "Rounded expanded surfaces, orbital workspaces, and spring motion", Revision: 1},
		{ID: PresetNature, Name: "Nature", Description: "Organic spacing, grounded translucent sections, growing workspaces, and gentle spring motion", Revision: 1},
		{ID: PresetOriental, Name: "Oriental", Description: "Kanagawa-inspired night surfaces, Japanese workspaces, and quiet ink-brush motion", Revision: 1},
	}
}

func Resolve(preset string) (Composition, error) {
	composition := Composition{
		SchemaVersion:  SchemaVersion,
		Preset:         preset,
		PresetRevision: 1,
		Customized: map[string]bool{
			"window": false, "shell": false, "bar": false, "animations": false, "terminal": false,
		},
		Window:     session.DefaultDesktopStyle(),
		Shell:      session.DefaultShellStyle(),
		Bar:        session.DefaultBarStyle(),
		Animations: session.DefaultAnimationsStyle(),
		Terminal:   DefaultTerminalTranslucency(),
	}

	switch preset {
	case PresetNative:
		// The defaults above are intentionally a no-op for native Omarchy.
	case PresetGlassBlur:
		composition.PresetRevision = 7
		composition.Window = glassWindow()
		composition.Shell = glassShell()
		composition.Bar = glassBar()
		composition.Animations = session.MotionPreset("smooth")
		composition.Terminal = TerminalTranslucency{
			SchemaVersion: SchemaVersion,
			Mode:          TerminalModePreset,
			Opacity:       0.82,
			CellMode:      TerminalCellPainted,
		}
	case PresetFocused:
		composition.PresetRevision = 2
		composition.Window = focusedWindow()
		composition.Shell = focusedShell()
		composition.Bar = focusedBar()
		composition.Animations = session.MotionPreset("snappy")
		// Focused changes desktop/shell/bar/motion treatment but never takes
		// ownership of a user's terminal opacity configuration.
		composition.Terminal = DefaultTerminalTranslucency()
	case PresetCyberpunk:
		composition.PresetRevision = 7
		composition.Window = cyberpunkWindow()
		composition.Shell = cyberpunkShell()
		composition.Bar = cyberpunkBar()
		composition.Animations = session.MotionPreset("cyberpunk")
		composition.Terminal = DefaultTerminalTranslucency()
	case PresetSpectral:
		composition.Window = spectralWindow()
		composition.Shell = spectralShell()
		composition.Bar = spectralBar()
		composition.Animations = spectralMotion()
	case PresetPhosphor:
		composition.Window = phosphorWindow()
		composition.Shell = phosphorShell()
		composition.Bar = phosphorBar()
		composition.Animations = phosphorMotion()
	case PresetMonolith:
		composition.Window = monolithWindow()
		composition.Shell = monolithShell()
		composition.Bar = monolithBar()
		composition.Animations = session.MotionPreset("minimal")
	case PresetOrbit:
		composition.Window = orbitWindow()
		composition.Shell = orbitShell()
		composition.Bar = orbitBar()
		composition.Animations = orbitMotion()
	case PresetNature:
		composition.Window = natureWindow()
		composition.Shell = natureShell()
		composition.Bar = natureBar()
		composition.Animations = natureMotion()
	case PresetOriental:
		composition.Window = orientalWindow()
		composition.Shell = orientalShell()
		composition.Bar = orientalBar()
		composition.Animations = orientalMotion()
	default:
		return Composition{}, fmt.Errorf("unknown Look & Feel preset %q", preset)
	}

	if err := composition.Validate(); err != nil {
		return Composition{}, err
	}
	return composition, nil
}

func (c Composition) Validate() error {
	if c.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported Look & Feel schema version %d", c.SchemaVersion)
	}
	if c.PresetRevision < 1 {
		return fmt.Errorf("invalid Look & Feel preset revision %d", c.PresetRevision)
	}
	// Community manifests use their own stable IDs. Built-in lookup remains
	// strict in Resolve; a decoded composition is validated by its fields rather
	// than rejected merely because it did not ship in this binary.
	if c.Preset == "" {
		return fmt.Errorf("Look & Feel preset ID is empty")
	}
	window := session.NormalizeDesktopStyle(c.Window)
	shell := session.NormalizeShellStyle(c.Shell)
	barStyle := session.NormalizeBarStyle(c.Bar)
	animations := session.NormalizeAnimationsStyle(c.Animations)
	if !window.Valid() {
		return fmt.Errorf("invalid Look & Feel window style")
	}
	if !shell.Valid() {
		return fmt.Errorf("invalid Look & Feel shell style")
	}
	if err := barStyle.EffectiveBarSpec().Validate(); err != nil {
		return fmt.Errorf("invalid Look & Feel bar spec: %w", err)
	}
	if !barStyle.Valid() {
		return fmt.Errorf("invalid Look & Feel bar style")
	}
	if barStyle.Profile != nil {
		if err := barStyle.Profile.Validate(); err != nil {
			return fmt.Errorf("invalid Look & Feel bar profile: %w", err)
		}
	}
	if !animations.Valid() {
		return fmt.Errorf("invalid Look & Feel animations style")
	}
	if err := c.Terminal.Validate(); err != nil {
		return err
	}
	for _, key := range []string{"window", "shell", "bar", "animations", "terminal"} {
		if _, ok := c.Customized[key]; !ok {
			return fmt.Errorf("Look & Feel customized state is missing %q", key)
		}
	}
	return nil
}

func glassWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "blend"
	style.Shape = "rounded"
	style.Spacing = "airy"
	style.Depth = "shadow"
	style.Active = "frosted_light"
	style.Inactive = "frosted_light"
	return style
}

func focusedWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderSizeMode = "fixed"
	style.BorderSize = 2
	style.Shape = "rounded"
	style.Depth = "shadow"
	style.Inactive = "shadow_only"
	return style
}

func focusedShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Surface = "contrast"
	style.Detail = "focus"
	return style
}

func cyberpunkWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "neon"
	style.BorderSizeMode = "fixed"
	style.BorderSize = 4
	style.BorderSpeed = 28
	style.Shape = "rounded"
	style.Depth = "shadow"
	style.Inactive = "shadow_only"
	return style
}

func spectralWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "blend"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Depth, style.Inactive = "soft", "shadow", "shadow_only"
	return style
}

func phosphorWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "split_top"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Spacing, style.Depth, style.Inactive = "subtle", "compact", "flat", "shadow_only"
	return style
}

func monolithWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "split_bottom"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Spacing, style.Depth, style.Inactive = "subtle", "compact", "flat", "shadow_only"
	return style
}

func orbitWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "blend"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Spacing, style.Depth, style.Inactive = "pill", "airy", "shadow", "shadow"
	return style
}

func natureWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	style.BorderStyle = "blend"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Spacing, style.Depth = "soft", "airy", "shadow"
	style.Active, style.Inactive = "frosted_light", "frosted_light"
	return style
}

func orientalWindow() session.DesktopStyle {
	style := session.DefaultDesktopStyle()
	// Kanagawa's quiet, architectural contrast: a restrained top split rather
	// than a neon or continuously animated border, with warm translucent focus
	// and a shadow-only inactive state.
	style.BorderStyle = "split_top"
	style.BorderSizeMode, style.BorderSize = "fixed", 2
	style.Shape, style.Spacing, style.Depth = "soft", "airy", "shadow"
	style.Active, style.Inactive = "frosted_balanced", "shadow_only"
	return style
}

func cyberpunkShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	// Keep the shell's reading surfaces neutral and dark. Accent is reserved
	// for the Edge chrome and explicit feedback, never as a full-shell fill.
	style.Surface = "layered"
	style.Detail = "edge"
	style.Tooltip = "accent"
	style.Notifications = "accent"
	return style
}

func spectralShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Surface, style.Detail, style.Tooltip, style.Notifications = "layered", "edge", "accent", "accent"
	return style
}

func phosphorShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Surface, style.Detail, style.Notifications = "contrast", "framed", "accent"
	return style
}

func monolithShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Surface, style.Detail = "contrast", "framed"
	return style
}

func orbitShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Surface, style.Detail = "layered", "focus"
	return style
}

func natureShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Preset, style.Surface, style.Detail = session.ShellPresetGlass, "layered", "framed"
	return style
}

func orientalShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Preset = session.ShellPresetGlass
	style.Surface, style.Detail = "layered", "framed"
	style.Tooltip, style.Notifications = "accent", "accent"
	return style
}

func glassShell() session.ShellStyle {
	style := session.DefaultShellStyle()
	style.Preset = session.ShellPresetGlass
	style.Surface = "layered"
	style.Detail = "edge"
	return style
}

func glassBar() session.BarStyle {
	spec, err := bar.Preset("float")
	if err != nil {
		// The preset is a package-local constant and is covered by tests. Keep a
		// valid native fallback here so a future catalog edit cannot panic the UI.
		spec = bar.Default()
	}
	spec.Preset = "float"
	spec.Surface.Treatment = "glass"
	spec.Surface.Opacity = 0.82
	spec.Surface.Blur = 12
	spec.Surface.BorderRole = "accent"
	spec.Surface.BorderOpacity = 0.35
	spec.Surface.BorderWidth = 1
	spec.Surface.Shadow = "floating"
	spec.Motion.Preset = "smooth"
	spec.Motion.DurationMs = 220
	spec.Motion.Easing = "out_cubic"
	spec.Workspace = bar.WorkspacePresentation{Mode: "dots"}
	spec = spec.Normalize()
	profile := barprofile.Profile{
		SchemaVersion:  barprofile.SchemaVersion,
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior: barprofile.Behavior{
			Form:       "floating",
			Visibility: "always",
			Reveal:     "edge",
			Expansion:  "none",
			Workspace:  "native",
		},
	}
	return session.BarStyle{
		Surface:    "native",
		Density:    "compact",
		Attention:  "semantic",
		Form:       "continuous",
		Visibility: "native",
		Profile:    &profile,
		Spec:       &spec,
	}
}

func focusedBar() session.BarStyle {
	spec, err := bar.Preset("dock")
	if err != nil {
		// Keep a valid native fallback if the package-local preset ever changes;
		// resolver validation will still protect the composition contract.
		spec = bar.Default()
	}
	spec.Preset = "dock"
	spec.Workspace = bar.WorkspacePresentation{Mode: "numbers"}
	spec = spec.Normalize()
	profile := barprofile.Profile{
		SchemaVersion:  barprofile.SchemaVersion,
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior: barprofile.Behavior{
			Form: "dock", Visibility: "auto-hide", Reveal: "edge", Expansion: "hover", Workspace: "native",
		},
	}
	return session.BarStyle{
		Surface: "dark", Density: "comfortable", Attention: "accent", Form: "docked", Visibility: "native",
		Profile: &profile, Spec: &spec,
	}
}

func cyberpunkBar() session.BarStyle {
	spec, err := bar.Preset("orbit")
	if err != nil {
		spec = bar.Default()
	}
	spec.Preset = "orbit"
	spec.Surface.Treatment = "glass"
	spec.Surface.Opacity = 0.88
	spec.Surface.Blur = 8
	spec.Surface.BorderRole = "accent"
	spec.Surface.BorderOpacity = 0.7
	spec.Surface.BorderWidth = 1
	spec.Surface.Shadow = "floating"
	spec.Motion.Preset = "cyberpunk"
	spec.Motion.DurationMs = 140
	spec.Motion.Easing = "out_cubic"
	// Keep the cyberpunk material, geometry, motion, and signal values stable
	// while using the orbital composition and a seven-segment clock face.
	spec.Workspace = bar.WorkspacePresentation{Mode: "roman"}
	spec.Clock.Style = "neon"
	spec = spec.Normalize()
	profile := barprofile.Profile{
		SchemaVersion:  barprofile.SchemaVersion,
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior: barprofile.Behavior{
			Form: "floating", Visibility: "always", Reveal: "edge", Expansion: "focus", Workspace: "segmented",
		},
	}
	return session.BarStyle{
		Surface: "dark", Density: "comfortable", Attention: "accent", Form: "docked", Visibility: "native",
		Profile: &profile, Spec: &spec,
	}
}

func replacementBar(preset, workspace string, glyphs []string) session.BarStyle {
	spec, err := bar.Preset(preset)
	if err != nil {
		spec = bar.Default()
	}
	spec.Workspace = bar.WorkspacePresentation{Mode: workspace, Glyphs: glyphs}
	spec = spec.Normalize()
	profile := barprofile.Profile{
		SchemaVersion: barprofile.SchemaVersion, Ownership: barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior:       barprofile.Behavior{Form: string(spec.Topology), Visibility: "always", Reveal: "edge", Expansion: "none", Workspace: "native"},
	}
	return session.BarStyle{Surface: "native", Density: spec.Geometry.Density, Attention: spec.Attention.Mode, Form: "docked", Visibility: "native", Profile: &profile, Spec: &spec}
}

func spectralBar() session.BarStyle {
	style := replacementBar("split", "letters", nil)
	spec := style.Spec
	spec.Surface.Treatment, spec.Surface.Role, spec.Surface.Opacity, spec.Surface.Blur = "glass", "dark", .90, 6
	spec.Surface.BorderRole, spec.Surface.BorderOpacity, spec.Surface.BorderWidth, spec.Surface.Shadow = "accent", .4, 1, "raised"
	spec.Geometry.Density = "compact"
	spec.Motion = bar.Motion{Preset: "smooth", DurationMs: 190, Easing: "out_cubic"}
	style.Density = "compact"
	return style
}

func phosphorBar() session.BarStyle {
	style := replacementBar("sections", "glyphs", []string{"A1", "B2", "C3", "D4", "E5"})
	spec := style.Spec
	spec.Surface.Treatment, spec.Surface.Role, spec.Surface.Opacity = "metal", "dark", .94
	spec.Geometry.Density = "compact"
	spec.Motion = bar.Motion{Preset: "subtle", DurationMs: 120, Easing: "out_quart"}
	style.Density = "compact"
	return style
}

func monolithBar() session.BarStyle {
	style := replacementBar("rail", "glyphs", []string{"W1", "W2", "W3", "W4", "W5"})
	style.Spec.Surface.Treatment, style.Spec.Surface.Role, style.Spec.Surface.Opacity = "opaque", "dark", 1
	style.Spec.Motion = bar.Motion{Preset: "none", DurationMs: 0, Easing: "linear"}
	style.Density = "compact"
	return style
}

func orbitBar() session.BarStyle {
	style := replacementBar("float-expanded", "glyphs", []string{"○", "◔", "◑", "◕", "●"})
	style.Spec.Surface.Treatment, style.Spec.Surface.Role, style.Spec.Surface.Opacity = "metal", "background", .96
	style.Spec.Geometry.Density = "comfortable"
	style.Spec.Motion = bar.Motion{Preset: "expressive", DurationMs: 260, Easing: "in_out_cubic"}
	style.Density = "comfortable"
	return style
}

func natureBar() session.BarStyle {
	// Use single-cell Nerd Font botanical icons so Nature's workspace identity
	// stays legible in the native 20px slots without emoji/fallback mixing.
	style := replacementBar("sections", "glyphs", []string{"", "", "", "", ""})
	style.Spec.Surface.Treatment, style.Spec.Surface.Role, style.Spec.Surface.Opacity, style.Spec.Surface.Blur = "glass", "background", .88, 8
	style.Spec.Surface.BorderRole, style.Spec.Surface.BorderOpacity, style.Spec.Surface.BorderWidth = "accent", .25, 1
	style.Spec.Geometry.Density, style.Spec.Geometry.SectionGap, style.Spec.Geometry.Radius = "comfortable", 12, 12
	style.Spec.Motion = bar.Motion{Preset: "smooth", DurationMs: 240, Easing: "in_out_cubic"}
	style.Density = "comfortable"
	return style
}

func orientalBar() session.BarStyle {
	// Split sections keep the native widget order while giving the Japanese
	// workspace rail a deliberate, ink-on-lacquer silhouette.
	style := replacementBar("split", "kanji", nil)
	spec := style.Spec
	spec.Surface.Treatment, spec.Surface.Role, spec.Surface.Opacity, spec.Surface.Blur = "glass", "background", .90, 10
	spec.Surface.BorderRole, spec.Surface.BorderOpacity, spec.Surface.BorderWidth, spec.Surface.Shadow = "accent", .28, 1, "raised"
	spec.Geometry.Density, spec.Geometry.SectionGap, spec.Geometry.Radius = "comfortable", 14, 10
	spec.Motion = bar.Motion{Preset: "smooth", DurationMs: 220, Easing: "out_cubic"}
	style.Density = "comfortable"
	return style
}

func spectralMotion() session.AnimationsStyle {
	style := session.MotionPreset("cinematic")
	style.Preset, style.WindowClose, style.WindowMove = "custom", "fade", "smooth"
	style.WindowAmount, style.WindowSpeed = 88, 3
	style.WorkspaceAxis, style.WorkspaceTravel = "vertical", 16
	style.ScreenEffect = &session.ScreenEffect{
		ID: "spectral-shift", Strength: "medium", DurationMs: 500,
		Triggers: []string{"window-open", "window-close", "workspace", "panel"}, Coalesce: true,
	}
	return style
}

func phosphorMotion() session.AnimationsStyle {
	style := session.MotionPreset("minimal")
	style.Preset = "custom"
	style.ScreenEffect = &session.ScreenEffect{
		ID: "phosphor-scan", Strength: "medium", DurationMs: 850,
		Triggers: []string{"window-open", "window-close", "workspace", "panel", "notification", "urgent"}, Coalesce: true,
	}
	return style
}

func orbitMotion() session.AnimationsStyle {
	style := session.MotionPreset("spring")
	style.Preset, style.WindowAmount, style.WorkspaceAxis = "custom", 86, "vertical"
	style.Special = "slidefade"
	return style
}

func natureMotion() session.AnimationsStyle {
	style := session.MotionPreset("spring")
	style.Preset, style.WindowAmount, style.WindowSpeed, style.WorkspaceTravel = "custom", 90, 4, 14
	style.Special = "fade"
	return style
}

func orientalMotion() session.AnimationsStyle {
	style := session.MotionPreset("cinematic")
	// The movement is intentionally calm and directional: windows slide in like
	// a brush stroke, dissolve on exit, and settle softly when focus changes.
	style.Preset = "custom"
	style.Window, style.WindowOpen, style.WindowClose = "cinematic", "slide", "fade"
	style.WindowMove, style.WindowAmount, style.WindowSpeed = "smooth", 88, 4
	style.WindowOpacity = 100
	style.Workspace, style.WorkspaceAxis, style.WorkspaceTravel = "slidefade", "horizontal", 16
	style.Special, style.Focus, style.Layers = "fade", "smooth", "fade"
	style.Curve, style.Border, style.Glitch = "glass", "static", "none"
	return style
}

func oneOf(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}
