import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "qml/components" as Components

// The bar keeps the familiar left-click summon, while right-click exposes
// the small lifecycle menu used by Omagen.  KeyboardPanel gives this menu
// the same focus prime and outside-click release behavior as Quattro's own
// panels, so it cannot strand pointer or keyboard focus in the shell.
BarWidget {
    id: root

    moduleName: "pretty.omagen"
    property bool menuOpen: false
    property int menuIndex: 0
    property bool quitBusy: false
    property bool sessionActive: false
    property color animatedIconColor: normalIconColor

    readonly property color normalIconColor: root.bar ? root.bar.foreground : Color.foreground
    readonly property string stateHome: {
        const configured = Quickshell.env("XDG_STATE_HOME")
        const home = Quickshell.env("HOME")
        return configured && configured.length > 0 ? configured : home + "/.local/state"
    }
    readonly property string activeSessionPath: root.stateHome + "/omagen/active-session.json"
    readonly property var rainbowColors: [
        "#ff6b6b", "#ffd166", "#7bd88f", "#5ed0e6", "#7aa7ff", "#c58cff", "#ff7ac8"
    ]

    readonly property string backendPath: decodeURIComponent(
        Qt.resolvedUrl("bin/omagen")
            .toString()
            .replace("file://", "")
    )

    function close() {
        menuOpen = false;
    }

    // The bar host captures left clicks at ModuleSlot level and dispatches
    // them through this contract.  Without it, the inner MouseArea only gets
    // the right-click path because the host intentionally owns left-click
    // routing for reorderable modules.
    function triggerPress(buttonCode) {
        if (buttonCode === Qt.RightButton) {
            // ModuleSlot owns bar input in current Quickshell. Handle the
            // secondary click here so the widget menu remains reachable even
            // when the slot consumes the event before the child MouseArea.
            root.menuIndex = 0;
            root.menuOpen = !root.menuOpen;
            return;
        }
        if (buttonCode === Qt.LeftButton)
            invoke("open");
    }

    function invoke(action) {
        menuOpen = false;

        // Quit is deliberately independent from the overlay loader.  Calling
        // shell.summon here makes a cold/lazy plugin appear before the quit
        // method can be delivered, which leaves the user with an open overlay.
        if (action === "quit") {
            quitNow();
            return;
        }

        if (!root.bar || !root.bar.shell)
            return;

        // Open and Settings both go through summon so the lazy overlay loader
        // is created after a shell restart.
        if (action === "open") {
            root.bar.shell.summon("pretty.omagen", "{}");
            return;
        }

        // Passing the action through summon is reliable for a cold plugin:
        // the overlay loader receives the payload during construction and
        // opens the settings route directly, without first showing setup.
        if (action === "settings") {
            root.bar.shell.summon("pretty.omagen", JSON.stringify({ action: "settings" }));
            return;
        }
    }

    function quitNow() {
        // Close any already-visible surface without creating one.  The
        // backend recovery command is authoritative for demo, pending Apply,
        // theme/background restoration, and durable session cleanup.
        if (root.bar && root.bar.shell && typeof root.bar.shell.hide === "function")
            root.bar.shell.hide("pretty.omagen");

        if (root.quitBusy)
            return;
        root.quitBusy = true;
        quitProcess.exec([root.backendPath, "session", "recover"]);
    }

    function activateMenu() {
        if (menuIndex === 0)
            invoke("open");
        else if (menuIndex === 1)
            invoke("settings");
        else
            invoke("quit");
    }

    implicitWidth: Style.bar.statusSlot
    implicitHeight: barSize

    Components.DockedBarSurface {
        anchorItem: root
        bar: root.bar
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: if (!activeSessionProbe.running) activeSessionProbe.running = true
    }

    // The marker is written atomically by the backend, so a non-empty file is
    // the authoritative, race-free signal that an Omagen session is active.
    // Checking the path directly also avoids FileView retaining stale JSON
    // after the marker is removed during recovery or normal completion.
    Process {
        id: activeSessionProbe
        command: ["/usr/bin/test", "-s", root.activeSessionPath]
        running: true
        onExited: function(exitCode) { root.setSessionActive(exitCode === 0) }
    }

    function setSessionActive(next) {
        next = next === true
        if (sessionActive === next)
            return
        sessionActive = next
        if (!next)
            animatedIconColor = normalIconColor
    }

    SequentialAnimation {
        running: root.sessionActive
        loops: Animation.Infinite

        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[0]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[1]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[2]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[3]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[4]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[5]; duration: 280; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedIconColor"; to: root.rainbowColors[6]; duration: 280; easing.type: Easing.InOutSine }
    }

    Text {
        anchors.centerIn: parent
        text: "O"
        color: root.sessionActive ? root.animatedIconColor : root.normalIconColor
        font.family: Style.font.family
        font.pixelSize: Style.bar.iconFont
        font.bold: true
    }

    Process {
        id: quitProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: root.quitBusy = false
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.menuIndex = 0;
                root.menuOpen = !root.menuOpen;
            } else {
                root.invoke("open");
            }
        }
    }

    KeyboardPanel {
        id: menu
        anchorItem: root
        owner: root
        bar: root.bar
        open: root.menuOpen
        focusTarget: keyCatcher
        contentWidth: menu.fittedContentWidth(Style.space(250))
        contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onMoveRequested: function(dx, dy) {
                if (dy === 0)
                    return;
                root.menuIndex = (root.menuIndex + (dy > 0 ? 1 : -1) + 3) % 3;
            }
            onActivateRequested: root.activateMenu()

            Column {
                id: menuColumn
                anchors.fill: parent
                spacing: Style.space(4)

                Text {
                    width: parent.width
                    text: "OMAGEN"
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: "Quattro theme studio"
                    color: Color.popups.text
                    opacity: 0.58
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                PanelSeparator { width: parent.width }

                Button {
                    width: parent.width
                    text: "Open"
                    iconText: "󰐕"
                    leftAlign: true
                    foreground: Color.popups.text
                    hasCursor: root.menuIndex === 0
                    onClicked: root.invoke("open")
                }

                Button {
                    width: parent.width
                    text: "Settings"
                    iconText: "󰒓"
                    leftAlign: true
                    foreground: Color.popups.text
                    hasCursor: root.menuIndex === 1
                    onClicked: root.invoke("settings")
                }

                Button {
                    width: parent.width
                    text: "Quit"
                    iconText: "󰗼"
                    leftAlign: true
                    foreground: Color.popups.text
                    hasCursor: root.menuIndex === 2
                    onClicked: root.invoke("quit")
                }
            }
        }
    }
}
