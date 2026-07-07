#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float curvature;
    float vignetteStrength;
    float scanlineStrength;
    float glitchIntensity;
};

layout(binding = 1) uniform sampler2D source;

float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453123);
}

vec2 barrelDistort(vec2 uv, float k) {
    vec2 cc = uv - 0.5;
    float d2 = dot(cc, cc);
    return uv + cc * d2 * k;
}

void main() {
    vec2 uv = barrelDistort(qt_TexCoord0, curvature);

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, qt_Opacity);
        return;
    }

    // Cyberpsychosis datamosh: short bursts of horizontal block-tearing.
    float burstPhase = floor(time * 0.55);
    float burstT = fract(time * 0.55);
    float burstRoll = hash11(burstPhase * 13.17);
    bool burstActive = glitchIntensity > 0.0 && burstRoll > 0.62 && burstT < 0.16;

    vec2 sampleUV = uv;
    vec3 col;

    if (burstActive) {
        float blockH = 0.028 + hash11(burstPhase * 5.31) * 0.05;
        float rowId = floor(uv.y / blockH);
        float rowRoll = hash11(rowId * 3.71 + burstPhase * 91.7);

        if (rowRoll > 0.5) {
            float xOff = (hash11(rowId * 7.13 + burstPhase * 17.3) - 0.5) * 0.5 * glitchIntensity;
            sampleUV.x = fract(uv.x + xOff);

            float aberr = (rowRoll - 0.5) * 0.03 * glitchIntensity;
            col.r = texture(source, clamp(sampleUV + vec2(aberr, 0.0), 0.0, 1.0)).r;
            col.g = texture(source, sampleUV).g;
            col.b = texture(source, clamp(sampleUV - vec2(aberr, 0.0), 0.0, 1.0)).b;

            if (rowRoll > 0.88) col = 1.0 - col;
        } else {
            col = texture(source, sampleUV).rgb;
        }
    } else {
        col = texture(source, sampleUV).rgb;
    }

    float scan = mix(1.0, sin(uv.y * 850.0) * 0.5 + 0.5, scanlineStrength);
    col *= scan;

    vec2 vc = uv - 0.5;
    float vig = clamp(1.0 - dot(vc, vc) * vignetteStrength, 0.0, 1.0);
    col *= vig;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
