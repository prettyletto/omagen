import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast
import "." as Local

Item {
    id: root

    property var catalog: []
    property var lookFeel: ({ preset: "omarchy-native", customized: ({}) })
    property var recipe: null
    property bool decided: false
    property bool catalogLoading: false
    property string catalogError: ""
    property bool busy: false
    property bool previewBusy: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal presetRequested(string preset)
    signal skipRequested()
    signal catalogRetryRequested()

    implicitHeight: content.implicitHeight

    readonly property string selectedPreset: String(root.lookFeel.preset || "omarchy-native")

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(9)

        Text {
            Layout.fillWidth: true
            text: "Choose a Look & Feel"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "Presets preview as soon as you click. Keep Omarchy native or choose a complete recipe before moving to optional advanced controls."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        Local.StepCard {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(86)
            eyebrow: "NATIVE"
            title: "Keep native / Skip"
            description: "Use the selected palette with Omarchy's native window, shell, bar, motion, and terminal behavior."
            status: root.decided && root.selectedPreset === "omarchy-native" ? "SELECTED" : "OPTIONAL"
            selected: root.decided && root.selectedPreset === "omarchy-native"
            live: root.decided && root.selectedPreset === "omarchy-native" && !root.busy && !root.previewBusy
            previewing: root.decided && root.selectedPreset === "omarchy-native" && (root.busy || root.previewBusy)
            foregroundColor: root.foregroundColor
            backgroundColor: root.backgroundColor
            accentColor: root.accentColor
            onClicked: root.skipRequested()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= Style.space(470) ? 2 : 1
            columnSpacing: Style.space(7)
            rowSpacing: Style.space(7)

            Repeater {
                model: root.catalog

                delegate: Local.StepCard {
                    required property var modelData
                    readonly property bool chosen: root.selectedPreset === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(112)
                    eyebrow: "PRESET"
                    title: modelData.name || modelData.id
                    description: root.conciseDescription(modelData.description)
                    status: chosen ? (root.busy || root.previewBusy ? "UPDATING" : "SELECTED") : "PREVIEW"
                    selected: chosen
                    live: chosen && root.decided && !root.busy && !root.previewBusy
                    previewing: chosen && (root.busy || root.previewBusy)
                    // Look & Feel clicks remain available during preview so
                    // the controller can converge on the newest intent.
                    enabled: true
                    foregroundColor: root.foregroundColor
                    backgroundColor: root.backgroundColor
                    accentColor: root.accentColor
                    onClicked: root.presetRequested(modelData.id)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.catalogLoading || root.catalogError !== ""
            implicitHeight: catalogMessage.implicitHeight + Style.space(18)
            radius: Style.space(6)
            color: Util.alpha(root.foregroundColor, 0.035)
            border.width: 1
            border.color: Util.alpha(root.foregroundColor, 0.16)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                Text {
                    id: catalogMessage
                    Layout.fillWidth: true
                    text: root.catalogError !== ""
                        ? "Preset catalog unavailable: " + root.catalogError
                        : "Loading Look & Feel presets…"
                    color: root.catalogError !== "" ? Color.urgent : root.foregroundColor
                    opacity: root.catalogError !== "" ? 1 : 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }

                Button {
                    visible: root.catalogError !== ""
                    Layout.preferredWidth: retryText.implicitWidth + Style.space(24)
                    Layout.preferredHeight: Style.space(30)
                    text: "Retry"
                    foreground: root.foregroundColor
                    accent: root.accentColor
                    background: Util.alpha(root.foregroundColor, 0.05)
                    bordered: true
                    onClicked: root.catalogRetryRequested()

                    Text { id: retryText; visible: false; text: parent.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.recipe !== null
            text: root.recipeSummary()
            color: root.foregroundColor
            opacity: 0.68
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }
    }

    function conciseDescription(value) {
        var text = String(value || "Complete Omarchy composition recipe.")
        return text.length > 106 ? text.slice(0, 103) + "…" : text
    }

    function recipeSummary() {
        var value = root.recipe || ({})
        var window = value.window || ({})
        var bar = value.bar || ({})
        var motion = value.animations || ({})
        return "Preview recipe · " + String(window.shape || "native") + " windows · "
            + String((bar.spec || {}).preset || bar.form || "native") + " bar · "
            + String(motion.preset || "native") + " motion"
    }
}
