import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui
import "." as Bar

WidgetButton {
    required property var entry
    property var bar: null
    readonly property var settings: bar.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined
        return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
        var data = Util.parseModuleJson(raw)
        var klass = data.class || data.alt || ""
        outputText = data.text || String(raw || "").trim()
        outputTooltip = data.tooltip || String(setting("tooltip", ""))
        outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))
    onPressed: function(button) {
        var command = button === Qt.RightButton ? String(setting("onRightClick", ""))
            : button === Qt.MiddleButton ? String(setting("onMiddleClick", ""))
            : String(setting("onClick", ""))
        if (command) bar.run(command)
    }

    Process {
        id: customProcess
        command: ["bash", "-lc", String(parent.setting("exec", ""))]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: parent.parent.update(text)
        }
    }
    Timer {
        interval: Math.max(1, Number(parent.setting("interval", 5))) * 1000
        running: String(parent.setting("exec", "")) !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.runProcess(customProcess)
    }
}

