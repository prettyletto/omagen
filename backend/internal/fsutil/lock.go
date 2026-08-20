package fsutil

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
)

// FileLock is a process-wide advisory lock backed by a durable lock file.
// The file is intentionally never removed: its inode is the stable lock
// identity used by other processes.
type FileLock struct {
	file *os.File
}

func AcquireFileLock(path string) (*FileLock, error) {
	if err := EnsureDir(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("prepare lock directory: %w", err)
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX); err != nil {
		_ = file.Close()
		return nil, fmt.Errorf("acquire lock: %w", err)
	}
	return &FileLock{file: file}, nil
}

func (l *FileLock) Close() error {
	if l == nil || l.file == nil {
		return nil
	}
	unlockErr := syscall.Flock(int(l.file.Fd()), syscall.LOCK_UN)
	closeErr := l.file.Close()
	l.file = nil
	return errors.Join(unlockErr, closeErr)
}
