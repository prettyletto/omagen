import QtQuick

// A deliberately contained cyberpunk signal. It belongs to the Omagen QML
// surface that owns it; it never samples or distorts desktop pixels.
Item {
    id: root

    property bool enabled: false
    property int triggerEpoch: 0
    property color accentColor: "#29d9ff"
    property color secondaryColor: "#ff28d7"
    property bool running: false
    property real signalOpacity: 0
    property real cyanShift: 0
    property real magentaShift: 0
    property real shaderTime: 0

    visible: root.enabled && root.running
    clip: true

    function trigger() {
        signalBurst.stop()
        root.running = true
        root.signalOpacity = 0
        root.cyanShift = 0
        root.magentaShift = 0
        signalBurst.start()
    }

    onTriggerEpochChanged: {
        if (root.enabled && root.triggerEpoch > 0)
            root.trigger()
    }

    // Make Test Live visibly prove the effect as soon as a Cyberpunk-owned
    // surface appears, even when opening the surface itself emits no Hyprland
    // window event.
    onEnabledChanged: {
        if (root.enabled)
            root.trigger()
    }

    Item {
        id: signalGraphic
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.accentColor
            opacity: root.signalOpacity * 0.72
        }

        Rectangle {
            x: root.cyanShift
            y: parent.height * 0.18
            width: parent.width * 0.62
            height: 1
            color: root.accentColor
            opacity: root.signalOpacity
        }

        Rectangle {
            x: parent.width * 0.27 + root.magentaShift
            y: parent.height * 0.49
            width: parent.width * 0.56
            height: 2
            color: root.secondaryColor
            opacity: root.signalOpacity * 0.78
        }

        Rectangle {
            x: root.cyanShift * -0.6
            y: parent.height * 0.77
            width: parent.width * 0.42
            height: 1
            color: root.accentColor
            opacity: root.signalOpacity * 0.64
        }
    }

    ShaderEffectSource {
        id: signalTexture
        anchors.fill: parent
        sourceItem: signalGraphic
        hideSource: true
        live: true
        textureSize: Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.enabled && root.running
        property variant source: signalTexture
        property real time: root.shaderTime
        property real intensity: root.signalOpacity
        vertexShader: Qt.resolvedUrl("glitch.vert.qsb")
        fragmentShader: Qt.resolvedUrl("glitch.frag.qsb")
    }

    Timer {
        interval: 16
        repeat: true
        running: root.running
        onTriggered: root.shaderTime += 0.016
    }

    SequentialAnimation {
        id: signalBurst
        running: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "signalOpacity"; to: 0.28; duration: 125; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "cyanShift"; to: 6; duration: 125; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "magentaShift"; to: -5; duration: 125; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "signalOpacity"; to: 0.09; duration: 210; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "cyanShift"; to: -4; duration: 210; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "magentaShift"; to: 4; duration: 210; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "signalOpacity"; to: 0.21; duration: 95; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "cyanShift"; to: 3; duration: 95; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "magentaShift"; to: -3; duration: 95; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "signalOpacity"; to: 0; duration: 320; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "cyanShift"; to: 0; duration: 320; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "magentaShift"; to: 0; duration: 320; easing.type: Easing.InOutQuad }
        }
        ScriptAction { script: root.running = false }
    }
}
