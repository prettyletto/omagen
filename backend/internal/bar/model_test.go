package bar

import "testing"

func TestPresetCompilationSelectsNativeOrOmagen(t *testing.T) {
	native, err := Preset("native")
	if err != nil {
		t.Fatal(err)
	}
	compiled, err := Compile(native)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineNative || !compiled.Capabilities.Topology || !compiled.Capabilities.Clock {
		t.Fatalf("native compilation = %#v", compiled)
	}
	sections, err := Preset("sections")
	if err != nil {
		t.Fatal(err)
	}
	compiled, err = Compile(sections)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("sections compilation = %#v", compiled)
	}

	dock, err := Preset("dock")
	if err != nil {
		t.Fatal(err)
	}
	compiled, err = Compile(dock)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("dock compilation = %#v", compiled)
	}

	islands, err := Preset("islands")
	if err != nil {
		t.Fatal(err)
	}
	if islands.Topology != TopologyIslands || islands.Engine != EngineOmagen {
		t.Fatalf("islands preset = %#v", islands)
	}
	compiled, err = Compile(islands)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("islands compilation = %#v", compiled)
	}

	minimal, err := Preset("minimal")
	if err != nil {
		t.Fatal(err)
	}
	if minimal.Topology != TopologyMinimal || minimal.Engine != EngineOmagen || !minimal.Behavior.HoverExpand || minimal.Surface.Role != "native" || minimal.Surface.Opacity != 1 {
		t.Fatalf("minimal preset = %#v", minimal)
	}
	compiled, err = Compile(minimal)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("minimal compilation = %#v", compiled)
	}
}

func TestExplicitNativeRejectsAdvancedBehavior(t *testing.T) {
	spec := Default()
	spec.Engine = EngineNative
	spec.Behavior.Visibility = "auto_hide"
	if _, err := Compile(spec); err == nil {
		t.Fatal("native engine accepted auto-hide")
	}
}

func TestAutoHideUsesFixedFiveSecondDelay(t *testing.T) {
	spec := Default()
	spec.Behavior.Visibility = "auto_hide"
	spec.Behavior.HideDelayMs = 250

	normalized := spec.Normalize()
	if normalized.Behavior.HideDelayMs != AutoHideDelayMs {
		t.Fatalf("auto-hide delay = %d, want %d", normalized.Behavior.HideDelayMs, AutoHideDelayMs)
	}
}

func TestClockStylesUseOmagenWithoutChangingNativeClockBehavior(t *testing.T) {
	if spec := Default(); spec.Clock.Style != "native" {
		t.Fatalf("default clock style = %q, want native", spec.Clock.Style)
	}

	for _, style := range []string{"neon", "matrix", "lcd", "classical", "gothic"} {
		t.Run(style, func(t *testing.T) {
			spec := Default()
			spec.Clock.Style = style
			compiled, err := Compile(spec)
			if err != nil {
				t.Fatal(err)
			}
			if compiled.Engine != EngineOmagen || compiled.Native {
				t.Fatalf("clock style %q compiled as native: %#v", style, compiled)
			}
			if compiled.Capabilities.Clock {
				t.Fatalf("clock style %q incorrectly reported native capability", style)
			}
		})
	}

	spec := Default()
	spec.Clock.Style = "unsupported"
	if err := spec.Validate(); err == nil {
		t.Fatal("unsupported clock style was accepted")
	}
}

func TestUnsupportedNativeSurfaceAndGeometrySelectOmagen(t *testing.T) {
	for name, mutate := range map[string]func(*BarSpec){
		"border": func(spec *BarSpec) {
			spec.Surface.BorderRole, spec.Surface.BorderOpacity, spec.Surface.BorderWidth = "foreground", .3, 1
		},
		"radius":   func(spec *BarSpec) { spec.Geometry.Radius = 12 },
		"position": func(spec *BarSpec) { spec.Position = PositionBottom },
		"motion":   func(spec *BarSpec) { spec.Motion.Preset = "smooth" },
	} {
		t.Run(name, func(t *testing.T) {
			spec := Default()
			mutate(&spec)
			compiled, err := Compile(spec)
			if err != nil {
				t.Fatal(err)
			}
			if compiled.Engine != EngineOmagen || compiled.Native {
				t.Fatalf("unsupported native field compiled as native: %#v", compiled)
			}
		})
	}
}

func TestGlassSurfaceKeepsContinuousBarNative(t *testing.T) {
	spec := Default()
	spec.Surface.Treatment = "glass"
	spec.Surface.Role = "background"
	spec.Surface.Opacity = 0.72
	spec.Surface.Blur = 1
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineNative || !compiled.Native || !compiled.Capabilities.Surface {
		t.Fatalf("glass surface should remain native-capable: %#v", compiled)
	}
}

func TestMetalSurfaceKeepsContinuousBarNative(t *testing.T) {
	spec := Default()
	spec.Surface.Treatment = "metal"
	spec.Surface.Role = "dark"
	spec.Surface.Opacity = 0.94
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineNative || !compiled.Native || !compiled.Capabilities.Surface {
		t.Fatalf("metal surface should remain native-capable: %#v", compiled)
	}
}

func TestRegionSurfaceModesAreValidatedAndAdapterBound(t *testing.T) {
	spec := Default()
	spec.Regions.Center.Mode = "island"
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("region decoration compiled as native: %#v", compiled)
	}
	spec.Regions.Left.Mode = "unsupported"
	if err := spec.Validate(); err == nil {
		t.Fatal("unsupported region mode was accepted")
	}
}

func TestDockAlignmentAndWorkspaceGlyphsAreValidatedAndAdapterBound(t *testing.T) {
	spec := Default()
	spec.Topology = TopologyDock
	spec.Geometry.LengthMode = "content"
	spec.Geometry.Alignment = "start"
	spec.Workspace = WorkspacePresentation{Mode: "glyphs", Glyphs: []string{"一", "二", "三"}}
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("custom dock compiled as native: %#v", compiled)
	}

	spec.Geometry.Alignment = "middle"
	if err := spec.Validate(); err == nil {
		t.Fatal("invalid dock alignment was accepted")
	}
	spec.Geometry.Alignment = "center"
	spec.Workspace.Glyphs = []string{"this-is-too-long"}
	if err := spec.Validate(); err == nil {
		t.Fatal("oversized workspace glyph was accepted")
	}
}

func TestWorkspacePresentationModesAreAccepted(t *testing.T) {
	for _, mode := range []string{"native", "numbers", "kanji", "roman", "letters", "dots"} {
		spec := Default()
		spec.Workspace.Mode = mode
		if err := spec.Validate(); err != nil {
			t.Fatalf("workspace mode %q rejected: %v", mode, err)
		}
	}

	spec := Default()
	spec.Workspace = WorkspacePresentation{Mode: "glyphs", Glyphs: []string{"①", "②", "③", "④", "⑤"}}
	if err := spec.Validate(); err != nil {
		t.Fatalf("five custom workspace glyphs rejected: %v", err)
	}
	spec.Workspace.Glyphs = append(spec.Workspace.Glyphs, "⑥")
	if err := spec.Validate(); err == nil {
		t.Fatal("more than five custom workspace glyphs were accepted")
	}
}

func TestJapaneseKanjiWorkspacePresentationUsesOmagenLabels(t *testing.T) {
	spec := Default()
	spec.Workspace.Mode = "kanji"
	if err := spec.Validate(); err != nil {
		t.Fatalf("Japanese Kanji workspace presentation rejected: %v", err)
	}
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native || compiled.Capabilities.Workspace {
		t.Fatalf("Japanese Kanji workspace presentation should use the Omagen reader: %#v", compiled)
	}
}

func TestPresetNamesAreStable(t *testing.T) {
	for _, name := range Presets() {
		spec, err := Preset(name)
		if err != nil {
			t.Fatalf("preset %q: %v", name, err)
		}
		if err := spec.Validate(); err != nil {
			t.Fatalf("preset %q invalid: %v", name, err)
		}
	}
}

func TestFloatingPresetUsesCompactDensity(t *testing.T) {
	spec, err := Preset("float")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Topology != TopologyFloating || spec.Geometry.Density != "compact" {
		t.Fatalf("floating preset should be compact: %#v", spec)
	}
}

func TestFloatingExpandedPresetUsesNativeTrayComposition(t *testing.T) {
	spec, err := Preset("float-expanded")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Topology != TopologyFloating || spec.Geometry.Density != "native" || !spec.Behavior.HoverExpand {
		t.Fatalf("floating expanded preset should retain native tray behavior: %#v", spec)
	}
}

func TestOrbitPresetUsesFloatingCompactComposition(t *testing.T) {
	spec, err := Preset("orbit")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Topology != TopologyFloating || spec.Engine != EngineOmagen || spec.Geometry.Density != "compact" || spec.Surface.BorderRole != "accent" || spec.Surface.Opacity != 1 {
		t.Fatalf("orbit preset should use a compact floating composition: %#v", spec)
	}
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("orbit compilation = %#v", compiled)
	}
}

func TestRibbonPresetUsesSectionComposition(t *testing.T) {
	spec, err := Preset("ribbon")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Topology != TopologySections || spec.Engine != EngineOmagen || spec.Geometry.SectionGap != 2 || spec.Surface.BorderRole != "accent" {
		t.Fatalf("ribbon preset should use a connected section composition: %#v", spec)
	}
	compiled, err := Compile(spec)
	if err != nil {
		t.Fatal(err)
	}
	if compiled.Engine != EngineOmagen || compiled.Native {
		t.Fatalf("ribbon compilation = %#v", compiled)
	}
}

func TestDockPresetUsesAutoHideContentSizedOmagenComposition(t *testing.T) {
	spec, err := Preset("dock")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Topology != TopologyDock || spec.Engine != EngineOmagen || spec.Geometry.LengthMode != "content" || spec.Geometry.Alignment != "center" || spec.Behavior.Visibility != "auto_hide" || spec.Behavior.HideDelayMs != AutoHideDelayMs || !spec.Behavior.HoverExpand {
		t.Fatalf("dock preset should be centered, content-sized, and hover-expanded: %#v", spec)
	}
}

func TestDockClosedPresentationDefaultsAndValidation(t *testing.T) {
	spec, err := Preset("dock")
	if err != nil {
		t.Fatal(err)
	}
	if spec.Dock.Closed != "ellipsis" || spec.Dock.Glyph != "✦" {
		t.Fatalf("dock closed presentation = %#v", spec.Dock)
	}

	for _, mode := range []string{"workspace", "ellipsis", "clock", "glyph"} {
		t.Run(mode, func(t *testing.T) {
			candidate := spec
			candidate.Dock.Closed = mode
			if err := candidate.Validate(); err != nil {
				t.Fatalf("dock closed mode %q rejected: %v", mode, err)
			}
		})
	}

	invalid := spec
	invalid.Dock.Closed = "unsupported"
	if err := invalid.Validate(); err == nil {
		t.Fatal("unsupported dock closed mode was accepted")
	}

	invalid = spec
	invalid.Dock.Closed = "glyph"
	invalid.Dock.Glyph = ""
	if err := invalid.Validate(); err == nil {
		t.Fatal("empty custom dock glyph was accepted")
	}

	invalid.Dock.Glyph = "12345"
	if err := invalid.Validate(); err == nil {
		t.Fatal("oversized custom dock glyph was accepted")
	}
}
