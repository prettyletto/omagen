package fsutil

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

func CopyFileAtomic(source, destination string, mode fs.FileMode) error {
	return CopyFileAtomicLimited(source, destination, mode, MaxFileBytes)
}

func CopyFileAtomicLimited(source, destination string, mode fs.FileMode, maxBytes int64) error {
	input, err := OpenRegularFile(source, maxBytes)
	if err != nil {
		return fmt.Errorf("open source %s: %w", source, err)
	}
	defer input.Close()
	return AtomicWrite(destination, mode, func(w io.Writer) error {
		written, err := io.Copy(w, io.LimitReader(input, maxBytes+1))
		if err != nil {
			return err
		}
		if written > maxBytes {
			return fmt.Errorf("%w: source %s exceeds %d bytes", ErrFileTooLarge, source, maxBytes)
		}
		return nil
	})
}

func LinkOrCopyAtomic(source, destination string, mode fs.FileMode) error {
	dir := filepath.Dir(destination)
	if err := EnsureDir(dir, 0o755); err != nil {
		return fmt.Errorf("prepare destination directory: %w", err)
	}
	reservation, err := os.CreateTemp(dir, "."+filepath.Base(destination)+".*.tmp")
	if err != nil {
		return fmt.Errorf("reserve temporary path: %w", err)
	}
	tmpPath := reservation.Name()
	if err := reservation.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("close temporary reservation: %w", err)
	}
	if err := os.Remove(tmpPath); err != nil {
		return fmt.Errorf("release temporary reservation: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = os.Remove(tmpPath)
		}
	}()
	if err := os.Link(source, tmpPath); err != nil {
		if copyErr := CopyFileAtomic(source, tmpPath, mode); copyErr != nil {
			return errors.Join(fmt.Errorf("hardlink source: %w", err), fmt.Errorf("copy fallback: %w", copyErr))
		}
	}
	if err := os.Rename(tmpPath, destination); err != nil {
		return fmt.Errorf("commit linked/copied file: %w", err)
	}
	committed = true
	if err := SyncDir(dir); err != nil {
		return fmt.Errorf("sync linked/copied file directory: %w", err)
	}
	return nil
}
