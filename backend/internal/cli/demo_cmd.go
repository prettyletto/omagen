package cli

import (
	"io"

	"github.com/prettyletto/omagen/backend/internal/demo"
)

func runDemo(args []string, service *demo.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing demo subcommand")
	}
	switch args[0] {
	case "capabilities":
		if len(args) != 1 {
			return fail(stderr, 2, "demo capabilities takes no arguments")
		}
		return writeJSON(stdout, stderr, demo.ResolveCapabilities())
	case "open":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen demo open <session_id>")
		}
		result, err := service.Open(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "open-window":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen demo open-window <session_id>")
		}
		result, err := service.OpenWindow(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "open-reader":
		if len(args) != 3 {
			return fail(stderr, 2, "usage: omagen demo open-reader <session_id> <shell|bar>")
		}
		if args[2] != demo.ModeShell && args[2] != demo.ModeBar {
			return fail(stderr, 2, "unsupported reader Demo mode: %s", args[2])
		}
		result, err := service.OpenReader(args[1], args[2])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "close":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen demo close <session_id>")
		}
		result, err := service.Close(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "reflow":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen demo reflow <session_id>")
		}
		if err := service.Reflow(args[1]); err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, map[string]any{"ok": true, "session_id": args[1]})
	case "capture":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen demo capture <session_id>")
		}
		result, err := service.CapturePreview(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	default:
		return fail(stderr, 2, "unknown demo subcommand: %s", args[0])
	}
}
