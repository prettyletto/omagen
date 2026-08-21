import QtQuick

QtObject {
    id: root
    property bool active: false
    property string sessionId: ""
    property var shellStyle: ({ surface: "flat", detail: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous" })
    property string generationId: ""
    property var palettes: ({})
    property var variantPaths: ({})
    property string selectedVariant: "source"
    property string previewVariant: ""
    readonly property bool workspaceReady: generationId !== "" && ["source","calm","mute","deep","vibrant","balanced"].every(hasPalette)

    function activate(id) { sessionId=id; clearGeneration(); active=true }
    function setGeneration(id, variants) { var next={}, paths={}; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } generationId=id; palettes=next; variantPaths=paths; if (!hasPalette(selectedVariant)) selectedVariant="source" }
    function resume(data) { var next={}, paths={}; var variants=data.variants||[]; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } active=true; sessionId=data.session_id||""; var style=data.shell_style||data.desktop_style||({}); shellStyle={ surface: style.surface||"flat", detail: style.detail||"native" }; var bar=data.bar_style||({}); barStyle={ surface: bar.surface||"native", density: bar.density||"native", attention: bar.attention||"semantic", form: bar.form||"continuous" }; generationId=data.generation_id||""; palettes=next; variantPaths=paths; previewVariant=data.preview_variant||""; selectedVariant=previewVariant!=="" ? previewVariant : "source" }
    function paletteFor(variant) { return palettes[variant] || null }
    function hasPalette(variant) { return paletteFor(variant) !== null }
    function selectVariant(variant) { if (hasPalette(variant)) selectedVariant=variant }
    function markPreviewed(variant) { previewVariant=variant; selectedVariant=variant }
    function clearGeneration() { generationId=""; palettes=({}); variantPaths=({}); selectedVariant="source"; previewVariant="" }
    function clear() { active=false; sessionId=""; shellStyle=({ surface: "flat", detail: "native" }); barStyle=({ surface: "native", density: "native", attention: "semantic", form: "continuous" }); clearGeneration() }
}
