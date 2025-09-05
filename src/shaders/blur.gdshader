shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float blur_amount : hint_range(0.0, 10.0) = 2.0; // max blur at the edge
uniform float mix_amount  : hint_range(0.0, 1.0) = 0.0;  // tint with color_over
uniform vec4  color_over  : source_color = vec4(0.0);

uniform bool  invert = false;     // false = fade downward (top strip), true = fade upward (bottom strip)
uniform float fade_start = 0.0;   // where the fade begins within the rect (0..1 from the edge)
uniform float fade_end   = 1.0;   // where blur is fully gone (0..1 at the inner edge)
uniform float falloff    = 1.0;   // >1 = tighter near the edge, <1 = softer

void fragment() {
	// 0..1 along the strip from the chosen edge
	float pos = UV.y;
	if (invert) pos = 1.0 - pos;

	// Mask is 1.0 at the edge, smoothly down to 0.0 by fade_end
	float m = 1.0 - smoothstep(fade_start, fade_end, pos);
	m = pow(m, max(falloff, 1e-5)); // shape the curve

	// Blur strength also fades out so there’s no harsh boundary
	float lod = clamp(blur_amount * m, 0.0, 10.0);
	vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, lod);

	// Optional tint
	vec4 fin = mix(blurred, color_over, mix_amount);

	// Alpha fades out with the blur, making the transition seamless
	fin.a = m;
	COLOR = fin;
}
