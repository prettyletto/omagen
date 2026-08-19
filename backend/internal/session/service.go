package session

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
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

func NewService(store *Store, omarchy Omarchy) *Service {
	return &Service{store: store, omarchy: omarchy}
}

func (s *Service) Begin() (BeginResult, error) {
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
	record := Record{SessionID: sessionID, OriginalTheme: theme, OriginalBackground: background, CreatedAt: time.Now().UTC()}
	if err := s.store.Save(record); err != nil {
		return BeginResult{}, fmt.Errorf("persist session: %w", err)
	}
	return BeginResult{SessionID: record.SessionID, OriginalTheme: record.OriginalTheme, OriginalBackground: record.OriginalBackground}, nil
}

func (s *Service) Cancel(sessionID string) error {
	record, err := s.store.Load(sessionID)
	if err != nil {
		return fmt.Errorf("load session: %w", err)
	}
	sessionDir := s.store.SessionDir(sessionID)
	if err := s.omarchy.RestoreThemeFast(record.OriginalTheme, sessionDir); err != nil {
		return fmt.Errorf("restore theme: %w", err)
	}
	if err := s.omarchy.RestoreBackground(record.OriginalBackground); err != nil {
		return fmt.Errorf("restore background: %w", err)
	}
	if err := s.store.Delete(sessionID); err != nil {
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
