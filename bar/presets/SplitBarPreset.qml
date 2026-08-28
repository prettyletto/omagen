import QtQuick

Item {
  property var bar: null
  anchors.fill: parent

  Loader {
    anchors.fill: parent
    active: bar !== null
    source: bar ? Qt.resolvedUrl(bar.vertical ? "VerticalBar.qml" : "ExpandedBar.qml") : ""
    onLoaded: if (item && "bar" in item) item.bar = bar
  }
}
