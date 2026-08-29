import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".." as Bar

Item {
  id: verticalBarContent
  property var bar: null

  Column {
    anchors.fill: parent
    spacing: 0

    Bar.VerticalWidgetGroup {
      bar: verticalBarContent.bar
      region: "right"
      entries: verticalBarContent.bar.entriesWithTrayFirst(verticalBarContent.bar.layoutConfig.right)
      centerSlots: true
      width: parent.width
    }
    Rectangle {
      width: Math.max(1, parent.width - Style.space(8))
      height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      color: Util.alpha(verticalBarContent.bar.barForeground, 0.24)
    }
    Item {
      width: parent.width
      height: visible ? Math.max(Style.space(8), (parent.height
        - parent.children[0].implicitHeight
        - parent.children[2].implicitHeight
        - parent.children[3].implicitHeight
        - Style.space(18)) / 2) : 0
    }
    Bar.CenterGestureGroup {
      bar: verticalBarContent.bar
      entries: verticalBarContent.bar.layoutConfig.center
      width: parent.width
    }
    Rectangle {
      width: Math.max(1, parent.width - Style.space(8))
      height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      color: Util.alpha(verticalBarContent.bar.barForeground, 0.24)
    }
    Item {
      width: parent.width
      height: visible ? Math.max(Style.space(8), (parent.height
        - parent.children[0].implicitHeight
        - parent.children[2].implicitHeight
        - parent.children[3].implicitHeight
        - Style.space(18)) / 2) : 0
    }
    Bar.VerticalWidgetGroup {
      bar: verticalBarContent.bar
      region: "left"
      entries: verticalBarContent.bar.layoutConfig.left
      centerSlots: true
      width: parent.width
    }
  }
}
