package session

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func (s *Store) StateRoot() string        { return filepath.Dir(s.root) }
func (s *Store) ActivePath() string       { return filepath.Join(s.StateRoot(), "active-session.json") }
func (s *Store) MutationLockPath() string { return filepath.Join(s.StateRoot(), "session.lock") }

func (s *Store) LoadActive() (ActiveRecord, bool, error) {
	data, err := fsutil.ReadFileLimited(s.ActivePath(), fsutil.MaxStateFileBytes)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return ActiveRecord{}, false, nil
		}
		return ActiveRecord{}, false, fmt.Errorf("read active session marker: %w", err)
	}
	var record ActiveRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return ActiveRecord{}, true, fmt.Errorf("%w: decode active session marker: %v", ErrActiveSessionCorrupt, err)
	}
	if err := validateActiveRecord(record); err != nil {
		return ActiveRecord{}, true, fmt.Errorf("%w: %v", ErrActiveSessionCorrupt, err)
	}
	return record, true, nil
}

func (s *Store) SaveActive(record ActiveRecord) error {
	if err := validateActiveRecord(record); err != nil {
		return err
	}
	if err := fsutil.AtomicWriteJSON(s.ActivePath(), record, 0o600); err != nil {
		return fmt.Errorf("persist active session: %w", err)
	}
	return nil
}

func (s *Store) ClearActive(expectedID string) error {
	if expectedID != "" {
		record, exists, err := s.LoadActive()
		if err != nil {
			return err
		}
		if !exists {
			return nil
		}
		if record.SessionID != expectedID {
			return fmt.Errorf("%w: active=%s requested=%s", ErrSessionNotActive, record.SessionID, expectedID)
		}
	}
	return fsutil.RemoveFileAndSync(s.ActivePath())
}

func (s *Store) ActiveSessionExists() (bool, error) {
	_, exists, err := s.LoadActive()
	return exists, err
}

func validateActiveRecord(record ActiveRecord) error {
	if !validSessionID(record.SessionID) {
		return fmt.Errorf("active session has invalid id")
	}
	if record.CreatedAt.IsZero() || record.CreatedAt.After(time.Now().UTC().Add(5*time.Minute)) {
		return fmt.Errorf("active session has invalid creation time")
	}
	return nil
}
