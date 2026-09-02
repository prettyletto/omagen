package generation

import (
	"fmt"
	"reflect"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type DiscardResult struct {
	OK           bool   `json:"ok"`
	SessionID    string `json:"session_id"`
	GenerationID string `json:"generation_id"`
}

// Discard restores the session baseline, then detaches the current generated
// workspace while preserving the active session and selected configuration.
// Generation files remain session-owned and are removed when the session ends.
func (s *Service) Discard(sessionID, generationID string) (DiscardResult, error) {
	if !validGenerationComponent(sessionID) {
		return DiscardResult{}, fmt.Errorf("invalid session id")
	}
	if !validGenerationComponent(generationID) || generationID[0] == '.' {
		return DiscardResult{}, fmt.Errorf("invalid generation id")
	}

	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return DiscardResult{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()

	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return DiscardResult{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != sessionID {
		return DiscardResult{}, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return DiscardResult{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return DiscardResult{}, fmt.Errorf("%w: cannot discard generation while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	if record.GenerationID != generationID {
		return DiscardResult{}, fmt.Errorf("generation %q is not current", generationID)
	}
	if err := s.restoreBaseline(record); err != nil {
		return DiscardResult{}, err
	}

	record.GenerationID = ""
	record.PreviewVariant = ""
	if err := s.sessions.Save(record); err != nil {
		return DiscardResult{}, fmt.Errorf("persist discarded generation: %w", err)
	}
	return DiscardResult{OK: true, SessionID: sessionID, GenerationID: generationID}, nil
}

func (s *Service) restoreBaseline(record session.Record) error {
	if s.omarchy == nil {
		return nil
	}
	if err := s.omarchy.RestoreThemeFast(record.OriginalTheme, s.sessions.SessionDir(record.SessionID)); err != nil {
		return fmt.Errorf("restore generation baseline theme: %w", err)
	}
	theme, err := s.omarchy.CurrentTheme()
	if err != nil {
		return fmt.Errorf("verify generation baseline theme: %w", err)
	}
	if theme != record.OriginalTheme {
		return fmt.Errorf("verify generation baseline theme: got %q, want %q", theme, record.OriginalTheme)
	}
	if err := s.omarchy.RestoreBackground(record.OriginalBackground); err != nil {
		return fmt.Errorf("restore generation baseline background: %w", err)
	}
	background, err := s.omarchy.CurrentBackground()
	if err != nil {
		return fmt.Errorf("verify generation baseline background: %w", err)
	}
	if !reflect.DeepEqual(background, record.OriginalBackground) {
		return fmt.Errorf("verify generation baseline background: got %#v, want %#v", background, record.OriginalBackground)
	}
	return nil
}
