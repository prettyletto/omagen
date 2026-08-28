package runtime

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/testenv"
)

type recordingRuntimeAdapter struct {
	contract      FeatureContract
	order         *[]string
	preflightErr  error
	activateErr   error
	deactivateErr error
	state         FeatureState
}

func (a recordingRuntimeAdapter) Contract() FeatureContract { return a.contract }

func (a recordingRuntimeAdapter) Preflight(context.Context, ActivationRequest) error {
	*a.order = append(*a.order, "preflight:"+string(a.contract.Feature))
	return a.preflightErr
}

func (a recordingRuntimeAdapter) Activate(context.Context, ActivationRequest) (FeatureResult, error) {
	*a.order = append(*a.order, "activate:"+string(a.contract.Feature))
	if a.activateErr != nil {
		return FeatureResult{}, a.activateErr
	}
	state := a.state
	if state == "" {
		state = FeatureReady
	}
	return FeatureResult{Feature: a.contract.Feature, Owner: a.contract.Owner, State: state}, nil
}

func (a recordingRuntimeAdapter) Deactivate(context.Context, DeactivationRequest) (FeatureResult, error) {
	*a.order = append(*a.order, "deactivate:"+string(a.contract.Feature))
	if a.deactivateErr != nil {
		return FeatureResult{}, a.deactivateErr
	}
	return FeatureResult{Feature: a.contract.Feature, Owner: a.contract.Owner, State: FeatureInactive}, nil
}

func TestCoordinatorActivatesInPlanOrderAndPersistsDegradedOutcome(t *testing.T) {
	testenv.Isolate(t)
	order := []string{}
	registry, err := NewAdapterRegistry(
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureBar, Owner: OwnerQuattro, DependsOn: []Feature{FeatureShell}, Durable: true, NativeFallback: true},
			order:    &order,
		},
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureShell, Owner: OwnerQuickshell, Durable: true, NativeFallback: true, NeedsShellReload: true},
			order:    &order,
		},
	)
	if err != nil {
		t.Fatal(err)
	}
	coordinator, err := NewRuntimeCoordinator(registry)
	if err != nil {
		t.Fatal(err)
	}
	result, err := coordinator.Activate(context.Background(), testActivationRequest("bar", "shell", "future-effect"))
	if err != nil {
		t.Fatal(err)
	}
	if result.State != FeatureDegraded {
		t.Fatalf("unsupported future feature must degrade activation: %#v", result)
	}
	if got, want := order, []string{"preflight:shell", "activate:shell", "preflight:bar", "activate:bar"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("adapter order = %#v, want %#v", got, want)
	}
	if len(result.Features) != 3 || result.Features[0].Feature != FeatureShell || result.Features[1].Feature != FeatureBar || result.Features[2].State != FeatureUnsupported {
		t.Fatalf("unexpected activation result: %#v", result.Features)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if state.LastActivation == nil || state.LastActivation.State != FeatureDegraded {
		t.Fatalf("activation was not persisted: %#v", state)
	}
}

func TestCoordinatorSkipsDependentsAfterAdapterFailureButRunsIndependentFeatures(t *testing.T) {
	testenv.Isolate(t)
	order := []string{}
	registry, err := NewAdapterRegistry(
		recordingRuntimeAdapter{
			contract:    FeatureContract{Feature: FeatureShell, Owner: OwnerQuickshell},
			order:       &order,
			activateErr: errors.New("shell host unavailable"),
		},
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureBar, Owner: OwnerQuattro, DependsOn: []Feature{FeatureShell}},
			order:    &order,
		},
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureWindow, Owner: OwnerHyprland},
			order:    &order,
		},
	)
	if err != nil {
		t.Fatal(err)
	}
	coordinator, err := NewRuntimeCoordinator(registry)
	if err != nil {
		t.Fatal(err)
	}
	result, err := coordinator.Activate(context.Background(), testActivationRequest("shell", "bar", "window"))
	if err != nil {
		t.Fatal(err)
	}
	if result.State != FeatureFailed {
		t.Fatalf("failed adapter must fail overall runtime activation: %#v", result)
	}
	if got, want := order, []string{"preflight:shell", "activate:shell", "preflight:window", "activate:window"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("adapter order after failure = %#v, want %#v", got, want)
	}
	for _, feature := range result.Features {
		if feature.Feature == FeatureBar && feature.State != FeatureSkipped {
			t.Fatalf("dependent feature was not skipped: %#v", feature)
		}
	}
}

func TestCoordinatorDeactivatesInReverseOrderAndClearsSuccessfulActivation(t *testing.T) {
	testenv.Isolate(t)
	order := []string{}
	registry, err := NewAdapterRegistry(
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureBar, Owner: OwnerQuattro, DependsOn: []Feature{FeatureShell}},
			order:    &order,
		},
		recordingRuntimeAdapter{
			contract: FeatureContract{Feature: FeatureShell, Owner: OwnerQuickshell},
			order:    &order,
		},
	)
	if err != nil {
		t.Fatal(err)
	}
	coordinator, err := NewRuntimeCoordinator(registry)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := coordinator.Activate(context.Background(), testActivationRequest("bar", "shell")); err != nil {
		t.Fatal(err)
	}
	result, err := coordinator.Deactivate(context.Background(), DeactivationRequest{ThemeName: "generated-theme", Reason: "switched to native theme"})
	if err != nil {
		t.Fatal(err)
	}
	if result.State != FeatureInactive {
		t.Fatalf("unexpected deactivation result: %#v", result)
	}
	if got, want := order, []string{"preflight:shell", "activate:shell", "preflight:bar", "activate:bar", "deactivate:bar", "deactivate:shell"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("deactivation order = %#v, want %#v", got, want)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if state.LastActivation != nil {
		t.Fatalf("successful deactivation left activation state: %#v", state.LastActivation)
	}
}

func TestThemeSetWithInstalledRuntimeReportsUnsupportedFeaturesInsteadOfPending(t *testing.T) {
	testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	themeRoot := t.TempDir()
	if err := WriteManifest(themeRoot, AdvancedManifest("shell", "bar")); err != nil {
		t.Fatal(err)
	}
	result, err := ThemeSet(themeRoot, "generated-theme")
	if err != nil {
		t.Fatal(err)
	}
	if result.RuntimeReady || result.ActivationPending || !result.NativeOnly || result.RuntimeState != FeatureDegraded {
		t.Fatalf("advanced theme made an unsupported runtime look ready: %#v", result)
	}
	if result.Activation == nil || len(result.Activation.Features) != 2 {
		t.Fatalf("unexpected activation result: %#v", result.Activation)
	}
}
