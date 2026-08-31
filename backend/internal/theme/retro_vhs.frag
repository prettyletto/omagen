#version 300 es
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

float hash(vec2 point) {
    // Keep every intermediate bounded for mediump fragment precision. The
    // classic sin(dot()) hash can overflow on a 960x540 noise grid and turn
    // the final color into NaN, which some compositor/GPU pairs display as a
    // large black region.
    point = fract(point * 0.1031);
    point += dot(point, point.yx + 33.33);
    return fract((point.x + point.y) * point.x);
}

vec4 sampleFrame(vec2 uv) {
    // Keep the analog offsets inside the compositor texture. Border sampling
    // is implementation-dependent and can turn a harmless edge wobble into a
    // large black wedge on some Hyprland/GPU combinations.
    return texture(tex, clamp(uv, vec2(0.001), vec2(0.999)));
}

void main() {
    float progress = clamp(time / __OMAGEN_DURATION_SECONDS__, 0.0, 1.0);
    float attack = smoothstep(0.0, 0.08, progress);
    float decay = 1.0 - smoothstep(0.38, 1.0, progress);
    float envelope = attack * decay;

    vec2 uv = clamp(v_texcoord, vec2(0.0), vec2(1.0));
    float trackingY = fract(progress * 0.92 + 0.04);
    float trackingBand = exp(-pow((uv.y - trackingY) * 24.0, 2.0));
    float wobble = sin(uv.y * 44.0 + time * 19.0) * __OMAGEN_RETRO_TRACKING__;
    float tapeJitter = sin(uv.y * 180.0 - time * 31.0) * 0.00035;
    uv.x += (wobble * (0.22 + 0.78 * trackingBand) + tapeJitter) * envelope;

    float chromaOffset = __OMAGEN_RETRO_CHROMA__ * envelope * (0.35 + 0.65 * trackingBand);
    vec4 center = sampleFrame(uv);
    vec3 bleed = (
        sampleFrame(uv - vec2(__OMAGEN_RETRO_BLEED_DISTANCE__ * 0.5, 0.0)).rgb +
        center.rgb +
        sampleFrame(uv + vec2(__OMAGEN_RETRO_BLEED_DISTANCE__ * 0.5, 0.0)).rgb
    ) / 3.0;
    vec3 softened = mix(center.rgb, bleed, __OMAGEN_RETRO_BLEED_MIX__ * envelope);
    float red = sampleFrame(uv + vec2(chromaOffset, 0.0)).r;
    float blue = sampleFrame(uv - vec2(chromaOffset, 0.0)).b;
    vec3 color = vec3(red, softened.g, blue);

    float scanline = sin(uv.y * 1180.0) * __OMAGEN_RETRO_SCANLINE__ * envelope;
    color *= 1.0 - scanline;

    vec2 noisePoint = floor(uv * vec2(960.0, 540.0)) + vec2(floor(time * 28.0));
    float noise = hash(noisePoint) - 0.5;
    color += noise * __OMAGEN_RETRO_NOISE__ * envelope;

    float vignette = smoothstep(0.18, 0.78, distance(uv, vec2(0.5)));
    color *= 1.0 - vignette * __OMAGEN_RETRO_VIGNETTE__ * envelope;
    color += vec3(0.018, 0.008, -0.004) * trackingBand * envelope;

    fragColor = vec4(color, center.a);
}
