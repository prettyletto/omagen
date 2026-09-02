package cli

import (
	"io"

	"github.com/prettyletto/omagen/backend/internal/terminaltheme"
)

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
