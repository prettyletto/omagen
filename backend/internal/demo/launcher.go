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

type slotLaunch struct {
	Slot Slot
	Cmd  *exec.Cmd
}

type processExit struct {
	slot Slot
	err  error
}

func launchDemoApps(demoDir string, before map[string]clientInfo, logger *launchLogger) (map[Slot]string, error) {
	launches, hints, err := buildDemoLaunches(demoDir, ResolveCapabilities())
	if err != nil {
		return nil, err
	}
	terminalExits := make(chan processExit, 4)
	hints.terminalExits = terminalExits
	for _, launch := range launches {
		if launch.Cmd == nil {
			return nil, fmt.Errorf("no launcher for demo slot %s", launch.Slot)
		}
		resolved, lookErr := exec.LookPath(launch.Cmd.Path)
		if lookErr != nil {
			resolved = "<not found: " + lookErr.Error() + ">"
		}
		logger.line("launch slot=%s path=%q resolved=%q args=%q dir=%q env_OMAGEN_DEMO_DIR=%q", launch.Slot, launch.Cmd.Path, resolved, launch.Cmd.Args, launch.Cmd.Dir, envValue(launch.Cmd.Env, "OMAGEN_DEMO_DIR"))
		var stdout, stderr bytes.Buffer
		launch.Cmd.Stdout = &stdout
		launch.Cmd.Stderr = &stderr
		if err := launch.Cmd.Start(); err != nil {
			logger.line("start slot=%s error=%v stdout=%q stderr=%q", launch.Slot, err, stdout.String(), stderr.String())
			return nil, fmt.Errorf("start demo %s: %w", launch.Slot, err)
		}
		hints.PIDs[launch.Slot] = launch.Cmd.Process.Pid
		logger.line("started slot=%s pid=%d", launch.Slot, launch.Cmd.Process.Pid)
		go func(slot Slot, cmd *exec.Cmd, out, errOut *bytes.Buffer) {
			err := cmd.Wait()
			logger.line("exit slot=%s pid=%d error=%v stdout=%q stderr=%q", slot, cmd.Process.Pid, err, out.String(), errOut.String())
			if isTerminalSlot(slot) && exitedFromTerminalReload(err) {
				terminalExits <- processExit{slot: slot, err: err}
			}
		}(launch.Slot, launch.Cmd, &stdout, &stderr)
	}
	return waitForDemoWindows(before, hints, 10*time.Second, logger)
}

func buildDemoLaunches(demoDir string, capabilities Capabilities) ([]slotLaunch, launchHints, error) {
	if capabilities.Terminal.Command == "" {
		return nil, launchHints{}, fmt.Errorf("demo requires a terminal capability")
	}
	editor, editorName := buildEditorCommand(demoDir, capabilities)
	monitor := buildMonitorCommand(demoDir, capabilities)
	shell := buildShellCommand(demoDir, capabilities)
	files := buildFilesCommand(demoDir, capabilities)
	launches := []slotLaunch{{Slot: SlotEditor, Cmd: editor}, {Slot: SlotBtop, Cmd: monitor}, {Slot: SlotShell, Cmd: shell}, {Slot: SlotFiles, Cmd: files}}
	for _, launch := range launches {
		if launch.Cmd == nil {
			return nil, launchHints{}, fmt.Errorf("no launcher for demo slot %s", launch.Slot)
		}
	}
	return launches, launchHints{PIDs: map[Slot]int{}, EditorName: editorName}, nil
}

func isTerminalSlot(slot Slot) bool {
	return slot == SlotEditor || slot == SlotBtop || slot == SlotShell || slot == SlotFiles
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
func buildEditorCommand(demoDir string, capabilities Capabilities) (*exec.Cmd, string) {
	sample := filepath.Join(demoDir, "sample.go")
	if capabilities.Editor.Command == "" {
		return terminalCommand(capabilities.Terminal, "org.omagen.demo.editor", demoDir, "/bin/bash", "-lc", sourceViewerScript(sample)), ""
	}
	if capabilities.Editor.Kind == "tui" {
		return terminalCommand(capabilities.Terminal, "org.omagen.demo.editor", demoDir, capabilities.Editor.Command, sample), capabilities.Editor.Command
	}
	cmd := exec.Command(capabilities.Editor.Command, sample)
	cmd.Dir = demoDir
	return cmd, capabilities.Editor.Command
}
func buildMonitorCommand(dir string, capabilities Capabilities) *exec.Cmd {
	if capabilities.Monitor.Command != "" {
		return terminalCommand(capabilities.Terminal, "org.omagen.demo.btop", dir, capabilities.Monitor.Command)
	}
	return terminalCommand(capabilities.Terminal, "org.omagen.demo.btop", dir, "/bin/bash", "-lc", systemInfoScript())
}
func buildShellCommand(dir string, capabilities Capabilities) *exec.Cmd {
	script := `cd "$OMAGEN_DEMO_DIR" || exit 1
printf '\033[1mOmagen demo\033[0m\n\n'
if command -v lsd >/dev/null 2>&1; then lsd -la; else ls -la; fi
printf '\n'
exec "${SHELL:-/bin/bash}" -l
`
	cmd := terminalCommand(capabilities.Terminal, "org.omagen.demo.shell", dir, "/bin/bash", "-lc", script)
	return cmd
}
func buildFilesCommand(dir string, capabilities Capabilities) *exec.Cmd {
	if capabilities.FileManager.Command != "" {
		if capabilities.FileManager.Command == "xdg-open" {
			cmd := exec.Command(capabilities.FileManager.Command, dir)
			cmd.Dir = dir
			return cmd
		}
		cmd := exec.Command(capabilities.FileManager.Command, "--new-window", dir)
		cmd.Dir = dir
		return cmd
	}
	return terminalCommand(capabilities.Terminal, "org.omagen.demo.files", dir, "/bin/bash", "-lc", fileListingScript())
}

func terminalCommand(capability ApplicationCapability, appID, dir string, command string, args ...string) *exec.Cmd {
	var cmd *exec.Cmd
	switch capability.Command {
	case "omarchy-launch-tui":
		cmd = exec.Command(capability.Command, append([]string{"--app-id=" + appID, command}, args...)...)
	case "xdg-terminal-exec":
		cmd = exec.Command(capability.Command, append([]string{"--app-id=" + appID, "-e", command}, args...)...)
	default:
		cmd = exec.Command(capability.Command, append([]string{"-e", command}, args...)...)
	}
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "OMAGEN_DEMO_DIR="+dir)
	return cmd
}

func sourceViewerScript(sample string) string {
	return fmt.Sprintf("if command -v bat >/dev/null 2>&1; then bat --style=numbers %q; elif command -v less >/dev/null 2>&1; then sed -n '1,120p' %q | less; else sed -n '1,120p' %q; fi\nprintf '\\n'\nexec \"${SHELL:-/bin/bash}\" -l", sample, sample, sample)
}
func systemInfoScript() string {
	return "printf 'SYSTEM\\n\\n'; uptime; printf '\\nMEMORY\\n'; free -h; printf '\\nDISK\\n'; df -h /; printf '\\nPROCESSES\\n'; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -12; exec \"${SHELL:-/bin/bash}\" -l"
}
func fileListingScript() string {
	return "cd \"$OMAGEN_DEMO_DIR\" || exit 1; if command -v tree >/dev/null 2>&1; then tree -a -L 2; elif command -v find >/dev/null 2>&1; then find . -maxdepth 2 -print; else ls -la; fi; printf '\\n'; exec \"${SHELL:-/bin/bash}\" -l"
}
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
