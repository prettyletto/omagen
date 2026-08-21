package cleanup

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/testenv"
)

func cleanupFixture(t *testing.T) (*session.Store, string) {
	t.Helper()
	testenv.Isolate(t)
	store, err := session.NewStore()
	if err != nil {
		t.Fatal(err)
	}
	themes := filepath.Join(t.TempDir(), "themes")
	if err := os.MkdirAll(themes, 0o755); err != nil {
		t.Fatal(err)
	}
	return store, themes
}

func cleanupRecord(id string) session.Record {
	return session.Record{SessionID: id, OriginalTheme: "old", OriginalBackground: session.BackgroundRef{Kind: "external", Path: "/tmp/bg.png"}, CreatedAt: time.Now().UTC()}
}

func TestCleanupNeverTouchesActiveSession(t *testing.T) {
	store, themes := cleanupFixture(t)
	record := cleanupRecord("active-session")
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	if err := store.SaveActive(session.ActiveRecord{SessionID: record.SessionID, CreatedAt: record.CreatedAt}); err != nil {
		t.Fatal(err)
	}
	root := store.SessionDir(record.SessionID)
	if err := os.MkdirAll(filepath.Join(root, "demo-scene", ".tmp"), 0o755); err != nil {
		t.Fatal(err)
	}
	alias := filepath.Join(themes, previewPrefix+record.SessionID+"-source")
	if err := os.Symlink(filepath.Join(root, "demo-scene"), alias); err != nil {
		t.Fatal(err)
	}
	result, err := NewService(store, themes).Run()
	if err != nil {
		t.Fatal(err)
	}
	if result.ActiveSession != record.SessionID || result.SessionDirsRemoved != 0 || result.PreviewAliasesRemoved != 0 {
		t.Fatalf("active cleanup result=%#v", result)
	}
	if _, err := os.Stat(root); err != nil {
		t.Fatalf("active session removed: %v", err)
	}
	if _, err := os.Lstat(alias); err != nil {
		t.Fatalf("active alias removed: %v", err)
	}
}

func TestCleanupRemovesInactiveOwnedResourcesAndIsIdempotent(t *testing.T) {
	store, themes := cleanupFixture(t)
	record := cleanupRecord("stale-session")
	if err := store.Save(record); err != nil {
		t.Fatal(err)
	}
	root := store.SessionDir(record.SessionID)
	if err := os.MkdirAll(filepath.Join(root, "demo-scene", ".generation.tmp"), 0o755); err != nil {
		t.Fatal(err)
	}
	alias := filepath.Join(themes, previewPrefix+record.SessionID+"-source")
	if err := os.Symlink(filepath.Join(root, "demo-scene"), alias); err != nil {
		t.Fatal(err)
	}
	permanentLike := filepath.Join(themes, previewPrefix+"user-owned")
	if err := os.MkdirAll(permanentLike, 0o755); err != nil {
		t.Fatal(err)
	}
	temp := filepath.Join(themes, ".omagen-apply-test.tmp")
	if err := os.MkdirAll(temp, 0o755); err != nil {
		t.Fatal(err)
	}
	service := NewService(store, themes)
	result, err := service.Run()
	if err != nil {
		t.Fatal(err)
	}
	if result.PreviewAliasesRemoved != 1 || result.SessionDirsRemoved != 1 || result.TempDirsRemoved < 1 {
		t.Fatalf("stale cleanup result=%#v", result)
	}
	if _, err := os.Stat(root); !os.IsNotExist(err) {
		t.Fatalf("stale session remains: %v", err)
	}
	if _, err := os.Lstat(alias); !os.IsNotExist(err) {
		t.Fatalf("stale alias remains: %v", err)
	}
	if _, err := os.Stat(permanentLike); err != nil {
		t.Fatalf("ordinary user directory removed: %v", err)
	}
	second, err := service.Run()
	if err != nil {
		t.Fatal(err)
	}
	if second.PreviewAliasesRemoved != 0 || second.TempDirsRemoved != 0 || second.DemoDirsRemoved != 0 || second.SessionDirsRemoved != 0 {
		t.Fatalf("second cleanup was not idempotent: %#v", second)
	}
}

func TestCleanupLeavesUnknownSessionDirectory(t *testing.T) {
	store, themes := cleanupFixture(t)
	unknown := filepath.Join(store.Root(), "not-a-session")
	if err := os.MkdirAll(unknown, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := NewService(store, themes).Run(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(unknown); err != nil {
		t.Fatalf("unknown directory was removed: %v", err)
	}
}
