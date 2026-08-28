import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Additive per-region surface behavior. Quattro still owns the actual module
// slots, placement, ordering, and input; these modes only change decoration.
Item {
    id: root

    property var spec: ({})
    readonly property var options: [
        { key: "native", title: "Native" },
        { key: "island", title: "Island" },
        { key: "quiet", title: "Quiet" },
        { key: "hidden", title: "Hidden" }
    ]
    signal specEdited(var spec)

    implicitHeight: regionsColumn.implicitHeight

    function mode(region) {
        var regions = root.spec && root.spec.regions ? root.spec.regions : ({})
        return regions[region] && regions[region].mode ? String(regions[region].mode) : "native"
    }

    function edit(region, key) {
        var next = JSON.parse(JSON.stringify(root.spec || ({})))
        next.regions = next.regions || ({})
        next.regions[region] = { mode: key }
        root.specEdited(next)
    }

    ColumnLayout {
        id: regionsColumn
        width: parent.width
        spacing: Style.space(6)

        Text {
            Layout.fillWidth: true
            text: "LEFT / CENTER / RIGHT"
            color: Color.foreground
            opacity: 0.56
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
        }

        Text {
            Layout.fillWidth: true
            text: "Surface behavior only; native Quattro widgets and input remain authoritative."
            color: Color.foreground
            opacity: 0.58
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }

        Repeater {
            model: ["left", "center", "right"]
            delegate: BarChoiceGroup {
                required property string modelData
                Layout.fillWidth: true
                title: modelData.charAt(0).toUpperCase() + modelData.slice(1) + " region"
                subtitle: "Choose the additive surface treatment"
                options: root.options
                selectedKey: root.mode(modelData)
                onChoiceSelected: root.edit(modelData, key)
            }
        }
    }
}
