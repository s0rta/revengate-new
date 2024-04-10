shader_type canvas_item;

const float time_scale = 10.0;  // things should move fairly fast

uniform sampler2D screen_texture: hint_screen_texture;

uniform float time;
uniform float start_time;
uniform float duration = 2.6;

float runaway(float val){
	// Return a value that increases faster and faster as val increases
	return 2.3*pow(1.19, val);
}

mat2 rotate2d(float angle){
    return mat2(vec2(cos(angle), -sin(angle)), 
			vec2(sin(angle), cos(angle)));
}

void fragment() {
	float effect_time = time - start_time;
	float fast_time = effect_time * time_scale;
	
	// We only look at the alpha channel of our combined sprites to determine 
	// the intentity of the pixel shift and the hue glow.
	float intensity = clamp(texture(TEXTURE, UV).a - effect_time/duration, 0.0, 1.0);
	vec2 offset = intensity * vec2(0.015) * rotate2d(runaway(fast_time));
	vec4 color = texture(screen_texture, SCREEN_UV + offset);	
	COLOR.rgb = clamp(color.rgb + COLOR.rgb*intensity, vec3(0.0), vec3(1.0));
}
