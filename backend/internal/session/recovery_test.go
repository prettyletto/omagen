package session

import (
	"errors"
	"os"
	"sync"
	"testing"
)

func TestActiveSessionLifecycleAndRecovery(t *testing.T) {
	store := testStore(t)
	fake := &fakeOmarchy{theme: "source", background: BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	service := NewService(store, fake)

	begin, err := service.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Begin(); !errors.Is(err, ErrActiveSession) {
		t.Fatalf("second begin error = %v", err)
	}
	status, err := service.Status()
	if err != nil {
		t.Fatal(err)
	}
	if !status.Active || !status.Recoverable || status.SessionID != begin.SessionID {
		t.Fatalf("status = %#v", status)
	}

	fake.theme = "changed"
	fake.background = BackgroundRef{Kind: "external", Path: "/tmp/other"}
	recovered, err := service.RecoverActive()
	if err != nil {
		t.Fatal(err)
	}
	if !recovered.Recovered || recovered.SessionID != begin.SessionID {
		t.Fatalf("recover = %#v", recovered)
	}
	status, err = service.Status()
	if err != nil {
		t.Fatal(err)
	}
	if status.Active {
		t.Fatalf("session remained active: %#v", status)
	}
}

func TestCorruptActiveMarkerIsNeverSilentlyIgnored(t *testing.T) {
	store := testStore(t)
	if err := os.MkdirAll(store.StateRoot(), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(store.ActivePath(), []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.LoadActive(); !errors.Is(err, ErrActiveSessionCorrupt) {
		t.Fatalf("error = %v", err)
	}
	if _, err := NewService(store, &fakeOmarchy{}).Status(); !errors.Is(err, ErrActiveSessionCorrupt) {
		t.Fatalf("status error = %v", err)
	}
}

func TestFailedRecoveryPreservesActiveState(t *testing.T) {
	store := testStore(t)
	fake := &fakeOmarchy{theme: "source", background: BackgroundRef{Kind: "external", Path: "/tmp/bg"}, restoreBackgroundErr: errors.New("background unavailable")}
	service := NewService(store, fake)
	begin, err := service.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.RecoverActive(); err == nil {
		t.Fatal("expected recovery failure")
	}
	if _, _, err := store.LoadActive(); err != nil {
		t.Fatalf("active marker was removed: %v", err)
	}
	if _, err := store.Load(begin.SessionID); err != nil {
		t.Fatalf("rollback record was removed: %v", err)
	}
}

func TestConcurrentBeginCreatesOneActiveSession(t *testing.T) {
	store := testStore(t)
	fake := &fakeOmarchy{theme: "source", background: BackgroundRef{Kind: "external", Path: "/tmp/bg"}}
	service := NewService(store, fake)
	var wg sync.WaitGroup
	results := make(chan error, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, err := service.Begin(); results <- err }()
	}
	wg.Wait()
	close(results)
	var successes, activeErrors int
	for err := range results {
		if err == nil {
			successes++
		}
		if errors.Is(err, ErrActiveSession) {
			activeErrors++
		}
	}
	if successes != 1 || activeErrors != 1 {
		t.Fatalf("successes=%d activeErrors=%d", successes, activeErrors)
	}
}
