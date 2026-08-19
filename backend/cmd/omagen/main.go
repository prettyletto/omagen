package main

import (
	"io"
	"os"

	"github.com/prettyletto/omagen/backend/internal/cli"
)

func main() {
	exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

var exit = os.Exit

func run(args []string, stdout, stderr io.Writer) int {
	return cli.Run(args, stdout, stderr)
}
