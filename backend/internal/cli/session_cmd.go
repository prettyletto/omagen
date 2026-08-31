package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/cleanup"
	"github.com/prettyletto/omagen/backend/internal/demo"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/lookfeel"
	"github.com/prettyletto/omagen/backend/internal/preview"
	"github.com/prettyletto/omagen/backend/internal/session"
)

type cancelResponse struct {
	OK        bool   `json:"ok"`
	SessionID string `json:"session_id"`
}

type resumeResponse struct {
	Active                 bool                          `json:"active"`
	Workflow               string                        `json:"workflow,omitempty"`
	ThemeEdit              *session.ThemeEdit            `json:"theme_edit,omitempty"`
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

func runSession(args []string, service *session.Service, previewService *preview.Service, stdout, stderr io.Writer) int {
	return runSessionWithDependencies(args, service, previewService, nil, nil, nil, nil, stdout, stderr)
}

func runSessionWithDependencies(args []string, service *session.Service, previewService *preview.Service, applyService *apply.Service, cleanupService *cleanup.Service, demoService *demo.Service, generationService *generation.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "missing session subcommand")
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
		result := resumeResponse{Active: true, Workflow: record.Workflow, ThemeEdit: record.ThemeEdit, SessionID: record.SessionID, SourceImage: record.SourceImage, GenerationID: record.GenerationID, PreviewVariant: record.PreviewVariant, ShellStyle: record.ShellStyle, DesktopStyle: record.DesktopStyle, BarStyle: record.BarStyle, AnimationsStyle: session.NormalizeAnimationsStyle(record.AnimationsStyle), LookFeel: session.NormalizeLookFeelDocument(record.LookFeel), TerminalTranslucency: session.NormalizeTerminalTranslucency(record.TerminalTranslucency), ExtraConfigs: record.ExtraConfigs, OriginalTheme: record.OriginalTheme, OriginalBackgroundKind: record.OriginalBackground.Kind, OriginalBackgroundPath: record.OriginalBackground.Path}
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
		} else if lookFeelSeen {
			result, err = service.Begin(shellStyle, desktopStyle, barStyle, animationsStyle, lookFeel, terminalTranslucency)
		} else {
			result, err = service.Begin(shellStyle, desktopStyle, barStyle, animationsStyle)
		}
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)

	case "cancel":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen session cancel <session_id>")
		}
		var cleanupErrors []error
		if demoService != nil {
			if _, closeErr := demoService.Close(args[1]); closeErr != nil {
				return fail(stderr, 1, "close demo: %v", closeErr)
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
		return writeJSON(stdout, stderr, cancelResponse{OK: true, SessionID: args[1]})

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
				return fail(stderr, 1, "close demo: %v", closeErr)
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
		return fail(stderr, 2, "unknown session subcommand: %s", args[0])
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
