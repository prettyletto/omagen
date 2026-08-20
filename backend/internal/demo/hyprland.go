package demo

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
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
type rect struct{ X, Y, W, H int }
type demoRects struct{ Editor, Btop, Shell, Files rect }

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
func placeWindow(address, workspace string, target rect) error {
	if address == "" {
		return fmt.Errorf("cannot place empty window address")
	}
	selector := luaString("address:" + address)
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.move({ workspace = %s, follow = false, window = %s })",
		luaString("name:"+workspace), selector,
	)); err != nil {
		return fmt.Errorf("move demo window %s to workspace: %w", address, err)
	}
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.float({ action = \"set\", window = %s })", selector,
	)); err != nil {
		return fmt.Errorf("float demo window %s: %w", address, err)
	}
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.resize({ x = %d, y = %d, relative = false, window = %s })",
		target.W, target.H, selector,
	)); err != nil {
		return fmt.Errorf("resize demo window %s: %w", address, err)
	}
	if err := hyprLuaDispatch(fmt.Sprintf(
		"hl.dsp.window.move({ x = %d, y = %d, relative = false, window = %s })",
		target.X, target.Y, selector,
	)); err != nil {
		return fmt.Errorf("position demo window %s: %w", address, err)
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
func allOwnedWindowsExist(s State) bool {
	windows, err := survivingWindows(s)
	return err == nil && len(missingSlots(windows)) == 0
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
func layoutForMonitor(m monitorInfo) demoRects {
	scale := m.Scale
	if scale <= 0 {
		scale = 1
	}
	w := int(math.Round(float64(m.Width) / scale))
	h := int(math.Round(float64(m.Height) / scale))
	if m.Transform == 1 || m.Transform == 3 || m.Transform == 5 || m.Transform == 7 {
		w, h = h, w
	}
	const outerSide, outerTop, outerBottom, gap = 12, 8, 12, 14
	left := m.Reserved[0]
	top := m.Reserved[1]
	right := m.Reserved[2]
	bottom := m.Reserved[3]
	x, y := m.X+left+outerSide, m.Y+top+outerTop
	contentW := w - left - right - (outerSide * 2) - gap
	contentH := h - top - bottom - outerTop - outerBottom - gap
	if contentW+gap < 640 {
		contentW = 640 - gap
	}
	if contentH+gap < 480 {
		contentH = 480 - gap
	}
	lw := int(math.Round(float64(contentW) * 0.485))
	rw := contentW - lw
	th := int(math.Round(float64(contentH) * 0.665))
	bh := contentH - th
	return demoRects{Editor: rect{x, y, lw, th}, Btop: rect{x + lw + gap, y, rw, th}, Shell: rect{x, y + th + gap, lw, bh}, Files: rect{x + lw + gap, y + th + gap, rw, bh}}
}
func placeDemoWindows(s State, m monitorInfo) error {
	r := layoutForMonitor(m)
	placements := map[Slot]rect{SlotEditor: r.Editor, SlotBtop: r.Btop, SlotShell: r.Shell, SlotFiles: r.Files}
	for _, slot := range []Slot{SlotEditor, SlotBtop, SlotShell, SlotFiles} {
		if err := placeWindow(s.Windows[slot], s.Workspace, placements[slot]); err != nil {
			return err
		}
	}
	return nil
}
