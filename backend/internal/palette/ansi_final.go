package palette

import (
	"fmt"
	"math"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/contrast"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type finalANSISlot struct {
	name  string
	value *string
}

// EnsureANSIDistinctAfterContrast repairs only exact ANSI collisions after
// contrast enforcement, preserving hue and the existing contrast guarantee.
func EnsureANSIDistinctAfterContrast(input theme.Palette, normalTarget, brightTarget float64) (theme.Palette, error) {
	result := input
	normal := []finalANSISlot{{"red", &result.Red}, {"orange", &result.Orange}, {"yellow", &result.Yellow}, {"green", &result.Green}, {"cyan", &result.Cyan}, {"blue", &result.Blue}, {"magenta", &result.Magenta}, {"brown", &result.Brown}}
	if err := ensureFinalANSIGroupDistinct(result.Background, result.Mode, normalTarget, normal); err != nil {
		return theme.Palette{}, fmt.Errorf("repair normal ANSI collisions: %w", err)
	}
	bright := []finalANSISlot{{"bright_red", &result.BrightRed}, {"bright_yellow", &result.BrightYellow}, {"bright_green", &result.BrightGreen}, {"bright_cyan", &result.BrightCyan}, {"bright_blue", &result.BrightBlue}, {"bright_magenta", &result.BrightMagenta}}
	if err := ensureFinalANSIGroupDistinct(result.Background, result.Mode, brightTarget, bright); err != nil {
		return theme.Palette{}, fmt.Errorf("repair bright ANSI collisions: %w", err)
	}
	return result, nil
}

func ensureFinalANSIGroupDistinct(background, mode string, target float64, slots []finalANSISlot) error {
	used := make(map[string]string, len(slots))
	for _, slot := range slots {
		if _, exists := used[*slot.value]; !exists {
			used[*slot.value] = slot.name
			continue
		}
		repaired, err := findDistinctANSIColor(*slot.value, background, mode, target, used)
		if err != nil {
			return fmt.Errorf("%s (%s): %w", slot.name, *slot.value, err)
		}
		*slot.value = repaired
		used[repaired] = slot.name
	}
	return nil
}

func findDistinctANSIColor(value, background, mode string, target float64, used map[string]string) (string, error) {
	original, err := colorspace.OKLCHFromHex(value)
	if err != nil {
		return "", fmt.Errorf("decode %s: %w", value, err)
	}
	for step := 1; step <= 32; step++ {
		chromaStep, lightnessStep := float64(step)*0.004, float64(step)*0.002
		candidates := []colorspace.OKLCH{
			{L: original.L, C: original.C + chromaStep, H: original.H},
			{L: original.L, C: math.Max(0, original.C-chromaStep), H: original.H},
			ansiOutwardCandidate(original, mode, lightnessStep, chromaStep),
			ansiOutwardCandidate(original, mode, lightnessStep, -chromaStep),
		}
		for _, candidate := range candidates {
			candidate.L = clampANSI01(candidate.L)
			candidate.C = math.Max(0, candidate.C)
			hex := colorspace.HexFromOKLCH(candidate)
			if _, exists := used[hex]; exists {
				continue
			}
			ratio, err := contrast.Ratio(hex, background)
			if err != nil {
				return "", fmt.Errorf("measure contrast for %s: %w", hex, err)
			}
			if ratio+1e-9 < target {
				continue
			}
			return hex, nil
		}
	}
	return "", fmt.Errorf("could not find distinct contrast-safe color")
}

func ansiOutwardCandidate(original colorspace.OKLCH, mode string, lightnessStep, chromaStep float64) colorspace.OKLCH {
	result := original
	if mode == "light" {
		result.L -= lightnessStep
	} else {
		result.L += lightnessStep
	}
	result.C += chromaStep
	return result
}

func clampANSI01(value float64) float64 {
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}
