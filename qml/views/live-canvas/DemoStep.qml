import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast

Item {
    id: root

    property bool demoActive: false
    property bool demoBusy: false
    property string demoMode: "none"
    property string monitorName: ""
    property string errorMessage: ""
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal startRequested()
    signal stopRequested()
    signal skipRequested()

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        Text {
            Layout.fillWidth: true
            text: "Preview the real desktop"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "The Full Demo opens four session-owned windows on the selected monitor. Stop it to return here without ending the preview session."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusColumn.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: root.demoActive ? Util.alpha(root.accentColor, 0.1) : Util.alpha(root.foregroundColor, 0.035)
            border.width: 1
            border.color: root.demoActive ? Util.alpha(root.accentColor, 0.45) : Util.alpha(root.foregroundColor, 0.16)

            ColumnLayout {
                id: statusColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(16)
                spacing: Style.space(7)

                Text {
                    Layout.fillWidth: true
                    text: root.demoBusy
                        ? (root.demoActive ? "CLOSING FULL DEMO" : "OPENING FULL DEMO")
                        : root.demoActive ? "FULL DEMO IS LIVE" : "FULL DEMO READY"
                    color: root.demoActive ? root.accentColor : root.foregroundColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    Layout.fillWidth: true
                    text: root.demoActive
                        ? "Four owned windows are arranged on " + (root.monitorName || "the selected monitor") + "."
                        : "Start the demo to inspect the complete staged composition in context."
                    color: root.foregroundColor
                    opacity: 0.68
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(40)
                    text: root.demoBusy
                        ? (root.demoActive ? "Stopping demo…" : "Starting demo…")
                        : (root.demoActive ? "Stop Full Demo" : "Start Full Demo")
                    foreground: root.demoActive
                        ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        : root.foregroundColor
                    accent: root.accentColor
                    background: root.demoActive ? root.accentColor : Util.alpha(root.accentColor, 0.18)
                    bordered: true
                    enabled: !root.demoBusy
                    onClicked: root.demoActive ? root.stopRequested() : root.startRequested()
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Skip Demo"
            foreground: root.foregroundColor
            accent: root.accentColor
            background: Util.alpha(root.foregroundColor, 0.045)
            bordered: true
            enabled: !root.demoBusy
            onClicked: root.skipRequested()
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
