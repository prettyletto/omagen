import QtQuick

Item {
  property var bar: null
  anchors.fill: parent
  implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
  implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

  Loader {
    id: contentLoader
    anchors.fill: parent
    active: bar !== null
    source: Qt.resolvedUrl(
      bar === null
        ? ""
        : bar.topology === "dock"
        ? "DockBarPreset.qml"
        : bar.topology === "islands"
        ? "IslandsBarPreset.qml"
        : bar.topology === "minimal"
        ? "MinimalBarPreset.qml"
        : bar.vertical
        ? (bar.floatingCompact ? "FloatingVerticalBar.qml" : "VerticalBar.qml")
        : bar.floatingCompact
        ? "CompactBar.qml"
        : "ExpandedBar.qml"
    )
    onLoaded: if (item && "bar" in item) item.bar = bar
  }
}
