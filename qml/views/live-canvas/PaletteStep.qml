import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast
import "../../components" as Components

Item {
    id: root

    property var variants: []
    property var palettes: ({})
    property string selectedVariant: "source"
    property bool paletteSelected: false
    property bool previewBusy: false
    property bool generationBusy: false
    property bool controlsEnabled: true
    property bool customColoursOpen: false
    property int activeRoleIndex: 0
    property var stagedColors: ({})
    property bool colorPreviewLive: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal variantRequested(string variant)
    signal colorOverridesCommitted(var overrides)

    readonly property var editableRoles: [
        { key: "accent", label: "Accent", description: "Focus, controls, and the main visual signal." },
        { key: "background", label: "Background", description: "The base desktop and terminal surface." },
        { key: "foreground", label: "Foreground", description: "Readable text and icon colour." },
        { key: "selection", label: "Selection", description: "Highlights used by editors and interactive surfaces." }
    ]
    readonly property var activeRole: root.editableRoles[root.activeRoleIndex]
        || root.editableRoles[0]

    implicitHeight: content.implicitHeight

    function paletteFor(variant) {
        return root.palettes[variant] || ({})
    }

    function fallbackColor(roleKey) {
        if (roleKey === "accent")
            return String(root.accentColor).toUpperCase()
        if (roleKey === "background")
            return String(root.backgroundColor).toUpperCase()
        if (roleKey === "foreground")
            return String(root.foregroundColor).toUpperCase()
        return String(root.accentColor).toUpperCase()
    }

    function paletteColor(palette, key, fallback) {
        return String(palette && palette[key] ? palette[key] : fallback).toUpperCase()
    }

    function paletteSurface(palette) {
        const fallback = root.paletteColor(palette, "background", root.backgroundColor)
        const surfaceKey = String(palette.mode || "dark") === "light"
            ? "darker_background" : "lighter_background"
        return root.paletteColor(palette, surfaceKey, fallback)
    }

    function presetColor(roleKey) {
        return root.paletteColor(root.paletteFor(root.selectedVariant), roleKey,
            root.fallbackColor(roleKey))
    }

    function editorColor(roleKey) {
        const staged = root.stagedColors || ({})
        return String(staged[roleKey] || root.presetColor(roleKey)).toUpperCase()
    }

    function hasSelectedPalette() {
        return Object.keys(root.paletteFor(root.selectedVariant)).length > 0
    }

    function copyColors(value) {
        const next = {}
        for (const key in (value || {}))
            next[key] = String(value[key]).toUpperCase()
        return next
    }

    function commitRole(roleKey, hex) {
        const next = root.copyColors(root.stagedColors)
        const normalized = String(hex || "").toUpperCase()
        if (normalized === root.presetColor(roleKey))
            delete next[roleKey]
        else
            next[roleKey] = normalized
        root.colorOverridesCommitted(next)
    }

    function resetColours() {
        root.colorOverridesCommitted({})
    }

    function openCustomColours() {
        if (!root.hasSelectedPalette())
            return
        root.activeRoleIndex = 0
        root.customColoursOpen = true
    }

    function paletteDescription(palette) {
        const mode = String(palette.mode || "generated")
        return mode.charAt(0).toUpperCase() + mode.slice(1)
            + " palette · "
            + root.paletteColor(palette, "background", root.backgroundColor)
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(12)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                    Layout.fillWidth: true
                    text: "Choose a colour direction"
                    color: root.foregroundColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.variants.length > 0
                        ? "Six considered palettes, each previewed with its own colours."
                        : "Generate palettes to compare colour directions."
                    color: root.foregroundColor
                    opacity: 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }
            }

            Button {
                Layout.preferredWidth: Style.space(142)
                Layout.preferredHeight: Style.space(38)
                text: root.customColoursOpen ? "Close editor" : "Custom colours"
                fontSize: Style.font.caption
                foreground: root.customColoursOpen
                    ? Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                    : root.foregroundColor
                accent: root.accentColor
                background: root.customColoursOpen
                    ? root.accentColor : Util.alpha(root.foregroundColor, 0.045)
                bordered: true
                enabled: root.controlsEnabled && root.hasSelectedPalette()
                tooltipText: "Tune semantic colours for the selected palette"
                onClicked: root.customColoursOpen
                    ? root.customColoursOpen = false : root.openCustomColours()
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Pick a direction to preview it on the desktop immediately. Custom colours stay staged to that direction."
            color: root.foregroundColor
            opacity: 0.58
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }

        GridLayout {
            id: paletteGrid
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
            visible: !root.customColoursOpen
            columns: width >= Style.space(500) ? 2 : 1
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            Repeater {
                model: root.variants

                delegate: Item {
                    id: cardItem
                    required property var modelData

                    readonly property bool chosen: root.selectedVariant === modelData.variant
                    readonly property var palette: root.paletteFor(modelData.variant)
                    readonly property string baseColor: root.paletteColor(palette, "background", root.backgroundColor)
                    readonly property string surfaceColor: root.paletteSurface(palette)
                    readonly property string accentColor: root.paletteColor(palette, "accent", root.accentColor)
                    readonly property string textColor: root.paletteColor(palette, "foreground", root.foregroundColor)
                    readonly property string selectionColor: root.paletteColor(palette, "selection", accentColor)

                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(156)
                    implicitHeight: Style.space(156)

                    Button {
                        id: cardButton
                        anchors.fill: parent
                        text: ""
                        foreground: cardItem.textColor
                        accent: cardItem.accentColor
                        background: cardItem.chosen
                            ? Util.alpha(cardItem.accentColor, 0.16)
                            : Util.alpha(cardItem.surfaceColor, 0.92)
                        bordered: true
                        enabled: !root.generationBusy && !root.previewBusy
                        tooltipText: root.paletteDescription(cardItem.palette)
                        onClicked: root.variantRequested(cardItem.modelData.variant)

                        Item {
                            anchors.fill: parent
                            anchors.margins: Style.space(12)

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.right: palettePreview.left
                                anchors.rightMargin: Style.space(10)
                                anchors.bottom: parent.bottom
                                spacing: Style.space(5)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(6)

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(cardItem.modelData.variant || "palette").toUpperCase()
                                        color: cardItem.chosen
                                            ? cardItem.accentColor : root.accentColor
                                        opacity: cardItem.chosen ? 1 : 0.9
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 0.9
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: cardItem.chosen
                                            ? (root.previewBusy ? "UPDATING" : "SELECTED") : "PREVIEW"
                                        color: cardItem.textColor
                                        opacity: 0.62
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: cardItem.modelData.label || cardItem.modelData.variant
                                    color: cardItem.textColor
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.subtitle
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.paletteDescription(cardItem.palette)
                                    color: cardItem.textColor
                                    opacity: 0.65
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                }

                                Item { Layout.fillHeight: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(5)

                                    Repeater {
                                        model: [
                                            { label: "BASE", color: cardItem.baseColor },
                                            { label: "ACCENT", color: cardItem.accentColor },
                                            { label: "SURFACE", color: cardItem.surfaceColor },
                                            { label: "TEXT", color: cardItem.textColor }
                                        ]

                                        delegate: Column {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: Style.space(2)

                                            Text {
                                                text: modelData.label
                                                color: cardItem.textColor
                                                opacity: 0.52
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                font.bold: true
                                            }

                                            Rectangle {
                                                width: Style.space(27)
                                                height: Style.space(9)
                                                radius: Style.space(2)
                                                color: modelData.color
                                                border.width: 1
                                                border.color: Util.alpha(cardItem.textColor, 0.35)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: palettePreview
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.min(Style.space(142), parent.width * 0.40)
                                radius: Style.space(7)
                                color: cardItem.baseColor
                                border.width: 1
                                border.color: cardItem.accentColor
                                clip: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: Style.space(25)
                                    color: cardItem.accentColor

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Style.space(8)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "OMAGEN"
                                        color: Contrast.textFor(cardItem.accentColor, cardItem.baseColor, cardItem.textColor)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 0.7
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.topMargin: Style.space(25)
                                    anchors.bottom: parent.bottom
                                    color: cardItem.surfaceColor

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Style.space(9)
                                        anchors.top: parent.top
                                        anchors.topMargin: Style.space(10)
                                        text: "Aa"
                                        color: cardItem.textColor
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.subtitle
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Style.space(9)
                                        anchors.top: parent.top
                                        anchors.topMargin: Style.space(34)
                                        text: "Preview text"
                                        color: cardItem.textColor
                                        opacity: 0.7
                                        font.family: Style.font.family
                                        font.pixelSize: Math.max(1, Style.font.caption - 1)
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: Style.space(8)
                                        height: Style.space(10)
                                        radius: Style.space(2)
                                        color: cardItem.selectionColor
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: cardItem.chosen && root.paletteSelected
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Style.space(12)
                            anchors.bottomMargin: Style.space(7)
                            width: Style.space(6)
                            height: Style.space(6)
                            radius: width / 2
                            color: cardItem.accentColor
                        }
                    }
                }
            }
        }

        Rectangle {
            id: customColoursPanel
            Layout.fillWidth: true
            Layout.preferredHeight: root.customColoursOpen ? implicitHeight : 0
            implicitHeight: root.customColoursOpen
                ? editorBody.implicitHeight + Style.space(24) : 0
            visible: root.customColoursOpen
            color: Util.alpha(root.backgroundColor, 0.72)
            radius: Style.space(8)
            border.width: 1
            border.color: Util.alpha(root.accentColor, 0.55)

            ColumnLayout {
                id: editorBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(9)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(10)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(2)

                        Text {
                            Layout.fillWidth: true
                            text: "CUSTOM COLOURS"
                            color: root.accentColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.0
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Editing " + (root.selectedVariant || "selected")
                                + " · changes preview immediately"
                            color: root.foregroundColor
                            opacity: 0.7
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    Button {
                        Layout.preferredWidth: Style.space(92)
                        Layout.preferredHeight: Style.space(34)
                        text: "Reset all"
                        fontSize: Style.font.caption
                        foreground: root.foregroundColor
                        accent: root.accentColor
                        background: Util.alpha(root.foregroundColor, 0.045)
                        bordered: true
                        enabled: root.controlsEnabled
                            && Object.keys(root.stagedColors || ({})).length > 0
                        onClicked: root.resetColours()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Choose a role, then use the colour field or enter its exact hex value."
                    color: root.foregroundColor
                    opacity: 0.56
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= Style.space(500) ? 2 : 1
                    columnSpacing: Style.space(7)
                    rowSpacing: Style.space(7)

                    Repeater {
                        model: root.editableRoles

                        delegate: Button {
                            required property var modelData
                            required property int index
                            readonly property bool selected: root.activeRoleIndex === index
                            readonly property string roleColor: root.editorColor(modelData.key)

                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(62)
                            text: ""
                            foreground: root.foregroundColor
                            accent: roleColor
                            background: selected
                                ? Util.alpha(roleColor, 0.18)
                                : Util.alpha(root.foregroundColor, 0.035)
                            bordered: true
                            enabled: root.controlsEnabled
                            tooltipText: modelData.description
                            onClicked: root.activeRoleIndex = index

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(30)
                                height: width
                                radius: Style.space(6)
                                color: roleColor
                                border.width: 1
                                border.color: Util.alpha(root.foregroundColor, 0.36)
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(50)
                                anchors.right: parent.right
                                anchors.rightMargin: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(2)

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: root.foregroundColor
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: roleColor
                                        color: roleColor
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.description
                                    color: root.foregroundColor
                                    opacity: 0.55
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Components.ColorRoleEditor {
                    Layout.fillWidth: true
                    roleKey: root.activeRole.key
                    roleLabel: root.activeRole.label
                    roleDescription: root.activeRole.description
                    value: root.editorColor(root.activeRole.key)
                    presetValue: root.presetColor(root.activeRole.key)
                    live: root.colorPreviewLive && !root.previewBusy
                    enabled: root.controlsEnabled
                    onValueEdited: root.commitRole(roleKey, hex)
                    onResetRequested: root.commitRole(roleKey, presetValue)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(7)

                    Text {
                        Layout.fillWidth: true
                        text: Object.keys(root.stagedColors || ({})).length > 0
                            ? "Staged colours are previewed live."
                            : "Using preset colours."
                        color: root.foregroundColor
                        opacity: 0.56
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Button {
                        Layout.preferredWidth: Style.space(120)
                        Layout.preferredHeight: Style.space(36)
                        text: "Apply & close"
                        fontSize: Style.font.caption
                        foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
                        accent: root.accentColor
                        background: root.accentColor
                        bordered: false
                        enabled: root.controlsEnabled
                        onClicked: root.customColoursOpen = false
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.variants.length === 0
            text: root.generationBusy
                ? "Preparing palette directions…" : "No palette directions are available yet."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
    }
}
