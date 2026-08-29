import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components" as Components
import "WindowStyle.js" as WindowStyle

// Focused Window/Hyprland editor. Border text entry and slider staging belong
// here because they are local interaction state, not application state.
Item {
    id: root

    property var desktopStyle: ({})
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal styleEdited(var desktopStyle)

    readonly property var borderOptions: [
        { key: "solid", title: "Solid" }, { key: "split_top", title: "Split top" },
        { key: "split_bottom", title: "Split bottom" }, { key: "blend", title: "Accent blend" },
        { key: "neon", title: "Neon" }, { key: "spin", title: "Spinning" }
    ]
    readonly property var shapeOptions: [
        { key: "native", title: "Default" }, { key: "subtle", title: "Subtle" },
        { key: "soft", title: "Soft" }, { key: "rounded", title: "Rounded" }, { key: "pill", title: "Pill" }
    ]
    readonly property var spacingOptions: [
        { key: "native", title: "Default" }, { key: "compact", title: "Compact" }, { key: "airy", title: "Airy" }
    ]
    readonly property var depthOptions: [
        { key: "native", title: "Default" }, { key: "flat", title: "Flat" }, { key: "shadow", title: "Shadow" }
    ]
    readonly property var inactiveOptions: [
        { key: "native", title: "Native" }, { key: "shadow", title: "Soft dim" }, { key: "shadow_only", title: "Shadow · Preserve transparency" },
        { key: "frosted_light", title: "Frosted · Light" }, { key: "frosted_balanced", title: "Frosted · Balanced" },
        { key: "frosted_rich", title: "Frosted · Rich" }
    ]
    readonly property var activeOptions: [
        { key: "native", title: "Native" }, { key: "frosted_light", title: "Frosted · Light" },
        { key: "frosted_balanced", title: "Frosted · Balanced" }, { key: "frosted_rich", title: "Frosted · Rich" }
    ]

    property int stagedBorderSize: root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1
    property int stagedBorderSpeed: Number(root.desktopStyle.borderSpeed || 36)
    property bool borderSizeEditing: false
    property bool speedEditing: false

    implicitHeight: windowColumn.implicitHeight

    function optionDescription(group, key) {
        var descriptions = {
            borderStyle: {
                solid: "A single accent border around the focused window.",
                split_top: "An accent border with a stronger top edge for the focused window.",
                split_bottom: "An accent border with a stronger bottom edge for the focused window.",
                blend: "A softer border that blends the accent into the window surface.",
                neon: "A high-contrast accent border for a more luminous focused window.",
                spin: "An animated accent border treatment for the focused window."
            },
            shape: {
                native: "Use the active theme's normal window corner radius.",
                subtle: "Use a small 2 px corner radius on windows.",
                soft: "Use a gentle 4 px corner radius on windows.",
                rounded: "Use a clearly rounded 8 px corner radius on windows.",
                pill: "Use a very rounded 16 px corner radius on windows."
            },
            spacing: {
                native: "Keep the active theme's normal gaps between windows.",
                compact: "Reduce gaps between windows for a tighter layout.",
                airy: "Increase gaps between windows for a more open layout."
            },
            depth: {
                native: "Keep the active theme's normal compositor shadow treatment.",
                flat: "Reduce compositor shadows for a flatter window surface.",
                shadow: "Emphasise compositor shadows to separate windows from the desktop."
            },
            inactiveStyle: {
                native: "Keep inactive windows using the active Hyprland treatment.",
                shadow: "Dim inactive windows without adding background blur.",
                shadow_only: "Add a transparent compositor shadow without overriding inactive opacity or dimming content.",
                blur: "Legacy Backdrop blur setting; it becomes the Balanced frosted backdrop profile.",
                frosted_light: "A light glass treatment: subtle dimming and low-cost background blur.",
                frosted_balanced: "Recommended glass treatment: visible background blur without a shadow-heavy dim.",
                frosted_rich: "A stronger glass treatment with a larger, multipass blur and higher GPU cost."
            }
        }
        return descriptions[group] && descriptions[group][key]
            ? descriptions[group][key]
            : "Native inactive-window treatment from the active Hyprland configuration."
    }

    function borderSliderPosition() {
        return WindowStyle.borderSliderPosition(root.stagedBorderSize)
    }

    function borderSizeFromSlider(position) {
        return WindowStyle.borderSizeFromSlider(position)
    }

    function chooseDesktop(group, key) {
        root.styleEdited(WindowStyle.choose(root.desktopStyle, group, key))
    }

    function chooseActive(key) {
        root.chooseDesktop("activeStyle", key)
    }

    function beginBorderSizeEdit() {
        root.borderSizeEditing = true
        borderSizeInput.text = root.stagedBorderSize > 0 ? String(root.stagedBorderSize) : "2"
        Qt.callLater(function() { borderSizeInput.forceActiveFocus(); borderSizeInput.selectAll() })
    }

    function commitBorderSizeEdit() {
        if (!root.borderSizeEditing) return
        var value = Number(borderSizeInput.text)
        root.borderSizeEditing = false
        if (!isFinite(value)) return
        root.chooseDesktop("borderSize", Math.max(-1, Math.min(24, Math.round(value))))
    }

    function beginSpeedEdit() {
        root.speedEditing = true
        speedInput.text = (root.stagedBorderSpeed / 10).toFixed(1)
        Qt.callLater(function() { speedInput.forceActiveFocus(); speedInput.selectAll() })
    }

    function commitSpeedEdit() {
        if (!root.speedEditing) return
        var seconds = Number(speedInput.text)
        root.speedEditing = false
        if (!isFinite(seconds)) return
        root.chooseDesktop("borderSpeed", Math.max(10, Math.min(100, Math.round(seconds * 10))))
    }

    onDesktopStyleChanged: {
        if (!borderSlider.dragging)
            root.stagedBorderSize = root.desktopStyle.borderSize !== undefined ? Number(root.desktopStyle.borderSize) : -1
        if (!speedSlider.dragging)
            root.stagedBorderSpeed = Number(root.desktopStyle.borderSpeed || 36)
    }

    ColumnLayout {
        id: windowColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(5)

        Text { Layout.fillWidth: true; text: "HYPRLAND WINDOW EFFECTS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
        Text { Layout.fillWidth: true; text: "Window appearance is written to hyprland.lua for the compositor."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        Text { Layout.fillWidth: true; text: "BORDER STYLE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout {
            Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5)
            Repeater { model: root.borderOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("borderStyle", modelData.key); selected: root.desktopStyle.borderStyle === modelData.key; onClicked: root.chooseDesktop("borderStyle", modelData.key) } }
        }
        Text { Layout.fillWidth: true; text: "BORDER THICKNESS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        RowLayout {
            Layout.fillWidth: true; spacing: Style.space(8)
            Text { text: "BORDER"; color: root.foregroundColor; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            PanelSlider {
                id: borderSlider
                Layout.fillWidth: true; minimum: 0; maximum: 13; step: 1; integer: true
                value: root.borderSliderPosition(); tickCount: 14
                trackColor: Util.alpha(root.foregroundColor, 0.2); fillColor: root.accentColor; knobColor: root.accentColor; tickColor: root.backgroundColor
                onMoved: root.stagedBorderSize = root.borderSizeFromSlider(value)
                onReleased: root.chooseDesktop("borderSize", root.borderSizeFromSlider(value))
            }
            Item {
                Layout.preferredWidth: Style.space(70); Layout.preferredHeight: Style.space(32)
                Text { anchors.fill: parent; visible: !root.borderSizeEditing; text: root.stagedBorderSize < 0 ? "Default" : root.stagedBorderSize === 0 ? "None" : root.stagedBorderSize + " px"; color: root.accentColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; visible: !root.borderSizeEditing; cursorShape: Qt.PointingHandCursor; onClicked: root.beginBorderSizeEdit() }
                Rectangle { anchors.fill: parent; visible: root.borderSizeEditing; radius: Style.space(5); color: Util.alpha(root.backgroundColor, 0.48); border.width: 1; border.color: borderSizeInput.activeFocus ? root.accentColor : Color.popups.border }
                TextInput {
                    id: borderSizeInput
                    anchors.fill: parent; anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6); visible: root.borderSizeEditing
                    color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: TextInput.AlignRight; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                    Keys.onReturnPressed: root.commitBorderSizeEdit(); Keys.onEnterPressed: root.commitBorderSizeEdit(); Keys.onEscapePressed: root.borderSizeEditing = false; onEditingFinished: root.commitBorderSizeEdit()
                }
            }
        }
        Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "SPIN SPEED"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; visible: root.desktopStyle.borderStyle === "spin"; text: "Controls the full gradient cycle. Lower seconds move faster."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        RowLayout {
            visible: root.desktopStyle.borderStyle === "spin"; Layout.fillWidth: true; spacing: Style.space(8)
            Text { text: "SPEED"; color: root.foregroundColor; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            PanelSlider {
                id: speedSlider
                Layout.fillWidth: true; minimum: 10; maximum: 100; step: 1; integer: true; value: root.stagedBorderSpeed; tickCount: 10
                trackColor: Util.alpha(root.foregroundColor, 0.2); fillColor: root.accentColor; knobColor: root.accentColor; tickColor: root.backgroundColor
                onMoved: root.stagedBorderSpeed = Math.round(value)
                onReleased: root.chooseDesktop("borderSpeed", Math.round(value))
            }
            Item {
                Layout.preferredWidth: Style.space(70); Layout.preferredHeight: Style.space(32)
                Text { anchors.fill: parent; visible: !root.speedEditing; text: (root.stagedBorderSpeed / 10).toFixed(1) + " s"; color: root.accentColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                MouseArea { anchors.fill: parent; visible: !root.speedEditing; cursorShape: Qt.PointingHandCursor; onClicked: root.beginSpeedEdit() }
                Rectangle { anchors.fill: parent; visible: root.speedEditing; radius: Style.space(5); color: Util.alpha(root.backgroundColor, 0.48); border.width: 1; border.color: speedInput.activeFocus ? root.accentColor : Color.popups.border }
                TextInput {
                    id: speedInput
                    anchors.fill: parent; anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6); visible: root.speedEditing
                    color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: TextInput.AlignRight; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                    Keys.onReturnPressed: root.commitSpeedEdit(); Keys.onEnterPressed: root.commitSpeedEdit(); Keys.onEscapePressed: root.speedEditing = false; onEditingFinished: root.commitSpeedEdit()
                }
            }
        }
        Text { Layout.fillWidth: true; text: "SHAPE"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.shapeOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("shape", modelData.key); selected: root.desktopStyle.shape === modelData.key; onClicked: root.chooseDesktop("shape", modelData.key) } } }
        Text { Layout.fillWidth: true; text: "SPACING"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.spacingOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("spacing", modelData.key); selected: root.desktopStyle.spacing === modelData.key; onClicked: root.chooseDesktop("spacing", modelData.key) } } }
        Text { Layout.fillWidth: true; text: "DEPTH"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.depthOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("depth", modelData.key); selected: root.desktopStyle.depth === modelData.key; onClicked: root.chooseDesktop("depth", modelData.key) } } }
        Text { Layout.fillWidth: true; text: "ACTIVE WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; text: "Active and inactive opacity/dim choices are independent. Hyprland uses one shared blur kernel, so the focused window's frosted choice sets the blur strength when active glass is enabled."; color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.activeOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: "Focused-window opacity and backdrop treatment."; selected: (root.desktopStyle.activeStyle || "native") === modelData.key; onClicked: root.chooseActive(modelData.key) } } }
        Text { Layout.fillWidth: true; text: "INACTIVE WINDOWS"; color: root.foregroundColor; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Text { Layout.fillWidth: true; text: root.optionDescription("inactiveStyle", root.desktopStyle.inactiveStyle || "native"); color: root.foregroundColor; opacity: 0.58; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: Style.space(5); rowSpacing: Style.space(5); Repeater { model: root.inactiveOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; compact: true; title: modelData.title; description: root.optionDescription("inactiveStyle", modelData.key); selected: (root.desktopStyle.inactiveStyle || "native") === modelData.key || (modelData.key === "frosted_balanced" && root.desktopStyle.inactiveStyle === "blur"); onClicked: root.chooseDesktop("inactiveStyle", modelData.key) } } }
    }
}
