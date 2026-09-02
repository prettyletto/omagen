.pragma library

// The clock style layer is deliberately presentation-only. The native clock
// remains mounted underneath it, so these helpers only decide how its already
// formatted display text should be painted.
var CLOCK_STYLES = ["native", "neon", "matrix", "lcd", "classical", "gothic"]

var SEGMENTS = {
    "0": "abcdef",
    "1": "bc",
    "2": "abdeg",
    "3": "abcdg",
    "4": "bcfg",
    "5": "acdfg",
    "6": "acdefg",
    "7": "abc",
    "8": "abcdefg",
    "9": "abcdfg",
    "A": "abcefg",
    "P": "abefg",
    "-": "g"
}

var MATRIX = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ":": ["0", "1", "0", "0", "1", "0", "0"],
    ".": ["0", "0", "0", "0", "0", "1", "0"],
    " ": ["00", "00", "00", "00", "00", "00", "00"]
}

function normalizeStyle(value) {
    var style = String(value === undefined || value === null ? "native" : value).toLowerCase()
    return CLOCK_STYLES.indexOf(style) >= 0 ? style : "native"
}

function normalizedChar(value) {
    var text = String(value === undefined || value === null ? "" : value)
    if (text === "—") return "-"
    return text.length > 0 ? text.charAt(0).toUpperCase() : ""
}

function normalizedLines(value) {
    var text = String(value === undefined || value === null ? "" : value).replace(/—/g, "-")
    var lines = text.split("\n")
    return lines.length > 0 ? lines : [""]
}

function isSevenSegmentText(value) {
    var lines = normalizedLines(value)
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        var line = lines[lineIndex]
        for (var charIndex = 0; charIndex < line.length; charIndex++) {
            var ch = normalizedChar(line.charAt(charIndex))
            if (ch === ":" || ch === "." || ch === " ") continue
            if (SEGMENTS[ch] === undefined) return false
        }
    }
    return String(value === undefined || value === null ? "" : value).length > 0
}

function segmentsFor(value) {
    return SEGMENTS[normalizedChar(value)] || ""
}

function matrixFor(value) {
    var ch = normalizedChar(value)
    return MATRIX[ch] || []
}

function isMatrixText(value) {
    var lines = normalizedLines(value)
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        var line = lines[lineIndex]
        for (var charIndex = 0; charIndex < line.length; charIndex++) {
            if (matrixFor(line.charAt(charIndex)).length === 0) return false
        }
    }
    return String(value === undefined || value === null ? "" : value).length > 0
}

if (typeof module !== "undefined") {
    module.exports = {
        CLOCK_STYLES: CLOCK_STYLES,
        normalizeStyle: normalizeStyle,
        normalizedChar: normalizedChar,
        normalizedLines: normalizedLines,
        isSevenSegmentText: isSevenSegmentText,
        segmentsFor: segmentsFor,
        matrixFor: matrixFor,
        isMatrixText: isMatrixText
    }
}
