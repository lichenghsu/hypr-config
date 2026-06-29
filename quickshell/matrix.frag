#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float gridW;
    float gridH;
    float numChars;
    float trailLen;
};

layout(binding = 1) uniform sampler2D atlasSource;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void main() {
    vec2 uv = qt_TexCoord0;

    float col      = floor(uv.x / gridW);
    float row      = floor(uv.y / gridH);
    float totalRows = floor(1.0 / gridH);

    float colSeed = col * 0.17319 + 3.7;
    float speed   = 1.0 + hash(colSeed) * 1.2;
    float phase   = hash(colSeed + 19.3) * (totalRows + trailLen);

    float headRow = mod(time * speed * totalRows * 0.12 + phase, totalRows + trailLen) - trailLen;
    float dist    = row - headRow;

    if (dist < 0.0 || dist >= trailLen) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Tier: 0=head, 1=bright, 2=medium, 3=dim
    int tier;
    if (dist < 1.0) {
        tier = 0;
    } else {
        float t = (dist - 1.0) / max(trailLen - 1.0, 1.0);
        tier = 1 + min(int(t * 3.0), 2);
    }

    // Character selection:
    // - head: very fast (~20/s), unique per column
    // - body: moderate (~8/s), unique per cell so neighbours look independent
    float charIdx;
    if (dist < 1.0) {
        float t = floor(time * 20.0 + hash(colSeed + 7.1) * 100.0);
        charIdx = floor(hash(col * 13.73 + t) * numChars);
    } else {
        float t = floor(time * 8.0 + hash(col * 31.71 + row * 7.31) * 51.0);
        charIdx = floor(hash(col * 13.73 + row * 91.13 + t) * numChars);
    }
    charIdx = clamp(charIdx, 0.0, numChars - 1.0);

    vec2 cellUV = vec2(fract(uv.x / gridW), fract(uv.y / gridH));
    vec2 atlasUV = vec2(
        (charIdx + cellUV.x) / numChars,
        (float(tier) + cellUV.y) / 4.0
    );

    fragColor = texture(atlasSource, atlasUV);
}
