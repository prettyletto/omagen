package cli

import (
	"encoding/json"
	"io"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/lookfeel"
)

func runLookFeel(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen look-feel {list|resolve <preset>|save <name> <composition.json>|export <preset>|import <manifest.json>}")
	}
	switch args[0] {
	case "list":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen look-feel list")
		}
		catalog, err := lookfeel.CatalogWithLocal()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, catalog)
	case "resolve":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen look-feel resolve <preset>")
		}
		composition, err := lookfeel.Resolve(args[1])
		if err != nil {
			return fail(stderr, 2, "%v", err)
		}
		return writeJSON(stdout, stderr, composition)
	case "save":
		if len(args) != 3 {
			return fail(stderr, 2, "usage: omagen look-feel save <name> <composition.json>")
		}
		var composition lookfeel.Composition
		if err := json.Unmarshal([]byte(args[2]), &composition); err != nil {
			return fail(stderr, 2, "decode Look & Feel composition: %v", err)
		}
		entry, err := lookfeel.SaveLocal(args[1], composition)
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, entry)
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
		data, err := fsutil.ReadFileLimited(args[1], fsutil.MaxStateFileBytes)
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
