package cli

import (
	"encoding/json"
	"fmt"
	"io"
)

func writeJSON(stdout, stderr io.Writer, value any) int {
	if err := json.NewEncoder(stdout).Encode(value); err != nil {
		return fail(stderr, 1, "write json: %v", err)
	}
	return 0
}

func fail(stderr io.Writer, code int, format string, args ...any) int {
	_, _ = fmt.Fprintf(stderr, format+"\n", args...)
	return code
}
