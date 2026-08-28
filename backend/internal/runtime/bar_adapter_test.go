package runtime

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func TestBarAdapterAppliesProfileAndRestoresExactUserConfig(t *testing.T) {
	root := t.TempDir()
	themeRoot := filepath.Join(root, "theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(root, "shell.json")
	stateRoot := filepath.Join(root, "bar-state")
	original := []byte("{\n  \"bar\": {\"id\": \"omarchy.bar\", \"layout\": {\"right\": []}},\n  \"future\": {\"keep\": true}\n}\n")
	if err := os.WriteFile(configPath, original, 0o600); err != nil {
		t.Fatal(err)
	}
	profile := barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior:       barprofile.Behavior{Form: "dock"},
	}
	profileData, err := json.Marshal(profile)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, barProfileFile), profileData, 0o644); err != nil {
		t.Fatal(err)
	}

	store := barprofile.NewStoreAt(configPath, stateRoot)
	adapter, err := NewBarAdapter(store)
	if err != nil {
		t.Fatal(err)
	}
	request := testActivationRequest("bar")
	request.ThemeRoot = themeRoot
	if err := adapter.Preflight(context.Background(), request); err != nil {
		t.Fatal(err)
	}
	first, err := adapter.Activate(context.Background(), request)
	if err != nil {
		t.Fatal(err)
	}
	if first.State != FeatureReady || len(first.OwnedPaths) != 1 {
		t.Fatalf("unexpected first bar activation: %#v", first)
	}
	changed, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(changed) == string(original) || !bytes.Contains(changed, []byte(`"pretty.omagen.bar"`)) {
		t.Fatalf("bar profile was not applied: %s", changed)
	}

	// A repeated hook invocation must not replace the original baseline with
	// the already-themed shell configuration.
	if _, err := adapter.Activate(context.Background(), request); err != nil {
		t.Fatal(err)
	}
	if _, err := adapter.Deactivate(context.Background(), DeactivationRequest{ThemeName: request.ThemeName, Reason: "switched to native theme"}); err != nil {
		t.Fatal(err)
	}
	restored, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(restored) != string(original) {
		t.Fatalf("bar baseline was not restored exactly:\nwant:%s\ngot:%s", original, restored)
	}
	if _, err := os.Stat(filepath.Join(stateRoot, "snapshots", barSnapshotID(request.ThemeName)+".json")); !os.IsNotExist(err) {
		t.Fatalf("bar snapshot was not removed after restore: %v", err)
	}
}

func TestThemeSetUsesProductionBarAdapterAndRestoresOnFastTheme(t *testing.T) {
	root := testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	themeRoot := filepath.Join(root, "advanced-theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := WriteManifest(themeRoot, AdvancedManifest("bar")); err != nil {
		t.Fatal(err)
	}
	profileData, err := json.Marshal(barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior:       barprofile.Behavior{Form: "dock"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, barProfileFile), profileData, 0o644); err != nil {
		t.Fatal(err)
	}

	advanced, err := ThemeSet(themeRoot, "advanced-theme")
	if err != nil {
		t.Fatal(err)
	}
	if advanced.Activation == nil || advanced.Activation.State != FeatureReady {
		t.Fatalf("production Bar adapter did not activate: %#v", advanced)
	}
	configPath := filepath.Join(root, ".config", "omarchy", "shell.json")
	config, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(config, []byte(`"pretty.omagen.bar"`)) {
		t.Fatalf("production Bar adapter did not apply shell config: %s", config)
	}

	fastRoot := filepath.Join(root, "fast-theme")
	if err := os.MkdirAll(fastRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	fast, err := ThemeSet(fastRoot, "ryu")
	if err != nil {
		t.Fatal(err)
	}
	if fast.Deactivation == nil || fast.Deactivation.State != FeatureInactive {
		t.Fatalf("switching to a Fast theme did not deactivate Bar: %#v", fast)
	}
	if _, err := os.Stat(configPath); !os.IsNotExist(err) {
		t.Fatalf("Fast theme did not restore the absent user shell config: %v", err)
	}
}
