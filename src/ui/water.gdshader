shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D noise;
uniform sampler2D submerged_floor;

void fragment() {
	vec2 noise_offset = mod(vec2(TIME/8.0), 1.0);
	float noise_val = texture(noise, mod(SCREEN_UV+noise_offset, 1.0)).r;
	vec2 offset = vec2(1.0, 1.0) * noise_val * 0.02;
	vec2 floor_uv = mod(2.2*(UV+offset), 1.0);	
	COLOR = texture(submerged_floor, floor_uv);

	// DEBUG:
//	COLOR.rgb = vec3(noise_val);

	// blue tint
	COLOR.b *= 1.4;
	COLOR.rg *= 0.7;
}
