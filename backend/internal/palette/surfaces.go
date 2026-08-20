package palette

import (
	"fmt"

	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

func NormalizeSurfaceHierarchy(p theme.Palette) (theme.Palette, error) {
	if err := p.Validate(); err != nil {
		return theme.Palette{}, fmt.Errorf("validate palette: %w", err)
	}

	background, err := colorspace.OKLCHFromHex(p.Background)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("parse background: %w", err)
	}
	dark, err := colorspace.OKLCHFromHex(p.DarkBackground)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("parse dark background: %w", err)
	}
	darker, err := colorspace.OKLCHFromHex(p.DarkerBackground)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("parse darker background: %w", err)
	}
	lighter, err := colorspace.OKLCHFromHex(p.LighterBackground)
	if err != nil {
		return theme.Palette{}, fmt.Errorf("parse lighter background: %w", err)
	}

	if p.Mode == "dark" {
		darker.L = clampValue(background.L-0.06, 0, 1)
		dark.L = clampValue(background.L-0.03, 0, 1)
		lighter.L = clampValue(background.L+0.08, 0, 1)
	} else {
		darker.L = clampValue(background.L-0.08, 0, 1)
		dark.L = clampValue(background.L-0.04, 0, 1)
		lighter.L = clampValue(background.L+0.03, 0, 1)
	}

	p.DarkerBackground = colorspace.HexFromOKLCH(darker)
	p.DarkBackground = colorspace.HexFromOKLCH(dark)
	p.LighterBackground = colorspace.HexFromOKLCH(lighter)
	return p, nil
}
