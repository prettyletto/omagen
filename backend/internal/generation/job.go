package generation

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/theme"
)

type job struct {
	variant Variant
}

func (j job) run(
	ctx context.Context,
	generationRoot string,
	sourceImage string,
) error {
	if err := ctx.Err(); err != nil {
		return err
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

	if err := ctx.Err(); err != nil {
		return err
	}

	if err := theme.WriteBackground(
		variantDir,
		sourceImage,
	); err != nil {
		return fmt.Errorf(
			"write background: %w",
			err,
		)
	}

	return ctx.Err()
}
