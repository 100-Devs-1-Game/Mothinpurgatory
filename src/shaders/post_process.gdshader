shader_type canvas_item;

uniform float shadow_strength  : hint_range(0.0, 1.0) = 0.7;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float shadow_softness  : hint_range(0.001, 1.0) = 0.25;

uniform float bloom_threshold : hint_range(0.0, 2.0) = 1.0;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float bloom_spread    : hint_range(0.5, 4.0) = 2.0;
uniform bool  bloom_after_shadows = true;

uniform bool  protect_enable = true;
uniform float protect_strength : hint_range(0.0, 1.0) = 1.0;

uniform float protect_hue1        : hint_range(0.0, 1.0) = 0.08;
uniform float protect_hue_width1  : hint_range(0.0, 0.5) = 0.10;
uniform float protect_min_sat1    : hint_range(0.0, 1.0) = 0.50;
uniform float protect_min_val1    : hint_range(0.0, 1.0) = 0.35;

uniform float protect_hue2        : hint_range(0.0, 1.0) = 0.98;
uniform float protect_hue_width2  : hint_range(0.0, 0.5) = 0.06;
uniform float protect_min_sat2    : hint_range(0.0, 1.0) = 0.50;
uniform float protect_min_val2    : hint_range(0.0, 1.0) = 0.30;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float luma(vec3 c){ return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 rgb2hsv(vec3 c){
    vec4 K = vec4(0., -1./3., 2./3., -1.);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.*d + e)), d / (q.x + e), q.x);
}

float hue_dist(float a, float b){
    float d = abs(a - b);
    return min(d, 1.0 - d);
}

vec3 sample_col(vec2 uv){ return texture(SCREEN_TEXTURE, uv).rgb; }

float protected_mask(vec3 col){
    if (!protect_enable) return 0.0;
    vec3 hsv = rgb2hsv(clamp(col, 0.0, 1.0));

    float d1 = hue_dist(hsv.x, protect_hue1);
    float in_h1 = 1.0 - smoothstep(protect_hue_width1, protect_hue_width1 * 1.1, d1);
    float s1 = step(protect_min_sat1, hsv.y);
    float v1 = step(protect_min_val1, hsv.z);
    float m1 = in_h1 * s1 * v1;

    float d2 = hue_dist(hsv.x, protect_hue2);
    float in_h2 = 1.0 - smoothstep(protect_hue_width2, protect_hue_width2 * 1.1, d2);
    float s2 = step(protect_min_sat2, hsv.y);
    float v2 = step(protect_min_val2, hsv.z);
    float m2 = in_h2 * s2 * v2;

    return clamp(max(m1, m2), 0.0, 1.0);
}

void fragment(){
    vec2 uv = SCREEN_UV;
    vec3 base = sample_col(uv);

    float Y = luma(base);
    float factor = smoothstep(shadow_threshold + shadow_softness,
                              shadow_threshold - shadow_softness, Y);

    float prot = protected_mask(base) * protect_strength;
    float effective = factor * (1.0 - prot);

    vec3 shadowed = base * mix(1.0, shadow_strength, effective);

    vec3 bloom_src = bloom_after_shadows ? shadowed : base;

    vec3 bright = max(bloom_src - vec3(bloom_threshold), vec3(0.0))
                  / max(1e-4, (2.0 - bloom_threshold));

    vec2 px = SCREEN_PIXEL_SIZE * bloom_spread;
    vec3 b = bright * 0.2;
    b += sample_col(uv + vec2( px.x, 0.0)) * 0.1;
    b += sample_col(uv + vec2(-px.x, 0.0)) * 0.1;
    b += sample_col(uv + vec2(0.0,  px.y)) * 0.1;
    b += sample_col(uv + vec2(0.0, -px.y)) * 0.1;
    b += sample_col(uv + vec2( px.x,  px.y)) * 0.1;
    b += sample_col(uv + vec2(-px.x,  px.y)) * 0.1;
    b += sample_col(uv + vec2( px.x, -px.y)) * 0.1;
    b += sample_col(uv + vec2(-px.x, -px.y)) * 0.1;

    vec3 col = shadowed + b * bloom_intensity;
    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
