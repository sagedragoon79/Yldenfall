class_name PlayerInput
extends RefCounted
## One frame of player intent. Reads the real input map, or is driven by tests
## (scripted = true), so the controller never touches Input directly.

var scripted := false

var move_x := 0
## How far the stick leans that way, 0 to 1 past its deadzone (pass 183): a
## light tilt walks, a full one runs. Keys and the d-pad are always 1.
var tilt := 1.0
var up := false
var up_pressed := false
var down := false
var jump_pressed := false
var jump_held := false
var attack_pressed := false
var attack_held := false
var dash_pressed := false
var block_pressed := false
var block_held := false
var spell_pressed := false
var spell_next_pressed := false
var heal_pressed := false
var stillstone_pressed := false
var throw_pressed := false
var belt_next_pressed := false
var belt_use_pressed := false
## Up was held last frame as a stick's sideways drift, too level to count.
var _up_drifting := false


## Reads this frame's intent. `tuning` gives the stick's vertical angle
## (`MovementTuning.stick_vertical_angle`, pass 368); without it, 35 degrees.
func poll(tuning: MovementTuning = null) -> void:
	if scripted:
		return
	var axis := Input.get_axis("move_left", "move_right")
	move_x = int(signf(axis))
	tilt = absf(axis) if move_x != 0 else 1.0
	var slope := tan(deg_to_rad(tuning.stick_vertical_angle if tuning != null else 35.0))
	var held_up := Input.is_action_pressed("move_up")
	up = held_up and vertical("move_up", slope)
	# Up is pressed as it is pressed, or as a stick held from a sideways drift
	# swings up far enough to count, so it still enters a door. Held through a
	# door or a dialog it is not pressed again.
	up_pressed = up and (Input.is_action_just_pressed("move_up") or _up_drifting)
	_up_drifting = held_up and not up
	down = Input.is_action_pressed("move_down") and vertical("move_down", slope)
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	attack_pressed = Input.is_action_just_pressed("attack")
	attack_held = Input.is_action_pressed("attack")
	dash_pressed = Input.is_action_just_pressed("dash")
	block_pressed = Input.is_action_just_pressed("block")
	block_held = Input.is_action_pressed("block")
	spell_pressed = Input.is_action_just_pressed("spell")
	spell_next_pressed = Input.is_action_just_pressed("spell_next")
	heal_pressed = Input.is_action_just_pressed("heal")
	stillstone_pressed = Input.is_action_just_pressed("stillstone")
	throw_pressed = Input.is_action_just_pressed("throw")
	belt_next_pressed = Input.is_action_just_pressed("belt_next")
	belt_use_pressed = Input.is_action_just_pressed("belt_use")


## Whether `action` (up or down) leans far enough from level to count: its
## strength is at least `slope` times the stronger of left and right. Keys and
## the d-pad press at full strength, so a digital diagonal always counts.
static func vertical(action: String, slope: float) -> bool:
	var side := maxf(Input.get_action_raw_strength("move_left"), Input.get_action_raw_strength("move_right"))
	return Input.get_action_raw_strength(action) >= side * slope


## Called by the player after it has consumed this frame. Scripted presses last one frame.
func end_frame() -> void:
	if scripted:
		drop_presses()


## Forgets this frame's presses; held buttons stay held.
func drop_presses() -> void:
	up_pressed = false
	jump_pressed = false
	attack_pressed = false
	dash_pressed = false
	block_pressed = false
	spell_pressed = false
	spell_next_pressed = false
	heal_pressed = false
	stillstone_pressed = false
	throw_pressed = false
	belt_next_pressed = false
	belt_use_pressed = false


## Clears everything (used when control is taken away, e.g. on death).
func clear() -> void:
	move_x = 0
	tilt = 1.0
	up = false
	down = false
	jump_held = false
	attack_held = false
	block_held = false
	end_frame()
