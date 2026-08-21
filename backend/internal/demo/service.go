package demo

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/omarchy"
	"github.com/prettyletto/omagen/backend/internal/session"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type Service struct{ sessions *session.Store }

const captureSettleDelay = 750 * time.Millisecond

func NewService(sessions *session.Store) *Service { return &Service{sessions: sessions} }

func (s *Service) Open(sessionID string) (OpenResult, error) {
	if _, err := s.requireActiveIdle(sessionID); err != nil {
		return OpenResult{}, fmt.Errorf("inspect session: %w", err)
	}
	state, stateErr := s.loadState(sessionID)
	if stateErr != nil && !errors.Is(stateErr, os.ErrNotExist) {
		return OpenResult{}, fmt.Errorf("load demo state: %w", stateErr)
	}
	if stateErr == nil {
		return s.reopenDemo(state)
	}
	return s.createDemo(sessionID)
}

func (s *Service) requireActiveIdle(sessionID string) (session.Record, error) {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return session.Record{}, fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return session.Record{}, fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != sessionID {
		return session.Record{}, session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(sessionID)
	if err != nil {
		return session.Record{}, fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return session.Record{}, fmt.Errorf("%w: cannot open Demo while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	return record, nil
}

func (s *Service) saveStateIfActive(state State) error {
	lock, err := fsutil.AcquireFileLock(s.sessions.MutationLockPath())
	if err != nil {
		return fmt.Errorf("acquire session mutation lock: %w", err)
	}
	defer lock.Close()
	active, exists, err := s.sessions.LoadActive()
	if err != nil {
		return fmt.Errorf("load active session: %w", err)
	}
	if !exists || active.SessionID != state.SessionID {
		return session.ErrSessionNotActive
	}
	record, err := s.sessions.Load(state.SessionID)
	if err != nil {
		return fmt.Errorf("load session: %w", err)
	}
	if record.ApplyPhase != session.ApplyPhaseNone {
		return fmt.Errorf("%w: cannot persist Demo while phase is %q", session.ErrApplyInProgress, record.ApplyPhase)
	}
	return s.saveState(state)
}

func (s *Service) reopenDemo(state State) (OpenResult, error) {
	if state.OwnerToken == "" {
		state.OwnerToken = makeOwnerToken(state.SessionID)
	}
	monitor, err := resolveDemoMonitor(state)
	if err != nil {
		return OpenResult{}, err
	}
	state.DemoMonitor = monitor.Name
	if err = focusMonitor(monitor.Name); err != nil {
		return OpenResult{}, err
	}
	if err = switchWorkspace(state.Workspace); err != nil {
		return OpenResult{}, err
	}
	surviving, err := survivingWindows(state)
	if err != nil {
		return OpenResult{}, err
	}
	missing := missingSlots(surviving)
	createdDuringReopen := map[Slot]string{}
	if len(missing) > 0 {
		before, err := windowAddresses()
		if err != nil {
			return OpenResult{}, err
		}
		logger := appendLaunchLogger(s.launchLogPath(state.SessionID))
		created, err := launchDemoSlots(state.DemoDir, state.OwnerToken, missing, ResolveCapabilities(), before, logger)
		if err != nil {
			return OpenResult{}, fmt.Errorf("recreate demo slots: %w", err)
		}
		createdDuringReopen = cloneWindows(created)
		surviving = mergeWindows(surviving, created)
	}
	cleanupCreated := func() error {
		if len(createdDuringReopen) == 0 {
			return nil
		}
		return closeDemoWindows(createdDuringReopen, 3*time.Second, appendLaunchLogger(s.launchLogPath(state.SessionID)))
	}
	state.Windows = surviving
	if err = placeDemoWindows(state, monitor); err != nil {
		return OpenResult{}, errors.Join(err, cleanupCreated())
	}
	if err = s.saveStateIfActive(state); err != nil {
		return OpenResult{}, errors.Join(fmt.Errorf("persist demo state: %w", err), cleanupCreated())
	}
	return s.openResult(state, len(missing) == 0), nil
}

func resolveDemoMonitor(state State) (monitorInfo, error) {
	if state.DemoMonitor != "" {
		if monitor, err := monitorByName(state.DemoMonitor); err == nil {
			return monitor, nil
		}
	}
	return focusedMonitor()
}

func (s *Service) createDemo(sessionID string) (OpenResult, error) {
	m, err := focusedMonitor()
	if err != nil {
		return OpenResult{}, err
	}
	origin := State{SessionID: sessionID, DemoMonitor: m.Name, OriginMonitor: m.Name, OriginWorkspaceID: m.ActiveWorkspace.ID, OriginWorkspaceName: m.ActiveWorkspace.Name}
	demoMonitor := origin.DemoMonitor
	dir, err := s.prepareDemoDir(sessionID)
	if err != nil {
		return OpenResult{}, err
	}
	if err = focusMonitor(demoMonitor); err != nil {
		return OpenResult{}, err
	}
	if _, err = s.requireActiveIdle(sessionID); err != nil {
		_ = os.RemoveAll(dir)
		return OpenResult{}, fmt.Errorf("recheck session before opening Demo: %w", err)
	}
	workspace := workspacePrefix + shortID(sessionID)
	state := State{SessionID: sessionID, Workspace: workspace, DemoMonitor: demoMonitor, OriginMonitor: origin.OriginMonitor, OriginWorkspaceID: origin.OriginWorkspaceID, OriginWorkspaceName: origin.OriginWorkspaceName, DemoDir: dir, OwnerToken: makeOwnerToken(sessionID), Windows: map[Slot]string{}, CreatedAt: time.Now().UTC()}
	if err = s.saveStateIfActive(state); err != nil {
		return OpenResult{}, fmt.Errorf("persist initial demo state: %w", err)
	}
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
	windows, err := launchDemoSlots(dir, state.OwnerToken, allDemoSlots(), ResolveCapabilities(), before, logger)
	if err != nil {
		logger.line("launch failed error=%v; cleaning up classified windows", err)
		state.Windows = cloneWindows(windows)
		_ = s.saveStateIfActive(state)
		closeErr := closeDemoWindows(windows, 3*time.Second, logger)
		restoreErr := restoreWorkspace(origin)
		if closeErr == nil && restoreErr == nil {
			_ = os.RemoveAll(dir)
			_ = os.Remove(s.statePath(sessionID))
		}
		return OpenResult{}, fmt.Errorf("%w (demo launch log: %s): cleanup=%v restore=%v", err, logPath, closeErr, restoreErr)
	}
	state.Windows = cloneWindows(windows)
	cleanup := func() error {
		closeErr := closeDemoWindows(windows, 3*time.Second, logger)
		restoreErr := restoreWorkspace(origin)
		if closeErr == nil && restoreErr == nil {
			if err := os.RemoveAll(dir); err != nil {
				return err
			}
			if err := os.Remove(s.statePath(sessionID)); err != nil && !errors.Is(err, os.ErrNotExist) {
				return err
			}
		}
		return errors.Join(closeErr, restoreErr)
	}
	if err = placeDemoWindows(state, m); err != nil {
		return OpenResult{}, errors.Join(err, cleanup())
	}
	if err = s.saveStateIfActive(state); err != nil {
		return OpenResult{}, errors.Join(err, cleanup())
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
	surviving, err := survivingWindows(state)
	if err != nil {
		return CloseResult{}, fmt.Errorf("find demo windows: %w", err)
	}
	if err := closeDemoWindows(surviving, 3*time.Second, logger); err != nil {
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

// CapturePreview takes a screenshot only for an Apply request. It deliberately
// uses the Demo state monitor/workspace instead of the current focus, then
// normalizes the result into the session's staged preview.png asset.
func (s *Service) CapturePreview(sessionID string) (CaptureResult, error) {
	if _, err := s.requireActiveIdle(sessionID); err != nil {
		return CaptureResult{}, fmt.Errorf("inspect session: %w", err)
	}
	state, err := s.loadState(sessionID)
	if err != nil {
		return CaptureResult{}, fmt.Errorf("load demo state: %w", err)
	}
	monitor, err := resolveDemoMonitor(state)
	if err != nil {
		return CaptureResult{}, err
	}
	surviving, err := survivingWindows(state)
	if err != nil {
		return CaptureResult{}, fmt.Errorf("find demo windows: %w", err)
	}
	if missing := missingSlots(surviving); len(missing) > 0 {
		return CaptureResult{}, fmt.Errorf("cannot capture Demo before all windows are ready: missing %s", strings.Join(slotNames(missing), ", "))
	}
	if err := focusMonitor(monitor.Name); err != nil {
		return CaptureResult{}, err
	}
	if err := switchWorkspace(state.Workspace); err != nil {
		return CaptureResult{}, err
	}
	if err := omarchy.WaitForPendingTerminalReload(s.sessions.SessionDir(sessionID)); err != nil {
		return CaptureResult{}, fmt.Errorf("wait for Demo terminal reload: %w", err)
	}
	// Window classification completes before Open returns, but terminal/editor
	// content and the shell bar need one compositor settle interval before the
	// screenshot is useful as a gallery preview.
	time.Sleep(captureSettleDelay)

	sessionDir := s.sessions.SessionDir(sessionID)
	rawPath := filepath.Join(sessionDir, ".demo-capture.png")
	previewPath := filepath.Join(sessionDir, "apply-preview.png")
	_ = os.Remove(rawPath)
	cmd := exec.Command("grim", "-o", monitor.Name, rawPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return CaptureResult{}, fmt.Errorf("capture Demo monitor %q: %w: %s", monitor.Name, err, strings.TrimSpace(string(output)))
	}
	defer os.Remove(rawPath)
	if err := theme.WritePreviewFile(previewPath, rawPath); err != nil {
		return CaptureResult{}, fmt.Errorf("normalize Demo screenshot: %w", err)
	}
	return CaptureResult{OK: true, SessionID: sessionID, PreviewPath: previewPath}, nil
}

func slotNames(slots []Slot) []string {
	result := make([]string, 0, len(slots))
	for _, slot := range slots {
		result = append(result, string(slot))
	}
	return result
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
	return fsutil.AtomicWriteJSON(path, state, 0600)
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
