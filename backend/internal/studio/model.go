package studio

import (
	"bufio"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type Color struct {
	Name string
	Hex  string
}

var paletteOrder = []string{
	"background",
	"foreground",
	"accent",
	"selection",
	"red",
	"orange",
	"yellow",
	"green",
	"cyan",
	"blue",
	"magenta",
}

var paletteFallbacks = map[string]string{
	"background": "#161616",
	"foreground": "#f9e7c7",
	"muted":      "#7c7466",
	"accent":     "#ecb54f",
	"selection":  "#ecb54f",
	"red":        "#79581e",
	"orange":     "#966a1c",
	"yellow":     "#b37d19",
	"green":      "#a4a611",
	"cyan":       "#e7d121",
	"blue":       "#dd3817",
	"magenta":    "#e66c18",
}

const omagenASCII = ` ██████╗ ███╗   ███╗  █████╗  ██████╗ ███████╗███╗   ██╗
██╔═══██╗████╗ ████║ ██╔══██╗██╔════╝ ██╔════╝████╗  ██║
██║   ██║██╔████╔██║ ███████║██║  ███╗█████╗  ██╔██╗ ██║
██║   ██║██║╚██╔╝██║ ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║
╚██████╔╝██║ ╚═╝ ██║ ██║  ██║╚██████╔╝███████╗██║ ╚████║
 ╚═════╝ ╚═╝     ╚═╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝`

const studioASCII = ` ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗
 ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗
 ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║
 ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║
 ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝
 ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝`

type Palette map[string]string

const palettePollInterval = 250 * time.Millisecond

type palettePollMsg struct {
	path      string
	palette   Palette
	signature string
}

func CurrentPalettePath() string {
	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		home, _ := os.UserHomeDir()
		stateHome = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(stateHome, "omarchy", "current", "theme", "colors.toml")
}

func LoadPalette(path string) Palette {
	palette, _ := loadPaletteSnapshot(path)
	return palette
}

func loadPaletteSnapshot(path string) (Palette, string) {
	palette := make(Palette, len(paletteFallbacks))
	for key, fallback := range paletteFallbacks {
		palette[key] = fallback
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return palette, ""
	}

	signature := fmt.Sprintf("%x", sha256.Sum256(data))
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), `"`)
		if _, ok := paletteFallbacks[key]; ok && isHexColor(value) {
			palette[key] = strings.ToLower(value)
		}
	}
	return palette, signature
}

func isHexColor(value string) bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}
	for _, char := range value[1:] {
		if !(char >= '0' && char <= '9') && !(char >= 'a' && char <= 'f') && !(char >= 'A' && char <= 'F') {
			return false
		}
	}
	return true
}

type Model struct {
	palette     Palette
	palettePath string
	paletteSig  string
	width       int
	height      int
}

func NewModel(palette Palette) Model {
	return NewModelAtPath(palette, CurrentPalettePath())
}

func NewModelAtPath(palette Palette, path string) Model {
	_, signature := loadPaletteSnapshot(path)
	return Model{palette: palette, palettePath: path, paletteSig: signature, width: 100, height: 32}
}

func NewModelFromCurrentTheme() Model {
	return NewModel(LoadPalette(CurrentPalettePath()))
}

func (m Model) Init() tea.Cmd {
	return pollPalette(m.palettePath)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch message := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = message.Width
		m.height = message.Height
	case palettePollMsg:
		if message.path == m.palettePath && message.signature != m.paletteSig {
			m.palette = message.palette
			m.paletteSig = message.signature
		}
		return m, pollPalette(m.palettePath)
	case tea.KeyPressMsg:
		switch message.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "r":
			m.palette, m.paletteSig = loadPaletteSnapshot(m.palettePath)
		}
	}
	return m, nil
}

func (m Model) View() tea.View {
	view := tea.NewView(m.render())
	view.AltScreen = true
	view.WindowTitle = "Omagen Studio"
	return view
}

func (m Model) render() string {
	width, height := m.width, m.height
	if width < 1 {
		width = 100
	}
	if height < 1 {
		height = 32
	}

	compact := width < 82 || height < 28
	accent := lipgloss.Color(m.palette["accent"])
	foreground := lipgloss.Color(m.palette["foreground"])
	muted := lipgloss.Color(m.palette["muted"])
	if muted == nil {
		muted = lipgloss.Color("#7c7466")
	}

	accentStyle := lipgloss.NewStyle().Foreground(accent)
	textStyle := lipgloss.NewStyle().Foreground(foreground)
	mutedStyle := lipgloss.NewStyle().Foreground(muted)
	var logo, studio string
	if compact {
		logo = accentStyle.Bold(true).Render("OMAGEN")
		studio = accentStyle.Bold(true).Render("STUDIO")
	} else {
		logo = accentStyle.Bold(true).Render(omagenASCII)
		studio = accentStyle.Bold(true).Render(studioASCII)
	}

	rows := m.paletteRows(compact, textStyle)
	header := textStyle.Bold(true).Render("> COLORS <")
	footer := mutedStyle.Render("[auto] preview reload   [r] manual   [q] quit")
	content := lipgloss.JoinVertical(lipgloss.Center, logo, studio, "", header, rows, "", footer)

	// The terminal window already provides the compositor-owned frame. Keep the
	// TUI content open and centered instead of boxing it in a second container.
	return lipgloss.Place(width, height, lipgloss.Center, lipgloss.Center, content)
}

func pollPalette(path string) tea.Cmd {
	return tea.Tick(palettePollInterval, func(time.Time) tea.Msg {
		palette, signature := loadPaletteSnapshot(path)
		return palettePollMsg{path: path, palette: palette, signature: signature}
	})
}

func (m Model) paletteRows(compact bool, textStyle lipgloss.Style) string {
	limit := len(paletteOrder)
	if compact {
		limit = 7
	}
	rows := make([]string, 0, limit)
	for _, name := range paletteOrder[:limit] {
		hex := m.palette[name]
		swatch := lipgloss.NewStyle().Background(lipgloss.Color(hex)).Render("   ")
		label := strings.ToUpper(name)
		rows = append(rows, swatch+" "+textStyle.Render(fmt.Sprintf("%-10s %s", label, hex)))
	}
	return strings.Join(rows, "\n")
}
