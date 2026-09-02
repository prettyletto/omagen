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

Item {
    required property var icon
    required property var trayHost
    readonly property bool symbolic: trayHost.iconIsSymbolic(icon)

    Image {
        id: trayIconImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        source: String(parent.icon || "")
        visible: !parent.symbolic
        layer.enabled: parent.symbolic
    }

    MultiEffect {
        anchors.fill: trayIconImage
        source: trayIconImage
        visible: parent.symbolic
        colorization: 1.0
        colorizationColor: parent.trayHost.foreground
    }
}

