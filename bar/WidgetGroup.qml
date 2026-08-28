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

Row {
    id: groupRoot
    property var bar: null
    required property string region
    required property var entries
    property bool active: true
    readonly property string groupRegion: region
    spacing: 0
    // Repeater delegates are created after the Row component itself. Keep
    // the group dimensions bound to the live child geometry so a compact
    // floating surface grows with its actual icons instead of leaving
    // late-loaded modules painting beyond the border.
    width: childrenRect.width
    height: childrenRect.height
    Repeater {
        model: active ? entries : []
        delegate: WidgetSlot {
            bar: groupRoot.bar
            required property var modelData
            entry: modelData
            region: groupRegion
        }
    }

}
