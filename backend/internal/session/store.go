package session

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Store struct {
	root string
}

func NewStore() (*Store, error) {
	cacheRoot, err := os.UserCacheDir()
	if err != nil {
		return nil, err
	}

	return &Store{root: filepath.Join(cacheRoot, "omagen", "sessions")}, nil
}

func (s *Store) Save(record Record) error {
	dir := s.SessionDir(record.SessionID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	tmpPath := filepath.Join(dir, "session.json.tmp")
	finalPath := filepath.Join(dir, "session.json")
	f, err := os.OpenFile(tmpPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}

	enc := json.NewEncoder(f)
	enc.SetIndent("", "  ")
	if err := enc.Encode(record); err != nil {
		_ = f.Close()
		_ = os.Remove(tmpPath)
		return err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}

	return os.Rename(tmpPath, finalPath)
}

func (s *Store) Load(sessionID string) (Record, error) {
	if !validSessionID(sessionID) {
		return Record{}, fmt.Errorf("invalid session id")
	}

	data, err := os.ReadFile(filepath.Join(s.SessionDir(sessionID), "session.json"))
	if err != nil {
		return Record{}, err
	}

	var record Record
	if err := json.Unmarshal(data, &record); err != nil {
		return Record{}, err
	}
	if record.SessionID != sessionID {
		return Record{}, fmt.Errorf("session id mismatch")
	}
	if record.OriginalTheme == "" {
		return Record{}, fmt.Errorf("session has no original theme")
	}
	if record.OriginalBackground.Kind == "" {
		return Record{}, fmt.Errorf("session has no original background kind")
	}
	if record.OriginalBackground.Path == "" {
		return Record{}, fmt.Errorf("session has no original background path")
	}

	return record, nil
}

func (s *Store) Delete(sessionID string) error {
	if !validSessionID(sessionID) {
		return fmt.Errorf("invalid session id")
	}
	return os.RemoveAll(s.SessionDir(sessionID))
}

func (s *Store) SessionDir(sessionID string) string {
	return filepath.Join(s.root, sessionID)
}

func validSessionID(sessionID string) bool {
	return sessionID != "" && filepath.Base(sessionID) == sessionID
}
