package demo

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

type launchHints struct {
	PIDs          map[Slot]int
	EditorName    string
	terminalExits <-chan processExit
}

type processExit struct {
	slot Slot
	err  error
}

func launchDemoApps(demoDir string, before map[string]clientInfo, logger *launchLogger) (map[Slot]string, error) {
	editorName, editor := editorCommand(demoDir)
	launches := []struct {
		slot Slot
		cmd  *exec.Cmd
	}{
		{SlotEditor, editor}, {SlotBtop, btopCommand(demoDir)}, {SlotShell, shellCommand(demoDir)}, {SlotFiles, filesCommand(demoDir)},
	}
	terminalExits := make(chan processExit, 3)
	hints := launchHints{PIDs: map[Slot]int{}, EditorName: editorName, terminalExits: terminalExits}
	for _, launch := range launches {
		if launch.cmd == nil {
			return nil, fmt.Errorf("no launcher for demo slot %s", launch.slot)
		}
		resolved, lookErr := exec.LookPath(launch.cmd.Path)
		if lookErr != nil {
			resolved = "<not found: " + lookErr.Error() + ">"
		}
		logger.line("launch slot=%s path=%q resolved=%q args=%q dir=%q env_OMAGEN_DEMO_DIR=%q", launch.slot, launch.cmd.Path, resolved, launch.cmd.Args, launch.cmd.Dir, envValue(launch.cmd.Env, "OMAGEN_DEMO_DIR"))
		var stdout, stderr bytes.Buffer
		launch.cmd.Stdout = &stdout
		launch.cmd.Stderr = &stderr
		if err := launch.cmd.Start(); err != nil {
			logger.line("start slot=%s error=%v stdout=%q stderr=%q", launch.slot, err, stdout.String(), stderr.String())
			return nil, fmt.Errorf("start demo %s: %w", launch.slot, err)
		}
		hints.PIDs[launch.slot] = launch.cmd.Process.Pid
		logger.line("started slot=%s pid=%d", launch.slot, launch.cmd.Process.Pid)
		go func(slot Slot, cmd *exec.Cmd, out, errOut *bytes.Buffer) {
			err := cmd.Wait()
			logger.line("exit slot=%s pid=%d error=%v stdout=%q stderr=%q", slot, cmd.Process.Pid, err, out.String(), errOut.String())
			if isTerminalSlot(slot) && exitedFromTerminalReload(err) {
				terminalExits <- processExit{slot: slot, err: err}
			}
		}(launch.slot, launch.cmd, &stdout, &stderr)
	}
	return waitForDemoWindows(before, hints, 10*time.Second, logger)
}

func isTerminalSlot(slot Slot) bool {
	return slot == SlotEditor || slot == SlotBtop || slot == SlotShell
}

func exitedFromTerminalReload(err error) bool {
	var exitErr *exec.ExitError
	if !errors.As(err, &exitErr) {
		return false
	}
	status, ok := exitErr.Sys().(syscall.WaitStatus)
	return ok && status.Signaled() && status.Signal() == syscall.SIGUSR2
}

func envValue(env []string, key string) string {
	prefix := key + "="
	for _, value := range env {
		if strings.HasPrefix(value, prefix) {
			return strings.TrimPrefix(value, prefix)
		}
	}
	return ""
}
func editorCommand(demoDir string) (string, *exec.Cmd) {
	sample := filepath.Join(demoDir, "sample.go")
	editor := configuredEditor()
	if isTUIEditor(editor) {
		cmd := exec.Command("omarchy-launch-tui", "--app-id=org.omagen.demo.editor", editor, sample)
		cmd.Dir = demoDir
		return filepath.Base(editor), cmd
	}
	// GUI editors still go through Omarchy's editor launcher so its configured
	// default and desktop integration remain authoritative.
	cmd := exec.Command("omarchy-launch-editor", sample)
	cmd.Dir = demoDir
	return "omarchy-launch-editor", cmd
}
func configuredEditor() string {
	home, err := os.UserHomeDir()
	if err == nil {
		data, err := os.ReadFile(filepath.Join(home, ".local", "state", "omarchy", "defaults", "editor"))
		if err == nil {
			fields := strings.Fields(strings.TrimSpace(string(data)))
			if len(fields) > 0 {
				if path, lookErr := exec.LookPath(fields[0]); lookErr == nil {
					return path
				}
			}
		}
	}
	if path, err := exec.LookPath("nvim"); err == nil {
		return path
	}
	return "nvim"
}
func isTUIEditor(editor string) bool {
	switch strings.ToLower(filepath.Base(editor)) {
	case "nvim", "vim", "nano", "micro", "hx", "helix", "fresh":
		return true
	}
	return false
}
func btopCommand(dir string) *exec.Cmd {
	cmd := exec.Command("omarchy-launch-tui", "--app-id=org.omagen.demo.btop", firstPresent("btop", "htop", "top"))
	cmd.Dir = dir
	return cmd
}
func shellCommand(dir string) *exec.Cmd {
	script := `cd "$OMAGEN_DEMO_DIR" || exit 1
printf '\033[1mOmagen demo\033[0m\n\n'
ls -la --color=always
printf '\n'
exec "${SHELL:-/bin/bash}" -l
`
	cmd := exec.Command("omarchy-launch-tui", "--app-id=org.omagen.demo.shell", "/bin/bash", "-lc", script)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "OMAGEN_DEMO_DIR="+dir)
	return cmd
}
func filesCommand(dir string) *exec.Cmd {
	if commandExists("nautilus") {
		cmd := exec.Command("nautilus", "--new-window", dir)
		cmd.Dir = dir
		return cmd
	}
	cmd := exec.Command("xdg-open", dir)
	cmd.Dir = dir
	return cmd
}
func firstPresent(commands ...string) string {
	for _, c := range commands {
		if path, err := exec.LookPath(c); err == nil {
			return path
		}
	}
	return "top"
}
func commandExists(command string) bool { _, err := exec.LookPath(command); return err == nil }
func waitForDemoWindows(before map[string]clientInfo, hints launchHints, timeout time.Duration, logger *launchLogger) (map[Slot]string, error) {
	deadline := time.Now().Add(timeout)
	var last []clientInfo
	lastCount := -1
	lastClassification := ""
	for time.Now().Before(deadline) {
		current, err := clients()
		if err != nil {
			logger.line("client snapshot error=%v", err)
			return nil, err
		}
		fresh := []clientInfo{}
		for _, c := range current {
			if c.Address != "" {
				if _, ok := before[c.Address]; !ok {
					fresh = append(fresh, c)
				}
			}
		}
		last = fresh
		windows := classifyDemoWindows(fresh, hints)
		if exit := terminalReloadExit(hints, windows); exit != nil {
			logger.line("terminal launch interrupted before window classification: slot=%s error=%v", exit.slot, exit.err)
			return windows, fmt.Errorf("demo %s terminal was interrupted by Omarchy terminal reload", exit.slot)
		}
		classification := formatWindows(windows)
		if len(fresh) != lastCount || classification != lastClassification {
			logger.jsonLine("client snapshot", current)
			logger.jsonLine("new clients", fresh)
			logger.line("classification fresh=%d slots=%s", len(fresh), classification)
			lastCount = len(fresh)
			lastClassification = classification
		}
		if len(windows) == 4 {
			logger.line("all demo windows classified: %s", classification)
			return windows, nil
		}
		time.Sleep(75 * time.Millisecond)
	}
	windows := classifyDemoWindows(last, hints)
	logger.jsonLine("timeout final clients", last)
	logger.line("timeout classification fresh=%d slots=%s", len(last), formatWindows(windows))
	return windows, fmt.Errorf("timed out waiting for demo windows; saw %d new window(s)", len(last))
}

func terminalReloadExit(hints launchHints, windows map[Slot]string) *processExit {
	for {
		select {
		case exit := <-hints.terminalExits:
			if windows[exit.slot] == "" {
				return &exit
			}
		default:
			return nil
		}
	}
}

func formatWindows(windows map[Slot]string) string {
	return fmt.Sprintf("editor=%q btop=%q shell=%q files=%q", windows[SlotEditor], windows[SlotBtop], windows[SlotShell], windows[SlotFiles])
}
func classifyDemoWindows(clients []clientInfo, hints launchHints) map[Slot]string {
	result := map[Slot]string{}
	used := map[string]bool{}
	assign := func(slot Slot, c clientInfo) {
		if result[slot] == "" && c.Address != "" && !used[c.Address] {
			result[slot] = c.Address
			used[c.Address] = true
		}
	}
	for _, c := range clients {
		for slot, pid := range hints.PIDs {
			if pid > 0 && c.PID == pid {
				assign(slot, c)
			}
		}
	}
	for _, c := range clients {
		if used[c.Address] {
			continue
		}
		text := strings.ToLower(strings.Join([]string{c.Class, c.InitialClass, c.Title, c.InitialTitle}, " "))
		switch {
		case strings.Contains(text, "org.omagen.demo.btop"):
			assign(SlotBtop, c)
		case strings.Contains(text, "org.omagen.demo.shell"):
			assign(SlotShell, c)
		case strings.Contains(text, "org.omagen.demo.editor"):
			assign(SlotEditor, c)
		}
	}
	for _, c := range clients {
		if !used[c.Address] && isFileManagerClient(c) {
			assign(SlotFiles, c)
		}
	}
	for _, c := range clients {
		if !used[c.Address] && isEditorClient(c, hints.EditorName) {
			assign(SlotEditor, c)
		}
	}
	leftovers := []clientInfo{}
	for _, c := range clients {
		if !used[c.Address] {
			leftovers = append(leftovers, c)
		}
	}
	sort.Slice(leftovers, func(i, j int) bool { return leftovers[i].Address < leftovers[j].Address })
	if result[SlotFiles] == "" && len(leftovers) == 1 {
		assign(SlotFiles, leftovers[0])
	}
	return result
}
func isFileManagerClient(c clientInfo) bool {
	text := strings.ToLower(c.Class + " " + c.InitialClass)
	for _, token := range []string{"nautilus", "dolphin", "thunar", "nemo", "pcmanfm", "caja"} {
		if strings.Contains(text, token) {
			return true
		}
	}
	return false
}
func isEditorClient(c clientInfo, editor string) bool {
	hint := strings.ToLower(filepath.Base(editor))
	if hint == "" {
		return false
	}
	text := strings.ToLower(strings.Join([]string{c.Class, c.InitialClass, c.Title, c.InitialTitle}, " "))
	switch hint {
	case "code-insiders":
		hint = "code"
	case "vscodium":
		hint = "codium"
	case "sublime_text":
		hint = "sublime"
	}
	return strings.Contains(text, hint) || strings.Contains(strings.ToLower(c.Title), "sample.go")
}
