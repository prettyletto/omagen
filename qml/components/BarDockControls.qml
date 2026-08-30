import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Dock-only presentation controls. Widget ordering and expanded behavior stay
// with Quattro/Omagen's existing Dock host; this changes only the one visual
// affordance shown while the Dock is closed.
Item {
    id: root

    property var spec: ({})
    signal specEdited(var spec)

    readonly property var dock: root.spec && root.spec.dock ? root.spec.dock : ({})
    readonly property string closed: String(root.dock.closed || "ellipsis")
    readonly property string glyph: String(root.dock.glyph || "✦")

    implicitHeight: body.implicitHeight

    function copySpec() {
        return JSON.parse(JSON.stringify(root.spec || ({})))
    }

    function normalizedGlyph(value) {
        var result = Array.from(String(value || "")).slice(0, 4).join("")
        return result.length > 0 ? result : "✦"
    }

    function edit(closed, glyph) {
        var next = root.copySpec()
        next.dock = {
            closed: closed,
            glyph: root.normalizedGlyph(glyph !== undefined ? glyph : root.glyph)
        }
        root.specEdited(next)
    }

    function parseGlyph(raw) {
        return root.normalizedGlyph(raw)
    }

    // TextInput::editingFinished is not guaranteed when the editor is left by
    // a wizard navigation action or when the final save dialog opens without
    // moving keyboard focus. Commit the non-empty user edit as it is made so
    // the staged BarSpec never falls back to the default star just because the
    // field did not receive a final focus event.
    function commitGlyph(raw) {
        var value = String(raw === undefined ? "" : raw)
        if (value.length === 0)
            return
        root.edit(root.closed, root.normalizedGlyph(value))
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        BarChoiceGroup {
            Layout.fillWidth: true
            title: "Closed dock"
            subtitle: "Choose the single mark shown before the Dock expands"
            options: [
                { key: "workspace", title: "Current workspace" },
                { key: "ellipsis", title: "(...)" },
                { key: "clock", title: "Clock" },
                { key: "glyph", title: "Custom glyph" }
            ]
            selectedKey: root.closed
            optionDescriptions: ({
                workspace: "Show the currently focused workspace label.",
                ellipsis: "Keep the existing ellipsis affordance.",
                clock: "Show the current local time.",
                glyph: "Show one custom glyph in a large size."
            })
            onChoiceSelected: {
                var nextGlyph = root.glyph
                if (key === "glyph" && nextGlyph.length === 0)
                    nextGlyph = "✦"
                root.edit(key, nextGlyph)
            }
        }

        BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            visible: root.closed === "glyph"
            color: Util.alpha(Color.foreground, 0.035)
            radius: Math.max(Style.space(5), Style.cornerRadius / 2)
            borderSpec: Border.flat(Util.alpha(Color.popups.border, glyphInput.activeFocus ? 0.9 : 0.55), 1)

            TextInput {
                id: glyphInput
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                verticalAlignment: TextInput.AlignVCenter
                text: root.glyph
                color: Color.foreground
                selectionColor: Util.alpha(Color.accent, 0.42)
                selectedTextColor: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                horizontalAlignment: TextInput.AlignHCenter
                maximumLength: 16
                onTextEdited: root.commitGlyph(text)
                onEditingFinished: root.edit(root.closed, root.parseGlyph(text))
                Keys.onReturnPressed: focus = false
                Keys.onEnterPressed: focus = false
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.closed === "glyph"
            text: "Enter up to four characters. The selected glyph is rendered large in the closed Dock."
            color: Color.foreground
            opacity: 0.56
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }
}
