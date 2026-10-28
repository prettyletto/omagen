import QtTest
import "../gateways/JsonArray.js" as JsonArray

TestCase {
    name: "JsonArray"

    signal parsed(var value)
    property var received: null
    onParsed: function(value) { received = JsonArray.toArray(value) }

    function test_normalizesParsedCatalogAcrossSignalBoundary() {
        received = null
        parsed(JSON.parse('[{"id":"glass-blur"},{"id":"nature"}]'))
        verify(received !== null)
        compare(received.length, 2)
        compare(received[0].id, "glass-blur")
        compare(received[1].id, "nature")
    }

    function test_preservesJavaScriptArray() {
        const source = [{ id: "glass-blur" }]
        const result = JsonArray.toArray(source)

        verify(Array.isArray(result))
        compare(result.length, 1)
        compare(result[0].id, "glass-blur")
    }

    function test_normalizesQmlArrayLikeValue() {
        const source = ({
            0: { id: "glass-blur" },
            1: { id: "nature" },
            length: 2
        })
        verify(!Array.isArray(source))

        const result = JsonArray.toArray(source)
        verify(Array.isArray(result))
        compare(result.length, 2)
        compare(result[0].id, "glass-blur")
        compare(result[1].id, "nature")
    }

    function test_rejectsObjectsWithoutArrayShape() {
        compare(JsonArray.toArray({ id: "glass-blur" }), null)
    }

    function test_rejectsSparseArrayLikeValues() {
        compare(JsonArray.toArray({ length: 1 }), null)
    }
}
