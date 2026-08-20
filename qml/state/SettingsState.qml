import QtQuick

QtObject {
    property string harmony: "auto"
    property real primaryText: 4.5
    property real brightText: 7.0
    property real secondaryText: 3.0
    property real uiElement: 3.0
    property real selectionText: 4.5
    property real ansi: 3.0
    property real brightAnsi: 4.5

    function load(loadedHarmony, loadedPrimaryText, loadedBrightText, loadedSecondaryText, loadedUiElement, loadedSelectionText, loadedAnsi, loadedBrightAnsi) {
        harmony = loadedHarmony;
        primaryText = Number(loadedPrimaryText);
        brightText = Number(loadedBrightText);
        secondaryText = Number(loadedSecondaryText);
        uiElement = Number(loadedUiElement);
        selectionText = Number(loadedSelectionText);
        ansi = Number(loadedAnsi);
        brightAnsi = Number(loadedBrightAnsi);
    }

    function reset() {
        load("auto", 4.5, 7.0, 3.0, 3.0, 4.5, 3.0, 4.5);
    }
}
