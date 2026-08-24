import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A compact shell-token colour row. Semantic values such as "accent" are
// previewed with fallbackColor; picking a colour stages an explicit hex value.
Item {
    id: root

    property string tokenKey: ""
    property string label: ""
    property string description: ""
    property string value: ""
    property color fallbackColor: Color.accent
    property bool expanded: false
    property bool modified: value !== ""

    signal valueEdited(string value)
    signal resetRequested()

    readonly property string fallbackHex: {
        var text = String(root.fallbackColor)
        return text.indexOf("#") === 0 ? text.slice(0, 7).toUpperCase() : "#FFFFFF"
    }
    readonly property string pickerValue: /^#[0-9A-Fa-f]{6}$/.test(root.value) ? root.value : root.fallbackHex

    implicitHeight: headerColumn.implicitHeight + (root.expanded ? colorEditor.implicitHeight + Style.space(8) : 0)

    ColumnLayout {
        id: headerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(3)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.space(5)
                color: root.pickerValue
                border.width: 1
                border.color: Util.alpha(Color.foreground, 0.42)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { Layout.fillWidth: true; text: root.label; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: root.modified ? root.value : "Theme token · " + root.fallbackHex; color: root.modified ? Color.accent : Color.foreground; opacity: root.modified ? 1 : 0.54; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
            }

            Rectangle {
                Layout.preferredWidth: Style.space(62)
                Layout.preferredHeight: Style.space(28)
                color: Util.alpha(Color.foreground, 0.045)
                border.width: 1
                border.color: Util.alpha(Color.popups.border, 0.72)
                radius: Math.max(Style.space(3), Style.cornerRadius / 3)
                Text {
                    anchors.fill: parent
                    text: root.expanded ? "Close" : "Pick"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }

            Rectangle {
                visible: root.modified
                Layout.preferredWidth: Style.space(46)
                Layout.preferredHeight: Style.space(28)
                color: Util.alpha(Color.foreground, 0.045)
                border.width: 1
                border.color: Util.alpha(Color.popups.border, 0.72)
                radius: Math.max(Style.space(3), Style.cornerRadius / 3)
                Text {
                    anchors.fill: parent
                    text: "Reset"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetRequested()
                }
            }
        }

        Text { visible: root.description !== ""; Layout.fillWidth: true; text: root.description; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    }

    ColorRoleEditor {
        id: colorEditor
        visible: root.expanded
        anchors.top: headerColumn.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Style.space(8)
        roleKey: root.tokenKey
        roleLabel: root.label
        roleDescription: root.description
        value: root.pickerValue
        presetValue: root.fallbackHex
        live: false
        onValueEdited: function(hex) { root.valueEdited(hex) }
    }
}
