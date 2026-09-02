package fsutil

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"syscall"

	"golang.org/x/sys/unix"
)

func AtomicWriteFile(path string, data []byte, mode fs.FileMode) error {
	return AtomicWrite(path, mode, func(w io.Writer) error { _, err := w.Write(data); return err })
}
func AtomicWriteJSON(path string, value any, mode fs.FileMode) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal JSON: %w", err)
	}
	return AtomicWriteFile(path, append(data, '\n'), mode)
}

func AtomicWrite(path string, mode fs.FileMode, write func(io.Writer) error) error {
	dir := filepath.Dir(path)
	if err := EnsureDir(dir, 0o755); err != nil {
		return fmt.Errorf("prepare destination directory: %w", err)
	}
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".*.tmp")
	if err != nil {
		return fmt.Errorf("create temporary file: %w", err)
	}
	tmpPath, closed, committed := tmp.Name(), false, false
	defer func() {
		if !closed {
			_ = tmp.Close()
		}
		if !committed {
			_ = os.Remove(tmpPath)
		}
	}()
	if err := tmp.Chmod(mode); err != nil {
		return fmt.Errorf("set temporary file permissions: %w", err)
	}
	if err := write(tmp); err != nil {
		return fmt.Errorf("write temporary file: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		return fmt.Errorf("sync temporary file: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("close temporary file: %w", err)
	}
	closed = true
	if err := os.Rename(tmpPath, path); err != nil {
		return fmt.Errorf("commit temporary file: %w", err)
	}
	committed = true
	if err := SyncDir(dir); err != nil {
		return fmt.Errorf("sync directory after commit: %w", err)
	}
	return nil
}

func RenameAndSyncNoReplace(source, destination string) (bool, error) {
	// The existence check plus os.Rename is racy: a concurrent creator could
	// appear between the two calls and be overwritten. Linux's no-replace
	// rename is the commit primitive used by Apply, Preview, and Generation.
	err := unix.Renameat2(unix.AT_FDCWD, source, unix.AT_FDCWD, destination, unix.RENAME_NOREPLACE)
	if err != nil {
		if errors.Is(err, unix.EEXIST) {
			return false, fmt.Errorf("destination already exists: %w", fs.ErrExist)
		}
		return false, fmt.Errorf("rename %s to %s: %w", source, destination, err)
	}
	if err := SyncDir(filepath.Dir(destination)); err != nil {
		return true, fmt.Errorf("sync destination parent: %w", err)
	}
	if filepath.Dir(source) != filepath.Dir(destination) {
		if err := SyncDir(filepath.Dir(source)); err != nil {
			return true, fmt.Errorf("sync source parent: %w", err)
		}
	}
	return true, nil
}

func RemoveFileAndSync(path string) error {
	err := os.Remove(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("remove %s: %w", path, err)
	}
	if err := SyncDir(filepath.Dir(path)); err != nil {
		return fmt.Errorf("sync directory after removing %s: %w", path, err)
	}
	return nil
}
func RemoveAllAndSync(path string) error {
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return fmt.Errorf("inspect %s before removal: %w", path, err)
	}
	if err := os.RemoveAll(path); err != nil {
		return fmt.Errorf("remove %s: %w", path, err)
	}
	if err := SyncDir(filepath.Dir(path)); err != nil {
		return fmt.Errorf("sync parent after removing %s: %w", path, err)
	}
	return nil
}

func SyncDir(path string) error {
	dir, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open directory %s: %w", path, err)
	}
	syncErr, closeErr := dir.Sync(), dir.Close()
	if isUnsupportedDirectorySync(syncErr) {
		syncErr = nil
	}
	if syncErr != nil || closeErr != nil {
		return errors.Join(syncErr, closeErr)
	}
	return nil
}
func isUnsupportedDirectorySync(err error) bool {
	return errors.Is(err, syscall.EINVAL) || errors.Is(err, syscall.ENOTSUP) || errors.Is(err, syscall.EBADF)
}
