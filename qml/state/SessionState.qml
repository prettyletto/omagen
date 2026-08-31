import QtQuick

QtObject {
    id: root
    property bool active: false
    property string workflow: "generate"
    property var themeEdit: null
    property string sessionId: ""
    property var shellStyle: ({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) })
    property var desktopStyle: ({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, windowOpacity: 100, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" })
    property var barStyle: ({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", colors: ({}), profile: null, spec: null })
    property var animationsStyle: ({ version: 1, preset: "native", window: "native", windowOpen: "popin", windowClose: "popin", windowMove: "native", windowAmount: 87, windowOpacity: 100, windowSpeed: 4, workspace: "native", workspaceAxis: "horizontal", workspaceTravel: 18, specialWorkspace: "inherit", focus: "native", layers: "native", curve: "bezier", border: "native", borderSpeed: 36, glitch: "none", screenEffect: null, reducedMotion: false })
    property var lookFeel: ({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) })
    property var terminalTranslucency: ({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" })
    property string generationId: ""
    property var palettes: ({})
    property var variantPaths: ({})
    property string selectedVariant: "source"
    property string previewVariant: ""
    readonly property bool workspaceReady: generationId !== "" && (workflow === "theme-edit" ? hasPalette("source") : ["source","calm","mute","deep","vibrant","balanced"].every(hasPalette))

    function activate(id) { sessionId=id; workflow="generate"; themeEdit=null; clearGeneration(); active=true }
    function activateThemeEdit(result) {
        sessionId=result.session_id||""
        workflow="theme-edit"
        themeEdit=result.theme||null
        clearGeneration()
        generationId=result.generation_id||""
        palettes={ source: result.palette||({}) }
        variantPaths={ source: result.path||"" }
        root.ensureSelectedVariant("source")
        active=true
        var recipe=result.recipe||null
        if (recipe) {
            shellStyle=recipe.shell||shellStyle
            desktopStyle=recipe.desktop||desktopStyle
            barStyle=recipe.bar||barStyle
            animationsStyle=animationStyleFrom(recipe.animations)
            lookFeel=recipe.look_feel||lookFeel
            terminalTranslucency=recipe.terminal||terminalTranslucency
            var scopes=[]
            for (var i=0; i<(recipe.managed_scopes||[]).length; ++i)
                scopes.push(String(recipe.managed_scopes[i]))
            if (themeEdit) {
                var edit=themeEdit
                edit.managed_scopes=scopes
                themeEdit=edit
            }
        }
    }
    function setGeneration(id, variants) { var preferred=selectedVariant; var next={}, paths={}; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } generationId=id; palettes=next; variantPaths=paths; root.ensureSelectedVariant(preferred); previewVariant="" }
    function animationStyleFrom(value) { value=value||({}); var glitch=value.glitch||"none"; if(glitch==="flicker")glitch="medium"; var effect=value.screen_effect||value.screenEffect||null; return { version:Number(value.version||1), preset:value.preset||"native", window:value.window||"native", windowOpen:value.window_open||value.windowOpen||"popin", windowClose:value.window_close||value.windowClose||"popin", windowMove:value.window_move||value.windowMove||"native", windowAmount:Number(value.window_amount||value.windowAmount||87), windowOpacity:Number(value.window_opacity||value.windowOpacity||100), windowSpeed:Number(value.window_speed||value.windowSpeed||4), workspace:value.workspace||"native", workspaceAxis:value.workspace_axis||value.workspaceAxis||"horizontal", workspaceTravel:Number(value.workspace_travel||value.workspaceTravel||18), specialWorkspace:value.special_workspace||value.specialWorkspace||"inherit", focus:value.focus||"native", layers:value.layers||"native", curve:value.curve||"bezier", border:value.border||"native", borderSpeed:Number(value.border_speed||value.borderSpeed||36), glitch:glitch, screenEffect:effect, reducedMotion:value.reduced_motion===true||value.reducedMotion===true } }
    function resume(data) { var next={}, paths={}; var variants=data.variants||[]; for (var i=0;i<variants.length;++i) { var e=variants[i]; if (e && e.variant && e.palette) { next[e.variant]=e.palette; paths[e.variant]=e.path||"" } } active=true; workflow=data.workflow||"generate"; themeEdit=data.theme_edit||null; sessionId=data.session_id||""; var style=data.shell_style||data.desktop_style||({}); shellStyle={ preset: style.preset||"default", surface: style.surface||"flat", detail: style.detail||"native", tooltip: style.tooltip||"native", notifications: style.notifications||"native", overrides: style.overrides||({}) }; var desktop=data.desktop_style||({}); desktopStyle={ borderStyle: desktop.border_style||desktop.borderStyle||"solid", borderSize: Number(desktop.border_size !== undefined ? desktop.border_size : desktop.borderSize !== undefined ? desktop.borderSize : -1), borderSizeMode: desktop.border_size_mode||desktop.borderSizeMode||"default", borderSpeed: Number(desktop.border_speed || desktop.borderSpeed || 36), windowOpacity: Number(desktop.window_opacity !== undefined ? desktop.window_opacity : desktop.windowOpacity !== undefined ? desktop.windowOpacity : 100), shape: desktop.shape||"native", spacing: desktop.spacing||"native", depth: desktop.depth||"native", activeStyle: desktop.active_style||desktop.activeStyle||"native", inactiveStyle: desktop.inactive_style||desktop.inactiveStyle||"native" }; var bar=data.bar_style||({}); barStyle={ surface: bar.surface||"native", density: bar.density||"native", attention: bar.attention||"semantic", form: bar.form||"continuous", visibility: bar.visibility||"native", profile: bar.profile||null, spec: bar.spec||null }; animationsStyle=animationStyleFrom(data.animations_style); var lf=data.look_feel||({}); lookFeel={ schemaVersion: Number(lf.schema_version || lf.schemaVersion || 1), preset: lf.preset||"omarchy-native", presetRevision: Number(lf.preset_revision || lf.presetRevision || 1), customized: lf.customized||({}) }; var terminal=data.terminal_translucency||({}); terminalTranslucency={ schemaVersion: Number(terminal.schema_version || terminal.schemaVersion || 1), mode: terminal.mode||"preserve", opacity: Number(terminal.opacity !== undefined ? terminal.opacity : 1), cellMode: terminal.cell_mode||terminal.cellMode||"background" }; generationId=data.generation_id||""; palettes=next; variantPaths=paths; previewVariant=data.preview_variant||""; selectedVariant=previewVariant!=="" ? previewVariant : "source" }
    function paletteFor(variant) { return palettes[variant] || null }
    function hasPalette(variant) { return paletteFor(variant) !== null }
    function selectVariant(variant) { if (hasPalette(variant)) selectedVariant=variant }
    function ensureSelectedVariant(preferred) { var candidate=String(preferred || selectedVariant || ""); if (hasPalette(candidate)) { selectedVariant=candidate; return candidate } if (hasPalette("source")) { selectedVariant="source"; return selectedVariant } var available=Object.keys(palettes); selectedVariant=available.length > 0 ? available[0] : ""; return selectedVariant }
    function markPreviewed(variant) { previewVariant=variant; selectedVariant=variant }
    function clearGeneration() { generationId=""; palettes=({}); variantPaths=({}); selectedVariant="source"; previewVariant="" }
    function clear() { active=false; sessionId=""; workflow="generate"; themeEdit=null; shellStyle=({ preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native", overrides: ({}) }); desktopStyle=({ borderStyle: "solid", borderSize: -1, borderSizeMode: "default", borderSpeed: 36, windowOpacity: 100, shape: "native", spacing: "native", depth: "native", activeStyle: "native", inactiveStyle: "native" }); barStyle=({ surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native", profile: null, spec: null }); animationsStyle=animationStyleFrom({}); lookFeel=({ schemaVersion: 1, preset: "omarchy-native", presetRevision: 1, customized: ({}) }); terminalTranslucency=({ schemaVersion: 1, mode: "preserve", opacity: 1, cellMode: "background" }); clearGeneration() }
}
