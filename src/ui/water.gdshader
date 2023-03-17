shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D noise;
uniform sampler2D wave1 : hint_default_white;
uniform sampler2D highlight_noise;
uniform sampler2D submerged_floor;

void fragment() {
	vec2 noise_offset = mod(vec2(TIME/16.0), 1.0);
	float noise_val = texture(noise, mod(SCREEN_UV+noise_offset, 1.0)).r;
	vec2 offset = vec2(1.0, 1.0) * noise_val * 0.02;
	vec2 floor_uv = mod(2.2*(UV+offset), 1.0);	

	COLOR = texture(submerged_floor, floor_uv);

	// DEBUG:
	// COLOR.rgb = vec3(noise_val);

	// blue tint
	COLOR.b *= 1.4;
	COLOR.rg *= 0.6;
	
	// Wave highlights	
	COLOR.rgb +=  min(0.5, (sin(TIME / 2.0) + 1.1)) * texture(wave1,vec2(SCREEN_UV.x + mix(0, sin(TIME), 0.01) / 2.0 + sin(offset.y * TIME * 0.1) * 0.002, SCREEN_UV.y+0.2 +noise_val / 64.0  + sin(offset.x * TIME*0.03) * 0.0016)).rgb;

	COLOR.b *= 1.4;
}

