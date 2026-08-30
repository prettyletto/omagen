import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../../components" as Components
import "." as Local

Item {
    id: root

    property string choice: "undecided"
    property bool controlsEnabled: true
    property var shellStyle: ({})
    property var desktopStyle: ({})
    property var barStyle: ({})
    property var animationsStyle: ({})
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent

    signal choiceRequested(string choice)
    signal stylesChanged(var shellStyle, var desktopStyle, var barStyle, var animationsStyle)
    signal sectionChanged(int index)

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(9)

        Text {
            Layout.fillWidth: true
            text: "Advanced, only if you want it"
            color: root.foregroundColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "Keep the selected recipe, or open the focused editors for Window, Shell, Bar, and Motion. Your staged values stay in place when you go back."
            color: root.foregroundColor
            opacity: 0.62
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(7)

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(96)
                eyebrow: "SKIP"
                title: "Keep selected recipe"
                description: "Use the preset exactly as previewed."
                status: root.choice === "skip" ? "SELECTED" : "OPTIONAL"
                selected: root.choice === "skip"
                live: root.choice === "skip"
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.choiceRequested("skip")
            }

            Local.StepCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(96)
                eyebrow: "CUSTOMIZE"
                title: "Customize further"
                description: "Tune the composition before the next preview."
                status: root.choice === "customize" ? "SELECTED" : "OPTIONAL"
                selected: root.choice === "customize"
                live: root.choice === "customize"
                foregroundColor: root.foregroundColor
                backgroundColor: root.backgroundColor
                accentColor: root.accentColor
                onClicked: root.choiceRequested("customize")
            }
        }

        Components.AdvancedStyleEditor {
            id: editor
            Layout.fillWidth: true
            visible: root.choice === "customize"
            enabled: root.controlsEnabled
            shellStyle: root.shellStyle
            desktopStyle: root.desktopStyle
            barStyle: root.barStyle
            animationsStyle: root.animationsStyle
            foregroundColor: root.foregroundColor
            backgroundColor: root.backgroundColor
            accentColor: root.accentColor
            onStylesChanged: function(nextShell, nextDesktop, nextBar, nextAnimations) {
                root.stylesChanged(nextShell, nextDesktop, nextBar, nextAnimations)
            }
            onSectionChanged: root.sectionChanged(index)
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.choice !== "customize"
            implicitHeight: Style.space(58)
            radius: Style.space(6)
            color: Util.alpha(root.accentColor, 0.07)
            border.width: 1
            border.color: Util.alpha(root.accentColor, 0.26)

            Text {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                text: root.choice === "skip"
                    ? "Advanced controls are skipped. Continue to the optional full Demo."
                    : "Choose one option above to continue."
                color: root.foregroundColor
                opacity: 0.74
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
