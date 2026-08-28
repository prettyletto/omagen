#version 300 es
precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    float progress = clamp(time / __OMAGEN_DURATION_SECONDS__, 0.0, 1.0);
    float envelope = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.34, 1.0, progress));
    vec2 uv = v_texcoord;
    float refraction = sin((uv.y + uv.x * 0.22) * 34.0 - time * 9.0);
    float offset = __OMAGEN_SPECTRAL_OFFSET__ * envelope * (0.62 + 0.38 * refraction);
    vec4 center = texture(tex, uv);
    float red = texture(tex, uv + vec2(offset, -offset * 0.20)).r;
    float green = texture(tex, uv + vec2(0.0, offset * 0.18)).g;
    float blue = texture(tex, uv - vec2(offset, offset * 0.14)).b;
    vec3 prism = vec3(red, green, blue);
    vec3 color = mix(center.rgb, prism, __OMAGEN_SPECTRAL_MIX__ * envelope);
    fragColor = vec4(color, center.a);
}
