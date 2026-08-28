import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  property var bar: null

  Column {
    anchors.fill: parent
    spacing: 0

    Bar.VerticalWidgetGroup {
      bar: bar
      region: "right"
      entries: bar.floatingCompact ? bar.entriesWithoutTray(bar.layoutConfig.right) : bar.entriesWithTrayFirst(bar.layoutConfig.right)
      centerSlots: true
      width: parent.width
    }
    Rectangle {
      visible: !bar.floatingCompact
      width: Math.max(1, parent.width - Style.space(8))
      height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      color: Util.alpha(bar.barForeground, 0.24)
    }
    Item {
      visible: !bar.floatingCompact
      width: parent.width
      height: visible ? Math.max(Style.space(8), (parent.height
        - parent.children[0].implicitHeight
        - parent.children[2].implicitHeight
        - parent.children[3].implicitHeight
        - Style.space(18)) / 2) : 0
    }
    Bar.CenterGestureGroup {
      bar: bar
      entries: bar.layoutConfig.center
      width: parent.width
    }
    Rectangle {
      visible: !bar.floatingCompact
      width: Math.max(1, parent.width - Style.space(8))
      height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      color: Util.alpha(bar.barForeground, 0.24)
    }
    Item {
      visible: !bar.floatingCompact
      width: parent.width
      height: visible ? Math.max(Style.space(8), (parent.height
        - parent.children[0].implicitHeight
        - parent.children[2].implicitHeight
        - parent.children[3].implicitHeight
        - Style.space(18)) / 2) : 0
    }
    Bar.VerticalWidgetGroup {
      bar: bar
      region: "left"
      entries: bar.layoutConfig.left
      centerSlots: true
      width: parent.width
    }
  }
}
