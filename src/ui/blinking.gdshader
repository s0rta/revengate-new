shader_type canvas_item;

const float min_alpha = 0.25;
const float max_alpha = 1.0;
const float speed = 2.5;

void fragment() {
	float range = max_alpha - min_alpha;
	float new_alpha = min_alpha + range * (sin(TIME*speed)/2.0+0.5);
	COLOR.a *= new_alpha;
}
