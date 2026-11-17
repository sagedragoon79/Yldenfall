shader_type canvas_item;
// A foe's hurt flash and attack tell (design bible 7): everything it draws is
// washed toward white, so the flash follows its own silhouette. A tell washes
// toward its own tint (Enemy.TELL_TINT), and less, so the pose reads through it.

uniform float amount : hint_range(0.0, 1.0) = 0.72;
uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	COLOR = vec4(mix(COLOR.rgb, tint, amount), COLOR.a);
}
