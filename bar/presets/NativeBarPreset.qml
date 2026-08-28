import QtQuick
import "../.." as App

Item {
  property var bar: null
  anchors.fill: parent

  App.NativeBarClone {
    anchors.fill: parent
    omarchyPath: bar.omarchyPath
    barWidgetRegistry: bar.barWidgetRegistry
    barConfig: bar.barConfig
    shell: bar.shell
    manifest: bar.manifest
    workspaceOverrideEnabled: bar.workspaceMode !== "native"
    workspaceSpecOverride: bar.workspaceSpec
  }
}
