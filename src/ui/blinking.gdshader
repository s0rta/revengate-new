shader_type canvas_item;

void fragment() {
	COLOR.a = min(COLOR.a, sin(TIME*2.5)/2.0+0.5);
}
