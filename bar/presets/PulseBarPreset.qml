import QtQuick

Item {
    property var bar: null
    anchors.fill: parent
    implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: bar !== null
        source: bar ? Qt.resolvedUrl(bar.vertical ? "PulseVerticalBar.qml" : "PulseHorizontalBar.qml") : ""
        onLoaded: if (item && "bar" in item) item.bar = bar
    }
}
