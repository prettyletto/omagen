package cleanup

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

const previewPrefix = "omagen-preview-"

type Service struct {
	sessions   *session.Store
	themesRoot string
}

func NewService(sessions *session.Store, themesRoot string) *Service {
	return &Service{sessions: sessions, themesRoot: themesRoot}
}

func (s *Service) Run() (Result, error) {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return Result{}, fmt.Errorf("acquire cleanup lock: %w", err)
	}
	defer lock.Close()
	result := Result{OK: true}
	active, hasActive, err := s.sessions.LoadActive()
	if err != nil {
		return Result{}, fmt.Errorf("load active session: %w", err)
	}
	if hasActive {
		result.ActiveSession = active.SessionID
	}
	s.cleanupPreviewAliases(active, hasActive, &result)
	s.cleanupPermanentTemps(active, hasActive, &result)
	s.cleanupSessions(active, hasActive, &result)
	return result, nil
}

func (s *Service) cleanupPreviewAliases(active session.ActiveRecord, hasActive bool, result *Result) {
	entries, err := os.ReadDir(s.themesRoot)
	if os.IsNotExist(err) {
		return
	}
	if err != nil {
		result.Warnings = append(result.Warnings, fmt.Sprintf("read themes directory: %v", err))
		return
	}
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), previewPrefix) {
			continue
		}
		path := filepath.Join(s.themesRoot, entry.Name())
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			continue
		}
		target, err := os.Readlink(path)
		if err != nil {
			continue
		}
		if !filepath.IsAbs(target) {
			target = filepath.Join(filepath.Dir(path), target)
		}
		target, err = filepath.Abs(target)
		if err != nil {
			continue
		}
		sessionID := s.sessionIDFromPath(target)
		if sessionID == "" || (hasActive && sessionID == active.SessionID) {
			continue
		}
		if err := fsutil.RemoveFileAndSync(path); err != nil {
			result.Warnings = append(result.Warnings, fmt.Sprintf("remove preview alias %s: %v", path, err))
			continue
		}
		result.PreviewAliasesRemoved++
	}
}

func (s *Service) sessionIDFromPath(target string) string {
	root, err := filepath.Abs(s.sessions.Root())
	if err != nil {
		return ""
	}
	rel, err := filepath.Rel(root, target)
	if err != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return ""
	}
	parts := strings.Split(rel, string(filepath.Separator))
	if len(parts) < 2 || parts[0] == "" {
		return ""
	}
	if record, err := s.sessions.Load(parts[0]); err == nil && record.SessionID == parts[0] {
		return parts[0]
	}
	return ""
}

func (s *Service) cleanupPermanentTemps(active session.ActiveRecord, hasActive bool, result *Result) {
	entries, err := os.ReadDir(s.themesRoot)
	if os.IsNotExist(err) || err != nil {
		if err != nil && !os.IsNotExist(err) {
			result.Warnings = append(result.Warnings, fmt.Sprintf("read theme temp directories: %v", err))
		}
		return
	}
	for _, entry := range entries {
		if !entry.IsDir() || !strings.HasPrefix(entry.Name(), ".omagen-apply-") || !strings.HasSuffix(entry.Name(), ".tmp") {
			continue
		}
		path := filepath.Join(s.themesRoot, entry.Name())
		owner, err := fsutil.ReadFileLimited(filepath.Join(path, ".omagen-owner"), 4096)
		if err != nil {
			// A matching name is not proof of Omagen ownership. Leave
			// unmarked/user-created directories untouched.
			continue
		}
		sessionID := strings.TrimSpace(string(owner))
		if sessionID == "" {
			continue
		}
		if record, loadErr := s.sessions.Load(sessionID); loadErr != nil || record.SessionID != sessionID {
			continue
		}
		if hasActive && sessionID == active.SessionID {
			continue
		}
		if err := fsutil.RemoveAllAndSync(path); err != nil {
			result.Warnings = append(result.Warnings, fmt.Sprintf("remove theme temp %s: %v", path, err))
			continue
		}
		result.TempDirsRemoved++
	}
}

func (s *Service) cleanupSessions(active session.ActiveRecord, hasActive bool, result *Result) {
	entries, err := os.ReadDir(s.sessions.Root())
	if os.IsNotExist(err) {
		return
	}
	if err != nil {
		result.Warnings = append(result.Warnings, fmt.Sprintf("read session directory: %v", err))
		return
	}
	for _, entry := range entries {
		if !entry.IsDir() || (hasActive && entry.Name() == active.SessionID) {
			continue
		}
		record, err := s.sessions.Load(entry.Name())
		if err != nil || record.SessionID != entry.Name() {
			continue
		}
		root := s.sessions.SessionDir(record.SessionID)
		if n := countNamedDirs(root, ".tmp"); n > 0 {
			result.TempDirsRemoved += n
		}
		if hasPath(filepath.Join(root, "demo-scene")) || hasPath(filepath.Join(root, "demo-state.json")) {
			result.DemoDirsRemoved++
		}
		if err := fsutil.RemoveAllAndSync(root); err != nil {
			result.Warnings = append(result.Warnings, fmt.Sprintf("remove stale session %s: %v", record.SessionID, err))
			continue
		}
		// Remove protocol journals created by pre-history builds along with the
		// session that owned them.
		if err := fsutil.RemoveAllAndSync(filepath.Join(s.sessions.StateRoot(), "protocol", record.SessionID)); err != nil {
			result.Warnings = append(result.Warnings, fmt.Sprintf("remove stale protocol %s: %v", record.SessionID, err))
		}
		result.SessionDirsRemoved++
	}
}

func countNamedDirs(root, suffix string) int {
	count := 0
	_ = filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err == nil && path != root && entry.IsDir() && strings.HasSuffix(entry.Name(), suffix) {
			count++
			return filepath.SkipDir
		}
		return nil
	})
	return count
}

func hasPath(path string) bool {
	_, err := os.Lstat(path)
	return err == nil
}
