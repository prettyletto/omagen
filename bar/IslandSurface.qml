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
    id: island
  property var bar: null
    default property alias contentData: content.data
    property real horizontalPadding: Style.space(8)
    property real verticalPadding: Style.space(6)

    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: content.implicitHeight + verticalPadding * 2

    BorderSurface {
        anchors.fill: parent
        color: bar.transparent
            ? "transparent"
            : bar.topology === "islands" || bar.topology === "minimal"
            ? Util.alpha(bar.replacementSurfaceColor, bar.surfaceOpacity)
            : bar.dock
            ? Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
            : Util.alpha(bar.surfaceColor, bar.surfaceOpacity)
        radius: Math.min(width, height) / 2
        borderSpec: bar.transparent ? Border.none() : Border.flat(
            Util.alpha(bar.borderColor, Math.max(bar.borderOpacity, 0.28)),
            Math.max(1, bar.borderWidth)
        )
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: island.horizontalPadding
        anchors.rightMargin: island.horizontalPadding
        anchors.topMargin: island.verticalPadding
        anchors.bottomMargin: island.verticalPadding
    }
}

