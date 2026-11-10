class_name MovementTuning
extends Resource
## Every movement number from the design bible (section 6), in px and seconds at
## the 640x360 internal resolution. Tests assert against these values.

@export_group("Ground")
@export var run_speed := 165.0
@export var ground_accel := 1800.0
@export var ground_decel := 2600.0
@export var turn_multiplier := 1.6
## Analog walk into run (pass 183, bible 6.1): a stick tilted up to walk_tilt
## walks at walk_fraction of run_speed, the speed climbs with the tilt from
## there, and from run_tilt on it is a full run. Keys and the d-pad always run.
@export var walk_fraction := 0.4
@export var walk_tilt := 0.45
@export var run_tilt := 0.9
## A stick reads up or down only this many degrees or more from level (pass
## 368, bible 6.1): a thumb pushing sideways drifts a little up or down, and a
## drift past the deadzone had made a running jump drop through a platform,
## a slash a pogo, and a run past a door walk in. Keys and the d-pad, digital,
## are always as pressed, diagonals too.
@export var stick_vertical_angle := 35.0

@export_group("Jump")
@export var jump_height := 72.0
@export var jump_time_to_apex := 0.36
@export var fall_gravity_multiplier := 1.6
@export var jump_cut_multiplier := 0.45
@export var apex_threshold := 40.0
@export var apex_gravity_multiplier := 0.5
@export var max_fall_speed := 520.0
@export var max_fast_fall_speed := 620.0
@export var air_accel := 1400.0
@export var air_decel := 900.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var corner_correction_px := 6
@export var ledge_correction_px := 4
## Pass 139: a dash or fall that clips the top edge of an opening with the
## head is nudged down into it, up to this many px.
@export var head_correction_px := 4

@export_group("Wall")
@export var wall_slide_speed := 90.0
@export var wall_stick_time := 0.08
@export var wall_jump_x := 220.0
@export var wall_jump_y := 380.0
@export var wall_climb_jump_x := 120.0
@export var wall_jump_lock := 0.10
@export var wall_climb_jump_lock := 0.06
@export var wall_jump_blend := 0.10
@export var wall_coyote_time := 0.08

@export_group("Double jump")
@export var double_jump_height := 48.0

@export_group("Feather Fall")
## Feather Fall (skill, bible 6.10): with the double jump spent, holding Jump
## while falling eases the fall to glide_fall_speed, braking at glide_brake.
## Air control is unchanged, so a glide carries you as far as you can steer.
@export var glide_fall_speed := 60.0
@export var glide_brake := 1500.0

@export_group("Dash")
@export var dash_speed := 380.0
@export var dash_time := 0.15
@export var dash_invuln := 0.10
@export var air_dash_charges := 1
@export var ground_dash_cooldown := 0.25
## A dash pressed while it can't go yet (on the cooldown, or in the air with
## no charge) is held this long and fires the frame it can.
@export var dash_buffer_time := 0.10
## A ground dash snaps to the floor from this far (px), so it follows a slope
## down instead of sailing off it; a ledge deeper than this still drops away.
@export var ground_dash_snap := 10.0

@export_group("Pogo and attacks")
@export var pogo_bounce := 380.0
@export var pogo_bounce_held := 420.0
## The hit-stop a pogo lands with (bible 6.6), so each bounce reads as a strike.
@export var pogo_hitstop := 0.045
## A bounce-pod's launch (High Boughs): about 9 tiles of rise.
@export var pod_bounce := 600.0
@export var slash_active := 0.10
@export var down_strike_active := 0.14
@export var attack_cooldown := 0.28
@export var slash_recoil := 120.0

@export_group("Swimming")
## Deep water (the Sunken Spring, bible 6.8): the body floats up toward the
## surface, sinks while Down is held, and each jump press is a stroke upward.
## With the head above water a jump press is a full jump out.
@export var swim_speed_multiplier := 0.7
@export var swim_float := 50.0
@export var swim_sink := 120.0
@export var swim_drag := 520.0
@export var swim_stroke := 230.0

@export_group("Wind")
## A wind current in the High Boughs (bible 6.9): in the air inside one, the run
## target is shifted by wind_speed along the wind, so you can't make headway
## against it, and the current bears you level (velocity.y eases to 0 at
## wind_drag once you stop rising). Hold Down to drop out of it.
@export var wind_speed := 200.0
@export var wind_drag := 2400.0

@export_group("Sap")
## Amber sap (bible 6.12, the Heartwood' pools and a Sap Spitter's puddles):
## standing in it, the run is held to sap_speed of its pace and a ground jump
## leaves at sap_jump of its speed (about half the height). Nothing else is
## slowed: the double jump, wall jump and dash are the way out.
@export var sap_speed := 0.5
@export var sap_jump := 0.72

@export_group("Ladders")
## Ladders (bible 6.11, the original's own way up): Up grabs one, Up and Down
## climb at ladder_speed with no gravity, Jump leaves with a full jump, and a
## ladder can't be grabbed again for ladder_regrab after you leave it.
@export var ladder_speed := 90.0
@export var ladder_snap := 240.0
@export var ladder_regrab := 0.25

@export_group("Crouch")
## The crouch (bible 6.15): Down held on the ground drops the body to
## crouch_height (px; standing it is 40), so a blow above that passes over. A
## crouch holds still and only turns; crouch_creep_speed is the creep a body
## pinned under a roof too low to stand in moves at, so it is never stuck.
@export var crouch_height := 26.0
@export var crouch_creep_speed := 40.0

@export_group("Damage")
@export var hurt_invuln := 0.8


var gravity: float:
	get: return 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)

var jump_velocity: float:
	get: return 2.0 * jump_height / jump_time_to_apex

var double_jump_velocity: float:
	get: return sqrt(2.0 * gravity * double_jump_height)


## The share of run_speed a stick tilted this far (0 to 1) asks for.
func speed_fraction(tilt: float) -> float:
	if tilt >= run_tilt:
		return 1.0
	if tilt <= walk_tilt:
		return walk_fraction
	return lerpf(walk_fraction, 1.0, (tilt - walk_tilt) / (run_tilt - walk_tilt))
