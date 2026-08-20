package fsutil

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

func EnsureDir(path string, mode fs.FileMode) error {
	path = filepath.Clean(path)
	var missing []string
	current := path
	for {
		info, err := os.Stat(current)
		if err == nil {
			if !info.IsDir() {
				return fmt.Errorf("%s exists but is not a directory", current)
			}
			break
		}
		if !os.IsNotExist(err) {
			return fmt.Errorf("stat directory %s: %w", current, err)
		}
		missing = append(missing, current)
		parent := filepath.Dir(current)
		if parent == current {
			return fmt.Errorf("could not find existing parent for %s", path)
		}
		current = parent
	}
	for i := len(missing) - 1; i >= 0; i-- {
		dir := missing[i]
		if err := os.Mkdir(dir, mode); err != nil && !os.IsExist(err) {
			return fmt.Errorf("create directory %s: %w", dir, err)
		}
		info, err := os.Stat(dir)
		if err != nil {
			return fmt.Errorf("stat created directory %s: %w", dir, err)
		}
		if !info.IsDir() {
			return fmt.Errorf("%s is not a directory", dir)
		}
		if err := SyncDir(filepath.Dir(dir)); err != nil {
			return fmt.Errorf("sync parent of %s: %w", dir, err)
		}
	}
	return nil
}
