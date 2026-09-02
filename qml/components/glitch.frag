#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
};
layout(binding = 1) uniform sampler2D source;

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float strength = clamp(intensity, 0.0, 1.0);
    float row = floor(uv.y * 54.0);
    float frame = floor(time * 8.0);
    float rowNoise = hash12(vec2(row, frame));
    float tear = step(0.78, rowNoise) * strength;
    float offset = (hash12(vec2(row + 17.0, frame)) - 0.5) * 0.045 * tear;
    vec2 tearUv = clamp(uv + vec2(offset, 0.0), vec2(0.001), vec2(0.999));

    float rgbShift = (0.004 + 0.018 * strength) * (0.45 + 0.55 * tear);
    vec4 base = texture(source, tearUv);
    float red = texture(source, clamp(tearUv + vec2(rgbShift, 0.0), vec2(0.001), vec2(0.999))).r;
    float blue = texture(source, clamp(tearUv - vec2(rgbShift, 0.0), vec2(0.001), vec2(0.999))).b;
    float scanline = 0.965 + 0.035 * sin(uv.y * 620.0 + time * 2.0);
    vec3 rgb = mix(base.rgb, vec3(red, base.g, blue), strength * 0.82);
    fragColor = vec4(rgb * scanline, base.a) * qt_Opacity;
}
