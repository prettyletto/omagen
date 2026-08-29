import QtTest
import "../../bar/ClockStyleModel.js" as ClockStyleModel

TestCase {
    name: "ClockStyleModel"

    function test_styleNamesAndFallback() {
        compare(ClockStyleModel.normalizeStyle("neon"), "neon")
        compare(ClockStyleModel.normalizeStyle("matrix"), "matrix")
        compare(ClockStyleModel.normalizeStyle("lcd"), "lcd")
        compare(ClockStyleModel.normalizeStyle("classical"), "classical")
        compare(ClockStyleModel.normalizeStyle("gothic"), "gothic")
        compare(ClockStyleModel.normalizeStyle("missing"), "native")
        compare(ClockStyleModel.normalizeStyle(null), "native")
    }

    function test_neonTextSupportsClockSeparatorsAndVerticalLines() {
        verify(ClockStyleModel.isSevenSegmentText("06:53"))
        verify(ClockStyleModel.isSevenSegmentText("06\n—\n53"))
        compare(ClockStyleModel.normalizedLines("06\n—\n53")[1], "-")
        compare(ClockStyleModel.segmentsFor("8"), "abcdefg")
        compare(ClockStyleModel.segmentsFor("-"), "g")
        verify(!ClockStyleModel.isSevenSegmentText("Thursday 06:53"))
    }

    function test_matrixPatternsCoverClockCharacters() {
        verify(ClockStyleModel.isMatrixText("06:53"))
        verify(ClockStyleModel.isMatrixText("06\n—\n53"))
        compare(ClockStyleModel.matrixFor("8").length, 7)
        compare(ClockStyleModel.matrixFor(":").length, 7)
        verify(!ClockStyleModel.isMatrixText("Thursday 06:53"))
    }
}
