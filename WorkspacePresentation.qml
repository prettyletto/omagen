import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspace labels are the only intentional deviation from Omarchy's native
// bar in the Default clone. This is loaded by URL from NativeBarClone.qml so
// the native Loader does not have to receive a Component object created in a
// different QML context.
BarWidget {
  id: root

  property var workspaceSpecOverride: ({})
  readonly property var workspaceSpec: workspaceSpecOverride && typeof workspaceSpecOverride === "object"
    ? workspaceSpecOverride : ({})
  readonly property string presentationMode: String(root.workspaceSpec.mode || "native")
  readonly property var glyphs: Array.isArray(root.workspaceSpec.glyphs) ? root.workspaceSpec.glyphs : []
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property int workspaceCount: root.workspaceIds().length

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function roman(value) {
    var numerals = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
    var remaining = Number(value)
    var result = ""
    for (var i = 0; i < numerals.length; i++) {
      while (remaining >= numerals[i][0]) {
        result += numerals[i][1]
        remaining -= numerals[i][0]
      }
    }
    return result
  }

  function japaneseKanji(value) {
    var labels = ["一", "二", "三", "四", "五"]
    var index = Number(value) - 1
    return index >= 0 && index < labels.length ? labels[index] : String(value)
  }

  function workspaceLabel(id, focused, occupied) {
    if (root.presentationMode === "dots")
      return focused ? "●" : occupied ? "•" : "○"
    if (root.presentationMode === "kanji")
      return root.japaneseKanji(id)
    if (root.presentationMode === "glyphs") {
      var custom = root.glyphs[id - 1]
      if (custom !== undefined && String(custom).length > 0) return String(custom)
    }
    if (root.presentationMode === "roman") return root.roman(id)
    if (root.presentationMode === "letters") return String.fromCharCode(64 + Number(id))
    if (root.presentationMode === "native") return focused ? "\uDB85\uDCFB" : id === 10 ? "0" : String(id)
    return id === 10 ? "0" : String(id)
  }

  function focusWorkspace(id) {
    if (root.bar)
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // Size the host before its Loader/positioner lays it out. This prevents the
  // implicit-size cycle that makes a replacement workspace widget disappear.
  implicitWidth: root.vertical
    ? root.barSize
    : root.workspaceCount * Style.space(20)
      + Math.max(0, root.workspaceCount - 1) * Style.space(1)
      + root.trailingGap
  implicitHeight: root.vertical
    ? root.workspaceCount * root.barSize
      + Math.max(0, root.workspaceCount - 1) * Style.space(2)
    : root.barSize
  width: implicitWidth
  height: implicitHeight

  GridLayout {
    id: workspaceGrid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceCount
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData
        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: root.workspaceLabel(modelData, focused, occupied)
        active: focused
        opacity: occupied || focused ? 1 : 0.5
        // Preserve native fixed-size workspace slots without allowing an
        // oversized custom glyph to paint into adjacent buttons.
        clip: true
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
