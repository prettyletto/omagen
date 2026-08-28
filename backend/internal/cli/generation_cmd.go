package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/bar"
	"github.com/prettyletto/omagen/backend/internal/barprofile"
	"github.com/prettyletto/omagen/backend/internal/generation"
	"github.com/prettyletto/omagen/backend/internal/lookfeel"
	palettecfg "github.com/prettyletto/omagen/backend/internal/palette"
	"github.com/prettyletto/omagen/backend/internal/session"
)

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

func runGenerate(args []string, service *generation.Service, stdout, stderr io.Writer) int {
	request, err := parseGenerateArgs(args)
	if err != nil {
		return fail(stderr, 2, "%v", err)
	}
	result, err := service.Generate(context.Background(), request)
	if err != nil {
		return fail(stderr, 1, "%v", err)
	}
	return writeJSON(stdout, stderr, result)
}

func parseGenerateArgs(args []string) (generation.Request, error) {
	if len(args) < 2 {
		return generation.Request{}, fmt.Errorf("usage: omagen generate <session_id> <image> [--harmony <mode>] [--shell-style <surface> <detail> <tooltip> <notifications> --desktop-style <border> <border-size> <shape> <spacing> <depth> <inactive-style> --bar-style <surface> <density> <attention> <form> <visibility>] [--bar-spec-json <object>]")
	}

	request := generation.Request{SessionID: args[0], SourceImage: args[1]}
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
