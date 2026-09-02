import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "." as Local

Item {
    id: root

    property string workflowMode: "fast"
    property bool workflowSelected: false
    property string sourceImage: ""
    property int cursorIndex: -1
    property bool busy: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal workflowModeSelected(string mode)

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        Text {
            Layout.fillWidth: true
            text: "Choose your workflow"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "Choose how much control you want. You can review every decision on the next pages before anything is saved."
            color: root.foregroundColor
            opacity: 0.64
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: root.sourceImage !== ""
            text: "Source image  ·  " + root.sourceImage
            color: root.foregroundColor
            opacity: 0.52
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(132)
                eyebrow: "QUICK START"
                title: "Fast"
                description: "Pick a colour direction, preview it, then save or restore."
                status: root.workflowSelected && root.workflowMode === "fast" ? "SELECTED" : "CHOOSE"
                selected: root.workflowSelected && root.workflowMode === "fast"
                hasCursor: root.cursorIndex === 0
                enabled: !root.busy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.workflowModeSelected("fast")
            }

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(132)
                eyebrow: "STUDIO"
                title: "In-depth"
                description: "Open Look & Feel and Advanced controls before you decide."
                status: root.workflowSelected && root.workflowMode === "in-depth" ? "SELECTED" : "CHOOSE"
                selected: root.workflowSelected && root.workflowMode === "in-depth"
                hasCursor: root.cursorIndex === 1
                enabled: !root.busy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.workflowModeSelected("in-depth")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusText.implicitHeight + Style.space(22)
            radius: Style.space(6)
            color: root.workflowSelected
                ? Util.alpha(root.accentColor, 0.08)
                : Util.alpha(root.foregroundColor, 0.035)
            border.width: 1
            border.color: root.workflowSelected
                ? Util.alpha(root.accentColor, 0.3)
                : Util.alpha(root.foregroundColor, 0.16)

            Text {
                id: statusText
                anchors.fill: parent
                anchors.margins: Style.space(11)
                text: root.workflowSelected
                    ? (root.workflowMode === "in-depth"
                        ? "In-depth selected · the Studio pages will be available after palette generation."
                        : "Fast selected · the wizard will keep the path focused and lightweight.")
                    : "Select Fast or In-depth to continue."
                color: root.foregroundColor
                opacity: 0.72
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
