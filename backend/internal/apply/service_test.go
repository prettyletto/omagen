package apply

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
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

func (postSwitchErrorApplier) ApplyTheme(string, string) error {
	return errors.New("post-switch failure")
}
func (postSwitchErrorApplier) CurrentTheme() (string, error) { return "test-theme", nil }

func (a *inspectingApplier) ApplyTheme(string, string) error { a.called = true; return nil }
func (a *inspectingApplier) CurrentTheme() (string, error)   { return a.theme, nil }

func (a *testApplier) ApplyTheme(theme, _ string) error {
	a.theme = theme
	return a.err
}

func setupApplyTest(t *testing.T, applier ThemeApplier) (*Service, *session.Store, string) {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
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
