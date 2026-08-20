package session

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

type Store struct {
	root       string
	legacyRoot string
}

func NewStore() (*Store, error) {
	stateRoot, err := fsutil.UserStateDir("omagen")
	if err != nil {
		return nil, err
	}
	legacyRoot := ""
	if cacheRoot, cacheErr := os.UserCacheDir(); cacheErr == nil {
		legacyRoot = filepath.Join(cacheRoot, "omagen", "sessions")
	}
	return &Store{root: filepath.Join(stateRoot, "sessions"), legacyRoot: legacyRoot}, nil
}

func (s *Store) Save(record Record) error {
	if err := validateRecord(record, record.SessionID); err != nil {
		return err
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(s.root, record.SessionID, "session.json"), record, 0o644); err != nil {
		return fmt.Errorf("persist session record: %w", err)
	}
	return nil
}

func (s *Store) Load(sessionID string) (Record, error) {
	if !validSessionID(sessionID) {
		return Record{}, fmt.Errorf("invalid session id")
	}

	data, err := os.ReadFile(filepath.Join(s.SessionDir(sessionID), "session.json"))
	if err != nil {
		return Record{}, fmt.Errorf("read session record: %w", err)
	}

	var record Record
	if err := json.Unmarshal(data, &record); err != nil {
		return Record{}, fmt.Errorf("decode session record: %w", err)
	}
	if err := validateRecord(record, sessionID); err != nil {
		return Record{}, err
	}

	return record, nil
}

func (s *Store) Delete(sessionID string) error {
	if !validSessionID(sessionID) {
		return fmt.Errorf("invalid session id")
	}
	var errs []error
	if err := fsutil.RemoveAllAndSync(s.primarySessionDir(sessionID)); err != nil {
		errs = append(errs, err)
	}
	if s.legacyRoot != "" {
		if err := fsutil.RemoveAllAndSync(filepath.Join(s.legacyRoot, sessionID)); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (s *Store) SessionDir(sessionID string) string {
	primary := s.primarySessionDir(sessionID)
	if _, err := os.Stat(primary); err == nil {
		return primary
	}
	if s.legacyRoot != "" && validSessionID(sessionID) {
		legacy := filepath.Join(s.legacyRoot, sessionID)
		if _, err := os.Stat(legacy); err == nil {
			return legacy
		}
	}
	return primary
}

func (s *Store) primarySessionDir(sessionID string) string { return filepath.Join(s.root, sessionID) }

func validateRecord(record Record, expectedID string) error {
	if !validSessionID(record.SessionID) {
		return fmt.Errorf("session has invalid id")
	}
	if record.SessionID != expectedID {
		return fmt.Errorf("session id mismatch")
	}
	if record.OriginalTheme == "" {
		return fmt.Errorf("session has no original theme")
	}
	if record.OriginalBackground.Kind == "" {
		return fmt.Errorf("session has no original background kind")
	}
	if record.OriginalBackground.Path == "" {
		return fmt.Errorf("session has no original background path")
	}
	return nil
}

func validSessionID(sessionID string) bool {
	return sessionID != "" && filepath.Base(sessionID) == sessionID
}
