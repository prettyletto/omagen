package main

import (
	"flag"
	"fmt"
	"os"

	tea "charm.land/bubbletea/v2"
	"github.com/prettyletto/omagen/backend/internal/studio"
)

func main() {
	palettePath := flag.String("palette", studio.CurrentPalettePath(), "path to an Omarchy colors.toml file")
	flag.Parse()

	program := tea.NewProgram(studio.NewModel(studio.LoadPalette(*palettePath)))
	if _, err := program.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "omagen-studio:", err)
		os.Exit(1)
	}
}
