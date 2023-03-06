shader_type canvas_item;

mat2 rotate2d(float _angle){
    return mat2(vec2(cos(_angle), -sin(_angle)), 
			vec2(sin(_angle), cos(_angle)));
}

void vertex() {
	float scale = sin(TIME*3.0)/5.0+1.0;
	VERTEX *= rotate2d(TIME) * scale;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float intensity = sin(TIME) / 4.0 + 0.5;
	COLOR.a = col.a * intensity;
}
