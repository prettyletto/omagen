package theme

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
)

func WriteBackground(
	themeDir string,
	source string,
) error {
	backgroundsDir := filepath.Join(
		themeDir,
		"backgrounds",
	)

	if err := os.Mkdir(
		backgroundsDir,
		0o755,
	); err != nil {
		return fmt.Errorf(
			"create backgrounds directory: %w",
			err,
		)
	}

	extension := filepath.Ext(source)

	destination := filepath.Join(
		backgroundsDir,
		"wallpaper"+extension,
	)

	if err := os.Link(
		source,
		destination,
	); err == nil {
		return nil
	}

	// Fallback in case hardlinks are unavailable.
	if err := copyBackground(
		source,
		destination,
	); err != nil {
		return fmt.Errorf(
			"write wallpaper: %w",
			err,
		)
	}

	return nil
}

func copyBackground(
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
