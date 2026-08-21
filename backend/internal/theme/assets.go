package theme

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"os"
	"path/filepath"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	_ "golang.org/x/image/bmp"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

const (
	previewWidth        = 1920
	previewHeight       = 1080
	unlockWidth         = 800
	unlockHeight        = 450
	unlockPreviewWidth  = 1920
	unlockPreviewHeight = 1080
)

// WritePreview converts a captured screen into the canonical 16:9 gallery
// image used by Omarchy themes. The center crop avoids stretching ultrawide
// or taller displays and keeps the result stable across monitor sizes.
func WritePreview(themeDir, sourcePath string) error {
	return WritePreviewFile(filepath.Join(themeDir, "preview.png"), sourcePath)
}

// WritePreviewFile is the same normalization used for a theme preview, but
// allows the Apply session to stage the result outside the candidate first.
func WritePreviewFile(destination, sourcePath string) error {
	return writeNormalizedPNG(destination, sourcePath, previewWidth, previewHeight)
}

// WriteUnlock creates the Plymouth unlock artwork and its switcher preview
// from the selected source image. Omarchy's Plymouth switcher discovers
// themes through preview-unlock.png, while Plymouth itself consumes
// unlock.png.
func WriteUnlock(themeDir, sourcePath string) error {
	unlockPath := filepath.Join(themeDir, "unlock.png")
	if err := writeNormalizedPNG(unlockPath, sourcePath, unlockWidth, unlockHeight); err != nil {
		return err
	}
	return writeUnlockPreview(filepath.Join(themeDir, "preview-unlock.png"), unlockPath)
}

func writeUnlockPreview(destination, unlockPath string) error {
	file, err := os.Open(unlockPath)
	if err != nil {
		return fmt.Errorf("open unlock image: %w", err)
	}
	defer file.Close()

	unlock, err := png.Decode(file)
	if err != nil {
		return fmt.Errorf("decode unlock image: %w", err)
	}

	result := image.NewRGBA(image.Rect(0, 0, unlockPreviewWidth, unlockPreviewHeight))
	draw.Draw(result, result.Bounds(), image.NewUniform(color.Black), image.Point{}, draw.Src)
	bounds := unlock.Bounds()
	x := (unlockPreviewWidth - bounds.Dx()) / 2
	y := (unlockPreviewHeight - bounds.Dy()) / 2
	draw.Draw(result, image.Rect(x, y, x+bounds.Dx(), y+bounds.Dy()), unlock, bounds.Min, draw.Over)

	var encoded bytes.Buffer
	if err := png.Encode(&encoded, result); err != nil {
		return fmt.Errorf("encode unlock preview: %w", err)
	}
	if err := fsutil.AtomicWriteFile(destination, encoded.Bytes(), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", destination, err)
	}
	return nil
}

func writeNormalizedPNG(destination, sourcePath string, width, height int) error {
	file, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("open image: %w", err)
	}
	defer file.Close()

	source, _, err := image.Decode(file)
	if err != nil {
		return fmt.Errorf("decode image: %w", err)
	}
	cropped, err := centerCrop16x9(source)
	if err != nil {
		return err
	}

	result := image.NewRGBA(image.Rect(0, 0, width, height))
	draw.CatmullRom.Scale(result, result.Bounds(), cropped, cropped.Bounds(), draw.Src, nil)

	var encoded bytes.Buffer
	if err := png.Encode(&encoded, result); err != nil {
		return fmt.Errorf("encode PNG: %w", err)
	}
	if err := fsutil.AtomicWriteFile(destination, encoded.Bytes(), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", destination, err)
	}
	return nil
}

func centerCrop16x9(source image.Image) (image.Image, error) {
	if source == nil {
		return nil, fmt.Errorf("image is nil")
	}
	bounds := source.Bounds()
	if bounds.Dx() <= 0 || bounds.Dy() <= 0 {
		return nil, fmt.Errorf("image has invalid dimensions %dx%d", bounds.Dx(), bounds.Dy())
	}

	const aspect = 16.0 / 9.0
	width, height := bounds.Dx(), bounds.Dy()
	if float64(width)/float64(height) > aspect {
		width = int(float64(height) * aspect)
	} else {
		height = int(float64(width) / aspect)
	}
	if width < 1 || height < 1 {
		return nil, fmt.Errorf("image is too small to crop to 16:9")
	}
	x := bounds.Min.X + (bounds.Dx()-width)/2
	y := bounds.Min.Y + (bounds.Dy()-height)/2
	result := image.NewRGBA(image.Rect(0, 0, width, height))
	draw.Draw(result, result.Bounds(), source, image.Point{X: x, Y: y}, draw.Src)
	return result, nil
}
