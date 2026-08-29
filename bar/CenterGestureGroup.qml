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
    // Orbit uses this while collapsed. The center anchor stays mounted and
    // centered, while the before/after groups are clipped to zero without
    // changing their Repeater models.
    property bool compactAnchorOnly: false

    readonly property bool hasAnchor: bar.entryIndex(centerGestureGroup.entries,
        bar.centerAnchor) >= 0
    readonly property var anchorEntry: bar.entryNamed(centerGestureGroup.entries,
        bar.centerAnchor)
    readonly property real anchorWidth: !bar.vertical && hasAnchor
        ? centerAnchorModule.implicitWidth : 0
    readonly property real anchorHeight: bar.vertical && hasAnchor
        ? centerAnchorModule.implicitHeight : 0
    readonly property real beforeWidth: compactAnchorOnly ? 0 : centerBeforeGroup.implicitWidth
    readonly property real afterWidth: compactAnchorOnly ? 0 : centerAfterGroup.implicitWidth
    readonly property real beforeHeight: compactAnchorOnly ? 0 : centerBeforeColumn.implicitHeight
    readonly property real afterHeight: compactAnchorOnly ? 0 : centerAfterColumn.implicitHeight
    // The clock stays centered, but a trayable indicator block can be much
    // wider/taller on one side of it. Reserve that difference as symmetric
    // space; otherwise the heavier side paints outside the center capsule and
    // its inactive indicators are clipped during expansion.
    readonly property real horizontalSideBalance: !bar.vertical && hasAnchor
        ? Math.abs(beforeWidth - afterWidth) : 0
    readonly property real verticalSideBalance: bar.vertical && hasAnchor
        ? Math.abs(beforeHeight - afterHeight) : 0

    // The anchor is centered in the parent, matching Quattro's native center
    // host. The side groups attach to the anchor rather than to the overall
    // row, so unequal side content cannot move the clock off the monitor
    // center.
    implicitWidth: bar.vertical
        ? (hasAnchor
            ? Math.max(anchorWidth, centerBeforeColumn.implicitWidth,
                centerAfterColumn.implicitWidth)
            : centerColumn.implicitWidth)
        : (hasAnchor
            ? beforeWidth + anchorWidth + afterWidth + horizontalSideBalance
            : centerRow.implicitWidth)
    implicitHeight: bar.vertical
        ? (hasAnchor
            ? beforeHeight + anchorHeight + afterHeight + verticalSideBalance
            : centerColumn.implicitHeight)
        : (hasAnchor
            ? Math.max(centerBeforeGroup.implicitHeight,
                centerAnchorModule.implicitHeight,
                centerAfterGroup.implicitHeight)
            : centerRow.implicitHeight)

    // Omarchy's native center host holds indicator reveals while the pointer
    // crosses the expanding center row. Attach the handler to the containing
    // host rather than this content-sized group: inactive indicators such as
    // screen recording and Stay Awake can widen/reposition the group without
    // making the pointer leave its hover target.
    HoverHandler {
        // The parent Item is the stable center host in every preset. This is
        // the same ownership boundary as native CenterModules' anchors.fill
        // container, while the visual rows below retain their own measured
        // geometry.
        parent: centerGestureGroup.parent || centerGestureGroup
        onHoveredChanged: centerGestureGroup.bar.setCenterSectionHovered(hovered)
    }

    Row {
        id: centerRow
        anchors.centerIn: parent
        spacing: 0
        visible: !bar.vertical && !centerGestureGroup.hasAnchor

        WidgetGroup {
            bar: centerGestureGroup.bar
            region: "center"
            entries: centerGestureGroup.entries
            active: !centerGestureGroup.hasAnchor
        }
    }

    WidgetGroup {
        id: centerBeforeGroup
        bar: centerGestureGroup.bar
        region: "center"
        entries: bar.entriesBefore(centerGestureGroup.entries, bar.centerAnchor)
        active: centerGestureGroup.hasAnchor
        collapseContents: centerGestureGroup.compactAnchorOnly
        visible: !bar.vertical && centerGestureGroup.hasAnchor
        anchors.right: centerAnchorModule.left
        anchors.verticalCenter: centerAnchorModule.verticalCenter
    }

    WidgetSlot {
        id: centerAnchorModule
        bar: centerGestureGroup.bar
        entry: centerGestureGroup.anchorEntry
        region: "center"
        active: centerGestureGroup.hasAnchor
        visible: centerGestureGroup.hasAnchor
        anchors.centerIn: parent
    }

    WidgetGroup {
        id: centerAfterGroup
        bar: centerGestureGroup.bar
        region: "center"
        entries: bar.entriesAfter(centerGestureGroup.entries, bar.centerAnchor)
        active: centerGestureGroup.hasAnchor
        collapseContents: centerGestureGroup.compactAnchorOnly
        visible: !bar.vertical && centerGestureGroup.hasAnchor
        anchors.left: centerAnchorModule.right
        anchors.verticalCenter: centerAnchorModule.verticalCenter
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
            active: !centerGestureGroup.hasAnchor
        }
    }

    VerticalWidgetGroup {
        id: centerBeforeColumn
        bar: centerGestureGroup.bar
        region: "center"
        entries: bar.entriesBefore(centerGestureGroup.entries, bar.centerAnchor)
        active: centerGestureGroup.hasAnchor
        collapseContents: centerGestureGroup.compactAnchorOnly
        visible: bar.vertical && centerGestureGroup.hasAnchor
        anchors.bottom: centerAnchorModule.top
        anchors.horizontalCenter: centerAnchorModule.horizontalCenter
    }

    VerticalWidgetGroup {
        id: centerAfterColumn
        bar: centerGestureGroup.bar
        region: "center"
        entries: bar.entriesAfter(centerGestureGroup.entries, bar.centerAnchor)
        active: centerGestureGroup.hasAnchor
        collapseContents: centerGestureGroup.compactAnchorOnly
        visible: bar.vertical && centerGestureGroup.hasAnchor
        anchors.top: centerAnchorModule.bottom
        anchors.horizontalCenter: centerAnchorModule.horizontalCenter
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
