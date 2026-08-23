package protocol

import (
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"testing"
)

func TestJournalPersistsOperationTreeAndCheckpointState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "protocol", "events.jsonl")

	journal, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	root, err := journal.StartOperation(OperationInput{
		Name:         "preview",
		SessionID:    "session-1",
		GenerationID: "generation-1",
		Variant:      "source",
	})
	if err != nil {
		t.Fatal(err)
	}
	step, err := journal.StartOperation(OperationInput{
		ParentID:  root.ID,
		Name:      "promote",
		SessionID: "session-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Progress(step.ID, "theme promoted", "current theme and lock verified", nil); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.CompleteOperation(step.ID, StatusSucceeded, "promotion complete", "filesystem verified"); err != nil {
		t.Fatal(err)
	}

	state := json.RawMessage(`{"theme":"candidate-a","scope":["theme","shell"]}`)
	checkpoint, err := journal.CreateCheckpoint(CheckpointInput{
		OperationID: root.ID,
		Name:        "candidate-a",
		State:       state,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.CompleteOperation(root.ID, StatusSucceeded, "preview ready", "critical state active"); err != nil {
		t.Fatal(err)
	}

	snapshot, err := journal.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.LastSequence != 6 {
		t.Fatalf("last sequence = %d, want 6", snapshot.LastSequence)
	}
	if len(snapshot.Operations) != 2 || snapshot.Operations[0].Children[0] != step.ID {
		t.Fatalf("operation tree = %#v", snapshot.Operations)
	}
	if snapshot.Operations[0].Status != StatusSucceeded || snapshot.Operations[1].Status != StatusSucceeded {
		t.Fatalf("operation statuses = %#v", snapshot.Operations)
	}
	if snapshot.CurrentCheckpointID != checkpoint.ID || string(snapshot.CurrentState) != string(state) {
		t.Fatalf("checkpoint cursor = %#v", snapshot)
	}

	reopened, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	reopenedSnapshot, err := reopened.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if reopenedSnapshot.CurrentCheckpointID != checkpoint.ID || len(reopenedSnapshot.Operations) != 2 {
		t.Fatalf("reopened snapshot = %#v", reopenedSnapshot)
	}
}

func TestJournalNavigationBranchesAndRequiresChoice(t *testing.T) {
	journal, err := Open(filepath.Join(t.TempDir(), "events.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	root, err := journal.StartOperation(OperationInput{Name: "session"})
	if err != nil {
		t.Fatal(err)
	}
	first, err := journal.CreateCheckpoint(CheckpointInput{OperationID: root.ID, Name: "first", State: json.RawMessage(`{"theme":"first"}`)})
	if err != nil {
		t.Fatal(err)
	}
	second, err := journal.CreateCheckpoint(CheckpointInput{OperationID: root.ID, Name: "second", State: json.RawMessage(`{"theme":"second"}`)})
	if err != nil {
		t.Fatal(err)
	}

	back, err := journal.Back()
	if err != nil {
		t.Fatal(err)
	}
	if back.ToCheckpointID != first.ID || string(back.State) != `{"theme":"first"}` {
		t.Fatalf("back = %#v", back)
	}
	forward, err := journal.Forward("")
	if err != nil {
		t.Fatal(err)
	}
	if forward.ToCheckpointID != second.ID {
		t.Fatalf("forward = %#v", forward)
	}

	if _, err := journal.Back(); err != nil {
		t.Fatal(err)
	}
	branch, err := journal.CreateCheckpoint(CheckpointInput{OperationID: root.ID, Name: "branch", State: json.RawMessage(`{"theme":"branch"}`)})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Back(); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Forward(""); !errors.Is(err, ErrAmbiguousForward) {
		t.Fatalf("forward without choice error = %v, want %v", err, ErrAmbiguousForward)
	}
	chosen, err := journal.Forward(branch.ID)
	if err != nil {
		t.Fatal(err)
	}
	if chosen.ToCheckpointID != branch.ID {
		t.Fatalf("chosen branch = %#v", chosen)
	}
}

func TestJournalRejectsInvalidTransitions(t *testing.T) {
	journal, err := Open(filepath.Join(t.TempDir(), "events.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Progress("missing", "no", "", nil); !errors.Is(err, ErrOperationNotFound) {
		t.Fatalf("missing operation error = %v", err)
	}
	if _, err := journal.CreateCheckpoint(CheckpointInput{ParentID: "missing", State: json.RawMessage(`{}`)}); !errors.Is(err, ErrCheckpointNotFound) {
		t.Fatalf("missing checkpoint parent error = %v", err)
	}
	if _, err := journal.Back(); !errors.Is(err, ErrNoHistory) {
		t.Fatalf("empty back error = %v", err)
	}

	op, err := journal.StartOperation(OperationInput{Name: "operation"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.CompleteOperation(op.ID, StatusSucceeded, "done", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Progress(op.ID, "late", "", nil); !errors.Is(err, ErrOperationClosed) {
		t.Fatalf("closed operation error = %v", err)
	}
	if _, err := journal.CreateCheckpoint(CheckpointInput{OperationID: op.ID, State: json.RawMessage(`not-json`)}); !errors.Is(err, ErrInvalidPayload) {
		t.Fatalf("invalid payload error = %v", err)
	}
}

func TestJournalSubscriptionReplaysAndStreams(t *testing.T) {
	journal, err := Open(filepath.Join(t.TempDir(), "events.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	operation, err := journal.StartOperation(OperationInput{Name: "preview"})
	if err != nil {
		t.Fatal(err)
	}
	subscription, err := journal.Subscribe(0, 8)
	if err != nil {
		t.Fatal(err)
	}
	defer subscription.Close()

	replayed := <-subscription.Events
	if replayed.Type != EventOperationStarted || replayed.OperationID != operation.ID {
		t.Fatalf("replayed event = %#v", replayed)
	}
	if _, err := journal.Progress(operation.ID, "driver started", "", nil); err != nil {
		t.Fatal(err)
	}
	live := <-subscription.Events
	if live.Type != EventOperationProgress || live.Message != "driver started" {
		t.Fatalf("live event = %#v", live)
	}
}

func TestJournalRefreshesEventsWrittenByAnotherProcess(t *testing.T) {
	path := filepath.Join(t.TempDir(), "events.jsonl")
	writer, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	reader, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	subscription, err := reader.Subscribe(0, 8)
	if err != nil {
		t.Fatal(err)
	}
	defer subscription.Close()

	operation, err := writer.StartOperation(OperationInput{Name: "external"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := reader.Refresh(); err != nil {
		t.Fatal(err)
	}
	event := <-subscription.Events
	if event.OperationID != operation.ID || event.Type != EventOperationStarted {
		t.Fatalf("refreshed event = %#v", event)
	}
}

func TestJournalSerializesConcurrentWriters(t *testing.T) {
	journal, err := Open(filepath.Join(t.TempDir(), "events.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	const writers = 8
	const eventsPerWriter = 12
	var wait sync.WaitGroup
	for i := 0; i < writers; i++ {
		wait.Add(1)
		go func(index int) {
			defer wait.Done()
			for event := 0; event < eventsPerWriter; event++ {
				operation, startErr := journal.StartOperation(OperationInput{Name: "concurrent"})
				if startErr != nil {
					t.Errorf("writer %d start: %v", index, startErr)
					return
				}
				if _, progressErr := journal.Progress(operation.ID, "step", "", nil); progressErr != nil {
					t.Errorf("writer %d progress: %v", index, progressErr)
					return
				}
			}
		}(i)
	}
	wait.Wait()

	events, err := journal.Events(0)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != writers*eventsPerWriter*2 {
		t.Fatalf("event count = %d, want %d", len(events), writers*eventsPerWriter*2)
	}
	for index, event := range events {
		want := uint64(index + 1)
		if event.Sequence != want {
			t.Fatalf("event %d sequence = %d, want %d", index, event.Sequence, want)
		}
	}
}
