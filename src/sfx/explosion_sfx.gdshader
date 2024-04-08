shader_type canvas_item;

const float time_scale = 10.0;  // things should move fairly fast during an explosion

uniform sampler2D screen_texture: hint_screen_texture;
uniform float time;
uniform float start_time;
uniform float fadout_delay = 0.2;
uniform float fade_slope = 8.0;
uniform float blast_radius: hint_range(0.0, 0.5) = 0.5;

void fragment() {
	float effect_time = (time - start_time) * time_scale;
	float delay = fadout_delay * time_scale;

	// distance from the center of effect
	float dist = distance(UV, vec2(0.5));
	float wave_front = clamp(-fade_slope * dist + effect_time, 0.0, 1.0);
	float wave_back = clamp(-fade_slope * dist + effect_time-delay, 0.0, 1.0);

	// fast ripples with a few periods inside the effect radius
	float wave = cos(PI * 6.0 * dist - time * 12.0);
	float refraction_size = 0.01 * wave;
	vec2 offset = normalize(UV - vec2(0.5)) * refraction_size;
	vec4 color = texture(screen_texture, SCREEN_UV + offset);
	COLOR.rgb = color.rgb;

	// How much of the effect is visible? Progressive fadeout that ends at blast_radius
	float effect_mask = clamp((dist - blast_radius) * -fade_slope, 0.0, 1.0);
	COLOR.a = min(effect_mask, wave_front-wave_back);
}
