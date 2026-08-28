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
    id: centerGestureGroup
    required property var bar
    required property var entries
    property string region: "center"
    readonly property bool hasAnchor: bar.entryIndex(centerGestureGroup.entries, bar.centerAnchor) >= 0
    readonly property var anchorEntry: bar.entryNamed(centerGestureGroup.entries, bar.centerAnchor)
    implicitWidth: bar.vertical
        ? (centerAnchoredColumn.visible ? centerAnchoredColumn.implicitWidth : centerColumn.implicitWidth)
        : (centerAnchoredRow.visible ? centerAnchoredRow.implicitWidth : centerRow.implicitWidth)
    implicitHeight: bar.vertical
        ? (centerAnchoredColumn.visible ? centerAnchoredColumn.implicitHeight : centerColumn.implicitHeight)
        : (centerAnchoredRow.visible ? centerAnchoredRow.implicitHeight : centerRow.implicitHeight)

        Row {
            id: centerRow
            anchors.centerIn: parent
            spacing: 0
            visible: !bar.vertical && !centerGestureGroup.hasAnchor
            WidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
                entries: centerGestureGroup.entries
                active: centerRow.visible
            }
        }

    Row {
        id: centerAnchoredRow
        anchors.centerIn: parent
        spacing: 0
            visible: !bar.vertical && centerGestureGroup.hasAnchor
            WidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
                entries: bar.entriesBefore(centerGestureGroup.entries, bar.centerAnchor)
                active: centerAnchoredRow.visible
            }
            WidgetSlot {
                bar: centerGestureGroup.bar
                entry: centerGestureGroup.anchorEntry
                region: "center"
                active: centerAnchoredRow.visible
            }
            WidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
                entries: bar.entriesAfter(centerGestureGroup.entries, bar.centerAnchor)
                active: centerAnchoredRow.visible
            }
        }

    Column {
        id: centerColumn
        anchors.centerIn: parent
        spacing: 0
        visible: bar.vertical && !centerGestureGroup.hasAnchor
            VerticalWidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
            entries: centerGestureGroup.entries
            active: centerColumn.visible
        }
        }

    Column {
        id: centerAnchoredColumn
        anchors.centerIn: parent
        spacing: 0
        visible: bar.vertical && centerGestureGroup.hasAnchor
            VerticalWidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
            entries: bar.entriesBefore(centerGestureGroup.entries, bar.centerAnchor)
            active: centerAnchoredColumn.visible
        }
            WidgetSlot {
                bar: centerGestureGroup.bar
                entry: centerGestureGroup.anchorEntry
            region: "center"
            active: centerAnchoredColumn.visible
        }
            VerticalWidgetGroup {
                bar: centerGestureGroup.bar
                region: "center"
            entries: bar.entriesAfter(centerGestureGroup.entries, bar.centerAnchor)
            active: centerAnchoredColumn.visible
        }
    }

    MouseArea {
        id: centerGesture
        property bool dragging: false
        property bool suppressClick: false
        property real pressedX: 0
        property real pressedY: 0
        readonly property real dragThreshold: Style.space(4)
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true
        // Keep widget slots above the gesture so their own reorder/click
        // handlers remain authoritative; the gesture still receives
        // pointer input in the center section's empty space.
        z: -1
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

        onPressed: function(mouse) {
            dragging = false
            suppressClick = false
            pressedX = mouse.x
            pressedY = mouse.y
        }
        onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
            if (!dragging && distance >= dragThreshold) {
                dragging = true
                bar.beginBarMove(bar.targetWindow(centerGesture))
            }
            if (!dragging) return
            var scenePoint = centerGesture.mapToItem(null, mouse.x, mouse.y)
            bar.updateBarMove(bar.windowScreenPoint(scenePoint, bar.barMoveWindow))
        }
        onReleased: function(mouse) {
            if (!dragging) {
                mouse.accepted = false
                return
            }
            dragging = false
            suppressClick = true
            bar.finishBarMove()
            mouse.accepted = true
        }
        onCanceled: {
            dragging = false
            suppressClick = false
            bar.clearBarMove()
        }
        onClicked: function(mouse) {
            if (suppressClick) {
                suppressClick = false
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
        onDoubleClicked: function(mouse) {
            if (suppressClick) {
                suppressClick = false
                return
            }
            if (mouse.button === Qt.LeftButton) {
                bar.toggleTransparency()
                mouse.accepted = true
            }
        }
    }
}
