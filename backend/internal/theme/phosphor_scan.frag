#version 300 es
precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

void main() {
    float progress = clamp(time / __OMAGEN_DURATION_SECONDS__, 0.0, 1.0);
    float attack = smoothstep(0.0, 0.08, progress);
    float decay = 1.0 - smoothstep(0.28, 1.0, progress);
    float envelope = attack * decay;
    vec2 uv = v_texcoord;
    float syncBand = exp(-pow((uv.y - fract(progress * 1.35)) * 12.0, 2.0));
    uv.x += sin(uv.y * 42.0 + time * 16.0) * __OMAGEN_SYNC_OFFSET__ * syncBand * envelope;
    vec4 center = texture(tex, uv);
    float scanline = sin(uv.y * 980.0) * __OMAGEN_SCANLINE__ * envelope;
    float phosphor = (0.55 + 0.45 * sin(uv.y * 510.0 + time * 18.0)) * __OMAGEN_PHOSPHOR__ * envelope;
    vec3 color = center.rgb * (1.0 - scanline);
    color += vec3(0.18, 0.48, 0.24) * phosphor;
    fragColor = vec4(color, center.a);
}
