package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type protocolInspectResponse struct {
	SessionID string                `json:"session_id"`
	Paths     protocol.SessionPaths `json:"paths"`
	Snapshot  protocol.Snapshot     `json:"snapshot"`
}

type protocolReadyResponse struct {
	OK        bool                  `json:"ok"`
	SessionID string                `json:"session_id"`
	Paths     protocol.SessionPaths `json:"paths"`
}

func runProtocol(args []string, store *session.Store, previewService *preview.Service, stdout, stderr io.Writer) int {
	if len(args) < 2 {
		return fail(stderr, 2, "usage: omagen protocol {inspect|events|back|forward|serve} <session_id> [checkpoint_id]")
	}
	command := args[0]
	sessionID := args[1]
	journal, paths, err := protocol.OpenForSession(store.StateRoot(), sessionID)
	if err != nil {
		return fail(stderr, 1, "open protocol: %v", err)
	}
	switch command {
	case "inspect":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen protocol inspect <session_id>")
		}
		snapshot, err := journal.Snapshot()
		if err != nil {
			return fail(stderr, 1, "inspect protocol: %v", err)
		}
		return writeJSON(stdout, stderr, protocolInspectResponse{SessionID: sessionID, Paths: paths, Snapshot: snapshot})
	case "events":
		if len(args) > 3 {
			return fail(stderr, 2, "usage: omagen protocol events <session_id> [after_sequence]")
		}
		var after uint64
		if len(args) == 3 {
			after, err = strconv.ParseUint(args[2], 10, 64)
			if err != nil {
				return fail(stderr, 2, "invalid event sequence: %v", err)
			}
		}
		events, err := journal.Events(after)
		if err != nil {
			return fail(stderr, 1, "read protocol events: %v", err)
		}
		return writeJSON(stdout, stderr, events)
	case "back":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen protocol back <session_id>")
		}
		navigation, err := executeProtocolNavigation(journal, previewService, sessionID, "back", "")
		if err != nil {
			return fail(stderr, 1, "protocol back: %v", err)
		}
		return writeJSON(stdout, stderr, navigation)
	case "forward":
		if len(args) > 3 {
			return fail(stderr, 2, "usage: omagen protocol forward <session_id> [checkpoint_id]")
		}
		checkpointID := ""
		if len(args) == 3 {
			checkpointID = args[2]
		}
		navigation, err := executeProtocolNavigation(journal, previewService, sessionID, "forward", checkpointID)
		if err != nil {
			return fail(stderr, 1, "protocol forward: %v", err)
		}
		return writeJSON(stdout, stderr, navigation)
	case "serve":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen protocol serve <session_id>")
		}
		server := protocol.NewServer(journal, paths.Socket, 100*time.Millisecond)
		if status := writeJSON(stdout, stderr, protocolReadyResponse{OK: true, SessionID: sessionID, Paths: paths}); status != 0 {
			return status
		}
		ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
		defer stop()
		if err := server.Serve(ctx); err != nil {
			return fail(stderr, 1, "serve protocol: %v", err)
		}
		return 0
	default:
		return fail(stderr, 2, "unknown protocol command: %s", command)
	}
}

type checkpointState struct {
	ThemeName      string                  `json:"theme_name"`
	GenerationID   string                  `json:"generation_id"`
	Variant        string                  `json:"variant"`
	Mode           string                  `json:"mode"`
	ColorOverrides map[string]string       `json:"color_overrides,omitempty"`
	StyleOverrides *preview.StyleOverrides `json:"style_overrides,omitempty"`
}

func executeProtocolNavigation(journal *protocol.Journal, previewService *preview.Service, sessionID, direction, checkpointID string) (protocol.NavigationResult, error) {
	if previewService == nil {
		return protocol.NavigationResult{}, fmt.Errorf("protocol navigation executor is unavailable")
	}
	target, err := journal.NavigationTarget(direction, checkpointID)
	if err != nil {
		return protocol.NavigationResult{}, err
	}
	var state checkpointState
	if err := json.Unmarshal(target.State, &state); err != nil {
		return protocol.NavigationResult{}, fmt.Errorf("decode protocol checkpoint state: %w", err)
	}
	if state.Mode != "preview" {
		return protocol.NavigationResult{}, fmt.Errorf("protocol checkpoint mode %q cannot be reapplied in the active session", state.Mode)
	}
	variant, err := generation.ParseVariant(state.Variant)
	if err != nil {
		return protocol.NavigationResult{}, fmt.Errorf("decode protocol checkpoint variant: %w", err)
	}
	operation, err := journal.StartOperation(protocol.OperationInput{Name: "navigate " + direction, SessionID: sessionID, GenerationID: state.GenerationID, Variant: state.Variant})
	if err != nil {
		return protocol.NavigationResult{}, fmt.Errorf("start navigation protocol: %w", err)
	}
	completeFailed := func(cause error) error {
		_, _ = journal.CompleteOperation(operation.ID, protocol.StatusFailed, cause.Error(), "native checkpoint reapply failed")
		return cause
	}
	if _, err := journal.Progress(operation.ID, "reapplying checkpoint", "scope=theme,shell,hyprland,background,apps wait=critical", nil); err != nil {
		return protocol.NavigationResult{}, completeFailed(err)
	}
	driverOperation, err := journal.StartOperation(protocol.OperationInput{ParentID: operation.ID, Name: "native checkpoint driver", SessionID: sessionID, GenerationID: state.GenerationID, Variant: state.Variant})
	if err != nil {
		return protocol.NavigationResult{}, completeFailed(err)
	}
	if _, err := previewService.ApplyCheckpoint(preview.Request{SessionID: sessionID, GenerationID: state.GenerationID, Variant: variant, ColorOverrides: state.ColorOverrides, Styles: state.StyleOverrides}); err != nil {
		_, _ = journal.CompleteOperation(driverOperation.ID, protocol.StatusFailed, err.Error(), "native checkpoint driver failed")
		return protocol.NavigationResult{}, completeFailed(err)
	}
	if _, err := journal.CompleteOperation(driverOperation.ID, protocol.StatusSucceeded, "native checkpoint driver reached critical state", "native preview state verified"); err != nil {
		return protocol.NavigationResult{}, completeFailed(err)
	}
	moved, err := journal.MoveCursor(target.ToCheckpointID)
	if err != nil {
		return protocol.NavigationResult{}, completeFailed(fmt.Errorf("commit protocol cursor: %w", err))
	}
	if _, err := journal.CompleteOperation(operation.ID, protocol.StatusSucceeded, "checkpoint reapplied", "native preview state verified"); err != nil {
		return protocol.NavigationResult{}, err
	}
	return moved, nil
}
