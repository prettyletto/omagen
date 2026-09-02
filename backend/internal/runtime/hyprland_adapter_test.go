package runtime

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestHyprlandAdapterReportsNativeWindowAndAnimationsReady(t *testing.T) {
	themeRoot := t.TempDir()
	if err := os.WriteFile(filepath.Join(themeRoot, hyprlandConfigFile), []byte("hl.config({})\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	for _, feature := range []Feature{FeatureWindow, FeatureAnimations} {
		t.Run(string(feature), func(t *testing.T) {
			adapter, err := NewHyprlandAdapter(feature)
			if err != nil {
				t.Fatal(err)
			}
			request := testActivationRequest(string(feature))
			request.ThemeRoot = themeRoot
			if err := adapter.Preflight(context.Background(), request); err != nil {
				t.Fatal(err)
			}
			result, err := adapter.Activate(context.Background(), request)
			if err != nil {
				t.Fatal(err)
			}
			if result.Feature != feature || result.Owner != OwnerHyprland || result.State != FeatureReady {
				t.Fatalf("unexpected activation result: %#v", result)
			}
			if result.OwnedPaths != nil {
				t.Fatalf("native Hyprland adapter must not claim persistent paths: %#v", result)
			}
			inactive, err := adapter.Deactivate(context.Background(), DeactivationRequest{ThemeName: "generated-theme", Reason: "switched to native theme"})
			if err != nil {
				t.Fatal(err)
			}
			if inactive.State != FeatureInactive || inactive.Owner != OwnerHyprland {
				t.Fatalf("unexpected deactivation result: %#v", inactive)
			}
		})
	}
}

func TestHyprlandAdapterRejectsMissingOrEmptyConfig(t *testing.T) {
	adapter, err := NewHyprlandAdapter(FeatureWindow)
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name string
		data string
	}{
		{name: "missing"},
		{name: "empty", data: "\n"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			themeRoot := t.TempDir()
			if tc.data != "" {
				if err := os.WriteFile(filepath.Join(themeRoot, hyprlandConfigFile), []byte(tc.data), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			request := testActivationRequest("window")
			request.ThemeRoot = themeRoot
			if err := adapter.Preflight(context.Background(), request); err == nil {
				t.Fatal("expected invalid Hyprland config to fail preflight")
			}
		})
	}
}

func TestDefaultRegistryRegistersNativeHyprlandFeatures(t *testing.T) {
	registry, err := NewDefaultAdapterRegistry()
	if err != nil {
		t.Fatal(err)
	}
	plan, err := registry.Plan(testActivationRequest("shell", "bar", "window", "animations"))
	if err != nil {
		t.Fatal(err)
	}
	for _, feature := range plan.Features {
		if (feature.Feature == FeatureWindow || feature.Feature == FeatureAnimations) && feature.State == FeatureUnsupported {
			t.Fatalf("native Hyprland feature remained unsupported: %#v", plan.Features)
		}
	}
}
