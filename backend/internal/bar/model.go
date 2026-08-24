package bar

import (
	"encoding/json"
	"fmt"
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

// BarSpec is the shared document consumed by the preview and by the native /
// Omagen compiler. It deliberately has no widget layout field: shell.json is
// a user-owned canonical document and must only change after an explicit
// layout edit.
type BarSpec struct {
	Version   int       `json:"version"`
	Engine    Engine    `json:"engine"`
	Topology  Topology  `json:"topology"`
	Position  Position  `json:"position"`
	Surface   Surface   `json:"surface"`
	Geometry  Geometry  `json:"geometry"`
	Attention Attention `json:"attention"`
	Behavior  Behavior  `json:"behavior"`
	Motion    Motion    `json:"motion"`
}

func Default() BarSpec {
	return BarSpec{
		Version: SchemaVersion,
		Engine:  EngineAuto, Topology: TopologyContinuous, Position: PositionTop,
		Surface:   Surface{Role: "native", Opacity: 1, BorderRole: "none", Shadow: "none"},
		Geometry:  Geometry{Density: "native", SectionGap: 8, LengthMode: "full"},
		Attention: Attention{Mode: "semantic"},
		Behavior:  Behavior{Visibility: "always", ExclusiveZone: "reserve", HideDelayMs: 500, RevealDelayMs: 50, EdgeSensor: 3, KeepVisibleWhilePopupOpen: true},
		Motion:    Motion{Preset: "native", DurationMs: 180, Easing: "out_cubic"},
	}
}

func (s BarSpec) Normalize() BarSpec {
	d := Default()
	if s.Version == 0 {
		s.Version = d.Version
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
	if !oneOf(string(s.Topology), "continuous", "floating", "sections", "islands", "dock", "split", "minimal", "notch", "rail") {
		return fmt.Errorf("invalid bar topology %q", s.Topology)
	}
	if !oneOf(string(s.Position), "top", "bottom", "left", "right") {
		return fmt.Errorf("invalid bar position %q", s.Position)
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
	if !oneOf(s.Attention.Mode, "semantic", "accent") {
		return fmt.Errorf("invalid bar attention mode %q", s.Attention.Mode)
	}
	if !oneOf(s.Behavior.Visibility, "always", "fullscreen", "auto_hide", "hover") || !oneOf(s.Behavior.ExclusiveZone, "reserve", "overlay", "smart") || s.Behavior.HideDelayMs < 0 || s.Behavior.HideDelayMs > 60000 || s.Behavior.RevealDelayMs < 0 || s.Behavior.RevealDelayMs > 60000 || s.Behavior.EdgeSensor < 0 || s.Behavior.EdgeSensor > 32 {
		return fmt.Errorf("invalid bar behavior")
	}
	if !oneOf(s.Motion.Preset, "native", "none", "subtle", "smooth", "expressive") || s.Motion.DurationMs < 0 || s.Motion.DurationMs > 2000 || !oneOf(s.Motion.Easing, "linear", "out_cubic", "out_quart", "in_out_cubic") {
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
		Surface  bool `json:"surface"`
		Topology bool `json:"topology"`
		Behavior bool `json:"behavior"`
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
	// the minimal transparent variant. Floating/sectioned/dock/rail shapes and
	// fields with no Quattro token are additive Omagen decorations and must not
	// be mislabeled as native output.
	nativeTopology := oneOf(string(spec.Topology), "continuous", "minimal")
	nativeSurface := oneOf(spec.Surface.Role, "native", "background", "dark", "light", "accent", "transparent") &&
		spec.Surface.Blur == 0 && spec.Surface.BorderRole == "none" && spec.Surface.BorderOpacity == 0 && spec.Surface.BorderWidth == 0 && spec.Surface.Shadow == "none"
	nativeGeometry := spec.Position == PositionTop &&
		spec.Geometry.EdgeOffset == 0 && spec.Geometry.OuterMargin == 0 && spec.Geometry.InnerPadding == 0 &&
		spec.Geometry.SectionGap == Default().Geometry.SectionGap && spec.Geometry.WidgetGap == 0 && spec.Geometry.Radius == 0 &&
		oneOf(spec.Geometry.LengthMode, "full") && spec.Geometry.LengthValue == 0
	nativeBehavior := spec.Behavior.Visibility == "always" && !spec.Behavior.HoverExpand && spec.Behavior.ExclusiveZone == "reserve"
	nativeMotion := spec.Motion.Preset == "native" && spec.Motion.DurationMs == Default().Motion.DurationMs && spec.Motion.Easing == Default().Motion.Easing
	needsOmagen := !nativeTopology || !nativeSurface || !nativeGeometry || !nativeBehavior || !nativeMotion
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
	return result, nil
}

func Presets() []string {
	return []string{"native", "float", "sections", "glass-islands", "dock", "minimal", "split", "notch", "rail"}
}

func Preset(name string) (BarSpec, error) {
	s := Default()
	switch name {
	case "native":
	case "float":
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyFloating, "background", .88, "foreground", .3, 1, "raised"
		s.Geometry.EdgeOffset, s.Geometry.OuterMargin, s.Geometry.Radius = 8, 8, 14
	case "sections":
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth = TopologySections, "dark", .9, "accent", .35, 1
		s.Geometry.SectionGap, s.Geometry.Radius = 10, 14
	case "glass-islands":
		s.Topology, s.Engine, s.Surface.Role, s.Surface.Opacity, s.Surface.Blur, s.Surface.BorderRole, s.Surface.BorderOpacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyIslands, EngineOmagen, "dark", .72, 18, "foreground", .35, 1, "floating"
	case "dock":
		s.Topology, s.Engine, s.Surface.Role, s.Surface.Opacity, s.Surface.BorderWidth, s.Surface.Shadow = TopologyDock, EngineOmagen, "dark", .9, 1, "floating"
		s.Geometry.LengthMode, s.Geometry.Radius, s.Behavior.Visibility = "content", 16, "auto_hide"
	case "minimal":
		s.Topology, s.Surface.Role, s.Surface.Opacity, s.Geometry.Density = TopologyMinimal, "transparent", 0, "compact"
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
