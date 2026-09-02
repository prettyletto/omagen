import QtQuick

Item {
    id: root

    property var bar: null

    anchors.fill: parent
    implicitWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: root.bar !== null
        source: root.bar
            ? Qt.resolvedUrl(root.bar.vertical
                ? "OrbitVerticalBar.qml"
                : "OrbitHorizontalBar.qml")
            : ""
        onLoaded: if (item && "bar" in item) item.bar = root.bar
    }
}
