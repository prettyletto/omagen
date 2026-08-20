package fsutil

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestAtomicWriteFileReplacesExistingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "value.json")
	if err := os.WriteFile(path, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := AtomicWriteFile(path, []byte("new"), 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "new" {
		t.Fatalf("got %q", got)
	}
}

func TestRenameAndSyncNoReplaceRefusesExistingDestination(t *testing.T) {
	root := t.TempDir()
	source, destination := filepath.Join(root, "source"), filepath.Join(root, "destination")
	if err := os.Mkdir(source, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(destination, 0o755); err != nil {
		t.Fatal(err)
	}
	renamed, err := RenameAndSyncNoReplace(source, destination)
	if renamed || !errors.Is(err, fs.ErrExist) {
		t.Fatalf("renamed=%v err=%v", renamed, err)
	}
	if _, err := os.Stat(source); err != nil {
		t.Fatal(err)
	}
}

func TestLinkOrCopyAtomicCanReplaceDestination(t *testing.T) {
	root := t.TempDir()
	source, destination := filepath.Join(root, "source"), filepath.Join(root, "destination")
	if err := os.WriteFile(source, []byte("wallpaper"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(destination, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := LinkOrCopyAtomic(source, destination, 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(destination)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "wallpaper" {
		t.Fatalf("got %q", got)
	}
}

func TestCleanupStaleTempDirsKeepsFreshWork(t *testing.T) {
	root := t.TempDir()
	now := time.Date(2026, 8, 20, 12, 0, 0, 0, time.UTC)
	old, fresh, committed := filepath.Join(root, ".old.tmp"), filepath.Join(root, ".fresh.tmp"), filepath.Join(root, "generation-1")
	for _, path := range []string{old, fresh, committed} {
		if err := os.Mkdir(path, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	oldTime, freshTime := now.Add(-48*time.Hour), now.Add(-10*time.Minute)
	if err := os.Chtimes(old, oldTime, oldTime); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(fresh, freshTime, freshTime); err != nil {
		t.Fatal(err)
	}
	if err := CleanupStaleTempDirs(root, 24*time.Hour, now); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Fatalf("old temp remains: %v", err)
	}
	if _, err := os.Stat(fresh); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(committed); err != nil {
		t.Fatal(err)
	}
}
