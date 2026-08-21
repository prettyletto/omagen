package session

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"reflect"
	"time"
)

type Omarchy interface {
	CurrentTheme() (string, error)
	CurrentBackground() (BackgroundRef, error)
	RestoreThemeFast(theme, sessionDir string) error
	RestoreBackground(background BackgroundRef) error
}

type Service struct {
	store   *Store
	omarchy Omarchy
}

func (s *Service) Store() *Store { return s.store }

func NewService(store *Store, omarchy Omarchy) *Service {
	return &Service{store: store, omarchy: omarchy}
}

func (s *Service) Begin(styles ...any) (BeginResult, error) {
	shellStyle := DefaultShellStyle()
	desktopStyle := DefaultDesktopStyle()
	barStyle := DefaultBarStyle()
	extraConfigs := len(styles) > 0
	for _, style := range styles {
		switch value := style.(type) {
		case ShellStyle:
			shellStyle = value
		case DesktopStyle:
			desktopStyle = value
		case BarStyle:
			barStyle = value
		default:
			return BeginResult{}, fmt.Errorf("invalid style configuration")
		}
	}
	if extraConfigs {
		if !shellStyle.Valid() {
			return BeginResult{}, fmt.Errorf("invalid shell style")
		}
		if !desktopStyle.Valid() {
			return BeginResult{}, fmt.Errorf("invalid desktop style")
		}
		if !barStyle.Valid() {
			return BeginResult{}, fmt.Errorf("invalid bar style")
		}
	}
	return withMutationLock(s.store, func() (BeginResult, error) {
		exists, err := s.store.ActiveSessionExists()
		if err != nil {
			return BeginResult{}, fmt.Errorf("check active session: %w", err)
		}
		if exists {
			active, _, loadErr := s.store.LoadActive()
			if loadErr != nil {
				return BeginResult{}, loadErr
			}
			if _, loadErr := s.store.Load(active.SessionID); loadErr != nil {
				return BeginResult{}, fmt.Errorf("%w: rollback record: %v", ErrActiveSessionCorrupt, loadErr)
			}
			return BeginResult{}, ErrActiveSession
		}

		theme, err := s.omarchy.CurrentTheme()
		if err != nil {
			return BeginResult{}, fmt.Errorf("read current theme: %w", err)
		}
		background, err := s.omarchy.CurrentBackground()
		if err != nil {
			return BeginResult{}, fmt.Errorf("read current background: %w", err)
		}
		sessionID, err := newSessionID()
		if err != nil {
			return BeginResult{}, fmt.Errorf("create session id: %w", err)
		}
		now := time.Now().UTC()
		record := Record{SessionID: sessionID, OriginalTheme: theme, OriginalBackground: background, ExtraConfigs: extraConfigs, ShellStyle: shellStyle, DesktopStyle: desktopStyle, BarStyle: barStyle, CreatedAt: now}
		if err := s.store.Save(record); err != nil {
			return BeginResult{}, fmt.Errorf("persist session: %w", err)
		}
		if err := s.store.SaveActive(ActiveRecord{SessionID: sessionID, CreatedAt: now}); err != nil {
			_ = s.store.Delete(sessionID)
			return BeginResult{}, fmt.Errorf("persist active session: %w", err)
		}
		return BeginResult{SessionID: sessionID, OriginalTheme: theme, OriginalBackground: background, ShellStyle: shellStyle, DesktopStyle: desktopStyle, BarStyle: barStyle, ExtraConfigs: extraConfigs}, nil
	})
}

func (s *Service) Status() (StatusResult, error) {
	return withMutationLock(s.store, func() (StatusResult, error) {
		exists, err := s.store.ActiveSessionExists()
		if err != nil {
			return StatusResult{}, fmt.Errorf("check active session: %w", err)
		}
		if !exists {
			return StatusResult{Active: false, Recoverable: false}, nil
		}
		active, _, err := s.store.LoadActive()
		if err != nil {
			return StatusResult{}, err
		}
		record, err := s.store.Load(active.SessionID)
		if err != nil {
			return StatusResult{}, fmt.Errorf("%w: rollback record: %v", ErrActiveSessionCorrupt, err)
		}
		background := record.OriginalBackground
		return StatusResult{Active: true, SessionID: active.SessionID, Recoverable: true, OriginalTheme: record.OriginalTheme, OriginalBackground: &background, CreatedAt: active.CreatedAt}, nil
	})
}

func (s *Service) Cancel(sessionID string) error {
	return withMutationLockError(s.store, func() error {
		if !validSessionID(sessionID) {
			return fmt.Errorf("invalid session id")
		}
		exists, err := s.store.ActiveSessionExists()
		if err != nil {
			return err
		}
		if exists {
			active, _, err := s.store.LoadActive()
			if err != nil {
				return err
			}
			if active.SessionID != sessionID {
				return ErrSessionNotActive
			}
		}
		record, err := s.store.Load(sessionID)
		if err != nil {
			if !exists && errors.Is(err, os.ErrNotExist) {
				return nil
			}
			return fmt.Errorf("load session: %w", err)
		}
		if record.ApplyPhase == ApplyPhaseCommitted {
			return s.finishRestoredSession(sessionID)
		}
		if err := s.restoreAndVerify(record); err != nil {
			return err
		}
		return s.finishRestoredSession(sessionID)
	})
}

func (s *Service) RecoverActive() (RecoverResult, error) {
	return withMutationLock(s.store, func() (RecoverResult, error) {
		exists, err := s.store.ActiveSessionExists()
		if err != nil {
			return RecoverResult{}, err
		}
		if !exists {
			return RecoverResult{Recovered: false}, nil
		}
		active, _, err := s.store.LoadActive()
		if err != nil {
			return RecoverResult{}, err
		}
		record, err := s.store.Load(active.SessionID)
		if err != nil {
			return RecoverResult{}, fmt.Errorf("%w: rollback record: %v", ErrActiveSessionCorrupt, err)
		}
		if record.ApplyPhase == ApplyPhaseCommitted {
			if err := s.finishRestoredSession(active.SessionID); err != nil {
				return RecoverResult{}, err
			}
			return RecoverResult{Recovered: true, SessionID: active.SessionID}, nil
		}
		if err := s.restoreAndVerify(record); err != nil {
			return RecoverResult{}, err
		}
		if err := s.finishRestoredSession(active.SessionID); err != nil {
			return RecoverResult{}, err
		}
		return RecoverResult{Recovered: true, SessionID: active.SessionID}, nil
	})
}

func (s *Service) restoreAndVerify(record Record) error {
	if err := s.omarchy.RestoreThemeFast(record.OriginalTheme, s.store.SessionDir(record.SessionID)); err != nil {
		return fmt.Errorf("restore theme: %w", err)
	}
	theme, err := s.omarchy.CurrentTheme()
	if err != nil {
		return fmt.Errorf("verify restored theme: %w", err)
	}
	if theme != record.OriginalTheme {
		return fmt.Errorf("verify restored theme: got %q, want %q", theme, record.OriginalTheme)
	}
	if err := s.omarchy.RestoreBackground(record.OriginalBackground); err != nil {
		return fmt.Errorf("restore background: %w", err)
	}
	background, err := s.omarchy.CurrentBackground()
	if err != nil {
		return fmt.Errorf("verify restored background: %w", err)
	}
	if !reflect.DeepEqual(background, record.OriginalBackground) {
		return fmt.Errorf("verify restored background: got %#v, want %#v", background, record.OriginalBackground)
	}
	return nil
}

func (s *Service) finishRestoredSession(sessionID string) error {
	record, err := s.store.Load(sessionID)
	if err != nil {
		return fmt.Errorf("load completed session: %w", err)
	}
	if err := s.store.ClearActive(sessionID); err != nil {
		return fmt.Errorf("clear active session: %w", err)
	}
	if err := s.store.Delete(sessionID); err != nil {
		_ = s.store.SaveActive(ActiveRecord{SessionID: sessionID, CreatedAt: record.CreatedAt})
		return fmt.Errorf("remove session: %w", err)
	}
	return nil
}

func newSessionID() (string, error) {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	return fmt.Sprintf("%s-%s", time.Now().UTC().Format("20060102T150405Z"), hex.EncodeToString(b[:])), nil
}
