import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "." as Local

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
    signal modeRequested(string mode)
    signal skipRequested()

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        Text {
            Layout.fillWidth: true
            text: "Demo Studio"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "Choose one focused surface at a time. Every Demo uses a session-owned workspace; Window and Full Workspace add owned windows, while Shell and Bar are read-only readers."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(112)
                eyebrow: "OWNED"
                title: "Window Demo"
                description: root.demoMode === "window" && root.demoActive
                    ? "Click to stop the focused window surface."
                    : "Two real session-owned windows for focused styling."
                status: root.demoMode === "window" && root.demoActive ? "ACTIVE" : "READY"
                selected: root.demoMode === "window" && root.demoActive
                live: root.demoMode === "window" && root.demoActive
                enabled: !root.demoBusy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.modeRequested("window")
            }

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(112)
                eyebrow: "READER"
                title: "Shell Demo"
                description: root.demoMode === "shell" && root.demoActive
                    ? "Click to stop the Shell reader."
                    : "Read-only menus, popups, tooltips, and notifications."
                status: root.demoMode === "shell" && root.demoActive ? "ACTIVE" : "READY"
                selected: root.demoMode === "shell" && root.demoActive
                live: root.demoMode === "shell" && root.demoActive
                enabled: !root.demoBusy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.modeRequested("shell")
            }

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(112)
                eyebrow: "READER"
                title: "Bar Demo"
                description: root.demoMode === "bar" && root.demoActive
                    ? "Click to stop the Bar reader."
                    : "Read-only topology, density, regions, and motion."
                status: root.demoMode === "bar" && root.demoActive ? "ACTIVE" : "READY"
                selected: root.demoMode === "bar" && root.demoActive
                live: root.demoMode === "bar" && root.demoActive
                enabled: !root.demoBusy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.modeRequested("bar")
            }

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(112)
                eyebrow: "OWNED"
                title: "Full Workspace"
                description: root.demoMode === "full" && root.demoActive
                    ? "Click to stop the four-window workspace."
                    : "Four real session-owned windows for the full composition."
                status: root.demoMode === "full" && root.demoActive ? "ACTIVE" : "SECONDARY"
                selected: root.demoMode === "full" && root.demoActive
                live: root.demoMode === "full" && root.demoActive
                enabled: !root.demoBusy
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.modeRequested("full")
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
