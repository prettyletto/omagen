package barprofile

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestSnapshotRestorePreservesExactUserConfig(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "shell.json")
	original := []byte("{\n  \"version\": 1,\n  \"bar\": {\"layout\": {\"left\": [{\"id\": \"user.widget\", \"future\": true}]}}\n}\n")
	if err := os.WriteFile(config, original, 0o640); err != nil {
		t.Fatal(err)
	}
	store := NewStoreAt(config, filepath.Join(root, "state"))
	snapshot, err := store.Capture("theme-a")
	if err != nil {
		t.Fatal(err)
	}
	if err := store.SaveSnapshot("session", snapshot); err != nil {
		t.Fatal(err)
	}
	profile := Profile{Ownership: OwnershipOverlay, Implementation: ImplementationAdapter, Bar: json.RawMessage(`{"transparent":true}`)}
	if err := store.Apply(profile); err != nil {
		t.Fatal(err)
	}
	changed, _ := os.ReadFile(config)
	if string(changed) == string(original) {
		t.Fatal("profile did not change config")
	}
	loaded, err := store.LoadSnapshot("session")
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Restore(loaded); err != nil {
		t.Fatal(err)
	}
	restored, _ := os.ReadFile(config)
	if string(restored) != string(original) {
		t.Fatalf("restore changed bytes:\nwant %q\ngot  %q", original, restored)
	}
	if mode := mustMode(t, config); mode != 0o640 {
		t.Fatalf("restore mode = %o, want 640", mode)
	}
}

func TestRestoreRemovesConfigThatDidNotExist(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "missing-shell.json")
	store := NewStoreAt(config, filepath.Join(root, "state"))
	snapshot, err := store.Capture("theme-a")
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.ConfigExists {
		t.Fatal("missing config was captured as present")
	}
	if err := os.WriteFile(config, []byte("temporary"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Restore(snapshot); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(config); !os.IsNotExist(err) {
		t.Fatalf("config still exists: %v", err)
	}
}

func TestSnapshotRestorePreservesBarHiddenToggle(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "shell.json")
	hidden := filepath.Join(root, "toggles", "bar-off")
	if err := os.MkdirAll(filepath.Dir(hidden), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(config, []byte(`{"bar":{}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(hidden, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	store := NewStoreAt(config, filepath.Join(root, "state"), hidden)
	snapshot, err := store.Capture("theme")
	if err != nil {
		t.Fatal(err)
	}
	if !snapshot.HiddenToggleExists || snapshot.HiddenTogglePath != hidden {
		t.Fatalf("hidden toggle was not captured: %#v", snapshot)
	}
	if err := os.Remove(hidden); err != nil {
		t.Fatal(err)
	}
	if err := store.Restore(snapshot); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(hidden); err != nil {
		t.Fatalf("hidden toggle was not restored: %v", err)
	}
}

func TestApplyThemeOwnedProfileCreatesMissingShellConfig(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "shell.json")
	store := NewStoreAt(config, filepath.Join(root, "state"))
	profile := Profile{
		Ownership:      OwnershipThemeOwned,
		Implementation: ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.theme.bar","layout":{"center":[{"id":"theme.clock"}]}}`),
	}
	if err := store.Apply(profile); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(config)
	if err != nil {
		t.Fatal(err)
	}
	var rootConfig map[string]any
	if err := json.Unmarshal(data, &rootConfig); err != nil {
		t.Fatal(err)
	}
	bar, ok := rootConfig["bar"].(map[string]any)
	if !ok || bar["id"] != "pretty.theme.bar" {
		t.Fatalf("effective bar = %#v", rootConfig["bar"])
	}
}

func TestApplyFromSnapshotDerivesOverlayFromBaseline(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "shell.json")
	original := []byte(`{"version":1,"bar":{"layout":{"left":[{"id":"user.widget"}]},"position":"top"}}`)
	if err := os.WriteFile(config, original, 0o640); err != nil {
		t.Fatal(err)
	}
	store := NewStoreAt(config, filepath.Join(root, "state"))
	snapshot, err := store.Capture("theme-a")
	if err != nil {
		t.Fatal(err)
	}

	// Simulate the previously live replacement bar. The next preview must not
	// merge its overlay into this transient state.
	if err := os.WriteFile(config, []byte(`{"version":1,"bar":{"id":"previous.theme.bar","layout":{"center":[]}}}`), 0o640); err != nil {
		t.Fatal(err)
	}
	profile := Profile{
		Ownership:      OwnershipOverlay,
		Implementation: ImplementationAdapter,
		Bar:            json.RawMessage(`{"transparent":true}`),
	}
	if err := store.ApplyFromSnapshot(snapshot, profile); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(config)
	if err != nil {
		t.Fatal(err)
	}
	var result struct {
		Bar map[string]json.RawMessage `json:"bar"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	if _, exists := result.Bar["id"]; exists {
		t.Fatalf("transient replacement bar leaked into baseline-derived profile: %s", data)
	}
	if _, exists := result.Bar["layout"]; !exists {
		t.Fatalf("baseline layout was lost: %s", data)
	}
	if string(result.Bar["transparent"]) != "true" {
		t.Fatalf("overlay was not applied: %s", data)
	}
	if mode := mustMode(t, config); mode != 0o640 {
		t.Fatalf("profile mode = %o, want baseline mode 640", mode)
	}
}

func TestRestoreLeavesMatchingConfigInPlace(t *testing.T) {
	root := t.TempDir()
	config := filepath.Join(root, "shell.json")
	original := []byte("{\n  \"version\": 1,\n  \"bar\": {}\n}\n")
	if err := os.WriteFile(config, original, 0o640); err != nil {
		t.Fatal(err)
	}
	store := NewStoreAt(config, filepath.Join(root, "state"))
	snapshot, err := store.Capture("theme-a")
	if err != nil {
		t.Fatal(err)
	}
	before, err := os.Stat(config)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Restore(snapshot); err != nil {
		t.Fatal(err)
	}
	after, err := os.Stat(config)
	if err != nil {
		t.Fatal(err)
	}
	if !os.SameFile(before, after) {
		t.Fatal("matching baseline was replaced and would trigger a redundant Quickshell reload")
	}
}

func mustMode(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	return info.Mode().Perm()
}
