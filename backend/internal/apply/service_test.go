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
	if _, statErr := os.Stat(filepath.Join(service.themesRoot, "test-theme")); !os.IsNotExist(statErr) {
		t.Fatalf("failed apply published theme: err=%v", statErr)
	}
}
