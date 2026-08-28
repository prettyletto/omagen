package cli

import (
	"io"
	"os"

	"github.com/prettyletto/omagen/backend/internal/lookfeel"
)

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
