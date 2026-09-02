import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Compact access to the mutually-exclusive Demo surfaces. The component only
// renders intent; DemoController remains the owner of transitions and cleanup.
Item {
    id: root

    property bool controlsEnabled: true
    // Opening the switcher is deliberately independent from whether the
    // current session can start a demo. A visible Live Canvas may briefly be
    // ahead of session.workspaceReady during reload/recovery; the launcher
    // must still be a real, inspectable control in that state.
    property bool triggerEnabled: true
    property bool busy: false
    property bool demoActive: false
    property string demoMode: "none"
    property string buttonLabel: "Demos"
    property bool compact: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal modeRequested(string mode)

    readonly property bool canOpen: root.triggerEnabled && !root.busy
    readonly property bool canInteract: root.controlsEnabled && !root.busy
    property bool menuOpen: false
    readonly property var primaryModes: [
        { mode: "window", title: "Window Demo", description: "Two owned windows for focused styling." },
        { mode: "shell", title: "Shell Demo", description: "Read-only menus, popups, tooltips, and notifications." },
        { mode: "bar", title: "Bar Demo", description: "Read-only topology, density, regions, and motion." }
    ]

    implicitWidth: root.compact ? Style.space(86) : Style.space(92)
    implicitHeight: Style.space(34)
    focus: root.menuOpen

    function modeTitle(mode) {
        if (mode === "window") return "Window"
        if (mode === "shell") return "Shell"
        if (mode === "bar") return "Bar"
        if (mode === "full") return "Full Workspace"
        return "Demo"
    }

    function choose(mode) {
        if (!root.canInteract)
            return
        root.closeMenu()
        root.modeRequested(mode)
    }

    function openMenu() {
        if (!root.canOpen)
            return
        root.menuOpen = true
    }

    function closeMenu() {
        root.menuOpen = false
    }

    Keys.onEscapePressed: function(event) {
        if (!root.menuOpen)
            return
        root.closeMenu()
        event.accepted = true
    }

    Button {
        id: trigger
        anchors.fill: parent
        text: root.buttonLabel
        fontSize: Style.font.caption
        foreground: root.foregroundColor
        accent: root.accentColor
        background: root.menuOpen || root.demoActive
            ? Util.alpha(root.accentColor, 0.18)
            : Util.alpha(root.foregroundColor, 0.04)
        bordered: true
        enabled: root.canOpen
        tooltipText: root.demoActive
            ? "Switch or stop the active " + root.modeTitle(root.demoMode)
            : "Open Demo surfaces"
        onClicked: root.menuOpen ? root.closeMenu() : root.openMenu()
    }

    PopupWindow {
        id: menu
        visible: root.menuOpen
        color: "transparent"
        implicitWidth: Style.space(264)
        implicitHeight: menuColumn.implicitHeight + Style.space(20)

        anchor {
            id: menuAnchor
            window: trigger.QsWindow.window
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                const window = trigger.QsWindow.window
                if (!window)
                    return
                const point = window.contentItem.mapFromItem(
                    trigger,
                    trigger.width - menu.implicitWidth,
                    trigger.height + Style.space(6)
                )
                menuAnchor.rect.x = Math.round(point.x)
                menuAnchor.rect.y = Math.round(point.y)
            }
        }

        HyprlandFocusGrab {
            active: root.menuOpen
            windows: trigger.QsWindow.window ? [menu, trigger.QsWindow.window] : [menu]
            onCleared: root.closeMenu()
        }

        Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Qt.rgba(
                Color.popups.background.r,
                Color.popups.background.g,
                Color.popups.background.b,
                1
            )
            border.width: 1
            border.color: Color.popups.border
        }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(5)

            Text {
                Layout.fillWidth: true
                text: "DEMO SURFACES"
                color: root.accentColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.9
            }

            Text {
                Layout.fillWidth: true
                text: "Only one surface is active at a time."
                color: root.foregroundColor
                opacity: 0.6
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Repeater {
                model: root.primaryModes

                delegate: Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(52)
                    text: ""
                    foreground: root.foregroundColor
                    accent: root.accentColor
                    background: root.demoActive && root.demoMode === modelData.mode
                        ? Util.alpha(root.accentColor, 0.18)
                        : Util.alpha(root.foregroundColor, 0.04)
                    bordered: true
                    enabled: root.canInteract
                    tooltipText: modelData.description
                    onClicked: root.choose(modelData.mode)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        anchors.topMargin: Style.space(6)
                        anchors.bottomMargin: Style.space(6)
                        spacing: Style.space(2)

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: root.foregroundColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: root.demoActive && root.demoMode === modelData.mode
                                text: "ACTIVE"
                                color: root.accentColor
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.demoActive && root.demoMode === modelData.mode
                                ? "Click to stop this surface."
                                : modelData.description
                            color: root.foregroundColor
                            opacity: 0.62
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Util.alpha(root.foregroundColor, 0.14)
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(52)
                text: ""
                foreground: root.foregroundColor
                accent: root.accentColor
                background: root.demoActive && root.demoMode === "full"
                    ? Util.alpha(root.accentColor, 0.18)
                    : Util.alpha(root.foregroundColor, 0.04)
                bordered: true
                enabled: root.canInteract
                tooltipText: "Four owned windows for judging the complete composition."
                onClicked: root.choose("full")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(6)
                    anchors.bottomMargin: Style.space(6)
                    spacing: Style.space(2)

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Full Workspace"
                            color: root.foregroundColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                        }
                        Text {
                            visible: root.demoActive && root.demoMode === "full"
                            text: "ACTIVE"
                            color: root.accentColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.demoActive && root.demoMode === "full"
                            ? "Click to stop this workspace."
                            : "Four owned windows for the complete composition."
                        color: root.foregroundColor
                        opacity: 0.62
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
