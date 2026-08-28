package runtime

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
)

// ActivationContractVersion versions the backend seam between a generated
// advanced theme and the runtime adapters that consume it. It is separate
// from ManifestVersion so the on-disk marker can remain compatible while the
// activation protocol grows.
const ActivationContractVersion = 1

// Feature is a declarative, allowlisted runtime capability. Theme data may
// name a future feature, but an older backend must report it as unsupported
// rather than execute arbitrary theme-provided code.
type Feature string

const (
	FeatureShell      Feature = "shell"
	FeatureBar        Feature = "bar"
	FeatureWindow     Feature = "window"
	FeatureAnimations Feature = "animations"
)

// Owner identifies the native runtime that remains authoritative for a
// feature. It prevents an adapter from silently taking ownership of another
// engine's geometry or lifecycle.
type Owner string

const (
	OwnerQuickshell Owner = "quickshell"
	OwnerQuattro    Owner = "quattro"
	OwnerHyprland   Owner = "hyprland"
)

// FeatureState is the durable outcome of one adapter activation. Native
// theme application is independent from these states and remains the
// fallback when an advanced feature is unavailable.
type FeatureState string

const (
	FeaturePending     FeatureState = "pending"
	FeatureReady       FeatureState = "ready"
	FeatureDegraded    FeatureState = "degraded"
	FeatureFailed      FeatureState = "failed"
	FeatureUnsupported FeatureState = "unsupported"
	FeatureSkipped     FeatureState = "skipped"
	FeatureInactive    FeatureState = "inactive"
)

// FeatureContract is the part of an adapter that the dispatcher needs before
// it can call the implementation. Dependencies are explicit so activation
// order does not leak into the generated theme or the registry's map order.
type FeatureContract struct {
	Feature          Feature   `json:"feature"`
	Owner            Owner     `json:"owner"`
	DependsOn        []Feature `json:"depends_on,omitempty"`
	Durable          bool      `json:"durable"`
	NativeFallback   bool      `json:"native_fallback"`
	NeedsShellReload bool      `json:"needs_shell_reload"`
	NeedsHyprReload  bool      `json:"needs_hyprland_reload"`
}

func (c FeatureContract) Validate() error {
	if !validIdentifier(string(c.Feature)) {
		return fmt.Errorf("invalid runtime feature %q", c.Feature)
	}
	if !validIdentifier(string(c.Owner)) {
		return fmt.Errorf("invalid runtime owner %q", c.Owner)
	}
	seen := make(map[Feature]struct{}, len(c.DependsOn))
	for _, dependency := range c.DependsOn {
		if !validIdentifier(string(dependency)) {
			return fmt.Errorf("invalid dependency %q for feature %q", dependency, c.Feature)
		}
		if dependency == c.Feature {
			return fmt.Errorf("feature %q cannot depend on itself", c.Feature)
		}
		if _, exists := seen[dependency]; exists {
			return fmt.Errorf("feature %q declares duplicate dependency %q", c.Feature, dependency)
		}
		seen[dependency] = struct{}{}
	}
	return nil
}

// ActivationRequest is the immutable input to every adapter. Adapters must
// treat ThemeRoot as staged, theme-owned input and may only write through
// paths they declare in their durable runtime implementation.
type ActivationRequest struct {
	ThemeRoot string   `json:"theme_root"`
	ThemeName string   `json:"theme_name"`
	Manifest  Manifest `json:"manifest"`
}

func (r ActivationRequest) Validate() error {
	if r.ThemeRoot == "" || !filepath.IsAbs(r.ThemeRoot) || filepath.Clean(r.ThemeRoot) != r.ThemeRoot {
		return fmt.Errorf("theme root must be a clean absolute path")
	}
	if !validThemeName(r.ThemeName) {
		return fmt.Errorf("invalid theme name %q", r.ThemeName)
	}
	return r.Manifest.Validate()
}

// DeactivationRequest is deliberately smaller than ActivationRequest. It is
// used when switching to a Fast or stock theme and the old advanced runtime
// must remove only Omagen-owned state.
type DeactivationRequest struct {
	ThemeName string `json:"theme_name"`
	Reason    string `json:"reason"`
}

func (r DeactivationRequest) Validate() error {
	if !validThemeName(r.ThemeName) {
		return fmt.Errorf("invalid theme name %q", r.ThemeName)
	}
	if strings.TrimSpace(r.Reason) == "" {
		return fmt.Errorf("deactivation reason is empty")
	}
	return nil
}

// FeatureResult is the only result an adapter may publish. OwnedPaths are
// provenance, not instructions: they let the dispatcher and recovery code
// remove or restore only files that belong to that adapter.
type FeatureResult struct {
	Feature    Feature      `json:"feature"`
	Owner      Owner        `json:"owner"`
	State      FeatureState `json:"state"`
	Message    string       `json:"message,omitempty"`
	OwnedPaths []string     `json:"owned_paths,omitempty"`
}

func (r FeatureResult) Validate(contract FeatureContract) error {
	if r.Feature != contract.Feature {
		return fmt.Errorf("runtime feature result is for %q, want %q", r.Feature, contract.Feature)
	}
	if r.Owner != contract.Owner {
		return fmt.Errorf("runtime feature %q result owner is %q, want %q", r.Feature, r.Owner, contract.Owner)
	}
	if !validFeatureState(r.State) || r.State == FeaturePending {
		return fmt.Errorf("runtime feature %q returned invalid state %q", r.Feature, r.State)
	}
	for _, path := range r.OwnedPaths {
		if path == "" || !filepath.IsAbs(path) || filepath.Clean(path) != path {
			return fmt.Errorf("runtime feature %q returned an unsafe owned path", r.Feature)
		}
	}
	return nil
}

// RuntimeActivationResult is the durable, per-feature report surfaced by the
// future worker and UI. A report is not successful merely because the native
// theme was applied; every declared feature has an explicit state.
type RuntimeActivationResult struct {
	ContractVersion int             `json:"contract_version"`
	Theme           string          `json:"theme"`
	State           FeatureState    `json:"state"`
	Features        []FeatureResult `json:"features"`
}

func (r RuntimeActivationResult) Validate() error {
	if r.ContractVersion != ActivationContractVersion {
		return fmt.Errorf("unsupported runtime activation contract version %d", r.ContractVersion)
	}
	if !validThemeName(r.Theme) {
		return fmt.Errorf("invalid runtime activation theme %q", r.Theme)
	}
	if !validFeatureState(r.State) || r.State == FeaturePending {
		return fmt.Errorf("invalid runtime activation state %q", r.State)
	}
	seen := make(map[Feature]struct{}, len(r.Features))
	for _, result := range r.Features {
		if !validIdentifier(string(result.Feature)) || (result.Owner != "" && !validIdentifier(string(result.Owner))) {
			return fmt.Errorf("invalid runtime feature result %q", result.Feature)
		}
		if result.Owner == "" && result.State != FeatureUnsupported && result.State != FeatureSkipped {
			return fmt.Errorf("runtime feature %q has no owner for state %q", result.Feature, result.State)
		}
		if _, exists := seen[result.Feature]; exists {
			return fmt.Errorf("duplicate runtime feature result %q", result.Feature)
		}
		seen[result.Feature] = struct{}{}
		if !validFeatureState(result.State) || result.State == FeaturePending {
			return fmt.Errorf("runtime feature %q has invalid state %q", result.Feature, result.State)
		}
		for _, path := range result.OwnedPaths {
			if path == "" || !filepath.IsAbs(path) || filepath.Clean(path) != path {
				return fmt.Errorf("runtime feature %q has an unsafe owned path", result.Feature)
			}
		}
	}
	return nil
}

// RuntimeAdapter is the implementation seam for Shell, Bar, Window,
// Animations, and future features. Preflight must not mutate the desktop.
// Activate and Deactivate must be idempotent and limited to the adapter's
// declared ownership; native fallback remains available after any error.
type RuntimeAdapter interface {
	Contract() FeatureContract
	Preflight(context.Context, ActivationRequest) error
	Activate(context.Context, ActivationRequest) (FeatureResult, error)
	Deactivate(context.Context, DeactivationRequest) (FeatureResult, error)
}

type PlannedFeature struct {
	Feature   Feature      `json:"feature"`
	Owner     Owner        `json:"owner,omitempty"`
	DependsOn []Feature    `json:"depends_on,omitempty"`
	State     FeatureState `json:"state"`
	Reason    string       `json:"reason,omitempty"`
}

type ActivationPlan struct {
	ContractVersion int              `json:"contract_version"`
	Theme           string           `json:"theme"`
	Features        []PlannedFeature `json:"features"`
}

// AdapterRegistry is the dispatcher seam. It only plans activation at this
// stage; actual adapters can be added independently without changing manifest
// parsing or the hook contract.
type AdapterRegistry struct {
	adapters map[Feature]RuntimeAdapter
}

func NewAdapterRegistry(adapters ...RuntimeAdapter) (*AdapterRegistry, error) {
	registry := &AdapterRegistry{adapters: make(map[Feature]RuntimeAdapter, len(adapters))}
	for _, adapter := range adapters {
		if adapter == nil {
			return nil, fmt.Errorf("runtime adapter is nil")
		}
		contract := adapter.Contract()
		if err := contract.Validate(); err != nil {
			return nil, err
		}
		if _, exists := registry.adapters[contract.Feature]; exists {
			return nil, fmt.Errorf("duplicate runtime adapter for feature %q", contract.Feature)
		}
		registry.adapters[contract.Feature] = adapter
	}
	return registry, nil
}

func (r *AdapterRegistry) Plan(request ActivationRequest) (ActivationPlan, error) {
	if r == nil {
		return ActivationPlan{}, fmt.Errorf("runtime adapter registry is nil")
	}
	if err := request.Validate(); err != nil {
		return ActivationPlan{}, err
	}

	declared := make(map[Feature]struct{}, len(request.Manifest.Features))
	for _, rawFeature := range request.Manifest.Features {
		declared[Feature(rawFeature)] = struct{}{}
	}

	ordered, err := r.order(request.Manifest.Features, declared)
	if err != nil {
		return ActivationPlan{}, err
	}

	plan := ActivationPlan{
		ContractVersion: ActivationContractVersion,
		Theme:           request.ThemeName,
		Features:        make([]PlannedFeature, 0, len(ordered)),
	}
	for _, feature := range ordered {
		adapter, exists := r.adapters[feature]
		if !exists {
			plan.Features = append(plan.Features, PlannedFeature{
				Feature: feature,
				State:   FeatureUnsupported,
				Reason:  "no adapter is registered for this feature",
			})
			continue
		}
		contract := adapter.Contract()
		item := PlannedFeature{
			Feature:   contract.Feature,
			Owner:     contract.Owner,
			DependsOn: append([]Feature(nil), contract.DependsOn...),
			State:     FeaturePending,
		}
		for _, dependency := range contract.DependsOn {
			if !r.hasAdapter(dependency) {
				item.State = FeatureUnsupported
				item.Reason = fmt.Sprintf("dependency %q has no adapter", dependency)
				break
			}
		}
		plan.Features = append(plan.Features, item)
	}
	return plan, nil
}

func (r *AdapterRegistry) hasAdapter(feature Feature) bool {
	_, ok := r.adapters[feature]
	return ok
}

func (r *AdapterRegistry) order(features []string, declared map[Feature]struct{}) ([]Feature, error) {
	visitState := make(map[Feature]uint8, len(features))
	ordered := make([]Feature, 0, len(features))
	var visit func(Feature) error
	visit = func(feature Feature) error {
		switch visitState[feature] {
		case 1:
			return fmt.Errorf("runtime feature dependency cycle at %q", feature)
		case 2:
			return nil
		}
		visitState[feature] = 1
		if adapter, ok := r.adapters[feature]; ok {
			for _, dependency := range adapter.Contract().DependsOn {
				if _, ok := declared[dependency]; !ok {
					return fmt.Errorf("feature %q depends on undeclared feature %q", feature, dependency)
				}
				if err := visit(dependency); err != nil {
					return err
				}
			}
		}
		visitState[feature] = 2
		ordered = append(ordered, feature)
		return nil
	}
	for _, rawFeature := range features {
		if err := visit(Feature(rawFeature)); err != nil {
			return nil, err
		}
	}
	return ordered, nil
}

func validThemeName(name string) bool {
	return name != "" && filepath.Base(name) == name && validIdentifier(name)
}

func validFeatureState(state FeatureState) bool {
	switch state {
	case FeaturePending, FeatureReady, FeatureDegraded, FeatureFailed, FeatureUnsupported, FeatureSkipped, FeatureInactive:
		return true
	default:
		return false
	}
}

func validIdentifier(value string) bool {
	if len(value) == 0 || len(value) > 64 {
		return false
	}
	for index, char := range value {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9' && index > 0) || (char == '-' && index > 0) {
			continue
		}
		return false
	}
	return true
}
