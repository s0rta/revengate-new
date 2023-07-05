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
	// vec2 refelction_uv = vec2(-0.2, -0.2) + SCREEN_UV;

	COLOR = texture(submerged_floor, floor_uv);
	// COLOR = texture(screen_texture, refelction_uv);

	// DEBUG:
	 //COLOR.r = offset.x * 10.0;
	 //COLOR.g = offset.y * 10.0;

	// blue tint
	COLOR.b *= 1.4;
	COLOR.rg *= 0.6;
	
	// Wave highlights	
	float mixFactor = sin(TIME) / 100.0;
	float highlightAlpha = (sin(TIME / 2.0) / 4.0) + 0.42;
	
	vec2 highlightVector = vec2(SCREEN_UV.x + mixFactor / 2.0 + sin(offset.y * TIME * 0.1) * 0.002, SCREEN_UV.y+0.2 +noise_val / 64.0  + sin(offset.x * TIME*0.03) * 0.0016);

	COLOR.rgb += highlightAlpha * texture(wave1, mod(highlightVector, 1.0)).rgb;

	COLOR.b *= 1.4;
	COLOR = clamp(COLOR, vec4(0.0), vec4(1.0));
}

