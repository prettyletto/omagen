import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// Visual editing only. The parent owns the staged palette document and decides
// when an edited value is sent to the live preview.
FocusScope {
    id: root

    required property string roleKey
    required property string roleLabel
    property string value: "#ffffff"
    property string presetValue: "#ffffff"
    property string roleDescription: ""
    property var suggestions: []
    property bool live: false
    property string draftHex: root.value.toUpperCase()
    property real hue: 0
    property real saturation: 1
    property real brightness: 1
    property string errorMessage: ""

    readonly property bool dirty: root.draftHex !== root.presetValue.toUpperCase()
    readonly property color draftColor: root.isHex(root.draftHex) ? root.draftHex : "#ffffff"

    signal valueEdited(string hex)
    signal resetRequested()
    signal suggestionRequested(string hex)

    implicitHeight: content.implicitHeight
    focus: true

    function isHex(value) {
        return /^#[0-9a-fA-F]{6}$/.test(value || "")
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function parseHex(value) {
        return {
            r: parseInt(value.slice(1, 3), 16) / 255,
            g: parseInt(value.slice(3, 5), 16) / 255,
            b: parseInt(value.slice(5, 7), 16) / 255
        }
    }

    function syncPickerFromHex(value) {
        if (!root.isHex(value))
            return

        const rgb = root.parseHex(value)
        const maximum = Math.max(rgb.r, rgb.g, rgb.b)
        const minimum = Math.min(rgb.r, rgb.g, rgb.b)
        const delta = maximum - minimum

        root.brightness = maximum
        root.saturation = maximum === 0 ? 0 : delta / maximum
        if (delta === 0) {
            root.hue = 0
            return
        }

        let hue
        if (maximum === rgb.r)
            hue = ((rgb.g - rgb.b) / delta) % 6
        else if (maximum === rgb.g)
            hue = (rgb.b - rgb.r) / delta + 2
        else
            hue = (rgb.r - rgb.g) / delta + 4

        root.hue = (hue / 6 + 1) % 1
    }

    function hexComponent(value) {
        return ("0" + Math.round(root.clamp(value, 0, 1) * 255).toString(16)).slice(-2).toUpperCase()
    }

    function pickerHex() {
        const hue = root.hue * 6
        const sector = Math.floor(hue)
        const fraction = hue - sector
        const p = root.brightness * (1 - root.saturation)
        const q = root.brightness * (1 - root.saturation * fraction)
        const t = root.brightness * (1 - root.saturation * (1 - fraction))
        let rgb

        switch (sector % 6) {
        case 0: rgb = { r: root.brightness, g: t, b: p }; break
        case 1: rgb = { r: q, g: root.brightness, b: p }; break
        case 2: rgb = { r: p, g: root.brightness, b: t }; break
        case 3: rgb = { r: p, g: q, b: root.brightness }; break
        case 4: rgb = { r: t, g: p, b: root.brightness }; break
        default: rgb = { r: root.brightness, g: p, b: q }
        }

        return "#" + root.hexComponent(rgb.r) + root.hexComponent(rgb.g) + root.hexComponent(rgb.b)
    }

    function commitHex(value) {
        let next = String(value || "").trim().toUpperCase()
        if (next.length === 6)
            next = "#" + next

        if (!root.isHex(next)) {
            root.errorMessage = "Use a six-digit hex colour, for example #D06B91"
            return
        }

        root.errorMessage = ""
        root.draftHex = next
        root.syncPickerFromHex(next)
        root.valueEdited(next)
    }

    function commitPicker() {
        root.commitHex(root.pickerHex())
    }

    function updateSaturationBrightness(x, y) {
        root.saturation = root.clamp(x / saturationField.width, 0, 1)
        root.brightness = 1 - root.clamp(y / saturationField.height, 0, 1)
        root.commitPicker()
    }

    function updateHue(y) {
        root.hue = root.clamp(y / hueField.height, 0, 1)
        root.commitPicker()
    }

    onValueChanged: {
        const next = String(root.value || "#ffffff").toUpperCase()
        if (root.draftHex !== next) {
            root.draftHex = next
            root.errorMessage = ""
            root.syncPickerFromHex(next)
        }
    }

    Component.onCompleted: root.syncPickerFromHex(root.draftHex)

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                    Layout.fillWidth: true
                    text: root.roleLabel.toUpperCase()
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0.9
                }

                Text {
                    Layout.fillWidth: true
                    text: root.roleDescription
                    color: Color.foreground
                    opacity: 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                spacing: Style.space(6)

                Rectangle {
                    Layout.preferredWidth: Style.space(34)
                    Layout.preferredHeight: Style.space(34)
                    radius: Style.space(6)
                    color: root.draftColor
                    border.width: 1
                    border.color: Util.alpha(Color.foreground, 0.4)
                }

                Column {
                    spacing: Style.space(1)

                    Text {
                        text: root.draftHex
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                    }

                    Text {
                        text: root.live && !root.dirty ? "LIVE" : root.dirty ? "STAGED" : "PRESET"
                        color: root.dirty ? Color.accent : Color.foreground
                        opacity: root.dirty ? 0.95 : 0.52
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= Style.space(430) ? 2 : 1
            columnSpacing: Style.space(10)
            rowSpacing: Style.space(8)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: width >= Style.space(430)
                    ? Style.space(154) : Style.space(166)
                spacing: Style.space(8)

                Rectangle {
                    id: saturationField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Style.space(7)
                    clip: true
                    color: Qt.hsva(root.hue, 1, 1, 1)

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#FFFFFFFF" }
                            GradientStop { position: 1; color: "#00FFFFFF" }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#00000000" }
                            GradientStop { position: 1; color: "#FF000000" }
                        }
                    }

                    Rectangle {
                        x: root.saturation * parent.width - width / 2
                        y: (1 - root.brightness) * parent.height - height / 2
                        width: Style.space(14)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.enabled
                        onPressed: function(mouse) { root.updateSaturationBrightness(mouse.x, mouse.y) }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                root.updateSaturationBrightness(mouse.x, mouse.y)
                        }
                    }
                }

                Rectangle {
                    id: hueField
                    Layout.preferredWidth: Style.space(18)
                    Layout.fillHeight: true
                    radius: width / 2
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.hsva(0.00, 1, 1, 1) }
                        GradientStop { position: 0.17; color: Qt.hsva(0.17, 1, 1, 1) }
                        GradientStop { position: 0.33; color: Qt.hsva(0.33, 1, 1, 1) }
                        GradientStop { position: 0.50; color: Qt.hsva(0.50, 1, 1, 1) }
                        GradientStop { position: 0.67; color: Qt.hsva(0.67, 1, 1, 1) }
                        GradientStop { position: 0.83; color: Qt.hsva(0.83, 1, 1, 1) }
                        GradientStop { position: 1.00; color: Qt.hsva(1.00, 1, 1, 1) }
                    }

                    Rectangle {
                        x: 0
                        y: root.hue * parent.height - height / 2
                        width: parent.width
                        height: Style.space(4)
                        color: "white"
                        border.width: 1
                        border.color: Util.alpha(Color.background, 0.7)
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.enabled
                        onPressed: function(mouse) { root.updateHue(mouse.y) }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                root.updateHue(mouse.y)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(7)

                Text {
                    Layout.fillWidth: true
                    text: "EXACT VALUE"
                    color: Color.foreground
                    opacity: 0.55
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(38)
                    radius: Style.space(6)
                    color: Util.alpha(Color.background, 0.5)
                    border.width: 1
                    border.color: hexInput.activeFocus ? Color.accent : Color.popups.border

                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        verticalAlignment: TextInput.AlignVCenter
                        color: Color.foreground
                        selectionColor: Style.selectionFillFor(Color.foreground, Color.accent, Color.urgent)
                        selectedTextColor: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        text: root.draftHex
                        selectByMouse: true
                        enabled: root.enabled
                        maximumLength: 7
                        Keys.onReturnPressed: root.commitHex(text)
                        Keys.onEnterPressed: root.commitHex(text)
                        onEditingFinished: root.commitHex(text)
                        Binding {
                            target: hexInput
                            property: "text"
                            value: root.draftHex
                            when: !hexInput.activeFocus
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Preset  " + root.presetValue.toUpperCase()
                    color: Color.foreground
                    opacity: 0.52
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(34)
                    text: "Reset to preset"
                    fontSize: Style.font.caption
                    foreground: Color.foreground
                    background: Util.alpha(Color.foreground, 0.045)
                    accent: Color.accent
                    bordered: true
                    enabled: root.enabled && root.dirty
                    onClicked: root.resetRequested()
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.errorMessage !== ""
                    text: root.errorMessage
                    color: Color.urgent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.suggestions.length > 0
            spacing: Style.space(6)

            Text {
                text: "SUGGESTED"
                color: Color.foreground
                opacity: 0.52
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Repeater {
                model: root.suggestions
                delegate: Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(30)
                    text: modelData.hex
                    fontSize: Style.font.caption
                    foreground: Contrast.textFor(modelData.hex, Color.background, Color.foreground)
                    background: modelData.hex
                    bordered: true
                    tooltipText: modelData.label + "  " + modelData.hex
                    enabled: root.enabled
                    onClicked: root.suggestionRequested(modelData.hex)
                }
            }
        }
    }
}
