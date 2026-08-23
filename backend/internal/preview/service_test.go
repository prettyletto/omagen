package preview

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

type previewApplier struct{}

func (previewApplier) ApplyThemePreview(string, string) (int, bool, error) { return 0, false, nil }

func TestApplyPublishesProtocolOperationAndCheckpoint(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "protocol-preview-session",
		OriginalTheme:      "theme",
		OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"},
		CreatedAt:          time.Now().UTC(),
	}
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
	if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("not-an-image"), 0o644); err != nil {
		t.Fatal(err)
	}

	service := newServiceWithThemeRoot(store, previewApplier{}, t.TempDir())
	result, err := service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Variant("source")})
	if err != nil {
		t.Fatal(err)
	}
	if result.ProtocolOperation == "" || result.ProtocolCheckpoint == "" || result.ProtocolSocket == "" {
		t.Fatalf("protocol metadata = %#v", result)
	}

	journal, err := protocol.Open(result.ProtocolEvents)
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := journal.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Operations) != 3 || snapshot.Operations[0].Status != protocol.StatusSucceeded || len(snapshot.Operations[0].Children) != 2 {
		t.Fatalf("protocol operations = %#v", snapshot.Operations)
	}
	if snapshot.CurrentCheckpointID != result.ProtocolCheckpoint {
		t.Fatalf("protocol cursor = %#v", snapshot)
	}
	if len(snapshot.Checkpoints) != 1 || snapshot.Checkpoints[0].Name != "source" {
		t.Fatalf("protocol checkpoints = %#v", snapshot.Checkpoints)
	}
	events, err := journal.Events(0)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 9 || events[2].Type != protocol.EventOperationProgress || events[7].Type != protocol.EventCheckpointCreated {
		t.Fatalf("protocol events = %#v", events)
	}
}

func TestApplyRejectsPendingTransactionBeforePublishingPreview(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{
		SessionID:          "preview-session",
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
	service := newServiceWithThemeRoot(store, previewApplier{}, t.TempDir())
	_, err = service.Apply(Request{SessionID: record.SessionID, GenerationID: "generation-1", Variant: generation.Variant("source")})
	if !errors.Is(err, session.ErrApplyInProgress) {
		t.Fatalf("error=%v, want ErrApplyInProgress", err)
	}
}
