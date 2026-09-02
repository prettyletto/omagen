#version 300 es
precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
    // Keep the signal present for 1.25 seconds without holding maximum
    // distortion for the whole interval: a fast attack, two digital beats,
    // then a long controlled return to a perfectly stable desktop.
    float progress = clamp(time / 1.25, 0.0, 1.0);
    float rise = smoothstep(0.0, 0.11, progress);
    float fall = 1.0 - smoothstep(0.40, 1.0, progress);
    float beatOne = 1.0 - smoothstep(0.0, 0.12, abs(progress - 0.17));
    float beatTwo = 1.0 - smoothstep(0.0, 0.10, abs(progress - 0.39));
    float pulse = rise * fall * (0.68 + 0.32 * max(beatOne, beatTwo));

    vec2 uv = v_texcoord;
    float row = floor(uv.y * 180.0);
    float noise = hash(vec2(row, floor(time * 22.0)));
    float tear = step(__OMAGEN_TEAR_THRESHOLD__, noise) * sign(hash(vec2(row, 7.0)) - 0.5);
    uv.x += tear * __OMAGEN_TEAR_DISTANCE__ * pulse;

    vec4 center = texture(tex, uv);
    vec2 chroma = vec2(__OMAGEN_CHROMA_DISTANCE__ * pulse, 0.0);
    float red = texture(tex, uv + chroma).r;
    float blue = texture(tex, uv - chroma).b;
    vec3 color = mix(center.rgb, vec3(red, center.g, blue), __OMAGEN_CHROMA_MIX__ * pulse);
    float scanline = __OMAGEN_SCANLINE__ * sin(uv.y * 900.0 + time * 40.0) * pulse;
    color += vec3(0.03, 0.0, 0.05) * scanline;

    fragColor = vec4(color, center.a);
}
