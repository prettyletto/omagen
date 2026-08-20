package generation

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type job struct {
	variant     Variant
	sourceImage string
	analysis    *imageanalysis.Analysis
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

	palette := fixturePalette(
		j.variant,
	)

	if err := theme.WriteColors(
		variantDir,
		palette,
	); err != nil {
		return fmt.Errorf(
			"write colors: %w",
			err,
		)
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
