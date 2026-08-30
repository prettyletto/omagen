import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui as Ui
import "Contrast.js" as Contrast

Item {
    id: root
    property bool opened: false
    property bool busy: false
    property string errorMessage: ""
    property string validationError: ""
    property bool generateUnlock: false
    property bool capturePreview: false
    property bool saveLookFeelPreset: false
    property string lookFeelPresetName: ""
    property bool themeEditMode: false
    property string sourceThemeName: ""
    property bool replaceSource: false
    signal cancelled()
    signal confirmed(string name, bool generateUnlock, bool capturePreview, bool replaceSource, bool saveLookFeelPreset, string lookFeelPresetName)
    visible: opened

    function openWith(name) {
        validationError = ""
        nameInput.text = name
        lookFeelPresetName = name
        generateUnlock = false
        capturePreview = false
        saveLookFeelPreset = false
        replaceSource = false
        opened = true
        Qt.callLater(function() { nameInput.forceActiveFocus(); nameInput.selectAll() })
    }
    function reset() {
        opened = false
        validationError = ""
        nameInput.text = ""
        lookFeelPresetName = ""
        generateUnlock = false
        capturePreview = false
        saveLookFeelPreset = false
        replaceSource = false
    }
    function close() { if (!busy) { opened = false; validationError = "" } }
    function submit() {
        if (busy) return
        const value = nameInput.text.trim()
        if (value.length === 0) { validationError = "Theme name cannot be empty"; return }
        if (value.length > 64) { validationError = "Theme name must be 64 characters or fewer"; return }
        const presetName = root.lookFeelPresetName.trim()
        if (root.saveLookFeelPreset && presetName.length === 0) { validationError = "Look & Feel preset name cannot be empty"; return }
        if (root.saveLookFeelPreset && presetName.length > 64) { validationError = "Look & Feel preset name must be 64 characters or fewer"; return }
        validationError = ""
        confirmed(value, root.generateUnlock, root.capturePreview, root.replaceSource, root.saveLookFeelPreset, presetName)
    }

        Rectangle { anchors.fill: parent; color: Util.alpha(Color.background, 0.72); MouseArea { anchors.fill: parent; onClicked: { root.close(); root.cancelled() } } }
    Rectangle {
        width: 430; height: root.themeEditMode ? 558 : 486; anchors.centerIn: parent; radius: 14; z: 1
        visible: !root.busy
        color: Color.popups.background; border.width: 1; border.color: Color.popups.border
        Keys.onEscapePressed: { if (!root.busy) { root.close(); root.cancelled() } }

        // Consume clicks inside the dialog so the dismissing scrim behind it
        // only closes the modal when the user clicks outside the card.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

        Column {
            anchors.fill: parent; anchors.margins: 24; spacing: 16
            Column { width: parent.width; spacing: 5
                Text { text: "Save theme"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: root.themeEditMode ? "Save your edits as a new clone, or replace the selected theme." : "Choose a name for the permanent Omarchy theme."; color: Color.popups.text; opacity: .58; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            }
            Rectangle { width: parent.width; height: 44; radius: 8; color: Util.alpha(Color.popups.text, 0.06); border.width: 1; border.color: nameInput.activeFocus ? Color.accent : Color.popups.border
                TextInput { id: nameInput; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; verticalAlignment: TextInput.AlignVCenter; color: Color.popups.text; selectionColor: Style.selectionFillFor(Color.popups.text, Color.accent, Color.urgent); selectedTextColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; maximumLength: 64; enabled: !root.busy; Keys.onReturnPressed: root.submit(); Keys.onEnterPressed: root.submit() }
            }
            Ui.Toggle {
                width: parent.width
                label: "Generate unlock screen"
                description: "Include Plymouth artwork and its unlock-switcher preview."
                checked: root.generateUnlock
                foreground: Color.popups.text
                accent: Color.accent
                enabled: !root.busy
                onClicked: root.generateUnlock = !root.generateUnlock
            }
            Ui.Toggle {
                width: parent.width
                label: "Capture live Demo preview"
                description: "Use the loaded Demo workspace as preview.png."
                checked: root.capturePreview
                foreground: Color.popups.text
                accent: Color.accent
                enabled: !root.busy
                onClicked: root.capturePreview = !root.capturePreview
            }
            Ui.Toggle {
                width: parent.width
                label: "Save as Look & Feel preset"
                description: "Save all final Window, Shell, Bar, Animations, and terminal tweaks locally using the preset name below."
                checked: root.saveLookFeelPreset
                foreground: Color.popups.text
                accent: Color.accent
                enabled: !root.busy
                onClicked: root.saveLookFeelPreset = !root.saveLookFeelPreset
            }
            Rectangle {
                visible: root.saveLookFeelPreset
                width: parent.width
                height: 42
                radius: 8
                color: Util.alpha(Color.popups.text, 0.06)
                border.width: 1
                border.color: presetNameInput.activeFocus ? Color.accent : Color.popups.border
                TextInput {
                    id: presetNameInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Color.popups.text
                    selectionColor: Style.selectionFillFor(Color.popups.text, Color.accent, Color.urgent)
                    selectedTextColor: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    maximumLength: 64
                    text: root.lookFeelPresetName
                    placeholderText: "Look & Feel preset name"
                    enabled: !root.busy
                    onTextChanged: root.lookFeelPresetName = text
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                }
            }
            Ui.Toggle {
                visible: root.themeEditMode
                width: parent.width
                label: "Replace selected theme in place"
                description: "Explicitly overwrite " + (root.sourceThemeName || "the selected theme") + ". Leave this off to create a clone with a new name."
                checked: root.replaceSource
                foreground: Color.popups.text
                accent: Color.accent
                enabled: !root.busy
                onClicked: root.replaceSource = !root.replaceSource
            }
            Text { visible: root.errorMessage !== "" || root.validationError !== ""; width: parent.width; text: root.errorMessage !== "" ? root.errorMessage : root.validationError; textFormat: Text.PlainText; color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
            Item { width: 1; height: root.errorMessage !== "" || root.validationError !== "" ? 0 : 14 }
            Row { anchors.right: parent.right; spacing: 10
                Rectangle { width: 95; height: 38; radius: 8; color: Util.alpha(Color.popups.text, 0.06); border.width: 1; border.color: Color.popups.border; opacity: root.busy ? .4 : 1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: { root.close(); root.cancelled() } }
                }
                Rectangle { width: 130; height: 38; radius: 8; color: Color.accent; opacity: root.busy ? .55 : 1
                Text { anchors.centerIn: parent; text: root.busy ? "Applying…" : "Save & Apply"; color: Contrast.textFor(Color.accent, Color.background, Color.foreground); font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.submit() }
                }
            }
        }
    }

    // Keep the user oriented while the backend applies the permanent theme.
    // This replaces the editable form instead of leaving a disabled-looking
    // Save dialog on screen during the potentially longer Omarchy work.
    Rectangle {
        anchors.fill: parent
        visible: root.busy
        color: "transparent"
        z: 2

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        Rectangle {
            width: 360
            height: 150
            anchors.centerIn: parent
            radius: 14
            color: Color.popups.background
            border.width: 1
            border.color: Color.popups.border

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8

                Text {
                    width: parent.width
                    text: "Applying theme…"
                    horizontalAlignment: Text.AlignHCenter
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: "Saving the theme and updating Omarchy."
                    horizontalAlignment: Text.AlignHCenter
                    color: Color.popups.text
                    opacity: 0.58
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
