package session

import (
	"errors"
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func withMutationLock[T any](store *Store, fn func() (T, error)) (result T, err error) {
	lock, err := fsutil.AcquireFileLock(store.MutationLockPath())
	if err != nil {
		return result, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer func() {
		if releaseErr := lock.Close(); releaseErr != nil {
			err = errors.Join(err, fmt.Errorf("release session mutation lock: %w", releaseErr))
		}
	}()
	return fn()
}

func withMutationLockError(store *Store, fn func() error) error {
	_, err := withMutationLock(store, func() (struct{}, error) { return struct{}{}, fn() })
	return err
}
