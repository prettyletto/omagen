package palette

import "github.com/prettyletto/omagen/backend/internal/theme"

var calmProfile = variantProfile{
	dark: modeProfile{
		backgroundTargetL: 0.18,
		backgroundBlend:   0.0,
		surface:           colorTransform{chromaScale: 0.72, lightnessSpread: 0.84},
		accent:            colorTransform{chromaScale: 0.78, lightnessSpread: 1.0},
		selection:         colorTransform{chromaScale: 0.72, lightnessSpread: 0.88},
		muted:             colorTransform{chromaScale: 0.72, lightnessSpread: 1.0},
		ansi:              colorTransform{chromaScale: 0.78, lightnessSpread: 1.0},
		brightANSI:        colorTransform{chromaScale: 0.82, lightnessSpread: 1.0},
	},
	light: modeProfile{
		backgroundTargetL: 0.93,
		backgroundBlend:   0.35,
		surface:           colorTransform{chromaScale: 0.58, lightnessSpread: 0.84},
		accent:            colorTransform{chromaScale: 0.68, lightnessSpread: 1.0},
		selection:         colorTransform{chromaScale: 0.60, lightnessSpread: 0.86},
		muted:             colorTransform{chromaScale: 0.60, lightnessSpread: 1.0},
		ansi:              colorTransform{chromaScale: 0.70, lightnessSpread: 1.0},
		brightANSI:        colorTransform{chromaScale: 0.76, lightnessSpread: 1.0},
	},
}

func Calm(base theme.Palette) (theme.Palette, error) {
	return applyVariantProfile(base, calmProfile)
}
