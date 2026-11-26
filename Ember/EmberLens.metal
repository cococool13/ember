// The Ember lens: a biconvex chrome disc with the mark's ember crescent inlaid
// on its face, raymarched in one SwiftUI colour effect. Ported from the site's
// Kron hero (docs/design/DIRECTION.md): the same pale studio above, the page
// below, and a shadow in a burnt tint of Coal that is tight when the lens is
// low and wide and soft when it lifts. Used once, on the setup welcome step.
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float THICK = 0.26;                              // half thickness at the centre
constant float BIG = (1.0 + THICK * THICK) / (2.0 * THICK); // sphere radius so the rim is at r = 1
constant float SAFE = 0.8;
constant float TILT = 0.48869219;                         // 28°: the lit side faces lower right
constant float TERM = 0.42;                               // EmberGeometry.iconTerminator

static float lensSDF(float3 p) {
    float a = length(p - float3(0, 0, -(BIG - THICK))) - BIG;
    float b = length(p - float3(0, 0, BIG - THICK)) - BIG;
    return max(a, b) * SAFE;
}

static float mapW(float3 pw, float3x3 m) { return lensSDF(m * pw); }

static float3 normalW(float3 p, float3x3 m) {
    float2 e = float2(1, -1) * 0.0018;
    return normalize(e.xyy * mapW(p + e.xyy, m) + e.yyx * mapW(p + e.yyx, m) +
                     e.yxy * mapW(p + e.yxy, m) + e.xxx * mapW(p + e.xxx, m));
}

// Studio above (warmed a touch toward Ash), Coal below.
static float3 env(float3 r) {
    float e = r.z;
    float3 dark = float3(0.035, 0.026, 0.021);
    float3 sky = mix(float3(0.53, 0.52, 0.53), float3(0.985, 0.965, 0.94), smoothstep(0.08, 0.9, e));
    sky += float3(0.55) * smoothstep(0.70, 0.86, dot(r, float3(-0.5498, -0.6198, 0.5598)));
    sky *= 1.0 - 0.7 * smoothstep(0.865, 0.915, dot(r, float3(0.7836, 0.1206, 0.6094)));
    sky *= 1.0 - 0.65 * smoothstep(0.935, 0.965, dot(r, float3(-0.2504, 0.7512, 0.6109)));
    sky = mix(dark, sky, smoothstep(0.015, 0.17, e));
    float3 coal = float3(0.102, 0.082, 0.071);
    float3 ash = float3(0.937, 0.894, 0.839);
    // The page under the lens: Coal, with the ash of the type catching in bands.
    float band = smoothstep(0.35, 0.5, fract(r.y * 2.4 + 0.2)) * smoothstep(0.85, 0.7, fract(r.y * 2.4 + 0.2));
    float3 page = mix(coal, ash, 0.35 * band * smoothstep(-0.1, -0.6, e));
    page = mix(dark, page, smoothstep(-0.015, -0.16, e));
    return e > 0 ? sky : page;
}

// The crescent: ember deepening toward the tips, daylight on the limb.
static float4 crescent(float3 po, float3 no) {
    if (po.z <= 0.0 || no.z < 0.2) return float4(0);
    float c = cos(TILT), s = sin(TILT);
    float u = po.x * c - po.y * s;
    float v = po.x * s + po.y * c;
    float r = length(po.xy);
    float edge = u - TERM * sqrt(max(0.0, 1.0 - v * v));
    float cover = smoothstep(0.0, 0.025, edge) * (1.0 - smoothstep(0.9, 0.93, r));
    if (cover <= 0.0) return float4(0);
    float d = length(float2(u, v) - float2(0.92, 0.0)) / 1.6;
    float3 hot = float3(1.0, 0.886, 0.737), ember = float3(0.8, 0.392, 0.216), deep = float3(0.478, 0.165, 0.07);
    float3 col = d < 0.55 ? mix(hot, ember, d / 0.55) : mix(ember, deep, (d - 0.55) / 0.45);
    return float4(col, cover);
}

[[ stitchable ]] half4 emberLens(float2 position, half4 color, float2 center, float radius,
                                  float height, float3 row0, float3 row1, float3 row2) {
    // Rows of object → world, taken as columns: world → object, as in Kron.
    float3x3 m = float3x3(row0, row1, row2);
    float r0 = radius;
    float rr = r0 * (1.0 + 0.1 * (height - 1.0));
    float2 q = (position - center) / rr;
    q.y = -q.y;
    float4 obj = float4(0);
    if (dot(q, q) < 1.21) {
        float3 ro = float3(0, 0, 5), rd = normalize(float3(q, -5));
        float b = dot(ro, rd), h = b * b - (25.0 - 1.21);
        if (h > 0.0) {
            h = sqrt(h);
            float t = -b - h, t1 = -b + h, md = 1e3, mt = t;
            bool hit = false;
            for (int i = 0; i < 96; i++) {
                float d = mapW(ro + rd * t, m);
                if (d < md) { md = d; mt = t; }
                if (d < 0.0012) { hit = true; break; }
                t += max(d, 0.0024);
                if (t > t1) break;
            }
            float cov = hit ? 1.0 : 1.0 - smoothstep(0.0, 1.7 / rr, md);
            if (cov > 0.0) {
                if (!hit) t = mt;
                float3 p = ro + rd * t;
                float3 n = normalW(p, m), r = reflect(rd, n);
                float3 col = env(r);
                col = mix(col, float3(1.0), 0.07 * pow(1.0 - max(dot(n, -rd), 0.0), 4.0));
                col *= float3(0.985, 0.972, 0.955);
                // Smoked chrome, as on the site: the mark is a dark disc, so the body keeps only its hottest highlights.
                col = col * float3(0.30, 0.27, 0.25) + pow(col, float3(4.0)) * 0.7;
                float4 cr = crescent(m * p, m * n);
                if (cr.a > 0.0) {
                    float lit = 0.55 + 0.45 * max(dot(n, normalize(float3(-0.3, 0.5, 0.8))), 0.0);
                    float3 enamel = cr.rgb * lit + col * 0.16 + cr.rgb * 0.12;
                    col = mix(col, enamel, cr.a);
                }
                obj = float4(col, 1.0) * cov;
            }
        }
    }
    // Shadow: tight and dark when low, wide, soft and further down-right when it lifts.
    float lift = clamp((height - 0.8) / 1.7, 0.0, 1.0);
    float2 sc = center + float2(height * 0.3, height * 0.4) * r0;
    float sd = length((position - sc) / (r0 * (1.0 + 0.35 * lift)));
    float soft = mix(0.18, 0.75, lift);
    float sh = (1.0 - smoothstep(1.0 - soft, 1.0 + soft, sd)) * (0.7 - 0.3 * lift);
    sh += 0.3 * (1.0 - lift) * (1.0 - lift) * (1.0 - smoothstep(0.0, 1.2, length((position - center) / r0)));
    float sa = clamp(sh, 0.0, 0.86) * (1.0 - obj.a);
    float3 burnt = float3(0.035, 0.016, 0.008);
    return half4(half3(obj.rgb + burnt * sa), half(obj.a + sa));
}
