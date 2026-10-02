#version 450

// Party mode overlay: mirror ball + sweeping light beams + reflection spots.
// Output is premultiplied alpha; light is added on top of a light dim.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;   // width / height
    float beat;     // 0 ~ 1, cava level
    float ballX;    // uv
    float ballY;    // uv
    float ballR;    // radius in height units
    float tintR;
    float tintG;
    float tintB;
};

const float PI = 3.14159265;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hue(float h) {
    return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    // height-normalized coords so circles stay round
    vec2 p  = vec2(uv.x * aspect, uv.y);
    vec2 bc = vec2(ballX * aspect, ballY);
    vec2 d  = p - bc;
    float dist = length(d);

    vec3 tint = vec3(tintR, tintG, tintB);
    vec3 col = vec3(0.0);
    float a = 0.30 + 0.10 * beat;

    // ── light beams from the ball ──
    float ang = atan(d.y, d.x);
    float beams = 0.0;
    vec3 beamCol = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float n = 7.0 + fi * 2.0;
        float rot = time * (0.25 + 0.12 * fi) * (i == 1 ? -1.0 : 1.0);
        float s = cos((ang + rot) * n);
        float b = smoothstep(0.985, 1.0, s);
        vec3 c = mix(hue(fract(fi * 0.33 + time * 0.05)), tint, 0.35);
        beamCol += c * b;
        beams += b;
    }
    float beamFall = exp(-dist * 0.9) * smoothstep(ballR, ballR * 1.6, dist);
    col += beamCol * beamFall * (0.16 + 0.22 * beat);

    // ── reflection spots sweeping across the screen ──
    float cell = 0.075;
    vec2 sp = p;
    sp.x += time * 0.06;                      // ball rotation drags spots sideways
    sp.y += sin(time * 0.3 + p.x * 2.0) * 0.01;
    vec2 id = floor(sp / cell);
    vec2 f  = fract(sp / cell) - 0.5;
    float h = hash(id);
    if (h > 0.45) {
        vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
        float r = 0.10 + 0.12 * hash(id + 1.3);
        float spot = smoothstep(r, r * 0.35, length(f - off * 0.5));
        float flick = 0.55 + 0.45 * sin(time * (2.0 + 4.0 * h) + h * 40.0);
        vec3 c = mix(hue(fract(h * 3.7 + time * 0.03)), vec3(1.0), 0.35);
        col += c * spot * flick * (0.30 + 0.45 * beat);
    }

    // ── colored wash pulsing with the beat ──
    vec2 wash1 = vec2(aspect * (0.5 + 0.45 * sin(time * 0.4)), 0.9);
    vec2 wash2 = vec2(aspect * (0.5 + 0.45 * cos(time * 0.33)), 0.6);
    col += hue(fract(time * 0.04)) * exp(-length(p - wash1) * 2.2) * (0.10 + 0.20 * beat);
    col += tint * exp(-length(p - wash2) * 2.5) * (0.08 + 0.18 * beat);

    // ── hanging string ──
    float stringW = 0.0012;
    if (p.y < bc.y - ballR) {
        float s = smoothstep(stringW, 0.0, abs(p.x - bc.x));
        col = mix(col, vec3(0.6), s);
        a = mix(a, 1.0, s);
    }

    // ── mirror ball ──
    float rr = dist / ballR;
    if (rr < 1.0) {
        float z = sqrt(1.0 - rr * rr);
        vec3 n = vec3(d / ballR, z);
        // spherical facet grid, spinning around the vertical axis
        float lon = atan(n.x, n.z) + time * 0.6;
        float lat = asin(clamp(n.y, -1.0, 1.0));
        float rows = 14.0;
        vec2 g = vec2(lon / (2.0 * PI) * rows * 2.0, lat / PI * rows);
        vec2 gid = floor(g);
        vec2 gf = fract(g);
        float edge = smoothstep(0.0, 0.12, min(min(gf.x, 1.0 - gf.x), min(gf.y, 1.0 - gf.y)));
        float fh = hash(gid);
        float base = 0.25 + 0.35 * fh;
        float light = 0.35 + 0.65 * max(dot(n, normalize(vec3(-0.4, -0.6, 0.7))), 0.0);
        float glint = pow(max(sin(time * 3.0 + fh * 60.0), 0.0), 18.0);
        vec3 fc = vec3(base * light) + mix(vec3(1.0), hue(fh), 0.5) * glint * 1.5;
        fc *= mix(0.25, 1.0, edge);
        float m = smoothstep(1.0, 0.97, rr);
        col = mix(col, fc, m);
        a = mix(a, 1.0, m);
    }
    // glow around the ball
    col += vec3(1.0, 0.95, 0.85) * exp(-max(dist - ballR, 0.0) * 18.0) * (0.25 + 0.4 * beat) * step(ballR, dist);

    fragColor = vec4(col, a) * qt_Opacity;
}
