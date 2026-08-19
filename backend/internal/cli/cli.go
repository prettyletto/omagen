package cli

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/prettyletto/omagen/backend/internal/omarchy"
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

func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing command")
	}
	store, err := session.NewStore()
	if err != nil {
		return fail(stderr, 1, "initialize session store: %v", err)
	}
	service := session.NewService(store, omarchy.NewClient(stderr))
	switch args[0] {
	case "ping":
		return writeJSON(stdout, stderr, pingResponse{OK: true, Version: "dev"})
	case "session":
		return runSession(args[1:], service, stdout, stderr)
	default:
		return fail(stderr, 2, "unknown command: %s", args[0])
	}
}

func runSession(args []string, service *session.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing session subcommand")
	}
	switch args[0] {
	case "begin":
		result, err := service.Begin()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "cancel":
		if len(args) < 2 {
			return fail(stderr, 2, "missing session id")
		}
		if err := service.Cancel(args[1]); err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, cancelResponse{OK: true, SessionID: args[1]})
	default:
		return fail(stderr, 2, "unknown session subcommand: %s", args[0])
	}
}

func writeJSON(stdout, stderr io.Writer, value any) int {
	if err := json.NewEncoder(stdout).Encode(value); err != nil {
		return fail(stderr, 1, "write json: %v", err)
	}
	return 0
}

func fail(stderr io.Writer, code int, format string, args ...any) int {
	_, _ = fmt.Fprintf(stderr, format+"\n", args...)
	return code
}
