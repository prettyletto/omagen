import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
    id: moveGhost
    property var bar: null
    required property var ghostScreen
    readonly property bool screenMatches: bar.barMoveScreen === ghostScreen
        || (bar.barMoveScreen && ghostScreen && bar.barMoveScreen.name && ghostScreen.name
            && bar.barMoveScreen.name === ghostScreen.name)
    visible: !bar.nativeDefaultClone && bar.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "pretty-omagen-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    anchors { top: true; bottom: true; left: true; right: true }

    BorderSurface {
        visible: bar.barMoveCandidate === "top"
        x: 0; y: 0; width: parent.width; height: bar.barSize
        color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, 0.7)
        borderSpec: Border.flat(bar.barForeground, 1)
        opacity: 0.8
    }
    BorderSurface {
        visible: bar.barMoveCandidate === "bottom"
        x: 0; y: parent.height - bar.barSize; width: parent.width; height: bar.barSize
        color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, 0.7)
        borderSpec: Border.flat(bar.barForeground, 1)
        opacity: 0.8
    }
    BorderSurface {
        visible: bar.barMoveCandidate === "left"
        x: 0; y: 0; width: bar.barSize; height: parent.height
        color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, 0.7)
        borderSpec: Border.flat(bar.barForeground, 1)
        opacity: 0.8
    }
    BorderSurface {
        visible: bar.barMoveCandidate === "right"
        x: parent.width - bar.barSize; y: 0; width: bar.barSize; height: parent.height
        color: bar.transparent ? "transparent" : Util.alpha(bar.surfaceColor, 0.7)
        borderSpec: Border.flat(bar.barForeground, 1)
        opacity: 0.8
    }
}
