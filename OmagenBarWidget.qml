import QtQuick
import qs.Ui

Item {
    id: root

    property var bar

    implicitWidth: 28
    implicitHeight: 28

    BarIconButton {
        anchors.fill: parent
        bar: root.bar
        text: "O"
        tooltipText: "Open Omagen"
        onPressed: function(button) {
            var shell = root.bar ? root.bar.shell : null
            if (button === Qt.LeftButton && shell)
                shell.summon("pretty.omagen", "{}")
        }
    }
}
