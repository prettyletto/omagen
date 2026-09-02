package lookfeel

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestCatalogContainsStableInitialPresets(t *testing.T) {
	entries := Catalog()
	if len(entries) != 13 {
		t.Fatalf("catalog length = %d, want 13", len(entries))
	}
	want := []string{PresetNative, PresetGlassBlur, PresetFocused, PresetCyberpunk, PresetSpectral, PresetPhosphor, PresetRetro, PresetMonolith, PresetOrbit, PresetNature, PresetOriental, PresetGothic, PresetAcid}
	for index, id := range want {
		if entries[index].ID != id {
			t.Fatalf("catalog[%d] = %q, want %q", index, entries[index].ID, id)
		}
	}
	if entries[1].Revision != 9 || entries[2].Revision != 3 || entries[3].Revision != 7 || entries[4].Revision != 2 || entries[5].Revision != 3 || entries[6].Revision != 1 || entries[7].Revision != 4 || entries[8].Revision != 2 || entries[9].Revision != 4 || entries[10].Revision != 6 || entries[11].Revision != 3 || entries[12].Revision != 2 {
		t.Fatalf("catalog order = %#v", entries)
	}
}

func TestLocalPresetRoundTripAndCatalogMetadata(t *testing.T) {
	dir := t.TempDir()
	store := NewLocalStoreAt(dir)
	composition, err := Resolve(PresetNature)
	if err != nil {
		t.Fatal(err)
	}
	entry, err := store.Save("My Quiet Glass", composition)
	if err != nil {
		t.Fatal(err)
	}
	if entry.ID != "local-my-quiet-glass" || !entry.Local {
		t.Fatalf("saved entry = %#v", entry)
	}
	resolved, err := store.Resolve(entry.ID)
	if err != nil {
		t.Fatal(err)
	}
	if resolved.Preset != entry.ID || resolved.PresetRevision != 1 || !resolved.Customized["window"] || resolved.Bar.Spec == nil {
		t.Fatalf("resolved local recipe = %#v", resolved)
	}
	entries, err := store.List()
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Name != "My Quiet Glass" {
		t.Fatalf("local catalog = %#v", entries)
	}
	if _, err := os.Stat(filepath.Join(dir, "local-my-quiet-glass.json")); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Save("my quiet glass", composition); !errors.Is(err, fs.ErrExist) {
		t.Fatalf("duplicate save error = %v, want fs.ErrExist", err)
	}
}

func TestLocalPresetResolvesAndExportsThroughDefaultStore(t *testing.T) {
	config := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", config)
	store := NewLocalStoreAt(filepath.Join(config, "omagen", localPresetDirectory))
	composition, err := Resolve(PresetGlassBlur)
	if err != nil {
		t.Fatal(err)
	}
	entry, err := store.Save("Saved Glass", composition)
	if err != nil {
		t.Fatal(err)
	}
	resolved, err := Resolve(entry.ID)
	if err != nil || resolved.Preset != entry.ID {
		t.Fatalf("Resolve(%q) = %#v, %v", entry.ID, resolved, err)
	}
	manifest, err := Export(entry.ID)
	if err != nil || manifest.ID != entry.ID || manifest.Author != "Local" {
		t.Fatalf("Export(%q) = %#v, %v", entry.ID, manifest, err)
	}
}

func TestResolveCyberpunkGlitchComposesOrbitBarNeonClockAndGlitchMotion(t *testing.T) {
	composition, err := Resolve(PresetCyberpunk)
	if err != nil {
		t.Fatal(err)
	}
	if composition.PresetRevision != 7 || composition.Window.BorderStyle != "neon" || composition.Window.BorderSize != 4 || composition.Window.Shape != "rounded" || composition.Window.Inactive != "shadow_only" {
		t.Fatalf("cyberpunk window recipe = %#v", composition.Window)
	}
	if composition.Shell.Surface != "layered" || composition.Shell.Detail != "edge" || composition.Shell.Tooltip != "accent" || composition.Shell.Notifications != "accent" {
		t.Fatalf("cyberpunk shell recipe = %#v", composition.Shell)
	}
	if composition.Bar.Surface != "dark" || composition.Bar.Spec == nil || composition.Bar.Spec.Preset != "orbit" || composition.Bar.Spec.Topology != bar.TopologyFloating || composition.Bar.Spec.Surface.Treatment != "glass" || composition.Bar.Spec.Surface.Blur != 8 || composition.Bar.Spec.Motion.Preset != "cyberpunk" || composition.Bar.Spec.Behavior.HoverExpand != false {
		t.Fatalf("cyberpunk bar recipe = %#v", composition.Bar)
	}
	if composition.Bar.Profile == nil || composition.Bar.Profile.Behavior.Form != "floating" || composition.Bar.Profile.Behavior.Islands {
		t.Fatalf("cyberpunk bar profile = %#v", composition.Bar.Profile)
	}
	if composition.Bar.Spec.Workspace.Mode != "roman" || composition.Bar.Spec.Clock.Style != "neon" {
		t.Fatalf("cyberpunk workspace = %#v", composition.Bar.Spec.Workspace)
	}
	if composition.Animations.Preset != "cyberpunk" || composition.Animations.Glitch != "medium" || composition.Animations.Border != "static" || composition.Animations.WindowOpacity != 82 {
		t.Fatalf("cyberpunk motion recipe = %#v", composition.Animations)
	}
	if composition.Animations.Window != "digital" || composition.Animations.WindowOpen != "gnomed" || composition.Animations.WindowClose != "slide" || composition.Animations.WindowMove != "digital" || composition.Animations.Focus != "digital" || composition.Animations.Curve != "digital" {
		t.Fatalf("cyberpunk digital identity = %#v", composition.Animations)
	}
	if composition.Terminal.Mode != TerminalModePreserve || composition.Terminal.Opacity != 1 {
		t.Fatalf("cyberpunk terminal recipe = %#v", composition.Terminal)
	}
	if err := composition.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestResolveFocusedComposesGroundedDesktopShellBarAndMotion(t *testing.T) {
	composition, err := Resolve(PresetFocused)
	if err != nil {
		t.Fatal(err)
	}
	if composition.Window.BorderSizeMode != "fixed" || composition.Window.BorderSize != 2 || composition.Window.Shape != "rounded" || composition.Window.Inactive != "shadow_only" {
		t.Fatalf("focused window recipe = %#v", composition.Window)
	}
	if composition.Shell.Preset != session.ShellPresetDefault || composition.Shell.Surface != "contrast" || composition.Shell.Detail != "focus" {
		t.Fatalf("focused shell recipe = %#v", composition.Shell)
	}
	if composition.PresetRevision != 3 || composition.Bar.Spec == nil || composition.Bar.Spec.Topology != bar.TopologyDock || composition.Bar.Spec.Engine != bar.EngineOmagen || composition.Bar.Spec.Behavior.Visibility != "auto_hide" || !composition.Bar.Spec.Behavior.HoverExpand || composition.Bar.Spec.Dock.Closed != "clock" {
		t.Fatalf("focused bar recipe = %#v", composition.Bar)
	}
	if composition.Bar.Profile == nil || composition.Bar.Profile.Behavior.Form != "dock" || composition.Bar.Profile.Behavior.Visibility != "auto-hide" {
		t.Fatalf("focused bar profile = %#v", composition.Bar.Profile)
	}
	if composition.Bar.Spec.Workspace.Mode != "numbers" {
		t.Fatalf("focused workspace = %#v", composition.Bar.Spec.Workspace)
	}
	if composition.Animations.Preset != "snappy" || composition.Terminal.Mode != TerminalModePreserve || composition.Terminal.Opacity != 1 {
		t.Fatalf("focused motion/terminal recipe = %#v %#v", composition.Animations, composition.Terminal)
	}
	if composition.Animations.WindowAmount != 97 || composition.Animations.WindowSpeed != 1 || composition.Animations.Workspace != "fade" || composition.Animations.WindowMove != "quick" || composition.Animations.Curve != "precision" {
		t.Fatalf("focused precision identity = %#v", composition.Animations)
	}
	if err := composition.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestResolveNativeIsNoOpAndPortable(t *testing.T) {
	composition, err := Resolve(PresetNative)
	if err != nil {
		t.Fatal(err)
	}
	if composition.Terminal.Mode != TerminalModePreserve || composition.Terminal.Opacity != 1 {
		t.Fatalf("native terminal intent = %#v", composition.Terminal)
	}
	if composition.Shell.Preset != "default" || composition.Window.Active != "native" || composition.Bar.Spec != nil {
		t.Fatalf("native composition introduced behavior: %#v", composition)
	}
	if err := composition.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestResolveGlassBlurComposesFourEnginesAndTerminalIntent(t *testing.T) {
	composition, err := Resolve(PresetGlassBlur)
	if err != nil {
		t.Fatal(err)
	}
	if composition.PresetRevision != 9 || composition.Window.WindowOpacity == nil || *composition.Window.WindowOpacity != 82 || composition.Window.Active != "frosted_light" || composition.Window.Inactive != "frosted_light" {
		t.Fatalf("window glass recipe = %#v", composition.Window)
	}
	if composition.Shell.Preset != "glass" || composition.Shell.Detail != "edge" {
		t.Fatalf("shell glass recipe = %#v", composition.Shell)
	}
	if composition.Bar.Spec == nil || composition.Bar.Spec.Topology != "floating" || composition.Bar.Spec.Surface.Treatment != "glass" {
		t.Fatalf("bar glass recipe = %#v", composition.Bar)
	}
	if composition.Bar.Profile == nil || composition.Bar.Profile.Implementation != "replacement" || string(composition.Bar.Profile.Bar) != `{"id":"pretty.omagen.bar"}` || composition.Bar.Profile.Behavior.Form != "floating" {
		t.Fatalf("bar glass runtime profile = %#v", composition.Bar.Profile)
	}
	if composition.Bar.Spec.Workspace.Mode != "dots" || composition.Bar.Spec.Clock.Style != "lcd" {
		t.Fatalf("glass workspace = %#v", composition.Bar.Spec.Workspace)
	}
	if composition.Animations.Preset != "smooth" {
		t.Fatalf("animation glass recipe = %#v", composition.Animations)
	}
	if composition.Animations.WindowAmount != 82 || composition.Animations.WindowSpeed != 4 || composition.Animations.Workspace != "slidefade" || composition.Animations.WorkspaceTravel != 22 || composition.Animations.Curve != "glass" {
		t.Fatalf("glass floating identity = %#v", composition.Animations)
	}
	if composition.Terminal.Mode != TerminalModePreset || composition.Terminal.Opacity != 0.82 || composition.Terminal.CellMode != TerminalCellPainted {
		t.Fatalf("terminal glass recipe = %#v", composition.Terminal)
	}
	if err := composition.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestResolveNewRecipesHaveDistinctPortableIdentities(t *testing.T) {
	tests := []struct {
		id, workspace, barPreset, clock, effect string
		revision                                int
	}{
		{PresetSpectral, "letters", "ribbon", "lcd", "spectral-shift", 2},
		{PresetPhosphor, "glyphs", "minimal", "matrix", "phosphor-scan", 3},
		{PresetRetro, "glyphs", "minimal", "lcd", "retro-vhs", 1},
		{PresetMonolith, "glyphs", "islands", "gothic", "none", 4},
		{PresetOrbit, "glyphs", "orbit", "lcd", "none", 2},
		{PresetNature, "glyphs", "islands", "classical", "none", 4},
		{PresetOriental, "kanji", "zen", "classical", "none", 6},
		{PresetGothic, "glyphs", "cathedral", "gothic", "none", 3},
		{PresetAcid, "glyphs", "pulse", "native", "none", 2},
	}
	for _, test := range tests {
		t.Run(test.id, func(t *testing.T) {
			composition, err := Resolve(test.id)
			if err != nil {
				t.Fatal(err)
			}
			if composition.PresetRevision != test.revision || composition.Bar.Spec == nil || composition.Bar.Spec.Preset != test.barPreset || composition.Bar.Spec.Workspace.Mode != test.workspace || composition.Bar.Spec.Clock.Style != test.clock {
				t.Fatalf("workspace = %#v, want %q", composition.Bar.Spec, test.workspace)
			}
			if got := composition.Animations.EffectiveScreenEffect().ID; got != test.effect {
				t.Fatalf("effect = %q, want %q", got, test.effect)
			}
			if err := composition.Validate(); err != nil {
				t.Fatal(err)
			}
		})
	}
	nature, err := Resolve(PresetNature)
	if err != nil {
		t.Fatal(err)
	}
	if nature.PresetRevision != 4 || nature.Window.Active != "frosted_light" || nature.Window.Inactive != "frosted_balanced" || nature.Bar.Spec.Preset != "islands" || nature.Bar.Spec.Topology != bar.TopologyIslands || !reflect.DeepEqual(nature.Bar.Spec.Workspace.Glyphs, []string{"", "", "", "", ""}) || nature.Animations.Curve != "spring" || nature.Shell.Preset != session.ShellPresetGlass {
		t.Fatalf("nature identity = %#v", nature)
	}
	oriental, err := Resolve(PresetOriental)
	if err != nil {
		t.Fatal(err)
	}
	if oriental.Window.BorderStyle != "split_top" || oriental.Window.Depth != "flat" || oriental.Window.Active != "native" || oriental.Window.Inactive != "frosted_rich" {
		t.Fatalf("oriental window identity = %#v", oriental.Window)
	}
	if oriental.Shell.Preset != session.ShellPresetGlass || oriental.Shell.Detail != "framed" || oriental.Shell.Notifications != "accent" {
		t.Fatalf("oriental shell identity = %#v", oriental.Shell)
	}
	if oriental.PresetRevision != 6 || oriental.Bar.Spec.Topology != bar.TopologyIslands || oriental.Bar.Spec.Preset != "zen" || oriental.Bar.Spec.Workspace.Mode != "kanji" || oriental.Bar.Spec.Geometry.Density != "compact" {
		t.Fatalf("oriental bar identity = %#v", oriental.Bar.Spec)
	}
	if oriental.Animations.WindowOpen != "slide" || oriental.Animations.WindowClose != "fade" || oriental.Animations.Workspace != "slidefade" || oriental.Animations.WorkspaceAxis != "horizontal" || oriental.Animations.Curve != "glass" {
		t.Fatalf("oriental motion identity = %#v", oriental.Animations)
	}
	if oriental.Animations.EffectiveScreenEffect().ID != "none" {
		t.Fatalf("oriental unexpectedly enables a screen effect: %#v", oriental.Animations.EffectiveScreenEffect())
	}
}

func TestResolveGothicAndAcidHaveDistinctPortableIdentities(t *testing.T) {
	gothic, err := Resolve(PresetGothic)
	if err != nil {
		t.Fatal(err)
	}
	if gothic.PresetRevision != 3 || gothic.Window.BorderStyle != "split_top" || gothic.Window.BorderSize != 3 || gothic.Window.Shape != "soft" || gothic.Window.Active != "native" || gothic.Window.Inactive != "frosted_rich" {
		t.Fatalf("gothic window identity = %#v", gothic.Window)
	}
	if gothic.Shell.Surface != "contrast" || gothic.Shell.Detail != "framed" || gothic.Shell.Tooltip != "accent" || gothic.Shell.Notifications != "accent" {
		t.Fatalf("gothic shell identity = %#v", gothic.Shell)
	}
	if gothic.Bar.Spec == nil || gothic.Bar.Spec.Preset != "cathedral" || gothic.Bar.Spec.Topology != bar.TopologySections || gothic.Bar.Spec.Clock.Style != "gothic" || gothic.Bar.Spec.Surface.Treatment != "opaque" || gothic.Bar.Spec.Surface.Opacity != 1 || gothic.Bar.Spec.Surface.BorderWidth != 2 || gothic.Bar.Spec.Behavior.HoverExpand != true || gothic.Bar.Profile == nil || gothic.Bar.Profile.Behavior.Expansion != "hover" {
		t.Fatalf("gothic bar identity = %#v", gothic.Bar)
	}
	if gothic.Animations.Preset != "custom" || gothic.Animations.Window != "cinematic" || gothic.Animations.WindowOpen != "slide" || gothic.Animations.WindowClose != "fade" || gothic.Animations.WorkspaceAxis != "vertical" || gothic.Animations.Border != "static" || gothic.Animations.EffectiveScreenEffect().ID != "none" {
		t.Fatalf("gothic motion identity = %#v", gothic.Animations)
	}
	if err := gothic.Validate(); err != nil {
		t.Fatal(err)
	}

	acid, err := Resolve(PresetAcid)
	if err != nil {
		t.Fatal(err)
	}
	if acid.PresetRevision != 2 || acid.Window.BorderStyle != "spin" || acid.Window.BorderSize != 2 || acid.Window.BorderSpeed != 72 || acid.Window.Active != "frosted_balanced" || acid.Window.Inactive != "shadow_only" {
		t.Fatalf("acid window identity = %#v", acid.Window)
	}
	if acid.Shell.Surface != "layered" || acid.Shell.Detail != "edge" || acid.Shell.Tooltip != "accent" || acid.Shell.Notifications != "accent" {
		t.Fatalf("acid shell identity = %#v", acid.Shell)
	}
	if acid.Bar.Spec == nil || acid.Bar.Spec.Preset != "pulse" || acid.Bar.Spec.Topology != bar.TopologyRail || acid.Bar.Spec.Clock.Style != "native" || acid.Bar.Spec.Surface.Treatment != "metal" || acid.Bar.Spec.Surface.BorderWidth != 2 || acid.Bar.Spec.Workspace.Mode != "glyphs" || !reflect.DeepEqual(acid.Bar.Spec.Workspace.Glyphs, []string{"⊹", "⊕", "◉", "⊗", "✦"}) {
		t.Fatalf("acid bar identity = %#v", acid.Bar)
	}
	if acid.Animations.Preset != "custom" || acid.Animations.WindowOpacity != 94 || acid.Animations.Border != "spin" || acid.Animations.BorderSpeed != 72 || acid.Animations.Glitch != "none" || acid.Animations.EffectiveScreenEffect().ID != "none" {
		t.Fatalf("acid motion identity = %#v", acid.Animations)
	}
	if err := acid.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestResolveIsDeterministicAndJSONRoundTrips(t *testing.T) {
	first, err := Resolve(PresetGlassBlur)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Resolve(PresetGlassBlur)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatalf("resolutions differ:\n%#v\n%#v", first, second)
	}
	payload, err := json.Marshal(first)
	if err != nil {
		t.Fatal(err)
	}
	var decoded Composition
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(first, decoded) {
		t.Fatalf("JSON round trip changed composition:\n%#v\n%#v", first, decoded)
	}
}

func TestPortableManifestExportsAndImportsResolvedRecipe(t *testing.T) {
	manifest, err := Export(PresetNature)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Kind != ManifestKind || manifest.ID != PresetNature || manifest.Name != "Nature" || manifest.Version != 4 {
		t.Fatalf("manifest metadata = %#v", manifest)
	}
	payload, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := DecodeManifest(payload)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(decoded, manifest) {
		t.Fatalf("manifest round trip changed recipe:\n%#v\n%#v", manifest, decoded)
	}
	orientalManifest, err := Export(PresetOriental)
	if err != nil {
		t.Fatal(err)
	}
	if orientalManifest.ID != PresetOriental || orientalManifest.Name != "Oriental" || orientalManifest.Version != 6 || orientalManifest.Recipe.Bar.Spec.Preset != "zen" || orientalManifest.Recipe.Bar.Spec.Workspace.Mode != "kanji" {
		t.Fatalf("oriental manifest = %#v", orientalManifest)
	}
}

func TestTerminalTranslucencyRejectsUnsafeOpacity(t *testing.T) {
	for _, opacity := range []float64{0.49, 1.01} {
		spec := DefaultTerminalTranslucency()
		spec.Mode = TerminalModeCustom
		spec.Opacity = opacity
		if spec.Valid() {
			t.Fatalf("opacity %.2f unexpectedly valid", opacity)
		}
	}
}

func TestResolveRejectsUnknownPreset(t *testing.T) {
	if _, err := Resolve("neon"); err == nil {
		t.Fatal("unknown preset was accepted")
	}
}
