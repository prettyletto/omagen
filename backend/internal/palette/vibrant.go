package palette

import "github.com/prettyletto/omagen/backend/internal/theme"

// Vibrant emphasizes perceptual color intensity while preserving tonal identity.
var vibrantProfile = variantProfile{
	dark: modeProfile{
		backgroundTargetL: 0.18, backgroundBlend: 0,
		surface:    colorTransform{chromaScale: 1.08, chromaTarget: 0.075, chromaBlend: 0.42, lightnessSpread: 1.02},
		accent:     colorTransform{chromaScale: 1.10, chromaTarget: 0.20, chromaBlend: 0.65, lightnessSpread: 1.02},
		selection:  colorTransform{chromaScale: 1.08, chromaTarget: 0.11, chromaBlend: 0.48, lightnessSpread: 1.04},
		muted:      colorTransform{chromaScale: 0.95, chromaTarget: 0.045, chromaBlend: 0.20, lightnessSpread: 1.00},
		ansi:       colorTransform{chromaScale: 1.08, chromaTarget: 0.17, chromaBlend: 0.60, lightnessSpread: 1.00},
		brightANSI: colorTransform{chromaScale: 1.10, chromaTarget: 0.19, chromaBlend: 0.62, lightnessSpread: 1.00},
	},
	light: modeProfile{
		backgroundTargetL: 0.91, backgroundBlend: 0.20,
		surface:    colorTransform{chromaScale: 1.08, chromaTarget: 0.065, chromaBlend: 0.55, lightnessSpread: 1.02},
		accent:     colorTransform{chromaScale: 1.10, chromaTarget: 0.18, chromaBlend: 0.72, lightnessSpread: 1.00},
		selection:  colorTransform{chromaScale: 1.08, chromaTarget: 0.095, chromaBlend: 0.58, lightnessSpread: 1.02},
		muted:      colorTransform{chromaScale: 0.95, chromaTarget: 0.040, chromaBlend: 0.20, lightnessSpread: 1.00},
		ansi:       colorTransform{chromaScale: 1.08, chromaTarget: 0.15, chromaBlend: 0.68, lightnessSpread: 1.00},
		brightANSI: colorTransform{chromaScale: 1.10, chromaTarget: 0.17, chromaBlend: 0.70, lightnessSpread: 1.00},
	},
}

func Vibrant(base theme.Palette) (theme.Palette, error) {
	return applyVariantProfile(base, vibrantProfile)
}
