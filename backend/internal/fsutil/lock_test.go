package fsutil

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAcquireFileLockLeavesStableLockFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "session.lock")
	lock, err := AcquireFileLock(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := lock.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("lock file was removed: %v", err)
	}
}
