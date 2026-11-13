shader_type canvas_item;
// The Mist's fog (design bible 3.2): a grey-green murk over the room with clear
// pockets around the player and every light. Fog.visibility_at mirrors the
// falloff on the CPU, so keep the two in step.
//
// Pass 549 (bible 12.40): the grades called the pockets "perfect blue circles"
// in "hard concentric rings". Each pocket's rim now wavers with a slow noise of
// its own (POCKET_WAVER of the radius, never at the centre, which the CPU
// mirror keeps), and the clearing steps between four levels through a 4 x 4
// ordered dither in 2-pixel blocks rather than snapping to rings.

const int MAX_LIGHTS = 48;

uniform vec4 fog_color : source_color = vec4(0.47, 0.53, 0.48, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.09, 0.09, 1.0);
uniform float density = 0.82;
// 1 while the Haar Wyrm lives: the fog is his steam, warm and rising (bible
// 3.2). 0 once the Haar Spring runs: a thin cool mist that drifts sideways.
uniform float steam = 0.0;
uniform vec4 warm_color : source_color = vec4(0.66, 0.60, 0.50, 1.0);
uniform int light_count = 0;
// x, y in world pixels; z is the clear radius.
uniform vec3 lights[MAX_LIGHTS];

// Tileable random lattice (Fog.drift_texture); sampled with linear filtering it
// is value noise for a texture fetch, far cheaper than hashing per fragment.
uniform sampler2D drift_tex : repeat_enable, filter_linear;

// World position of the fog texture's top-left pixel: the fog is drawn one
// texel per world pixel in its own small viewport (see Fog) and scaled up.
uniform vec2 origin = vec2(0.0);

varying vec2 world_pos;

// How far a pocket's rim wavers in and out, as a fraction of its radius.
const float POCKET_WAVER = 0.18;
// The 4 x 4 ordered dither, 0 to 15.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_pos = origin + VERTEX;
}

void fragment() {
	// Snap to world pixels so the fog stays pixel art.
	vec2 p = floor(world_pos);
	float clear = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec2 dv = p - lights[i].xy;
		float r = lights[i].z;
		float d2 = dot(dv, dv);
		// Most lights are far from most fragments: skip the sqrt and smoothstep.
		if (d2 < r * r) {
			// The rim wavers: noise read along the pocket's own direction from
			// its light (and seeded by where the light is), drifting slowly.
			float d = sqrt(d2);
			vec2 dir = dv / max(d, 1.0);
			float w = texture(drift_tex, (dir * 3.0 + lights[i].xy * 0.071 + vec2(TIME * 0.05, 0.0)) / 64.0).r;
			float rr = r * (1.0 - POCKET_WAVER * w);
			clear = max(clear, 1.0 - smoothstep(rr * 0.45, rr, d));
		}
	}
	// Four steps, dithered between in 2-pixel blocks, never a smooth gradient
	// and never hard rings.
	ivec2 cell = ivec2(mod(floor(p / 2.0), 4.0));
	float thresh = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
	clear = floor(clear * 3.0 + thresh) / 3.0;
	// Steam climbs (the pattern scrolls up); a cooled mist slides sideways.
	vec2 slow = mix(vec2(TIME * 0.15, TIME * 0.05), vec2(TIME * 0.03, TIME * 0.24), steam);
	vec2 fast = mix(vec2(-TIME * 0.3, 0.0), vec2(TIME * 0.05, TIME * 0.5), steam);
	float drift = texture(drift_tex, (p / 40.0 + slow) / 64.0).r * 0.6
		+ texture(drift_tex, (p / 13.0 + fast) / 64.0).r * 0.4;
	// Rising wisps: tall thin threads of paler steam, stepped through the same
	// dither so they stay pixel art.
	float wisp = texture(drift_tex, (vec2(p.x / 7.0, p.y / 44.0 + TIME * 0.55)) / 64.0).r;
	wisp = floor(smoothstep(0.58, 0.9, wisp) * 2.0 + thresh) / 2.0 * steam;
	float thick = density * (1.0 - clear) * (0.85 + 0.15 * drift);
	vec3 col = mix(fog_color.rgb, deep_color.rgb, 0.55 + 0.25 * drift);
	col = mix(col, warm_color.rgb, 0.16 * steam + 0.3 * wisp);
	COLOR = vec4(col, thick);
}
