import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components/Contrast.js" as Contrast

Item {
    id: root

    property string selectedVariant: "source"
    property string selectedVariantLabel: "Source"
    property string selectedPreset: "Keep native"
    property string advancedChoice: "undecided"
    property bool demoActive: false
    property bool applyBusy: false
    property bool cancelBusy: false
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal applyRequested()
    signal restoreAndCloseRequested()

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        Text {
            Layout.fillWidth: true
            text: "Ready to decide"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "Review the reversible preview, then save it permanently or restore the original desktop and close Omagen."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: summary.implicitHeight + Style.space(28)
            radius: Style.cornerRadius
            color: Util.alpha(root.foregroundColor, 0.035)
            border.width: 1
            border.color: Util.alpha(root.foregroundColor, 0.16)

            ColumnLayout {
                id: summary
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(15)
                spacing: Style.space(7)

                Text { Layout.fillWidth: true; text: "PREVIEW SUMMARY"; color: root.accentColor; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.9 }
                Text { Layout.fillWidth: true; text: "Palette  ·  " + root.selectedVariantLabel + " (" + root.selectedVariant.toUpperCase() + ")"; color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                Text { Layout.fillWidth: true; text: "Look & Feel  ·  " + root.selectedPreset; color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                Text { Layout.fillWidth: true; text: "Advanced  ·  " + (root.advancedChoice === "customize" ? "Customized" : "Native recipe"); color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                Text { Layout.fillWidth: true; text: "Demo  ·  " + (root.demoActive ? "Running — stop before saving" : "Not running"); color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(44)
            text: root.applyBusy ? "Saving theme…" : "Save & Apply"
            foreground: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
            accent: root.accentColor
            background: root.accentColor
            bordered: true
            enabled: !root.applyBusy && !root.cancelBusy && !root.demoActive
            tooltipText: "Open the final save confirmation"
            onClicked: root.applyRequested()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: restoreColumn.implicitHeight + Style.space(20)
            radius: Style.space(6)
            color: Util.alpha(Color.urgent, 0.055)
            border.width: 1
            border.color: Util.alpha(Color.urgent, 0.24)

            ColumnLayout {
                id: restoreColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                Text {
                    Layout.fillWidth: true
                    text: "Not keeping this preview?"
                    color: root.foregroundColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "Restore the original theme, background, bar, and owned Demo resources, then close the wizard."
                    color: root.foregroundColor
                    opacity: 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                Button {
                    Layout.fillWidth: true
                    text: root.cancelBusy ? "Restoring original desktop…" : "Restore & close"
                    foreground: root.foregroundColor
                    accent: Color.urgent
                    background: Util.alpha(Color.urgent, 0.1)
                    bordered: true
                    enabled: !root.applyBusy && !root.cancelBusy
                    onClicked: root.restoreAndCloseRequested()
                }
            }
        }
    }
}
