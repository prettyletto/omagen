package bar

import (
	"encoding/json"
	"fmt"
	"unicode/utf8"
)

// SchemaVersion is the version of the declarative BarSpec document. BarSpec
// describes the bar's appearance and behaviour; widget placement remains in
// the separate, user-owned Quattro shell.json document.
const SchemaVersion = 2

type Engine string

const (
	EngineAuto   Engine = "auto"
	EngineNative Engine = "native"
	EngineOmagen Engine = "omagen"
)

type Topology string

const (
	TopologyContinuous Topology = "continuous"
	TopologyFloating   Topology = "floating"
	TopologySections   Topology = "sections"
	TopologyIslands    Topology = "islands"
	TopologyDock       Topology = "dock"
	TopologySplit      Topology = "split"
	TopologyMinimal    Topology = "minimal"
	TopologyNotch      Topology = "notch"
	TopologyRail       Topology = "rail"
)

type Position string

const (
	PositionTop    Position = "top"
	PositionBottom Position = "bottom"
	PositionLeft   Position = "left"
	PositionRight  Position = "right"
)

type Surface struct {
	// Treatment is the user-facing pane choice. Role/opacity/blur remain the
	// serialized rendering primitives so older specs and the native shell
	// compiler stay compatible.
	Treatment     string  `json:"treatment"`
	Role          string  `json:"role"`
	Opacity       float64 `json:"opacity"`
	Blur          int     `json:"blur"`
	BorderRole    string  `json:"border_role"`
	BorderOpacity float64 `json:"border_opacity"`
	BorderWidth   int     `json:"border_width"`
	Shadow        string  `json:"shadow"`
}

type Geometry struct {
	Density      string `json:"density"`
	Thickness    int    `json:"thickness"`
	EdgeOffset   int    `json:"edge_offset"`
	OuterMargin  int    `json:"outer_margin"`
	InnerPadding int    `json:"inner_padding"`
	SectionGap   int    `json:"section_gap"`
	WidgetGap    int    `json:"widget_gap"`
	Radius       int    `json:"radius"`
	LengthMode   string `json:"length_mode"`
	LengthValue  int    `json:"length_value"`
	Alignment    string `json:"alignment"`
}

type Attention struct {
	Mode string `json:"mode"`
}

type Behavior struct {
	Visibility                string `json:"visibility"`
	ExclusiveZone             string `json:"exclusive_zone"`
	HoverExpand               bool   `json:"hover_expand"`
	HideDelayMs               int    `json:"hide_delay_ms"`
	RevealDelayMs             int    `json:"reveal_delay_ms"`
	EdgeSensor                int    `json:"edge_sensor"`
	KeepVisibleWhilePopupOpen bool   `json:"keep_visible_while_popup_open"`
}

type Motion struct {
	Preset     string `json:"preset"`
	DurationMs int    `json:"duration_ms"`
	Easing     string `json:"easing"`
}

// RegionBehavior controls only the additive surface treatment for a native
// bar region.  The native Quattro bar still owns the widgets, ordering, and
// input in every mode.
type RegionBehavior struct {
	Mode string `json:"mode"`
}

type Regions struct {
	Left   RegionBehavior `json:"left"`
	Center RegionBehavior `json:"center"`
	Right  RegionBehavior `json:"right"`
}

// WorkspacePresentation describes the workspace labels rendered by the Bar Lab
// and the Omagen bar host. Native preserves Quattro's first-party presentation
// contract; kanji is the bounded Japanese 1-5 presentation (一 through 五),
// while glyphs is deliberately bounded so theme data cannot create an
// unbounded QML model or pathological labels.
type WorkspacePresentation struct {
	Mode   string   `json:"mode"`
	Glyphs []string `json:"glyphs,omitempty"`
}

// Clock controls only the visual presentation used by the Omagen replacement
// bar. The native clock remains the default and remains the behavioral owner
// for the calendar, format cycling, timezone action, IPC, and popout routing.
type Clock struct {
	Style string `json:"style"`
}

// BarSpec is the shared document consumed by the preview and by the native /
// Omagen compiler. It deliberately has no widget layout field: shell.json is
// a user-owned canonical document and must only change after an explicit
// layout edit.
type BarSpec struct {
	Version   int                   `json:"version"`
	Preset    string                `json:"preset"`
	Engine    Engine                `json:"engine"`
	Topology  Topology              `json:"topology"`
	Position  Position              `json:"position"`
	Surface   Surface               `json:"surface"`
	Geometry  Geometry              `json:"geometry"`
	Attention Attention             `json:"attention"`
	Behavior  Behavior              `json:"behavior"`
	Regions   Regions               `json:"regions"`
	Workspace WorkspacePresentation `json:"workspace"`
	Clock     Clock                 `json:"clock"`
	Motion    Motion                `json:"motion"`
}

func Default() BarSpec {
	return BarSpec{
		Version: SchemaVersion,
		Preset:  "native",
		Engine:  EngineAuto, Topology: TopologyContinuous, Position: PositionTop,
		Surface:   Surface{Treatment: "preset", Role: "native", Opacity: 1, BorderRole: "none", Shadow: "none"},
		Geometry:  Geometry{Density: "native", SectionGap: 8, LengthMode: "full", Alignment: "center"},
		Attention: Attention{Mode: "semantic"},
		Behavior:  Behavior{Visibility: "always", ExclusiveZone: "reserve", HideDelayMs: 500, RevealDelayMs: 50, EdgeSensor: 3, KeepVisibleWhilePopupOpen: true},
		Regions:   Regions{Left: RegionBehavior{Mode: "native"}, Center: RegionBehavior{Mode: "native"}, Right: RegionBehavior{Mode: "native"}},
		Workspace: WorkspacePresentation{Mode: "native"},
		Clock:     Clock{Style: "native"},
		Motion:    Motion{Preset: "native", DurationMs: 180, Easing: "out_cubic"},
	}
}

func (s BarSpec) Normalize() BarSpec {
	d := Default()
	if s.Version == 0 {
		s.Version = d.Version
	}
	if s.Preset == "" {
		s.Preset = "custom"
	}
	if s.Engine == "" {
		s.Engine = d.Engine
	}
	if s.Topology == "" {
		s.Topology = d.Topology
	}
	if s.Position == "" {
		s.Position = d.Position
	}
	if s.Surface.Role == "" {
		s.Surface.Role = d.Surface.Role
	}
	if s.Surface.Treatment == "" {
		s.Surface.Treatment = d.Surface.Treatment
	}
	if s.Surface.Opacity == 0 && s.Surface.Role == "native" {
		s.Surface.Opacity = d.Surface.Opacity
	}
	if s.Surface.BorderRole == "" {
		s.Surface.BorderRole = d.Surface.BorderRole
	}
	if s.Surface.Shadow == "" {
		s.Surface.Shadow = d.Surface.Shadow
	}
	if s.Geometry.Density == "" {
		s.Geometry.Density = d.Geometry.Density
	}
	if s.Geometry.SectionGap == 0 {
		s.Geometry.SectionGap = d.Geometry.SectionGap
	}
	if s.Geometry.LengthMode == "" {
		s.Geometry.LengthMode = d.Geometry.LengthMode
	}
	if s.Geometry.Alignment == "" {
		s.Geometry.Alignment = d.Geometry.Alignment
	}
	if s.Attention.Mode == "" {
		s.Attention.Mode = d.Attention.Mode
	}
	if s.Behavior.Visibility == "" {
		s.Behavior.Visibility = d.Behavior.Visibility
	}
	if s.Behavior.ExclusiveZone == "" {
		s.Behavior.ExclusiveZone = d.Behavior.ExclusiveZone
	}
	if s.Behavior.HideDelayMs == 0 {
		s.Behavior.HideDelayMs = d.Behavior.HideDelayMs
	}
	if s.Behavior.RevealDelayMs == 0 {
		s.Behavior.RevealDelayMs = d.Behavior.RevealDelayMs
	}
	if s.Behavior.EdgeSensor == 0 {
		s.Behavior.EdgeSensor = d.Behavior.EdgeSensor
	}
	if s.Regions.Left.Mode == "" {
		s.Regions.Left.Mode = d.Regions.Left.Mode
	}
	if s.Regions.Center.Mode == "" {
		s.Regions.Center.Mode = d.Regions.Center.Mode
	}
	if s.Regions.Right.Mode == "" {
		s.Regions.Right.Mode = d.Regions.Right.Mode
	}
	if s.Workspace.Mode == "" {
		s.Workspace.Mode = d.Workspace.Mode
	}
	if s.Clock.Style == "" {
		s.Clock.Style = d.Clock.Style
	}
	if s.Motion.Preset == "" {
		s.Motion.Preset = d.Motion.Preset
	}
	if s.Motion.DurationMs == 0 {
		s.Motion.DurationMs = d.Motion.DurationMs
	}
	if s.Motion.Easing == "" {
		s.Motion.Easing = d.Motion.Easing
	}
	return s
}

func (s BarSpec) Validate() error {
	s = s.Normalize()
	if s.Version != SchemaVersion {
		return fmt.Errorf("unsupported bar spec version %d", s.Version)
	}
	if !oneOf(string(s.Engine), string(EngineAuto), string(EngineNative), string(EngineOmagen)) {
		return fmt.Errorf("invalid bar engine %q", s.Engine)
	}
	if !oneOf(s.Preset, "native", "float", "float-expanded", "sections", "islands", "dock", "minimal", "split", "notch", "rail", "custom") {
		return fmt.Errorf("invalid bar preset %q", s.Preset)
	}
	if !oneOf(string(s.Topology), "continuous", "floating", "sections", "islands", "dock", "split", "minimal", "notch", "rail") {
		return fmt.Errorf("invalid bar topology %q", s.Topology)
	}
	if !oneOf(string(s.Position), "top", "bottom", "left", "right") {
		return fmt.Errorf("invalid bar position %q", s.Position)
	}
	if !oneOf(s.Surface.Treatment, "preset", "opaque", "metal", "glass", "clear") {
		return fmt.Errorf("invalid bar surface treatment %q", s.Surface.Treatment)
	}
	if !oneOf(s.Surface.Role, "native", "background", "dark", "light", "accent", "selection", "transparent", "custom") {
		return fmt.Errorf("invalid bar surface role %q", s.Surface.Role)
	}
	if s.Surface.Opacity < 0 || s.Surface.Opacity > 1 || s.Surface.BorderOpacity < 0 || s.Surface.BorderOpacity > 1 {
		return fmt.Errorf("bar surface opacity out of range")
	}
	if s.Surface.Blur < 0 || s.Surface.Blur > 64 || s.Surface.BorderWidth < 0 || s.Surface.BorderWidth > 8 {
		return fmt.Errorf("bar surface dimensions out of range")
	}
	if !oneOf(s.Surface.BorderRole, "none", "foreground", "accent", "custom") || !oneOf(s.Surface.Shadow, "none", "flat", "raised", "floating") {
		return fmt.Errorf("invalid bar surface treatment")
	}
	if !oneOf(s.Geometry.Density, "native", "compact", "comfortable") || s.Geometry.Thickness < 0 || s.Geometry.Thickness > 128 || s.Geometry.EdgeOffset < 0 || s.Geometry.EdgeOffset > 128 || s.Geometry.OuterMargin < 0 || s.Geometry.OuterMargin > 128 || s.Geometry.InnerPadding < 0 || s.Geometry.InnerPadding > 64 || s.Geometry.SectionGap < 0 || s.Geometry.SectionGap > 128 || s.Geometry.WidgetGap < 0 || s.Geometry.WidgetGap > 64 || s.Geometry.Radius < 0 || s.Geometry.Radius > 64 {
		return fmt.Errorf("bar geometry out of range")
	}
	if !oneOf(s.Geometry.LengthMode, "full", "content", "percentage", "fixed") || (s.Geometry.LengthMode == "percentage" && (s.Geometry.LengthValue < 1 || s.Geometry.LengthValue > 100)) || (s.Geometry.LengthMode == "fixed" && (s.Geometry.LengthValue < 1 || s.Geometry.LengthValue > 8192)) {
		return fmt.Errorf("invalid bar length")
	}
	if !oneOf(s.Geometry.Alignment, "start", "center", "end") {
		return fmt.Errorf("invalid bar alignment %q", s.Geometry.Alignment)
	}
	if !oneOf(s.Attention.Mode, "semantic", "accent") {
		return fmt.Errorf("invalid bar attention mode %q", s.Attention.Mode)
	}
	if !oneOf(s.Behavior.Visibility, "always", "fullscreen", "auto_hide", "hover") || !oneOf(s.Behavior.ExclusiveZone, "reserve", "overlay", "smart") || s.Behavior.HideDelayMs < 0 || s.Behavior.HideDelayMs > 60000 || s.Behavior.RevealDelayMs < 0 || s.Behavior.RevealDelayMs > 60000 || s.Behavior.EdgeSensor < 0 || s.Behavior.EdgeSensor > 32 {
		return fmt.Errorf("invalid bar behavior")
	}
	for name, region := range map[string]RegionBehavior{"left": s.Regions.Left, "center": s.Regions.Center, "right": s.Regions.Right} {
		if !oneOf(region.Mode, "native", "island", "quiet", "hidden") {
			return fmt.Errorf("invalid bar %s region mode %q", name, region.Mode)
		}
	}
	if !oneOf(s.Workspace.Mode, "native", "numbers", "kanji", "roman", "letters", "dots", "glyphs") {
		return fmt.Errorf("invalid workspace presentation %q", s.Workspace.Mode)
	}
	if len(s.Workspace.Glyphs) > 5 {
		return fmt.Errorf("too many workspace glyphs")
	}
	for _, glyph := range s.Workspace.Glyphs {
		if !utf8.ValidString(glyph) || utf8.RuneCountInString(glyph) > 4 {
			return fmt.Errorf("invalid workspace glyph")
		}
	}
	if s.Workspace.Mode == "glyphs" && len(s.Workspace.Glyphs) == 0 {
		return fmt.Errorf("custom workspace glyphs are empty")
	}
	if !oneOf(s.Clock.Style, "native", "neon", "matrix", "lcd") {
		return fmt.Errorf("invalid clock style %q", s.Clock.Style)
	}
	if !oneOf(s.Motion.Preset, "native", "none", "subtle", "smooth", "expressive", "cyberpunk") || s.Motion.DurationMs < 0 || s.Motion.DurationMs > 2000 || !oneOf(s.Motion.Easing, "linear", "out_cubic", "out_quart", "in_out_cubic") {
		return fmt.Errorf("invalid bar motion")
	}
	return nil
}

func (s BarSpec) Valid() bool { return s.Validate() == nil }

type CompileResult struct {
	Spec         BarSpec `json:"spec"`
	Engine       Engine  `json:"engine"`
	Native       bool    `json:"native"`
	Capabilities struct {
		Surface   bool `json:"surface"`
		Topology  bool `json:"topology"`
		Behavior  bool `json:"behavior"`
		Regions   bool `json:"regions"`
		Workspace bool `json:"workspace"`
		Clock     bool `json:"clock"`
	} `json:"capabilities"`
}

// Compile selects the least invasive reader that can express the requested
// spec. Explicit native requests fail for unsupported topology/behaviour so
// the UI cannot silently claim a native result it cannot produce.
func Compile(spec BarSpec) (CompileResult, error) {
	spec = spec.Normalize()
	if err := spec.Validate(); err != nil {
		return CompileResult{}, err
	}
	// The root Quattro shell reader can express the continuous native bar and
	// Minimal is an Omagen replacement because its hover expansion changes the
	// widget host geometry; it must not be mislabeled as native output.
	nativeTopology := oneOf(string(spec.Topology), "continuous")
	// A blurred bar remains native-capable: Hyprland owns the backdrop blur on
	// the bar's layer namespace while Quattro continues to own widgets, order,
	// drag/reorder, focus, and input. Only local border/shadow decoration needs
	// the Omagen replacement surface.
	nativeSurface := oneOf(spec.Surface.Role, "native", "background", "dark", "light", "accent", "transparent") &&
		spec.Surface.BorderRole == "none" && spec.Surface.BorderOpacity == 0 && spec.Surface.BorderWidth == 0 && spec.Surface.Shadow == "none"
	nativeGeometry := spec.Position == PositionTop &&
		spec.Geometry.EdgeOffset == 0 && spec.Geometry.OuterMargin == 0 && spec.Geometry.InnerPadding == 0 &&
		spec.Geometry.SectionGap == Default().Geometry.SectionGap && spec.Geometry.WidgetGap == 0 && spec.Geometry.Radius == 0 &&
		oneOf(spec.Geometry.LengthMode, "full") && spec.Geometry.LengthValue == 0 && spec.Geometry.Alignment == "center"
	nativeBehavior := spec.Behavior.Visibility == "always" && !spec.Behavior.HoverExpand && spec.Behavior.ExclusiveZone == "reserve"
	nativeRegions := spec.Regions.Left.Mode == "native" && spec.Regions.Center.Mode == "native" && spec.Regions.Right.Mode == "native"
	nativeWorkspace := spec.Workspace.Mode == "native" && len(spec.Workspace.Glyphs) == 0
	nativeClock := spec.Clock.Style == "native"
	nativeMotion := spec.Motion.Preset == "native" && spec.Motion.DurationMs == Default().Motion.DurationMs && spec.Motion.Easing == Default().Motion.Easing
	needsOmagen := !nativeTopology || !nativeSurface || !nativeGeometry || !nativeBehavior || !nativeRegions || !nativeWorkspace || !nativeClock || !nativeMotion
	engine := spec.Engine
	if engine == EngineAuto {
		if needsOmagen {
			engine = EngineOmagen
		} else {
			engine = EngineNative
		}
	}
	if engine == EngineNative && needsOmagen {
		return CompileResult{}, fmt.Errorf("bar spec requires Omagen engine")
	}
	result := CompileResult{Spec: spec, Engine: engine, Native: engine == EngineNative}
	result.Capabilities.Surface = nativeSurface
	result.Capabilities.Topology = nativeTopology
	result.Capabilities.Behavior = nativeBehavior
	result.Capabilities.Regions = nativeRegions
	result.Capabilities.Workspace = nativeWorkspace
	result.Capabilities.Clock = nativeClock
	return result, nil
}

func Presets() []string {
	return []string{"native", "float", "float-expanded", "sections", "islands", "dock", "minimal", "split", "notch", "rail"}
}

func Preset(name string) (BarSpec, error) {
	s := Default()
	s.Preset = name
	switch name {
	case "native":
	case "float":
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyFloating, "background", .88, "foreground", .3, 1, "raised"
		s.Geometry.Density = "compact"
		s.Geometry.EdgeOffset, s.Geometry.OuterMargin, s.Geometry.Radius = 8, 8, 14
	case "float-expanded":
		// Keep the native three-section composition and native tray drawer,
		// changing only the host surface: a centered floating pill whose tray
		// expands leftward from the right edge on hover.
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyFloating, "background", .88, "foreground", .3, 1, "raised"
		s.Geometry.Density = "native"
		s.Geometry.EdgeOffset, s.Geometry.OuterMargin, s.Geometry.Radius = 8, 8, 14
		s.Behavior.HoverExpand = true
	case "sections":
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth = TopologySections, "dark", .9, "accent", .35, 1
		s.Geometry.SectionGap, s.Geometry.Radius = 10, 14
	case "islands":
		s.Topology, s.Engine, s.Surface.Role, s.Surface.Opacity, s.Surface.Blur, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyIslands, EngineOmagen, "native", 1, 0, "foreground", .35, 1, "none"
	case "dock":
		s.Topology, s.Engine, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyDock, EngineOmagen, "dark", .9, 1, "floating"
		s.Geometry.LengthMode, s.Geometry.Alignment, s.Geometry.Radius, s.Behavior.Visibility, s.Behavior.HoverExpand = "content", "center", 16, "auto_hide", true
	case "minimal":
		s.Topology, s.Engine = TopologyMinimal, EngineOmagen
		s.Surface = Surface{Treatment: "preset", Role: "native", Opacity: 1, BorderRole: "foreground", BorderOpacity: .35, BorderWidth: 1, Shadow: "none"}
		s.Geometry.Density = "compact"
		s.Behavior.HoverExpand = true
		s.Motion = Motion{Preset: "smooth", DurationMs: 260, Easing: "out_cubic"}
	case "split":
		s.Topology, s.Engine, s.Surface.Role = TopologySplit, EngineOmagen, "dark"
	case "notch":
		s.Topology, s.Engine, s.Surface.Role, s.Geometry.Radius = TopologyNotch, EngineOmagen, "dark", 14
	case "rail":
		s.Topology, s.Engine, s.Position, s.Surface.Role = TopologyRail, EngineOmagen, PositionLeft, "dark"
	default:
		return BarSpec{}, fmt.Errorf("unknown bar preset %q", name)
	}
	return s.Normalize(), nil
}

func (s BarSpec) JSON() ([]byte, error) { return json.MarshalIndent(s.Normalize(), "", "  ") }

func oneOf(value string, choices ...string) bool {
	for _, choice := range choices {
		if value == choice {
			return true
		}
	}
	return false
}
