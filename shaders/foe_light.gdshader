shader_type canvas_item;
// A foe stands in its room's light (design bible 12.43): its colour is muted a
// little and its darks sink toward the zone's haze, the colour the room's own
// shadows recede into. Lights keep their value, so the foe still reads.
// One colour of its own is left out of that and lifted: its accent (12.69).
// FoeLight.lit is the same sum in GDScript, for the tests.

uniform vec3 haze = vec3(0.17, 0.15, 0.25);
uniform float mute : hint_range(0.0, 1.0) = 0.2;
uniform float sink : hint_range(0.0, 1.0) = 0.55;
// The accent: x its hue in degrees, y the band's half width in degrees, z the
// least saturation and w the least value a pixel needs to count. y of 0: none.
uniform vec4 accent = vec4(0.0);
// How far an accent pixel's saturation (x) and value (y) rise toward 1.
uniform vec2 lift = vec2(0.0);
// The falloffs past the band's edge (degrees) and over the two floors.
uniform float band_soft = 12.0;
uniform float floor_soft = 0.12;

vec3 to_hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
	}
	return vec3(h * 60.0, mx > 0.00001 ? d / mx : 0.0, mx);
}

vec3 from_hsv(vec3 hsv) {
	vec3 k = mod(vec3(5.0, 3.0, 1.0) + hsv.x / 60.0, 6.0);
	return hsv.z - hsv.z * hsv.y * clamp(min(k, 4.0 - k), 0.0, 1.0);
}

void fragment() {
	vec3 painted = COLOR.rgb;
	float g = dot(painted, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(painted, vec3(g), mute);
	float w = sink * (1.0 - g) * (1.0 - g);
	c = mix(c, haze, w);
	if (accent.y > 0.0) {
		vec3 hsv = to_hsv(painted);
		float d = abs(mod(hsv.x - accent.x + 180.0, 360.0) - 180.0);
		float a = (1.0 - smoothstep(accent.y, accent.y + band_soft, d))
			* smoothstep(accent.z, accent.z + floor_soft, hsv.y)
			* smoothstep(accent.w, accent.w + floor_soft, hsv.z);
		vec3 lifted = from_hsv(vec3(hsv.x, hsv.y + (1.0 - hsv.y) * lift.x, hsv.z + (1.0 - hsv.z) * lift.y));
		c = mix(c, lifted, a);
	}
	COLOR = vec4(c, COLOR.a);
}
