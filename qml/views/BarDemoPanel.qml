import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../components" as Components
import "../../bar/BarSizing.js" as BarSizing

// An interactive BarSpec reader surface. It is also the visual contract for
// the full-bar replacement: the demo exposes the same regions and growth
// rules while the live bar owns widget placement and input.
PanelWindow {
    id: root

    property bool active: false
    property string monitorName: ""
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", colors: ({}), profile: null, spec: null })
    property bool motionPlaying: true
    property bool previewExpanded: false
    property bool previewVisible: true
	property bool previewHovered: false
    property bool glitchEnabled: false
    property int glitchEpoch: 0

    signal closeRequested()

    readonly property var targetScreen: root.resolveScreen()
    readonly property var spec: root.barStyle.spec || ({})
    readonly property var surfaceSpec: root.spec.surface || ({})
    readonly property string surfaceTreatment: String(root.surfaceSpec.treatment || "preset")
    readonly property var geometrySpec: root.spec.geometry || ({})
    readonly property var behaviorSpec: root.spec.behavior || ({})
    readonly property var regionsSpec: root.spec.regions || ({})
	readonly property var workspaceSpec: root.spec.workspace || ({})
	readonly property var dockSpec: root.spec.dock || ({})
    readonly property string topology: String(root.spec.topology || root.fallbackTopology())
    readonly property string position: String(root.spec.position || (root.fallbackTopology() === "rail" ? "left" : "top"))
    readonly property bool vertical: root.position === "left" || root.position === "right"
    readonly property bool sectioned: ["sections", "islands", "minimal", "split", "notch"].indexOf(root.topology) >= 0
    readonly property bool replacement: (root.barStyle.profile && String(root.barStyle.profile.implementation || "") === "replacement")
        || String(root.spec.engine || "auto") === "omagen"
        || ["continuous", "minimal"].indexOf(root.topology) < 0
    readonly property bool adapter: !root.replacement && root.barStyle.profile && String(root.barStyle.profile.implementation || "") === "adapter"
    readonly property string ownershipLabel: root.replacement ? "OMAGEN REPLACEMENT" : root.adapter ? "ADDITIVE ADAPTER" : "NATIVE READER"
    readonly property var barColors: root.barStyle.colors || ({})
    readonly property color surfaceColor: root.barColors.background || root.surfaceFor(String(root.surfaceSpec.role || root.barStyle.surface || "native"))
    readonly property color foregroundColor: root.barColors.text || root.foregroundFor(String(root.surfaceSpec.role || root.barStyle.surface || "native"))
    readonly property color activeColor: root.barColors.active || (root.barStyle.attention === "accent" ? Color.accent : Color.urgent)
    readonly property color borderColor: String(root.surfaceSpec.border_role || "none") === "accent" ? Color.accent : Color.foreground
    readonly property real barOpacity: ["preset", "opaque"].indexOf(String(root.surfaceSpec.treatment || "preset")) >= 0
        ? 1
        : (root.surfaceSpec.opacity !== undefined ? Math.max(0, Math.min(1, Number(root.surfaceSpec.opacity))) : 1)
    readonly property real borderOpacity: root.surfaceSpec.border_opacity !== undefined ? Math.max(0, Math.min(1, Number(root.surfaceSpec.border_opacity))) : 0
    readonly property int borderWidth: root.surfaceSpec.border_width !== undefined ? Math.max(0, Number(root.surfaceSpec.border_width)) : 0
    readonly property int barRadius: root.geometrySpec.radius !== undefined ? Math.max(0, Number(root.geometrySpec.radius)) : 0
    readonly property int barBaseThickness: root.geometrySpec.thickness !== undefined && Number(root.geometrySpec.thickness) > 0
        ? Number(root.geometrySpec.thickness)
        : BarSizing.baseSize(
            String(root.geometrySpec.density || root.barStyle.density || "native"),
            root.vertical,
            Style.bar.sizeHorizontal,
            Style.bar.sizeVertical,
            Style.barScaleWithFont,
            Style.fontScale
        )
    readonly property int structuralThicknessPadding: root.topology === "dock"
        || (root.topology === "islands" && root.vertical) ? Style.space(16) : 0
    readonly property int barThickness: root.barBaseThickness + root.structuralThicknessPadding
    readonly property int sectionGap: root.geometrySpec.section_gap !== undefined ? Math.max(4, Number(root.geometrySpec.section_gap)) : Style.space(8)
    readonly property int outerMargin: root.geometrySpec.outer_margin !== undefined ? Math.max(0, Number(root.geometrySpec.outer_margin)) : 0
    readonly property int edgeOffset: root.geometrySpec.edge_offset !== undefined ? Math.max(0, Number(root.geometrySpec.edge_offset)) : 0
	readonly property string alignment: String(root.geometrySpec.alignment || "center")
	readonly property string lengthMode: String(root.geometrySpec.length_mode || "full")
    readonly property var motionSpec: root.spec.motion || ({})
    readonly property int motionDuration: root.motionSpec.duration_ms !== undefined ? Math.max(0, Number(root.motionSpec.duration_ms)) : 180
    readonly property bool motionEnabled: root.motionPlaying && String(root.motionSpec.preset || "native") !== "none" && root.motionDuration > 0
    readonly property bool autoHide: String(root.behaviorSpec.visibility || "always") === "auto_hide"
        || (root.barStyle.profile && root.barStyle.profile.behavior && String(root.barStyle.profile.behavior.visibility || "always") === "auto-hide")
    readonly property bool hoverExpand: root.behaviorSpec.hover_expand === true
        || (root.barStyle.profile && root.barStyle.profile.behavior && String(root.barStyle.profile.behavior.expansion || "none") !== "none")

    function resolveScreen() {
        var screens = Quickshell.screens || []
        if (root.monitorName === "" && screens.length > 0)
            return screens[0]
        for (var index = 0; index < screens.length; index++) {
            if (screens[index].name === root.monitorName)
                return screens[index]
        }
        return screens.length > 0 ? screens[0] : null
    }

    function fallbackTopology() {
        var profile = root.barStyle.profile || ({})
        var behavior = profile.behavior || ({})
        var form = String(behavior.form || "")
        if (form !== "")
            return form === "dock" ? "dock" : form
        if (root.barStyle.visibility === "islands") return "sections"
        return root.barStyle.form === "docked" ? "sections" : "continuous"
    }

    function surfaceFor(role) {
        if (role === "accent") return Color.accent
        if (role === "selection") return Color.selection
        if (role === "dark") return Qt.darker(Color.background, 1.12)
        if (role === "light") return Color.foreground
        if (role === "transparent") return Color.background
        return Color.bar.background
    }

    function foregroundFor(role) {
        return role === "accent" || role === "light" ? Color.background : Color.bar.text
    }

    function titleFor(value) {
        var labels = {
            continuous: "Continuous", floating: "Floating", sections: "Sections",
            islands: "Islands", dock: "Dock", split: "Split", minimal: "Minimal",
            notch: "Notch", rail: "Rail"
        }
        return labels[value] || value
    }

    function behaviorSummary() {
        var visibility = String(root.behaviorSpec.visibility || "always")
        if (visibility === "auto_hide") return "Auto-hide"
        if (visibility === "fullscreen") return "Fullscreen only"
        if (visibility === "hover") return "Intelligent reveal"
        return "Always visible"
    }

    function regionName(index) {
        return ["left", "center", "right"][index] || "center"
    }

    function regionMode(index) {
        var region = root.regionsSpec[root.regionName(index)] || ({})
        return String(region.mode || "native")
    }

    function regionOpacity(index) {
        var mode = root.regionMode(index)
        if (mode === "hidden") return 0.04
        if (mode === "quiet") return 0.42
        return 1
    }

	function workspaceLabel(index) {
		var mode = String(root.workspaceSpec.mode || "native")
		if (mode === "native")
			return index === 0 ? "\uDB85\uDCFB" : String(index + 1)
		if (mode === "dots")
			return index === 0 ? "●" : "○"
		if (mode === "roman")
			return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][index] || String(index + 1)
		if (mode === "letters")
			return String.fromCharCode(65 + index)
		if (mode === "glyphs") {
			var glyphs = root.workspaceSpec.glyphs || []
			return glyphs[index] !== undefined && String(glyphs[index]).length > 0 ? String(glyphs[index]) : String(index + 1)
		}
		return String(index + 1)
	}

	function dockClosedLabel() {
		var mode = String(root.dockSpec.closed || "ellipsis")
		if (mode === "workspace") return root.workspaceLabel(0)
		if (mode === "clock") return Qt.formatTime(new Date(), "HH:mm")
		if (mode === "glyph") return String(root.dockSpec.glyph || "✦")
		return root.vertical ? "⋮" : "···"
	}

	function alignmentLabel() {
		if (root.alignment === "start") return root.vertical ? "TOP → DOWN" : "LEFT → RIGHT"
		if (root.alignment === "end") return root.vertical ? "BOTTOM → UP" : "RIGHT → LEFT"
		return "CENTER → SIDES"
	}

    function motionSummary() {
        if (!root.motionEnabled)
            return "Paused"
        return String(root.motionSpec.preset || "native") + " · " + root.motionDuration + " ms"
    }

    function easingType() {
        var easing = String(root.motionSpec.easing || "out_cubic")
        if (easing === "linear") return Easing.Linear
        if (easing === "out_quart") return Easing.OutQuart
        if (easing === "in_out_cubic") return Easing.InOutCubic
        return Easing.OutCubic
    }

    Timer {
        id: motionCycle
        interval: Math.max(900, root.motionDuration * 5)
        repeat: true
        running: root.active && root.motionEnabled
        onTriggered: {
			if (root.autoHide) {
				// A stationary pointer does not emit another entered event. Keep
				// the explicit hover state authoritative so the demo cannot hide
				// underneath a pointer that is still inside the dock.
				if (root.previewHovered) {
					root.previewVisible = true
					return
				}
				root.previewVisible = !root.previewVisible
			}
            else
                root.previewExpanded = !root.previewExpanded
        }
    }

    visible: root.active && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omagen-bar-demo"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
    }
    margins {
        // Keep the demo reader separate from the live bar so screenshots can
        // distinguish staged data from compositor proof.
        top: Style.bar.sizeHorizontal + Style.space(24)
        left: Style.space(28)
    }
    implicitWidth: Math.max(
        Style.space(560),
        Math.min(Style.space(980), root.targetScreen ? root.targetScreen.width * 0.62 : Style.space(980))
    )
    implicitHeight: Math.max(
        Style.space(420),
        Math.min(Style.space(620), root.targetScreen ? root.targetScreen.height - Style.bar.sizeHorizontal - Style.space(48) : Style.space(620))
    )

    BorderSurface {
        id: surface
        anchors.fill: parent
        color: Util.alpha(Color.popups.background, 0.97)
        radius: Style.cornerRadius
        borderSpec: Border.flat(Util.alpha(root.adapter ? Color.accent : Color.foreground, 0.78), 1)

        Components.SignalGlitch {
            anchors.fill: parent
            z: 10
            enabled: root.glitchEnabled
            triggerEpoch: root.glitchEpoch
            accentColor: Color.accent
            secondaryColor: Color.foreground
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(18)
            spacing: Style.space(10)

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(50)

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                        text: "BAR ENGINE / DEMO READER"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: "Staged composition preview"
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.title
                        font.bold: true
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                        text: root.ownershipLabel + "\nWIDGETS STAY NATIVE"
                        horizontalAlignment: Text.AlignRight
                        color: root.adapter ? Color.accent : Color.foreground
                        opacity: 0.78
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    Button {
                        Layout.preferredWidth: Style.space(34)
                        Layout.preferredHeight: Style.space(34)
                        text: "×"
                        foreground: Color.foreground
                        accent: Color.accent
                        bordered: true
                        tooltipText: "Close Bar Demo"
                        onClicked: root.closeRequested()
                    }
                    Button {
                        Layout.preferredWidth: Style.space(88)
                        Layout.preferredHeight: Style.space(34)
                        text: root.motionPlaying ? "Pause motion" : "Play motion"
                        foreground: Color.foreground
                        accent: Color.accent
                        bordered: true
                        tooltipText: "Pause or resume the staged BarSpec motion preview"
                        onClicked: root.motionPlaying = !root.motionPlaying
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
				columns: 4
				rowSpacing: Style.space(5)
				columnSpacing: Style.space(5)
                Repeater {
                    model: [
                        { label: "TOPOLOGY", value: root.titleFor(root.topology) },
                        { label: "PLACEMENT", value: root.position.toUpperCase() },
                        { label: "BEHAVIOR", value: root.behaviorSummary() },
                        { label: "PANE", value: root.surfaceTreatment.toUpperCase() },
						{ label: "GROWTH", value: root.alignmentLabel() },
						{ label: "WORKSPACES", value: String(root.workspaceSpec.mode || "native").toUpperCase() },
						{ label: "CLOSED", value: root.topology === "dock" ? String(root.dockSpec.closed || "ellipsis").toUpperCase() : "N/A" },
						{ label: "MOTION", value: root.motionSummary() },
						{ label: "ENGINE", value: root.replacement ? "OMAGEN BAR" : root.adapter ? "OMAGEN ADAPTER" : "QUATTRO" }
                    ]
                    delegate: BorderSurface {
                        required property var modelData
                        Layout.fillWidth: true
						Layout.preferredHeight: Style.space(42)
                        color: Util.alpha(root.adapter ? Color.accent : Color.foreground, 0.055)
                        radius: Style.cornerRadius
                        borderSpec: Border.flat(Util.alpha(root.adapter ? Color.accent : Color.foreground, 0.30), 1)
                        Column {
                            anchors.centerIn: parent
                            spacing: Style.space(2)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Color.foreground
                                opacity: 0.55
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: Color.foreground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                            }
                        }
                    }
                }
            }

            BorderSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Util.alpha(Color.foreground, 0.025)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Util.alpha(Color.foreground, 0.14), 1)

                Item {
                    id: stage
                    anchors.fill: parent
                    anchors.margins: Style.space(16)

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: root.vertical ? "VERTICAL RAIL READER" : "HORIZONTAL BAR READER"
                        color: Color.foreground
                        opacity: 0.48
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Item {
                        id: barFrame
						readonly property real availableLength: root.vertical ? stage.height - Style.space(68) : stage.width - Style.space(42)
						readonly property bool contentSized: ["dock", "split", "notch", "islands", "minimal"].indexOf(root.topology) >= 0 || root.lengthMode === "content"
						readonly property real compactLength: root.topology === "minimal"
							? Math.max(Style.space(150), availableLength * 0.24)
							: Math.max(Style.space(190), availableLength * (root.topology === "split" ? 0.62 : 0.46))
						readonly property bool dockCollapsed: root.topology === "dock" && !root.previewExpanded
						readonly property real expandedLength: root.topology === "minimal"
							? availableLength
							: Math.min(availableLength, compactLength * 1.38)
						readonly property real currentLength: root.topology === "dock" && !root.previewExpanded
							? Math.min(Style.space(64), availableLength)
							: contentSized ? (root.previewExpanded ? expandedLength : compactLength) : availableLength
						x: root.vertical ? (stage.width - width) / 2
							: root.topology === "minimal" ? Style.space(21)
							: root.alignment === "start" ? Style.space(21)
							: root.alignment === "end" ? stage.width - width - Style.space(21)
							: (stage.width - width) / 2
						y: !root.vertical ? (stage.height - height) / 2
							: root.topology === "minimal" ? stage.height - height - Style.space(34)
							: root.alignment === "start" ? Style.space(34)
							: root.alignment === "end" ? stage.height - height - Style.space(34)
							: (stage.height - height) / 2
						width: root.vertical ? root.barThickness : currentLength
						height: root.vertical ? currentLength : root.barThickness
                        opacity: root.previewVisible ? 1 : 0.16

						Behavior on width {
							NumberAnimation { duration: root.motionDuration; easing.type: root.easingType() }
						}
						Behavior on height {
							NumberAnimation { duration: root.motionDuration; easing.type: root.easingType() }
						}
						Behavior on x {
							NumberAnimation { duration: root.motionDuration; easing.type: root.easingType() }
						}
						Behavior on y {
                            NumberAnimation { duration: root.motionDuration; easing.type: root.easingType() }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: root.motionDuration; easing.type: root.easingType() }
                        }

                        HoverHandler {
                            onHoveredChanged: {
								root.previewHovered = hovered
								if (hovered)
									root.previewVisible = true
                                if (root.hoverExpand)
                                    root.previewExpanded = hovered
                            }
                        }

                        TapHandler {
                            onTapped: root.previewExpanded = !root.previewExpanded
                        }

                        Repeater {
                            model: root.sectioned ? [0, 1, 2] : [0]
                            delegate: BorderSurface {
                                required property int modelData
                                readonly property string region: root.regionName(modelData)
                                readonly property string regionMode: root.regionMode(modelData)
                                visible: root.topology !== "minimal" || root.previewExpanded || modelData === 0
                                readonly property real sectionStart: root.sectioned ? modelData * (barFrame.width + root.sectionGap) / 3 : 0
                                readonly property real sectionLength: root.sectioned ? (barFrame.width - root.sectionGap * 2) / 3 : barFrame.width
                                readonly property real verticalStart: root.sectioned ? modelData * (barFrame.height + root.sectionGap) / 3 : 0
                                readonly property real verticalLength: root.sectioned ? (barFrame.height - root.sectionGap * 2) / 3 : barFrame.height
                                x: root.vertical ? 0 : sectionStart
                                y: root.vertical ? verticalStart : 0
                                width: root.vertical ? barFrame.width : sectionLength
                                height: root.vertical ? verticalLength : barFrame.height
                                color: Util.alpha(root.surfaceColor, root.barOpacity * root.regionOpacity(modelData))
                                radius: root.barRadius > 0 ? Math.min(root.barRadius, Math.min(width, height) / 2) : Math.min(Style.cornerRadius, Math.min(width, height) / 2)
                                borderSpec: Border.flat(Util.alpha(root.borderColor, root.borderOpacity * (regionMode === "quiet" ? 0.5 : 1)), regionMode === "island" ? Math.max(1, root.borderWidth) : root.borderWidth)

								RowLayout {
									visible: !root.vertical && regionMode !== "hidden"
										&& !barFrame.dockCollapsed
										&& (root.topology !== "minimal" || root.previewExpanded || modelData === 0)
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(10)
                                    anchors.rightMargin: Style.space(10)
                                    spacing: Style.space(8)
									Row {
										visible: modelData === 0
										spacing: Style.space(5)
										Repeater {
											model: 5
											Text {
												required property int modelData
												text: root.workspaceLabel(modelData)
												color: modelData === 0 ? root.activeColor : root.foregroundColor
												opacity: modelData === 0 ? 1 : 0.62
												font.family: Style.font.family
												font.pixelSize: Style.font.bodySmall
												font.bold: modelData === 0
											}
										}
									}
									Text { visible: modelData !== 0; text: modelData === 1 ? "OMAGEN BAR" : "NET 100%"; color: root.foregroundColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { visible: modelData === 0; text: root.barStyle.attention === "accent" ? "●" : "•"; color: root.activeColor; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
                                }

								Text {
									visible: root.vertical && regionMode !== "hidden"
										&& !barFrame.dockCollapsed
										&& (root.topology !== "minimal" || root.previewExpanded || modelData === 0)
                                    anchors.centerIn: parent
									text: modelData === 1 ? "OMAGEN" : modelData === 0 ? [0, 1, 2].map(root.workspaceLabel).join("  ") : "NET"
                                    color: root.foregroundColor
                                    rotation: root.position === "left" ? 90 : -90
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: true
								}
							}
						}

						Text {
							visible: barFrame.dockCollapsed
							anchors.centerIn: parent
							text: root.dockClosedLabel()
							color: root.foregroundColor
							font.family: Style.font.family
							font.pixelSize: root.dockSpec.closed === "glyph" ? Style.font.heading : Style.font.body
							font.bold: true
							fontSizeMode: Text.Fit
							minimumPixelSize: Style.font.caption
						}
					}

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: root.autoHide || root.hoverExpand
                            ? "Hover or click the bar to exercise reveal/expand · replacement host owns the live surface"
                            : "Motion preview is staged here · live widget placement remains user-owned"
                        color: Color.foreground
                        opacity: 0.56
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Style.space(5)
                columnSpacing: Style.space(8)

                Text { text: "THICKNESS  " + root.barThickness + " px"; color: Color.foreground; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Text { text: "RADIUS  " + root.barRadius + " px"; color: Color.foreground; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Text { text: "EDGE OFFSET  " + root.edgeOffset + " px"; color: Color.foreground; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Text { text: "OUTER MARGIN  " + root.outerMargin + " px"; color: Color.foreground; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            }
        }
    }
}
