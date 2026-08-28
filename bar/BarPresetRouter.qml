import QtQuick

Item {
  id: root
  property var bar: null
  anchors.fill: parent

  readonly property string preset: bar ? String(bar.spec.preset || "custom") : "custom"

  function sourceFor(name) {
    switch (name) {
    case "native": return Qt.resolvedUrl("presets/NativeBarPreset.qml")
    case "float": return Qt.resolvedUrl("presets/FloatingBarPreset.qml")
    case "float-expanded": return Qt.resolvedUrl("presets/FloatingExpandedBarPreset.qml")
    case "sections": return Qt.resolvedUrl("presets/SectionsBarPreset.qml")
    case "islands": return Qt.resolvedUrl("presets/IslandsBarPreset.qml")
    case "dock": return Qt.resolvedUrl("presets/DockBarPreset.qml")
    case "minimal": return Qt.resolvedUrl("presets/MinimalBarPreset.qml")
    case "split": return Qt.resolvedUrl("presets/SplitBarPreset.qml")
    case "notch": return Qt.resolvedUrl("presets/NotchBarPreset.qml")
    case "rail": return Qt.resolvedUrl("presets/RailBarPreset.qml")
    default: return Qt.resolvedUrl("presets/CustomBarPreset.qml")
    }
  }

  Loader {
    anchors.fill: parent
    active: root.bar !== null
    source: root.bar ? root.sourceFor(root.preset) : ""
    onLoaded: if (item && "bar" in item) item.bar = root.bar
  }
}
