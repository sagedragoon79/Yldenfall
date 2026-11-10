shader_type canvas_item;
// The foreground silhouette layer (design bible 12.11, 12.26): wherever a
// silhouette passes in front of an actor (the hero, a townsperson, a foe), it
// thins to a ghost so nothing important sits behind a near-black post. Backdrop
// feeds the actors' boxes each frame as `holes`: (centre u, centre v, half width,
// half height), the centre in the art's UV and the half sizes in world pixels.
// The layer repeats sideways every `size.x`, so the hole's distance wraps in u.
// The maths mirror Backdrop.reveal_mask() exactly, which the tests drive.

const int MAX_HOLES = 16;

uniform vec4 holes[MAX_HOLES];
uniform int hole_count = 0;
// The art's extent in world pixels (Backdrop.SIZE).
uniform vec2 size = vec2(640.0, 480.0);
// How much of a silhouette is left in front of an actor.
uniform float keep : hint_range(0.0, 1.0) = 0.2;
// The soft edge around each box, in world pixels.
uniform float soft = 8.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float m = 0.0;
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 h = holes[i];
		float du = abs(fract(UV.x - h.x + 0.5) - 0.5) * size.x;
		float dv = abs(UV.y - h.y) * size.y;
		vec2 out_d = max(vec2(du, dv) - h.zw, vec2(0.0));
		m = max(m, 1.0 - smoothstep(0.0, soft, length(out_d)));
	}
	COLOR = vec4(col.rgb, col.a * mix(1.0, keep, m));
}
