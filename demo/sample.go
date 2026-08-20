package main

import (
	"errors"
	"fmt"
)

type Variant string

const (
	Source  Variant = "source"
	Vibrant Variant = "vibrant"
)

type Theme struct {
	Name       string
	Variant    Variant
	Accent     string
	Background string
	Ready      bool
}

func preview(theme Theme) error {
	if !theme.Ready { return errors.New("theme is not ready") }
	fmt.Printf("previewing %s/%s with accent %s\n", theme.Name, theme.Variant, theme.Accent)
	return nil
}

func main() {
	theme := Theme{Name: "Omagen", Variant: Vibrant, Accent: "#f4c95d", Background: "#1f0c20", Ready: true}
	if err := preview(theme); err != nil { panic(err) }
}
