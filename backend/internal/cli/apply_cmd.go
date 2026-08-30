package cli

import (
	"io"

	"github.com/prettyletto/omagen/backend/internal/apply"
	"github.com/prettyletto/omagen/backend/internal/generation"
)

func runApply(args []string, service *apply.Service, stdout, stderr io.Writer) int {
	if len(args) < 4 {
		return fail(stderr, 2, "usage: omagen apply <session_id> <generation_id> <variant> <theme_name> [--unlock] [--live-preview] [--replace-source] [--run <adapters>] [--skip <adapters>]")
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
		case "--replace-source":
			request.DestinationPolicy = "replace-source"
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
