import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The Dock's closed state is a single, presentation-only affordance. The
// expanded Dock keeps using the normal widget slots, so this component never
// takes ownership of widget actions or popups.
Item {
    id: root

    property var bar: null
    property int clockTick: 0

    readonly property string mode: root.bar ? root.bar.dockClosedContent : "ellipsis"
    readonly property string glyph: root.bar ? root.bar.dockClosedGlyph : "✦"
    readonly property bool vertical: !!root.bar && root.bar.vertical
    readonly property int currentWorkspaceId: {
        var workspace = Hyprland.focusedWorkspace
        var id = workspace ? Number(workspace.id) : 1
        return id > 0 ? Math.round(id) : 1
    }
    readonly property string displayText: root.mode === "workspace"
        ? root.workspaceLabel(root.currentWorkspaceId)
        : root.mode === "clock" ? root.formattedClock()
        : root.mode === "glyph" ? root.glyph
        : root.vertical ? "⋮" : "···"

    implicitWidth: root.bar ? root.bar.dockCollapsedExtent : Style.space(48)
    implicitHeight: root.bar ? root.bar.dockCollapsedExtent : Style.space(48)

    function formattedClock() {
        // Read the counter so the binding refreshes once a second without
        // polling the compositor or creating a second native clock widget.
        var tick = root.clockTick
        return Qt.formatTime(new Date(), "HH:mm")
    }

    function workspaceLabel(id) {
        var workspace = root.bar ? root.bar.workspaceSpec : ({})
        var mode = String(workspace.mode || "native")
        if (mode === "dots") return "●"
        if (mode === "kanji") {
            var kanji = ["一", "二", "三", "四", "五"]
            return id >= 1 && id <= kanji.length ? kanji[id - 1] : String(id)
        }
        if (mode === "glyphs") {
            var glyphs = workspace.glyphs || []
            if (glyphs[id - 1] !== undefined && String(glyphs[id - 1]).length > 0)
                return String(glyphs[id - 1])
        }
        if (mode === "roman") {
            var numerals = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
            var remaining = id
            var roman = ""
            for (var index = 0; index < numerals.length; index++) {
                while (remaining >= numerals[index][0]) {
                    roman += numerals[index][1]
                    remaining -= numerals[index][0]
                }
            }
            return roman
        }
        if (mode === "letters") return String.fromCharCode(64 + id)
        if (mode === "native" && id === 1) return "\uDB85\uDCFB"
        return id === 10 ? "0" : String(id)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.mode === "clock"
        onTriggered: root.clockTick += 1
    }

    Text {
        anchors.fill: parent
        anchors.margins: Style.space(4)
        text: root.displayText
        color: root.bar ? root.bar.barForeground : Color.bar.text
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: root.mode === "glyph"
            ? Math.max(Style.font.heading, root.bar ? root.bar.barSize : Style.font.heading)
            : root.mode === "clock" ? Style.font.body : Style.font.title
        font.bold: true
        fontSizeMode: Text.Fit
        minimumPixelSize: root.mode === "glyph" ? Style.font.body : Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }
}
