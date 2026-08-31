package runtime

import (
	"context"
	"path/filepath"
	"testing"
)

type contractTestAdapter struct {
	contract FeatureContract
}

func (a contractTestAdapter) Contract() FeatureContract { return a.contract }

func (a contractTestAdapter) Preflight(context.Context, ActivationRequest) error { return nil }

func (a contractTestAdapter) Activate(context.Context, ActivationRequest) (FeatureResult, error) {
	return FeatureResult{Feature: a.contract.Feature, Owner: a.contract.Owner, State: FeatureReady}, nil
}

func (a contractTestAdapter) Deactivate(context.Context, DeactivationRequest) (FeatureResult, error) {
	return FeatureResult{Feature: a.contract.Feature, Owner: a.contract.Owner, State: FeatureReady}, nil
}

func testActivationRequest(features ...string) ActivationRequest {
	return ActivationRequest{
		ThemeRoot: filepath.Join(string(filepath.Separator), "tmp", "theme"),
		ThemeName: "generated-theme",
		Manifest:  AdvancedManifest(features...),
	}
}

func TestManifestRejectsMalformedFeatureDeclarations(t *testing.T) {
	for name, manifest := range map[string]Manifest{
		"none":      AdvancedManifest(),
		"duplicate": AdvancedManifest("shell", "shell"),
		"uppercase": AdvancedManifest("Shell"),
		"slash":     AdvancedManifest("shell/bar"),
	} {
		t.Run(name, func(t *testing.T) {
			if err := manifest.Validate(); err == nil {
				t.Fatal("expected manifest validation to fail")
			}
		})
	}
}

func TestActivationRequestRejectsUnsafeThemeInputs(t *testing.T) {
	request := testActivationRequest("shell")
	request.ThemeRoot = request.ThemeRoot + "/.."
	if err := request.Validate(); err == nil {
		t.Fatal("expected dirty theme root to fail")
	}

	request = testActivationRequest("shell")
	request.ThemeName = "../escape"
	if err := request.Validate(); err == nil {
		t.Fatal("expected unsafe theme name to fail")
	}
}

func TestDeactivationRequestValidatesPreservedFeatures(t *testing.T) {
	request := DeactivationRequest{ThemeName: "generated-theme", Reason: "handoff", Preserve: []Feature{FeatureBar}}
	if err := request.Validate(); err != nil {
		t.Fatal(err)
	}
	if !request.Preserves(FeatureBar) || request.Preserves(FeatureShell) {
		t.Fatalf("unexpected preserved feature lookup: %#v", request)
	}
	request.Preserve = []Feature{FeatureBar, FeatureBar}
	if err := request.Validate(); err == nil {
		t.Fatal("expected duplicate preserved feature to fail")
	}
	request.Preserve = []Feature{"../bar"}
	if err := request.Validate(); err == nil {
		t.Fatal("expected invalid preserved feature to fail")
	}
}

func TestRegistryPlansDependenciesBeforeFeaturesAndDoesNotClaimReady(t *testing.T) {
	registry, err := NewAdapterRegistry(
		contractTestAdapter{contract: FeatureContract{Feature: FeatureBar, Owner: OwnerQuattro, DependsOn: []Feature{FeatureShell}, Durable: true, NativeFallback: true}},
		contractTestAdapter{contract: FeatureContract{Feature: FeatureShell, Owner: OwnerQuickshell, Durable: true, NativeFallback: true}},
	)
	if err != nil {
		t.Fatal(err)
	}
	plan, err := registry.Plan(testActivationRequest("bar", "shell", "future-effect"))
	if err != nil {
		t.Fatal(err)
	}
	if len(plan.Features) != 3 || plan.Features[0].Feature != FeatureShell || plan.Features[1].Feature != FeatureBar {
		t.Fatalf("unexpected dependency order: %#v", plan.Features)
	}
	if plan.Features[0].State != FeaturePending || plan.Features[1].State != FeaturePending {
		t.Fatalf("registered features must remain pending until activation: %#v", plan.Features)
	}
	if plan.Features[2].Feature != Feature("future-effect") || plan.Features[2].State != FeatureUnsupported {
		t.Fatalf("unknown feature was not reported as unsupported: %#v", plan.Features)
	}
}

func TestRegistryRejectsDuplicateAdaptersAndMissingDependencies(t *testing.T) {
	adapter := contractTestAdapter{contract: FeatureContract{Feature: FeatureShell, Owner: OwnerQuickshell}}
	if _, err := NewAdapterRegistry(adapter, adapter); err == nil {
		t.Fatal("expected duplicate adapter to fail")
	}

	registry, err := NewAdapterRegistry(contractTestAdapter{contract: FeatureContract{
		Feature: FeatureBar, Owner: OwnerQuattro, DependsOn: []Feature{FeatureShell},
	}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := registry.Plan(testActivationRequest("bar")); err == nil {
		t.Fatal("expected undeclared dependency to fail")
	}
}
