import QtTest
import QtQuick
import "../gateways"

TestCase {
    name: "PreviewGateway"

    PreviewGateway {
        id: gateway
    }

    function test_stylePayloadCarriesDesktopWindowOpacityFromPresetsAndEdits() {
        var payload = gateway.styleOverridesPayload({
            desktop: {
                borderStyle: "blend", borderSize: 2, borderSizeMode: "fixed", borderSpeed: 36,
                windowOpacity: 72, shape: "rounded", spacing: "airy", depth: "shadow",
                activeStyle: "frosted_light", inactiveStyle: "frosted_light"
            }
        })

        compare(payload.desktop.window_opacity, 72)
    }

    function test_stylePayloadPreservesExplicitZeroOpacity() {
        var payload = gateway.styleOverridesPayload({ desktop: { window_opacity: 0 } })

        compare(payload.desktop.window_opacity, 0)
    }
}
