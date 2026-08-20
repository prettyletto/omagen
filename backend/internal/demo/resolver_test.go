package demo

import (
	"errors"
	"testing"
)

func TestResolveCapabilitiesPreferredOmarchySetup(t *testing.T) {
	t.Parallel()
	env := fakeResolverEnvironment(map[string]bool{"omarchy-launch-tui": true, "nvim": true, "btop": true, "nautilus": true}, "nvim\n")
	got := resolveCapabilities(env)
	if got.Terminal.Command != "omarchy-launch-tui" || got.Terminal.Fallback {
		t.Fatalf("terminal = %#v", got.Terminal)
	}
	if got.Editor.Command != "nvim" || got.Editor.Kind != "tui" || got.Editor.Fallback {
		t.Fatalf("editor = %#v", got.Editor)
	}
	if got.Monitor.Command != "btop" || got.FileManager.Command != "nautilus" {
		t.Fatalf("capabilities = %#v", got)
	}
}

func TestResolveCapabilitiesFallsBack(t *testing.T) {
	t.Parallel()
	env := fakeResolverEnvironment(map[string]bool{"xdg-terminal-exec": true, "hx": true, "htop": true, "dolphin": true}, "missing-editor\n")
	got := resolveCapabilities(env)
	if got.Terminal.Command != "xdg-terminal-exec" || !got.Terminal.Fallback {
		t.Fatalf("terminal = %#v", got.Terminal)
	}
	if got.Editor.Command != "hx" || got.Editor.Kind != "tui" || !got.Editor.Fallback {
		t.Fatalf("editor = %#v", got.Editor)
	}
	if got.Monitor.Command != "htop" || !got.Monitor.Fallback {
		t.Fatalf("monitor = %#v", got.Monitor)
	}
	if got.FileManager.Command != "dolphin" || !got.FileManager.Fallback {
		t.Fatalf("file manager = %#v", got.FileManager)
	}
}

func TestResolveCapabilitiesMissingOptionalApplications(t *testing.T) {
	t.Parallel()
	env := fakeResolverEnvironment(map[string]bool{"ghostty": true, "vim": true, "top": true}, "")
	got := resolveCapabilities(env)
	if got.Terminal.Command != "ghostty" || got.Editor.Command != "vim" || got.Monitor.Command != "top" {
		t.Fatalf("capabilities = %#v", got)
	}
	if got.FileManager.Command != "" || got.FileManager.Source != CapabilitySourceNone {
		t.Fatalf("file manager = %#v", got.FileManager)
	}
}

func TestResolveCapabilitiesConfiguredGUIEditor(t *testing.T) {
	t.Parallel()
	env := fakeResolverEnvironment(map[string]bool{"omarchy-launch-tui": true, "code": true, "btop": true, "nautilus": true}, "code\n")
	got := resolveCapabilities(env)
	if got.Editor.Command != "code" || got.Editor.Kind != "gui" || got.Editor.Fallback {
		t.Fatalf("editor = %#v", got.Editor)
	}
}

func TestResolveCapabilitiesUsesConfiguredEditorEnvironment(t *testing.T) {
	t.Parallel()
	env := fakeResolverEnvironment(map[string]bool{"omarchy-launch-tui": true, "nvim": true, "btop": true, "nautilus": true}, "")
	env.getenv = func(name string) string {
		if name == "EDITOR" {
			return "nvim"
		}
		return ""
	}
	got := resolveCapabilities(env)
	if got.Editor.Command != "nvim" || got.Editor.Source != CapabilitySourceOmarchy || got.Editor.Fallback {
		t.Fatalf("editor = %#v", got.Editor)
	}
}

func fakeResolverEnvironment(commands map[string]bool, editorFile string) resolverEnvironment {
	return resolverEnvironment{
		lookupPath: func(command string) (string, error) {
			if commands[command] {
				return "/usr/bin/" + command, nil
			}
			return "", errors.New("not found")
		},
		readFile: func(string) ([]byte, error) {
			if editorFile == "" {
				return nil, errors.New("missing")
			}
			return []byte(editorFile), nil
		},
		homeDir: func() (string, error) { return "/home/test", nil },
		getenv:  func(string) string { return "" },
	}
}
