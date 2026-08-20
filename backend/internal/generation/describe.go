package generation

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

func (s *Service) Describe(sessionID, generationID string) (DescribeResult, error) {
	if !validGenerationComponent(sessionID) {
		return DescribeResult{}, fmt.Errorf("invalid session id")
	}
	if !validGenerationComponent(generationID) || strings.HasPrefix(generationID, ".") {
		return DescribeResult{}, fmt.Errorf("invalid generation id")
	}
	if _, err := s.sessions.Load(sessionID); err != nil {
		return DescribeResult{}, fmt.Errorf("load session: %w", err)
	}
	root := filepath.Join(s.sessions.SessionDir(sessionID), "generations", generationID)
	info, err := os.Lstat(root)
	if err != nil {
		return DescribeResult{}, fmt.Errorf("inspect generation: %w", err)
	}
	if !info.IsDir() {
		return DescribeResult{}, fmt.Errorf("generation is not a directory")
	}
	result := DescribeResult{GenerationID: generationID, Variants: make([]DescribedVariant, 0, len(orderedVariants))}
	for _, variant := range orderedVariants {
		path := filepath.Join(root, string(variant))
		palette, err := theme.ReadColors(path)
		if err != nil {
			return DescribeResult{}, fmt.Errorf("read %s palette: %w", variant, err)
		}
		result.Variants = append(result.Variants, DescribedVariant{Variant: variant, Path: path, Palette: paletteView(palette)})
	}
	return result, nil
}

func paletteView(p theme.Palette) PaletteView {
	return PaletteView{Mode: p.Mode, Accent: p.Accent, Selection: p.Selection, Muted: p.Muted, Background: p.Background, DarkBackground: p.DarkBackground, DarkerBackground: p.DarkerBackground, LighterBackground: p.LighterBackground, Foreground: p.Foreground, DarkForeground: p.DarkForeground, LightForeground: p.LightForeground, BrightForeground: p.BrightForeground, Red: p.Red, Yellow: p.Yellow, Orange: p.Orange, Green: p.Green, Cyan: p.Cyan, Blue: p.Blue, Magenta: p.Magenta, Brown: p.Brown, BrightRed: p.BrightRed, BrightYellow: p.BrightYellow, BrightGreen: p.BrightGreen, BrightCyan: p.BrightCyan, BrightBlue: p.BrightBlue, BrightMagenta: p.BrightMagenta}
}

func validGenerationComponent(value string) bool {
	return value != "" && value != "." && value != ".." && filepath.Base(value) == value
}
