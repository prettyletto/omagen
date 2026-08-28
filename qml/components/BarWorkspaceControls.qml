import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Workspace presentation belongs to BarSpec, while switching remains owned by
// the native workspace service. The bounded glyph list is shared with the Bar
// Demo and the Omagen bar widget host.
Item {
    id: root

    property var spec: ({})
    signal specEdited(var spec)

    implicitHeight: body.implicitHeight

    readonly property var workspace: root.spec && root.spec.workspace ? root.spec.workspace : ({})
    readonly property string mode: String(root.workspace.mode || "native")

    function normalizedGlyphs(values) {
        var result = []
        var source = values || []
        for (var index = 0; index < source.length && result.length < 5; index++) {
            var value = Array.from(String(source[index] || "")).slice(0, 4).join("")
            if (value.length > 0)
                result.push(value)
        }
        return result
    }

    function edit(mode, glyphs) {
        var next = JSON.parse(JSON.stringify(root.spec || ({})))
        next.workspace = {
            mode: mode,
            glyphs: mode === "glyphs"
                ? root.normalizedGlyphs(glyphs || (next.workspace && next.workspace.glyphs ? next.workspace.glyphs : []))
                : []
        }
        root.specEdited(next)
    }

    function parseGlyphs(raw) {
        var parts = String(raw || "").split(/[,\s]+/)
        var glyphs = []
        for (var index = 0; index < parts.length && glyphs.length < 5; index++) {
            var value = parts[index].trim()
            if (value.length > 0)
                glyphs.push(Array.from(value).slice(0, 4).join(""))
        }
        return glyphs
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        BarChoiceGroup {
            Layout.fillWidth: true
            title: "Workspaces"
            subtitle: "Default matches Omarchy's normal bar; labels change without changing workspace actions"
            options: [
                { key: "native", title: "Default" },
                { key: "numbers", title: "Numbers" },
                { key: "kanji", title: "Japanese Kanji" },
                { key: "roman", title: "Roman numerals" },
                { key: "letters", title: "Letters" },
                { key: "dots", title: "Dots" },
                { key: "glyphs", title: "Custom glyphs" }
            ]
            selectedKey: root.mode
            onChoiceSelected: {
                var glyphs = root.workspace.glyphs || []
                if (key === "glyphs" && glyphs.length === 0)
                    glyphs = ["①", "②", "③", "④", "⑤"]
                root.edit(key, glyphs)
            }
        }

        BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            visible: root.mode === "glyphs"
            color: Util.alpha(Color.foreground, 0.035)
            radius: Math.max(Style.space(5), Style.cornerRadius / 2)
            borderSpec: Border.flat(Util.alpha(Color.popups.border, glyphInput.activeFocus ? 0.9 : 0.55), 1)

            TextInput {
                id: glyphInput
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                verticalAlignment: TextInput.AlignVCenter
                text: (root.workspace.glyphs || []).join("  ")
                color: Color.foreground
                selectionColor: Util.alpha(Color.accent, 0.42)
                selectedTextColor: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                maximumLength: 80
                onEditingFinished: root.edit("glyphs", root.parseGlyphs(text))
                Keys.onReturnPressed: focus = false
                Keys.onEnterPressed: focus = false
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.mode === "glyphs"
            text: "Enter up to 5 labels in workspace order, separated by spaces or commas. Each label may contain up to four characters."
            color: Color.foreground
            opacity: 0.56
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }
}
