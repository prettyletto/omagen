package imageanalysis

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"

	"github.com/prettyletto/omagen/backend/internal/fsutil"

	_ "golang.org/x/image/bmp"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

const maxPixels int64 = 40_000_000

func DecodeFile(path string) (*Analysis, error) {
	file, err := fsutil.OpenRegularFile(path, fsutil.MaxFileBytes)
	if err != nil {
		return nil, fmt.Errorf("open image: %w", err)
	}
	defer file.Close()

	config, format, err := image.DecodeConfig(file)
	if err != nil {
		return nil, fmt.Errorf("unsupported or invalid image: %w", err)
	}

	if err := validateDimensions(config.Width, config.Height); err != nil {
		return nil, err
	}

	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("rewind image: %w", err)
	}

	decoded, decodedFormat, err := image.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("decode image: %w", err)
	}

	if decodedFormat != format {
		return nil, fmt.Errorf(
			"image format changed during decode: %s -> %s",
			format,
			decodedFormat,
		)
	}

	bounds := decoded.Bounds()

	samples, err := samplePixels(decoded)
	if err != nil {
		return nil, fmt.Errorf(
			"sample image: %w",
			err,
		)
	}

	representatives, err := extractRepresentativeColors(samples)
	if err != nil {
		return nil, fmt.Errorf(
			"extract representative colors: %w",
			err,
		)
	}

	analysis := &Analysis{
		Image:           decoded,
		Width:           bounds.Dx(),
		Height:          bounds.Dy(),
		Format:          format,
		Samples:         samples,
		Representatives: representatives,
	}
	if err := analysis.Validate(); err != nil {
		return nil, err
	}

	return analysis, nil
}

func validateDimensions(width, height int) error {
	if width <= 0 || height <= 0 {
		return fmt.Errorf("invalid image dimensions %dx%d", width, height)
	}

	pixels := int64(width) * int64(height)
	if pixels > maxPixels {
		return fmt.Errorf(
			"image is too large: %dx%d (%d pixels, maximum %d)",
			width, height, pixels, maxPixels,
		)
	}

	return nil
}
