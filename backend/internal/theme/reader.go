package theme

import (
	"bufio"
	"fmt"
	"math"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
)

func ReadColors(themeDir string) (Palette, error) {
	data, err := fsutil.ReadFileLimited(filepath.Join(themeDir, "colors.toml"), fsutil.MaxStateFileBytes)
	if err != nil {
		return Palette{}, fmt.Errorf("open colors.toml: %w", err)
	}
	var palette Palette
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, raw, ok := strings.Cut(line, "=")
		if !ok {
			return Palette{}, fmt.Errorf("invalid colors.toml line %q", line)
		}
		value, err := strconv.Unquote(strings.TrimSpace(raw))
		if err != nil {
			return Palette{}, fmt.Errorf("decode %s: %w", strings.TrimSpace(key), err)
		}
		switch strings.TrimSpace(key) {
		case "mode":
			palette.Mode = value
		case "accent":
			palette.Accent = value
		case "selection":
			palette.Selection = value
		case "muted":
			palette.Muted = value
		case "background":
			palette.Background = value
		case "dark_background":
			palette.DarkBackground = value
		case "darker_background":
			palette.DarkerBackground = value
		case "lighter_background":
			palette.LighterBackground = value
		case "foreground":
			palette.Foreground = value
		case "dark_foreground":
			palette.DarkForeground = value
		case "light_foreground":
			palette.LightForeground = value
		case "bright_foreground":
			palette.BrightForeground = value
		case "red":
			palette.Red = value
		case "yellow":
			palette.Yellow = value
		case "orange":
			palette.Orange = value
		case "green":
			palette.Green = value
		case "cyan":
			palette.Cyan = value
		case "blue":
			palette.Blue = value
		case "magenta":
			palette.Magenta = value
		case "brown":
			palette.Brown = value
		case "bright_red":
			palette.BrightRed = value
		case "bright_yellow":
			palette.BrightYellow = value
		case "bright_green":
			palette.BrightGreen = value
		case "bright_cyan":
			palette.BrightCyan = value
		case "bright_blue":
			palette.BrightBlue = value
		case "bright_magenta":
			palette.BrightMagenta = value
		}
	}
	if err := scanner.Err(); err != nil {
		return Palette{}, fmt.Errorf("read colors.toml: %w", err)
	}
	if err := palette.Validate(); err != nil {
		return Palette{}, fmt.Errorf("validate colors.toml: %w", err)
	}
	return palette, nil
}

// ReadSharedWindowOpacity recovers Omagen's shared steady-state window
// opacity from an existing Hyprland theme. It deliberately accepts a value
// only when active and inactive opacity are both explicitly present and
// equal: the Studio control owns one shared value and must not flatten a
// user-authored asymmetric compositor configuration.
//
// This is a migration reader for themes written before the value was added to
// omagen.theme-recipe.json. New themes use their recipe sidecar directly.
func ReadSharedWindowOpacity(themeDir string) (*int, error) {
	data, err := fsutil.ReadFileLimited(filepath.Join(themeDir, "hyprland.lua"), fsutil.MaxStateFileBytes)
	if err != nil {
		return nil, err
	}
	active, activeSet := luaOpacitySetting(string(data), "active_opacity")
	inactive, inactiveSet := luaOpacitySetting(string(data), "inactive_opacity")
	if !activeSet || !inactiveSet || math.Abs(active-inactive) > 0.000001 {
		return nil, nil
	}
	percent := int(math.Round(active * 100))
	if percent < 0 || percent > 100 {
		return nil, nil
	}
	return &percent, nil
}

func luaOpacitySetting(source, key string) (float64, bool) {
	var value float64
	found := false
	scanner := bufio.NewScanner(strings.NewReader(source))
	for scanner.Scan() {
		line := strings.TrimSpace(strings.SplitN(scanner.Text(), "--", 2)[0])
		name, raw, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(name) != key {
			continue
		}
		parsed, err := strconv.ParseFloat(strings.TrimSpace(strings.TrimSuffix(raw, ",")), 64)
		if err != nil || parsed < 0 || parsed > 1 {
			continue
		}
		value, found = parsed, true
	}
	return value, found
}
