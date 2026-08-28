package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/cleanup"
	"github.com/prettyletto/omagen/backend/internal/demo"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/lookfeel"
	"github.com/prettyletto/omagen/backend/internal/omarchy"
	palettecfg "github.com/prettyletto/omagen/backend/internal/palette"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/protocol"
	"github.com/prettyletto/omagen/backend/internal/runtime"
	"github.com/prettyletto/omagen/backend/internal/session"
	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/terminaltheme"
)

type pingResponse struct {
	OK      bool   `json:"ok"`
	Version string `json:"version"`
}

const BackendVersion = "1.0.0"

type cancelResponse struct {
	OK        bool   `json:"ok"`
	SessionID string `json:"session_id"`
}

type resumeResponse struct {
	Active                 bool                          `json:"active"`
	SessionID              string                        `json:"session_id,omitempty"`
	SourceImage            string                        `json:"source_image,omitempty"`
	GenerationID           string                        `json:"generation_id,omitempty"`
	WorkspaceResumable     bool                          `json:"workspace_resumable"`
	CanvasActive           bool                          `json:"canvas_active"`
	CanvasMode             string                        `json:"canvas_mode,omitempty"`
	CanvasMonitor          string                        `json:"canvas_monitor,omitempty"`
	PreviewVariant         string                        `json:"preview_variant,omitempty"`
	ShellStyle             session.ShellStyle            `json:"shell_style,omitempty"`
	DesktopStyle           session.DesktopStyle          `json:"desktop_style,omitempty"`
	BarStyle               session.BarStyle              `json:"bar_style,omitempty"`
	AnimationsStyle        session.AnimationsStyle       `json:"animations_style,omitempty"`
	LookFeel               session.LookFeelDocument      `json:"look_feel,omitempty"`
	TerminalTranslucency   session.TerminalTranslucency  `json:"terminal_translucency,omitempty"`
	ExtraConfigs           bool                          `json:"extra_configs,omitempty"`
	OriginalTheme          string                        `json:"original_theme,omitempty"`
	OriginalBackgroundKind string                        `json:"original_background_kind,omitempty"`
	OriginalBackgroundPath string                        `json:"original_background_path,omitempty"`
	Variants               []generation.DescribedVariant `json:"variants,omitempty"`
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
	barStore, err := barprofile.NewStore()
	if err != nil {
		return fail(stderr, 1, "initialize bar profile store: %v", err)
	}
	sessionService := session.NewService(store, omarchyClient, barStore)
	previewService, err := preview.NewService(store, omarchyClient, barStore)
	if err != nil {
		return fail(stderr, 1, "initialize preview service: %v", err)
	}
	applyService, err := apply.NewService(store, omarchyClient, barStore)
	if err != nil {
		return fail(stderr, 1, "initialize apply service: %v", err)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return fail(stderr, 1, "resolve user home: %v", err)
	}
	cleanupService := cleanup.NewService(store, filepath.Join(home, ".config", "omarchy", "themes"))
	generationService := generation.NewServiceWithBaselineRestorer(store, settingsStore, omarchyClient)
	demoService := demo.NewService(store)

	switch args[0] {
	case "--help", "-h", "help":
		_, _ = fmt.Fprintln(stdout, "omagen: image-based Omarchy theme generator")
		_, _ = fmt.Fprintln(stdout, "commands: session, preview, apply, generate, generation, demo, cleanup, settings, bar, look-feel, terminal, runtime, protocol, ping")
		return 0
	case "ping":
		return writeJSON(
			stdout,
			stderr,
			pingResponse{
				OK:      true,
				Version: BackendVersion,
			},
		)

	case "session":
		return runSessionWithDependencies(
			args[1:],
			sessionService,
			previewService,
			applyService,
			cleanupService,
			demoService,
			generationService,
			stdout,
			stderr,
		)

	case "preview":
		return runPreview(args[1:], previewService, stdout, stderr)
	case "apply":
		return runApply(args[1:], applyService, stdout, stderr)
	case "cleanup":
		if len(args) != 1 {
			return fail(stderr, 2, "cleanup takes no arguments")
		}
		result, err := cleanupService.Run()
		if err != nil {
			return fail(stderr, 1, "cleanup: %v", err)
		}
		for _, warning := range result.Warnings {
			fmt.Fprintf(stderr, "warning: %s\n", warning)
		}
		return writeJSON(stdout, stderr, result)

	case "generate":
		return runGenerate(
			args[1:],
			generationService,
			stdout,
			stderr,
		)

	case "generation":
		return runGeneration(args[1:], generationService, stdout, stderr)

	case "demo":
		return runDemo(args[1:], demoService, stdout, stderr)

	case "settings":
		return runSettings(args[1:], settingsStore, stdout, stderr)
	case "bar":
		return runBar(args[1:], barStore, omarchyClient, stdout, stderr)
	case "look-feel":
		return runLookFeel(args[1:], stdout, stderr)
	case "terminal":
		return runTerminal(args[1:], stdout, stderr)
	case "runtime":
		return runRuntime(args[1:], stdout, stderr)
	case "protocol":
		return runProtocol(args[1:], store, previewService, stdout, stderr)

	default:
		return fail(
			stderr,
			2,
			"unknown command: %s",
			args[0],
		)
	}
}

func runTerminal(args []string, stdout, stderr io.Writer) int {
	if len(args) != 2 || args[0] != "materialize" {
		return fail(stderr, 2, "usage: omagen terminal materialize <staged-theme-directory>")
	}
	report, err := terminaltheme.Materialize(args[1])
	if err != nil {
		return fail(stderr, 1, "materialize terminal themes: %v", err)
	}
	return writeJSON(stdout, stderr, report)
}

func runLookFeel(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen look-feel {list|resolve <preset>|export <preset>|import <manifest.json>}")
	}
	switch args[0] {
	case "list":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen look-feel list")
		}
		return writeJSON(stdout, stderr, lookfeel.Catalog())
	case "resolve":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen look-feel resolve <preset>")
		}
		composition, err := lookfeel.Resolve(args[1])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		return writeJSON(stdout, stderr, composition)
	case "export":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen look-feel export <preset>")
		}
		manifest, err := lookfeel.Export(args[1])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		return writeJSON(stdout, stderr, manifest)
	case "import":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen look-feel import <manifest.json>")
		}
		data, err := os.ReadFile(args[1])
		if err != nil {
			return fail(stderr, 2, "read recipe manifest: %v", err)
		}
		manifest, err := lookfeel.DecodeManifest(data)
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		return writeJSON(stdout, stderr, manifest.Recipe)
	default:
		return fail(stderr, 2, "unknown look-feel subcommand: %s", args[0])
	}
}

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
		themeRoot, _, err := runtime.ActiveThemePaths()
		if err != nil {
			return fail(stderr, 1, "resolve active theme for runtime: %v", err)
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

type barInspectResponse struct {
	SchemaVersion int    `json:"schema_version"`
	Theme         string `json:"theme,omitempty"`
	ConfigPath    string `json:"config_path"`
	ConfigExists  bool   `json:"config_exists"`
	ConfigMode    uint32 `json:"config_mode,omitempty"`
	ConfigSHA256  string `json:"config_sha256,omitempty"`
}

func runBar(args []string, store *barprofile.Store, native interface{ CurrentTheme() (string, error) }, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen bar {inspect|apply-profile|restore} ...")
	}
	switch args[0] {
	case "inspect":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen bar inspect")
		}
		theme, err := native.CurrentTheme()
		if err != nil {
			return fail(stderr, 1, "inspect current theme: %v", err)
		}
		snapshot, err := store.Capture(theme)
		if err != nil {
			return fail(stderr, 1, "inspect bar: %v", err)
		}
		return writeJSON(stdout, stderr, barInspectResponse{SchemaVersion: snapshot.SchemaVersion, Theme: snapshot.Theme, ConfigPath: snapshot.ConfigPath, ConfigExists: snapshot.ConfigExists, ConfigMode: snapshot.ConfigMode, ConfigSHA256: snapshot.ConfigSHA256})
	case "apply-profile":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen bar apply-profile <profile.json>")
		}
		profile, err := barprofile.LoadProfile(args[1])
		if err != nil {
			return fail(stderr, 2, "load bar profile: %v", err)
		}
		if err := store.Apply(profile); err != nil {
			return fail(stderr, 1, "apply bar profile: %v", err)
		}
		return writeJSON(stdout, stderr, profile)
	case "restore":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen bar restore <session_id>")
		}
		snapshot, err := store.LoadSnapshot(args[1])
		if err != nil {
			return fail(stderr, 1, "load bar snapshot: %v", err)
		}
		if err := store.Restore(snapshot); err != nil {
			return fail(stderr, 1, "restore bar snapshot: %v", err)
		}
		return writeJSON(stdout, stderr, map[string]any{"restored": true, "session_id": args[1]})
	default:
		return fail(stderr, 2, "unknown bar command: %s", args[0])
	}
}

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
	operation, err := journal.StartOperation(protocol.OperationInput{
		Name:         "navigate " + direction,
		SessionID:    sessionID,
		GenerationID: state.GenerationID,
		Variant:      state.Variant,
	})
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
	driverOperation, err := journal.StartOperation(protocol.OperationInput{
		ParentID: operation.ID, Name: "native checkpoint driver", SessionID: sessionID,
		GenerationID: state.GenerationID, Variant: state.Variant,
	})
	if err != nil {
		return protocol.NavigationResult{}, completeFailed(err)
	}
	if _, err := previewService.ApplyCheckpoint(preview.Request{
		SessionID: sessionID, GenerationID: state.GenerationID, Variant: variant, ColorOverrides: state.ColorOverrides, Styles: state.StyleOverrides,
	}); err != nil {
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

func runApply(args []string, service *apply.Service, stdout, stderr io.Writer) int {
	if len(args) < 4 {
		return fail(stderr, 2, "usage: omagen apply <session_id> <generation_id> <variant> <theme_name> [--unlock] [--live-preview] [--run <adapters>] [--skip <adapters>]")
	}
	variant, err := generation.ParseVariant(args[2])
	if err != nil {
		return fail(stderr, 2, "%v", err)
	}
	request := apply.Request{SessionID: args[0], GenerationID: args[1], Variant: variant, ThemeName: args[3]}
	for i := 4; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--unlock":
			request.GenerateUnlock = true
		case "--live-preview":
			request.CapturePreview = true
		case "--run", "--apps":
			if i+1 >= len(args) || args[i+1] == "" {
				return fail(stderr, 2, "usage: %s requires adapter names", arg)
			}
			request.RetintRun = args[i+1]
			i++
		case "--skip":
			if i+1 >= len(args) || args[i+1] == "" {
				return fail(stderr, 2, "usage: --skip requires adapter names")
			}
			request.RetintSkip = args[i+1]
			i++
		case "--scope":
			if i+1 >= len(args) || args[i+1] == "" {
				return fail(stderr, 2, "usage: --scope requires scope names")
			}
			request.Scope = args[i+1]
			i++
		case "--wait":
			if i+1 >= len(args) || (args[i+1] != "critical" && args[i+1] != "full" && args[i+1] != "none") {
				return fail(stderr, 2, "usage: --wait must be critical, full, or none")
			}
			request.WaitMode = args[i+1]
			i++
		case "--allow-trusted-hooks":
			request.AllowTrustedHooks = true
		default:
			return fail(stderr, 2, "unknown apply option: %s", arg)
		}
	}
	result, err := service.Apply(request)
	if err != nil {
		return fail(stderr, 1, "%v", err)
	}
	return writeJSON(stdout, stderr, result)
}

func runGeneration(args []string, service *generation.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing generation subcommand")
	}
	switch args[0] {
	case "discard":
		if len(args) != 3 {
			return fail(stderr, 2, "usage: omagen generation discard <session_id> <generation_id>")
		}
		result, err := service.Discard(args[1], args[2])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "describe":
		if len(args) != 3 {
			return fail(stderr, 2, "usage: omagen generation describe <session_id> <generation_id>")
		}
		result, err := service.Describe(args[1], args[2])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	default:
		return fail(stderr, 2, "unknown generation subcommand: %s", args[0])
	}
}

func runSession(args []string, service *session.Service, previewService *preview.Service, stdout, stderr io.Writer) int {
	return runSessionWithDependencies(args, service, previewService, nil, nil, nil, nil, stdout, stderr)
}

func runSessionWithDependencies(
	args []string,
	service *session.Service,
	previewService *preview.Service,
	applyService *apply.Service,
	cleanupService *cleanup.Service,
	demoService *demo.Service,
	generationService *generation.Service,
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
	case "resume":
		if len(args) != 1 {
			return fail(stderr, 2, "session resume takes no arguments")
		}
		active, exists, err := serviceStoreActive(service)
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		if !exists {
			return writeJSON(stdout, stderr, resumeResponse{Active: false})
		}
		if applyService != nil {
			handled, recoverErr := applyService.RecoverPending(active.SessionID)
			if recoverErr != nil {
				return fail(stderr, 1, "recover pending apply: %v", recoverErr)
			}
			if handled {
				active, exists, err = serviceStoreActive(service)
				if err != nil {
					return fail(stderr, 1, "%v", err)
				}
				if !exists {
					return writeJSON(stdout, stderr, resumeResponse{Active: false})
				}
			}
		}
		record, err := serviceStoreRecord(service, active.SessionID)
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		result := resumeResponse{Active: true, SessionID: record.SessionID, SourceImage: record.SourceImage, GenerationID: record.GenerationID, PreviewVariant: record.PreviewVariant, ShellStyle: record.ShellStyle, DesktopStyle: record.DesktopStyle, BarStyle: record.BarStyle, AnimationsStyle: session.NormalizeAnimationsStyle(record.AnimationsStyle), LookFeel: session.NormalizeLookFeelDocument(record.LookFeel), TerminalTranslucency: session.NormalizeTerminalTranslucency(record.TerminalTranslucency), ExtraConfigs: record.ExtraConfigs, OriginalTheme: record.OriginalTheme, OriginalBackgroundKind: record.OriginalBackground.Kind, OriginalBackgroundPath: record.OriginalBackground.Path}
		if demoService != nil {
			canvas, statusErr := demoService.Status(record.SessionID)
			if statusErr == nil {
				result.CanvasActive = canvas.Active
				result.CanvasMode = canvas.Mode
				result.CanvasMonitor = canvas.Monitor
			}
		}
		if record.GenerationID != "" && generationService != nil {
			described, err := generationService.Describe(record.SessionID, record.GenerationID)
			if err == nil {
				result.WorkspaceResumable = true
				result.Variants = described.Variants
			}
		}
		return writeJSON(stdout, stderr, result)
	case "begin":
		if len(args) != 1 && len(args) < 13 {
			return fail(stderr, 2, "usage: omagen session begin [--shell-style <surface> <detail> [<tooltip> <notifications>] --desktop-style <border> <border-size> [<default|none|fixed>] <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> [<form> [<visibility>]]]")
		}
		if cleanupService != nil {
			if result, cleanupErr := cleanupService.Run(); cleanupErr != nil {
				fmt.Fprintf(stderr, "warning: cleanup: %v\n", cleanupErr)
			} else {
				for _, warning := range result.Warnings {
					fmt.Fprintf(stderr, "warning: %s\n", warning)
				}
			}
		}
		var shellStyle session.ShellStyle
		var desktopStyle session.DesktopStyle
		var barStyle session.BarStyle
		var animationsStyle session.AnimationsStyle
		var lookFeel session.LookFeelDocument
		var terminalTranslucency session.TerminalTranslucency
		lookFeelSeen := false
		if len(args) >= 13 {
			shellStyleEnd := 4
			newShellStyle := len(args) >= 17
			if newShellStyle {
				shellStyleEnd = 6
			}
			if args[1] != "--shell-style" || args[shellStyleEnd] != "--desktop-style" {
				return fail(stderr, 2, "usage: omagen session begin [--shell-style <surface> <detail> [<tooltip> <notifications>] --desktop-style <border> <border-size> [<default|none|fixed>] <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> [<form> [<visibility>]]]")
			}
			barStyleStart := -1
			for index := shellStyleEnd + 1; index < len(args); index++ {
				if args[index] == "--bar-style" {
					barStyleStart = index
					break
				}
			}
			if barStyleStart < 0 {
				return fail(stderr, 2, "usage: omagen session begin [--shell-style <surface> <detail> [<tooltip> <notifications>] --desktop-style <border> <border-size> [<default|none|fixed>] <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> [<form> [<visibility>]]]")
			}
			shellStyle = session.ShellStyle{Surface: args[2], Detail: args[3], Tooltip: "native", Notifications: "native"}
			desktopStart := shellStyleEnd + 1
			if newShellStyle {
				shellStyle.Tooltip = args[4]
				shellStyle.Notifications = args[5]
			}
			desktopValueCount := barStyleStart - desktopStart
			if desktopValueCount != 6 && desktopValueCount != 7 {
				return fail(stderr, 2, "usage: omagen session begin [--shell-style <surface> <detail> [<tooltip> <notifications>] --desktop-style <border> <border-size> [<default|none|fixed>] <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> [<form> [<visibility>]]]")
			}
			borderSize, parseErr := strconv.Atoi(args[desktopStart+1])
			if parseErr != nil {
				return fail(stderr, 2, "invalid border size")
			}
			shapeStart := desktopStart + 2
			borderSizeMode := ""
			if desktopValueCount == 7 {
				borderSizeMode = args[desktopStart+2]
				shapeStart++
			}
			desktopStyle = session.DesktopStyle{BorderStyle: args[desktopStart], BorderSize: borderSize, BorderSizeMode: borderSizeMode, Shape: args[shapeStart], Spacing: args[shapeStart+1], Depth: args[shapeStart+2], Inactive: args[shapeStart+3]}
			barStyle = session.BarStyle{Surface: args[barStyleStart+1], Density: args[barStyleStart+2], Attention: args[barStyleStart+3], Form: "continuous", Visibility: "native"}
			barArgCount := len(args) - (barStyleStart + 1)
			if barArgCount >= 4 && !strings.HasPrefix(args[barStyleStart+4], "--") {
				barStyle.Form = args[barStyleStart+4]
			}
			if barArgCount >= 5 && !strings.HasPrefix(args[barStyleStart+5], "--") {
				barStyle.Visibility = args[barStyleStart+5]
			}
			for index := barStyleStart + 1; index < len(args); index++ {
				switch args[index] {
				case "--window-active-style":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --window-active-style requires a value")
					}
					desktopStyle.Active = args[index+1]
					index++
				case "--shell-preset":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --shell-preset requires a value")
					}
					shellStyle.Preset = args[index+1]
					index++
				case "--look-feel":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --look-feel requires a preset")
					}
					composition, resolveErr := lookfeel.Resolve(args[index+1])
					if resolveErr != nil {
						return fail(stderr, 2, "%v", resolveErr)
					}
					shellStyle = composition.Shell
					desktopStyle = composition.Window
					barStyle = composition.Bar
					animationsStyle = composition.Animations
					lookFeel = composition.LookFeelDocument()
					terminalTranslucency = composition.Terminal
					lookFeelSeen = true
					index++
				case "--look-feel-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --look-feel-json requires a JSON object")
					}
					if err := json.Unmarshal([]byte(args[index+1]), &lookFeel); err != nil {
						return fail(stderr, 2, "decode --look-feel-json: %v", err)
					}
					lookFeelSeen = true
					index++
				case "--terminal-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --terminal-json requires a JSON object")
					}
					if err := json.Unmarshal([]byte(args[index+1]), &terminalTranslucency); err != nil {
						return fail(stderr, 2, "decode --terminal-json: %v", err)
					}
					lookFeelSeen = true
					index++
				case "--animations-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --animations-json requires a JSON object")
					}
					if err := json.Unmarshal([]byte(args[index+1]), &animationsStyle); err != nil {
						return fail(stderr, 2, "decode --animations-json: %v", err)
					}
					index++
				case "--shell-overrides-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --shell-overrides-json requires a JSON object")
					}
					var overrides map[string]string
					if err := json.Unmarshal([]byte(args[index+1]), &overrides); err != nil {
						return fail(stderr, 2, "decode --shell-overrides-json: %v", err)
					}
					shellStyle.Overrides = overrides
					index++
				case "--bar-profile-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --bar-profile-json requires a JSON object")
					}
					var profile barprofile.Profile
					if err := json.Unmarshal([]byte(args[index+1]), &profile); err != nil {
						return fail(stderr, 2, "decode --bar-profile-json: %v", err)
					}
					profile = profile.Normalize()
					barStyle.Profile = &profile
					index++
				case "--bar-spec-json":
					if index+1 >= len(args) {
						return fail(stderr, 2, "usage: --bar-spec-json requires a JSON object")
					}
					var spec bar.BarSpec
					if err := json.Unmarshal([]byte(args[index+1]), &spec); err != nil {
						return fail(stderr, 2, "decode --bar-spec-json: %v", err)
					}
					spec = spec.Normalize()
					barStyle.Spec = &spec
					index++
				case "--bar-style":
					// The marker was already consumed above.
				default:
					if strings.HasPrefix(args[index], "--") && index != barStyleStart+4 && index != barStyleStart+5 {
						return fail(stderr, 2, "unknown session begin option: %s", args[index])
					}
				}
			}
		}
		var result session.BeginResult
		var err error
		if len(args) == 1 {
			result, err = service.Begin()
		} else {
			if lookFeelSeen {
				result, err = service.Begin(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
			} else {
				result, err = service.Begin(shellStyle, desktopStyle, barStyle, animationsStyle)
			}
		}
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

		var cleanupErrors []error
		if demoService != nil {
			if _, closeErr := demoService.Close(args[1]); closeErr != nil {
				cleanupErrors = append(cleanupErrors, fmt.Errorf("close demo: %w", closeErr))
			}
		}
		handled := false
		if applyService != nil {
			var recoverErr error
			handled, recoverErr = applyService.RecoverPending(args[1])
			if recoverErr != nil {
				return fail(stderr, 1, "recover pending apply: %v", recoverErr)
			}
		}
		if !handled {
			if err := service.Cancel(args[1]); err != nil {
				return fail(stderr, 1, "cancel session: %v", err)
			}
		}
		if previewService != nil {
			if err := previewService.CleanupSession(args[1]); err != nil {
				cleanupErrors = append(cleanupErrors, fmt.Errorf("cleanup preview: %w", err))
			}
		}
		writeCleanupWarnings(stderr, cleanupErrors)

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
		status, statusErr := service.Status()
		if statusErr != nil {
			return fail(stderr, 1, "%v", statusErr)
		}
		var cleanupErrors []error
		if status.Active && demoService != nil {
			if _, closeErr := demoService.Close(status.SessionID); closeErr != nil {
				cleanupErrors = append(cleanupErrors, fmt.Errorf("close demo: %w", closeErr))
			}
		}
		if applyService != nil {
			handled, recoverErr := applyService.RecoverPending(status.SessionID)
			if recoverErr != nil {
				return fail(stderr, 1, "recover pending apply: %v", recoverErr)
			}
			if handled {
				if previewService != nil {
					if err := previewService.CleanupSession(status.SessionID); err != nil {
						cleanupErrors = append(cleanupErrors, fmt.Errorf("cleanup preview: %w", err))
					}
				}
				writeCleanupWarnings(stderr, cleanupErrors)
				return writeJSON(stdout, stderr, session.RecoverResult{Recovered: true, SessionID: status.SessionID})
			}
		}
		result, err := service.RecoverActive()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		if result.Recovered && previewService != nil {
			if err := previewService.CleanupSession(result.SessionID); err != nil {
				cleanupErrors = append(cleanupErrors, fmt.Errorf("cleanup preview: %w", err))
			}
		}
		writeCleanupWarnings(stderr, cleanupErrors)
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

func writeCleanupWarnings(stderr io.Writer, cleanupErrors []error) {
	for _, err := range cleanupErrors {
		fmt.Fprintf(stderr, "warning: %v\n", err)
	}
}

func serviceStoreActive(service *session.Service) (session.ActiveRecord, bool, error) {
	return service.Store().LoadActive()
}

func serviceStoreRecord(service *session.Service, sessionID string) (session.Record, error) {
	return service.Store().Load(sessionID)
}

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

func parseRetintOptions(args []string) (run, skip string, err error) {
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--run", "--apps":
			if i+1 >= len(args) || args[i+1] == "" {
				return "", "", fmt.Errorf("%s requires adapter names", args[i])
			}
			run = args[i+1]
			i++
		case "--skip":
			if i+1 >= len(args) || args[i+1] == "" {
				return "", "", fmt.Errorf("--skip requires adapter names")
			}
			skip = args[i+1]
			i++
		default:
			return "", "", fmt.Errorf("unknown retint option: %s", args[i])
		}
	}
	return run, skip, nil
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
			"usage: omagen generate <session_id> <image> [--harmony <mode>] [--shell-style <surface> <detail> <tooltip> <notifications> --desktop-style <border> <border-size> <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> <form> <visibility>] [--bar-spec-json <object>]",
		)
	}

	request := generation.Request{
		SessionID:   args[0],
		SourceImage: args[1],
	}
	harmonySeen := false
	shellStyleSeen := false
	desktopStyleSeen := false
	barStyleSeen := false
	barProfileSeen := false
	barSpecSeen := false
	activeStyleSeen := false
	var shellStyle session.ShellStyle
	var desktopStyle session.DesktopStyle
	var barStyle session.BarStyle
	var animationsStyle session.AnimationsStyle
	animationsStyleSeen := false
	shellOverridesSeen := false
	lookFeelSeen := false
	var lookFeelDocument session.LookFeelDocument
	var terminalTranslucency session.TerminalTranslucency

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
		case arg == "--shell-style":
			if shellStyleSeen {
				return generation.Request{}, fmt.Errorf("--shell-style specified more than once")
			}
			if i+4 >= len(args) {
				return generation.Request{}, fmt.Errorf("--shell-style requires surface, detail, tooltip, and notifications")
			}
			shellStyle = session.ShellStyle{Surface: args[i+1], Detail: args[i+2], Tooltip: args[i+3], Notifications: args[i+4]}
			shellStyleSeen = true
			i += 4
		case arg == "--shell-preset":
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--shell-preset requires a value")
			}
			shellStyle.Preset = args[i+1]
			shellStyleSeen = true
			i++
		case arg == "--look-feel":
			if lookFeelSeen {
				return generation.Request{}, fmt.Errorf("--look-feel specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--look-feel requires a preset")
			}
			composition, err := lookfeel.Resolve(args[i+1])
			if err != nil {
				return generation.Request{}, err
			}
			lookFeelDocument = composition.LookFeelDocument()
			terminalTranslucency = composition.Terminal
			lookFeelSeen = true
			i++
		case arg == "--look-feel-json":
			if lookFeelSeen {
				return generation.Request{}, fmt.Errorf("--look-feel specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--look-feel-json requires a JSON object")
			}
			if err := json.Unmarshal([]byte(args[i+1]), &lookFeelDocument); err != nil {
				return generation.Request{}, fmt.Errorf("decode --look-feel-json: %w", err)
			}
			lookFeelSeen = true
			i++
		case arg == "--terminal-json":
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--terminal-json requires a JSON object")
			}
			if err := json.Unmarshal([]byte(args[i+1]), &terminalTranslucency); err != nil {
				return generation.Request{}, fmt.Errorf("decode --terminal-json: %w", err)
			}
			lookFeelSeen = true
			i++
		case arg == "--desktop-style":
			if desktopStyleSeen {
				return generation.Request{}, fmt.Errorf("--desktop-style specified more than once")
			}
			if i+6 >= len(args) {
				return generation.Request{}, fmt.Errorf("--desktop-style requires border, border size, shape, spacing, depth, and inactive style")
			}
			borderSize, parseErr := strconv.Atoi(args[i+2])
			if parseErr != nil {
				return generation.Request{}, fmt.Errorf("invalid border size")
			}
			shapeStart := i + 3
			borderSizeMode := ""
			consumed := 6
			if i+7 < len(args) && isBorderSizeMode(args[i+3]) {
				borderSizeMode = args[i+3]
				shapeStart++
				consumed = 7
			}
			desktopStyle = session.DesktopStyle{BorderStyle: args[i+1], BorderSize: borderSize, BorderSizeMode: borderSizeMode, Shape: args[shapeStart], Spacing: args[shapeStart+1], Depth: args[shapeStart+2], Inactive: args[shapeStart+3]}
			desktopStyleSeen = true
			i += consumed
		case arg == "--bar-style":
			if barStyleSeen {
				return generation.Request{}, fmt.Errorf("--bar-style specified more than once")
			}
			if i+5 >= len(args) {
				return generation.Request{}, fmt.Errorf("--bar-style requires surface, density, attention, form, and visibility")
			}
			barStyle = session.BarStyle{Surface: args[i+1], Density: args[i+2], Attention: args[i+3], Form: args[i+4], Visibility: args[i+5]}
			barStyleSeen = true
			i += 5
		case arg == "--bar-profile-json":
			if barProfileSeen {
				return generation.Request{}, fmt.Errorf("--bar-profile-json specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--bar-profile-json requires a JSON object")
			}
			var profile barprofile.Profile
			if err := json.Unmarshal([]byte(args[i+1]), &profile); err != nil {
				return generation.Request{}, fmt.Errorf("decode --bar-profile-json: %w", err)
			}
			profile = profile.Normalize()
			barStyle.Profile = &profile
			barProfileSeen = true
			i++
		case arg == "--bar-spec-json":
			if barSpecSeen {
				return generation.Request{}, fmt.Errorf("--bar-spec-json specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--bar-spec-json requires a JSON object")
			}
			var spec bar.BarSpec
			if err := json.Unmarshal([]byte(args[i+1]), &spec); err != nil {
				return generation.Request{}, fmt.Errorf("decode --bar-spec-json: %w", err)
			}
			spec = spec.Normalize()
			barStyle.Spec = &spec
			barSpecSeen = true
			i++
		case arg == "--window-active-style":
			if activeStyleSeen {
				return generation.Request{}, fmt.Errorf("--window-active-style specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--window-active-style requires a value")
			}
			desktopStyle.Active = args[i+1]
			activeStyleSeen = true
			i++
		case arg == "--animations-json":
			if animationsStyleSeen {
				return generation.Request{}, fmt.Errorf("--animations-json specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--animations-json requires a JSON object")
			}
			if err := json.Unmarshal([]byte(args[i+1]), &animationsStyle); err != nil {
				return generation.Request{}, fmt.Errorf("decode --animations-json: %w", err)
			}
			animationsStyleSeen = true
			i++
		case arg == "--shell-overrides-json":
			if shellOverridesSeen {
				return generation.Request{}, fmt.Errorf("--shell-overrides-json specified more than once")
			}
			if i+1 >= len(args) {
				return generation.Request{}, fmt.Errorf("--shell-overrides-json requires a JSON object")
			}
			if err := json.Unmarshal([]byte(args[i+1]), &shellStyle.Overrides); err != nil {
				return generation.Request{}, fmt.Errorf("decode --shell-overrides-json: %w", err)
			}
			shellOverridesSeen = true
			i++
		default:
			return generation.Request{}, fmt.Errorf("unknown generate option %q", arg)
		}
	}
	if lookFeelSeen {
		composition, err := lookfeel.Resolve(lookFeelDocument.Preset)
		if err != nil {
			return generation.Request{}, err
		}
		if !shellStyleSeen {
			shellStyle = composition.Shell
		}
		if !desktopStyleSeen {
			desktopStyle = composition.Window
		}
		if !barStyleSeen && !barProfileSeen && !barSpecSeen {
			barStyle = composition.Bar
		}
		if !animationsStyleSeen {
			animationsStyle = composition.Animations
		}
		if shellStyleSeen {
			lookFeelDocument.Customized["shell"] = true
		}
		if desktopStyleSeen {
			lookFeelDocument.Customized["window"] = true
		}
		if barStyleSeen || barProfileSeen || barSpecSeen {
			lookFeelDocument.Customized["bar"] = true
		}
		if animationsStyleSeen {
			lookFeelDocument.Customized["animations"] = true
		}
	}
	if shellStyleSeen || desktopStyleSeen || barStyleSeen || barProfileSeen || barSpecSeen || lookFeelSeen {
		if !shellStyleSeen && !lookFeelSeen {
			shellStyle = session.DefaultShellStyle()
		}
		if !desktopStyleSeen && !lookFeelSeen {
			desktopStyle = session.DefaultDesktopStyle()
		}
		if !barStyleSeen && !lookFeelSeen {
			profile, spec := barStyle.Profile, barStyle.Spec
			barStyle = session.DefaultBarStyle()
			barStyle.Profile, barStyle.Spec = profile, spec
		}
		request.Configuration = &generation.Configuration{ShellStyle: shellStyle, DesktopStyle: desktopStyle, BarStyle: barStyle, AnimationsStyle: animationsStyle, LookFeel: lookFeelDocument, Terminal: terminalTranslucency}
	}

	return request, nil
}

func isBorderSizeMode(value string) bool {
	return value == "default" || value == "none" || value == "fixed"
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
