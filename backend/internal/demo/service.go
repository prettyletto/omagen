package demo

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/prettyletto/omagen/backend/internal/omarchy"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type Service struct{ sessions *session.Store }

func NewService(sessions *session.Store) *Service { return &Service{sessions: sessions} }

func (s *Service) Open(sessionID string) (OpenResult, error) {
	if _, err := s.sessions.Load(sessionID); err != nil {
		return OpenResult{}, fmt.Errorf("load session: %w", err)
	}
	state, stateErr := s.loadState(sessionID)
	if stateErr == nil && allOwnedWindowsExist(state) {
		m, err := monitorByName(state.DemoMonitor)
		if err != nil {
			return OpenResult{}, err
		}
		if err = focusMonitor(state.DemoMonitor); err != nil {
			return OpenResult{}, err
		}
		if err = switchWorkspace(state.Workspace); err != nil {
			return OpenResult{}, err
		}
		if err = placeDemoWindows(state, m); err != nil {
			return OpenResult{}, err
		}
		return s.openResult(state, true), nil
	}
	if stateErr != nil && !errors.Is(stateErr, os.ErrNotExist) {
		return OpenResult{}, fmt.Errorf("load demo state: %w", stateErr)
	}
	if stateErr == nil {
		if err := closeDemoWindows(state.Windows, 3*time.Second, nil); err != nil {
			return OpenResult{}, fmt.Errorf("close previous demo before opening another: %w", err)
		}
	}
	var origin State
	if stateErr == nil {
		origin = state
	} else {
		m, err := focusedMonitor()
		if err != nil {
			return OpenResult{}, err
		}
		origin = State{SessionID: sessionID, DemoMonitor: m.Name, OriginMonitor: m.Name, OriginWorkspaceID: m.ActiveWorkspace.ID, OriginWorkspaceName: m.ActiveWorkspace.Name}
	}
	demoMonitor := origin.DemoMonitor
	if demoMonitor == "" {
		demoMonitor = origin.OriginMonitor
	}
	m, err := monitorByName(demoMonitor)
	if err != nil {
		return OpenResult{}, err
	}
	dir, err := s.prepareDemoDir(sessionID)
	if err != nil {
		return OpenResult{}, err
	}
	if err = focusMonitor(demoMonitor); err != nil {
		return OpenResult{}, err
	}
	workspace := workspacePrefix + shortID(sessionID)
	if err = switchWorkspace(workspace); err != nil {
		return OpenResult{}, err
	}
	logPath := s.launchLogPath(sessionID)
	logger, err := newLaunchLogger(logPath)
	if err != nil {
		return OpenResult{}, fmt.Errorf("create demo launch log: %w", err)
	}
	logger.line("session=%s demo_dir=%q monitor=%q workspace=%q", sessionID, dir, demoMonitor, workspace)
	before, err := windowAddresses()
	if err != nil {
		logger.line("before client snapshot error=%v", err)
		_ = restoreWorkspace(origin)
		return OpenResult{}, fmt.Errorf("%w (demo launch log: %s)", err, logPath)
	}
	logger.jsonLine("before clients", beforeClients(before))
	if err := omarchy.WaitForPendingTerminalReload(s.sessions.SessionDir(sessionID)); err != nil {
		logger.line("preview terminal reload wait error=%v", err)
		_ = restoreWorkspace(origin)
		return OpenResult{}, fmt.Errorf("wait for preview terminal reload: %w (demo launch log: %s)", err, logPath)
	}
	windows, err := launchDemoApps(dir, before, logger)
	if err != nil {
		logger.line("launch failed error=%v; cleaning up classified windows", err)
		if closeErr := closeDemoWindows(windows, 3*time.Second, logger); closeErr != nil {
			logger.line("launch cleanup error=%v", closeErr)
		}
		_ = restoreWorkspace(origin)
		_ = os.RemoveAll(dir)
		return OpenResult{}, fmt.Errorf("%w (demo launch log: %s)", err, logPath)
	}
	state = State{SessionID: sessionID, Workspace: workspace, DemoMonitor: demoMonitor, OriginMonitor: origin.OriginMonitor, OriginWorkspaceID: origin.OriginWorkspaceID, OriginWorkspaceName: origin.OriginWorkspaceName, DemoDir: dir, Windows: cloneWindows(windows), CreatedAt: time.Now().UTC()}
	cleanup := func() {
		if closeErr := closeDemoWindows(windows, 3*time.Second, logger); closeErr != nil {
			logger.line("open cleanup error=%v", closeErr)
		}
		_ = restoreWorkspace(origin)
		_ = os.RemoveAll(dir)
	}
	if err = placeDemoWindows(state, m); err != nil {
		cleanup()
		return OpenResult{}, err
	}
	if err = s.saveState(state); err != nil {
		cleanup()
		return OpenResult{}, err
	}
	return s.openResult(state, false), nil
}
func (s *Service) Close(sessionID string) (CloseResult, error) {
	state, err := s.loadState(sessionID)
	if errors.Is(err, os.ErrNotExist) {
		return CloseResult{OK: true, SessionID: sessionID}, nil
	}
	if err != nil {
		return CloseResult{}, fmt.Errorf("load demo state: %w", err)
	}
	logger := appendLaunchLogger(s.launchLogPath(sessionID))
	if err := closeDemoWindows(state.Windows, 3*time.Second, logger); err != nil {
		return CloseResult{}, fmt.Errorf("close demo windows: %w", err)
	}
	if err = restoreWorkspace(state); err != nil {
		return CloseResult{}, err
	}
	if err = os.RemoveAll(state.DemoDir); err != nil {
		return CloseResult{}, fmt.Errorf("remove demo directory: %w", err)
	}
	if err = os.Remove(s.statePath(sessionID)); err != nil && !errors.Is(err, os.ErrNotExist) {
		return CloseResult{}, fmt.Errorf("remove demo state: %w", err)
	}
	return CloseResult{OK: true, SessionID: sessionID, Closed: true}, nil
}
func (s *Service) openResult(state State, reused bool) OpenResult {
	return OpenResult{OK: true, SessionID: state.SessionID, Workspace: state.Workspace, DemoDir: state.DemoDir, LogPath: s.launchLogPath(state.SessionID), Reused: reused, Windows: cloneWindows(state.Windows)}
}
func (s *Service) prepareDemoDir(sessionID string) (string, error) {
	dst := filepath.Join(s.sessions.SessionDir(sessionID), "demo-scene")
	if err := os.RemoveAll(dst); err != nil {
		return "", fmt.Errorf("clear demo directory: %w", err)
	}
	if err := os.MkdirAll(dst, 0755); err != nil {
		return "", fmt.Errorf("create demo directory: %w", err)
	}
	src, err := pluginDemoDir()
	if err == nil {
		if err = copyTree(src, dst); err == nil {
			_ = os.Symlink("sample.go", filepath.Join(dst, "current"))
			return dst, nil
		}
	}
	if err = writeFallbackDemo(dst); err != nil {
		return "", err
	}
	return dst, nil
}
func pluginDemoDir() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", err
	}
	path := filepath.Join(filepath.Dir(filepath.Dir(exe)), "demo")
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("%s is not a directory", path)
	}
	return path, nil
}
func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, e fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		target := filepath.Join(dst, rel)
		info, err := e.Info()
		if err != nil {
			return err
		}
		if e.IsDir() {
			return os.MkdirAll(target, info.Mode().Perm())
		}
		if e.Type()&os.ModeSymlink != 0 {
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, info.Mode().Perm())
	})
}
func writeFallbackDemo(dst string) error {
	for _, dir := range []string{"assets", "scripts"} {
		if err := os.MkdirAll(filepath.Join(dst, dir), 0755); err != nil {
			return err
		}
	}
	files := map[string]string{"sample.go": "package main\n\nimport \"fmt\"\n\nfunc main() { fmt.Println(\"Omagen demo\") }\n", "README.md": "# Omagen Demo\n\nDeterministic live theme preview workspace.\n", "config.json": "{\n  \"name\": \"omagen-demo\",\n  \"variant\": \"source\",\n  \"preview\": true\n}\n", "assets/palette.txt": "background\nforeground\naccent\nselection\nmuted\n\nred\nyellow\ngreen\ncyan\nblue\nmagenta\n", "scripts/build.sh": "#!/bin/bash\nset -euo pipefail\ngo test ./...\n"}
	for name, data := range files {
		mode := os.FileMode(0644)
		if strings.HasPrefix(name, "scripts/") {
			mode = 0755
		}
		if err := os.WriteFile(filepath.Join(dst, name), []byte(data), mode); err != nil {
			return err
		}
	}
	return os.Symlink("sample.go", filepath.Join(dst, "current"))
}
func (s *Service) statePath(id string) string {
	return filepath.Join(s.sessions.SessionDir(id), "demo-state.json")
}

func (s *Service) launchLogPath(id string) string {
	// Keep diagnostics outside the session directory. Session cancellation
	// removes that directory, but the launch log is needed precisely when a
	// launch fails and the session is being cleaned up.
	return filepath.Join(s.sessions.StateRoot(), "demo-launch-"+id+".log")
}

func beforeClients(clients map[string]clientInfo) []clientInfo {
	result := make([]clientInfo, 0, len(clients))
	for _, client := range clients {
		result = append(result, client)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Address < result[j].Address })
	return result
}
func (s *Service) saveState(state State) error {
	path := s.statePath(state.SessionID)
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	tmp := path + ".tmp"
	if err = os.WriteFile(tmp, data, 0600); err != nil {
		return err
	}
	if err = os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}
func (s *Service) loadState(id string) (State, error) {
	data, err := os.ReadFile(s.statePath(id))
	if err != nil {
		return State{}, err
	}
	var state State
	if err = json.Unmarshal(data, &state); err != nil {
		return State{}, err
	}
	if state.SessionID != id {
		return State{}, fmt.Errorf("demo state session mismatch")
	}
	return state, nil
}
func shortID(id string) string {
	var b strings.Builder
	for _, r := range strings.TrimSpace(id) {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		}
		if b.Len() >= 12 {
			break
		}
	}
	if b.Len() == 0 {
		return "session"
	}
	return b.String()
}
func cloneWindows(src map[Slot]string) map[Slot]string {
	dst := make(map[Slot]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
