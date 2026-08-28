import QtQuick

Item {
  property var bar: null
  anchors.fill: parent

  Loader {
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
        ? "VerticalBar.qml"
        : bar.floatingCompact
        ? "CompactBar.qml"
        : "ExpandedBar.qml"
    )
    onLoaded: if (item && "bar" in item) item.bar = bar
  }
}
