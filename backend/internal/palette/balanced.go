package palette

import "github.com/prettyletto/omagen/backend/internal/theme"

// Balanced gently normalizes the source palette toward a general-purpose theme.
var balancedProfile = variantProfile{
	dark: modeProfile{
		backgroundTargetL: 0.16, backgroundBlend: 0.46,
		surface:    colorTransform{chromaScale: 1.00, chromaTarget: 0.045, chromaBlend: 0.42, lightnessSpread: 1.04},
		accent:     colorTransform{chromaScale: 1.00, chromaTarget: 0.135, chromaBlend: 0.52, lightnessSpread: 1.00},
		selection:  colorTransform{chromaScale: 1.00, chromaTarget: 0.075, chromaBlend: 0.46, lightnessSpread: 1.04},
		muted:      colorTransform{chromaScale: 1.00, chromaTarget: 0.028, chromaBlend: 0.34, lightnessSpread: 1.00},
		ansi:       colorTransform{chromaScale: 1.00, chromaTarget: 0.115, chromaBlend: 0.48, lightnessSpread: 1.00},
		brightANSI: colorTransform{chromaScale: 1.00, chromaTarget: 0.135, chromaBlend: 0.50, lightnessSpread: 1.00},
	},
	light: modeProfile{
		backgroundTargetL: 0.89, backgroundBlend: 0.46,
		surface:    colorTransform{chromaScale: 1.00, chromaTarget: 0.038, chromaBlend: 0.40, lightnessSpread: 1.04},
		accent:     colorTransform{chromaScale: 1.00, chromaTarget: 0.115, chromaBlend: 0.52, lightnessSpread: 1.00},
		selection:  colorTransform{chromaScale: 1.00, chromaTarget: 0.065, chromaBlend: 0.46, lightnessSpread: 1.02},
		muted:      colorTransform{chromaScale: 1.00, chromaTarget: 0.025, chromaBlend: 0.34, lightnessSpread: 1.00},
		ansi:       colorTransform{chromaScale: 1.00, chromaTarget: 0.105, chromaBlend: 0.50, lightnessSpread: 1.00},
		brightANSI: colorTransform{chromaScale: 1.00, chromaTarget: 0.125, chromaBlend: 0.52, lightnessSpread: 1.00},
	},
}

func Balanced(base theme.Palette) (theme.Palette, error) {
	return applyVariantProfile(base, balancedProfile)
}
