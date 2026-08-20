package theme

import (
	"fmt"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func WriteBackground(
	themeDir string,
	source string,
	extension string,
) error {
	backgroundsDir := filepath.Join(
		themeDir,
		"backgrounds",
	)

	if err := fsutil.EnsureDir(backgroundsDir, 0o755); err != nil {
		return fmt.Errorf(
			"create backgrounds directory: %w",
			err,
		)
	}

	destination := filepath.Join(
		backgroundsDir,
		"wallpaper"+extension,
	)

	if err := fsutil.LinkOrCopyAtomic(source, destination, 0o644); err != nil {
		return fmt.Errorf(
			"write wallpaper: %w",
			err,
		)
	}

	return nil
}
