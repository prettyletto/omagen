import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
    id: root
    property bool active: false
    property bool busy: false
    property var themes: []
    property string errorMessage: ""
    signal themeSelected(string themeId)
    signal closeRequested()

    visible: active
    color: "transparent"
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.closeRequested()
    }
    WlrLayershell.namespace: "omagen-theme-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(860), parent.width - Style.space(48))
        height: Math.min(Style.space(760), parent.height - Style.space(48))
        radius: Style.cornerRadius
        color: Color.popups.background
        border.width: 1
        border.color: Color.popups.border

        // Keep clicks inside the picker from reaching the dismissing scrim.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(26)
            spacing: Style.space(12)

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    Text {
                        Layout.fillWidth: true
                        text: "Edit an installed theme"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.busy ? "Opening theme workspace…" : "Choose a theme to open in Omagen Studio"
                        color: Color.popups.text
                        opacity: 0.62
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                }

                Button {
                    text: "×"
                    foreground: Color.popups.text
                    onClicked: root.closeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Stock, user, and Omagen-managed themes are shown with their native preview artwork. Select one to snapshot it before editing."
                color: Color.popups.text
                opacity: 0.65
                wrapMode: Text.Wrap
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.themes.length === 0

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Opening…" : "No installed themes found"
                    color: Color.popups.text
                    opacity: 0.62
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }
            }

            ScrollView {
                id: themeScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.themes.length > 0
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                GridLayout {
                    id: themeGrid
                    width: themeScroll.availableWidth
                    columns: 2
                    columnSpacing: Style.space(12)
                    rowSpacing: Style.space(12)

                    Repeater {
                        model: root.themes

                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: (themeGrid.width - themeGrid.columnSpacing) / 2
                            Layout.preferredHeight: Style.space(218)
                            radius: Style.cornerRadius
                            color: tileMouse.containsMouse
                                ? Util.alpha(Color.accent, 0.13)
                                : Util.alpha(Color.popups.text, 0.045)
                            border.width: tileMouse.containsMouse ? 2 : 1
                            border.color: tileMouse.containsMouse
                                ? Color.accent
                                : Util.alpha(Color.popups.border, 0.62)

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                onClicked: root.themeSelected(tile.modelData.id || tile.modelData.name)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.space(8)
                                spacing: Style.space(7)

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Style.space(142)
                                    radius: Math.max(4, Style.cornerRadius - Style.space(4))
                                    color: Util.alpha(Color.background, 0.55)
                                    border.width: 1
                                    border.color: Util.alpha(Color.popups.border, 0.5)
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: Boolean(tile.modelData.preview_path)
                                        source: tile.modelData.preview_path ? Util.fileUrl(tile.modelData.preview_path) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 420
                                        sourceSize.height: 180
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: Boolean(tile.modelData.preview_path)
                                        color: Util.alpha(Color.background, 0.12)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !tile.modelData.preview_path
                                        text: "No preview"
                                        color: Color.popups.text
                                        opacity: 0.45
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(2)

                                    Text {
                                        Layout.fillWidth: true
                                        text: tile.modelData.name || tile.modelData.id
                                        color: Color.popups.text
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: (tile.modelData.kind || "theme") + " · " + (tile.modelData.id || "")
                                        color: Color.popups.text
                                        opacity: 0.52
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorMessage !== ""
                text: root.errorMessage
                color: Color.urgent
                wrapMode: Text.Wrap
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
        }
    }
}
