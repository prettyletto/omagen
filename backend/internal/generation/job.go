package generation

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
)

type job struct {
	variant Variant
}

func (j job) run(
	ctx context.Context,
	generationRoot string,
) error {
	if err := ctx.Err(); err != nil {
		return err
	}

	variantDir := filepath.Join(
		generationRoot,
		string(j.variant),
	)

	if err := os.Mkdir(variantDir, 0o755); err != nil {
		return fmt.Errorf(
			"create variant directory: %w",
			err,
		)
	}

	if err := ctx.Err(); err != nil {
		return err
	}
	return nil
}
