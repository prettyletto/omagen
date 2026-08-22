package session

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	return &Store{root: t.TempDir()}
}

func TestStoreRejectsOversizedStateFiles(t *testing.T) {
	s := testStore(t)
	if err := os.MkdirAll(s.StateRoot(), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(s.ActivePath(), []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(s.ActivePath(), fsutil.MaxStateFileBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.LoadActive(); !errors.Is(err, fsutil.ErrFileTooLarge) {
		t.Fatalf("LoadActive() error = %v, want ErrFileTooLarge", err)
	}

	if err := os.MkdirAll(s.SessionDir("oversized"), 0o755); err != nil {
		t.Fatal(err)
	}
	sessionPath := filepath.Join(s.SessionDir("oversized"), "session.json")
	if err := os.WriteFile(sessionPath, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(sessionPath, fsutil.MaxStateFileBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Load("oversized"); !errors.Is(err, fsutil.ErrFileTooLarge) {
		t.Fatalf("Load() error = %v, want ErrFileTooLarge", err)
	}
}

func testRecord(id string) Record {
	return Record{
		SessionID:          id,
		OriginalTheme:      "kanagawa",
		OriginalBackground: BackgroundRef{Kind: "external", Path: "/tmp/background.png"},
		CreatedAt:          time.Unix(1, 0).UTC(),
	}
}

func TestStoreSaveLoadDelete(t *testing.T) {
	s := testStore(t)
	record := testRecord("session-1")
	if err := s.Save(record); err != nil {
		t.Fatal(err)
	}
	got, err := s.Load(record.SessionID)
	if err != nil {
		t.Fatal(err)
	}
	if got.SessionID != record.SessionID || got.OriginalTheme != record.OriginalTheme || got.OriginalBackground != record.OriginalBackground {
		t.Fatalf("loaded record differs: %#v", got)
	}
	if err := s.Delete(record.SessionID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Load(record.SessionID); err == nil {
		t.Fatal("expected deleted session to be unavailable")
	}
}

func TestStoreRejectsInvalidAndMalformedRecords(t *testing.T) {
	s := testStore(t)
	for _, id := range []string{"", ".", "..", "../escape", "a/b"} {
		if _, err := s.Load(id); err == nil {
			t.Errorf("Load(%q) accepted invalid id", id)
		}
		if err := s.Delete(id); err == nil {
			t.Errorf("Delete(%q) accepted invalid id", id)
		}
	}
	if err := s.Save(testRecord("valid")); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(s.SessionDir("valid"), "session.json")
	if err := writeTestFile(path, "{"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Load("valid"); err == nil {
		t.Fatal("expected malformed JSON error")
	}
	for _, record := range []Record{
		{SessionID: "valid", OriginalBackground: BackgroundRef{Kind: "x", Path: "x"}},
		{SessionID: "valid", OriginalTheme: "x", OriginalBackground: BackgroundRef{Path: "x"}},
		{SessionID: "valid", OriginalTheme: "x", OriginalBackground: BackgroundRef{Kind: "x"}},
	} {
		if err := s.Save(record); err == nil {
			t.Errorf("accepted invalid record: %#v", record)
		}
	}
}

func TestStoreRejectsUnknownAndIncompleteApplyTransactions(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*Record)
	}{
		{name: "unknown phase", mutate: func(record *Record) { record.ApplyPhase = ApplyPhase("rollback") }},
		{name: "prepared without metadata", mutate: func(record *Record) { record.ApplyPhase = ApplyPhasePrepared }},
		{name: "committed with bad variant", mutate: func(record *Record) {
			record.ApplyPhase = ApplyPhaseCommitted
			record.AppliedTheme = "theme"
			record.AppliedGeneration = "generation-1"
			record.AppliedVariant = "unknown"
			record.AppliedDisplayName = "Theme"
		}},
		{name: "metadata without phase", mutate: func(record *Record) { record.AppliedTheme = "theme" }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			record := testRecord("transaction")
			tc.mutate(&record)
			if err := testStore(t).Save(record); err == nil {
				t.Fatal("accepted invalid apply transaction")
			}
		})
	}

	record := testRecord("prepared")
	record.ApplyPhase = ApplyPhasePrepared
	record.AppliedTheme = "theme"
	record.AppliedGeneration = "generation-1"
	record.AppliedVariant = "source"
	record.AppliedDisplayName = "Theme"
	if err := testStore(t).Save(record); err != nil {
		t.Fatalf("rejected complete prepared transaction: %v", err)
	}
}

func writeTestFile(path, contents string) error {
	return os.WriteFile(path, []byte(contents), 0o644)
}
