import QtQuick

QtObject {
    property string harmony: "auto"
    property string primaryText: "4.5"
    property string brightText: "7.0"
    property string secondaryText: "3.0"
    property string uiElement: "3.0"
    property string selectionText: "4.5"

    function load(loadedHarmony, loadedPrimaryText, loadedBrightText, loadedSecondaryText, loadedUiElement, loadedSelectionText) {
        harmony = loadedHarmony;
        primaryText = Number(loadedPrimaryText).toFixed(1);
        brightText = Number(loadedBrightText).toFixed(1);
        secondaryText = Number(loadedSecondaryText).toFixed(1);
        uiElement = Number(loadedUiElement).toFixed(1);
        selectionText = Number(loadedSelectionText).toFixed(1);
    }

    function reset() {
        load("auto", 4.5, 7.0, 3.0, 3.0, 4.5);
    }
}
