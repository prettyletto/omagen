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
	if err := fsutil.AtomicWriteJSON(filepath.Join(s.root, record.SessionID, "session.json"), record, 0o600); err != nil {
		return fmt.Errorf("persist session record: %w", err)
	}
	return nil
}

func (s *Store) Load(sessionID string) (Record, error) {
	if !validSessionID(sessionID) {
		return Record{}, fmt.Errorf("invalid session id")
	}

	data, err := fsutil.ReadFileLimited(filepath.Join(s.SessionDir(sessionID), "session.json"), fsutil.MaxStateFileBytes)
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
	// Preview/apply history was removed. Clean any protocol journal left by an
	// older engine when its owning session is cleared.
	if err := fsutil.RemoveAllAndSync(filepath.Join(s.StateRoot(), "protocol", sessionID)); err != nil {
		errs = append(errs, err)
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

func (s *Store) Root() string { return s.root }

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
	if record.Workflow == "" {
		record.Workflow = "generate"
	}
	if record.Workflow != "generate" && record.Workflow != "theme-edit" {
		return fmt.Errorf("session has unknown workflow %q", record.Workflow)
	}
	if record.Workflow == "theme-edit" {
		if record.ThemeEdit == nil || record.ThemeEdit.SourceID == "" || record.ThemeEdit.SourceName == "" || record.ThemeEdit.SourcePath == "" || record.ThemeEdit.SourceKind == "" {
			return fmt.Errorf("theme-edit session has incomplete source metadata")
		}
	} else if record.ThemeEdit != nil {
		return fmt.Errorf("generated session has theme-edit metadata")
	}
	switch record.ApplyPhase {
	case ApplyPhaseNone:
		if record.AppliedTheme != "" || record.AppliedGeneration != "" || record.AppliedVariant != "" || record.AppliedDisplayName != "" || record.AppliedBackup != "" {
			return fmt.Errorf("session has apply metadata without a transaction phase")
		}
	case ApplyPhasePrepared, ApplyPhaseCommitted:
		if !validSessionComponent(record.AppliedTheme) {
			return fmt.Errorf("session has invalid applied theme")
		}
		if !validSessionComponent(record.AppliedGeneration) {
			return fmt.Errorf("session has invalid applied generation")
		}
		if !validApplyVariant(record.AppliedVariant) {
			return fmt.Errorf("session has invalid applied variant")
		}
		if record.AppliedDisplayName == "" {
			return fmt.Errorf("session has no applied display name")
		}
		if record.AppliedBackup != "" && record.AppliedBackup != "replacement-backup" {
			return fmt.Errorf("session has invalid applied backup")
		}
	default:
		return fmt.Errorf("session has unknown apply phase %q", record.ApplyPhase)
	}
	return nil
}

func validSessionComponent(value string) bool {
	if value == "." || value == ".." || !validSessionID(value) {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_' || r == '.') {
			return false
		}
	}
	return true
}

func validApplyVariant(value string) bool {
	switch value {
	case "source", "calm", "mute", "deep", "vibrant", "balanced":
		return true
	default:
		return false
	}
}

func validSessionID(sessionID string) bool {
	return sessionID != "" && sessionID != "." && sessionID != ".." && filepath.Base(sessionID) == sessionID
}
