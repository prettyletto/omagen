import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Contrast.js" as Contrast

// A small, scroll-safe numeric control for the common shell tokens. It stages
// only on release and deliberately does not consume the mouse wheel, so the
// surrounding Lab can still scroll normally.
Item {
    id: root

    property string label: ""
    property string description: ""
    property string value: ""
    property real fallback: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.01
    property int decimals: 2
    property string suffix: ""
    property string resetText: "Reset"
    property bool integer: false
    property bool modified: value !== ""
    property color foregroundColor: Color.foreground
    property color backgroundColor: Color.background
    property color accentColor: Color.accent
    property real draftValue: root.numericValue
    property bool dragging: false

    signal valueEdited(string value)
    signal resetRequested()

    readonly property real numericValue: {
        var parsed = Number(root.value)
        return isNaN(parsed) ? root.fallback : Math.max(root.minimum, Math.min(root.maximum, parsed))
    }

    implicitHeight: fieldColumn.implicitHeight

    function formatValue(value) {
        var next = root.integer ? Math.round(value) : Number(value.toFixed(root.decimals))
        return String(next)
    }

    function valueFromX(x) {
        var fraction = Math.max(0, Math.min(1, x / track.width))
        var raw = root.minimum + fraction * (root.maximum - root.minimum)
        var snapped = Math.round(raw / root.step) * root.step
        return Math.max(root.minimum, Math.min(root.maximum, root.integer ? Math.round(snapped) : snapped))
    }

    onValueChanged: if (!root.dragging) root.draftValue = root.numericValue

    ColumnLayout {
        id: fieldColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(3)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.foregroundColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.formatValue(root.draftValue) + root.suffix
                color: root.modified ? root.accentColor : root.foregroundColor
                opacity: root.modified ? 1 : 0.58
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
            }

            Rectangle {
                visible: root.modified
                Layout.preferredWidth: Math.max(Style.space(46), resetTextLabel.implicitWidth + Style.space(14))
                Layout.preferredHeight: Style.space(22)
                color: Util.alpha(root.foregroundColor, 0.045)
                border.width: 1
                border.color: Util.alpha(Color.popups.border, 0.72)
                radius: Math.max(Style.space(3), Style.cornerRadius / 3)
                Text {
                    id: resetTextLabel
                    anchors.fill: parent
                    text: root.resetText
                    color: root.foregroundColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetRequested()
                }
            }
        }

        Text {
            visible: root.description !== ""
            Layout.fillWidth: true
            text: root.description
            color: root.foregroundColor
            opacity: 0.52
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(26)

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(4, Style.space(5))
                radius: height / 2
                color: Util.alpha(root.foregroundColor, 0.18)
            }

            Rectangle {
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                width: track.width * ((root.draftValue - root.minimum) / Math.max(0.0001, root.maximum - root.minimum))
                height: track.height
                radius: height / 2
                color: root.accentColor
            }

            Rectangle {
                width: Style.space(16)
                height: width
                radius: width / 2
                x: Math.max(0, Math.min(track.width - width, track.width * ((root.draftValue - root.minimum) / Math.max(0.0001, root.maximum - root.minimum)) - width / 2))
                anchors.verticalCenter: track.verticalCenter
                color: root.accentColor
                border.width: 2
                border.color: Contrast.textFor(root.accentColor, root.backgroundColor, root.foregroundColor)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) {
                    root.dragging = true
                    root.draftValue = root.valueFromX(mouse.x)
                }
                onPositionChanged: function(mouse) {
                    if (root.dragging)
                        root.draftValue = root.valueFromX(mouse.x)
                }
                onReleased: {
                    root.dragging = false
                    root.valueEdited(root.formatValue(root.draftValue))
                }
            }
        }
    }
}
