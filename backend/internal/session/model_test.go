package session

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
)

func TestLegacyBarStyleHasEffectiveVersionedSpec(t *testing.T) {
	style := NormalizeBarStyle(BarStyle{Surface: "dark", Density: "compact", Attention: "accent", Form: "docked", Visibility: "islands"})
	if style.Spec != nil {
		t.Fatal("legacy normalization should not rewrite the durable shape")
	}
	spec := style.EffectiveBarSpec()
	if spec.Topology != bar.TopologySections || spec.Surface.Role != "dark" || spec.Geometry.Density != "compact" || spec.Attention.Mode != "accent" {
		t.Fatalf("legacy spec migration = %#v", spec)
	}
	if err := spec.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestLegacyWorkspacePresentationMigratesIntoBarSpec(t *testing.T) {
	profile := barprofile.DefaultProfile()
	profile.Behavior.Workspace = "dots"
	style := NormalizeBarStyle(BarStyle{Profile: &profile})
	if got := style.EffectiveBarSpec().Workspace.Mode; got != "dots" {
		t.Fatalf("workspace presentation = %q, want dots", got)
	}
}

func TestExplicitBarSpecSurvivesNormalization(t *testing.T) {
	spec := bar.Default()
	spec.Topology = bar.TopologyDock
	spec.Engine = bar.EngineOmagen
	style := NormalizeBarStyle(BarStyle{Surface: "dark", Density: "native", Attention: "semantic", Form: "continuous", Visibility: "native", Spec: &spec})
	if style.Spec == nil || style.Spec.Topology != bar.TopologyDock {
		t.Fatalf("explicit spec was lost: %#v", style)
	}
}

func TestMotionPresetsExpandToValidVersionedDocuments(t *testing.T) {
	for _, name := range []string{"native", "snappy", "smooth", "spring", "cinematic", "minimal", "cyberpunk"} {
		t.Run(name, func(t *testing.T) {
			style := NormalizeAnimationsStyle(AnimationsStyle{Preset: name})
			if !style.Valid() {
				t.Fatalf("preset %q is invalid after normalization: %#v", name, style)
			}
			if style.Version != 1 || style.Preset != name {
				t.Fatalf("preset %q did not remain versioned: %#v", name, style)
			}
		})
	}
}

func TestLookFeelMotionIdentitiesDoNotShareTheSameWindowSkeleton(t *testing.T) {
	glass := MotionPreset("smooth")
	focused := MotionPreset("snappy")
	cyberpunk := MotionPreset("cyberpunk")

	if glass.WindowOpen != "popin" || glass.Workspace != "slidefade" || glass.Curve != "glass" {
		t.Fatalf("glass identity = %#v", glass)
	}
	if focused.WindowOpen != "popin" || focused.Workspace != "fade" || focused.Curve != "precision" || focused.WindowSpeed != 1 {
		t.Fatalf("focused identity = %#v", focused)
	}
	if cyberpunk.WindowOpen != "gnomed" || cyberpunk.WindowClose != "slide" || cyberpunk.WindowOpacity != 82 || cyberpunk.Workspace != "slide" || cyberpunk.Focus != "digital" || cyberpunk.Curve != "digital" || cyberpunk.Glitch != "medium" {
		t.Fatalf("cyberpunk identity = %#v", cyberpunk)
	}
	if glass.Window == focused.Window || focused.Window == cyberpunk.Window || glass.Window == cyberpunk.Window {
		t.Fatalf("look-and-feel window families must remain distinct: glass=%q focused=%q cyberpunk=%q", glass.Window, focused.Window, cyberpunk.Window)
	}
}

func TestLegacyFlickerNormalizesToMediumRGBTear(t *testing.T) {
	style := NormalizeAnimationsStyle(AnimationsStyle{Preset: "cyberpunk", Window: "digital", WindowOpacity: 82, Workspace: "slide", Border: "static", BorderSpeed: 36, Glitch: "flicker"})
	if style.Glitch != "medium" || !style.Valid() {
		t.Fatalf("legacy flicker migration = %#v", style)
	}
}

func TestLegacyMotionFieldsKeepNativeDefaultsAndRemainValid(t *testing.T) {
	style := NormalizeAnimationsStyle(AnimationsStyle{Window: "snappy", Workspace: "smooth", Border: "static", BorderSpeed: 48})
	if !style.Valid() {
		t.Fatalf("legacy animation document is invalid after migration: %#v", style)
	}
	if style.WindowOpen != "popin" || style.WindowClose != "popin" || style.WindowAmount != 87 || style.WorkspaceAxis != "horizontal" {
		t.Fatalf("legacy defaults changed unexpectedly: %#v", style)
	}
}

func TestReducedMotionPreservesStagedMotionFields(t *testing.T) {
	original := MotionPreset("cyberpunk")
	original.ReducedMotion = true

	withReducedMotion := NormalizeAnimationsStyle(original)
	if !withReducedMotion.Valid() {
		t.Fatalf("reduced-motion document is invalid after normalization: %#v", withReducedMotion)
	}
	if withReducedMotion.Window != original.Window || withReducedMotion.WindowOpen != original.WindowOpen || withReducedMotion.WindowClose != original.WindowClose || withReducedMotion.WindowAmount != original.WindowAmount || withReducedMotion.WindowOpacity != original.WindowOpacity || withReducedMotion.WindowSpeed != original.WindowSpeed || withReducedMotion.Workspace != original.Workspace || withReducedMotion.Border != original.Border || withReducedMotion.Glitch != original.Glitch || withReducedMotion.ScreenEffect != original.ScreenEffect {
		t.Fatalf("reduced-motion normalization erased staged choices: got %#v, want %#v", withReducedMotion, original)
	}

	withReducedMotion.ReducedMotion = false
	if restored := NormalizeAnimationsStyle(withReducedMotion); restored.Window != original.Window || restored.Workspace != original.Workspace || restored.Border != original.Border || restored.Glitch != original.Glitch {
		t.Fatalf("turning reduced motion off did not restore staged choices: got %#v, want %#v", restored, original)
	}
}

func TestShellPresetsKeepPresetValuesSeparateFromExplicitOverrides(t *testing.T) {
	glass := NormalizeShellStyle(ShellStyle{
		Preset: ShellPresetGlass,
		Overrides: map[string]string{
			"popups.background-alpha": "0.65",
		},
	})
	if !glass.Valid() {
		t.Fatalf("glass Shell style is invalid: %#v", glass)
	}
	if got := ShellPresetOverrides(ShellPresetDefault); len(got) != 0 {
		t.Fatalf("default preset unexpectedly has tokens: %#v", got)
	}
	if got := ShellPresetOverrides(ShellPresetGlass)["menu.background-alpha"]; got != "0.72" {
		t.Fatalf("glass preset menu alpha = %q, want 0.72", got)
	}

	effective := EffectiveShellOverrides(glass, BarStyle{})
	if effective["popups.background-alpha"] != "0.65" {
		t.Fatalf("explicit override was not authoritative: %#v", effective)
	}
	if effective["menu.background-alpha"] != "0.72" {
		t.Fatalf("preset token was not derived: %#v", effective)
	}

	defaultStyle := NormalizeShellStyle(ShellStyle{Preset: ShellPresetDefault, Overrides: glass.Overrides})
	if got := EffectiveShellOverrides(defaultStyle, BarStyle{})["popups.background-alpha"]; got != "0.65" {
		t.Fatalf("custom token did not survive preset switch: %q", got)
	}
}

func TestScreenEffectContractPreservesLegacyCyberpunkAndValidatesNewEffects(t *testing.T) {
	cyberpunk := MotionPreset("cyberpunk")
	if cyberpunk.ScreenEffect != nil {
		t.Fatalf("legacy Cyberpunk document gained an explicit effect: %#v", cyberpunk.ScreenEffect)
	}
	effective := cyberpunk.EffectiveScreenEffect()
	if effective.ID != "rgb-tear" || effective.Strength != "medium" || effective.DurationMs != 1250 || !effective.Coalesce {
		t.Fatalf("effective Cyberpunk signal = %#v", effective)
	}
	spectral := ScreenEffect{ID: "spectral-shift", Strength: "strong", DurationMs: 500, Triggers: []string{"window-open", "workspace"}, Coalesce: true}
	if !spectral.Valid() {
		t.Fatalf("valid spectral effect rejected: %#v", spectral)
	}
	retro := ScreenEffect{ID: "retro-vhs", Strength: "medium", Triggers: []string{"window-open", "workspace"}, Coalesce: true}
	if normalized := retro.Normalize(); normalized.DurationMs != 1100 || !normalized.Valid() {
		t.Fatalf("valid retro VHS effect was not normalized: %#v", normalized)
	}
	spectral.Triggers = append(spectral.Triggers, "focus-every-frame")
	if spectral.Valid() {
		t.Fatalf("unknown trigger accepted: %#v", spectral)
	}
}
