package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func TestProtocolInspectCLIReturnsDurableSnapshot(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	journal, paths, err := protocol.OpenForSession(store.StateRoot(), "cli-session")
	if err != nil {
		t.Fatal(err)
	}
	operation, err := journal.StartOperation(protocol.OperationInput{Name: "inspectable", SessionID: "cli-session"})
	if err != nil {
		t.Fatal(err)
	}
	checkpoint, err := journal.CreateCheckpoint(protocol.CheckpointInput{OperationID: operation.ID, Name: "candidate", State: []byte(`{"theme":"candidate"}`)})
	if err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	if status := Run([]string{"protocol", "inspect", "cli-session"}, &stdout, &stderr); status != 0 {
		t.Fatalf("status=%d stderr=%s", status, stderr.String())
	}
	var response protocolInspectResponse
	if err := json.Unmarshal(stdout.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Paths != paths || response.Snapshot.CurrentCheckpointID != checkpoint.ID {
		t.Fatalf("protocol inspect response = %#v", response)
	}
}

func TestProtocolNavigationCLIMovesTheCursor(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{SessionID: "cli-navigation", OriginalTheme: "original", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}, GenerationID: "generation-1", CreatedAt: time.Now().UTC()}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	for _, variant := range []string{"source", "calm"} {
		candidate := filepath.Join(store.SessionDir(record.SessionID), "generations", record.GenerationID, variant)
		if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(candidate, "colors.toml"), []byte("primary = \"#fff\"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("wallpaper"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	path := filepath.Join(store.StateRoot(), "protocol", "cli-navigation", "events.jsonl")
	journal, err := protocol.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	operation, err := journal.StartOperation(protocol.OperationInput{Name: "navigation", SessionID: "cli-navigation"})
	if err != nil {
		t.Fatal(err)
	}
	firstState := []byte(`{"theme_name":"omagen-preview-cli-navigation-generation-1-source","generation_id":"generation-1","variant":"source","mode":"preview"}`)
	secondState := []byte(`{"theme_name":"omagen-preview-cli-navigation-generation-1-calm","generation_id":"generation-1","variant":"calm","mode":"preview"}`)
	if _, err := journal.CreateCheckpoint(protocol.CheckpointInput{OperationID: operation.ID, Name: "first", State: firstState}); err != nil {
		t.Fatal(err)
	}
	second, err := journal.CreateCheckpoint(protocol.CheckpointInput{OperationID: operation.ID, Name: "second", State: secondState})
	if err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	previewService, err := preview.NewService(store, cliPreviewApplier{})
	if err != nil {
		t.Fatal(err)
	}
	if status := runProtocol([]string{"back", "cli-navigation"}, store, previewService, &stdout, &stderr); status != 0 {
		t.Fatalf("back status=%d stderr=%s", status, stderr.String())
	}
	stdout.Reset()
	if status := runProtocol([]string{"forward", "cli-navigation", second.ID}, store, previewService, &stdout, &stderr); status != 0 {
		t.Fatalf("forward status=%d stderr=%s", status, stderr.String())
	}
	var navigation protocol.NavigationResult
	if err := json.Unmarshal(stdout.Bytes(), &navigation); err != nil {
		t.Fatal(err)
	}
	if navigation.ToCheckpointID != second.ID || string(navigation.State) != string(secondState) {
		t.Fatalf("navigation = %#v", navigation)
	}
}

func TestProtocolNavigationLeavesCursorInPlaceWhenReapplyFails(t *testing.T) {
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	record := session.Record{SessionID: "cli-navigation-failure", OriginalTheme: "original", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg"}, GenerationID: "generation-1", CreatedAt: time.Now().UTC()}
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	for _, variant := range []string{"source", "calm"} {
		candidate := filepath.Join(store.SessionDir(record.SessionID), "generations", record.GenerationID, variant)
		if err := os.MkdirAll(filepath.Join(candidate, "backgrounds"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(candidate, "colors.toml"), []byte("primary = \"#fff\"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(candidate, "backgrounds", "wallpaper.png"), []byte("wallpaper"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	journal, err := protocol.Open(filepath.Join(store.StateRoot(), "protocol", record.SessionID, "events.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	op, err := journal.StartOperation(protocol.OperationInput{Name: "navigation", SessionID: record.SessionID})
	if err != nil {
		t.Fatal(err)
	}
	first := []byte(`{"theme_name":"omagen-preview-cli-navigation-failure-generation-1-source","generation_id":"generation-1","variant":"source","mode":"preview"}`)
	second := []byte(`{"theme_name":"omagen-preview-cli-navigation-failure-generation-1-calm","generation_id":"generation-1","variant":"calm","mode":"preview"}`)
	if _, err := journal.CreateCheckpoint(protocol.CheckpointInput{OperationID: op.ID, Name: "first", State: first}); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.CreateCheckpoint(protocol.CheckpointInput{OperationID: op.ID, Name: "second", State: second}); err != nil {
		t.Fatal(err)
	}
	previewService, err := preview.NewService(store, failingPreviewApplier{})
	if err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if status := runProtocol([]string{"back", record.SessionID}, store, previewService, &stdout, &stderr); status == 0 {
		t.Fatal("expected failed checkpoint reapply")
	}
	snapshot, err := journal.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.CurrentCheckpointID == "" || snapshot.CurrentCheckpointID != snapshot.Checkpoints[1].ID {
		t.Fatalf("cursor moved after failed reapply: %#v", snapshot)
	}
}

type cliPreviewApplier struct{}

func (cliPreviewApplier) ApplyThemePreview(string, string) (int, bool, error) { return 0, false, nil }

type failingPreviewApplier struct{}

func (failingPreviewApplier) ApplyThemePreview(string, string) (int, bool, error) {
	return 0, false, fmt.Errorf("native preview failed")
}
