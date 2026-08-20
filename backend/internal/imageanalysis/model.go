package imageanalysis

import (
	"fmt"
	"image"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
)

type Sample struct {
	R uint8
	G uint8
	B uint8
	A uint8

	Lab colorspace.OKLab
}

type RepresentativeColor struct {
	Lab      colorspace.OKLab
	LCH      colorspace.OKLCH
	Coverage float64
}

type Analysis struct {
	Image           image.Image
	Width           int
	Height          int
	Format          string
	Samples         []Sample
	Representatives []RepresentativeColor
}

func (a *Analysis) Validate() error {
	if a == nil {
		return fmt.Errorf("analysis is nil")
	}

	if a.Image == nil {
		return fmt.Errorf("decoded image is nil")
	}

	if a.Width <= 0 || a.Height <= 0 {
		return fmt.Errorf(
			"invalid dimensions %dx%d",
			a.Width,
			a.Height,
		)
	}

	if a.Format == "" {
		return fmt.Errorf("image format is empty")
	}

	if len(a.Samples) == 0 {
		return fmt.Errorf("image has no usable pixel samples")
	}

	if len(a.Representatives) == 0 {
		return fmt.Errorf("image has no representative colors")
	}

	return nil
}

func (a *Analysis) Extension() (string, error) {
	switch a.Format {
	case "jpeg":
		return ".jpg", nil
	case "png":
		return ".png", nil
	case "gif":
		return ".gif", nil
	case "webp":
		return ".webp", nil
	case "bmp":
		return ".bmp", nil
	case "tiff":
		return ".tiff", nil
	default:
		return "", fmt.Errorf(
			"unsupported decoded format %q",
			a.Format,
		)
	}
}
