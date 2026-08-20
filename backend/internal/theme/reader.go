package theme

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func ReadColors(themeDir string) (Palette, error) {
	file, err := os.Open(filepath.Join(themeDir, "colors.toml"))
	if err != nil {
		return Palette{}, fmt.Errorf("open colors.toml: %w", err)
	}
	defer file.Close()
	var palette Palette
	scanner := bufio.NewScanner(file)
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
