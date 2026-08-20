package palette

import (
	"github.com/prettyletto/omagen/backend/internal/colorspace"
	"github.com/prettyletto/omagen/backend/internal/imageanalysis"
	"github.com/prettyletto/omagen/backend/internal/theme"
)

type ansiRole struct{ targetHue, familyShift, chromaScale, darkL, lightL float64 }

var ansiRoles = struct{ Red, Orange, Yellow, Green, Cyan, Blue, Magenta, Brown ansiRole }{
	Red: ansiRole{25, 0, 1.00, .66, .52}, Orange: ansiRole{55, 18, .88, .68, .53},
	Yellow: ansiRole{95, 36, .78, .70, .55}, Green: ansiRole{145, 22, .64, .63, .47},
	Cyan: ansiRole{195, 14, .70, .71, .56}, Blue: ansiRole{255, -29, .62, .67, .50},
	Magenta: ansiRole{320, -14, .84, .68, .51}, Brown: ansiRole{55, 9, .44, .52, .42},
}

type identityANSISet struct{ Red, Orange, Yellow, Green, Cyan, Blue, Magenta, Brown colorspace.OKLCH }

func applyANSI(result *theme.Palette, colors []imageanalysis.RepresentativeColor, accent colorspace.OKLCH) {
	ansi := buildIdentityANSI(analyzeSourceIdentity(colors, accent), result.Mode)
	result.Red, result.Orange, result.Yellow, result.Green = semanticColor(ansi.Red.L, ansi.Red.C, ansi.Red.H), semanticColor(ansi.Orange.L, ansi.Orange.C, ansi.Orange.H), semanticColor(ansi.Yellow.L, ansi.Yellow.C, ansi.Yellow.H), semanticColor(ansi.Green.L, ansi.Green.C, ansi.Green.H)
	result.Cyan, result.Blue, result.Magenta, result.Brown = semanticColor(ansi.Cyan.L, ansi.Cyan.C, ansi.Cyan.H), semanticColor(ansi.Blue.L, ansi.Blue.C, ansi.Blue.H), semanticColor(ansi.Magenta.L, ansi.Magenta.C, ansi.Magenta.H), semanticColor(ansi.Brown.L, ansi.Brown.C, ansi.Brown.H)
	bright := []struct {
		value *string
		base  colorspace.OKLCH
	}{{&result.BrightRed, ansi.Red}, {&result.BrightYellow, ansi.Yellow}, {&result.BrightGreen, ansi.Green}, {&result.BrightCyan, ansi.Cyan}, {&result.BrightBlue, ansi.Blue}, {&result.BrightMagenta, ansi.Magenta}}
	for _, item := range bright {
		color := brightenANSI(item.base, result.Mode)
		*item.value = semanticColor(color.L, color.C, color.H)
	}
}

func buildIdentityANSI(identity sourceIdentity, mode string) identityANSISet {
	if !identity.chromatic || len(identity.families) == 0 {
		return neutralANSISet(mode)
	}
	usage := make([]int, len(identity.families))
	return identityANSISet{
		Red: sourceFamilyANSI(identity, ansiRoles.Red, mode, usage), Orange: sourceFamilyANSI(identity, ansiRoles.Orange, mode, usage),
		Yellow: sourceFamilyANSI(identity, ansiRoles.Yellow, mode, usage), Green: sourceFamilyANSI(identity, ansiRoles.Green, mode, usage),
		Cyan: sourceFamilyANSI(identity, ansiRoles.Cyan, mode, usage), Blue: sourceFamilyANSI(identity, ansiRoles.Blue, mode, usage),
		Magenta: sourceFamilyANSI(identity, ansiRoles.Magenta, mode, usage), Brown: sourceFamilyANSI(identity, ansiRoles.Brown, mode, usage),
	}
}

func accentFamilyANSISet(anchor colorspace.OKLCH, mode string) identityANSISet {
	return identityANSISet{Red: narrowFamilyANSI(anchor, ansiRoles.Red, mode), Orange: narrowFamilyANSI(anchor, ansiRoles.Orange, mode), Yellow: narrowFamilyANSI(anchor, ansiRoles.Yellow, mode), Green: narrowFamilyANSI(anchor, ansiRoles.Green, mode), Cyan: narrowFamilyANSI(anchor, ansiRoles.Cyan, mode), Blue: narrowFamilyANSI(anchor, ansiRoles.Blue, mode), Magenta: narrowFamilyANSI(anchor, ansiRoles.Magenta, mode), Brown: narrowFamilyANSI(anchor, ansiRoles.Brown, mode)}
}

func narrowFamilyANSI(anchor colorspace.OKLCH, role ansiRole, mode string) colorspace.OKLCH {
	l := role.darkL
	if mode == "light" {
		l = role.lightL
	}
	c := clampValue(anchor.C*role.chromaScale, .055, .20)
	if role == ansiRoles.Brown {
		c = clampValue(anchor.C*role.chromaScale, .035, .095)
	}
	return colorspace.OKLCH{L: l, C: c, H: normalizeHue(anchor.H + role.familyShift)}
}

func sourceFamilyANSI(identity sourceIdentity, role ansiRole, mode string, usage []int) colorspace.OKLCH {
	i := nearestIdentityFamily(identity.families, role.targetHue, usage)
	usage[i]++
	color := colorspace.OKLCH{L: identity.families[i].L, C: identity.families[i].C, H: identity.families[i].H}
	if role == ansiRoles.Brown {
		color.C *= .55
		if mode == "light" {
			color.L = clampValue(color.L, .35, .50)
		} else {
			color.L = clampValue(color.L, .40, .55)
		}
		return color
	}
	return normalizeANSI(color, mode)
}

func neutralANSISet(mode string) identityANSISet {
	return identityANSISet{Red: neutralANSI(ansiRoles.Red, mode), Orange: neutralANSI(ansiRoles.Orange, mode), Yellow: neutralANSI(ansiRoles.Yellow, mode), Green: neutralANSI(ansiRoles.Green, mode), Cyan: neutralANSI(ansiRoles.Cyan, mode), Blue: neutralANSI(ansiRoles.Blue, mode), Magenta: neutralANSI(ansiRoles.Magenta, mode), Brown: neutralANSI(ansiRoles.Brown, mode)}
}
func neutralANSI(role ansiRole, mode string) colorspace.OKLCH {
	l := role.darkL
	if mode == "light" {
		l = role.lightL
	}
	return colorspace.OKLCH{L: l}
}

func normalizeANSI(color colorspace.OKLCH, mode string) colorspace.OKLCH {
	if mode == "light" {
		color.L = clampValue(color.L, .42, .62)
	} else {
		color.L = clampValue(color.L, .56, .76)
	}
	color.C = clampValue(color.C, .055, .20)
	return color
}

func brightenANSI(color colorspace.OKLCH, mode string) colorspace.OKLCH {
	if mode == "light" {
		color.L = clampValue(color.L+.07, .50, .68)
	} else {
		color.L = clampValue(color.L+.09, .65, .84)
	}
	if color.C < identityChromaThreshold {
		color.C = 0
		return color
	}
	color.C = clampValue(color.C*1.08, .060, .22)
	return color
}
