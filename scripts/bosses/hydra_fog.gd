class_name HydraFog
extends Node2D
## The Haar Wyrm's silent whisper (design bible 8.4): after a long wind-up one head
## breathes out a wave of superheated, nearly invisible vapour that fills the
## whole arena. The air itself shimmers and burns. There is one shelter: stand in
## the cistern's water (a third or more), which the heat cannot reach. The heat
## boils a third of that water away as it passes.
##
## It is a channel (Sean, 2026-11-19): the head holds its jaws wide on the core pulsing
## in its throat for as long as this lasts, and the heat comes off that core. Rings of
## it radiate from the jaws (`source`), and the whole arena wavers behind a heat haze: a
## rising noise map pushes each pixel of the screen aside (after SFML's heat haze shader,
## github.com/SFML/SFML/wiki/Source:-HeatHazeShader), in whole pixels so the art stays
## pixel art, with the same rings running through it. The water is left clear.
##
## The cistern is sunk under the arena's floor (Sean, 2026-11-20), so the fog fills its
## pit as well, down to the water: a dry pit wavers like the rest of the arena.

## What its blow is made of (design bible 5.6).
const DAMAGE_KIND := DamageKind.FIRE
const FILL := 0.6
const BURN := 2.4
const FADE := 1.0
const TICK := 0.4
const DAMAGE := 6
const HAZE := Color("fff1dc")
const HAZE_HOT := Color("ffd9a0")
const SHIMMER := Color("ffffff")
## The rings of heat off the jaws: how many are in the air at once, how far one travels
## before it is gone (world px), and how long that takes.
const RINGS := 5
const RING_REACH := 460.0
const RING_TIME := 1.6
## The haze: how far it pushes a pixel aside at its thickest (world px).
const HAZE_PUSH := 2.6
const RING_PUSH := 2.2

const HAZE_SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D map : repeat_enable, filter_linear;
// How thick the heat is, 0 to 1, and the seconds it has burned.
uniform float strength = 0.0;
uniform float time = 0.0;
// This rect's size in world pixels, and one world pixel in screen UV.
uniform vec2 size = vec2(928.0, 256.0);
uniform vec2 world_px = vec2(0.0015625, 0.0027778);
// The jaws the heat comes off, and the water it can't reach, in this rect's pixels.
uniform vec2 source = vec2(464.0, 40.0);
uniform vec4 clear = vec4(0.0);
// How far down this rect the arena's floor is, and the cistern's pit under it: below
// the floor there is air only in the pit.
uniform float floor_at = 100000.0;
uniform vec4 pit = vec4(0.0);
uniform float haze_push = 2.6;
uniform float ring_push = 2.2;
uniform float ring_reach = 460.0;
uniform float ring_time = 1.6;
uniform float rings = 5.0;
void fragment() {
	vec2 at = UV * size;
	// The haze: a noise map rising through the air pushes each pixel aside.
	vec2 m = texture(map, vec2(at.x / 256.0, at.y / 256.0 + time * 0.45)).rg - vec2(0.5);
	vec2 push = m * 2.0 * haze_push;
	// The rings: each a swell that runs out from the jaws and fades.
	vec2 away = at - source;
	float far = length(away);
	float phase = fract(far / (ring_reach / rings) - time / (ring_time / rings) * 1.0);
	float swell = sin(phase * 6.2831853) * (1.0 - smoothstep(0.0, ring_reach, far));
	push += normalize(away + vec2(0.0001)) * swell * ring_push;
	push *= strength;
	// The water is clear: the heat can't reach into it.
	if (clear.z > 0.0 && at.x >= clear.x && at.x <= clear.x + clear.z && at.y >= clear.y && at.y <= clear.y + clear.w) {
		push = vec2(0.0);
	}
	// Under the floor the fog is only in the pit: the stone round it stays still.
	if (at.y > floor_at && !(at.x >= pit.x && at.x <= pit.x + pit.z && at.y <= pit.y + pit.w)) {
		push = vec2(0.0);
	}
	// Whole pixels: the screen behind stays pixel art.
	push = floor(push + vec2(0.5));
	COLOR = texture(screen_tex, SCREEN_UV + push * world_px);
}"

## The arena it fills (world px) and the cistern that shelters.
var bounds := Rect2(16, 64, 928, 256)
var cistern: HydraCistern
## Where the heat comes off: the jaws of the head that breathes it, in the world. A
## callable, since the head moves. Unset, the middle of the arena's roof.
var source := Callable()
## The heat haze over the arena (see HAZE_SHADER).
var haze: ColorRect

var _time := 0.0
var _tick := 0.0
var _boiled := false


func _ready() -> void:
	z_index = 4
	add_to_group("hydra_fog")
	haze = ColorRect.new()
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = HAZE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# The map that rises through the air: seamless, so it can scroll for ever.
	var noise := FastNoiseLite.new()
	noise.seed = 8
	noise.frequency = 0.03
	var map := NoiseTexture2D.new()
	map.width = 128
	map.height = 128
	map.seamless = true
	map.as_normal_map = true
	map.noise = noise
	mat.set_shader_parameter("map", map)
	mat.set_shader_parameter("haze_push", HAZE_PUSH)
	mat.set_shader_parameter("ring_push", RING_PUSH)
	mat.set_shader_parameter("ring_reach", RING_REACH)
	mat.set_shader_parameter("ring_time", RING_TIME)
	mat.set_shader_parameter("rings", float(RINGS))
	haze.material = mat
	add_child(haze)
	_lay_haze()


## 0 clear .. 1 thick.
func thickness() -> float:
	if _time < FILL:
		return _time / FILL
	if _time < FILL + BURN:
		return 1.0
	return clampf(1.0 - (_time - FILL - BURN) / FADE, 0.0, 1.0)


## True while the fog burns whoever it reaches.
func burning() -> bool:
	return _time >= FILL * 0.5 and _time < FILL + BURN


## Where the heat comes off, in the world.
func source_point() -> Vector2:
	if source.is_valid():
		return source.call()
	return Vector2(bounds.get_center().x, bounds.position.y + 40.0)


## The rings of heat in the air: [radius in world px, strength 0 to 1] for each, the
## nearest first. One leaves the jaws every RING_TIME / RINGS and fades as it travels.
func rings() -> Array:
	var out := []
	var k := thickness()
	if k <= 0.0:
		return out
	var every := RING_TIME / RINGS
	for i in RINGS:
		var age := fmod(_time, every) + i * every
		# A ring that would have left before the breath began, or after it ended, was
		# never breathed.
		if age > _time or _time - age > FILL + BURN:
			continue
		var far := age / RING_TIME
		out.append([far * RING_REACH, (1.0 - far) * k])
	return out


## The water the heat can't reach, in the world (no size when the cistern is dry).
func clear_rect() -> Rect2:
	if cistern == null or cistern.level <= 0:
		return Rect2()
	var top := cistern.surface_y()
	return Rect2(cistern.inside.position.x, top, cistern.inside.size.x, cistern.inside.end.y - top)


## The cistern's pit, sunk under the arena's floor (no size with no cistern).
func pit() -> Rect2:
	return cistern.inside if cistern != null else Rect2()


## Everywhere the fog is: the arena, and the pit under its floor.
func reach() -> Rect2:
	var hole := pit()
	return bounds.merge(hole) if hole.size.x > 0.0 else bounds


func _lay_haze() -> void:
	if haze == null:
		return
	var all := reach()
	haze.position = to_local(all.position)
	haze.size = all.size
	var mat := haze.material as ShaderMaterial
	mat.set_shader_parameter("strength", thickness())
	mat.set_shader_parameter("time", _time)
	mat.set_shader_parameter("size", all.size)
	mat.set_shader_parameter("source", source_point() - all.position)
	var clear := clear_rect()
	mat.set_shader_parameter("clear", Vector4(clear.position.x - all.position.x, clear.position.y - all.position.y, clear.size.x, clear.size.y))
	var hole := pit()
	mat.set_shader_parameter("floor_at", bounds.end.y - all.position.y)
	mat.set_shader_parameter("pit", Vector4(hole.position.x - all.position.x, hole.position.y - all.position.y, hole.size.x, hole.size.y))
	if is_inside_tree():
		var view := get_viewport().get_visible_rect().size
		if view.x > 0.0 and view.y > 0.0:
			mat.set_shader_parameter("world_px", Vector2(1.0 / view.x, 1.0 / view.y))
	haze.visible = thickness() > 0.0


func _physics_process(delta: float) -> void:
	if TimeStop.active():
		return  # held still by the Stillstone
	_time += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if burning() and p != null and not p.dead:
		var safe := cistern != null and cistern.shelters(p)
		_tick -= delta
		if _tick <= 0.0 and not safe:
			_tick = TICK
			p.take_damage(DAMAGE, false, 0, DAMAGE_KIND)
			Sfx.play("steam_hiss", 0.15, -10.0)
	if not _boiled and _time >= FILL + BURN:
		_boiled = true
		if cistern != null:
			cistern.lose_third()
	if _time >= FILL + BURN + FADE:
		queue_free()
	_lay_haze()
	queue_redraw()


func _draw() -> void:
	var k := thickness()
	if k <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	# A thin warm veil over everything, except the water, which stays clear.
	# It lies over the arena, and in the cistern's pit under the floor.
	var clear := clear_rect()
	var band := 8.0
	var areas: Array[Rect2] = [bounds]
	if pit().size.x > 0.0:
		areas.append(pit())
	for area in areas:
		var y := area.position.y
		while y < area.end.y:
			var wob := sin(t * 2.0 + y * 0.05) * 0.04
			var heat := clampf((bounds.end.y - y) / bounds.size.y, 0.0, 1.0) * 0.5
			var col := Color(HAZE.lerp(HAZE_HOT, heat), (0.3 + wob) * k)
			var r := Rect2(area.position.x, y, area.size.x, minf(band, area.end.y - y))
			if clear.size.x > 0.0 and r.intersects(clear):
				# Beside the water, and above its surface where that cuts the band.
				draw_rect(Rect2(r.position.x, y, maxf(clear.position.x - r.position.x, 0.0), r.size.y), col)
				draw_rect(Rect2(clear.end.x, y, maxf(r.end.x - clear.end.x, 0.0), r.size.y), col)
				if clear.position.y > y:
					draw_rect(Rect2(maxf(clear.position.x, r.position.x), y, minf(clear.end.x, r.end.x) - maxf(clear.position.x, r.position.x), clear.position.y - y), col)
			else:
				draw_rect(r, col)
			y += band
	# The rings of heat off the jaws: a faint front with a warm wake behind it. They are
	# kept faint, since the haze bends the screen along the same rings: drawn any
	# stronger they read as circles ruled on the picture, not as heat.
	var from := to_local(source_point())
	for ring: Array in rings():
		var radius: float = ring[0]
		var a: float = ring[1]
		if radius < 6.0:
			continue
		var points := clampi(int(radius * 0.5), 24, 96)
		draw_arc(from, radius, 0.0, TAU, points, Color(SHIMMER, 0.13 * a), 1.0)
		draw_arc(from, maxf(radius - 4.0, 1.0), 0.0, TAU, points, Color(HAZE_HOT, 0.1 * a), 4.0)
	# Heat shimmer: faint wavering lines rising through the air, with a few
	# bright threads tracing the current.
	for i in 22:
		var ph := fmod(t * 0.35 + i * 0.0457, 1.0)
		var lx := bounds.position.x + fmod(i * 97.0, bounds.size.x)
		var ly := bounds.end.y - ph * bounds.size.y
		var pts := PackedVector2Array()
		for j in 6:
			pts.append(Vector2(lx + j * 6.0, ly + sin(t * 5.0 + j + i) * 2.0))
		draw_polyline(pts, Color(SHIMMER, 0.4 * k * (1.0 - ph)), 1.0)
		if i % 5 == 0:
			draw_rect(Rect2(lx + 12.0, ly, 2, 1), Color(HAZE_HOT, 0.6 * k))
