class_name SpringEel
extends Enemy
## A Spring Eel of the Sunken Spring (design bible 7): a long pale eel gone
## blind in the dark water, with a lamp of the spring's light grown at the tip
## of a lure that arches from its brow over its snout. It never leaves the water. It weaves back and forth near where it
## lives; come within about seven tiles and it draws back into an S, its lamp
## blazing, for 0.5 s (the telegraph), then darts straight at where you were
## and bites for 14. The dart stops dead at the water's edge, so the bank is
## safe. Spent, it hangs slack for 0.8 s and takes every blow at half again.
## Legend `l` (a cell of water with the eel in it).

const SWIM := 46.0
const WANDER := 80.0
const SIGHT := 112.0
const COIL := 0.5
const DART := 300.0
const DART_TIME := 0.45
const SLACK := 0.8
const COOLDOWN := 1.0
const BITE := 14
## The sheet's animation for each state (docs/art/enemy-style-guide.md 4).
const ANIMS := {"idle": "swim", "swim": "swim", "coil": "coil", "dart": "dart", "slack": "slack"}
## The orb at the tip of its lure in each animation (world px from its middle, facing right).
const LAMP_AT := {"swim": Vector2(19, 1.5), "coil": Vector2(8.5, -2), "dart": Vector2(19.5, 1), "slack": Vector2(19, 2)}

const LAMP := Color("8af0e8")
const LAMP_CORE := Color("f0fff8")

var water: SwimWater
var _cool := 0.6
var _dir := Vector2.ZERO
var _bit := false
var _died_at := -1.0


func _init() -> void:
	max_hp = 30
	gold_min = 6
	gold_max = 10
	xp = 16
	contact_damage = 8
	body_size = Vector2(26, 10)
	body_centered = true
	uses_gravity = false
	knockback = 120.0
	state = "swim"


func _modify_damage(damage: int, _dir_in: Vector2) -> int:
	return ceili(damage * 1.5) if state == "slack" else damage


## The room's water, found once it exists (the room adds it after the grid).
func _water() -> SwimWater:
	if water == null or not is_instance_valid(water):
		for c in get_parent().get_children():
			if c is SwimWater:
				water = c
	return water


func _in_water(pos: Vector2) -> bool:
	var w := _water()
	return w == null or w.has_point(pos - w.global_position)


## Moves at `v` this frame unless that would carry its head out of the water.
func _steer(v: Vector2, delta: float) -> bool:
	var ahead := global_position + v * delta + v.normalized() * body_size.x * 0.5
	if v != Vector2.ZERO and not _in_water(ahead):
		velocity = Vector2.ZERO
		return false
	velocity = v
	return true


func _think(delta: float) -> void:
	_cool -= delta
	var off := player_offset()
	var near := off.x != INF and off.length() < SIGHT
	match state:
		"swim", "idle":
			if state == "idle":
				set_state("swim")
			var drift := Vector2(facing * SWIM, sin(state_time * 2.4) * 14.0)
			if absf(global_position.x - home.x) > WANDER and signf(global_position.x - home.x) == facing:
				facing = -facing
			if not _steer(drift, delta):
				facing = -facing
			if near and _cool <= 0.0:
				face_player()
				_dir = off.normalized()
				velocity = Vector2.ZERO
				set_state("coil")
				Sfx.play("eel_lunge", 0.1, -10.0)
		"coil":
			# Draws back away from you, lamp blazing.
			_steer(-_dir * 20.0, delta)
			if off.x != INF:
				_dir = _dir.lerp(off.normalized(), minf(1.0, 4.0 * delta)).normalized()
			if state_time >= COIL:
				_bit = false
				set_state("dart")
				Sfx.play("eel_lunge", 0.05)
		"dart":
			if absf(_dir.x) > 0.1:
				facing = int(signf(_dir.x))
			var moving := _steer(_dir * DART, delta)
			if not _bit and hit_player_in_rect(Rect2(center() + _dir * 10.0 - Vector2(10, 8), Vector2(20, 16)), BITE) != "":
				_bit = true
			if state_time >= DART_TIME or not moving:
				set_state("slack")
		"slack":
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if state_time >= SLACK:
				_cool = COOLDOWN
				set_state("swim")


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


## The animation and its time for what it is doing now.
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered():
		return ["stagger", state_time]
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	var a: String = ANIMS.get(state, "swim")
	return [a, state_time if a != "swim" else Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var now := anim_now()
	var a: String = now[0]
	# Coiled or darting, it points along its strike.
	var ang := 0.0
	if a in ["coil", "dart"] and _dir != Vector2.ZERO:
		ang = atan2(_dir.y, absf(_dir.x))
	var white := flashing() or (state == "coil" and telegraph_pulse())
	var f := Sheet.frame_at("spring_eel", a, now[1])
	var over := flash_overlay(white)
	draw_set_transform(Vector2.ZERO, ang * facing, Vector2(facing, 1))
	Sheet.draw(self, "spring_eel", a, f)
	if white:
		Sheet.draw(self, "spring_eel", a, f, over, true)
	# The orb at the tip of its lure: a dim glow while it weaves, blazing as it coils.
	if LAMP_AT.has(a) and not dead:
		var lamp := 0.45 + 0.15 * sin(t * 3.0)
		if state == "coil":
			lamp = 0.6 + 0.4 * absf(sin(state_time * 18.0))
		elif state == "dart":
			lamp = 1.0
		elif state == "slack":
			lamp = 0.2
		var lp: Vector2 = LAMP_AT[a]
		draw_circle(lp, 2.4 + 2.0 * lamp, Color(LAMP, 0.16 * lamp))
		draw_circle(lp, 1.0, Color(LAMP, lamp))
		draw_circle(lp, 0.5, Color(LAMP_CORE, lamp))
	draw_set_transform(Vector2.ZERO)
