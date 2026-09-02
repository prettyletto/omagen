package runtime

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

const hyprlandConfigFile = "hyprland.lua"

// HyprlandAdapter is the runtime-contract bridge for the Window and
// Animations engines. Hyprland remains the native owner: the adapter does not
// write compositor state or compete with omarchy-theme-set's reload path. It
// validates that the generated theme contains the native Lua artifact and
// reports that artifact as consumed after the native theme transaction.
type HyprlandAdapter struct {
	feature Feature
}

func NewHyprlandAdapter(feature Feature) (*HyprlandAdapter, error) {
	if feature != FeatureWindow && feature != FeatureAnimations {
		return nil, fmt.Errorf("invalid Hyprland runtime feature %q", feature)
	}
	return &HyprlandAdapter{feature: feature}, nil
}

func (a *HyprlandAdapter) Contract() FeatureContract {
	return FeatureContract{
		Feature:         a.feature,
		Owner:           OwnerHyprland,
		NativeFallback:  true,
		NeedsHyprReload: true,
	}
}

func (a *HyprlandAdapter) Preflight(_ context.Context, request ActivationRequest) error {
	if a == nil {
		return fmt.Errorf("Hyprland runtime adapter is nil")
	}
	_, err := readHyprlandConfig(request.ThemeRoot)
	return err
}

func (a *HyprlandAdapter) Activate(_ context.Context, request ActivationRequest) (FeatureResult, error) {
	if a == nil {
		return FeatureResult{}, fmt.Errorf("Hyprland runtime adapter is nil")
	}
	if _, err := readHyprlandConfig(request.ThemeRoot); err != nil {
		return FeatureResult{}, err
	}
	return FeatureResult{
		Feature: a.feature,
		Owner:   OwnerHyprland,
		State:   FeatureReady,
		Message: fmt.Sprintf("native Hyprland consumed generated %s from hyprland.lua", hyprlandFeatureLabel(a.feature)),
	}, nil
}

func (a *HyprlandAdapter) Deactivate(_ context.Context, _ DeactivationRequest) (FeatureResult, error) {
	if a == nil {
		return FeatureResult{}, fmt.Errorf("Hyprland runtime adapter is nil")
	}
	return FeatureResult{
		Feature: a.feature,
		Owner:   OwnerHyprland,
		State:   FeatureInactive,
		Message: "Hyprland owns no persistent runtime state; the next native theme reload replaces the generated artifact",
	}, nil
}

func readHyprlandConfig(themeRoot string) ([]byte, error) {
	path := filepath.Join(themeRoot, hyprlandConfigFile)
	data, err := fsutil.ReadFileLimited(path, fsutil.MaxStateFileBytes)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("generated Hyprland config is missing: %s", path)
		}
		return nil, fmt.Errorf("read generated Hyprland config: %w", err)
	}
	if strings.TrimSpace(string(data)) == "" {
		return nil, fmt.Errorf("generated Hyprland config is empty: %s", path)
	}
	return data, nil
}

func hyprlandFeatureLabel(feature Feature) string {
	if feature == FeatureWindow {
		return "Window"
	}
	return "Animations"
}
