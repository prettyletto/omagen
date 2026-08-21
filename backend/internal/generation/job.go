package generation

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/contrast"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	semanticpalette "github.com/prettyletto/omagen/backend/internal/palette"
	"github.com/prettyletto/omagen/backend/internal/session"
	settingspkg "github.com/prettyletto/omagen/backend/internal/settings"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type job struct {
	variant      Variant
	sourceImage  string
	analysis     *imageanalysis.Analysis
	settings     settingspkg.Settings
	shellStyle   session.ShellStyle
	desktopStyle session.DesktopStyle
	barStyle     session.BarStyle
}

func (j job) run(
	ctx context.Context,
	generationRoot string,
) error {
	if err := ctx.Err(); err != nil {
		return err
	}

	if err := j.analysis.Validate(); err != nil {
		return fmt.Errorf(
			"invalid image analysis: %w",
			err,
		)
	}

	variantDir := filepath.Join(
		generationRoot,
		string(j.variant),
	)

	if err := os.Mkdir(
		variantDir,
		0o755,
	); err != nil {
		return fmt.Errorf(
			"create variant directory: %w",
			err,
		)
	}

	if err := ctx.Err(); err != nil {
		return err
	}

	var generatedPalette theme.Palette
	switch j.variant {
	case Source:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build source palette: %w", err)
		}
		generatedPalette = basePalette

	case Calm:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build calm base palette: %w", err)
		}
		generatedPalette, err = semanticpalette.Calm(basePalette)
		if err != nil {
			return fmt.Errorf("build calm palette: %w", err)
		}

	case Mute:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build mute base palette: %w", err)
		}
		generatedPalette, err = semanticpalette.Mute(basePalette)
		if err != nil {
			return fmt.Errorf("build mute palette: %w", err)
		}

	case Deep:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build deep base palette: %w", err)
		}
		generatedPalette, err = semanticpalette.Deep(basePalette)
		if err != nil {
			return fmt.Errorf("build deep palette: %w", err)
		}
		generatedPalette, err = semanticpalette.NormalizeSurfaceHierarchy(generatedPalette)
		if err != nil {
			return fmt.Errorf("normalize deep surfaces: %w", err)
		}

	case Vibrant:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build vibrant base palette: %w", err)
		}
		generatedPalette, err = semanticpalette.Vibrant(basePalette)
		if err != nil {
			return fmt.Errorf("build vibrant palette: %w", err)
		}

	case Balanced:
		basePalette, err := semanticpalette.Source(
			j.analysis.Representatives,
			j.settings.ColorTheory.Harmony,
		)
		if err != nil {
			return fmt.Errorf("build balanced base palette: %w", err)
		}
		generatedPalette, err = semanticpalette.Balanced(basePalette)
		if err != nil {
			return fmt.Errorf("build balanced palette: %w", err)
		}

	default:
		return fmt.Errorf("unsupported generation variant %q", j.variant)
	}

	if j.variant == Source || j.variant == Calm || j.variant == Mute || j.variant == Deep || j.variant == Vibrant || j.variant == Balanced {
		var err error
		generatedPalette, err = contrast.Enforce(generatedPalette, j.settings.Contrast)
		if err != nil {
			return fmt.Errorf("enforce %s contrast: %w", j.variant, err)
		}
		generatedPalette, err = semanticpalette.EnsureANSIDistinctAfterContrast(
			generatedPalette,
			j.settings.Contrast.ANSI,
			j.settings.Contrast.BrightANSI,
		)
		if err != nil {
			return fmt.Errorf("finalize ANSI palette for %s: %w", j.variant, err)
		}
	}

	if err := theme.WriteColors(
		variantDir,
		generatedPalette,
	); err != nil {
		return fmt.Errorf(
			"write colors: %w",
			err,
		)
	}
	if j.shellStyle.Valid() && j.barStyle.Valid() {
		if err := theme.WriteShell(
			variantDir,
			generatedPalette,
			j.shellStyle.Surface,
			j.shellStyle.Detail,
			j.barStyle.Surface,
			j.barStyle.Density,
			j.barStyle.Attention,
			j.barStyle.Form,
		); err != nil {
			return fmt.Errorf("write shell style: %w", err)
		}
	}
	if j.desktopStyle.Valid() {
		if err := theme.WriteHyprland(variantDir, generatedPalette, j.desktopStyle.BorderStyle, j.desktopStyle.Shape, j.desktopStyle.Spacing, j.desktopStyle.Depth); err != nil {
			return fmt.Errorf("write hyprland style: %w", err)
		}
	}
	extension, err := j.analysis.Extension()
	if err != nil {
		return fmt.Errorf(
			"resolve image extension: %w",
			err,
		)
	}

	if err := ctx.Err(); err != nil {
		return err
	}

	if err := theme.WriteBackground(
		variantDir,
		j.sourceImage,
		extension,
	); err != nil {
		return fmt.Errorf(
			"write background: %w",
			err,
		)
	}

	return ctx.Err()
}
