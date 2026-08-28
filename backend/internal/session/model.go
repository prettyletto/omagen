package session

import (
	"fmt"
	"maps"
	"time"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
)

type ShellStyle struct {
	// Preset is the user-facing Shell look. It is intentionally separate from
	// Overrides so changing a preset never destroys an explicit advanced token.
	// The legacy fields below remain readable for sessions written before the
	// preset contract existed.
	Preset        string `json:"preset,omitempty"`
	Surface       string `json:"surface"`
	Detail        string `json:"detail"`
	Tooltip       string `json:"tooltip"`
	Notifications string `json:"notifications"`
	// Overrides contains additive section.key values for the native Quattro
	// shell.toml reader. Empty maps preserve the active Omarchy defaults.
	Overrides map[string]string `json:"overrides,omitempty"`
}

// DesktopStyle remains the window-level configuration used by existing
// themes. ShellStyle is additive and only controls Quattro shell.toml.
type DesktopStyle struct {
	BorderStyle    string `json:"border_style"`
	BorderSize     int    `json:"border_size"`
	BorderSizeMode string `json:"border_size_mode"`
	BorderSpeed    int    `json:"border_speed"`
	Shape          string `json:"shape"`
	Spacing        string `json:"spacing"`
	Depth          string `json:"depth"`
	// Active controls the focused-window surface. Native keeps full opacity;
	// frosted profiles expose compositor backdrop blur through active opacity.
	Active string `json:"active_style"`
	// Inactive controls the inactive-window presentation. "blur" remains a
	// backwards-compatible alias for the balanced frosted-backdrop profile.
	Inactive string `json:"inactive_style"`
}

// AnimationsStyle is Omagen's versioned Motion Lab document. The first five
// fields are the original compact animation controls and remain the
// compatibility surface for old sessions and CLI callers. The additional
// fields are deliberately compositor-facing: they describe intent, while
// backend/internal/theme remains the only writer of Hyprland Lua.
type AnimationsStyle struct {
	Version         int    `json:"version,omitempty"`
	Preset          string `json:"preset,omitempty"`
	Window          string `json:"window"`
	WindowOpen      string `json:"window_open,omitempty"`
	WindowClose     string `json:"window_close,omitempty"`
	WindowMove      string `json:"window_move,omitempty"`
	WindowAmount    int    `json:"window_amount,omitempty"`
	WindowOpacity   int    `json:"window_opacity,omitempty"`
	WindowSpeed     int    `json:"window_speed,omitempty"`
	Workspace       string `json:"workspace"`
	WorkspaceAxis   string `json:"workspace_axis,omitempty"`
	WorkspaceTravel int    `json:"workspace_travel,omitempty"`
	Special         string `json:"special_workspace,omitempty"`
	Focus           string `json:"focus,omitempty"`
	Layers          string `json:"layers,omitempty"`
	Curve           string `json:"curve,omitempty"`
	Border          string `json:"border"`
	BorderSpeed     int    `json:"border_speed"`
	Glitch          string `json:"glitch,omitempty"`
	// ScreenEffect generalizes the finite whole-desktop signal without changing
	// the legacy Cyberpunk document. A nil value keeps old RGB-tear recipes
	// byte-compatible; EffectiveScreenEffect derives their runtime effect from
	// Glitch. New recipes use an explicit built-in effect identifier.
	ScreenEffect  *ScreenEffect `json:"screen_effect,omitempty"`
	ReducedMotion bool          `json:"reduced_motion"`
}

type ScreenEffect struct {
	ID         string   `json:"id"`
	Strength   string   `json:"strength"`
	DurationMs int      `json:"duration_ms"`
	Triggers   []string `json:"triggers"`
	Coalesce   bool     `json:"coalesce"`
}

func (e ScreenEffect) Normalize() ScreenEffect {
	if e.ID == "" {
		e.ID = "none"
	}
	if e.Strength == "" {
		e.Strength = "medium"
	}
	if e.DurationMs == 0 {
		switch e.ID {
		case "rgb-tear":
			e.DurationMs = 1250
		case "spectral-shift":
			e.DurationMs = 500
		case "phosphor-scan":
			e.DurationMs = 850
		}
	}
	if e.ID != "none" && len(e.Triggers) == 0 {
		e.Triggers = []string{"window-open", "window-close", "workspace", "panel"}
	}
	return e
}

func (e ScreenEffect) Valid() bool {
	e = e.Normalize()
	if !validChoice(e.ID, "none", "rgb-tear", "spectral-shift", "phosphor-scan") || !validChoice(e.Strength, "low", "medium", "strong") || e.DurationMs < 0 || e.DurationMs > 5000 {
		return false
	}
	for _, trigger := range e.Triggers {
		if !validChoice(trigger, "window-open", "window-close", "workspace", "panel", "notification", "urgent") {
			return false
		}
	}
	return true
}

func (s AnimationsStyle) EffectiveScreenEffect() ScreenEffect {
	if s.ReducedMotion {
		return ScreenEffect{ID: "none", Strength: "medium"}.Normalize()
	}
	if s.ScreenEffect != nil {
		return s.ScreenEffect.Normalize()
	}
	if validChoice(s.Glitch, "low", "medium", "strong", "flicker") {
		strength := s.Glitch
		if strength == "flicker" {
			strength = "medium"
		}
		return ScreenEffect{ID: "rgb-tear", Strength: strength, DurationMs: 1250, Triggers: []string{"window-open", "window-close", "workspace", "panel", "notification", "urgent"}, Coalesce: true}
	}
	return ScreenEffect{ID: "none", Strength: "medium"}.Normalize()
}

// LookFeelDocument records how the four engine documents were composed. It is
// metadata owned by Omagen; the individual engine documents remain the inputs
// to their existing compilers.
type LookFeelDocument struct {
	SchemaVersion  int             `json:"schema_version,omitempty"`
	Preset         string          `json:"preset,omitempty"`
	PresetRevision int             `json:"preset_revision,omitempty"`
	Customized     map[string]bool `json:"customized,omitempty"`
}

func DefaultLookFeelDocument() LookFeelDocument {
	return LookFeelDocument{
		SchemaVersion:  1,
		Preset:         "omarchy-native",
		PresetRevision: 1,
		Customized: map[string]bool{
			"window": false, "shell": false, "bar": false, "animations": false, "terminal": false,
		},
	}
}

func NormalizeLookFeelDocument(d LookFeelDocument) LookFeelDocument {
	if d.SchemaVersion == 0 {
		d.SchemaVersion = 1
	}
	if d.Preset == "" {
		d.Preset = "omarchy-native"
	}
	if d.PresetRevision == 0 {
		d.PresetRevision = 1
	}
	if d.Customized == nil {
		d.Customized = map[string]bool{}
	}
	return d
}

func (d LookFeelDocument) Valid() bool {
	d = NormalizeLookFeelDocument(d)
	return d.SchemaVersion == 1 && d.PresetRevision >= 1 && d.Preset != ""
}

// TerminalTranslucency is the bounded intent consumed by the terminal
// materializer. It is persisted with a session so preview and Apply can use
// the same adapter input.
type TerminalTranslucency struct {
	SchemaVersion int     `json:"schema_version,omitempty"`
	Mode          string  `json:"mode,omitempty"`
	Opacity       float64 `json:"opacity,omitempty"`
	CellMode      string  `json:"cell_mode,omitempty"`
}

func DefaultTerminalTranslucency() TerminalTranslucency {
	return TerminalTranslucency{SchemaVersion: 1, Mode: "preserve", Opacity: 1, CellMode: "background"}
}

func NormalizeTerminalTranslucency(s TerminalTranslucency) TerminalTranslucency {
	if s.SchemaVersion == 0 {
		s.SchemaVersion = 1
	}
	if s.Mode == "" {
		s.Mode = "preserve"
	}
	if s.Opacity == 0 {
		s.Opacity = 1
	}
	if s.CellMode == "" {
		s.CellMode = "background"
	}
	return s
}

func (s TerminalTranslucency) Validate() error {
	s = NormalizeTerminalTranslucency(s)
	if s.SchemaVersion != 1 {
		return fmt.Errorf("unsupported terminal translucency schema version %d", s.SchemaVersion)
	}
	switch s.Mode {
	case "preserve", "preset", "custom":
	default:
		return fmt.Errorf("invalid terminal translucency mode %q", s.Mode)
	}
	if s.Opacity < 0.5 || s.Opacity > 1 {
		return fmt.Errorf("terminal opacity %.3f is outside 0.50..1.00", s.Opacity)
	}
	switch s.CellMode {
	case "background", "painted":
	default:
		return fmt.Errorf("invalid terminal cell mode %q", s.CellMode)
	}
	return nil
}

func (s TerminalTranslucency) Valid() bool { return s.Validate() == nil }

func DefaultAnimationsStyle() AnimationsStyle {
	return AnimationsStyle{Version: 1, Preset: "native", Window: "native", WindowOpen: "popin", WindowClose: "popin", WindowMove: "native", WindowAmount: 87, WindowOpacity: 100, WindowSpeed: 4, Workspace: "native", WorkspaceAxis: "horizontal", WorkspaceTravel: 18, Special: "inherit", Focus: "native", Layers: "native", Curve: "bezier", Border: "native", BorderSpeed: 36, Glitch: "none"}
}

func NormalizeAnimationsStyle(s AnimationsStyle) AnimationsStyle {
	if s.Version == 0 {
		s.Version = 1
	}
	if s.Preset == "" {
		s.Preset = "native"
	}
	if isPresetOnly(s) {
		s = MotionPreset(s.Preset)
	}
	if s.Window == "" {
		s.Window = "native"
	}
	if s.WindowOpen == "" {
		s.WindowOpen = "popin"
	}
	if s.WindowClose == "" {
		s.WindowClose = "popin"
	}
	if s.WindowMove == "" {
		s.WindowMove = "native"
	}
	if s.WindowAmount == 0 {
		s.WindowAmount = 87
	}
	if s.WindowOpacity == 0 {
		s.WindowOpacity = 100
	}
	if s.WindowSpeed == 0 {
		s.WindowSpeed = 4
	}
	if s.Workspace == "" {
		s.Workspace = "native"
	}
	if s.WorkspaceAxis == "" {
		s.WorkspaceAxis = "horizontal"
	}
	if s.WorkspaceTravel == 0 {
		s.WorkspaceTravel = 18
	}
	if s.Special == "" {
		s.Special = "inherit"
	}
	if s.Focus == "" {
		s.Focus = "native"
	}
	if s.Layers == "" {
		s.Layers = "native"
	}
	if s.Curve == "" {
		s.Curve = "bezier"
	}
	if s.Border == "" {
		s.Border = "native"
	}
	if s.BorderSpeed == 0 {
		s.BorderSpeed = 36
	}
	if s.Glitch == "" {
		s.Glitch = "none"
	}
	// The first Cyberpunk recipe called its single RGB tear level "flicker".
	// Preserve those exported/session documents while giving new recipes an
	// explicit, portable strength scale.
	if s.Glitch == "flicker" {
		s.Glitch = "medium"
	}
	if s.ReducedMotion {
		s.Window = "none"
		s.Workspace = "none"
		s.Border = "static"
		s.Glitch = "none"
		s.ScreenEffect = nil
	}
	return s
}

func (s AnimationsStyle) Valid() bool {
	return s.Version == 1 &&
		validChoice(s.Preset, "native", "custom", "snappy", "smooth", "spring", "cinematic", "minimal", "cyberpunk") &&
		validChoice(s.Window, "native", "smooth", "snappy", "digital", "spring", "cinematic", "minimal", "none") &&
		validChoice(s.WindowOpen, "popin", "slide", "gnomed", "fade") &&
		validChoice(s.WindowClose, "popin", "slide", "gnomed", "fade") &&
		validChoice(s.WindowMove, "native", "smooth", "quick", "digital", "spring", "none") &&
		s.WindowAmount >= 60 && s.WindowAmount <= 100 &&
		s.WindowOpacity >= 60 && s.WindowOpacity <= 100 &&
		s.WindowSpeed >= 1 && s.WindowSpeed <= 10 &&
		validChoice(s.Workspace, "native", "smooth", "snappy", "spring", "fade", "slide", "slidefade", "slidefadevert", "none") &&
		validChoice(s.WorkspaceAxis, "horizontal", "vertical") &&
		s.WorkspaceTravel >= 5 && s.WorkspaceTravel <= 100 &&
		validChoice(s.Special, "inherit", "fade", "slide", "slidevert", "slidefade", "none") &&
		validChoice(s.Focus, "native", "quick", "smooth", "digital", "none") &&
		validChoice(s.Layers, "native", "fade", "slide", "none") &&
		validChoice(s.Curve, "bezier", "glass", "precision", "digital", "spring") &&
		validChoice(s.Border, "native", "static", "spin") &&
		s.BorderSpeed >= 10 && s.BorderSpeed <= 100 &&
		validChoice(s.Glitch, "none", "low", "medium", "strong") &&
		(s.ScreenEffect == nil || s.ScreenEffect.Valid())
}

// MotionPreset expands a semantic recipe into the versioned document. It is
// intentionally independent from palette generation: wallpaper colours never
// decide whether a desktop should bounce, slide, or stay still.
func MotionPreset(name string) AnimationsStyle {
	s := DefaultAnimationsStyle()
	s.Preset = name
	s.Version = 1
	s.Window = "native"
	s.Workspace = "native"
	s.Focus = "native"
	s.Layers = "native"
	s.Curve = "bezier"
	s.Border = "native"
	s.WindowOpen = "popin"
	s.WindowClose = "popin"
	s.WindowMove = "native"
	s.WindowAmount = 87
	s.WindowOpacity = 100
	s.WindowSpeed = 4
	s.WorkspaceAxis = "horizontal"
	s.WorkspaceTravel = 18
	s.Special = "inherit"
	switch name {
	case "snappy":
		// Precision motion begins almost at its final geometry and settles in one
		// short beat. A fade workspace avoids reusing Glass' spatial glide.
		s.Window, s.Workspace, s.WindowMove, s.Curve = "snappy", "fade", "quick", "precision"
		s.WindowAmount, s.WindowSpeed, s.WorkspaceTravel = 97, 1, 5
		s.Focus, s.Layers = "quick", "fade"
	case "smooth":
		// Glass motion uses visible depth and a long, soft settle. It is the only
		// built-in recipe whose normal workspace motion deliberately glides.
		s.Window, s.Workspace, s.WindowMove, s.Curve = "smooth", "slidefade", "smooth", "glass"
		s.WindowAmount, s.WindowSpeed, s.WorkspaceTravel = 82, 4, 22
		s.Special = "fade"
		s.Focus, s.Layers = "smooth", "fade"
	case "spring":
		s.Window, s.Workspace, s.WindowMove, s.Curve = "spring", "slidefade", "spring", "spring"
		s.WindowSpeed, s.WorkspaceTravel = 4, 18
		s.Focus, s.Layers = "smooth", "fade"
	case "cinematic":
		s.Window, s.Workspace, s.WindowOpen, s.WindowClose = "cinematic", "slidefade", "popin", "gnomed"
		s.WindowAmount, s.WindowSpeed, s.WorkspaceTravel = 76, 5, 28
		s.Special = "slide"
		s.Focus, s.Layers = "smooth", "slide"
	case "minimal":
		s.Window, s.Workspace, s.WindowOpen, s.WindowClose = "minimal", "fade", "fade", "fade"
		s.WindowMove, s.WindowAmount, s.WindowSpeed, s.WorkspaceTravel, s.Curve = "none", 100, 1, 5, "precision"
		s.Focus, s.Layers = "quick", "fade"
	case "cyberpunk":
		// Digital motion is not Snappy plus a shader. New windows deform into
		// place, exits cut spatially, focus changes are mechanical, and normal
		// workspaces move without borrowing Glass' slide-fade language.
		s.Window, s.WindowOpen, s.WindowClose, s.WindowMove = "digital", "gnomed", "slide", "digital"
		s.Workspace, s.WorkspaceTravel, s.Special = "slide", 12, "slidevert"
		s.WindowAmount, s.WindowSpeed, s.Curve = 94, 2, "digital"
		s.WindowOpacity = 82
		s.Focus, s.Layers, s.Border, s.Glitch = "digital", "slide", "static", "medium"
	case "native":
		// Keep the native preset as a true no-op in the compiler.
	default:
		s.Preset = "native"
	}
	return s
}

func isPresetOnly(s AnimationsStyle) bool {
	return s.Preset != "" && s.Window == "" && s.Workspace == "" && s.Border == "" && s.BorderSpeed == 0 && s.Glitch == "" &&
		s.WindowOpen == "" && s.WindowClose == "" && s.WindowMove == "" && s.WindowAmount == 0 && s.WindowOpacity == 0 && s.WindowSpeed == 0 &&
		s.WorkspaceAxis == "" && s.WorkspaceTravel == 0 && s.Special == "" && s.Focus == "" && s.Layers == "" && s.Curve == "" && s.ScreenEffect == nil && !s.ReducedMotion
}

type BarStyle struct {
	Surface    string              `json:"surface"`
	Density    string              `json:"density"`
	Attention  string              `json:"attention"`
	Form       string              `json:"form"`
	Visibility string              `json:"visibility"`
	Profile    *barprofile.Profile `json:"profile,omitempty"`
	// Spec is the versioned appearance/behaviour document. The legacy fields
	// stay serialized for old sessions and CLI callers; NormalizeBarStyle
	// keeps both representations coherent during the migration.
	Spec *bar.BarSpec `json:"spec,omitempty"`
}

func DefaultBarStyle() BarStyle {
	return BarStyle{Surface: "native", Density: "native", Attention: "semantic", Form: "continuous", Visibility: "native"}
}

// NormalizeBarStyle keeps sessions written before Bar Form was introduced
// valid. Missing form values are the backwards-compatible Continuous mode.
func NormalizeBarStyle(s BarStyle) BarStyle {
	if s.Surface == "" {
		s.Surface = "native"
	}
	if s.Density == "" {
		s.Density = "native"
	}
	if s.Attention == "" {
		s.Attention = "semantic"
	}
	if s.Form == "" {
		s.Form = "continuous"
	}
	if s.Visibility == "" {
		s.Visibility = "native"
	}
	if s.Profile != nil {
		profile := s.Profile.Normalize()
		s.Profile = &profile
	}
	if s.Spec != nil {
		spec := s.Spec.Normalize()
		s.Spec = &spec
	}
	return s
}

func (s BarStyle) Valid() bool {
	return validChoice(s.Surface, "native", "dark", "light", "accent") &&
		validChoice(s.Density, "native", "compact", "comfortable") &&
		validChoice(s.Attention, "semantic", "accent") &&
		validChoice(s.Form, "continuous", "docked") &&
		validChoice(s.Visibility, "native", "islands") &&
		s.EffectiveBarSpec().Valid() &&
		(s.Profile == nil || s.Profile.Valid())
}

// EffectiveShellOverrides keeps Shell-owned appearance tokens authoritative
// for the native bar too. The native and replacement bars both read Color.bar;
// these aliases keep their visual language in step with Shell without
// introducing a separate Bar colour owner.
func EffectiveShellOverrides(shell ShellStyle, _ BarStyle) map[string]string {
	overrides := ShellPresetOverrides(NormalizeShellStyle(shell).Preset)
	for key, value := range shell.Overrides {
		overrides[key] = value
	}
	if overrides == nil {
		overrides = map[string]string{}
	}
	copyFirst := func(target string, keys ...string) {
		if _, exists := overrides[target]; exists {
			return
		}
		for _, key := range keys {
			if value, exists := overrides[key]; exists {
				overrides[target] = value
				return
			}
		}
	}
	copyFirst("bar.background", "popups.background", "menu.background", "launcher.background")
	copyFirst("bar.text", "popups.text", "menu.text", "controls.normal-color")
	copyFirst("bar.active", "controls.focus-color", "menu.selected-text", "notifications.border", "menu.selected-background")
	return overrides
}

// EffectiveBarSpec returns the versioned document without forcing legacy
// sessions to rewrite their durable record. New callers may persist Spec;
// older five-field bar_style records remain byte-compatible until edited.
func (s BarStyle) EffectiveBarSpec() bar.BarSpec {
	if s.Spec != nil {
		return s.Spec.Normalize()
	}
	return migrateLegacyBarSpec(s)
}

func migrateLegacyBarSpec(s BarStyle) bar.BarSpec {
	spec := bar.Default()
	spec.Surface.Role = s.Surface
	spec.Geometry.Density = s.Density
	spec.Attention.Mode = s.Attention
	spec.Topology = bar.TopologyContinuous
	if s.Form == "docked" {
		spec.Topology = bar.TopologySections
	}
	if s.Visibility == "islands" {
		spec.Topology = bar.TopologySections
	}
	if s.Profile != nil {
		behavior := s.Profile.Behavior
		switch behavior.Form {
		case "continuous":
			spec.Topology = bar.TopologyContinuous
		case "split":
			spec.Topology = bar.TopologySplit
		case "islands":
			spec.Topology = bar.TopologyIslands
		case "dock":
			spec.Topology = bar.TopologyDock
		case "rail":
			spec.Topology = bar.TopologyRail
		case "sections":
			spec.Topology = bar.TopologySections
		}
		if s.Profile.Implementation == barprofile.ImplementationReplacement {
			spec.Engine = bar.EngineOmagen
		}
		if behavior.Visibility == "auto-hide" {
			spec.Behavior.Visibility = "auto_hide"
		}
		if behavior.Expansion != "none" {
			spec.Behavior.HoverExpand = true
		}
		switch behavior.Workspace {
		case "dots":
			spec.Workspace.Mode = "dots"
		case "numbers":
			spec.Workspace.Mode = "numbers"
		}
	}
	return spec.Normalize()
}

func DefaultDesktopStyle() DesktopStyle {
	return DesktopStyle{BorderStyle: "solid", BorderSize: -1, BorderSizeMode: "default", BorderSpeed: 36, Shape: "native", Spacing: "native", Depth: "native", Active: "native", Inactive: "native"}
}

// NormalizeDesktopStyle keeps sessions written before border-size modes and
// inactive-window modes were introduced compatible with the native behavior.
func NormalizeDesktopStyle(s DesktopStyle) DesktopStyle {
	if s.BorderSizeMode == "" {
		// Before border-size modes existed, zero meant "do not override the
		// theme". Migrate that legacy representation to Default. Positive
		// values remain explicit fixed sizes.
		if s.BorderSize == 0 {
			s.BorderSize = -1
			s.BorderSizeMode = "default"
		} else if s.BorderSize < 0 {
			s.BorderSizeMode = "default"
		} else {
			s.BorderSizeMode = "fixed"
		}
	}
	switch s.BorderSizeMode {
	case "default":
		s.BorderSize = -1
	case "none":
		s.BorderSize = 0
	case "fixed":
		if s.BorderSize < 1 {
			s.BorderSize = 1
		}
	}
	if s.BorderSpeed == 0 {
		s.BorderSpeed = 36
	}
	if s.Inactive == "" {
		s.Inactive = "native"
	}
	if s.Active == "" {
		s.Active = "native"
	}
	if s.Active == "blur" {
		s.Active = "frosted_balanced"
	}
	if s.Inactive == "blur" {
		s.Inactive = "frosted_balanced"
	}
	if s.Inactive == "shadow_full" {
		// The first shipped name meant full-opacity shadow, but Omarchy's
		// transparency policy must remain authoritative. Preserve it as the
		// shadow-only profile during migration.
		s.Inactive = "shadow_only"
	}
	return s
}

func (s DesktopStyle) Valid() bool {
	return validChoice(s.BorderStyle, "solid", "split", "split_top", "split_bottom", "blend", "neon", "spin") &&
		validChoice(s.BorderSizeMode, "default", "none", "fixed") &&
		s.BorderSize >= -1 && s.BorderSize <= 24 &&
		((s.BorderSizeMode == "default" && s.BorderSize == -1) ||
			(s.BorderSizeMode == "none" && s.BorderSize == 0) ||
			(s.BorderSizeMode == "fixed" && s.BorderSize >= 1)) &&
		s.BorderSpeed >= 10 && s.BorderSpeed <= 100 &&
		validChoice(s.Shape, "native", "subtle", "soft", "rounded", "pill") &&
		validChoice(s.Spacing, "native", "compact", "airy") &&
		validChoice(s.Depth, "native", "flat", "shadow") &&
		validChoice(s.Active, "native", "frosted_light", "frosted_balanced", "frosted_rich") &&
		validChoice(s.Inactive, "native", "shadow", "shadow_only", "blur", "frosted_light", "frosted_balanced", "frosted_rich")
}

func DefaultShellStyle() ShellStyle {
	return ShellStyle{Preset: ShellPresetDefault, Surface: "flat", Detail: "native", Tooltip: "native", Notifications: "native"}
}

const (
	ShellPresetDefault = "default"
	ShellPresetGlass   = "glass"
)

// ShellPresetOverrides returns the small, theme-owned token set that makes a
// preset visible to Quattro's native shell reader. Explicit user overrides are
// merged after this map, so advanced controls work on every preset and remain
// authoritative over preset defaults.
func ShellPresetOverrides(preset string) map[string]string {
	if preset != ShellPresetGlass {
		return map[string]string{}
	}
	return map[string]string{
		"bar.background-alpha":           "0.72",
		"popups.background-alpha":        "0.72",
		"menu.background-alpha":          "0.72",
		"launcher.background-alpha":      "0.72",
		"tooltip.background-alpha":       "0.88",
		"notifications.background-alpha": "0.86",
		"polkit.background-alpha":        "0.88",
		"lock.background-alpha":          "0.82",
	}
}

// NormalizeShellStyle keeps sessions written before feedback-surface controls
// were introduced compatible with the native Quattro behavior.
func NormalizeShellStyle(s ShellStyle) ShellStyle {
	if s.Preset == "" {
		s.Preset = ShellPresetDefault
	}
	if s.Surface == "" {
		s.Surface = "flat"
	}
	if s.Detail == "" {
		s.Detail = "native"
	}
	if s.Tooltip == "" {
		s.Tooltip = "native"
	}
	if s.Notifications == "" {
		s.Notifications = "native"
	}
	if s.Overrides != nil {
		s.Overrides = maps.Clone(s.Overrides)
	}
	return s
}

func (s ShellStyle) Valid() bool {
	return validChoice(s.Preset, ShellPresetDefault, ShellPresetGlass) &&
		validChoice(s.Surface, "flat", "layered", "contrast", "accent") &&
		validChoice(s.Detail, "native", "framed", "edge", "focus") &&
		validChoice(s.Tooltip, "native", "accent") &&
		validChoice(s.Notifications, "native", "accent")
}

func validChoice(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}

type ApplyPhase string

const (
	ApplyPhaseNone      ApplyPhase = ""
	ApplyPhasePrepared  ApplyPhase = "prepared"
	ApplyPhaseCommitted ApplyPhase = "committed"
)

type BackgroundRef struct {
	Kind string `json:"kind"`
	Path string `json:"path"`
}

type Record struct {
	SessionID            string               `json:"session_id"`
	OriginalTheme        string               `json:"original_theme"`
	OriginalBackground   BackgroundRef        `json:"original_background"`
	CreatedAt            time.Time            `json:"created_at"`
	SourceImage          string               `json:"source_image,omitempty"`
	ExtraConfigs         bool                 `json:"extra_configs,omitempty"`
	ShellStyle           ShellStyle           `json:"shell_style,omitempty"`
	DesktopStyle         DesktopStyle         `json:"desktop_style,omitempty"`
	BarStyle             BarStyle             `json:"bar_style,omitempty"`
	AnimationsStyle      AnimationsStyle      `json:"animations_style,omitempty"`
	LookFeel             LookFeelDocument     `json:"look_feel,omitempty"`
	TerminalTranslucency TerminalTranslucency `json:"terminal_translucency,omitempty"`
	// BarSnapshot preserves the exact pre-theme shell configuration, including
	// fields this version does not understand, for reversible bar profiles.
	BarSnapshot        *barprofile.Snapshot `json:"bar_snapshot,omitempty"`
	GenerationID       string               `json:"generation_id,omitempty"`
	PreviewVariant     string               `json:"preview_variant,omitempty"`
	ApplyPhase         ApplyPhase           `json:"apply_phase,omitempty"`
	AppliedTheme       string               `json:"applied_theme,omitempty"`
	AppliedGeneration  string               `json:"applied_generation,omitempty"`
	AppliedVariant     string               `json:"applied_variant,omitempty"`
	AppliedDisplayName string               `json:"applied_display_name,omitempty"`
}

type BeginResult struct {
	SessionID            string               `json:"session_id"`
	OriginalTheme        string               `json:"original_theme"`
	OriginalBackground   BackgroundRef        `json:"original_background"`
	ShellStyle           ShellStyle           `json:"shell_style"`
	DesktopStyle         DesktopStyle         `json:"desktop_style"`
	BarStyle             BarStyle             `json:"bar_style"`
	AnimationsStyle      AnimationsStyle      `json:"animations_style"`
	LookFeel             LookFeelDocument     `json:"look_feel,omitempty"`
	TerminalTranslucency TerminalTranslucency `json:"terminal_translucency,omitempty"`
	ExtraConfigs         bool                 `json:"extra_configs"`
	BarSnapshot          *barprofile.Snapshot `json:"bar_snapshot,omitempty"`
}

type ActiveRecord struct {
	SessionID string    `json:"session_id"`
	CreatedAt time.Time `json:"created_at"`
}

type StatusResult struct {
	Active             bool           `json:"active"`
	SessionID          string         `json:"session_id,omitempty"`
	Recoverable        bool           `json:"recoverable"`
	CreatedAt          time.Time      `json:"created_at,omitempty"`
	OriginalTheme      string         `json:"original_theme,omitempty"`
	OriginalBackground *BackgroundRef `json:"original_background,omitempty"`
}

type RecoverResult struct {
	Recovered bool   `json:"recovered"`
	SessionID string `json:"session_id,omitempty"`
}
