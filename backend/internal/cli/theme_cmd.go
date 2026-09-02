package cli

import (
	"fmt"
	"io"

	"github.com/prettyletto/omagen/backend/internal/themeedit"
)

func runTheme(args []string, service *themeedit.Service, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return fail(stderr, 2, "usage: omagen theme {list|edit <theme-id>|export-recipe <theme-id>}")
	}
	switch args[0] {
	case "list":
		if len(args) != 1 {
			return fail(stderr, 2, "usage: omagen theme list")
		}
		result, err := service.List()
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "edit":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen theme edit <theme-id>")
		}
		result, err := service.Open(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, result)
	case "export-recipe":
		if len(args) != 2 {
			return fail(stderr, 2, "usage: omagen theme export-recipe <theme-id>")
		}
		recipe, err := service.ExportRecipe(args[1])
		if err != nil {
			return fail(stderr, 1, "%v", err)
		}
		return writeJSON(stdout, stderr, recipe)
	default:
		return fail(stderr, 2, fmt.Sprintf("unknown theme subcommand: %s", args[0]))
	}
}
