package generation

import (
	"fmt"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func cacheSourceImage(
	generationRoot string,
	sourcePath string,
) (string, error) {
	inputDir := filepath.Join(
		generationRoot,
		"input",
	)

	if err := fsutil.EnsureDir(inputDir, 0o755); err != nil {
		return "", fmt.Errorf(
			"create input directory: %w",
			err,
		)
	}

	destination := filepath.Join(
		inputDir,
		"source",
	)

	if err := fsutil.CopyFileAtomicLimited(sourcePath, destination, 0o644, fsutil.MaxFileBytes); err != nil {
		return "", fmt.Errorf(
			"cache source image: %w",
			err,
		)
	}

	return destination, nil
}
