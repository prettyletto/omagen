// Package terminaltheme materializes Omagen's bounded terminal translucency
// intent into the terminal theme files generated inside a staged candidate.
// It never touches a user's main terminal configuration.
package terminaltheme

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/prettyletto/omagen/backend/internal/fsutil"
	"github.com/prettyletto/omagen/backend/internal/session"
)

const (
	IntentFile              = "omagen.terminal.json"
	maxThemeFileBytes int64 = 1 << 20
)

type Terminal string

const (
	Ghostty   Terminal = "ghostty"
	Alacritty Terminal = "alacritty"
	Kitty     Terminal = "kitty"
	Foot      Terminal = "foot"
)

type Output struct {
	Terminal Terminal `json:"terminal"`
	File     string   `json:"file"`
	Changed  bool     `json:"changed"`
	Message  string   `json:"message,omitempty"`
}

type Capability struct {
	Terminal          Terminal  `json:"terminal"`
	Installed         bool      `json:"installed"`
	Version           string    `json:"version,omitempty"`
	CellModeSupported bool      `json:"cell_mode_supported"`
	Message           string    `json:"message,omitempty"`
	UserOverride      *Override `json:"user_override,omitempty"`
}

type Override struct {
	Path  string `json:"path"`
	Key   string `json:"key"`
	Value string `json:"value,omitempty"`
}

type Report struct {
	SchemaVersion int          `json:"schema_version"`
	Mode          string       `json:"mode"`
	Opacity       float64      `json:"opacity"`
	CellMode      string       `json:"cell_mode"`
	Outputs       []Output     `json:"outputs"`
	Capabilities  []Capability `json:"capabilities"`
}

var assignmentPattern = regexp.MustCompile(`^([[:space:]]*)([A-Za-z0-9_-]+)([[:space:]]*)(=|[[:space:]]+)(.*)$`)

// Materialize reads the intent sidecar in themeDir and updates only the
// opacity/cell-mode keys owned by Omagen. All writes are atomic and remain
// inside the staged candidate directory.
func Materialize(themeDir string) (Report, error) {
	if err := validateThemeDir(themeDir); err != nil {
		return Report{}, err
	}
	data, err := fsutil.ReadFileLimited(filepath.Join(themeDir, IntentFile), fsutil.MaxStateFileBytes)
	if err != nil {
		return Report{}, fmt.Errorf("read terminal intent: %w", err)
	}
	var spec session.TerminalTranslucency
	if err := json.Unmarshal(data, &spec); err != nil {
		return Report{}, fmt.Errorf("decode terminal intent: %w", err)
	}
	spec = session.NormalizeTerminalTranslucency(spec)
	if err := spec.Validate(); err != nil {
		return Report{}, err
	}
	report := Report{SchemaVersion: spec.SchemaVersion, Mode: spec.Mode, Opacity: spec.Opacity, CellMode: spec.CellMode, Outputs: []Output{}, Capabilities: inspectCapabilities(spec)}
	if spec.Mode == sessionTerminalModePreserve {
		for _, target := range targets() {
			report.Outputs = append(report.Outputs, Output{Terminal: target.terminal, File: target.file, Message: "Preserve mode left the generated terminal file unchanged"})
		}
		return report, nil
	}
	for _, target := range targets() {
		path := filepath.Join(themeDir, target.file)
		info, statErr := os.Stat(path)
		if statErr != nil {
			return Report{}, fmt.Errorf("materialize %s: %w", target.terminal, statErr)
		}
		if !info.Mode().IsRegular() {
			return Report{}, fmt.Errorf("materialize %s: target is not a regular file", target.terminal)
		}
	}

	userOverrides := make(map[Terminal]*Override, len(report.Capabilities))
	for index := range report.Capabilities {
		capability := &report.Capabilities[index]
		if capability.UserOverride != nil {
			userOverrides[capability.Terminal] = capability.UserOverride
		}
	}
	for _, target := range targets() {
		path := filepath.Join(themeDir, target.file)
		changed, err := materializeTarget(path, target.terminal, spec, userOverrides[target.terminal])
		if err != nil {
			return Report{}, fmt.Errorf("materialize %s: %w", target.terminal, err)
		}
		message := "opacity and cell-mode intent materialized"
		if userOverrides[target.terminal] != nil {
			message = "user opacity override retained; generated opacity omitted"
		}
		if target.terminal == Kitty && spec.CellMode == sessionTerminalCellPainted {
			message = "opacity materialized; Kitty has no portable painted-cell toggle"
			if userOverrides[target.terminal] != nil {
				message = "user opacity override retained; Kitty has no portable painted-cell toggle"
			}
		}
		report.Outputs = append(report.Outputs, Output{Terminal: target.terminal, File: target.file, Changed: changed, Message: message})
	}
	return report, nil
}

// MaterializeSpec is useful to the generator and tests when the caller has
// already decoded the sidecar. The public CLI deliberately uses Materialize
// so the sidecar remains the single staged source of truth.
func MaterializeSpec(themeDir string, spec session.TerminalTranslucency) (Report, error) {
	if err := validateThemeDir(themeDir); err != nil {
		return Report{}, err
	}
	spec = session.NormalizeTerminalTranslucency(spec)
	if err := spec.Validate(); err != nil {
		return Report{}, err
	}
	if err := fsutil.AtomicWriteJSON(filepath.Join(themeDir, IntentFile), spec, 0o644); err != nil {
		return Report{}, fmt.Errorf("write terminal intent: %w", err)
	}
	return Materialize(themeDir)
}

type target struct {
	terminal Terminal
	file     string
}

func targets() []target {
	return []target{{Ghostty, "ghostty.conf"}, {Alacritty, "alacritty.toml"}, {Kitty, "kitty.conf"}, {Foot, "foot.ini"}}
}

func materializeTarget(path string, terminal Terminal, spec session.TerminalTranslucency, userOverride *Override) (bool, error) {
	data, err := fsutil.ReadFileLimited(path, maxThemeFileBytes)
	if err != nil {
		return false, err
	}
	info, err := os.Lstat(path)
	if err != nil {
		return false, err
	}
	if !info.Mode().IsRegular() {
		return false, fmt.Errorf("target is not a regular file")
	}
	content := string(data)
	var updated string
	switch terminal {
	case Ghostty:
		values := map[string]string{
			"background-opacity-cells": strconv.FormatBool(spec.CellMode == sessionTerminalCellPainted),
		}
		if userOverride == nil {
			values["background-opacity"] = formatOpacity(spec.Opacity)
		}
		updated = rewriteGlobalAssignments(content, values, " = ")
		if userOverride != nil {
			updated = removeGlobalAssignment(updated, "background-opacity")
		}
	case Alacritty:
		windowValues := map[string]string{}
		if userOverride == nil {
			windowValues["opacity"] = formatOpacity(spec.Opacity)
		}
		sections := map[string]map[string]string{
			"colors": {"transparent_background_colors": strconv.FormatBool(spec.CellMode == sessionTerminalCellPainted)},
		}
		if len(windowValues) > 0 {
			sections["window"] = windowValues
		}
		updated = rewriteTomlAssignments(content, sections)
		if userOverride != nil {
			updated = removeTomlAssignment(updated, "window", "opacity")
		}
	case Kitty:
		if userOverride == nil {
			updated = rewriteGlobalAssignments(content, map[string]string{"background_opacity": formatOpacity(spec.Opacity)}, " ")
		} else {
			updated = removeGlobalAssignment(content, "background_opacity")
		}
	case Foot:
		values := map[string]string{"alpha-mode": footAlphaMode(spec.CellMode)}
		if userOverride == nil {
			values["alpha"] = formatOpacity(spec.Opacity)
		}
		updated = rewriteIniAssignments(content, "colors-dark", values)
		if userOverride != nil {
			updated = removeIniAssignment(updated, "colors-dark", "alpha")
		}
	default:
		return false, fmt.Errorf("unsupported terminal %q", terminal)
	}
	if updated == content {
		return false, nil
	}
	if err := fsutil.AtomicWriteFile(path, []byte(updated), info.Mode().Perm()); err != nil {
		return false, err
	}
	return true, nil
}

func formatOpacity(opacity float64) string {
	return strconv.FormatFloat(opacity, 'f', 3, 64)
}

func footAlphaMode(cellMode string) string {
	if cellMode == sessionTerminalCellPainted {
		return "all"
	}
	return "default"
}

func rewriteGlobalAssignments(content string, values map[string]string, separator string) string {
	return rewriteAssignments(content, values, separator)
}

func rewriteTomlAssignments(content string, sections map[string]map[string]string) string {
	lines, finalNewline := splitLines(content)
	seen := make(map[string]bool)
	inserted := make(map[string]bool)
	section := ""
	result := make([]string, 0, len(lines)+len(sections)*2)
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			if sectionValues, ok := sections[section]; ok && !inserted[section] {
				result = appendMissingValues(result, section, sectionValues, seen, " = ")
				inserted[section] = true
			}
			section = strings.TrimSpace(trimmed[1 : len(trimmed)-1])
		}
		values, ok := sections[section]
		if ok {
			if key, value, matched := assignmentKey(line); matched {
				if replacement, owned := values[key]; owned {
					if seen[section+"\x00"+key] {
						continue
					}
					line = replaceAssignment(line, key, replacement, " = ")
					seen[section+"\x00"+key] = true
					_ = value
				}
			}
		}
		result = append(result, line)
	}
	// If the final input section is one of our target sections, complete it
	// before appending any previously absent sections. Otherwise those new
	// sections would capture the missing keys in the wrong TOML scope.
	if values, ok := sections[section]; ok && !inserted[section] {
		result = appendMissingValues(result, section, values, seen, " = ")
		inserted[section] = true
	}
	for _, sectionName := range sortedSectionKeys(sections) {
		values := sections[sectionName]
		if !inserted[sectionName] {
			if section == sectionName {
				result = appendMissingValues(result, sectionName, values, seen, " = ")
				inserted[sectionName] = true
				continue
			}
			if len(result) > 0 && strings.TrimSpace(result[len(result)-1]) != "" {
				result = append(result, "")
			}
			result = append(result, "["+sectionName+"]")
			result = appendMissingValues(result, sectionName, values, seen, " = ")
			inserted[sectionName] = true
		}
	}
	return joinLines(result, finalNewline)
}

func rewriteIniAssignments(content, wantedSection string, values map[string]string) string {
	lines, finalNewline := splitLines(content)
	seen := make(map[string]bool)
	inserted := false
	section := ""
	result := make([]string, 0, len(lines)+len(values))
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			if section == wantedSection && !inserted {
				result = appendMissingValues(result, wantedSection, values, seen, "=")
				inserted = true
			}
			section = strings.TrimSpace(trimmed[1 : len(trimmed)-1])
		}
		if section == wantedSection {
			if key, _, matched := assignmentKey(line); matched {
				if replacement, owned := values[key]; owned {
					if seen[key] {
						continue
					}
					line = replaceAssignment(line, key, replacement, "=")
					seen[key] = true
				}
			}
		}
		result = append(result, line)
	}
	if section == wantedSection && !inserted {
		result = appendMissingValues(result, wantedSection, values, seen, "=")
		inserted = true
	}
	if !inserted {
		if !containsSection(result, wantedSection) {
			if len(result) > 0 && strings.TrimSpace(result[len(result)-1]) != "" {
				result = append(result, "")
			}
			result = append(result, "["+wantedSection+"]")
		}
		result = appendMissingValues(result, wantedSection, values, seen, "=")
	}
	return joinLines(result, finalNewline)
}

func rewriteAssignments(content string, values map[string]string, separator string) string {
	lines, finalNewline := splitLines(content)
	seen := make(map[string]bool)
	result := make([]string, 0, len(lines)+len(values))
	for _, line := range lines {
		if key, _, matched := assignmentKey(line); matched {
			if replacement, owned := values[key]; owned {
				if seen[key] {
					continue
				}
				line = replaceAssignment(line, key, replacement, separator)
				seen[key] = true
			}
		}
		result = append(result, line)
	}
	missing := make([]string, 0, len(values))
	for _, key := range sortedKeys(values) {
		if !seen[key] {
			missing = append(missing, key+separator+values[key])
		}
	}
	if len(missing) > 0 {
		if len(result) > 0 && strings.TrimSpace(result[len(result)-1]) != "" {
			result = append(result, "")
		}
		result = append(result, missing...)
	}
	return joinLines(result, finalNewline)
}

// removeGlobalAssignment removes a single Omagen-owned global assignment from
// a generated terminal theme. This is used when the user's main config
// explicitly owns the same setting: leaving the generated key in place would
// let a terminal-specific import order accidentally override that preference.
func removeGlobalAssignment(content, wantedKey string) string {
	lines, finalNewline := splitLines(content)
	result := make([]string, 0, len(lines))
	for _, line := range lines {
		if key, _, matched := assignmentKey(line); matched && key == wantedKey {
			continue
		}
		result = append(result, line)
	}
	return joinLines(result, finalNewline)
}

func removeTomlAssignment(content, wantedSection, wantedKey string) string {
	lines, finalNewline := splitLines(content)
	section := ""
	result := make([]string, 0, len(lines))
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			section = strings.TrimSpace(trimmed[1 : len(trimmed)-1])
		}
		if section == wantedSection {
			if key, _, matched := assignmentKey(line); matched && key == wantedKey {
				continue
			}
		}
		result = append(result, line)
	}
	return joinLines(result, finalNewline)
}

func removeIniAssignment(content, wantedSection, wantedKey string) string {
	return removeTomlAssignment(content, wantedSection, wantedKey)
}

func appendMissingValues(lines []string, section string, values map[string]string, seen map[string]bool, separator string) []string {
	for _, key := range sortedKeys(values) {
		if seen[section+"\x00"+key] || seen[key] {
			continue
		}
		lines = append(lines, key+separator+values[key])
		if section == "" {
			seen[key] = true
		} else {
			seen[section+"\x00"+key] = true
		}
	}
	return lines
}

func sortedKeys(values map[string]string) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func sortedSectionKeys(values map[string]map[string]string) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func assignmentKey(line string) (string, string, bool) {
	trimmed := strings.TrimSpace(line)
	if trimmed == "" || strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, ";") {
		return "", "", false
	}
	match := assignmentPattern.FindStringSubmatch(line)
	if match == nil {
		return "", "", false
	}
	return match[2], match[5], true
}

func replaceAssignment(line, key, value, separator string) string {
	match := assignmentPattern.FindStringSubmatch(line)
	if match == nil {
		return key + separator + value
	}
	suffix := ""
	if index := strings.Index(match[5], " #"); index >= 0 {
		suffix = match[5][index:]
	}
	return match[1] + key + separator + value + suffix
}

func splitLines(content string) ([]string, bool) {
	finalNewline := strings.HasSuffix(content, "\n")
	content = strings.TrimSuffix(content, "\n")
	if content == "" {
		return nil, finalNewline
	}
	return strings.Split(content, "\n"), finalNewline
}

func joinLines(lines []string, finalNewline bool) string {
	result := strings.Join(lines, "\n")
	if finalNewline {
		result += "\n"
	}
	return result
}

func containsSection(lines []string, section string) bool {
	wanted := "[" + section + "]"
	for _, line := range lines {
		if strings.TrimSpace(line) == wanted {
			return true
		}
	}
	return false
}

func validateThemeDir(themeDir string) error {
	if themeDir == "" || !filepath.IsAbs(themeDir) || filepath.Clean(themeDir) != themeDir {
		return fmt.Errorf("theme directory must be a clean absolute path")
	}
	info, err := os.Stat(themeDir)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("theme directory is not a directory")
	}
	return nil
}

func inspectCapabilities(spec session.TerminalTranslucency) []Capability {
	result := make([]Capability, 0, 4)
	for _, item := range targets() {
		capability := Capability{Terminal: item.terminal, CellModeSupported: item.terminal != Kitty}
		command, args := versionCommand(item.terminal)
		if _, err := exec.LookPath(command); err == nil {
			capability.Installed = true
			capability.Version = commandVersion(command, args...)
		} else {
			capability.Message = "terminal executable is not installed; theme artifact remains portable"
		}
		if item.terminal == Kitty && spec.CellMode == sessionTerminalCellPainted {
			capability.Message = "Kitty supports opacity but has no portable painted-cell mode in this contract"
		}
		if override := detectUserOverride(item); override != nil {
			capability.UserOverride = override
			capability.Message = "user opacity override retained; generated opacity omitted"
		}
		result = append(result, capability)
	}
	return result
}

func versionCommand(terminal Terminal) (string, []string) {
	switch terminal {
	case Ghostty:
		return "ghostty", []string{"+version"}
	case Alacritty:
		return "alacritty", []string{"--version"}
	case Kitty:
		return "kitty", []string{"--version"}
	case Foot:
		return "foot", []string{"--version"}
	default:
		return string(terminal), []string{"--version"}
	}
}

func commandVersion(command string, args ...string) string {
	output, err := exec.Command(command, args...).CombinedOutput()
	if err != nil {
		return ""
	}
	match := regexp.MustCompile(`[0-9]+\.[0-9]+(?:\.[0-9]+)?`).FindString(string(output))
	return match
}

func detectUserOverride(item target) *Override {
	configHome, err := os.UserConfigDir()
	if err != nil {
		return nil
	}
	path := filepath.Join(configHome, itemConfigDirectory(item.terminal), itemConfigFile(item.terminal))
	data, err := fsutil.ReadFileLimited(path, maxThemeFileBytes)
	if err != nil {
		return nil
	}
	section, key := overrideLocation(item.terminal)
	value, ok := findAssignment(string(data), section, key)
	if !ok {
		return nil
	}
	return &Override{Path: path, Key: key, Value: value}
}

func itemConfigDirectory(terminal Terminal) string {
	return map[Terminal]string{Ghostty: "ghostty", Alacritty: "alacritty", Kitty: "kitty", Foot: "foot"}[terminal]
}

func itemConfigFile(terminal Terminal) string {
	return map[Terminal]string{Ghostty: "config", Alacritty: "alacritty.toml", Kitty: "kitty.conf", Foot: "foot.ini"}[terminal]
}

func overrideLocation(terminal Terminal) (string, string) {
	switch terminal {
	case Ghostty:
		return "", "background-opacity"
	case Alacritty:
		return "window", "opacity"
	case Kitty:
		return "", "background_opacity"
	case Foot:
		return "colors-dark", "alpha"
	default:
		return "", ""
	}
}

func findAssignment(content, wantedSection, wantedKey string) (string, bool) {
	section := ""
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			section = strings.TrimSpace(trimmed[1 : len(trimmed)-1])
		}
		if wantedSection != "" && section != wantedSection {
			continue
		}
		key, value, matched := assignmentKey(line)
		if matched && key == wantedKey {
			return strings.TrimSpace(value), true
		}
	}
	return "", false
}

const (
	sessionTerminalModePreserve = "preserve"
	sessionTerminalCellPainted  = "painted"
)
