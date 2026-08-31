package session

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"reflect"
	"time"

	"github.com/prettyletto/omagen/backend/internal/barprofile"
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
	bar     barSnapshotStore
}

func (s *Service) Store() *Store { return s.store }

type barSnapshotStore interface {
	Capture(theme string) (barprofile.Snapshot, error)
	LoadSnapshot(sessionID string) (barprofile.Snapshot, error)
	Restore(snapshot barprofile.Snapshot) error
	SaveSnapshot(sessionID string, snapshot barprofile.Snapshot) error
	DeleteSnapshot(sessionID string) error
}

func NewService(store *Store, omarchy Omarchy, barStores ...barSnapshotStore) *Service {
	var bar barSnapshotStore
	if len(barStores) > 0 {
		bar = barStores[0]
	}
	return &Service{store: store, omarchy: omarchy, bar: bar}
}

func (s *Service) Begin(styles ...any) (BeginResult, error) {
	shellStyle := DefaultShellStyle()
	desktopStyle := DefaultDesktopStyle()
	barStyle := DefaultBarStyle()
	animationsStyle := DefaultAnimationsStyle()
	lookFeel := LookFeelDocument{}
	terminalTranslucency := TerminalTranslucency{}
	extraConfigs := len(styles) > 0
	for _, style := range styles {
		switch value := style.(type) {
		case ShellStyle:
			shellStyle = value
		case DesktopStyle:
			desktopStyle = value
		case BarStyle:
			barStyle = value
		case AnimationsStyle:
			animationsStyle = value
		case LookFeelDocument:
			lookFeel = value
		case TerminalTranslucency:
			terminalTranslucency = value
		default:
			return BeginResult{}, fmt.Errorf("invalid style configuration")
		}
	}
	shellStyle = NormalizeShellStyle(shellStyle)
	desktopStyle = NormalizeDesktopStyle(desktopStyle)
	barStyle = NormalizeBarStyle(barStyle)
	animationsStyle = NormalizeAnimationsStyle(animationsStyle)
	if extraConfigs {
		if lookFeel.Preset == "" {
			lookFeel = DefaultLookFeelDocument()
		}
		lookFeel = NormalizeLookFeelDocument(lookFeel)
		if terminalTranslucency.Mode == "" {
			terminalTranslucency = DefaultTerminalTranslucency()
		}
		terminalTranslucency = NormalizeTerminalTranslucency(terminalTranslucency)
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
		if !animationsStyle.Valid() {
			return BeginResult{}, fmt.Errorf("invalid animations style")
		}
		if !lookFeel.Valid() {
			return BeginResult{}, fmt.Errorf("invalid Look & Feel document")
		}
		if !terminalTranslucency.Valid() {
			return BeginResult{}, fmt.Errorf("invalid terminal translucency")
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
		record := Record{SessionID: sessionID, Workflow: "generate", OriginalTheme: theme, OriginalBackground: background, ExtraConfigs: extraConfigs, ShellStyle: shellStyle, DesktopStyle: desktopStyle, BarStyle: barStyle, AnimationsStyle: animationsStyle, LookFeel: lookFeel, TerminalTranslucency: terminalTranslucency, CreatedAt: now}
		var capturedBarSnapshot *barprofile.Snapshot
		if s.bar != nil {
			snapshot, snapshotErr := s.bar.Capture(theme)
			if snapshotErr != nil {
				return BeginResult{}, fmt.Errorf("capture user bar: %w", snapshotErr)
			}
			// Keep the durable session record small. The full shell.json bytes live
			// in the separately checksummed bar snapshot file; the record carries
			// only its metadata for status/resume responses.
			recordSnapshot := snapshot
			recordSnapshot.Config = nil
			record.BarSnapshot = &recordSnapshot
			capturedBarSnapshot = &snapshot
		}
		if err := s.store.Save(record); err != nil {
			return BeginResult{}, fmt.Errorf("persist session: %w", err)
		}
		if err := s.store.SaveActive(ActiveRecord{SessionID: sessionID, CreatedAt: now}); err != nil {
			_ = s.store.Delete(sessionID)
			return BeginResult{}, fmt.Errorf("persist active session: %w", err)
		}
		if s.bar != nil && capturedBarSnapshot != nil {
			if err := s.bar.SaveSnapshot(sessionID, *capturedBarSnapshot); err != nil {
				// Keep the active marker until every cleanup step succeeds. If
				// cleanup itself fails, the durable record remains available for
				// recovery instead of pointing at a deleted session.
				cleanupErr := s.bar.DeleteSnapshot(sessionID)
				if cleanupErr == nil {
					cleanupErr = s.store.ClearActive(sessionID)
				}
				if cleanupErr == nil {
					cleanupErr = s.store.Delete(sessionID)
				}
				if cleanupErr != nil {
					// Best effort: the active marker is deliberately retained when
					// any cleanup step failed, so recovery can still find the record.
					_ = s.store.SaveActive(ActiveRecord{SessionID: sessionID, CreatedAt: now})
				}
				if cleanupErr != nil {
					return BeginResult{}, fmt.Errorf("persist user bar snapshot: %w (preserve recovery state: %v)", err, cleanupErr)
				}
				return BeginResult{}, fmt.Errorf("persist user bar snapshot: %w", err)
			}
		}
		return BeginResult{SessionID: sessionID, Workflow: record.Workflow, ThemeEdit: record.ThemeEdit, OriginalTheme: theme, OriginalBackground: background, ShellStyle: shellStyle, DesktopStyle: desktopStyle, BarStyle: barStyle, AnimationsStyle: animationsStyle, LookFeel: lookFeel, TerminalTranslucency: terminalTranslucency, ExtraConfigs: extraConfigs, BarSnapshot: record.BarSnapshot}, nil
	})
}

// MarkThemeEdit attaches an already-created source snapshot to a newly begun
// session. Keeping this mutation in session.Service preserves the durable
// record as the only lifecycle authority while the theme-edit adapter owns
// source discovery and copying.
func (s *Service) MarkThemeEdit(sessionID string, edit ThemeEdit, generationID string) error {
	return withMutationLockError(s.store, func() error {
		if !validSessionID(sessionID) {
			return fmt.Errorf("invalid session id")
		}
		active, exists, err := s.store.LoadActive()
		if err != nil {
			return err
		}
		if !exists || active.SessionID != sessionID {
			return ErrSessionNotActive
		}
		record, err := s.store.Load(sessionID)
		if err != nil {
			return err
		}
		if (record.Workflow != "" && record.Workflow != "generate") || record.ThemeEdit != nil {
			return fmt.Errorf("session is already configured for a different workflow")
		}
		if edit.SourceID == "" || edit.SourceName == "" || edit.SourcePath == "" || edit.SourceKind == "" {
			return fmt.Errorf("theme-edit source metadata is incomplete")
		}
		if generationID == "" || !validSessionID(generationID) {
			return fmt.Errorf("theme-edit source generation is incomplete")
		}
		record.Workflow = "theme-edit"
		// Theme editing always exposes the Studio controls, even when the
		// selected source has no Omagen recipe yet. Scope ownership remains
		// empty until the user explicitly changes an engine.
		record.ExtraConfigs = true
		if edit.Shell.Preset != "" || edit.Shell.Surface != "" || edit.Desktop.WindowOpacity != nil {
			record.ShellStyle = NormalizeShellStyle(edit.Shell)
			record.DesktopStyle = NormalizeDesktopStyle(edit.Desktop)
			record.BarStyle = NormalizeBarStyle(edit.Bar)
			record.AnimationsStyle = NormalizeAnimationsStyle(edit.Animations)
			record.LookFeel = NormalizeLookFeelDocument(edit.LookFeel)
			record.TerminalTranslucency = NormalizeTerminalTranslucency(edit.Terminal)
		}
		record.ThemeEdit = &edit
		record.GenerationID = generationID
		record.PreviewVariant = ""
		return s.store.Save(record)
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
	if s.bar != nil && record.BarSnapshot != nil {
		snapshot := *record.BarSnapshot
		if persisted, err := s.bar.LoadSnapshot(record.SessionID); err == nil {
			snapshot = persisted
		} else if snapshot.ConfigExists && len(snapshot.Config) == 0 {
			return fmt.Errorf("load user bar snapshot: %w", err)
		}
		if err := s.bar.Restore(snapshot); err != nil {
			return fmt.Errorf("restore user bar: %w", err)
		}
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
	// The transaction is already durably inactive. Snapshot cleanup is
	// intentionally last so a crash cannot leave an active session without its
	// rollback bytes. A leftover snapshot is harmless and can be cleaned later.
	if s.bar != nil {
		if err := s.bar.DeleteSnapshot(sessionID); err != nil {
			return fmt.Errorf("remove bar snapshot: %w", err)
		}
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
