import QtQuick

QtObject {
    id: root
    property bool active: false
    property string sessionId: ""
    property var shellStyle: ({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" })
    property var animationsStyle: ({ window: "native", workspace: "native", border: "native", borderSpeed: 36, reducedMotion: false })
    property string generationId: ""
    property var palettes: ({})
    property var variantPaths: ({})
    property string selectedVariant: "source"
    property string previewVariant: ""
    readonly property bool workspaceReady: generationId !== "" && ["source","calm","mute","deep","vibrant","balanced"].every(hasPalette)

    function activate(id) { sessionId=id; clearGeneration(); active=true }
    function setGeneration(id, variants) { var next={}, paths={}; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } generationId=id; palettes=next; variantPaths=paths; selectedVariant="source"; previewVariant="" }
    function resume(data) { var next={}, paths={}; var variants=data.variants||[]; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } active=true; sessionId=data.session_id||""; var style=data.shell_style||data.desktop_style||({}); shellStyle={ surface: style.surface||"flat", detail: style.detail||"native", tooltip: style.tooltip||"native", notifications: style.notifications||"native" }; var desktop=data.desktop_style||({}); desktopStyle={ borderStyle: desktop.border_style||desktop.borderStyle||"solid", borderSize: Number(desktop.border_size !== undefined ? desktop.border_size : desktop.borderSize !== undefined ? desktop.borderSize : -1), borderSizeMode: desktop.border_size_mode||desktop.borderSizeMode||"default", borderSpeed: Number(desktop.border_speed || desktop.borderSpeed || 36), shape: desktop.shape||"native", spacing: desktop.spacing||"native", depth: desktop.depth||"native", activeStyle: desktop.active_style||desktop.activeStyle||"native", inactiveStyle: desktop.inactive_style||desktop.inactiveStyle||"native" }; var bar=data.bar_style||({}); barStyle={ surface: bar.surface||"native", density: bar.density||"native", attention: bar.attention||"semantic", form: bar.form||"continuous", visibility: bar.visibility||"native" }; var animations=data.animations_style||({}); animationsStyle={ window: animations.window||"native", workspace: animations.workspace||"native", border: animations.border||"native", borderSpeed: Number(animations.border_speed || animations.borderSpeed || 36), reducedMotion: animations.reduced_motion === true || animations.reducedMotion === true }; generationId=data.generation_id||""; palettes=next; variantPaths=paths; previewVariant=data.preview_variant||""; selectedVariant=previewVariant!=="" ? previewVariant : "source" }
    function paletteFor(variant) { return palettes[variant] || null }
    function hasPalette(variant) { return paletteFor(variant) !== null }
    function selectVariant(variant) { if (hasPalette(variant)) selectedVariant=variant }
    function markPreviewed(variant) { previewVariant=variant; selectedVariant=variant }
    function clearGeneration() { generationId=""; palettes=({}); variantPaths=({}); selectedVariant="source"; previewVariant="" }
    function clear() { active=false; sessionId=""; shellStyle=({ surface: "flat", detail: "native", tooltip: "native", notifications: "native" }); desktopStyle=({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" }); barStyle=({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" }); animationsStyle=({ window: "native", workspace: "native", border: "native", borderSpeed: 36, reducedMotion: false }); clearGeneration() }
}
