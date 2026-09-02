import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
    id: signal

    property bool enabled: false
    property int triggerEpoch: 0
    property color primaryColor: "#29d9ff"
    property color secondaryColor: "#ff28d7"
    property string fontFamily: "sans-serif"
    property bool running: false
    property real strength: 0
    property real cyanOffset: 0
    property real magentaOffset: 0
    property real shaderTime: 0

    visible: signal.enabled && signal.running
    clip: true

    function trigger() {
        sequence.stop()
        signal.running = true
        signal.strength = 0
        signal.cyanOffset = 0
        signal.magentaOffset = 0
        sequence.start()
    }

    onTriggerEpochChanged: {
        if (signal.enabled && signal.triggerEpoch > 0)
            signal.trigger()
    }

    onEnabledChanged: {
        if (signal.enabled)
            signal.trigger()
    }

    Item {
        id: signalGraphic
        anchors.fill: parent

        Rectangle {
            x: signal.cyanOffset
            y: parent.height * 0.20
            width: parent.width * 0.54
            height: Math.max(1, Math.round(parent.height * 0.09))
            color: signal.primaryColor
            opacity: signal.strength * 0.54
        }
        Rectangle {
            x: parent.width * 0.36 + signal.magentaOffset
            y: parent.height * 0.63
            width: parent.width * 0.49
            height: Math.max(1, Math.round(parent.height * 0.06))
            color: signal.secondaryColor
            opacity: signal.strength * 0.42
        }
        Text {
            x: Math.max(Style.space(6), parent.width * 0.68 + signal.cyanOffset)
            anchors.verticalCenter: parent.verticalCenter
            text: "SYNC//"
            color: signal.primaryColor
            opacity: signal.strength
            font.family: signal.fontFamily
            font.pixelSize: Math.max(8, Math.min(Style.font.caption, parent.height * 0.42))
            font.bold: true
            font.letterSpacing: 0.8
        }
        Text {
            x: Math.max(Style.space(6), parent.width * 0.68 + signal.magentaOffset - 2)
            anchors.verticalCenter: parent.verticalCenter
            text: "SYNC//"
            color: signal.secondaryColor
            opacity: signal.strength * 0.46
            font.family: signal.fontFamily
            font.pixelSize: Math.max(8, Math.min(Style.font.caption, parent.height * 0.42))
            font.bold: true
            font.letterSpacing: 0.8
        }
    }

    ShaderEffectSource {
        id: signalTexture
        anchors.fill: parent
        sourceItem: signalGraphic
        hideSource: true
        live: true
        textureSize: Qt.size(Math.max(1, Math.round(signal.width)), Math.max(1, Math.round(signal.height)))
    }

    ShaderEffect {
        anchors.fill: parent
        visible: signal.enabled && signal.running
        property variant source: signalTexture
        property real time: signal.shaderTime
        property real intensity: signal.strength
        vertexShader: Qt.resolvedUrl("glitch.vert.qsb")
        fragmentShader: Qt.resolvedUrl("glitch.frag.qsb")
    }

    Timer {
        interval: 16
        repeat: true
        running: signal.running
        onTriggered: signal.shaderTime += 0.016
    }

    SequentialAnimation {
        id: sequence
        running: false
        ParallelAnimation {
            NumberAnimation { target: signal; property: "strength"; to: 0.86; duration: 110; easing.type: Easing.OutCubic }
            NumberAnimation { target: signal; property: "cyanOffset"; to: 9; duration: 110; easing.type: Easing.OutCubic }
            NumberAnimation { target: signal; property: "magentaOffset"; to: -7; duration: 110; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: signal; property: "strength"; to: 0.24; duration: 190; easing.type: Easing.InOutQuad }
            NumberAnimation { target: signal; property: "cyanOffset"; to: -4; duration: 190; easing.type: Easing.InOutQuad }
            NumberAnimation { target: signal; property: "magentaOffset"; to: 4; duration: 190; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: signal; property: "strength"; to: 0.56; duration: 80; easing.type: Easing.OutCubic }
            NumberAnimation { target: signal; property: "cyanOffset"; to: 3; duration: 80; easing.type: Easing.OutCubic }
            NumberAnimation { target: signal; property: "magentaOffset"; to: -3; duration: 80; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: signal; property: "strength"; to: 0; duration: 240; easing.type: Easing.InOutQuad }
            NumberAnimation { target: signal; property: "cyanOffset"; to: 0; duration: 240; easing.type: Easing.InOutQuad }
            NumberAnimation { target: signal; property: "magentaOffset"; to: 0; duration: 240; easing.type: Easing.InOutQuad }
        }
        ScriptAction { script: signal.running = false }
    }
}
