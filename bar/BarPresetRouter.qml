import QtQuick

Item {
  id: root
  property var bar: null
  anchors.fill: parent
  implicitWidth: presetLoader.item ? presetLoader.item.implicitWidth : 0
  implicitHeight: presetLoader.item ? presetLoader.item.implicitHeight : 0

  readonly property string preset: bar ? String(bar.spec.preset || "custom") : "custom"

  function sourceFor(name) {
    switch (name) {
    case "native": return Qt.resolvedUrl("presets/NativeBarPreset.qml")
    case "float": return Qt.resolvedUrl("presets/FloatingBarPreset.qml")
    case "float-expanded": return Qt.resolvedUrl("presets/FloatingExpandedBarPreset.qml")
    case "islands": return Qt.resolvedUrl("presets/IslandsBarPreset.qml")
    case "dock": return Qt.resolvedUrl("presets/DockBarPreset.qml")
    case "minimal": return Qt.resolvedUrl("presets/MinimalBarPreset.qml")
    case "orbit": return Qt.resolvedUrl("presets/OrbitBarPreset.qml")
    case "ribbon": return Qt.resolvedUrl("presets/SegmentedRibbonBarPreset.qml")
    case "cathedral": return Qt.resolvedUrl("presets/CathedralBarPreset.qml")
    case "pulse": return Qt.resolvedUrl("presets/PulseBarPreset.qml")
    case "zen": return Qt.resolvedUrl("presets/ZenBarPreset.qml")
    default: return Qt.resolvedUrl("presets/CustomBarPreset.qml")
    }
  }

  Loader {
    id: presetLoader
    anchors.fill: parent
    active: root.bar !== null
    source: root.bar ? root.sourceFor(root.preset) : ""
    onLoaded: if (item && "bar" in item) item.bar = root.bar
  }
}
