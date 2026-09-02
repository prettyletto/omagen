import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast
import "../../components" as Components

Item {
    id: root

    property string title: "Live Canvas"
    property string subtitle: "Build a reversible Omarchy preview one decision at a time."
    property string operationText: ""
    property string errorText: ""
    property int step: 0
    property int stepCount: 5
    property var steps: ["Palette", "Look & Feel", "Advanced", "Demo", "Finish"]
    property bool busy: false
    property bool demoBusy: false
    property bool demoActive: false
    property string demoMode: "none"
    property bool workspaceReady: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal hideRequested()
    signal demoRequested(string mode)

    implicitHeight: chrome.implicitHeight

    ColumnLayout {
        id: chrome
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.foregroundColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: root.foregroundColor
                    opacity: 0.58
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
            }

            Components.DemoSwitcher {
                Layout.preferredWidth: Style.space(92)
                Layout.preferredHeight: Style.space(34)
                triggerEnabled: !root.busy
                controlsEnabled: root.workspaceReady && !root.busy
                busy: root.demoBusy
                demoActive: root.demoActive
                demoMode: root.demoMode
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onModeRequested: root.demoRequested(mode)
            }

            Button {
                Layout.preferredWidth: Style.space(34)
                Layout.preferredHeight: Style.space(34)
                text: "×"
                fontSize: Style.font.title
                foreground: root.foregroundColor
                accent: root.accentColor
                background: Util.alpha(root.foregroundColor, 0.04)
                bordered: true
                tooltipText: "Hide Live Canvas"
                onClicked: root.hideRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
                model: root.steps

                delegate: Item {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(35)

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.space(5)
                        color: index === root.step
                            ? root.accentColor
                            : index < root.step
                                ? Util.alpha(root.accentColor, 0.16)
                                : Util.alpha(root.foregroundColor, 0.04)
                        border.width: 1
                        border.color: index === root.step
                            ? root.accentColor
                            : index < root.step
                                ? Util.alpha(root.accentColor, 0.42)
                                : Util.alpha(root.foregroundColor, 0.15)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(7)
                            anchors.rightMargin: Style.space(7)
                            text: (index < root.step ? "✓  " : (index + 1) + "  ") + modelData
                            color: index === root.step
                                ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                                : root.foregroundColor
                            opacity: index === root.step ? 1 : index < root.step ? 0.82 : 0.5
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: index === root.step
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.busy || root.operationText !== "" || root.errorText !== ""
            Layout.preferredHeight: Math.max(Style.space(28), operationLabel.implicitHeight + Style.space(12))
            radius: Style.space(5)
            color: root.errorText !== ""
                ? Util.alpha(Color.urgent, 0.12)
                : Util.alpha(root.accentColor, 0.09)
            border.width: 1
            border.color: root.errorText !== ""
                ? Util.alpha(Color.urgent, 0.42)
                : Util.alpha(root.accentColor, 0.3)

            Text {
                id: operationLabel
                anchors.fill: parent
                anchors.leftMargin: Style.space(9)
                anchors.rightMargin: Style.space(9)
                text: root.errorText !== ""
                    ? root.errorText
                    : root.operationText !== "" ? root.operationText : "Working…"
                color: root.errorText !== "" ? Color.urgent : root.foregroundColor
                opacity: root.errorText !== "" ? 1 : 0.78
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
