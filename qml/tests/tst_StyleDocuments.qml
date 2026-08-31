import QtTest
import "../app/StyleDocuments.js" as StyleDocuments
import "../features/style-editor/WindowStyle.js" as WindowStyle
import "../gateways/ConfigurationArgs.js" as ConfigurationArgs
import "../../bar/BarSizing.js" as BarSizing

TestCase {
    name: "StyleDocuments"

    function test_mergePreservesNestedSiblings() {
        var current = {
            preset: "islands",
            spec: {
                surface: { role: "dark", border_role: "accent", border_width: 1 },
                geometry: { density: "comfortable", radius: 14, section_gap: 10 },
                workspace: { mode: "labels", glyphs: ["I", "II", "III"] }
            }
        }
        var incoming = { spec: { geometry: { density: "compact" } } }

        var result = StyleDocuments.mergeStyleDocument(current, incoming)

        compare(result.preset, "islands")
        compare(result.spec.surface.role, "dark")
        compare(result.spec.surface.border_role, "accent")
        compare(result.spec.geometry.density, "compact")
        compare(result.spec.geometry.radius, 14)
        compare(result.spec.geometry.section_gap, 10)
        compare(result.spec.workspace.mode, "labels")
        compare(result.spec.workspace.glyphs.length, 3)
        compare(current.spec.geometry.density, "comfortable")

        var normalized = StyleDocuments.normalizeBarStyle(result)
        compare(normalized.spec.geometry.density, "compact")
        compare(normalized.spec.geometry.radius, 14)
        compare(normalized.spec.workspace.mode, "labels")
    }

    function test_mergeKeepsExplicitClearsAndReplacesArrays() {
        var current = {
            overrides: { "base.alpha": "0.8" },
            workspace: { mode: "labels", glyphs: ["I", "II"] },
            screenEffect: { id: "rgb-tear", triggers: ["panel"] }
        }
        var incoming = {
            overrides: null,
            workspace: { glyphs: [] },
            screenEffect: null
        }

        var result = StyleDocuments.mergeStyleDocument(current, incoming)

        compare(result.overrides, null)
        compare(result.workspace.mode, "labels")
        compare(result.workspace.glyphs.length, 0)
        compare(result.screenEffect, null)
    }

    function test_barSizesMatchTheLiveBarContract() {
        compare(BarSizing.baseSize("native", false, 26, 28), 26)
        compare(BarSizing.baseSize("native", true, 26, 28), 28)
        compare(BarSizing.baseSize("compact", false, 26, 28), 22)
        compare(BarSizing.baseSize("compact", true, 26, 28), 24)
        compare(BarSizing.baseSize("comfortable", false, 26, 28), 30)
        compare(BarSizing.baseSize("comfortable", true, 26, 28), 32)
        compare(BarSizing.baseSize("compact", false, 26, 28, true, 1.25), 28)
        compare(BarSizing.collapsedClockExtent(78, 30, 14), 92)
        compare(BarSizing.collapsedClockExtent(0, 30, 14), 30)
    }

    function test_barSizeLabelsDoNotPromiseASeparateNativePixelValue() {
        compare(BarSizing.optionLabel("native", false, 22, 24), "Default · native")
        compare(BarSizing.optionLabel("compact", false, 22, 24), "Compact · 22 px · same as native")
        compare(BarSizing.optionLabel("comfortable", false, 22, 24), "Comfortable · 30 px")
    }

    function test_barPresetDensityIsNotInheritedFromThePreviousPreset() {
        compare(BarSizing.presetDensity("native"), "native")
        compare(BarSizing.presetDensity("float"), "compact")
        compare(BarSizing.presetDensity("float-expanded"), "native")
        compare(BarSizing.presetDensity("minimal"), "compact")
        compare(BarSizing.presetDensity("dock"), "native")
        compare(BarSizing.presetDensity("cathedral"), "comfortable")
        compare(BarSizing.presetDensity("pulse"), "compact")
        compare(BarSizing.presetDensity("zen"), "compact")
    }

    function test_lookFeelCompositionSerializesBackendFields() {
        var payload = StyleDocuments.serializeLookFeelComposition({
            schemaVersion: 1,
            preset: "custom-local",
            presetRevision: 4,
            customized: { window: true, animations: true },
            window: {
                borderStyle: "spin", borderSize: 3, borderSizeMode: "fixed", borderSpeed: 72,
                windowOpacity: 48, shape: "soft", spacing: "airy", depth: "shadow", activeStyle: "native", inactiveStyle: "frosted_rich"
            },
            shell: { preset: "glass", surface: "contrast", detail: "framed", tooltip: "accent", notifications: "native", overrides: { "base.alpha": "0.8" } },
            bar: { surface: "dark", density: "compact", attention: "reactive", form: "docked", visibility: "islands", profile: null, spec: { workspace: { mode: "glyphs", glyphs: ["A", "B"] } } },
            animations: {
                version: 1, preset: "custom", window: "cinematic", windowOpen: "slide", windowClose: "fade", windowMove: "native",
                windowAmount: 91, windowOpacity: 94, windowSpeed: 7, workspace: "slidefade", workspaceAxis: "vertical", workspaceTravel: 24,
                specialWorkspace: "slide", focus: "spring", layers: "fade", curve: "spring", border: "spin", borderSpeed: 72,
                glitch: "none", screenEffect: { id: "spectral-shift", strength: "strong", durationMs: 500, triggers: ["panel"], coalesce: true }, reducedMotion: false
            },
            terminal: { schemaVersion: 1, mode: "custom", opacity: 0.78, cellMode: "painted" }
        })

        compare(payload.window.border_style, "spin")
        compare(payload.window.border_size, 3)
        compare(payload.window.window_opacity, 48)
        compare(payload.window.active_style, "native")
        compare(payload.animations.window_open, "slide")
        compare(payload.animations.window_amount, 91)
        compare(payload.animations.workspace_axis, "vertical")
        compare(payload.animations.screen_effect.duration_ms, 500)
        compare(payload.animations.reduced_motion, false)
        compare(payload.terminal.schema_version, 1)
        compare(payload.terminal.cell_mode, "painted")
        compare(payload.bar.spec.workspace.glyphs.length, 2)
    }

    function test_windowOpacityIsSharedAndClampedToTheFullRange() {
        var edited = WindowStyle.editOpacity({ window_opacity: 72, active_style: "frosted_light" }, 0)
        compare(edited.windowOpacity, 0)
        compare(WindowStyle.editOpacity(edited, 125).windowOpacity, 100)
        compare(WindowStyle.copy({ window_opacity: 72 }).windowOpacity, 72)
    }

    function test_generationConfigurationCarriesDesktopWindowOpacity() {
        var args = []
        ConfigurationArgs.appendConfigurationArgs(
            args,
            { preset: "default", surface: "flat", detail: "native", tooltip: "native", notifications: "native" },
            { borderStyle: "solid", borderSize: -1, borderSizeMode: "default", windowOpacity: 48, shape: "native", spacing: "native", depth: "native", inactiveStyle: "native", activeStyle: "native" },
            { surface: "native", density: "native", attention: "semantic", form: "continuous", visibility: "native" },
            null, null, null
        )

        var index = args.indexOf("--window-opacity")
        verify(index >= 0)
        verify(index > args.indexOf("--bar-style"))
        compare(args[index + 1], 48)
    }

    function test_presetDesktopOpacityRemainsAValidResetBaseline() {
        var glass = StyleDocuments.normalizeDesktopStyle({ window_opacity: 72 })
        var edited = WindowStyle.editOpacity(glass, 48)

        compare(glass.windowOpacity, 72)
        compare(edited.windowOpacity, 48)
        compare(WindowStyle.editOpacity(edited, glass.windowOpacity).windowOpacity, 72)
    }
}
