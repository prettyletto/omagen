// QVariantList values crossing a QML signal boundary are array-like, but
// Array.isArray() returns false for them. Normalize those values before a
// gateway validates or forwards a JSON array.
function toArray(value) {
    if (Array.isArray(value))
        return value;
    if (!value || typeof value !== "object")
        return null;

    const length = value.length;
    if (typeof length !== "number"
            || !isFinite(length)
            || length < 0
            || Math.floor(length) !== length
            || length > 32768) {
        return null;
    }

    const result = [];
    for (let index = 0; index < length; index++) {
        const entry = value[index];
        if (typeof entry === "undefined")
            return null;
        result.push(entry);
    }
    return result;
}
