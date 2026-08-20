package generation

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func cacheSourceImage(
	generationRoot string,
	sourcePath string,
) (string, error) {
	extension := strings.ToLower(
		filepath.Ext(sourcePath),
	)

	switch extension {
	case ".png", ".jpg", ".jpeg", ".webp":
	default:
		return "", fmt.Errorf(
			"unsupported image format %q",
			extension,
		)
	}

	inputDir := filepath.Join(
		generationRoot,
		"input",
	)

	if err := os.Mkdir(
		inputDir,
		0o755,
	); err != nil {
		return "", fmt.Errorf(
			"create input directory: %w",
			err,
		)
	}

	destination := filepath.Join(
		inputDir,
		"source"+extension,
	)

	if err := copyFile(
		sourcePath,
		destination,
	); err != nil {
		return "", fmt.Errorf(
			"cache source image: %w",
			err,
		)
	}

	return destination, nil
}

func copyFile(
	source string,
	destination string,
) error {
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()

	output, err := os.OpenFile(
		destination,
		os.O_CREATE|os.O_EXCL|os.O_WRONLY,
		0o644,
	)
	if err != nil {
		return err
	}

	_, copyErr := io.Copy(
		output,
		input,
	)

	closeErr := output.Close()

	if copyErr != nil {
		return copyErr
	}

	return closeErr
}
