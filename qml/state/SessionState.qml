import QtQuick

QtObject {
    id: root
    property bool active: false
    property string sessionId: ""
    property string originalTheme: ""
    property string originalBackgroundKind: ""
    property string originalBackgroundPath: ""
    property string generationId: ""
    property var palettes: ({})
    property var variantPaths: ({})
    property string selectedVariant: "source"
    property string previewVariant: ""
    readonly property bool workspaceReady: generationId !== "" && ["source","calm","mute","deep","vibrant","balanced"].every(hasPalette)

    function activate(id, theme, backgroundKind, backgroundPath) { sessionId=id; originalTheme=theme; originalBackgroundKind=backgroundKind; originalBackgroundPath=backgroundPath; clearGeneration(); active=true }
    function setGeneration(id, variants) { var next={}, paths={}; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } generationId=id; palettes=next; variantPaths=paths; if (!hasPalette(selectedVariant)) selectedVariant="source" }
    function paletteFor(variant) { return palettes[variant] || null }
    function hasPalette(variant) { return paletteFor(variant) !== null }
    function selectVariant(variant) { if (hasPalette(variant)) selectedVariant=variant }
    function markPreviewed(variant) { previewVariant=variant; selectedVariant=variant }
    function clearGeneration() { generationId=""; palettes=({}); variantPaths=({}); selectedVariant="source"; previewVariant="" }
    function clear() { active=false; sessionId=""; originalTheme=""; originalBackgroundKind=""; originalBackgroundPath=""; clearGeneration() }
}
