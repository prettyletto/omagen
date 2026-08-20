package palette

import "github.com/prettyletto/omagen/backend/internal/theme"

var muteProfile = variantProfile{
	dark: modeProfile{
		backgroundTargetL: 0.18,
		backgroundBlend:   0.0,
		surface:           colorTransform{chromaScale: 0.38, lightnessSpread: 0.72},
		accent:            colorTransform{chromaScale: 0.52, lightnessSpread: 0.96},
		selection:         colorTransform{chromaScale: 0.42, lightnessSpread: 0.78},
		muted:             colorTransform{chromaScale: 0.35, lightnessSpread: 0.96},
		ansi:              colorTransform{chromaScale: 0.52, lightnessSpread: 0.96},
		brightANSI:        colorTransform{chromaScale: 0.60, lightnessSpread: 0.98},
	},
	light: modeProfile{
		backgroundTargetL: 0.89,
		backgroundBlend:   0.60,
		surface:           colorTransform{chromaScale: 0.20, lightnessSpread: 0.74},
		accent:            colorTransform{chromaScale: 0.28, lightnessSpread: 0.95},
		selection:         colorTransform{chromaScale: 0.22, lightnessSpread: 0.80},
		muted:             colorTransform{chromaScale: 0.20, lightnessSpread: 0.95},
		ansi:              colorTransform{chromaScale: 0.35, lightnessSpread: 0.95},
		brightANSI:        colorTransform{chromaScale: 0.42, lightnessSpread: 0.97},
	},
}

func Mute(base theme.Palette) (theme.Palette, error) {
	return applyVariantProfile(base, muteProfile)
}
