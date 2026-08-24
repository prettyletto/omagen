import QtQuick
import QtQuick.Layouts
import qs.Commons

// Primitive BarSpec controls shared by the Bar Lab. Presets compose these
// values; this editor only changes the declarative surface/geometry document
// and never writes the user-owned widget layout.
Item {
    id: root

    property var spec: ({})
    signal specEdited(var spec)

    implicitHeight: body.implicitHeight

    function copySpec() {
        return JSON.parse(JSON.stringify(root.spec || ({})))
    }

    function edit(path, value) {
        var next = root.copySpec()
        var target = next
        for (var index = 0; index < path.length - 1; index++)
            target = target[path[index]] || (target[path[index]] = ({}))
        target[path[path.length - 1]] = Number(value)
        root.specEdited(next)
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(6)

        Text { Layout.fillWidth: true; text: "SURFACE PRIMITIVES"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }

        ShellRangeField {
            Layout.fillWidth: true
            label: "Background opacity"
            description: "Transparent gaps remain click-through; only the surface pixels are themed."
            value: root.spec.surface && root.spec.surface.opacity !== undefined ? String(root.spec.surface.opacity) : "1"
            fallback: 1; minimum: 0; maximum: 1; step: 0.01; decimals: 2
            modified: Number(value) !== fallback
            onValueEdited: root.edit(["surface", "opacity"], value)
            onResetRequested: root.edit(["surface", "opacity"], fallback)
        }

        ShellRangeField {
            Layout.fillWidth: true
            label: "Backdrop blur"
            description: "A compositor hint for translucent Omagen surfaces; native Quattro remains authoritative."
            value: root.spec.surface && root.spec.surface.blur !== undefined ? String(root.spec.surface.blur) : "0"
            fallback: 0; minimum: 0; maximum: 32; step: 1; decimals: 0; suffix: " px"; integer: true
            modified: Number(value) !== fallback
            onValueEdited: root.edit(["surface", "blur"], value)
            onResetRequested: root.edit(["surface", "blur"], fallback)
        }

        Text { Layout.fillWidth: true; text: "GEOMETRY"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ShellRangeField { Layout.fillWidth: true; label: "Radius"; value: root.spec.geometry && root.spec.geometry.radius !== undefined ? String(root.spec.geometry.radius) : "0"; fallback: 0; maximum: 40; step: 1; decimals: 0; suffix: " px"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.edit(["geometry", "radius"], value); onResetRequested: root.edit(["geometry", "radius"], fallback) }
            ShellRangeField { Layout.fillWidth: true; label: "Edge offset"; value: root.spec.geometry && root.spec.geometry.edge_offset !== undefined ? String(root.spec.geometry.edge_offset) : "0"; fallback: 0; maximum: 48; step: 1; decimals: 0; suffix: " px"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.edit(["geometry", "edge_offset"], value); onResetRequested: root.edit(["geometry", "edge_offset"], fallback) }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            ShellRangeField { Layout.fillWidth: true; label: "Section gap"; value: root.spec.geometry && root.spec.geometry.section_gap !== undefined ? String(root.spec.geometry.section_gap) : "8"; fallback: 8; maximum: 48; step: 1; decimals: 0; suffix: " px"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.edit(["geometry", "section_gap"], value); onResetRequested: root.edit(["geometry", "section_gap"], fallback) }
            ShellRangeField { Layout.fillWidth: true; label: "Thickness"; value: root.spec.geometry && root.spec.geometry.thickness !== undefined ? String(root.spec.geometry.thickness) : "0"; fallback: 0; maximum: 64; step: 1; decimals: 0; suffix: " px"; integer: true; modified: Number(value) !== fallback; onValueEdited: root.edit(["geometry", "thickness"], value); onResetRequested: root.edit(["geometry", "thickness"], fallback) }
        }
    }
}
