package palette

import "github.com/prettyletto/omagen/backend/internal/theme"

var deepProfile = variantProfile{
	dark: modeProfile{
		backgroundTargetL: 0.12,
		backgroundBlend:   0.60,
		surface:           colorTransform{chromaScale: 1.10, lightnessSpread: 1.40},
		accent:            colorTransform{chromaScale: 1.08, lightnessSpread: 1.08},
		selection:         colorTransform{chromaScale: 1.08, lightnessSpread: 1.22},
		muted:             colorTransform{chromaScale: 0.95, lightnessSpread: 1.00},
		ansi:              colorTransform{chromaScale: 1.04, lightnessSpread: 1.05},
		brightANSI:        colorTransform{chromaScale: 1.06, lightnessSpread: 1.07},
	},
	light: modeProfile{
		backgroundTargetL: 0.82,
		backgroundBlend:   0.65,
		surface:           colorTransform{chromaScale: 1.08, lightnessSpread: 1.22},
		accent:            colorTransform{chromaScale: 1.12, lightnessSpread: 1.08},
		selection:         colorTransform{chromaScale: 1.08, lightnessSpread: 1.14},
		muted:             colorTransform{chromaScale: 0.95, lightnessSpread: 1.00},
		ansi:              colorTransform{chromaScale: 1.05, lightnessSpread: 1.04},
		brightANSI:        colorTransform{chromaScale: 1.08, lightnessSpread: 1.05},
	},
}

func Deep(base theme.Palette) (theme.Palette, error) {
	return applyVariantProfile(base, deepProfile)
}
