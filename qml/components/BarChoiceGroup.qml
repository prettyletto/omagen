import QtQuick
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// A compact, shell-native inspector group.  Bar choices are presented as
// controls inside one semantic surface instead of a flat grid of unrelated
// cards, so the hierarchy reads like Quattro's own settings panels.
BorderSurface {
    id: root

    required property string title
    property string subtitle: ""
    property string selectedKey: ""
    property var options: []
    property var optionDescriptions: ({})
    property int columns: 2
    property string selectedTitleOverride: ""
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal choiceSelected(string key)

    readonly property real buttonHeight: Style.space(34)
    readonly property real gap: Style.space(5)
    readonly property int optionRows: Math.max(1, Math.ceil(root.options.length / Math.max(1, root.columns)))
    readonly property real headerHeight: Style.space(32)
    readonly property real optionsHeight: root.optionRows * root.buttonHeight + Math.max(0, root.optionRows - 1) * root.gap

    // Keep this surface's geometry explicit. Nested layouts inside a
    // BorderSurface can negotiate a zero height while the parent panel is
    // resizing, which makes titles and controls paint on top of one another.
    implicitHeight: Style.space(20) + root.headerHeight + root.gap + root.optionsHeight
    color: Util.alpha(root.foregroundColor, 0.035)
    radius: Math.max(Style.space(6), Style.cornerRadius / 2)
    borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.72), 1)

    function selectedTitle() {
        if (root.selectedTitleOverride !== "") return root.selectedTitleOverride
        for (var index = 0; index < root.options.length; index++) {
            if (root.options[index].key === root.selectedKey)
                return root.options[index].title
        }
        return "Native"
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        anchors.topMargin: Style.space(9)
        height: root.headerHeight

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.right: selectedLabel.left
            anchors.top: parent.top
            height: Style.space(15)
            text: root.title.toUpperCase()
            color: root.foregroundColor
            opacity: 0.76
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.7
            elide: Text.ElideRight
        }

        Text {
            id: selectedLabel
            anchors.right: parent.right
            anchors.top: parent.top
            width: Math.min(Style.space(110), parent.width * 0.32)
            height: Style.space(15)
            text: root.selectedTitle()
            color: root.accentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Style.space(16)
            height: Style.space(15)
            text: root.subtitle
            color: root.foregroundColor
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
        }
    }

    Item {
        id: optionsGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: root.gap
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        height: root.optionsHeight

        Repeater {
            model: root.options

            delegate: Button {
                required property var modelData
                required property int index
                x: (index % root.columns) * ((optionsGrid.width - (root.columns - 1) * root.gap) / root.columns + root.gap)
                y: Math.floor(index / root.columns) * (root.buttonHeight + root.gap)
                width: (optionsGrid.width - (root.columns - 1) * root.gap) / root.columns
                height: root.buttonHeight
                text: modelData.title
                fontSize: Style.font.caption
                foreground: root.selectedKey === modelData.key
                    ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                    : root.foregroundColor
                background: root.selectedKey === modelData.key
                    ? root.accentColor : Util.alpha(root.foregroundColor, 0.025)
                accent: root.accentColor
                // Paint the selected state explicitly so native shell tokens
                // cannot force a light label onto a dark staged accent.
                selected: false
                bordered: true
                focusable: true
                tooltipText: root.optionDescriptions[modelData.key] || ""
                enabled: root.enabled
                onClicked: root.choiceSelected(modelData.key)
            }
        }
    }
}
