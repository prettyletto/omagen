package runtime

import (
	"context"
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

// RuntimeCoordinator owns the activation lifecycle behind the theme-set hook.
// The hook only supplies the active theme; this module plans the declared
// features, invokes bundled adapters in dependency order, and records the
// result so a later shell restart can inspect the last known runtime state.
type RuntimeCoordinator struct {
	registry *AdapterRegistry
}

func NewRuntimeCoordinator(registry *AdapterRegistry) (*RuntimeCoordinator, error) {
	if registry == nil {
		return nil, fmt.Errorf("runtime adapter registry is nil")
	}
	return &RuntimeCoordinator{registry: registry}, nil
}

func (c *RuntimeCoordinator) Activate(ctx context.Context, request ActivationRequest) (RuntimeActivationResult, error) {
	if ctx == nil {
		return RuntimeActivationResult{}, fmt.Errorf("runtime activation context is nil")
	}
	if c == nil || c.registry == nil {
		return RuntimeActivationResult{}, fmt.Errorf("runtime coordinator is nil")
	}
	plan, err := c.registry.Plan(request)
	if err != nil {
		return RuntimeActivationResult{}, err
	}

	result := RuntimeActivationResult{
		ContractVersion: ActivationContractVersion,
		Theme:           request.ThemeName,
		State:           FeaturePending,
		Features:        make([]FeatureResult, 0, len(plan.Features)),
	}
	states := make(map[Feature]FeatureState, len(plan.Features))
	for _, planned := range plan.Features {
		if planned.State == FeatureUnsupported {
			feature := FeatureResult{
				Feature: planned.Feature,
				State:   FeatureUnsupported,
				Message: planned.Reason,
			}
			result.Features = append(result.Features, feature)
			states[planned.Feature] = feature.State
			continue
		}

		adapter, exists := c.registry.adapters[planned.Feature]
		if !exists {
			feature := FeatureResult{
				Feature: planned.Feature,
				State:   FeatureUnsupported,
				Message: "no adapter is registered for this feature",
			}
			result.Features = append(result.Features, feature)
			states[planned.Feature] = feature.State
			continue
		}
		contract := adapter.Contract()
		if dependency, reason := failedDependency(contract.DependsOn, states); dependency != "" {
			feature := FeatureResult{
				Feature: planned.Feature,
				Owner:   contract.Owner,
				State:   FeatureSkipped,
				Message: fmt.Sprintf("%s: dependency %q", reason, dependency),
			}
			result.Features = append(result.Features, feature)
			states[planned.Feature] = feature.State
			continue
		}
		if err := ctx.Err(); err != nil {
			feature := FeatureResult{
				Feature: planned.Feature,
				Owner:   contract.Owner,
				State:   FeatureSkipped,
				Message: fmt.Sprintf("activation cancelled: %v", err),
			}
			result.Features = append(result.Features, feature)
			states[planned.Feature] = feature.State
			continue
		}
		if err := adapter.Preflight(ctx, request); err != nil {
			feature := FeatureResult{
				Feature: planned.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: fmt.Sprintf("preflight: %v", err),
			}
			result.Features = append(result.Features, feature)
			states[planned.Feature] = feature.State
			continue
		}

		feature, err := adapter.Activate(ctx, request)
		if err != nil {
			feature = FeatureResult{
				Feature: planned.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: err.Error(),
			}
		} else if err := feature.Validate(contract); err != nil {
			feature = FeatureResult{
				Feature: planned.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: fmt.Sprintf("invalid adapter result: %v", err),
			}
		}
		result.Features = append(result.Features, feature)
		states[planned.Feature] = feature.State
	}
	result.State = summarizeActivation(result.Features)
	if err := result.Validate(); err != nil {
		return RuntimeActivationResult{}, err
	}
	if err := persistActivation(result); err != nil {
		return RuntimeActivationResult{}, err
	}
	return result, nil
}

// Deactivate removes only state recorded by the previous activation. A
// missing adapter is reported as skipped because there is no safe operation
// the current backend can perform against an unknown future feature.
func (c *RuntimeCoordinator) Deactivate(ctx context.Context, request DeactivationRequest) (RuntimeActivationResult, error) {
	if ctx == nil {
		return RuntimeActivationResult{}, fmt.Errorf("runtime deactivation context is nil")
	}
	if c == nil || c.registry == nil {
		return RuntimeActivationResult{}, fmt.Errorf("runtime coordinator is nil")
	}
	if err := request.Validate(); err != nil {
		return RuntimeActivationResult{}, err
	}
	state, err := LoadState()
	if err != nil {
		return RuntimeActivationResult{}, err
	}
	if state.LastActivation == nil {
		return RuntimeActivationResult{
			ContractVersion: ActivationContractVersion,
			Theme:           request.ThemeName,
			State:           FeatureInactive,
		}, nil
	}
	if state.LastActivation.Theme != request.ThemeName {
		return RuntimeActivationResult{}, fmt.Errorf("runtime deactivation targets %q, active runtime is %q", request.ThemeName, state.LastActivation.Theme)
	}

	result := RuntimeActivationResult{
		ContractVersion: ActivationContractVersion,
		Theme:           request.ThemeName,
		State:           FeaturePending,
		Features:        make([]FeatureResult, 0, len(state.LastActivation.Features)),
	}
	for index := len(state.LastActivation.Features) - 1; index >= 0; index-- {
		previous := state.LastActivation.Features[index]
		adapter, exists := c.registry.adapters[previous.Feature]
		if !exists {
			result.Features = append(result.Features, FeatureResult{
				Feature: previous.Feature,
				State:   FeatureSkipped,
				Message: "no adapter is registered to deactivate this feature",
			})
			continue
		}
		contract := adapter.Contract()
		if err := ctx.Err(); err != nil {
			result.Features = append(result.Features, FeatureResult{
				Feature: previous.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: fmt.Sprintf("deactivation cancelled: %v", err),
			})
			continue
		}
		feature, err := adapter.Deactivate(ctx, request)
		if err != nil {
			feature = FeatureResult{
				Feature: previous.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: err.Error(),
			}
		} else if err := feature.Validate(contract); err != nil {
			feature = FeatureResult{
				Feature: previous.Feature,
				Owner:   contract.Owner,
				State:   FeatureFailed,
				Message: fmt.Sprintf("invalid adapter result: %v", err),
			}
		}
		result.Features = append(result.Features, feature)
	}
	result.State = summarizeDeactivation(result.Features)
	if err := result.Validate(); err != nil {
		return RuntimeActivationResult{}, err
	}
	if result.State != FeatureFailed {
		state.LastActivation = nil
		if err := SaveState(state); err != nil {
			return RuntimeActivationResult{}, err
		}
	}
	return result, nil
}

func failedDependency(dependencies []Feature, states map[Feature]FeatureState) (Feature, string) {
	for _, dependency := range dependencies {
		switch states[dependency] {
		case FeatureFailed:
			return dependency, "dependency failed"
		case FeatureUnsupported:
			return dependency, "dependency is unsupported"
		case FeatureSkipped:
			return dependency, "dependency was skipped"
		}
	}
	return "", ""
}

func summarizeActivation(features []FeatureResult) FeatureState {
	if len(features) == 0 {
		return FeatureDegraded
	}
	degraded := false
	for _, feature := range features {
		switch feature.State {
		case FeatureFailed:
			return FeatureFailed
		case FeatureDegraded, FeatureUnsupported, FeatureSkipped:
			degraded = true
		}
	}
	if degraded {
		return FeatureDegraded
	}
	return FeatureReady
}

func summarizeDeactivation(features []FeatureResult) FeatureState {
	for _, feature := range features {
		if feature.State == FeatureFailed {
			return FeatureFailed
		}
	}
	return FeatureInactive
}

func persistActivation(result RuntimeActivationResult) error {
	state, err := LoadState()
	if err != nil {
		return err
	}
	state.LastActivation = &result
	return SaveState(state)
}

// withRuntimeLock serializes hook invocations and state transitions without
// coupling the coordinator to the native Omarchy theme transaction lock.
func withRuntimeLock(fn func() error) error {
	_, _, statePath, err := Paths()
	if err != nil {
		return err
	}
	lock, err := fsutil.AcquireFileLock(statePath + ".lock")
	if err != nil {
		return err
	}
	defer lock.Close()
	return fn()
}
