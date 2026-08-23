package demo

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildDemoLaunchesUsesResolvedPreferredApplications(t *testing.T) {
	capabilities := Capabilities{
		Terminal:    ApplicationCapability{Command: "omarchy-launch-tui", Source: CapabilitySourceOmarchy},
		Editor:      EditorCapability{ApplicationCapability: ApplicationCapability{Command: "nvim", Source: CapabilitySourceOmarchy}, Kind: "tui"},
		Monitor:     ApplicationCapability{Command: "btop", Source: CapabilitySourceSystem},
		FileManager: ApplicationCapability{Command: "nautilus", Source: CapabilitySourceOmarchy},
	}
	launches, _, err := buildDemoLaunches("/tmp/demo-scene", capabilities)
	if err != nil {
		t.Fatal(err)
	}
	if len(launches) != 4 {
		t.Fatalf("launch count = %d, want 4", len(launches))
	}
	if !strings.Contains(strings.Join(launches[0].Cmd.Args, " "), "nvim") {
		t.Fatalf("editor args = %q", launches[0].Cmd.Args)
	}
	if !strings.Contains(strings.Join(launches[1].Cmd.Args, " "), "btop") {
		t.Fatalf("monitor args = %q", launches[1].Cmd.Args)
	}
	if filepath.Base(launches[3].Cmd.Path) != "uwsm-app" && filepath.Base(launches[3].Cmd.Path) != "nautilus" {
		t.Fatalf("file manager path = %q", launches[3].Cmd.Path)
	}
	if filepath.Base(launches[3].Cmd.Path) == "uwsm-app" && strings.Join(launches[3].Cmd.Args, " ") != launches[3].Cmd.Path+" -- nautilus --new-window /tmp/demo-scene" {
		t.Fatalf("uwsm file manager args = %q", launches[3].Cmd.Args)
	}
	if !strings.Contains(strings.Join(launches[2].Cmd.Args, " "), "lsd -la") || !strings.Contains(strings.Join(launches[2].Cmd.Args, " "), "ls -la") {
		t.Fatalf("shell args do not prefer lsd with ls fallback: %q", launches[2].Cmd.Args)
	}
}

func TestBuildDemoLaunchesDegradesMissingSlotsToTerminal(t *testing.T) {
	capabilities := Capabilities{
		Terminal:    ApplicationCapability{Command: "omarchy-launch-tui", Source: CapabilitySourceOmarchy},
		Editor:      EditorCapability{ApplicationCapability: ApplicationCapability{Source: CapabilitySourceNone, Fallback: true}, Kind: "none"},
		Monitor:     ApplicationCapability{Source: CapabilitySourceNone, Fallback: true},
		FileManager: ApplicationCapability{Source: CapabilitySourceNone, Fallback: true},
	}
	launches, _, err := buildDemoLaunches("/tmp/demo-scene", capabilities)
	if err != nil {
		t.Fatal(err)
	}
	if len(launches) != 4 {
		t.Fatalf("launch count = %d, want 4", len(launches))
	}
	for _, launch := range launches {
		if filepath.Base(launch.Cmd.Path) != "omarchy-launch-tui" {
			t.Errorf("%s path = %q, want terminal launcher", launch.Slot, launch.Cmd.Path)
		}
	}
	args := strings.Join(launches[0].Cmd.Args, " ")
	if !strings.Contains(args, "bat") || !strings.Contains(args, "sed -n") {
		t.Errorf("editor fallback args = %q", args)
	}
	monitorArgs := strings.Join(launches[1].Cmd.Args, " ")
	if !strings.Contains(monitorArgs, "uptime") || !strings.Contains(monitorArgs, "free -h") || !strings.Contains(monitorArgs, "df -h") {
		t.Errorf("monitor fallback args = %q", monitorArgs)
	}
	fileArgs := strings.Join(launches[3].Cmd.Args, " ")
	if !strings.Contains(fileArgs, "tree -a -L 2") || !strings.Contains(fileArgs, "find . -maxdepth 2") || !strings.Contains(fileArgs, "ls -la") {
		t.Errorf("file fallback args = %q", fileArgs)
	}
}

func TestBuildDemoLaunchesRequiresTerminal(t *testing.T) {
	_, _, err := buildDemoLaunches("/tmp/demo-scene", Capabilities{})
	if err == nil {
		t.Fatal("expected missing terminal error")
	}
}

func TestDemoAppIDIsSessionSpecific(t *testing.T) {
	if got := demoAppID("abc123", SlotEditor); got != "org.omagen.demo.abc123.editor" {
		t.Fatalf("app id = %q", got)
	}
	if matchesOwnedSlot(clientInfo{Class: "org.omagen.demo.other.editor"}, "abc123", SlotEditor) {
		t.Fatal("accepted another session's window")
	}
	if !matchesOwnedSlot(clientInfo{InitialClass: "org.omagen.demo.abc123.editor"}, "abc123", SlotEditor) {
		t.Fatal("did not accept exact initial class")
	}
}

func TestMissingSlotsAndMergeWindows(t *testing.T) {
	base := map[Slot]string{SlotEditor: "editor-address", SlotShell: "shell-address"}
	missing := missingSlots(base)
	if len(missing) != 2 || missing[0] != SlotBtop || missing[1] != SlotFiles {
		t.Fatalf("missing slots = %#v", missing)
	}
	merged := mergeWindows(base, map[Slot]string{SlotBtop: "btop-address", SlotFiles: "files-address"})
	if len(merged) != 4 || merged[SlotEditor] != "editor-address" || merged[SlotFiles] != "files-address" {
		t.Fatalf("merged windows = %#v", merged)
	}
}
