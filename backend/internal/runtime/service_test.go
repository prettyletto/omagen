package runtime

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func TestManifestRoundTripAndFastThemeDetection(t *testing.T) {
	testenv.Isolate(t)
	themeRoot := filepath.Join(t.TempDir(), "theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, ok, err := ReadManifest(themeRoot); err != nil || ok {
		t.Fatalf("missing manifest = ok:%t err:%v", ok, err)
	}
	manifest := AdvancedManifest("shell", "bar")
	if err := WriteManifest(themeRoot, manifest); err != nil {
		t.Fatal(err)
	}
	got, ok, err := ReadManifest(themeRoot)
	if err != nil || !ok {
		t.Fatalf("read manifest = %#v ok:%t err:%v", got, ok, err)
	}
	if got.Mode != "advanced" || got.Runtime != "pretty.omagen" || !got.RequiresRuntime {
		t.Fatalf("unexpected manifest: %#v", got)
	}
	data, err := os.ReadFile(filepath.Join(themeRoot, ManifestFileName))
	if err != nil {
		t.Fatal(err)
	}
	var decoded Manifest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	if err := decoded.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestInstallRefusesToReplaceAnotherThemeSetHook(t *testing.T) {
	testenv.Isolate(t)
	_, hookPath, _, err := Paths()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(hookPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(hookPath, []byte("#!/bin/sh\necho user hook\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	if _, err := Install(); err == nil {
		t.Fatal("expected non-Omagen hook to be preserved")
	}
	data, err := os.ReadFile(hookPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "#!/bin/sh\necho user hook\n" {
		t.Fatalf("user hook changed: %q", data)
	}
}

func TestInstallIsIdempotentAndRecordsConsent(t *testing.T) {
	testenv.Isolate(t)
	first, err := Install()
	if err != nil {
		t.Fatal(err)
	}
	second, err := Install()
	if err != nil {
		t.Fatal(err)
	}
	if !first.Installed || !second.Installed || first.HookPath != second.HookPath {
		t.Fatalf("install results differ: first=%#v second=%#v", first, second)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if !state.Installed || !IsOwnedHook(first.HookPath) {
		t.Fatalf("consent state not recorded: state=%#v hook=%t", state, IsOwnedHook(first.HookPath))
	}
}

func TestThemeSetLeavesFastThemeNativeOnly(t *testing.T) {
	testenv.Isolate(t)
	themeRoot := filepath.Join(t.TempDir(), "theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	result, err := ThemeSet(themeRoot, "plain")
	if err != nil {
		t.Fatal(err)
	}
	if !result.NativeOnly || result.Advanced || result.RuntimeReady {
		t.Fatalf("unexpected fast theme result: %#v", result)
	}
}

func TestThemeSetActivatesCompleteAdvancedContract(t *testing.T) {
	testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	themeRoot := filepath.Join(t.TempDir(), "advanced-theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := WriteManifest(themeRoot, AdvancedManifest("shell", "bar", "window", "animations")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, shellConfigFile), []byte("[popups]\nbackground-alpha = 0.82\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, hyprlandConfigFile), []byte("hl.config({})\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	profileData, err := json.Marshal(barprofile.Profile{
		Ownership:      barprofile.OwnershipOverlay,
		Implementation: barprofile.ImplementationReplacement,
		Bar:            json.RawMessage(`{"id":"pretty.omagen.bar"}`),
		Behavior:       barprofile.Behavior{Form: "islands", Visibility: "always", Reveal: "edge", Expansion: "focus", Workspace: "segmented"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(themeRoot, barProfileFile), profileData, 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := ThemeSet(themeRoot, "advanced-theme")
	if err != nil {
		t.Fatal(err)
	}
	if !result.RuntimeReady || result.NativeOnly || result.RuntimeState != FeatureReady {
		t.Fatalf("complete advanced contract did not activate: %#v", result)
	}
	if result.Activation == nil || len(result.Activation.Features) != 4 {
		t.Fatalf("unexpected activation report: %#v", result.Activation)
	}
	for _, feature := range result.Activation.Features {
		if feature.State != FeatureReady {
			t.Fatalf("feature %q did not activate: %#v", feature.Feature, result.Activation.Features)
		}
	}
}

func TestThemeSetClearsStaleActivationWhenSameNameBecomesNative(t *testing.T) {
	testenv.Isolate(t)
	if _, err := Install(); err != nil {
		t.Fatal(err)
	}
	advancedRoot := filepath.Join(t.TempDir(), "advanced-theme")
	if err := os.MkdirAll(advancedRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := WriteManifest(advancedRoot, AdvancedManifest("shell")); err != nil {
		t.Fatal(err)
	}
	if _, err := ThemeSet(advancedRoot, "same-theme"); err != nil {
		t.Fatal(err)
	}
	plainRoot := filepath.Join(t.TempDir(), "plain-theme")
	if err := os.MkdirAll(plainRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	result, err := ThemeSet(plainRoot, "same-theme")
	if err != nil {
		t.Fatal(err)
	}
	if result.RuntimeState != FeatureInactive || result.Deactivation == nil {
		t.Fatalf("stale activation was not deactivated: %#v", result)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if state.LastActivation != nil {
		t.Fatalf("stale activation remained after native same-name theme: %#v", state)
	}
}

func TestFallbackNotificationIsBestEffortAndDeduplicated(t *testing.T) {
	root := testenv.Isolate(t)
	themeRoot := filepath.Join(t.TempDir(), "theme")
	if err := os.MkdirAll(themeRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := WriteManifest(themeRoot, AdvancedManifest("shell")); err != nil {
		t.Fatal(err)
	}

	binDir := filepath.Join(root, "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		t.Fatal(err)
	}
	logPath := filepath.Join(root, "notification.log")
	notifier := filepath.Join(binDir, "omarchy-notification-send")
	contents := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$NOTIFICATION_LOG\"\n"
	if err := os.WriteFile(notifier, []byte(contents), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("NOTIFICATION_LOG", logPath)
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))

	first, err := CheckAndNotifyFallback(themeRoot, "advanced-theme")
	if err != nil {
		t.Fatal(err)
	}
	if !first.Required || !first.NativeOnly || !first.NotificationShown {
		t.Fatalf("unexpected first fallback status: %#v", first)
	}
	if _, err := os.Stat(logPath); err != nil {
		t.Fatal(err)
	}
	second, err := CheckAndNotifyFallback(themeRoot, "advanced-theme")
	if err != nil {
		t.Fatal(err)
	}
	if second.NotificationShown {
		t.Fatalf("duplicate fallback notification: %#v", second)
	}
	state, err := LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if state.LastFallbackNotification != "advanced-theme" {
		t.Fatalf("fallback notification was not recorded: %#v", state)
	}
}
