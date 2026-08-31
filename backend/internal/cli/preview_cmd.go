package cli

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/preview"
)

func runPreview(args []string, service *preview.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing preview subcommand")
	}
	switch args[0] {
	case "apply":
		if len(args) < 4 {
			return fail(stderr, 2, "usage: omagen preview apply <session_id> <generation_id> <variant> [--colors-json <json>] [--styles-json <json>] [--run <adapters>] [--skip <adapters>]")
		}
		variant, err := generation.ParseVariant(args[3])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		options, err := parseStudioOptions(args[4:])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		result, err := service.Apply(preview.Request{SessionID: args[1], GenerationID: args[2], Variant: variant, RetintRun: options.RetintRun, RetintSkip: options.RetintSkip, Scope: options.Scope, WaitMode: options.WaitMode, AllowTrustedHooks: options.AllowTrustedHooks, ColorOverrides: options.ColorOverrides, Styles: options.Styles})
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "cleanup":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen preview cleanup <session_id>")
		}
		if err := service.CleanupSession(args[1]); err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, map[string]any{"ok": true, "session_id": args[1]})
	default:
		return fail(stderr, 2, "unknown preview subcommand: %s", args[0])
	}
}

type studioOptions struct {
	RetintRun         string
	RetintSkip        string
	Scope             string
	WaitMode          string
	AllowTrustedHooks bool
	ColorOverrides    map[string]string
	Styles            *preview.StyleOverrides
}

func parseStudioOptions(args []string) (studioOptions, error) {
	options := studioOptions{}
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--run", "--apps":
			if i+1 >= len(args) || args[i+1] == "" {
				return studioOptions{}, fmt.Errorf("%s requires adapter names", args[i])
			}
			options.RetintRun = args[i+1]
			i++
		case "--skip":
			if i+1 >= len(args) || args[i+1] == "" {
				return studioOptions{}, fmt.Errorf("--skip requires adapter names")
			}
			options.RetintSkip = args[i+1]
			i++
		case "--scope":
			if i+1 >= len(args) || args[i+1] == "" {
				return studioOptions{}, fmt.Errorf("--scope requires scope names")
			}
			options.Scope = args[i+1]
			i++
		case "--wait":
			if i+1 >= len(args) || (args[i+1] != "critical" && args[i+1] != "full" && args[i+1] != "none") {
				return studioOptions{}, fmt.Errorf("--wait must be critical, full, or none")
			}
			options.WaitMode = args[i+1]
			i++
		case "--allow-trusted-hooks":
			options.AllowTrustedHooks = true
		case "--colors-json":
			if i+1 >= len(args) || args[i+1] == "" {
				return studioOptions{}, fmt.Errorf("--colors-json requires a JSON object")
			}
			if err := json.Unmarshal([]byte(args[i+1]), &options.ColorOverrides); err != nil {
				return studioOptions{}, fmt.Errorf("decode --colors-json: %w", err)
			}
			if options.ColorOverrides == nil {
				options.ColorOverrides = map[string]string{}
			}
			i++
		case "--styles-json":
			if i+1 >= len(args) || args[i+1] == "" {
				return studioOptions{}, fmt.Errorf("--styles-json requires a JSON object")
			}
			var styles preview.StyleOverrides
			if err := json.Unmarshal([]byte(args[i+1]), &styles); err != nil {
				return studioOptions{}, fmt.Errorf("decode --styles-json: %w", err)
			}
			if !styles.Valid() {
				return studioOptions{}, fmt.Errorf("--styles-json contains invalid shell, desktop, or bar styles")
			}
			options.Styles = &styles
			i++
		default:
			return studioOptions{}, fmt.Errorf("unknown studio option: %s", args[i])
		}
	}
	return options, nil
}
