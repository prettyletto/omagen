import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// A tooltip for panel content that must not be clipped by a Flickable or by
// the panel edge. It remains a passive PopupWindow, so it does not take focus
// or change the panel's input ownership.
PopupWindow {
    id: root

    required property Item anchorItem
    readonly property bool open: root.anchorItem ? Boolean(root.anchorItem.hot) : false
    property string text: ""
    property int delay: 400
    property int maximumWidth: Style.space(360)
    property int margin: Style.space(8)

    readonly property var borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
    readonly property var anchorWindow: root.anchorItem ? root.anchorItem.QsWindow.window : null
    property bool shown: false

    visible: root.shown && root.text !== "" && root.anchorWindow !== null
    color: "transparent"
    implicitWidth: root.maximumWidth
    implicitHeight: tooltipLabel.implicitHeight + Style.spacing.controlPaddingY * 2 + Border.top(root.borderSpec) + Border.bottom(root.borderSpec)

    onOpenChanged: {
        root.shown = false
        showTimer.stop()
        if (root.open)
            showTimer.restart()
    }

    Component.onCompleted: {
        if (root.open)
            showTimer.start()
    }

    Timer {
        id: showTimer
        interval: root.delay
        repeat: false
        onTriggered: root.shown = root.open
    }

    anchor {
        id: tooltipAnchor
        window: root.anchorWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
            var target = root.anchorItem
            var window = root.anchorWindow
            if (!target || !window)
                return

            var point = window.contentItem.mapFromItem(
                target,
                target.width / 2 - root.implicitWidth / 2,
                target.height + Style.space(6)
            )
            point.x = Math.max(root.margin, Math.min(point.x, window.width - root.implicitWidth - root.margin))
            point.y = Math.max(root.margin, Math.min(point.y, window.height - root.implicitHeight - root.margin))
            tooltipAnchor.rect.x = Math.round(point.x)
            tooltipAnchor.rect.y = Math.round(point.y)
        }
    }

    BorderSurface {
        anchors.fill: parent
        color: Color.tooltip.background
        borderSpec: root.borderSpec
        radius: Style.cornerRadius

        Text {
            id: tooltipLabel
            anchors.fill: parent
            leftPadding: Border.left(root.borderSpec) + Style.spacing.controlPaddingX
            rightPadding: Border.right(root.borderSpec) + Style.spacing.controlPaddingX
            topPadding: Border.top(root.borderSpec) + Style.spacing.controlPaddingY
            bottomPadding: Border.bottom(root.borderSpec) + Style.spacing.controlPaddingY
            text: root.text
            color: Color.tooltip.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }
}
