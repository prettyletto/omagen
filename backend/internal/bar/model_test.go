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
	if compiled.Engine != EngineNative || !compiled.Capabilities.Topology {
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
}

func TestExplicitNativeRejectsAdvancedBehavior(t *testing.T) {
	spec := Default()
	spec.Engine = EngineNative
	spec.Behavior.Visibility = "auto_hide"
	if _, err := Compile(spec); err == nil {
		t.Fatal("native engine accepted auto-hide")
	}
}

func TestUnsupportedNativeSurfaceAndGeometrySelectOmagen(t *testing.T) {
	for name, mutate := range map[string]func(*BarSpec){
		"blur": func(spec *BarSpec) { spec.Surface.Blur = 8 },
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
