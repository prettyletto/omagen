package cli

import (
	"fmt"
	"io"

	"github.com/prettyletto/omagen/backend/internal/cleanup"
)

func runCleanup(args []string, service *cleanup.Service, stdout, stderr io.Writer) int {
	if len(args) != 0 {
		return fail(stderr, 2, "cleanup takes no arguments")
	}
	result, err := service.Run()
	if err != nil {
		return fail(stderr, 1, "cleanup: %v", err)
	}
	for _, warning := range result.Warnings {
		fmt.Fprintf(stderr, "warning: %s\n", warning)
	}
	return writeJSON(stdout, stderr, result)
}
