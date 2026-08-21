package generation

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type DiscardResult struct {
	OK           bool   `json:"ok"`
	SessionID    string `json:"session_id"`
	GenerationID string `json:"generation_id"`
}

// Discard detaches the current generated workspace while preserving the
// active session's original rollback baseline and selected configuration.
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

	record.GenerationID = ""
	record.PreviewVariant = ""
	if err := s.sessions.Save(record); err != nil {
		return DiscardResult{}, fmt.Errorf("persist discarded generation: %w", err)
	}
	return DiscardResult{OK: true, SessionID: sessionID, GenerationID: generationID}, nil
}
