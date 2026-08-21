package demo

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/session"
)

func TestOpenRejectsPendingApplyBeforeTouchingDemoWorkspace(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "demo-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		ApplyPhase:         session.ApplyPhasePrepared,
		AppliedTheme:       "theme-name",
		AppliedGeneration:  "generation-1",
		AppliedVariant:     "source",
		AppliedDisplayName: "Theme Name",
		CreatedAt:          time.Now().UTC(),
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	service := NewService(store)
	if _, err := service.Open(record.SessionID); !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}

func TestDemoStateCommitRejectsCancellationWonRace(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "demo-race",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
	}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: time.Now().UTC()}); err != nil {
		t.Fatal(err)
	}
	if err := store.ClearActive(record.SessionID); err != nil {
		t.Fatal(err)
	}
	state := State{SessionID: record.SessionID, Workspace: "workspace", Windows: map[Slot]string{}}
	if err := NewService(store).saveStateIfActive(state); !errors.Is(err, session.ErrSessionNotActive) {
		t.Fatalf("error=%v, want ErrSessionNotActive", err)
	}
	if _, err := os.Stat(filepath.Join(store.SessionDir(record.SessionID), "demo-state.json")); !os.IsNotExist(err) {
		t.Fatalf("demo state was persisted after cancellation, err=%v", err)
	}
}
