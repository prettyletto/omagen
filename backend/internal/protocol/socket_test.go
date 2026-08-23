package protocol

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
	"time"
)

func TestSocketServerStreamsSnapshotAndLiveEvents(t *testing.T) {
	path := filepath.Join(t.TempDir(), "events.jsonl")
	journal, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	socketPath := filepath.Join(t.TempDir(), "protocol.sock")
	server := NewServer(journal, socketPath, 5*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	serveErrors := make(chan error, 1)
	go func() { serveErrors <- server.Serve(ctx) }()

	waitForSocket(t, socketPath, serveErrors)
	connection, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close()
	if _, err := connection.Write([]byte(`{"command":"subscribe","after":0,"buffer":8}` + "\n")); err != nil {
		t.Fatal(err)
	}

	decoder := json.NewDecoder(bufio.NewReader(connection))
	var snapshot WireMessage
	if err := decoder.Decode(&snapshot); err != nil {
		t.Fatal(err)
	}
	if snapshot.Type != WireSnapshot || snapshot.Snapshot == nil {
		t.Fatalf("snapshot response = %#v", snapshot)
	}

	operation, err := journal.StartOperation(OperationInput{Name: "socketed"})
	if err != nil {
		t.Fatal(err)
	}
	var event WireMessage
	if err := decoder.Decode(&event); err != nil {
		t.Fatal(err)
	}
	if event.Type != WireEvent || event.Event == nil || event.Event.OperationID != operation.ID {
		t.Fatalf("event response = %#v", event)
	}
}

func TestSocketServerNavigatesCheckpointCursor(t *testing.T) {
	path := filepath.Join(t.TempDir(), "events.jsonl")
	journal, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	operation, err := journal.StartOperation(OperationInput{Name: "navigation"})
	if err != nil {
		t.Fatal(err)
	}
	_, err = journal.CreateCheckpoint(CheckpointInput{OperationID: operation.ID, Name: "first", State: json.RawMessage(`{"theme":"first"}`)})
	if err != nil {
		t.Fatal(err)
	}
	checkpoint, err := journal.CreateCheckpoint(CheckpointInput{OperationID: operation.ID, Name: "candidate", State: json.RawMessage(`{"theme":"candidate"}`)})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Back(); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Forward(checkpoint.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Back(); err != nil {
		t.Fatal(err)
	}

	socketPath := filepath.Join(t.TempDir(), "protocol.sock")
	server := NewServer(journal, socketPath, 5*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	serveErrors := make(chan error, 1)
	go func() { serveErrors <- server.Serve(ctx) }()
	waitForSocket(t, socketPath, serveErrors)

	connection, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close()
	if _, err := connection.Write([]byte(`{"command":"forward","checkpoint_id":"` + checkpoint.ID + `"}` + "\n")); err != nil {
		t.Fatal(err)
	}
	var response WireMessage
	if err := json.NewDecoder(bufio.NewReader(connection)).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Type != WireNavigation || response.Navigation == nil || response.Navigation.ToCheckpointID != checkpoint.ID {
		t.Fatalf("navigation response = %#v", response)
	}
}

func waitForSocket(t *testing.T, path string, serveErrors <-chan error) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case err := <-serveErrors:
			t.Fatalf("protocol server stopped: %v", err)
		default:
		}
		if _, err := net.DialTimeout("unix", path, 20*time.Millisecond); err == nil {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("socket %s did not become available", path)
}
