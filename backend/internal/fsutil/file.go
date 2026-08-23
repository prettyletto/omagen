package fsutil

import (
	"errors"
	"fmt"
	"io"
	"os"
	"syscall"
)

const (
	// MaxFileBytes bounds copied user-selected files. It is large enough for
	// the supported 40-megapixel image formats while preventing an unbounded
	// source from consuming plugin state.
	MaxFileBytes      int64 = 256 << 20
	MaxStateFileBytes int64 = 1 << 20
)

var ErrFileTooLarge = errors.New("file exceeds size limit")

func OpenRegularFile(path string, maxBytes int64) (*os.File, error) {
	if maxBytes <= 0 {
		return nil, fmt.Errorf("invalid file size limit %d", maxBytes)
	}

	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("path %s is not a regular file", path)
	}
	if info.Size() > maxBytes {
		return nil, fmt.Errorf("%w: %s is %d bytes, maximum %d", ErrFileTooLarge, path, info.Size(), maxBytes)
	}

	// O_NONBLOCK makes a concurrent replacement with a FIFO fail the regular
	// file check instead of allowing the backend to block in os.Open.
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, err
	}
	openedInfo, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return nil, err
	}
	if !openedInfo.Mode().IsRegular() {
		_ = file.Close()
		return nil, fmt.Errorf("path %s is not a regular file", path)
	}
	if openedInfo.Size() > maxBytes {
		_ = file.Close()
		return nil, fmt.Errorf("%w: %s is %d bytes, maximum %d", ErrFileTooLarge, path, openedInfo.Size(), maxBytes)
	}
	return file, nil
}

func ReadFileLimited(path string, maxBytes int64) ([]byte, error) {
	file, err := OpenRegularFile(path, maxBytes)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	data, err := io.ReadAll(io.LimitReader(file, maxBytes+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > maxBytes {
		return nil, fmt.Errorf("%w: %s grew beyond %d bytes", ErrFileTooLarge, path, maxBytes)
	}
	return data, nil
}
