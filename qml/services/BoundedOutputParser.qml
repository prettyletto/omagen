import QtQuick
import Quickshell.Io

// SplitParser with an empty delimiter forwards each read chunk without
// retaining an unbounded stream buffer. Keep only the bounded prefix needed by
// the service that consumes the output.
SplitParser {
    id: root

    property int maxBytes: 64 * 1024
    property string text: ""
    property bool truncated: false

    splitMarker: ""

    function utf8ByteLength(value) {
        const encoded = encodeURIComponent(value);
        let bytes = 0;
        for (let index = 0; index < encoded.length; index++) {
            if (encoded[index] === "%")
                index += 2;
            bytes++;
        }
        return bytes;
    }

    function appendPrefix(value, limit) {
        let prefix = "";
        let used = 0;

        for (let index = 0; index < value.length;) {
            let next = index + 1;
            const first = value.charCodeAt(index);
            if (first >= 0xd800 && first <= 0xdbff && index + 1 < value.length) {
                const second = value.charCodeAt(index + 1);
                if (second >= 0xdc00 && second <= 0xdfff)
                    next++;
            }

            const unit = value.slice(index, next);
            const unitBytes = utf8ByteLength(unit);
            if (used + unitBytes > limit)
                break;
            prefix += unit;
            used += unitBytes;
            index = next;
        }

        return prefix;
    }

    function append(value) {
        value = String(value || "");
        if (value === "" || root.truncated)
            return;

        const remaining = root.maxBytes - utf8ByteLength(root.text);
        if (remaining <= 0) {
            root.truncated = true;
            return;
        }

        if (utf8ByteLength(value) <= remaining) {
            root.text += value;
            return;
        }

        root.text += appendPrefix(value, remaining);
        root.truncated = true;
    }

    function reset() {
        root.text = "";
        root.truncated = false;
    }

    onRead: function(value) { root.append(value); }
}
