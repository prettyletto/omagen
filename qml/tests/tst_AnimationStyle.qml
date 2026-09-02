import QtTest
import "../features/style-editor/AnimationStyle.js" as AnimationStyle

TestCase {
    name: "AnimationStyle"

    function test_retroVHSDefaults() {
        var result = AnimationStyle.chooseScreenEffect({}, "retro-vhs")

        compare(result.preset, "custom")
        compare(result.glitch, "none")
        compare(result.screenEffect.id, "retro-vhs")
        compare(result.screenEffect.strength, "medium")
        compare(result.screenEffect.durationMs, 1100)
        compare(result.screenEffect.triggers.length, 4)
        verify(result.screenEffect.coalesce)
    }

    function test_retroVHSStrengthAndDurationRemainEditable() {
        var selected = AnimationStyle.chooseScreenEffect({}, "retro-vhs")
        var stronger = AnimationStyle.chooseEffectStrength(selected, "strong")
        var longer = AnimationStyle.editEffectDuration(stronger, 1450)

        compare(stronger.screenEffect.id, "retro-vhs")
        compare(stronger.screenEffect.strength, "strong")
        compare(longer.screenEffect.durationMs, 1450)
    }
}
