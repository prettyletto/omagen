package apply

import (
	"fmt"
	"strings"
	"unicode"
)

const maxThemeNameLength = 64

type themeName struct {
	Display string
	Slug    string
}

func parseThemeName(input string) (themeName, error) {
	display := strings.TrimSpace(input)
	if display == "" {
		return themeName{}, fmt.Errorf("theme name cannot be empty")
	}
	if len([]rune(display)) > maxThemeNameLength {
		return themeName{}, fmt.Errorf("theme name must be %d characters or fewer", maxThemeNameLength)
	}
	var builder strings.Builder
	pendingDash := false
	for _, r := range strings.ToLower(display) {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r):
			if pendingDash && builder.Len() > 0 {
				builder.WriteByte('-')
			}
			builder.WriteRune(r)
			pendingDash = false
		case r == '-', r == '_', unicode.IsSpace(r):
			pendingDash = builder.Len() > 0
		default:
			pendingDash = builder.Len() > 0
		}
	}
	slug := strings.Trim(builder.String(), "-")
	if slug == "" {
		return themeName{}, fmt.Errorf("theme name contains no usable characters")
	}
	return themeName{Display: display, Slug: slug}, nil
}
