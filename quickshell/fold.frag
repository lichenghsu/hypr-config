#version 450

// iPhone Duo style close: one half stays flat, the other swings over the
// vertical hinge (0 -> 180 deg) toward the eye and lands on top of it, like
// shutting a book. Perspective-projected; the moving face gets the
// frosted-glass blur and darkening from duo_unfold.agsl
// (github.com/marcoazeem/duo-open, itself based on github.com/Atomicx7/Duo-animation).
// Past 90 deg the screen faces away, so we see the pane's dark back.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float resW;
    float resH;
    float tilt;        // radians the moving pane has swung, 0 = flat, PI = shut
    float eyeDist;     // px from the plane
    float blurSpread;  // blur radius per px the pane point left the plane
    float darkening;   // light lost per px of blur radius
    float fade;        // 0..1 extra fade to black at the end
    float paneSide;    // +1 right half moves, -1 left half moves
    float vacatedGlow; // brightness of the ghost left where the moving half was
};

layout(binding = 1) uniform sampler2D source;

const float GOLDEN_ANGLE = 2.39996322972865332;
const float TWO_PI = 6.28318530717958648;
const float PI = 3.14159265358979;

vec3 frosted(vec2 hit, vec2 res, vec2 p, float radius) {
    if (radius < 0.5) return texture(source, hit / res).rgb;
    float taps = clamp(radius * 2.0, 6.0, 32.0);
    float rot = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) * TWO_PI;
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 32; i++) {
        float fi = float(i);
        float w = 1.0 - step(taps, fi);
        float r = radius * sqrt((fi + 0.5) / taps);
        float a = fi * GOLDEN_ANGLE + rot;
        sum += texture(source, (hit + r * vec2(cos(a), sin(a))) / res).rgb * w;
        wsum += w;
    }
    return sum / max(wsum, 1.0);
}

void main() {
    vec2 res = vec2(resW, resH);
    vec2 p = qt_TexCoord0 * res;
    float keep = (1.0 - fade) * qt_Opacity;

    float hinge = res.x * 0.5;
    vec2 eye = vec2(hinge, res.y * 0.5);
    float sn = sin(tilt), cs = cos(tilt);

    // Signed distance from the hinge, positive toward the moving half.
    float dx = paneSide * (p.x - hinge);

    // Inverse perspective onto the moving pane: pane point u (px from the
    // hinge) sits at (u cos, u sin) in (x, depth toward eye) and projects
    // with factor eyeDist / (eyeDist - u sin).
    float denom = eyeDist * cs + dx * sn;
    float u = denom > 1e-3 ? dx * eyeDist / denom : -1.0;
    float gap = u * sn;
    float scale = (eyeDist - gap) / eyeDist;
    float srcY = eye.y + (p.y - eye.y) * scale;
    bool onPane = u >= 0.0 && u <= hinge && srcY >= 0.0 && srcY <= res.y && tilt > 1e-4;

    if (onPane) {
        // Screen faces the eye until it swings past edge-on.
        vec3 pt = vec3(u * cs, 0.0, gap);
        vec3 nrm = vec3(-sn, 0.0, cs);
        vec3 toEye = vec3(0.0, 0.0, eyeDist) - pt;
        float facing = dot(nrm, toEye);

        if (facing > 0.0) {
            float radius = blurSpread * gap;
            float atten = max(1.0 - darkening * radius, 0.0);
            vec3 col = frosted(vec2(hinge + paneSide * u, srcY), res, p, radius);
            fragColor = vec4(col * atten * keep, keep);
        } else {
            // Back of the phone: near-black, a touch lighter toward the hinge.
            float lit = 0.10 * (1.0 - u / hinge) + 0.03;
            fragColor = vec4(vec3(lit) * keep, keep);
        }
        return;
    }

    if (dx < 0.0 || tilt < 1e-4) {
        // Still half: flat and crisp, shadowed as the other half closes over it.
        float shadow = 1.0 - 0.55 * smoothstep(0.3 * PI, PI, tilt);
        fragColor = vec4(texture(source, qt_TexCoord0).rgb * shadow * keep, keep);
        return;
    }

    // Where the moving half used to be: a blurred, dimmed ghost of it that
    // dies out as the pane swings over, instead of snapping to black.
    float ghost = mix(1.0, vacatedGlow, smoothstep(0.0, 0.3 * PI, tilt))
                * (1.0 - smoothstep(0.3 * PI, 0.9 * PI, tilt));
    vec3 col = frosted(p, res, p, 28.0 * smoothstep(0.0, 0.3 * PI, tilt)) * ghost;
    fragColor = vec4(col * keep, keep);
}
