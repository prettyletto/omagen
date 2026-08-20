package fsutil

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func CleanupStaleTempDirs(root string, olderThan time.Duration, now time.Time) error {
	if olderThan <= 0 {
		return fmt.Errorf("stale temp age must be positive")
	}
	entries, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("read temp root: %w", err)
	}
	cutoff := now.Add(-olderThan)
	var cleanupErrors []error
	removed := false
	for _, entry := range entries {
		if !entry.IsDir() || !strings.HasPrefix(entry.Name(), ".") || !strings.HasSuffix(entry.Name(), ".tmp") {
			continue
		}
		info, err := entry.Info()
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			cleanupErrors = append(cleanupErrors, fmt.Errorf("inspect stale temp %s: %w", entry.Name(), err))
			continue
		}
		if info.ModTime().After(cutoff) {
			continue
		}
		path := filepath.Join(root, entry.Name())
		if err := os.RemoveAll(path); err != nil {
			cleanupErrors = append(cleanupErrors, fmt.Errorf("remove stale temp %s: %w", path, err))
			continue
		}
		removed = true
	}
	if removed {
		if err := SyncDir(root); err != nil {
			cleanupErrors = append(cleanupErrors, fmt.Errorf("sync temp root after cleanup: %w", err))
		}
	}
	return errors.Join(cleanupErrors...)
}
