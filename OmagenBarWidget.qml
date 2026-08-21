import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// The bar keeps the familiar left-click summon, while right-click exposes
// the small lifecycle menu used by Omagen.  KeyboardPanel gives this menu
// the same focus prime and outside-click release behavior as Quattro's own
// panels, so it cannot strand pointer or keyboard focus in the shell.
BarWidget {
    id: root

    moduleName: "pretty.omagen"
    property bool menuOpen: false
    property int menuIndex: 0
    property string pendingMethod: ""
    property int pendingAttempts: 0
    property bool quitBusy: false

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

        // Open must go through summon so the lazy overlay loader is created
        // after a shell restart. Settings calls the loaded QML instance
        // directly, retrying briefly while that loader resolves.
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
        root.pendingMethod = "";
        invokeRetry.stop();

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

    function callPendingMethod() {
        if (root.pendingMethod === "" || !root.bar || !root.bar.shell)
            return;

        let result = typeof root.bar.shell.call === "function"
            ? root.bar.shell.call("pretty.omagen", root.pendingMethod, "")
            : "unknown";
        if (result !== "unknown") {
            root.pendingMethod = "";
            return;
        }

        if (root.pendingAttempts >= 10) {
            root.pendingMethod = "";
            return;
        }

        // Summon once to instantiate the overlay, then retry Settings after
        // the Loader has had a chance to resolve.
        if (root.pendingAttempts === 0)
            root.bar.shell.summon("pretty.omagen", "{}");
        root.pendingAttempts += 1;
        invokeRetry.restart();
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

    Text {
        anchors.centerIn: parent
        text: "O"
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.bar.iconFont
        font.bold: true
    }

    Timer {
        id: invokeRetry
        interval: 40
        repeat: false
        onTriggered: root.callPendingMethod()
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
