package apply

import (
	"errors"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

type testApplier struct {
	err   error
	theme string
}

type inspectingApplier struct {
	theme  string
	called bool
}

type postSwitchErrorApplier struct{}

type policyApplier struct {
	applyCalled  bool
	policyCalled bool
	run          string
	skip         string
}

type fastPreviewApplier struct {
	theme       string
	finalized   string
	applyCalled bool
}

func (postSwitchErrorApplier) ApplyTheme(string, string) error {
	return errors.New("post-switch failure")
}
func (postSwitchErrorApplier) CurrentTheme() (string, error) { return "test-theme", nil }

func (a *policyApplier) ApplyTheme(string, string) error {
	a.applyCalled = true
	return nil
}
func (a *policyApplier) ApplyThemeWithPolicy(_, _, run, skip string) error {
	a.policyCalled = true
	a.run = run
	a.skip = skip
	return nil
}

func (a *fastPreviewApplier) ApplyTheme(string, string) error {
	a.applyCalled = true
	return nil
}
func (a *fastPreviewApplier) ApplyThemeWithPolicy(string, string, string, string) error {
	a.applyCalled = true
	return nil
}
func (a *fastPreviewApplier) CurrentTheme() (string, error) { return a.theme, nil }
func (a *fastPreviewApplier) FinalizePreviewTheme(theme string) error {
	a.finalized = theme
	a.theme = theme
	return nil
}

func (a *inspectingApplier) ApplyTheme(string, string) error { a.called = true; return nil }
func (a *inspectingApplier) CurrentTheme() (string, error)   { return a.theme, nil }

func (a *testApplier) ApplyTheme(theme, _ string) error {
	a.theme = theme
	return a.err
}

func TestApplyUsesStudioPolicyByDefaultWhenAvailable(t *testing.T) {
	applier := &policyApplier{}
	service, _, sessionID := setupApplyTest(t, applier)
	variant, _ := generation.ParseVariant("source")
	if _, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Policy Theme"}); err != nil {
		t.Fatal(err)
	}
	if !applier.policyCalled || applier.applyCalled {
		t.Fatalf("policy_called=%t native_apply_called=%t", applier.policyCalled, applier.applyCalled)
	}
}

func TestApplyFinalizesMatchingLivePreviewWithoutRetinting(t *testing.T) {
	applier := &fastPreviewApplier{theme: "omagen-preview-session-1-generation-1-source"}
	service, store, sessionID := setupApplyTest(t, applier)
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.GenerationID = "generation-1"
	record.PreviewVariant = "source"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(service.currentThemeRoot, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "colors.toml"), []byte("from-preview\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "backgrounds", "wallpaper.png"), []byte("preview-image"), 0o644); err != nil {
		t.Fatal(err)
	}

	variant, _ := generation.ParseVariant("source")
	result, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Fast Theme"})
	if err != nil {
		t.Fatal(err)
	}
	if applier.finalized != "fast-theme" || applier.applyCalled {
		t.Fatalf("finalized=%q full_apply_called=%t", applier.finalized, applier.applyCalled)
	}
	contents, err := os.ReadFile(filepath.Join(result.ThemePath, "colors.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "from-preview\n" {
		t.Fatalf("published materialized preview=%q", contents)
	}
	if _, exists, err := store.LoadActive(); err != nil || exists {
		t.Fatalf("active session remains after fast finalize: exists=%t err=%v", exists, err)
	}
}

func TestApplyFinalizesMaterializedStyledPreviewWithoutLosingCandidate(t *testing.T) {
	// A preview with style or color overrides is assigned a deterministic
	// -colors-<hash> suffix. Apply must recognize that as the same preview so
	// it publishes the already-materialized dock/bar candidate.
	applier := &fastPreviewApplier{theme: "omagen-preview-session-1-generation-1-source-colors-99bfca879b614431"}
	service, store, sessionID := setupApplyTest(t, applier)
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.GenerationID = "generation-1"
	record.PreviewVariant = "source"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(service.currentThemeRoot, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "colors.toml"), []byte("from-styled-preview\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "shell.toml"), []byte("bar = \"dock\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	variant, _ := generation.ParseVariant("source")
	result, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Styled Dock Theme"})
	if err != nil {
		t.Fatal(err)
	}
	if applier.finalized != "styled-dock-theme" || applier.applyCalled {
		t.Fatalf("finalized=%q full_apply_called=%t", applier.finalized, applier.applyCalled)
	}
	contents, err := os.ReadFile(filepath.Join(result.ThemePath, "shell.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "bar = \"dock\"\n" {
		t.Fatalf("published styled preview=%q", contents)
	}
}

func TestApplyWithOptionalAssetsPublishesMatchingMaterializedPreview(t *testing.T) {
	applier := &fastPreviewApplier{theme: "omagen-preview-session-1-generation-1-source-colors-99bfca879b614431"}
	service, store, sessionID := setupApplyTest(t, applier)
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.GenerationID = "generation-1"
	record.PreviewVariant = "source"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(service.currentThemeRoot, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	wallpaper := image.NewRGBA(image.Rect(0, 0, 4, 3))
	wallpaper.Set(1, 1, color.RGBA{R: 255, A: 255})
	wallpaperFile, err := os.Create(filepath.Join(service.currentThemeRoot, "backgrounds", "wallpaper.png"))
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(wallpaperFile, wallpaper); err != nil {
		_ = wallpaperFile.Close()
		t.Fatal(err)
	}
	if err := wallpaperFile.Close(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "colors.toml"), []byte("from-styled-preview\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "hyprland.lua"), []byte("-- cyberpunk materialized preview\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(service.currentThemeRoot, "omagen-cyberpunk-glitch.frag"), []byte("#version 320 es\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := service.Apply(Request{
		SessionID:      sessionID,
		GenerationID:   "generation-1",
		Variant:        generation.Variant("source"),
		ThemeName:      "Cyber Materialized",
		GenerateUnlock: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if applier.finalized != "" || !applier.applyCalled {
		t.Fatalf("finalized=%q full_apply_called=%t", applier.finalized, applier.applyCalled)
	}
	for name, expected := range map[string]string{
		"colors.toml":                  "from-styled-preview\n",
		"hyprland.lua":                 "-- cyberpunk materialized preview\n",
		"omagen-cyberpunk-glitch.frag": "#version 320 es\n",
	} {
		contents, readErr := os.ReadFile(filepath.Join(result.ThemePath, name))
		if readErr != nil {
			t.Fatalf("read published %s: %v", name, readErr)
		}
		if string(contents) != expected {
			t.Fatalf("published %s=%q", name, contents)
		}
	}
	for _, name := range []string{"unlock.png", "preview-unlock.png"} {
		if info, statErr := os.Stat(filepath.Join(result.ThemePath, name)); statErr != nil || !info.Mode().IsRegular() {
			t.Fatalf("optional asset %s missing: info=%v err=%v", name, info, statErr)
		}
	}
}

func setupApplyTest(t *testing.T, applier ThemeApplier) (*Service, *session.Store, string) {
	t.Helper()
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{SessionID: "session-1", OriginalTheme: "old", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/old.png"}, CreatedAt: time.Now().UTC()}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	candidate := filepath.Join(store.SessionDir(record.SessionID), "generations", "generation-1", "source")
	if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "colors.toml"), []byte("background = \"#000000\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("image"), 0o644); err != nil {
		t.Fatal(err)
	}
	service, err := NewService(store, applier)
	if err != nil {
		t.Fatal(err)
	}
	return service, store, record.SessionID
}

func TestApplyFailureKeepsSessionActiveAndDoesNotPublish(t *testing.T) {
	applier := &testApplier{err: errors.New("theme set failed")}
	service, store, sessionID := setupApplyTest(t, applier)
	variant, parseErr := generation.ParseVariant("source")
	if parseErr != nil {
		t.Fatal(parseErr)
	}
	_, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Test Theme"})
	if err == nil {
		t.Fatal("expected apply failure")
	}
	if _, exists, loadErr := store.LoadActive(); loadErr != nil || !exists {
		t.Fatalf("session not recoverable: exists=%t err=%v", exists, loadErr)
	}
	destination := filepath.Join(service.themesRoot, "test-theme")
	if _, statErr := os.Stat(filepath.Join(destination, ".omagen-owner")); statErr != nil {
		t.Fatalf("prepared ownership marker missing: err=%v", statErr)
	}
	record, loadErr := store.Load(sessionID)
	if loadErr != nil || record.ApplyPhase != session.ApplyPhasePrepared {
		t.Fatalf("prepared transaction was not durable: record=%#v err=%v", record, loadErr)
	}
}

func TestReplaceSourceMovesExistingThemeBeforePublishing(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, &testApplier{})
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.Workflow = "theme-edit"
	record.ThemeEdit = &session.ThemeEdit{SourceID: "test-theme", SourceName: "Test Theme", SourcePath: "/source", SourceKind: "user"}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(service.themesRoot, "test-theme")
	if err := os.MkdirAll(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(destination, "original.txt"), []byte("preserve until commit"), 0o644); err != nil {
		t.Fatal(err)
	}
	result, err := service.Apply(Request{
		SessionID: sessionID, GenerationID: "generation-1", Variant: generation.Variant("source"),
		ThemeName: "Test Theme", DestinationPolicy: "replace-source",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.ThemeName != "test-theme" {
		t.Fatalf("result theme=%q", result.ThemeName)
	}
	if _, err := os.Stat(filepath.Join(destination, "original.txt")); !os.IsNotExist(err) {
		t.Fatalf("old source still present after replacement: err=%v", err)
	}
	if _, err := os.Stat(filepath.Join(destination, ".omagen-owner")); !os.IsNotExist(err) {
		t.Fatalf("owner marker not cleaned after commit: err=%v", err)
	}
	backup := filepath.Join(store.SessionDir(sessionID), "replacement-backup")
	if _, err := os.Stat(backup); !os.IsNotExist(err) {
		t.Fatalf("replacement backup not cleaned after commit: err=%v", err)
	}
}

func TestSameNameEditRequiresExplicitReplacementPolicy(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, &testApplier{})
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.Workflow = "theme-edit"
	record.ThemeEdit = &session.ThemeEdit{SourceID: "test-theme", SourceName: "Test Theme", SourcePath: "/source", SourceKind: "user"}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(service.themesRoot, "test-theme")
	if err := os.MkdirAll(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(destination, "original.txt"), []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Apply(Request{
		SessionID: sessionID, GenerationID: "generation-1", Variant: generation.Variant("source"), ThemeName: "Test Theme",
	}); err == nil {
		t.Fatal("same-name edit unexpectedly replaced a theme without explicit policy")
	}
	if data, err := os.ReadFile(filepath.Join(destination, "original.txt")); err != nil || string(data) != "keep" {
		t.Fatalf("existing theme changed after rejected apply: data=%q err=%v", data, err)
	}
}

func TestApplyStagesOptionalUnlockAndLivePreviewAssets(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, &testApplier{})
	candidate := filepath.Join(store.SessionDir(sessionID), "generations", "generation-1", "source")
	wallpaper := image.NewRGBA(image.Rect(0, 0, 4, 3))
	wallpaper.Set(1, 1, color.RGBA{R: 255, A: 255})
	wallpaperFile, err := os.Create(filepath.Join(candidate, "backgrounds", "wallpaper.png"))
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(wallpaperFile, wallpaper); err != nil {
		_ = wallpaperFile.Close()
		t.Fatal(err)
	}
	if err := wallpaperFile.Close(); err != nil {
		t.Fatal(err)
	}
	capturePath := filepath.Join(store.SessionDir(sessionID), "apply-preview.png")
	capture := image.NewRGBA(image.Rect(0, 0, 5, 4))
	capture.Set(2, 2, color.RGBA{G: 255, A: 255})
	captureFile, err := os.Create(capturePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(captureFile, capture); err != nil {
		_ = captureFile.Close()
		t.Fatal(err)
	}
	if err := captureFile.Close(); err != nil {
		t.Fatal(err)
	}

	result, err := service.Apply(Request{
		SessionID:      sessionID,
		GenerationID:   "generation-1",
		Variant:        generation.Variant("source"),
		ThemeName:      "Assets Theme",
		GenerateUnlock: true,
		CapturePreview: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"unlock.png", "preview-unlock.png", "preview.png"} {
		path := filepath.Join(result.ThemePath, name)
		if info, statErr := os.Stat(path); statErr != nil || !info.Mode().IsRegular() {
			t.Fatalf("optional asset %s missing: info=%v err=%v", name, info, statErr)
		}
	}
}

func TestPreparedApplyWithTargetThemeIsRecoveredAsCommitted(t *testing.T) {
	applier := &inspectingApplier{theme: "test-theme"}
	service, store, sessionID := setupApplyTest(t, applier)
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.ApplyPhase = session.ApplyPhasePrepared
	record.AppliedTheme = "test-theme"
	record.AppliedGeneration = "generation-1"
	record.AppliedVariant = "source"
	record.AppliedDisplayName = "Test Theme"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(service.themesRoot, "test-theme")
	if err := os.MkdirAll(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := writeOwnerMarker(destination, sessionID); err != nil {
		t.Fatal(err)
	}
	variant, _ := generation.ParseVariant("source")
	result, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Test Theme"})
	if err != nil {
		t.Fatal(err)
	}
	if result.ThemeName != "test-theme" || applier.called {
		t.Fatalf("recovered result=%#v applier_called=%t", result, applier.called)
	}
	if _, exists, err := store.LoadActive(); err != nil || exists {
		t.Fatalf("active marker remains after recovered commit: exists=%t err=%v", exists, err)
	}
}

func TestApplyErrorAfterThemeSwitchIsRecoveredAsCommitted(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, postSwitchErrorApplier{})
	variant, _ := generation.ParseVariant("source")
	if _, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Test Theme"}); err == nil {
		t.Fatal("expected post-switch Apply error")
	}
	record, err := store.Load(sessionID)
	if err != nil || record.ApplyPhase != session.ApplyPhasePrepared {
		t.Fatalf("transaction phase=%q err=%v", record.ApplyPhase, err)
	}
	result, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: variant, ThemeName: "Test Theme"})
	if err != nil {
		t.Fatal(err)
	}
	if result.ThemeName != "test-theme" {
		t.Fatalf("recovered result=%#v", result)
	}
}

func TestRecoverCommittedApplyRemovesStaleOwnerMarker(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, &testApplier{})
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.ApplyPhase = session.ApplyPhaseCommitted
	record.AppliedTheme = "test-theme"
	record.AppliedGeneration = "generation-1"
	record.AppliedVariant = "source"
	record.AppliedDisplayName = "Test Theme"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(service.themesRoot, record.AppliedTheme)
	if err := os.MkdirAll(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := writeOwnerMarker(destination, sessionID); err != nil {
		t.Fatal(err)
	}
	handled, err := service.RecoverPending(sessionID)
	if err != nil || !handled {
		t.Fatalf("handled=%t err=%v", handled, err)
	}
	if _, err := os.Stat(filepath.Join(destination, ".omagen-owner")); !os.IsNotExist(err) {
		t.Fatalf("stale owner marker remains, err=%v", err)
	}
}

func TestPreparedApplyActiveThemeWithoutOwnershipDoesNotCommit(t *testing.T) {
	service, store, sessionID := setupApplyTest(t, &inspectingApplier{theme: "test-theme"})
	record, err := store.Load(sessionID)
	if err != nil {
		t.Fatal(err)
	}
	record.ApplyPhase = session.ApplyPhasePrepared
	record.AppliedTheme = "test-theme"
	record.AppliedGeneration = "generation-1"
	record.AppliedVariant = "source"
	record.AppliedDisplayName = "Test Theme"
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Apply(Request{SessionID: sessionID, GenerationID: "generation-1", Variant: generation.Variant("source"), ThemeName: "Test Theme"}); err == nil {
		t.Fatal("expected ownership verification error")
	}
	got, err := store.Load(sessionID)
	if err != nil || got.ApplyPhase != session.ApplyPhasePrepared {
		t.Fatalf("transaction changed after ownership failure: record=%#v err=%v", got, err)
	}
	if _, exists, err := store.LoadActive(); err != nil || !exists {
		t.Fatalf("active marker changed after ownership failure: exists=%t err=%v", exists, err)
	}
}

func TestRestoreReplacementBackupNeverRemovesUnownedDestination(t *testing.T) {
	service, _, sessionID := setupApplyTest(t, &testApplier{})
	destination := filepath.Join(service.themesRoot, "existing-theme")
	backup := filepath.Join(service.sessions.SessionDir(sessionID), "replacement-backup")
	if err := os.MkdirAll(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(destination, "keep.txt"), []byte("user data"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(backup, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(backup, "old.txt"), []byte("backup"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := restoreReplacementBackup(destination, backup, sessionID); err == nil {
		t.Fatal("expected unowned destination refusal")
	}
	if _, err := os.Stat(filepath.Join(destination, "keep.txt")); err != nil {
		t.Fatalf("unowned destination was modified: %v", err)
	}
	if _, err := os.Stat(filepath.Join(backup, "old.txt")); err != nil {
		t.Fatalf("replacement backup was consumed after refusal: %v", err)
	}
}
