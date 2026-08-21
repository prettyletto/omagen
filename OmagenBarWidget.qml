import QtQuick
import QtQuick.Effects
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
    property color animatedDiamondColor: idleDiamondColor
    property real diamondGlowOpacity: 0.28

    readonly property color normalIconColor: root.bar ? root.bar.foreground : Color.foreground
    readonly property color accentAnchor: Color.accent
    readonly property color idleDiamondColor: Color.accent
    readonly property var accentRainbow: root.buildAccentRainbow(root.accentAnchor)
    readonly property string stateHome: {
        const configured = Quickshell.env("XDG_STATE_HOME")
        const home = Quickshell.env("HOME")
        return configured && configured.length > 0 ? configured : home + "/.local/state"
    }
    readonly property string activeSessionPath: root.stateHome + "/omagen/active-session.json"
    function buildAccentRainbow(baseColor) {
        var base = Qt.color(baseColor)
        var hue = base.hsvHue
        // A neutral accent has no hue. Start it at a cool blue and keep the
        // generated active-state colors vivid enough to survive a bar surface.
        if (hue < 0)
            hue = 0.58

        var saturation = Math.max(0.68, base.hsvSaturation)
        var value = Math.max(0.84, base.hsvValue)
        var offsets = [0.00, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84]
        var colors = []
        for (var i = 0; i < offsets.length; i++)
            colors.push(Qt.hsva((hue + offsets[i]) % 1.0, saturation, Math.min(0.98, value), 1.0))
        return colors
    }

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

        // Quit is deliberately independent from the overlay loader. Calling
        // shell.summon here would make a cold plugin appear before aborting.
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
        // Route through the plugin lifecycle when the shell is available so
        // both durable backend state and the already-loaded QML state reach
        // zero. open({action: "quit"}) aborts before showing any surface.
        if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function") {
            root.bar.shell.summon("pretty.omagen", JSON.stringify({ action: "quit" }));
            return;
        }

        // Defensive fallback for an unavailable shell host. Backend recovery
        // is idempotent and restores the same pre-session baseline.
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
        if (!next) {
            animatedDiamondColor = idleDiamondColor
            diamondGlowOpacity = 0.28
        }
    }

    SequentialAnimation {
        running: root.sessionActive
        loops: Animation.Infinite

        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[0]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[1]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[2]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[3]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[4]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[5]; duration: 420; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "animatedDiamondColor"; to: root.accentRainbow[6]; duration: 420; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        running: root.sessionActive
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "diamondGlowOpacity"; to: 0.56; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "diamondGlowOpacity"; to: 0.28; duration: 620; easing.type: Easing.InOutSine }
    }

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: Style.space(1)

        Text {
            text: "O"
            color: root.normalIconColor
            font.family: Style.font.family
            font.pixelSize: Style.bar.iconFont
            font.bold: true
        }

        Item {
            width: diamondGlow.implicitWidth
            height: diamondGlow.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: diamondGlow
                anchors.centerIn: parent
                text: "◈"
                color: root.animatedDiamondColor
                opacity: root.sessionActive ? 0.9 : 0
                font.family: Style.font.family
                font.pixelSize: Style.bar.iconFont
                font.bold: true
            }

            MultiEffect {
                anchors.fill: diamondGlow
                anchors.margins: -Style.space(5)
                source: diamondGlow
                visible: root.sessionActive
                blurEnabled: true
                blur: 1.0
                blurMax: 32
                blurMultiplier: 1.8
                opacity: root.diamondGlowOpacity
            }

            Text {
                anchors.centerIn: parent
                text: "◈"
                color: root.sessionActive ? root.animatedDiamondColor : root.idleDiamondColor
                scale: root.sessionActive ? 1.08 : 1.0
                // Keep the active accent readable when a rainbow step lands
                // near the current bar surface. Quattro's semantic bar
                // foreground is the contrast-safe outline for both themes.
                style: Text.Outline
                styleColor: root.normalIconColor
                font.family: Style.font.family
                font.pixelSize: Style.bar.iconFont
                font.bold: true
            }
        }
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
