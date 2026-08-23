package demo

import (
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

type workspaceRef struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}
type monitorInfo struct {
	Name            string       `json:"name"`
	Width           int          `json:"width"`
	Height          int          `json:"height"`
	X               int          `json:"x"`
	Y               int          `json:"y"`
	Scale           float64      `json:"scale"`
	Transform       int          `json:"transform"`
	Focused         bool         `json:"focused"`
	Reserved        [4]int       `json:"reserved"`
	ActiveWorkspace workspaceRef `json:"activeWorkspace"`
}
type clientInfo struct {
	Address      string       `json:"address"`
	Class        string       `json:"class"`
	InitialClass string       `json:"initialClass"`
	Title        string       `json:"title"`
	InitialTitle string       `json:"initialTitle"`
	PID          int          `json:"pid"`
	Workspace    workspaceRef `json:"workspace"`
}

func hyprJSON(dst any, args ...string) error {
	data, err := exec.Command("hyprctl", append([]string{"-j"}, args...)...).Output()
	if err != nil {
		return fmt.Errorf("hyprctl %s: %w", strings.Join(args, " "), err)
	}
	if err := json.Unmarshal(data, dst); err != nil {
		return fmt.Errorf("decode hyprctl %s: %w", strings.Join(args, " "), err)
	}
	return nil
}
func monitors() ([]monitorInfo, error) { var v []monitorInfo; return v, hyprJSON(&v, "monitors") }
func clients() ([]clientInfo, error)   { var v []clientInfo; return v, hyprJSON(&v, "clients") }
func focusedMonitor() (monitorInfo, error) {
	v, err := monitors()
	if err != nil {
		return monitorInfo{}, err
	}
	for _, m := range v {
		if m.Focused {
			return m, nil
		}
	}
	return monitorInfo{}, fmt.Errorf("hyprland returned no focused monitor")
}
func monitorByName(name string) (monitorInfo, error) {
	v, err := monitors()
	if err != nil {
		return monitorInfo{}, err
	}
	for _, m := range v {
		if m.Name == name {
			return m, nil
		}
	}
	return monitorInfo{}, fmt.Errorf("hyprland monitor %q not found", name)
}
func luaString(value string) string {
	return strconv.Quote(value)
}

func hyprLuaDispatch(expression string) error {
	data, err := exec.Command("hyprctl", "dispatch", expression).CombinedOutput()
	if err != nil {
		return fmt.Errorf("hyprctl dispatch %s: %w: %s", expression, err, strings.TrimSpace(string(data)))
	}
	return nil
}

func hyprDispatch(dispatcher, arg string) error {
	switch dispatcher {
	case "focusmonitor":
		return hyprLuaDispatch(fmt.Sprintf("hl.dsp.focus({ monitor = %s })", luaString(arg)))
	case "workspace":
		return hyprLuaDispatch(fmt.Sprintf("hl.dsp.focus({ workspace = %s })", luaString(arg)))
	case "closewindow":
		return hyprLuaDispatch(fmt.Sprintf("hl.dsp.window.close(%s)", luaString(arg)))
	default:
		return fmt.Errorf("unsupported Lua Hyprland dispatcher %q", dispatcher)
	}
}
func focusMonitor(name string) error {
	if name == "" {
		return nil
	}
	return hyprDispatch("focusmonitor", name)
}
func switchWorkspace(name string) error { return hyprDispatch("workspace", "name:"+name) }
func restoreWorkspace(s State) error {
	if err := focusMonitor(s.OriginMonitor); err != nil {
		return err
	}
	if s.OriginWorkspaceID > 0 {
		return hyprDispatch("workspace", fmt.Sprintf("%d", s.OriginWorkspaceID))
	}
	if s.OriginWorkspaceName != "" {
		return hyprDispatch("workspace", "name:"+s.OriginWorkspaceName)
	}
	return fmt.Errorf("demo state has no origin workspace")
}
func placeWindow(address, workspace string) error {
	if address == "" {
		return fmt.Errorf("cannot place empty window address")
	}
	workspaceSelector := "name:" + workspace
	if strings.HasPrefix(workspace, "special:") {
		workspaceSelector = workspace
	}
	selector := luaString("address:" + address)
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.move({ workspace = %s, follow = false, window = %s })",
		luaString(workspaceSelector), selector,
	)); err != nil {
		return fmt.Errorf("move demo window %s to workspace: %w", address, err)
	}
	return nil
}

func focusWindow(address string) error {
	if address == "" {
		return fmt.Errorf("cannot focus empty window address")
	}
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.focus({ window = %s })", luaString("address:"+address),
	)); err != nil {
		return fmt.Errorf("focus demo window %s: %w", address, err)
	}
	return nil
}

func preselectDwindle(direction string) error {
	if direction != "r" && direction != "d" {
		return fmt.Errorf("unsupported Demo dwindle preselection %q", direction)
	}
	if err := hyprLuaDispatch(fmt.Sprintf("hl.dsp.layout(%s)", luaString("preselect "+direction))); err != nil {
		return fmt.Errorf("preselect Demo dwindle %s: %w", direction, err)
	}
	return nil
}

func adjustDwindleRatio(delta float64) error {
	if delta == 0 {
		return nil
	}
	message := fmt.Sprintf("splitratio %+.3f", delta)
	if err := hyprLuaDispatch(fmt.Sprintf("hl.dsp.layout(%s)", luaString(message))); err != nil {
		return fmt.Errorf("adjust Demo dwindle split ratio by %.2f: %w", delta, err)
	}
	return nil
}

// shapeDemoWindows restores the historical Demo proportions after the four
// leaves exist. Focusing each lower leaf makes splitratio address its column's
// vertical parent: a positive delta gives the upper leaf roughly two-thirds
// of the available height, while the lower leaf keeps the remaining third.
func shapeDemoWindows(s State) error {
	const topRowDelta = 0.33
	for _, slot := range []Slot{SlotShell, SlotFiles} {
		if err := focusWindow(s.Windows[slot]); err != nil {
			return fmt.Errorf("focus Demo %s for historical row sizing: %w", slot, err)
		}
		if err := adjustDwindleRatio(topRowDelta); err != nil {
			return fmt.Errorf("size Demo %s column: %w", slot, err)
		}
	}
	return nil
}

// arrangeDemoWindows builds the Demo's stable four-pane shape using
// Hyprland's native dwindle tree. The temporary named workspace is only a
// staging area for the existing windows; no window is floated, resized, or
// positioned with absolute coordinates. It is emptied immediately after the
// tree is rebuilt, so Hyprland removes it from the workspace list.
func arrangeDemoWindows(s State) error {
	if s.Workspace == "" {
		return fmt.Errorf("Demo has no target workspace")
	}
	if err := switchWorkspace(s.Workspace); err != nil {
		return err
	}
	const stagingWorkspace = "__omagen_demo_layout"
	for _, slot := range []Slot{SlotEditor, SlotBtop, SlotShell} {
		if err := placeWindow(s.Windows[slot], stagingWorkspace); err != nil {
			return fmt.Errorf("stage Demo %s window: %w", slot, err)
		}
	}

	if err := placeWindow(s.Windows[SlotEditor], s.Workspace); err != nil {
		return fmt.Errorf("place Demo editor root: %w", err)
	}
	if err := focusWindow(s.Windows[SlotEditor]); err != nil {
		return err
	}
	if err := preselectDwindle("r"); err != nil {
		return err
	}
	if err := placeWindow(s.Windows[SlotBtop], s.Workspace); err != nil {
		return fmt.Errorf("place Demo btop split: %w", err)
	}
	if err := focusWindow(s.Windows[SlotEditor]); err != nil {
		return err
	}
	// The previous absolute layout gave the editor column 48.5% of the
	// content width. Apply that small bias while the root split is still the
	// active two-leaf tree; subsequent preselection creates the two columns'
	// vertical children without losing the ratio.
	if err := adjustDwindleRatio(-0.030); err != nil {
		return fmt.Errorf("restore Demo horizontal bias: %w", err)
	}

	if err := preselectDwindle("d"); err != nil {
		return err
	}
	if err := placeWindow(s.Windows[SlotShell], s.Workspace); err != nil {
		return fmt.Errorf("place Demo shell split: %w", err)
	}

	if err := focusWindow(s.Windows[SlotBtop]); err != nil {
		return err
	}
	if err := preselectDwindle("d"); err != nil {
		return err
	}
	return nil
}

func closeWindow(address string) error {
	if address == "" {
		return nil
	}
	return hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.close({ window = %s })",
		luaString("address:"+address),
	))
}
func windowAddresses() (map[string]clientInfo, error) {
	current, err := clients()
	if err != nil {
		return nil, err
	}
	result := make(map[string]clientInfo, len(current))
	for _, c := range current {
		if c.Address != "" {
			result[c.Address] = c
		}
	}
	return result, nil
}
func survivingWindows(s State) (map[Slot]string, error) {
	current, err := windowAddresses()
	if err != nil {
		return nil, err
	}
	result := map[Slot]string{}
	for slot, address := range s.Windows {
		if address != "" {
			if _, ok := current[address]; ok {
				result[slot] = address
			}
		}
	}
	if s.OwnerToken != "" {
		discovered, discoverErr := discoverOwnedWindows(s.OwnerToken)
		if discoverErr == nil {
			for slot, address := range discovered {
				if result[slot] == "" {
					result[slot] = address
				}
			}
		}
	}
	return result, nil
}

func missingSlots(windows map[Slot]string) []Slot {
	var result []Slot
	for _, slot := range allDemoSlots() {
		if windows[slot] == "" {
			result = append(result, slot)
		}
	}
	return result
}

func mergeWindows(base, added map[Slot]string) map[Slot]string {
	result := make(map[Slot]string, 4)
	for slot, address := range base {
		if address != "" {
			result[slot] = address
		}
	}
	for slot, address := range added {
		if address != "" {
			result[slot] = address
		}
	}
	return result
}

// closeDemoWindows waits until Hyprland has confirmed every owned window is
// gone. Theme restoration must not overlap terminal window teardown: Omarchy's
// terminal hook sends reload signals to every Ghostty process.
func closeDemoWindows(addresses map[Slot]string, timeout time.Duration, logger *launchLogger) error {
	if logger != nil {
		logger.line("shutdown requested windows=%s timeout=%s", formatWindows(addresses), timeout)
	}
	var errs []error
	for _, slot := range []Slot{SlotEditor, SlotBtop, SlotShell, SlotFiles} {
		if err := closeWindow(addresses[slot]); err != nil {
			errs = append(errs, fmt.Errorf("close demo %s window: %w", slot, err))
		}
	}
	closed, err := waitUntilClosed(addresses, timeout)
	if err != nil {
		errs = append(errs, err)
	}
	if !closed {
		errs = append(errs, fmt.Errorf("timed out waiting for demo windows to close"))
	}
	if logger != nil {
		logger.line("shutdown finished closed=%t error=%v", closed, errors.Join(errs...))
	}
	return errors.Join(errs...)
}

func waitUntilClosed(addresses map[Slot]string, timeout time.Duration) (bool, error) {
	deadline := time.Now().Add(timeout)
	for {
		current, err := windowAddresses()
		if err != nil {
			return false, err
		}
		found := false
		for _, address := range addresses {
			if _, ok := current[address]; ok {
				found = true
				break
			}
		}
		if !found {
			return true, nil
		}
		if !time.Now().Before(deadline) {
			return false, nil
		}
		// Polling compositor state at 5Hz is ample for window teardown and avoids
		// adding pressure precisely while Hyprland is processing close requests.
		time.Sleep(200 * time.Millisecond)
	}
}

// placeDemoWindows only repairs workspace ownership. The Demo belongs to
// Hyprland's normal dwindle tree; forcing float/resize/move geometry here
// makes the Demo fight the compositor whenever an overlay is opened.
func placeDemoWindows(s State) error {
	current, err := windowAddresses()
	if err != nil {
		return err
	}
	for _, slot := range []Slot{SlotEditor, SlotBtop, SlotShell, SlotFiles} {
		address := s.Windows[slot]
		if address == "" {
			continue
		}
		if client, ok := current[address]; ok && client.Workspace.Name == s.Workspace {
			continue
		}
		if err := placeWindow(address, s.Workspace); err != nil {
			return err
		}
	}
	return nil
}
