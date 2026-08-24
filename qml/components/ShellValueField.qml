import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Small editor for an additive shell.toml value. Empty values remove the
// override and let the active Omarchy/theme reader provide its default.
Item {
    id: root

    property string label: ""
    property string description: ""
    property string value: ""
    property string placeholder: "Theme default"
    property bool modified: value !== ""

    signal valueEdited(string value)
    signal resetRequested()

    implicitHeight: fieldColumn.implicitHeight

    onValueChanged: if (!valueInput.activeFocus) valueInput.text = root.value

    ColumnLayout {
        id: fieldColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(3)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
                Layout.fillWidth: true
                text: root.label
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
            }

            Button {
                visible: root.modified
                Layout.preferredWidth: Style.space(46)
                Layout.preferredHeight: Style.space(22)
                text: "Reset"
                fontSize: Style.font.caption
                foreground: Color.foreground
                background: Util.alpha(Color.foreground, 0.045)
                accent: Color.accent
                bordered: true
                onClicked: root.resetRequested()
            }
        }

        Text {
            visible: root.description !== ""
            Layout.fillWidth: true
            text: root.description
            color: Color.foreground
            opacity: 0.54
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(34)
            radius: Math.max(Style.space(4), Style.cornerRadius / 2)
            color: Util.alpha(Color.background, 0.38)
            border.width: valueInput.activeFocus ? Math.max(1, Style.focusBorderWidth) : 1
            border.color: valueInput.activeFocus ? Color.accent : Util.alpha(Color.popups.border, 0.72)

            TextInput {
                id: valueInput
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                selectByMouse: true
                clip: true
                text: root.value
                verticalAlignment: TextInput.AlignVCenter
                onEditingFinished: root.valueEdited(text.trim())
                Keys.onReturnPressed: root.valueEdited(text.trim())
                Keys.onEnterPressed: root.valueEdited(text.trim())
                Keys.onEscapePressed: { text = root.value; focus = false }
            }

            Text {
                visible: valueInput.text === "" && !valueInput.activeFocus
                anchors.fill: valueInput
                color: Color.foreground
                opacity: 0.42
                text: root.placeholder
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                clip: true
            }
        }
    }
}
