shader_type canvas_item;
render_mode blend_mul;

uniform float strength = 0.9; // 0..0.4
uniform float density = 480.0; // more = thinner lines

void fragment() {
	// 0..1
	float scan = 0.5 + 0.5 * sin(UV.y * density * 3.14159265);

	// "dark" is the multiplier applied to what's behind
	// when scan is low -> darker line; when high -> brighter line
	float dark = 1.0 - strength * (1.0 - scan);

	dark *= 0.98 + 0.02 * (0.5 + 0.5 * sin(TIME * 60.0));
	
	COLOR = vec4(dark, dark, dark, 1.0);
}
