import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components

PanelWindow {
    id: root

    property bool active: false
    property bool busy: false
    property string sourceImage: ""
    property var shellStyle: ({ surface: "flat", detail: "native" })
    property var desktopStyle: ({ borderStyle: "solid", shape: "native", spacing: "native", depth: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous" })
    property int activeTab: 0

    signal shellStyleSelected(var style)
    signal desktopStyleSelected(var style)
    signal barStyleSelected(var style)
    signal continueRequested()
    signal backRequested()
    signal hideRequested()

    readonly property var tabs: [
        { title: "Window", eyebrow: "WINDOW CHROME" },
        { title: "Shell", eyebrow: "QUATTRO SURFACES" },
        { title: "Bar", eyebrow: "STATUS BAR" }
    ]
    readonly property var borderOptions: [
        { key: "solid", title: "Solid (default)" }, { key: "split_top", title: "Split Top" },
        { key: "split_bottom", title: "Split Bottom" }, { key: "blend", title: "Accent Blend" },
        { key: "neon", title: "Neon Blend" }
    ]
    readonly property var shapeOptions: [
        { key: "native", title: "Default" }, { key: "soft", title: "Soft" }, { key: "rounded", title: "Rounded" }
    ]
    readonly property var spacingOptions: [
        { key: "native", title: "Default" }, { key: "compact", title: "Compact" }, { key: "airy", title: "Airy" }
    ]
    readonly property var depthOptions: [
        { key: "native", title: "Default" }, { key: "flat", title: "Flat" }, { key: "shadow", title: "Shadow" }
    ]
    readonly property var surfaceOptions: [
        { key: "flat", title: "Flat (default)" }, { key: "layered", title: "Layered" },
        { key: "contrast", title: "Contrast" }, { key: "accent", title: "Accent" }
    ]
    readonly property var detailOptions: [
        { key: "native", title: "Default" }, { key: "framed", title: "Framed" },
        { key: "edge", title: "Edge" }, { key: "focus", title: "Focus" }
    ]
    readonly property var barSurfaceOptions: [
        { key: "native", title: "Default" }, { key: "dark", title: "Dark" },
        { key: "light", title: "Light" }, { key: "accent", title: "Accent" }
    ]
    readonly property var barDensityOptions: [
        { key: "native", title: "Default" }, { key: "compact", title: "Compact" },
        { key: "comfortable", title: "Comfortable" }
    ]
    readonly property var attentionOptions: [
        { key: "semantic", title: "Semantic (default)" }, { key: "accent", title: "Accent" }
    ]
    readonly property var barFormOptions: [
        { key: "continuous", title: "Continuous (default)" }, { key: "docked", title: "Docked" }
    ]

    // Generation begins after this screen, so the actual Source palette is
    // not available yet.  This live card deliberately uses the active Quattro
    // palette while preserving the exact Source-card composition.
    readonly property var previewPalette: ({
        background: Color.background,
        dark_background: Qt.darker(Color.background, 1.14),
        darker_background: Qt.darker(Color.background, 1.32),
        lighter_background: Qt.lighter(Color.background, 1.24),
        foreground: Color.foreground,
        dark_foreground: Color.muted,
        accent: Color.accent,
        selection: Util.alpha(Color.accent, 0.28),
        muted: Color.muted,
        red: Color.urgent,
        yellow: "#c9a55b",
        green: "#75a884",
        cyan: "#68a7a4",
        blue: "#6c91bd",
        magenta: "#a17ca8"
    })

    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omagen-preview-config"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    function chooseDesktop(group, key) {
        var next = {
            borderStyle: desktopStyle.borderStyle,
            shape: desktopStyle.shape,
            spacing: desktopStyle.spacing,
            depth: desktopStyle.depth
        }
        next[group === "border" ? "borderStyle" : group] = key
        desktopStyle = next
        desktopStyleSelected(next)
    }

    function chooseShell(group, key) {
        var next = { surface: shellStyle.surface, detail: shellStyle.detail }
        next[group] = key
        shellStyle = next
        shellStyleSelected(next)
    }

    function chooseBar(group, key) {
        var next = { surface: barStyle.surface, density: barStyle.density, attention: barStyle.attention, form: barStyle.form }
        next[group] = key
        barStyle = next
        barStyleSelected(next)
    }

    onActiveChanged: if (active) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

    Rectangle {
        anchors.fill: parent
        color: Color.background

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Util.alpha(Color.accent, 0.035) }
                GradientStop { position: 0.46; color: "transparent" }
                GradientStop { position: 1; color: Util.alpha(Color.background, 0.2) }
            }
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.backRequested()
            onMoveRequested: function(dx, dy) {
                if (dx !== 0)
                    root.activeTab = (root.activeTab + (dx > 0 ? 1 : -1) + root.tabs.length) % root.tabs.length
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(28)
                spacing: Style.space(16)

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(62)

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(3)

                        Text {
                            text: "QUATTRO THEME STUDIO  /  DESKTOP COMPOSITION  /  STEP 1 OF 2"
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.25
                        }
                        Text {
                            text: "Shape the desktop"
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }
                        Text {
                            text: "Tune the window, shell, and bar. The next step generates palette directions from these choices."
                            color: Color.foreground
                            opacity: 0.56
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                    }

                    Column {
                        anchors.right: closeButton.left
                        anchors.rightMargin: Style.space(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            anchors.right: parent.right
                            text: "STEP 1  /  CONFIGURATION"
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }
                        Text {
                            anchors.right: parent.right
                            text: "Choices apply to the next step"
                            color: Color.foreground
                            opacity: 0.42
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Button {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(36)
                        height: Style.space(36)
                        text: "×"
                        fontSize: Style.font.title
                        foreground: Color.foreground
                        tooltipText: "Back"
                        onClicked: root.backRequested()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Style.space(22)

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: Style.space(390)
                        Layout.preferredWidth: Style.space(500)

                        Components.ThemePreviewCard {
                            anchors.fill: parent
                            anchors.topMargin: Style.space(8)
                            anchors.bottomMargin: Style.space(8)
                            variant: "source"
                            label: "Source"
                            palette: root.previewPalette
                            sourceImage: root.sourceImage
                            configurationPreview: true
                            activeSection: root.activeTab
                            desktopStyle: root.desktopStyle
                            shellStyle: root.shellStyle
                            barStyle: root.barStyle
                            previewed: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: Style.space(450)
                        Layout.preferredWidth: Style.space(570)
                        radius: Style.cornerRadius
                        color: Util.alpha(Color.foreground, 0.025)
                        border.width: 1
                        border.color: Util.alpha(Color.foreground, 0.16)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Style.space(18)
                            spacing: Style.space(13)

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(42)
                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: root.tabs[root.activeTab].eyebrow
                                        color: Color.accent
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 1.1
                                    }
                                    Text {
                                        text: root.tabs[root.activeTab].title + " styling"
                                        color: Color.foreground
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.heading
                                        font.bold: true
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    text: "← →  switch section"
                                    color: Color.foreground
                                    opacity: 0.38
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.space(7)
                                Repeater {
                                    model: root.tabs
                                    delegate: Button {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        accent: root.activeTab === index
                                        background: root.activeTab === index ? Color.foreground : "transparent"
                                        foreground: root.activeTab === index ? Color.background : Color.foreground
                                        bordered: true
                                        onClicked: root.activeTab = index
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Util.alpha(Color.foreground, 0.13) }

                            StackLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                currentIndex: root.activeTab

                                Item {
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Style.space(10)

                                        Text { text: "ACTIVE BORDER"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 5
                                            columnSpacing: Style.space(7)
                                            Repeater {
                                                model: root.borderOptions
                                                delegate: Components.DesktopOptionCard {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    title: modelData.title
                                                    selected: root.desktopStyle.borderStyle === modelData.key
                                                    onClicked: root.chooseDesktop("border", modelData.key)
                                                }
                                            }
                                        }
                                        Text { text: "CORNER SHAPE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(7)
                                            Repeater { model: root.shapeOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.desktopStyle.shape === modelData.key; onClicked: root.chooseDesktop("shape", modelData.key) } }
                                        }
                                        Text { text: "PANE SPACING"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(7)
                                            Repeater { model: root.spacingOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.desktopStyle.spacing === modelData.key; onClicked: root.chooseDesktop("spacing", modelData.key) } }
                                        }
                                        Text { text: "DEPTH"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(7)
                                            Repeater { model: root.depthOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.desktopStyle.depth === modelData.key; onClicked: root.chooseDesktop("depth", modelData.key) } }
                                        }
                                    }
                                }

                                Item {
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Style.space(12)
                                        Text { text: "SURFACE COMPOSITION"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        Text { Layout.fillWidth: true; text: "Redistribute the palette across Quickshell popups, menus, and interactive controls."; wrapMode: Text.WordWrap; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                                        GridLayout {
                                            Layout.fillWidth: true; columns: 2; rowSpacing: Style.space(8); columnSpacing: Style.space(8)
                                            Repeater { model: root.surfaceOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.shellStyle.surface === modelData.key; onClicked: root.chooseShell("surface", modelData.key) } }
                                        }
                                        Text { text: "DETAIL LANGUAGE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        Text { Layout.fillWidth: true; text: "Choose how focus and selection edges are expressed without changing shell layout."; wrapMode: Text.WordWrap; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                                        GridLayout {
                                            Layout.fillWidth: true; columns: 2; rowSpacing: Style.space(8); columnSpacing: Style.space(8)
                                            Repeater { model: root.detailOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.shellStyle.detail === modelData.key; onClicked: root.chooseShell("detail", modelData.key) } }
                                        }
                                        Item { Layout.fillHeight: true }
                                    }
                                }

                                Item {
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Style.space(12)
                                        Text { text: "BAR FORM"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        Text { Layout.fillWidth: true; text: "Keep Quattro's left, center, and right widgets in place; choose one continuous surface or three floating section surfaces."; wrapMode: Text.WordWrap; color: Color.foreground; opacity: 0.52; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(8)
                                            Repeater { model: root.barFormOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.barStyle.form === modelData.key; onClicked: root.chooseBar("form", modelData.key) } }
                                        }
                                        Text { text: "BAR SURFACE"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        GridLayout {
                                            Layout.fillWidth: true; columns: 2; rowSpacing: Style.space(8); columnSpacing: Style.space(8)
                                            Repeater { model: root.barSurfaceOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.barStyle.surface === modelData.key; onClicked: root.chooseBar("surface", modelData.key) } }
                                        }
                                        Text { text: "DENSITY"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(8)
                                            Repeater { model: root.barDensityOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.barStyle.density === modelData.key; onClicked: root.chooseBar("density", modelData.key) } }
                                        }
                                        Text { text: "ATTENTION COLOR"; color: Color.foreground; opacity: 0.5; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Style.space(8)
                                            Repeater { model: root.attentionOptions; delegate: Components.DesktopOptionCard { required property var modelData; Layout.fillWidth: true; title: modelData.title; selected: root.barStyle.attention === modelData.key; onClicked: root.chooseBar("attention", modelData.key) } }
                                        }
                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(54)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Every choice updates the Source card immediately."
                        color: Color.foreground
                        opacity: 0.42
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)
                        Button { text: "Back"; foreground: Color.foreground; bordered: true; onClicked: root.backRequested() }
                        Button {
                            text: root.busy ? "Starting…" : "Continue to directions"
                            foreground: Color.background
                            accent: Color.foreground
                            background: Color.foreground
                            bordered: true
                            enabled: !root.busy
                            onClicked: root.continueRequested()
                        }
                    }
                }
            }
        }
    }
}
