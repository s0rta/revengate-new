shader_type canvas_item;

uniform float min_alpha: hint_range(0.0, 1.0) = 0.0;
uniform float max_alpha: hint_range(0.0, 1.0) = 1.0;
uniform float speed: hint_range(0.0, 10.0) = 2.5;

void fragment() {
	float range = max_alpha - min_alpha;
	float new_alpha = min_alpha + range * (sin(TIME*speed)/2.0+0.5);
	COLOR.a *= new_alpha;
}
