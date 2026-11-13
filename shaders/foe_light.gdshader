shader_type canvas_item;
// A foe stands in its room's light (design bible 12.43): its colour is muted a
// little and its darks sink toward the zone's haze, the colour the room's own
// shadows recede into. Lights keep their value, so the foe still reads.
// FoeLight.lit is the same sum in GDScript, for the tests.

uniform vec3 haze = vec3(0.17, 0.15, 0.25);
uniform float mute : hint_range(0.0, 1.0) = 0.2;
uniform float sink : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 c = COLOR.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), mute);
	float w = sink * (1.0 - g) * (1.0 - g);
	COLOR = vec4(mix(c, haze, w), COLOR.a);
}
