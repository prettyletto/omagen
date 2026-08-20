package apply

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type ThemeApplier interface {
	ApplyTheme(themeName, logPath string) error
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
	if record.ApplyCommitted {
		if err := s.finishCommitted(r.SessionID); err != nil {
			return Result{}, err
		}
		variant, _ := generation.ParseVariant(record.AppliedVariant)
		return Result{SessionID: r.SessionID, GenerationID: record.AppliedGeneration, Variant: variant, ThemeName: record.AppliedTheme, DisplayName: record.AppliedDisplayName, ThemePath: filepath.Join(s.themesRoot, record.AppliedTheme)}, nil
	}
	candidate := filepath.Join(s.sessions.SessionDir(r.SessionID), "generations", r.GenerationID, string(r.Variant))
	if err := validateCandidate(candidate, s.sessions.SessionDir(r.SessionID)); err != nil {
		return Result{}, err
	}
	destination := filepath.Join(s.themesRoot, name.Slug)
	if _, err := os.Lstat(destination); err == nil {
		return Result{}, fmt.Errorf("theme %q already exists", name.Display)
	} else if !os.IsNotExist(err) {
		return Result{}, fmt.Errorf("inspect theme destination: %w", err)
	}
	if err := publish(candidate, destination, s.themesRoot); err != nil {
		return Result{}, fmt.Errorf("publish theme: %w", err)
	}
	logPath := filepath.Join(s.sessions.SessionDir(r.SessionID), "apply.log")
	if err := s.applier.ApplyTheme(name.Slug, logPath); err != nil {
		_ = os.RemoveAll(destination)
		return Result{}, fmt.Errorf("apply theme %q: %w", name.Display, err)
	}
	record.ApplyCommitted = true
	record.AppliedTheme = name.Slug
	record.AppliedGeneration = r.GenerationID
	record.AppliedVariant = string(r.Variant)
	record.AppliedDisplayName = name.Display
	if err := s.sessions.Save(record); err != nil {
		return Result{}, fmt.Errorf("persist committed apply: %w", err)
	}
	if err := s.finishCommitted(r.SessionID); err != nil {
		return Result{}, err
	}
	return Result{SessionID: r.SessionID, GenerationID: r.GenerationID, Variant: r.Variant, ThemeName: name.Slug, DisplayName: name.Display, ThemePath: destination}, nil
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

func publish(source, destination, parent string) error {
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
