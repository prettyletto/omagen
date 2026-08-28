package cli

import (
	"io"

	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
)

func runSettings(args []string, store *settingspkg.Store, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing settings subcommand")
	}
	switch args[0] {
	case "get":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen settings get")
		}
		current, err := store.Load()
		if err != nil {
			return fail(stderr, 1, "load settings: %v", err)
		}
		return writeJSON(stdout, stderr, current)
	case "set":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen settings set '<json>'")
		}
		updated, err := store.UpdateJSON([]byte(args[1]))
		if err != nil {
			return fail(stderr, 1, "update settings: %v", err)
		}
		return writeJSON(stdout, stderr, updated)
	case "reset":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen settings reset")
		}
		defaults, err := store.Reset()
		if err != nil {
			return fail(stderr, 1, "reset settings: %v", err)
		}
		return writeJSON(stdout, stderr, defaults)
	default:
		return fail(stderr, 2, "unknown settings subcommand: %s", args[0])
	}
}
