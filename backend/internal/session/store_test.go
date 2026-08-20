package session

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func testStore(t *testing.T) *Store {
	t.Helper()
	return &Store{root: t.TempDir()}
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
	for _, id := range []string{"", "../escape", "a/b"} {
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

func writeTestFile(path, contents string) error {
	return os.WriteFile(path, []byte(contents), 0o644)
}
