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

Column {
    id: groupRoot
    property var bar: null
    required property string region
    required property var entries
    property bool active: true
    property bool centerSlots: false
    // Keep delegates mounted while a compact composition hides the group.
    // Clamping the group's height avoids rebuilding panel-owning widgets.
    property bool collapseContents: false
    readonly property string groupRegion: region
    spacing: 0
    height: collapseContents ? 0 : childrenRect.height
    clip: collapseContents
    enabled: !collapseContents
    Repeater {
        model: active ? entries : []
        delegate: Item {
            id: slotFrame
            required property var modelData
            width: groupRoot.centerSlots ? groupRoot.width : slot.implicitWidth
            height: slot.implicitHeight

            // The compact floating rail has an inset narrower than a
            // barSize-wide widget. Give edge groups a full-width wrapper
            // and center their real slot inside it; the center group
            // retains its existing intrinsic-width composition.
            WidgetSlot {
                id: slot
                bar: groupRoot.bar
                entry: slotFrame.modelData
                region: groupRoot.groupRegion
                active: groupRoot.active
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
