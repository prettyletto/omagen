package generation

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func findThemeBackground(themeDir string) (string, error) {
	entries, err := os.ReadDir(filepath.Join(themeDir, "backgrounds"))
	if err != nil {
		return "", fmt.Errorf("read theme backgrounds: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 {
			continue
		}
		ext := strings.ToLower(filepath.Ext(entry.Name()))
		switch ext {
		case ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff":
			info, statErr := entry.Info()
			if statErr == nil && info.Mode().IsRegular() && info.Size() > 0 {
				return filepath.Join(themeDir, "backgrounds", entry.Name()), nil
			}
		}
	}
	return "", fmt.Errorf("theme has no supported background image")
}

func copyMissingTree(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := destination
		if relative != "." {
			target = filepath.Join(destination, relative)
		}
		if entry.IsDir() {
			return fsutil.EnsureDir(target, 0o755)
		}
		if entry.Type()&os.ModeSymlink != 0 || !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported theme entry %s", relative)
		}
		if _, statErr := os.Lstat(target); statErr == nil {
			return nil
		} else if !os.IsNotExist(statErr) {
			return statErr
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		return fsutil.CopyFileAtomic(path, target, info.Mode().Perm())
	})
}

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
