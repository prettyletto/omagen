package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/omarchy"
	palettecfg "github.com/prettyletto/omagen/backend/internal/palette"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/session"
	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
)

type pingResponse struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

type cancelResponse struct {
	OK        bool   `json:"ok"`
	SessionID string `json:"session_id"`
}

func Run(
	args []string,
	stdout,
	stderr io.Writer,
) int {
	if len(args) == 0 {
		return fail(
			stderr,
			2,
			"missing command",
		)
	}

	store, err := session.NewStore()
	if err != nil {
		return fail(
			stderr,
			1,
			"initialize session store: %v",
			err,
		)
	}
	settingsStore, err := settingspkg.NewStore()
	if err != nil {
		return fail(stderr, 1, "initialize settings store: %v", err)
	}

	omarchyClient := omarchy.NewClient(stderr)
	sessionService := session.NewService(store, omarchyClient)
	previewService, err := preview.NewService(store, omarchyClient)
	if err != nil {
		return fail(stderr, 1, "initialize preview service: %v", err)
	}

	generationService := generation.NewService(
		store,
		settingsStore,
	)

	switch args[0] {
	case "ping":
		return writeJSON(
			stdout,
			stderr,
			pingResponse{
				OK:      true,
				Version: "dev",
			},
		)

	case "session":
		return runSession(
			args[1:],
			sessionService,
			previewService,
			stdout,
			stderr,
		)

	case "preview":
		return runPreview(args[1:], previewService, stdout, stderr)

	case "generate":
		return runGenerate(
			args[1:],
			generationService,
			stdout,
			stderr,
		)

	case "settings":
		return runSettings(args[1:], settingsStore, stdout, stderr)

	default:
		return fail(
			stderr,
			2,
			"unknown command: %s",
			args[0],
		)
	}
}

func runSession(
	args []string,
	service *session.Service,
	previewService *preview.Service,
	stdout,
	stderr io.Writer,
) int {
	if len(args) == 0 {
		return fail(
			stderr,
			2,
			"missing session subcommand",
		)
	}

	switch args[0] {
	case "begin":
		if len(args) != 1 {
			return fail(stderr, 2, "session begin takes no arguments")
		}
		result, err := service.Begin()
		if err != nil {
			return fail(
				stderr,
				1,
				"%v",
				err,
			)
		}

		return writeJSON(
			stdout,
			stderr,
			result,
		)

	case "cancel":
		if len(args) != 2 {
			return fail(
				stderr,
				2,
				"usage: omagen session cancel <session_id>",
			)
		}

		if err := service.Cancel(
			args[1],
		); err != nil {
			return fail(
				stderr,
				1,
				"%v",
				err,
			)
		}
		if previewService != nil {
			if err := previewService.CleanupSession(args[1]); err != nil {
				return fail(stderr, 1, "session cancelled but preview cleanup failed: %v", err)
			}
		}

		return writeJSON(
			stdout,
			stderr,
			cancelResponse{
				OK:        true,
				SessionID: args[1],
			},
		)

	case "status":
		if len(args) != 1 {
			return fail(stderr, 2, "session status takes no arguments")
		}
		result, err := service.Status()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)

	case "recover":
		if len(args) != 1 {
			return fail(stderr, 2, "session recover takes no arguments")
		}
		result, err := service.RecoverActive()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		if result.Recovered && previewService != nil {
			if err := previewService.CleanupSession(result.SessionID); err != nil {
				return fail(stderr, 1, "session recovered but preview cleanup failed: %v", err)
			}
		}
		return writeJSON(stdout, stderr, result)

	default:
		return fail(
			stderr,
			2,
			"unknown session subcommand: %s",
			args[0],
		)
	}
}

func runPreview(args []string, service *preview.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing preview subcommand")
	}
	switch args[0] {
	case "apply":
		if len(args) != 4 {
			return fail(stderr, 2, "usage: omagen preview apply <session_id> <generation_id> <variant>")
		}
		variant, err := generation.ParseVariant(args[3])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		result, err := service.Apply(preview.Request{SessionID: args[1], GenerationID: args[2], Variant: variant})
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

func runGenerate(
	args []string,
	service *generation.Service,
	stdout,
	stderr io.Writer,
) int {
	request, err := parseGenerateArgs(args)
	if err != nil {
		return fail(stderr, 2, "%v", err)
	}

	result, err := service.Generate(
		context.Background(),
		request,
	)
	if err != nil {
		return fail(
			stderr,
			1,
			"%v",
			err,
		)
	}

	return writeJSON(
		stdout,
		stderr,
		result,
	)
}

func parseGenerateArgs(args []string) (generation.Request, error) {
	if len(args) < 2 {
		return generation.Request{}, fmt.Errorf(
			"usage: omagen generate <session_id> <image> [--harmony <mode>]",
		)
	}

	request := generation.Request{
		SessionID:   args[0],
		SourceImage: args[1],
	}
	harmonySeen := false

	for i := 2; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--harmony":
			if harmonySeen {
				return generation.Request{}, fmt.Errorf("--harmony specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--harmony requires a value")
			}
			i++
			harmony, err := palettecfg.ParseHarmony(args[i])
			if err != nil {
				return generation.Request{}, err
			}
			request.Overrides.ColorTheory.Harmony = &harmony
			harmonySeen = true
		case strings.HasPrefix(arg, "--harmony="):
			if harmonySeen {
				return generation.Request{}, fmt.Errorf("--harmony specified more than once")
			}
			harmony, err := palettecfg.ParseHarmony(strings.TrimPrefix(arg, "--harmony="))
			if err != nil {
				return generation.Request{}, err
			}
			request.Overrides.ColorTheory.Harmony = &harmony
			harmonySeen = true
		default:
			return generation.Request{}, fmt.Errorf("unknown generate option %q", arg)
		}
	}

	return request, nil
}

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

func writeJSON(
	stdout,
	stderr io.Writer,
	value any,
) int {
	if err := json.NewEncoder(
		stdout,
	).Encode(value); err != nil {
		return fail(
			stderr,
			1,
			"write json: %v",
			err,
		)
	}

	return 0
}

func fail(
	stderr io.Writer,
	code int,
	format string,
	args ...any,
) int {
	_, _ = fmt.Fprintf(
		stderr,
		format+"\n",
		args...,
	)

	return code
}
