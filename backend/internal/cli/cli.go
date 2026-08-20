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
	"github.com/prettyletto/omagen/backend/internal/session"
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

	sessionService := session.NewService(
		store,
		omarchy.NewClient(stderr),
	)

	generationService := generation.NewService(
		store,
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
			stdout,
			stderr,
		)

	case "generate":
		return runGenerate(
			args[1:],
			generationService,
			stdout,
			stderr,
		)

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
		if len(args) < 2 {
			return fail(
				stderr,
				2,
				"missing session id",
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

		return writeJSON(
			stdout,
			stderr,
			cancelResponse{
				OK:        true,
				SessionID: args[1],
			},
		)

	default:
		return fail(
			stderr,
			2,
			"unknown session subcommand: %s",
			args[0],
		)
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
		Options:     generation.DefaultOptions(),
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
			request.Options.ColorTheory.Harmony = harmony
			harmonySeen = true
		case strings.HasPrefix(arg, "--harmony="):
			if harmonySeen {
				return generation.Request{}, fmt.Errorf("--harmony specified more than once")
			}
			harmony, err := palettecfg.ParseHarmony(strings.TrimPrefix(arg, "--harmony="))
			if err != nil {
				return generation.Request{}, err
			}
			request.Options.ColorTheory.Harmony = harmony
			harmonySeen = true
		default:
			return generation.Request{}, fmt.Errorf("unknown generate option %q", arg)
		}
	}

	return request, nil
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
