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
	if _, err := os.Stat(filepath.Join(stateRoot, "snapshots", activeBarSnapshotID+".json")); !os.IsNotExist(err) {
		t.Fatalf("active bar snapshot was not removed after restore: %v", err)
	}
}

func TestThemeSetHandsReplacementBarDirectlyBetweenAdvancedThemes(t *testing.T) {
	root := testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(root, ".config", "omarchy", "shell.json")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	original := []byte("{\n  \"bar\": {\"layout\": {\"right\": []}},\n  \"user\": true\n}\n")
	if err := os.WriteFile(configPath, original, 0o600); err != nil {
		t.Fatal(err)
	}
	profile := barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior:       barprofile.Behavior{Form: "dock"},
	}
	writeTheme := func(name string) string {
		t.Helper()
		themeRoot := filepath.Join(root, name)
		if err := os.MkdirAll(themeRoot, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := WriteManifest(themeRoot, AdvancedManifest("bar")); err != nil {
			t.Fatal(err)
		}
		data, err := json.Marshal(profile)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(themeRoot, barProfileFile), data, 0o644); err != nil {
			t.Fatal(err)
		}
		return themeRoot
	}

	firstRoot := writeTheme("advanced-a")
	secondRoot := writeTheme("advanced-b")
	if result, err := ThemeSet(firstRoot, "advanced-a"); err != nil || !result.RuntimeReady {
		t.Fatalf("activate first advanced theme: result=%#v err=%v", result, err)
	}
	before, err := os.Stat(configPath)
	if err != nil {
		t.Fatal(err)
	}
	result, err := ThemeSet(secondRoot, "advanced-b")
	if err != nil {
		t.Fatal(err)
	}
	if !result.RuntimeReady || result.Deactivation == nil {
		t.Fatalf("advanced handoff did not complete: %#v", result)
	}
	after, err := os.Stat(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !os.SameFile(before, after) {
		t.Fatal("advanced handoff replaced shell.json even though the replacement selector was unchanged")
	}
	configured, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(configured, []byte(`"pretty.omagen.bar"`)) {
		t.Fatalf("replacement bar was unmounted during handoff: %s", configured)
	}

	plainRoot := filepath.Join(root, "native")
	if err := os.MkdirAll(plainRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := ThemeSet(plainRoot, "native"); err != nil {
		t.Fatal(err)
	}
	restored, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(restored, original) {
		t.Fatalf("native baseline was not restored after handoff:\nwant:%s\ngot:%s", original, restored)
	}
	stateRoot := filepath.Join(root, ".local", "state", "omagen", "bar", "snapshots")
	if _, err := os.Stat(filepath.Join(stateRoot, activeBarSnapshotID+".json")); !os.IsNotExist(err) {
		t.Fatalf("stable baseline remained after native restore: %v", err)
	}
}

func TestThemeSetPreflightsAdvancedTargetBeforeUnmountingCurrentBar(t *testing.T) {
	root := testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	validRoot := filepath.Join(root, "valid")
	invalidRoot := filepath.Join(root, "invalid")
	for _, themeRoot := range []string{validRoot, invalidRoot} {
		if err := os.MkdirAll(themeRoot, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := WriteManifest(themeRoot, AdvancedManifest("bar")); err != nil {
			t.Fatal(err)
		}
	}
	profile := barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
	}
	data, err := json.Marshal(profile)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(validRoot, barProfileFile), data, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(invalidRoot, barProfileFile), []byte(`{"implementation":`), 0o644); err != nil {
		t.Fatal(err)
	}
	if result, err := ThemeSet(validRoot, "valid"); err != nil || !result.RuntimeReady {
		t.Fatalf("activate valid theme: result=%#v err=%v", result, err)
	}
	configPath := filepath.Join(root, ".config", "omarchy", "shell.json")
	before, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	result, err := ThemeSet(invalidRoot, "invalid")
	if err != nil {
		t.Fatal(err)
	}
	if result.RuntimeState != FeatureFailed || result.Deactivation != nil {
		t.Fatalf("invalid target was not fenced before deactivation: %#v", result)
	}
	after, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(after, before) || !bytes.Contains(after, []byte(`"pretty.omagen.bar"`)) {
		t.Fatalf("current replacement bar changed after target preflight failure: %s", after)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if state.LastActivation == nil || state.LastActivation.Theme != "valid" {
		t.Fatalf("current activation was lost after target preflight failure: %#v", state.LastActivation)
	}
}

func TestBarHandoffMigratesLegacyPerThemeBaseline(t *testing.T) {
	root := t.TempDir()
	configPath := filepath.Join(root, "shell.json")
	stateRoot := filepath.Join(root, "bar-state")
	original := []byte("{\n  \"bar\": {\"layout\": {\"left\": []}},\n  \"kept\": true\n}\n")
	if err := os.WriteFile(configPath, original, 0o600); err != nil {
		t.Fatal(err)
	}
	store := barprofile.NewStoreAt(configPath, stateRoot)
	legacy, err := store.Capture("advanced-a")
	if err != nil {
		t.Fatal(err)
	}
	if err := store.SaveSnapshot(barSnapshotID("advanced-a"), legacy); err != nil {
		t.Fatal(err)
	}
	profile := barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
	}
	if err := store.Apply(profile); err != nil {
		t.Fatal(err)
	}
	themeRoot := filepath.Join(root, "advanced-b")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	data, err := json.Marshal(profile)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, barProfileFile), data, 0o644); err != nil {
		t.Fatal(err)
	}
	adapter, err := NewBarAdapter(store)
	if err != nil {
		t.Fatal(err)
	}
	request := testActivationRequest("bar")
	request.ThemeName = "advanced-b"
	request.ThemeRoot = themeRoot
	if err := adapter.PrepareTransition("advanced-a", request); err != nil {
		t.Fatal(err)
	}
	migrated, err := store.LoadSnapshot(activeBarSnapshotID)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(migrated.Config, original) {
		t.Fatalf("legacy baseline was not migrated exactly: %s", migrated.Config)
	}
	if _, err := adapter.Deactivate(context.Background(), DeactivationRequest{
		ThemeName: "advanced-a",
		Reason:    "advanced handoff",
		Preserve:  []Feature{FeatureBar},
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(stateRoot, "snapshots", barSnapshotID("advanced-a")+".json")); !os.IsNotExist(err) {
		t.Fatalf("legacy snapshot remained after handoff: %v", err)
	}
	if _, err := adapter.Activate(context.Background(), request); err != nil {
		t.Fatal(err)
	}
	if _, err := adapter.Deactivate(context.Background(), DeactivationRequest{ThemeName: "advanced-b", Reason: "native theme"}); err != nil {
		t.Fatal(err)
	}
	restored, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(restored, original) {
		t.Fatalf("migrated baseline did not restore exactly: %s", restored)
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
