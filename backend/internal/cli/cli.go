package cli

import (
	"fmt"
	"io"
)

type pingResponse struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

const BackendVersion = "1.0.0"

// Run is the CLI composition root. Command implementations live in the
// domain-named files in this package; durable behavior remains in backend
// domain packages.
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing command")
	}

	deps, err := newDependencies(stderr)
	if err != nil {
		return fail(stderr, 1, "%v", err)
	}

	switch args[0] {
	case "--help", "-h", "help":
		_, _ = fmt.Fprintln(stdout, "omagen: image-based Omarchy theme generator")
		_, _ = fmt.Fprintln(stdout, "commands: session, preview, apply, generate, generation, demo, cleanup, settings, bar, look-feel, theme, terminal, runtime, ping")
		return 0
	case "ping":
		return writeJSON(stdout, stderr, pingResponse{OK: true, Version: BackendVersion})
	case "session":
		return runSessionWithDependencies(args[1:], deps.sessionService, deps.previewService, deps.applyService, deps.cleanupService, deps.demoService, deps.generationService, stdout, stderr)
	case "preview":
		return runPreview(args[1:], deps.previewService, stdout, stderr)
	case "apply":
		return runApply(args[1:], deps.applyService, stdout, stderr)
	case "cleanup":
		return runCleanup(args[1:], deps.cleanupService, stdout, stderr)
	case "generate":
		return runGenerate(args[1:], deps.generationService, stdout, stderr)
	case "generation":
		return runGeneration(args[1:], deps.generationService, stdout, stderr)
	case "demo":
		return runDemo(args[1:], deps.demoService, stdout, stderr)
	case "settings":
		return runSettings(args[1:], deps.settingsStore, stdout, stderr)
	case "bar":
		return runBar(args[1:], deps.barStore, deps.omarchyClient, stdout, stderr)
	case "look-feel":
		return runLookFeel(args[1:], stdout, stderr)
	case "theme":
		return runTheme(args[1:], deps.themeEditService, stdout, stderr)
	case "terminal":
		return runTerminal(args[1:], stdout, stderr)
	case "runtime":
		return runRuntime(args[1:], stdout, stderr)
	default:
		return fail(stderr, 2, "unknown command: %s", args[0])
	}
}
