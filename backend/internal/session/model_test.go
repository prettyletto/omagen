package session

import (
	"testing"

	"github.com/prettyletto/omagen/backend/internal/bar"
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

func TestExplicitBarSpecSurvivesNormalization(t *testing.T) {
	spec := bar.Default()
	spec.Topology = bar.TopologyDock
	spec.Engine = bar.EngineOmagen
	style := NormalizeBarStyle(BarStyle{Surface: "dark", Density: "native", Attention: "semantic", Form: "continuous", Visibility: "native", Spec: &spec})
	if style.Spec == nil || style.Spec.Topology != bar.TopologyDock {
		t.Fatalf("explicit spec was lost: %#v", style)
	}
}
