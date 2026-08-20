package apply

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type ThemeApplier interface {
	ApplyTheme(themeName, logPath string) error
}

type themeInspector interface {
	CurrentTheme() (string, error)
}

type themeRestorer interface {
	themeInspector
	RestoreThemeFast(theme, sessionDir string) error
	CurrentBackground() (session.BackgroundRef, error)
	RestoreBackground(background session.BackgroundRef) error
}

type Service struct {
	sessions   *session.Store
	applier    ThemeApplier
	themesRoot string
}

func NewService(sessions *session.Store, applier ThemeApplier) (*Service, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("resolve user home: %w", err)
	}
	return &Service{sessions: sessions, applier: applier, themesRoot: filepath.Join(home, ".config", "omarchy", "themes")}, nil
}

func (s *Service) Apply(r Request) (Result, error) {
	if err := validComponent("session id", r.SessionID); err != nil {
		return Result{}, err
	}
	if err := validComponent("generation id", r.GenerationID); err != nil {
		return Result{}, err
	}
	variant, err := generation.ParseVariant(string(r.Variant))
	if err != nil {
		return Result{}, err
	}
	r.Variant = variant
	name, err := parseThemeName(r.ThemeName)
	if err != nil {
		return Result{}, fmt.Errorf("validate theme name: %w", err)
	}

	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return Result{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return Result{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != r.SessionID {
		return Result{}, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(r.SessionID)
	if err != nil {
		return Result{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase == session.ApplyPhaseCommitted {
		if err := s.finishCommitted(r.SessionID); err != nil {
			return Result{}, err
		}
		variant, _ := generation.ParseVariant(record.AppliedVariant)
		return Result{SessionID: r.SessionID, GenerationID: record.AppliedGeneration, Variant: variant, ThemeName: record.AppliedTheme, DisplayName: record.AppliedDisplayName, ThemePath: filepath.Join(s.themesRoot, record.AppliedTheme)}, nil
	}
	if record.ApplyPhase == session.ApplyPhasePrepared {
		inspector, ok := s.applier.(themeInspector)
		if !ok {
			return Result{}, fmt.Errorf("cannot resume prepared apply: theme inspection unavailable")
		}
		current, inspectErr := inspector.CurrentTheme()
		if inspectErr != nil {
			return Result{}, fmt.Errorf("inspect prepared apply: %w", inspectErr)
		}
		if current == record.AppliedTheme {
			destination := filepath.Join(s.themesRoot, record.AppliedTheme)
			if !destinationOwnedBy(destination, record.SessionID) {
				return Result{}, fmt.Errorf("prepared apply target %q is active but ownership cannot be verified", record.AppliedTheme)
			}
			record.ApplyPhase = session.ApplyPhaseCommitted
			if err := s.sessions.Save(record); err != nil {
				return Result{}, fmt.Errorf("persist recovered committed apply: %w", err)
			}
			if err := s.finishCommitted(r.SessionID); err != nil {
				return Result{}, err
			}
			variant, _ := generation.ParseVariant(record.AppliedVariant)
			return Result{SessionID: r.SessionID, GenerationID: record.AppliedGeneration, Variant: variant, ThemeName: record.AppliedTheme, DisplayName: record.AppliedDisplayName, ThemePath: filepath.Join(s.themesRoot, record.AppliedTheme)}, nil
		}
		owned := filepath.Join(s.themesRoot, record.AppliedTheme)
		if destinationOwnedBy(owned, r.SessionID) {
			if err := fsutil.RemoveAllAndSync(owned); err != nil {
				return Result{}, fmt.Errorf("remove abandoned prepared theme: %w", err)
			}
		}
	}
	candidate := filepath.Join(s.sessions.SessionDir(r.SessionID), "generations", r.GenerationID, string(r.Variant))
	if err := validateCandidate(candidate, s.sessions.SessionDir(r.SessionID)); err != nil {
		return Result{}, err
	}
	destination := filepath.Join(s.themesRoot, name.Slug)
	if _, err := os.Lstat(destination); err == nil {
		if !destinationOwnedBy(destination, r.SessionID) {
			return Result{}, fmt.Errorf("theme %q already exists", name.Display)
		}
		if err := fsutil.RemoveAllAndSync(destination); err != nil {
			return Result{}, fmt.Errorf("remove abandoned theme %q: %w", name.Display, err)
		}
	} else if !os.IsNotExist(err) {
		return Result{}, fmt.Errorf("inspect theme destination: %w", err)
	}
	record.ApplyPhase = session.ApplyPhasePrepared
	record.AppliedTheme = name.Slug
	record.AppliedGeneration = r.GenerationID
	record.AppliedVariant = string(r.Variant)
	record.AppliedDisplayName = name.Display
	if err := s.sessions.Save(record); err != nil {
		return Result{}, fmt.Errorf("persist prepared apply: %w", err)
	}
	if err := publish(candidate, destination, s.themesRoot, r.SessionID); err != nil {
		return Result{}, fmt.Errorf("publish theme: %w", err)
	}
	logPath := filepath.Join(s.sessions.SessionDir(r.SessionID), "apply.log")
	if err := s.applier.ApplyTheme(name.Slug, logPath); err != nil {
		return Result{}, fmt.Errorf("apply theme %q: %w", name.Display, err)
	}
	record.ApplyPhase = session.ApplyPhaseCommitted
	if err := s.sessions.Save(record); err != nil {
		return Result{}, fmt.Errorf("persist committed apply: %w", err)
	}
	// The external theme switch has committed. Marker removal is cleanup only;
	// failure here must not turn the operation back into a rollback.
	_ = fsutil.RemoveFileAndSync(filepath.Join(destination, ".omagen-owner"))
	if err := s.finishCommitted(r.SessionID); err != nil {
		return Result{}, err
	}
	return Result{SessionID: r.SessionID, GenerationID: r.GenerationID, Variant: r.Variant, ThemeName: name.Slug, DisplayName: name.Display, ThemePath: destination}, nil
}

// RecoverPending resolves an Apply transaction left in PREPARED or COMMITTED
// state by a process crash. It returns handled=false for an ordinary session.
func (s *Service) RecoverPending(sessionID string) (handled bool, err error) {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return false, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil || !exists || active.SessionID != sessionID {
		return false, err
	}
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return false, err
	}
	switch record.ApplyPhase {
	case session.ApplyPhaseCommitted:
		return true, s.finishCommitted(sessionID)
	case session.ApplyPhasePrepared:
		return true, s.recoverPrepared(record)
	default:
		return false, nil
	}
}

func (s *Service) recoverPrepared(record session.Record) error {
	inspector, inspectable := s.applier.(themeInspector)
	if inspectable {
		current, err := inspector.CurrentTheme()
		if err != nil {
			return fmt.Errorf("inspect prepared apply: %w", err)
		}
		if current == record.AppliedTheme {
			destination := filepath.Join(s.themesRoot, record.AppliedTheme)
			if !destinationOwnedBy(destination, record.SessionID) {
				return fmt.Errorf("prepared apply target %q is active but ownership cannot be verified", record.AppliedTheme)
			}
			record.ApplyPhase = session.ApplyPhaseCommitted
			if err := s.sessions.Save(record); err != nil {
				return fmt.Errorf("persist recovered apply: %w", err)
			}
			return s.finishCommitted(record.SessionID)
		}
	}

	destination := filepath.Join(s.themesRoot, record.AppliedTheme)
	if destinationOwnedBy(destination, record.SessionID) {
		if err := fsutil.RemoveAllAndSync(destination); err != nil {
			return fmt.Errorf("remove abandoned apply: %w", err)
		}
	}
	restorer, ok := s.applier.(themeRestorer)
	if !ok {
		return fmt.Errorf("cannot restore prepared apply: applier has no restore capability")
	}
	if err := restorer.RestoreThemeFast(record.OriginalTheme, s.sessions.SessionDir(record.SessionID)); err != nil {
		return fmt.Errorf("restore prepared theme: %w", err)
	}
	theme, err := restorer.CurrentTheme()
	if err != nil || theme != record.OriginalTheme {
		return fmt.Errorf("verify prepared theme restore: got %q err=%v", theme, err)
	}
	if err := restorer.RestoreBackground(record.OriginalBackground); err != nil {
		return fmt.Errorf("restore prepared background: %w", err)
	}
	background, err := restorer.CurrentBackground()
	if err != nil || !reflect.DeepEqual(background, record.OriginalBackground) {
		return fmt.Errorf("verify prepared background restore: got %#v err=%v", background, err)
	}
	return s.finishCommitted(record.SessionID)
}

func (s *Service) finishCommitted(sessionID string) error {
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return fmt.Errorf("load committed session: %w", err)
	}
	if err := s.sessions.ClearActive(sessionID); err != nil {
		return fmt.Errorf("clear active session: %w", err)
	}
	if err := s.sessions.Delete(sessionID); err != nil {
		_ = s.sessions.SaveActive(session.ActiveRecord{SessionID: sessionID, CreatedAt: record.CreatedAt})
		return fmt.Errorf("remove committed session: %w", err)
	}
	return nil
}

func writeOwnerMarker(destination, sessionID string) error {
	return fsutil.AtomicWriteFile(filepath.Join(destination, ".omagen-owner"), []byte(sessionID+"\n"), 0o600)
}

func destinationOwnedBy(destination, sessionID string) bool {
	data, err := os.ReadFile(filepath.Join(destination, ".omagen-owner"))
	return err == nil && strings.TrimSpace(string(data)) == sessionID
}
func validComponent(label, value string) error {
	if value == "" || value == "." || value == ".." || filepath.Base(value) != value {
		return fmt.Errorf("invalid %s", label)
	}
	return nil
}
func validateCandidate(path, base string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("inspect candidate: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("candidate is not a directory")
	}
	rel, err := filepath.Rel(base, path)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return fmt.Errorf("candidate escapes session directory")
	}
	if _, err := os.Stat(filepath.Join(path, "colors.toml")); err != nil {
		return fmt.Errorf("candidate colors.toml: %w", err)
	}
	if _, err := os.Stat(filepath.Join(path, "backgrounds")); err != nil {
		return fmt.Errorf("candidate backgrounds: %w", err)
	}
	return nil
}

func publish(source, destination, parent, sessionID string) error {
	if err := fsutil.EnsureDir(parent, 0o755); err != nil {
		return err
	}
	temp, err := os.MkdirTemp(parent, ".omagen-apply-*.tmp")
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			_ = os.RemoveAll(temp)
		}
	}()
	if err := copyTree(source, temp); err != nil {
		return err
	}
	if err := writeOwnerMarker(temp, sessionID); err != nil {
		return err
	}
	if _, err := fsutil.RenameAndSyncNoReplace(temp, destination); err != nil {
		return err
	}
	committed = true
	return nil
}
func copyTree(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := destination
		if rel != "." {
			target = filepath.Join(destination, rel)
		}
		if entry.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported candidate entry %s", rel)
		}
		return fsutil.CopyFileAtomic(path, target, 0o644)
	})
}
