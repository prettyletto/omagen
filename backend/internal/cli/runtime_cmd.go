package cli

import (
	"io"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/runtime"
)

func runRuntime(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen runtime {status|install|dismiss|theme-set <theme>}")
	}
	switch args[0] {
	case "status":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen runtime status")
		}
		themeRoot, themeName, err := runtime.ActiveThemePaths()
		if err != nil {
			home, homeErr := os.UserHomeDir()
			if homeErr != nil {
				return fail(stderr, 1, "inspect advanced runtime: %v", err)
			}
			themeRoot = filepath.Join(home, ".local", "state", "omarchy", "current", "theme")
			themeName = ""
		}
		status, err := runtime.InspectStatus(themeRoot, themeName)
		if err != nil {
			return fail(stderr, 1, "inspect advanced runtime: %v", err)
		}
		return writeJSON(stdout, stderr, status)
	case "install":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen runtime install")
		}
		result, err := runtime.Install()
		if err != nil {
			return fail(stderr, 1, "install advanced runtime: %v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "dismiss":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen runtime dismiss")
		}
		if err := runtime.DismissPrompt(); err != nil {
			return fail(stderr, 1, "dismiss advanced runtime setup: %v", err)
		}
		return writeJSON(stdout, stderr, map[string]bool{"prompted": true})
	case "theme-set":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen runtime theme-set <theme>")
		}
		themeRoot, activeTheme, err := runtime.ActiveThemePaths()
		if err != nil {
			return fail(stderr, 1, "resolve active theme for runtime: %v", err)
		}
		// Native Omarchy releases its theme transaction lock before running user
		// hooks. A rapid second theme selection can therefore promote a newer
		// theme before this older hook reaches Omagen. Never interpret the newer
		// current/theme tree using the stale hook argument or let it repaint the
		// runtime state under the wrong name.
		if activeTheme != args[1] {
			return writeJSON(stdout, stderr, runtime.ThemeSetResult{
				Theme:      args[1],
				Superseded: true,
				NativeOnly: true,
			})
		}
		result, err := runtime.ThemeSet(themeRoot, args[1])
		if err != nil {
			return fail(stderr, 1, "apply advanced runtime bridge: %v", err)
		}
		return writeJSON(stdout, stderr, result)
	default:
		return fail(stderr, 2, "unknown runtime subcommand: %s", args[0])
	}
}
