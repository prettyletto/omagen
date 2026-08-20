package demo

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type CapabilitySource string

const (
	CapabilitySourceOmarchy  CapabilitySource = "omarchy"
	CapabilitySourceSystem   CapabilitySource = "system"
	CapabilitySourceFallback CapabilitySource = "fallback"
	CapabilitySourceNone     CapabilitySource = "none"
)

type ApplicationCapability struct {
	Command  string           `json:"command"`
	Source   CapabilitySource `json:"source"`
	Fallback bool             `json:"fallback"`
}

type EditorCapability struct {
	ApplicationCapability
	Kind string `json:"kind"`
}

type Capabilities struct {
	Terminal    ApplicationCapability `json:"terminal"`
	Editor      EditorCapability      `json:"editor"`
	Monitor     ApplicationCapability `json:"monitor"`
	FileManager ApplicationCapability `json:"file_manager"`
}

func ResolveCapabilities() Capabilities { return resolveCapabilities(defaultResolverEnvironment()) }

type resolverEnvironment struct {
	lookupPath func(string) (string, error)
	readFile   func(string) ([]byte, error)
	homeDir    func() (string, error)
	getenv     func(string) string
}

func defaultResolverEnvironment() resolverEnvironment {
	return resolverEnvironment{lookupPath: exec.LookPath, readFile: os.ReadFile, homeDir: os.UserHomeDir, getenv: os.Getenv}
}

func resolveCapabilities(env resolverEnvironment) Capabilities {
	return Capabilities{Terminal: resolveTerminal(env), Editor: resolveEditor(env), Monitor: resolveMonitor(env), FileManager: resolveFileManager(env)}
}

func resolveTerminal(env resolverEnvironment) ApplicationCapability {
	if commandAvailable(env, "omarchy-launch-tui") {
		return ApplicationCapability{Command: "omarchy-launch-tui", Source: CapabilitySourceOmarchy}
	}
	if commandAvailable(env, "xdg-terminal-exec") {
		return ApplicationCapability{Command: "xdg-terminal-exec", Source: CapabilitySourceSystem, Fallback: true}
	}
	for _, command := range []string{"ghostty", "kitty", "foot", "alacritty", "wezterm"} {
		if commandAvailable(env, command) {
			return ApplicationCapability{Command: command, Source: CapabilitySourceFallback, Fallback: true}
		}
	}
	return ApplicationCapability{Source: CapabilitySourceNone, Fallback: true}
}

func resolveEditor(env resolverEnvironment) EditorCapability {
	if env.getenv != nil {
		if editor := strings.TrimSpace(env.getenv("EDITOR")); editor != "" {
			fields := strings.Fields(editor)
			if len(fields) > 0 && commandAvailable(env, fields[0]) {
				return EditorCapability{ApplicationCapability: ApplicationCapability{Command: fields[0], Source: CapabilitySourceOmarchy}, Kind: editorKind(fields[0])}
			}
		}
	}
	if editor := readOmarchyEditor(env); editor != "" && commandAvailable(env, editor) {
		return EditorCapability{ApplicationCapability: ApplicationCapability{Command: editor, Source: CapabilitySourceOmarchy}, Kind: editorKind(editor)}
	}
	for _, editor := range []string{"nvim", "hx", "helix", "vim", "micro", "nano"} {
		if commandAvailable(env, editor) {
			return EditorCapability{ApplicationCapability: ApplicationCapability{Command: editor, Source: CapabilitySourceFallback, Fallback: true}, Kind: "tui"}
		}
	}
	for _, editor := range []string{"code", "codium", "zed", "kate", "subl"} {
		if commandAvailable(env, editor) {
			return EditorCapability{ApplicationCapability: ApplicationCapability{Command: editor, Source: CapabilitySourceFallback, Fallback: true}, Kind: "gui"}
		}
	}
	return EditorCapability{ApplicationCapability: ApplicationCapability{Source: CapabilitySourceNone, Fallback: true}, Kind: "none"}
}

func resolveMonitor(env resolverEnvironment) ApplicationCapability {
	for index, command := range []string{"btop", "htop", "top"} {
		if commandAvailable(env, command) {
			source := CapabilitySourceFallback
			if index == 0 {
				source = CapabilitySourceSystem
			}
			return ApplicationCapability{Command: command, Source: source, Fallback: index != 0}
		}
	}
	return ApplicationCapability{Source: CapabilitySourceNone, Fallback: true}
}

func resolveFileManager(env resolverEnvironment) ApplicationCapability {
	if commandAvailable(env, "nautilus") {
		return ApplicationCapability{Command: "nautilus", Source: CapabilitySourceOmarchy}
	}
	for _, command := range []string{"dolphin", "thunar", "nemo", "pcmanfm", "caja"} {
		if commandAvailable(env, command) {
			return ApplicationCapability{Command: command, Source: CapabilitySourceFallback, Fallback: true}
		}
	}
	if commandAvailable(env, "xdg-open") {
		return ApplicationCapability{Command: "xdg-open", Source: CapabilitySourceSystem, Fallback: true}
	}
	return ApplicationCapability{Source: CapabilitySourceNone, Fallback: true}
}

func readOmarchyEditor(env resolverEnvironment) string {
	home, err := env.homeDir()
	if err != nil {
		return ""
	}
	data, err := env.readFile(filepath.Join(home, ".local", "state", "omarchy", "defaults", "editor"))
	if err != nil {
		return ""
	}
	fields := strings.Fields(strings.TrimSpace(string(data)))
	if len(fields) == 0 {
		return ""
	}
	return fields[0]
}

func commandAvailable(env resolverEnvironment, command string) bool {
	if command == "" {
		return false
	}
	_, err := env.lookupPath(command)
	return err == nil
}

func editorKind(command string) string {
	switch strings.ToLower(filepath.Base(command)) {
	case "nvim", "vim", "nano", "micro", "hx", "helix", "fresh":
		return "tui"
	default:
		return "gui"
	}
}
