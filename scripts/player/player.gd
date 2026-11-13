class_name Player
extends CharacterBody2D
## The elf wanderer's controller. Hand-written kinematic movement at a fixed
## 60 Hz, tuned by MovementTuning. The node origin is at the player's feet.

signal health_changed(hp: int, max_hp: int)
signal jumped(kind: String)
signal landed(fall_speed: float)
## A footstep (or the scuff under a landing) on `surface`: see Room.surface_at.
signal footstep(surface: String)
signal died
signal respawned

## The group of a foe's sorcery, which a shield wards (pass 225): a hex, a shadow
## bolt, a shard called up out of the floor, the core's beam.
const MAGIC := "magic"
## A ward turning part of a hex rings under the hurt (pass 230).
const WARD_SOUND := "ward"
## A guard held with too little MP to pay for a blow breaks (pass 242).
const GUARD_BREAK_SOUND := "guard_break"
const BODY_SIZE := Vector2(12, 40)
## A crouch's low cut (bible 6.15): as long as a side slash, this tall, along the floor.
const LOW_SLASH_HEIGHT := 18.0
## How high above the feet a crouched cast or Rune Dagger leaves (px), low
## enough to meet a crawler. Standing, a bolt leaves at CAST_HEIGHT and a
## dagger at THROW_HEIGHT.
const LOW_SHOT_HEIGHT := 10.0
const CAST_HEIGHT := 24.0
const THROW_HEIGHT := 22.0

# Collision layers (see docs/architecture.md).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_HAZARD := 4
const LAYER_ENEMY := 8
## Elven veils (StrideVeil, bible 4.1 A5): a wall to the player except mid-dash.
const LAYER_VEIL := 16

## How long an Barkbalm protects you (design bible 10.2).
const OINTMENT_TIME := 10.0
## Blightcap (a Yldenfall drop): seconds it lasts, and health lost each POISON_TICK.
## It never takes your last point of health.
const POISON_TIME := 8.0
const POISON_TICK := 1.0
const POISON_DAMAGE := 2

const SLASH_SIZE := Vector2(36, 26)
const UP_SLASH_SIZE := Vector2(34, 36)
const DOWN_STRIKE_SIZE := Vector2(28, 24)
## How far a Thrust reaches past the body (a cut reaches about 34).
const THRUST_LENGTH := 52.0
## How fast an updraft brings the body to its lift speed (px/s²).
const UPDRAFT_ACCEL := 1100.0
## A landing from at least this far above (px, 7 tiles) thuds: shake and rumble.
const BIG_DROP := 112.0
## How far a heavy hit's impact spark reaches past a light one's.
const HEAVY_SPARK := 1.6
## Skill tree numbers (design bible 9).
const BLOODLETTING_HEAL := 2
## Heard as Bloodletting gives health back (pass 318).
const BLOODLET_SOUND := "bloodlet"
const LAST_STAND_BELOW := 0.2
const LAST_STAND_TAKEN := 0.75
const TIME_THIEF_EXTRA := 1.0
## The glass running out (pass 230): GLASS_TICKS ticks, GLASS_TICK apart, end
## stopped time, then GLASS_END_SOUND as it runs again.
const GLASS_TICKS := 3
const GLASS_TICK := 0.25
const GLASS_TICK_SOUND := "glass_tick"
const GLASS_END_SOUND := "glass_end"
## A wall slide rasps as you catch the wall and every WALL_SCRAPE seconds after (pass 238).
const WALL_SLIDE_SOUND := "wall_slide"
const WALL_SCRAPE := 0.24
## Seconds before a wind or wrong-gravity cue may sound again, so the edge of a
## field does not chatter.
const FIELD_CUE_GAP := 0.3
## Deep Blight (pass 134): what share of its MP the Witherbloom spell costs.
const RING_OF_DEATH_MULT := 0.5
## Wanderer's Grace (pass 142): seconds of harm passing through you added to
## every dash, on top of `MovementTuning.dash_invuln`.
const GRACE_INVULN := 0.1
## Seconds between the feathers a glide sheds.
const GLIDE_FEATHERS := 0.14
## Corner and ledge correction step a hair past each whole pixel, so a clip of
## exactly 6 (or 4) px still clears: a body left flush against a tile counts as
## touching it (pass 107).
const CORRECTION_SLOP := 0.1
## A contact whose normal is at least this horizontal is a wall; a 45-degree
## slope's face (0.71) is floor.
## How far the floor snap reaches when running (px, bible 6.1).
const FLOOR_SNAP := 4.0
const WALL_NORMAL := 0.9


@export var tuning: MovementTuning = MovementTuning.new()
@export var combat: CombatTuning = CombatTuning.new()

var input := PlayerInput.new()
var abilities := {"glove": true, "delvers_pick": true, "boots": true, "stride": true, "torrent": true, "fire": true, "thunder": true, "wisplight": true, "seers_lens": true, "stillstone": true}

var max_hp := 100
## Heartbeats played at low health (tests).
var heartbeats := 0
## Riposte counter-cuts dealt (tests).
var ripostes := 0
var _heartbeat_timer := 0.0
var hp := 100
var max_mp := 60.0
var mp := 60.0
var gold := 0
var flask_max := 2
var flask_charges := 2
var equipped_spell := "torrent"

# Derived from gear and skills by GameState.refresh_stats. Defaults are the
# Short Sword with a shield and no skills, which is what the gym uses.
var slash_damage := 8
var heavy_damage := 14
var reach_bonus := 0.0
## Extra height (px) of a side slash, from the blade (the Dwarvish Broad Sword's huge arc).
var arc_bonus := 0.0
## Multiplies the wait after each swing: a heavy blade swings slower.
var swing_mult := 1.0
var defense := 0.0
var has_shield := true
## Share of damage a guard blocks; the shield sets it (data/items.json "guard").
var guard_reduction := 0.5
## The Warding Shield: a parry also catches small shots that can't otherwise be
## parried (group "small_projectile") and flings them back (ReflectedShot).
var reflects := false
## What a worn shield (and the Elven Helm) turns of a foe's sorcery, guarding
## or not (pass 225): the original's shields resisted enemy magic, 50 to 90%.
var magic_ward := 0.0
## Resistance to each kind of magic, kind to 0..1 (design bible 5.6; DamageKind
## holds it to the cap). Empty until the Warding gems are built.
var resist := {}
## The kind of the blow being taken, for the damage number's colour.
var _hurt_kind := DamageKind.PHYSICAL
## Amber Draughts carried: dying with one revives you where you fell.
var elixirs := 0
## Barkbalms carried: each makes you immune to harm for OINTMENT_TIME.
var ointments := 0
## Seconds left on a War Glove (the original's Glove, a rare drop): blade hits
## deal combat.war_glove_mult more while it lasts.
var glove_left: float:
	get: return maxf(_glove_timer, 0.0)
var melee_mult := 1.0
var mp_hit_mult := 1.0
var gold_mult := 1.0
var magnet_mult := 1.0
var ground_combo_length := 3
## Skill tree effects (design bible 9), set by GameState.refresh_stats.
var rising_cut := false
var down_strike_mult := 1.0
var spell_pierce := false
var drink_mult := 1.0
## Wisp Swarm (skill): Wisplight throws three orbs.
var wisplight_swarm := false
var bonus_air_dashes := 0
## Riposte: a parry answers with a heavy counter-cut. Bloodletting: hits on a
## staggered foe heal. Thrift scales spell costs; Forked Storm lets Tempest Lance leap;
## Time Thief lengthens the Stillstone (Treasure Sense lives on the map); Last
## Stand cuts damage at low health; Second Wind survives one killing blow per rest.
var riposte := false
var bloodletting := false
## Thrust (skill): hold Attack to charge a lunge, let go to strike.
var thrust := false
## Executioner (skill): blows on a boss in its opening land harder.
var executioner := false
## Thrusts made (tests read it).
var thrusts := 0
## Rune Daggers thrown (the soaks count them, pass 191).
var throws := 0
var spell_cost_mult := 1.0
var chain_thunder := false
var time_thief := false
var ring_of_death := false
var last_stand := false
var second_wind := false
## Wanderer's Grace (skill): longer dash invulnerability, and a kill gives the
## air dashes back.
var wanderers_grace := false
## Feather Fall (skill): glide after the double jump by holding Jump.
var feather_fall := false
## True while gliding (set each frame).
var is_gliding := false
var _glide_feather_timer := 0.0
## Spent until the next rest (a shrine, a Ringreader, or a respawn).
var second_wind_used := false
## Set each frame by the World when the feet are in a sap pool.
var in_sap := false
var dead := false
var purse: GoldPurse

var facing := 1
var wall_dir := 0
var is_wall_sliding := false
var is_dashing: bool:
	get: return _dash_timer > 0.0
var is_attacking: bool:
	get: return _attack_timer > 0.0
var attack_kind := ""
var combo_index := 0
var is_heavy_swing := false
var is_blocking := false
## Crouched (bible 6.15): Down held on the ground. The body is
## `tuning.crouch_height` tall, so a blow above it passes over.
var crouching := false
## Crouched under something too low to stand in (a blow slid you under it):
## you creep at `tuning.crouch_creep_speed` until there is room.
var crouch_pinned := false
var _body_shape: RectangleShape2D
var _body_node: CollisionShape2D
var is_drinking: bool:
	get: return _drink_timer > 0.0
var has_double_jump := true
var air_dash_charges := 1
## A frozen hero (a door's scroll, a fade, a respawn) can't move, so nothing
## hurts them (pass 435). A dialog pauses the world instead (pass 436).
var invulnerable: bool:
	get: return frozen or _invuln_timer > 0.0 or _ointment_timer > 0.0
## Seconds of Barkbalm left (0 when none is on).
var ointment_left: float:
	get: return maxf(_ointment_timer, 0.0)
## Seconds of poison left (0 when you are well).
var poison_left: float:
	get: return maxf(_poison_timer, 0.0)
## Counts swings, so the visual can restart an attack animation on each press.
var swing_count := 0
## The Rune Dagger in flight, if any (pass 184).
var rune_dagger: RuneDagger
var _dagger_back := 0.0
var is_casting: bool:
	get: return _cast_cooldown > combat.cast_cooldown - 0.2
var is_hurt: bool:
	get: return _invuln_timer > hurt_invuln() - 0.25 and not dead

var spawn_point := Vector2.ZERO
var safe_position := Vector2.ZERO
## When set, called instead of the default respawn at `spawn_point` (the World
## uses it to return the player to the last save shrine, in any room).
var respawn_handler: Callable
## While frozen (room transitions, dialog, menus) the controller does nothing.
var frozen := false:
	set(on):
		if on and not frozen:
			# A hold forgets every buffered press (pass 440): Up and Jump pressed
			# together at a sign or an inner door put the Jump in its buffer
			# before the hold began, and it leapt as the hold ended. Set here,
			# not in the frozen step, since a hold may end before a step runs.
			forget_buffers()
		frozen = on
## True only while the blade's own blow is dealt, so a foe whose guard turns
## it can tell a blade at arm's length from a bolt or a thrown blade (pass 442).
var _striking := false
var _blade_turned := false
var _turned_now := false
## Set by a screen that read this frame's press (the dialog box, pass 431):
## the hero's next step drops its presses, so the press is not read twice.
var drop_next_presses := false
## A drag in px/s that something outside the player applies this frame (a
## boss's web line reeling you in). Moves the body directly, so it works
## against any input; a dash breaks it. Cleared every frame.
var pull := Vector2.ZERO
## Falling water bearing down on you this frame (px/s, a floor on velocity.y).
## Set by a Waterfall while you are in it; cleared every frame.
var water_push := 0.0
## How much of their weight the player has this frame: a GravityDrift pocket in
## the Evercrown lowers it (design bible 8.9). Set by the pocket each frame, like water_push.
var gravity_scale := 1.0
## Field cues (pass 137): whether a current held you, and whether a pocket of
## wrong gravity did, last frame, and how long until each cue may sound again.
var _was_in_wind := false
var _was_drifting := false
var _wind_cue_wait := 0.0
var _drift_cue_wait := 0.0
## Rising wind under the player this frame (px/s up): Skyrend's updraft in its
## third phase (design bible 8.6). Set by an Updraft each frame; Down drops out.
var updraft := 0.0
## A wind current pushing the airborne player this frame (px/s, + east): the
## High Boughs' wind (bible 6.9). Set by a WindCurrent each frame; Down drops out.
var wind := 0.0
## Deep water around the body's centre this frame (the Sunken Spring, legend
## `a`), and the y of its surface in that column. Set by SwimWater each frame.
var in_water := false
var water_surface := 0.0
## True while swimming (the body was in deep water on the last physics frame).
var swimming := false
## True while climbing a ladder (bible 6.11, legend `"`).
var on_ladder := false
var _ladder_x := 0.0
var _ladder_top := 0.0
var _ladder_regrab := 0.0

var visual: PlayerVisual
var scarf: Scarf
var cloak: Cloak

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_coyote_timer := 0.0
var _last_wall_dir := 0
var _wall_stick_timer := 0.0
var _control_lock_timer := 0.0
## False until the hero's first physics step (pass 429).
var _woken := false
## The physics frame of the hero's last step (pass 430).
var _last_step := -1
var _control_blend_timer := 0.0
var _jump_cut_available := false
var _dash_timer := 0.0
## The run a dash's blended last step settles to after its move (pass 470); 0 when none.
var _dash_settle := 0.0
var _dash_cooldown := 0.0
var _dash_dir := 1
## The dash began on the ground: it follows the floor down a slope (bible 6.5).
var _ground_dash := false
var _afterimage_timer := 0.0
var _invuln_timer := 0.0
var _ointment_timer := 0.0
var _glove_timer := 0.0
var _glove_spark := 0.0
var _poison_timer := 0.0
var _poison_tick := 0.0
## Health each poison tick takes: POISON_DAMAGE scaled by the room's threat.
var _poison_damage := POISON_DAMAGE
var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _attack_hits := {}
## This swing's up-slash pop is spent (combat.up_slash_pop).
var _up_popped := false
var _was_on_floor := false
var _peak_fall_speed := 0.0
## The highest point (smallest y) of the current time in the air.
var _air_top_y := INF
var _dust_timer := 0.0
var _scrape_timer := 0.0
var _step_timer := 0.0
var _combo_timer := 0.0
var _attack_buffer_timer := 0.0
var _dash_buffer_timer := 0.0
var _throw_buffer_timer := 0.0
var _swing_damage := 0
## Seconds Attack has been held toward a Thrust, and the glint's clock.
var _thrust_charge := 0.0
var _thrust_glint := 0.0
## This thrust began on the floor and is still lunging.
var _thrust_lunge := false
var _parry_timer := 0.0
## Set when a guard breaks; the shield stays down until Block is let go.
var guard_broken := false
var _drink_timer := 0.0
var _cast_cooldown := 0.0
var _dead_timer := 0.0
var _gold_frac := 0.0


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_VEIL
	floor_snap_length = FLOOR_SNAP
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	safe_margin = 0.05
	add_to_group("player")
	TimeStop.reset()
	GameState.leveled_up.connect(_on_leveled_up)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y * 0.5)
	add_child(shape)
	_body_shape = rect
	_body_node = shape

	visual = PlayerVisual.new()
	visual.player = self

	# The scarf is added first so it draws behind the body. A sheet whose art
	# carries its own cloak turns it off (flags "scarf": false).
	scarf = Scarf.new()
	scarf.player = self
	scarf.visible = Sheet.flag(PlayerVisual.SHEET_NAME, "scarf", true)
	add_child(scarf)
	# The cloak over the body sets: its cape behind the body, its hood drawn by the visual.
	cloak = Cloak.new()
	cloak.player = self
	add_child(cloak)
	add_child(visual)

	air_dash_charges = tuning.air_dash_charges + bonus_air_dashes
	max_mp = max_mp
	mp = max_mp
	flask_max = combat.flask_charges
	flask_charges = flask_max
	spawn_point = global_position
	safe_position = global_position


func _physics_process(delta: float) -> void:
	# Steps missed while the game was paused (a menu, the map, a dialog).
	var missed := _last_step >= 0 and Engine.get_physics_frames() - _last_step > 1
	_last_step = Engine.get_physics_frames()
	if frozen:
		input.clear()
		# A hold (a door's scroll, a dialog) spends a Thrust's charge (pass
		# 434): the Attack let go during it lunged as the hold ended.
		_thrust_charge = 0.0
		return
	if dead:
		_dead_timer -= delta
		input.clear()
		if _dead_timer <= 0.0:
			_respawn()
		return
	input.poll(tuning)
	if not _woken or missed or drop_next_presses:
		# A press already under way when the hero woke is not the hero's (pass
		# 429): the Jump that takes a journey up from the title is read by the
		# shelf, and seen again here it buffered a jump for the first landing.
		# Nor is one made while the game was paused (pass 430): the Jump,
		# Attack or Dash that closes a menu reached the hero's next step too
		# whenever no physics step fell between the press and the close (most
		# frames on a display faster than 60 Hz), and the hero jumped, swung
		# or dashed out of the menu. Nor the one that puts a dialog away
		# (pass 431), which the box has read: it asks for this. A hold with
		# nothing to read a press (a door's scroll, a respawn) keeps the
		# player's next press (pass 432).
		_woken = true
		drop_next_presses = false
		if not input.scripted:
			input.drop_presses()
		# Nor is an Attack let go while paused a Thrust's release (pass 434).
		# Still held, the charge is kept and the player's own release lunges.
		if not input.attack_held:
			_thrust_charge = 0.0
		# A press buffered before a pause (Up and Jump at a shopkeeper, whose
		# shop pauses the game) is the same (pass 440).
		forget_buffers()
	_tick_timers(delta)
	mp = minf(mp + combat.mp_regen_per_second * delta, max_mp)

	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = tuning.coyote_time
		_refresh_air_moves()
	if input.jump_pressed:
		_jump_buffer_timer = tuning.jump_buffer_time

	if input.attack_pressed:
		_attack_buffer_timer = combat.attack_buffer
	if input.dash_pressed and abilities.stride:
		_dash_buffer_timer = tuning.dash_buffer_time
	if input.throw_pressed:
		_throw_buffer_timer = combat.throw_buffer

	if _try_interact(on_floor):
		input.end_frame()
		return
	if on_ladder and _dash_buffer_timer > 0.0 and _dash_cooldown <= 0.0:
		# A stride leaves the ladder: the dash below takes it from here. Only a
		# dash that will go lets go (pass 240): without the Elven Stride, or on
		# the ground dash's cooldown, the press keeps you on the rungs.
		_leave_ladder()
	if on_ladder or _try_grab_ladder(on_floor):
		_thrust_charge = 0.0
		_ladder_step(delta)
		input.end_frame()
		return
	_update_wall_contact(on_floor)
	_update_crouch(on_floor)
	_update_block()
	_update_drink(delta, on_floor)
	_try_drop_through(on_floor)
	_try_dash(on_floor)
	_try_cycle_spell()
	_try_cast()
	_try_stillstone()
	_try_throw(delta)
	_try_attack(on_floor)
	_try_thrust(on_floor, delta)

	swimming = in_water
	if swimming:
		_refresh_air_moves()
		# Water is footing for coyote time (pass 111): bobbing at the surface
		# lifts the body clear of the water for a few frames, and a jump pressed
		# then still jumps out at once.
		_coyote_timer = tuning.coyote_time
	if is_dashing:
		_dash_step(delta)
	elif _thrust_lunge and is_attacking and on_floor:
		velocity.x = facing * combat.thrust_speed
	else:
		# Off a ledge the lunge ends, and you step off at no more than a run
		# (pass 153): a thrust never carries you over a gap.
		if _thrust_lunge and not on_floor:
			velocity.x = clampf(velocity.x, -tuning.run_speed, tuning.run_speed)
		_thrust_lunge = false
		_horizontal_step(delta, on_floor)

	if swimming:
		_try_stroke()
	else:
		_try_jump()
	_apply_jump_cut()

	# A glide lasts only while _glide keeps it going this frame.
	var was_gliding := is_gliding
	is_gliding = false
	if not is_dashing:
		if swimming:
			_swim_drift(delta)
		elif updraft > 0.0 and not input.down:
			_ride_updraft(delta)
		elif wind != 0.0 and velocity.y >= 0.0 and not _pinned_by_wind():
			# The current bears you level once you stop rising.
			velocity.y = move_toward(velocity.y, 0.0, tuning.wind_drag * delta)
		elif not _glide(delta, on_floor, was_gliding):
			_apply_gravity(delta, on_floor)
	_apply_wall_slide()
	if water_push > 0.0:
		# A waterfall beats you down: no climbing or jumping up through it.
		velocity.y = maxf(velocity.y, water_push)
	water_push = 0.0
	_field_cues(delta)
	gravity_scale = 1.0
	updraft = 0.0
	wind = 0.0
	in_water = false

	if is_attacking:
		_process_attack_hits()

	if velocity.x != 0.0 and not is_attacking and not is_dashing and not is_wall_sliding and not is_blocking and input.move_x != 0:
		facing = input.move_x
	elif crouching and input.move_x != 0 and not is_attacking and not is_blocking:
		# Crouched, left and right turn you where you are (bible 6.15).
		facing = input.move_x

	_apply_corner_correction(delta)
	_apply_ledge_correction(delta, on_floor)
	_apply_head_correction(delta, on_floor)
	var pre_velocity := velocity
	# A ground stride hugs the floor: down a slope the snap reaches far enough
	# to hold a dash's 6 px a frame, so it doesn't sail off the ramp (pass 121).
	# A thrust's lunge is as fast, so it hugs the floor the same way, and so
	# does the slide out of either while it is still faster than a run (pass 153).
	var hugging := (is_dashing and _ground_dash) or (_thrust_lunge and is_attacking) \
		or (on_floor and absf(velocity.x) > tuning.run_speed)
	floor_snap_length = tuning.ground_dash_snap if hugging else FLOOR_SNAP
	collision_mask = LAYER_WORLD if passes_veils() else LAYER_WORLD | LAYER_VEIL
	move_and_slide()
	if _dash_settle != 0.0:
		# A wall that stopped the last step keeps the stop.
		if signf(velocity.x) == signf(_dash_settle):
			velocity.x = _dash_settle
		_dash_settle = 0.0
	if pull != Vector2.ZERO and not is_dashing:
		move_and_collide(pull * delta)
	pull = Vector2.ZERO
	_after_move(pre_velocity, delta)
	_check_hazards()
	input.end_frame()


# --- Timers and refresh -------------------------------------------------------

func _tick_timers(delta: float) -> void:
	var glass_was := TimeStop.left
	TimeStop.tick(delta)
	_glass_cues(glass_was, TimeStop.left)
	_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_wall_coyote_timer -= delta
	# After a wall jump the steering blends back only once the lock is over.
	if _control_lock_timer > 0.0:
		_control_lock_timer -= delta
		if _control_lock_timer <= 0.0:
			_control_blend_timer += _control_lock_timer
	else:
		_control_blend_timer -= delta
	_dash_cooldown -= delta
	_invuln_timer -= delta
	if _ointment_timer > 0.0:
		_ointment_timer -= delta
		if _ointment_timer <= 0.0:
			GameState.toast.emit("The Barkbalm wears off.")
	if _poison_timer > 0.0:
		_tick_poison(delta)
	if _glove_timer > 0.0:
		_tick_glove(delta)
	_attack_cooldown -= delta
	_dust_timer -= delta
	_step_timer -= delta
	_combo_timer -= delta
	_attack_buffer_timer -= delta
	_dash_buffer_timer -= delta
	_throw_buffer_timer -= delta
	_parry_timer -= delta
	_cast_cooldown -= delta
	_ladder_regrab -= delta
	_tick_heartbeat(delta)


## Low health (design bible 5.3): a heartbeat while you're down to one mask.
func is_low_health() -> bool:
	return not dead and hp > 0 and hp <= combat.low_health



## How far through the heartbeat we are: 0 as it sounds, rising to 1 by the
## next. The HUD's red edge reads it, so it swells on the beat (pass 484).
func heartbeat_phase() -> float:
	return clampf(1.0 - _heartbeat_timer / combat.heartbeat_interval, 0.0, 1.0)


func _tick_heartbeat(delta: float) -> void:
	if not is_low_health():
		_heartbeat_timer = 0.0
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = combat.heartbeat_interval
		heartbeats += 1
		Sfx.play("heartbeat", 0.0, -3.0)


func _refresh_air_moves() -> void:
	has_double_jump = true
	air_dash_charges = tuning.air_dash_charges + bonus_air_dashes


## True when a double jump or an air dash the player owns has been spent (a
## stride seed only bursts for someone who needs it).
func needs_air_refresh() -> bool:
	return (abilities.boots and not has_double_jump) \
		or (abilities.stride and air_dash_charges < tuning.air_dash_charges + bonus_air_dashes)


## Gives back the double jump and air dashes (a stride seed, bible 6.4).
func refresh_air_moves() -> void:
	_refresh_air_moves()


## Seconds of harm passing through you that a dash gives.
## How long a hit leaves you unhurtable: the tuning's 0.8 s, doubled by the
## mercy assist (Settings.mercy, bible 14).
func hurt_invuln() -> float:
	return tuning.hurt_invuln * (Settings.MERCY_MULT if Settings.mercy else 1.0)


func dash_invuln() -> float:
	return tuning.dash_invuln + (GRACE_INVULN if wanderers_grace else 0.0)


## A foe has died (Enemy.die). With Wanderer's Grace a kill gives back the air
## dashes spent, with a puff of feathers and a catch of wind, so a strike in
## midair can be dashed out of (bible 9). True if it gave any back.
func on_kill() -> bool:
	if not wanderers_grace or dead or not abilities.stride:
		return false
	var full := tuning.air_dash_charges + bonus_air_dashes
	if air_dash_charges >= full:
		return false
	air_dash_charges = full
	_spawn_dust(Vector2(0, -14), "feathers")
	Sfx.play("wind_catch", 0.05, -2.0)
	return true


# --- Walls ----------------------------------------------------------------------

func _update_wall_contact(on_floor: bool) -> void:
	wall_dir = 0
	if on_floor or not abilities.glove:
		return
	if _wall_at(1):
		wall_dir = 1
	elif _wall_at(-1):
		wall_dir = -1
	if wall_dir != 0:
		_last_wall_dir = wall_dir
		_wall_coyote_timer = tuning.wall_coyote_time
		_refresh_air_moves()


## A wall, not a slope, 2 px to that side: a 45-degree slope's face is
## floor, so it never catches you in a slide (design bible 6.1, pass 115).
func _wall_at(side: int) -> bool:
	var hit := KinematicCollision2D.new()
	return test_move(global_transform, Vector2(side * 2.0, 0), hit) and absf(hit.get_normal().x) > WALL_NORMAL


func _apply_wall_slide() -> void:
	var was_sliding := is_wall_sliding
	is_wall_sliding = false
	if wall_dir == 0 or is_dashing or velocity.y <= 0.0:
		_wall_stick_timer = tuning.wall_stick_time
		return
	if input.move_x == wall_dir:
		is_wall_sliding = true
		_wall_stick_timer = tuning.wall_stick_time
	elif input.move_x == -wall_dir:
		# Pushing away detaches only after a short stick, so wall jumps stay easy to aim.
		is_wall_sliding = was_sliding and _wall_stick_timer > 0.0
		_wall_stick_timer -= get_physics_process_delta_time()
	else:
		is_wall_sliding = was_sliding
	if is_wall_sliding:
		velocity.x = wall_dir * 10.0
		velocity.y = minf(velocity.y, tuning.wall_slide_speed)
		facing = -wall_dir
		if _dust_timer <= 0.0:
			# Carry the overshoot so the puffs keep a true 0.06 s beat.
			_dust_timer = 0.06 + maxf(_dust_timer, -0.06)
			_spawn_dust(Vector2(wall_dir * BODY_SIZE.x * 0.5, -BODY_SIZE.y * 0.6), "wall")
		# The glove rasps down the wall as you catch it, and every WALL_SCRAPE
		# after (pass 238: the slide had dust and no sound).
		_scrape_timer -= get_physics_process_delta_time()
		if not was_sliding or _scrape_timer <= 0.0:
			_scrape_timer = WALL_SCRAPE
			Sfx.play(WALL_SLIDE_SOUND, 0.08, -4.0 if not was_sliding else -8.0)


# --- Horizontal -----------------------------------------------------------------

func _horizontal_step(delta: float, on_floor: bool) -> void:
	var target := input.move_x * tuning.run_speed * tuning.speed_fraction(input.tilt)
	var held_low := crouching and on_floor
	if held_low:
		# A crouch holds still and only turns; pinned under a low roof it creeps.
		target = input.move_x * tuning.crouch_creep_speed if crouch_pinned else 0.0
	if is_drinking:
		target = 0.0
	elif is_blocking:
		target *= combat.guard_move_multiplier
	if in_sap:
		target *= tuning.sap_speed
	if swimming:
		target *= tuning.swim_speed_multiplier
	target += wind
	var accel: float
	if on_floor:
		if input.move_x != 0:
			accel = tuning.ground_accel
			if velocity.x != 0.0 and signf(velocity.x) != input.move_x:
				accel = tuning.ground_decel * tuning.turn_multiplier
				if absf(velocity.x) > 80.0:
					_spawn_run_dust()
		else:
			accel = tuning.ground_decel
		if input.move_x != 0 and absf(velocity.x) < 10.0 and not held_low:
			_spawn_run_dust()
		if held_low and not crouch_pinned:
			accel = tuning.ground_decel
	else:
		accel = tuning.air_accel if input.move_x != 0 else tuning.air_decel

	if _control_lock_timer > 0.0:
		accel = 0.0
	elif _control_blend_timer > 0.0:
		accel *= 1.0 - _control_blend_timer / tuning.wall_jump_blend
	velocity.x = move_toward(velocity.x, target, accel * delta)


# --- Jumping --------------------------------------------------------------------

func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if _coyote_timer > 0.0:
		# A jump stands you up first; under a roof too low to stand in, it waits.
		if not try_stand():
			return
		_do_jump()
	elif abilities.glove and (wall_dir != 0 or _wall_coyote_timer > 0.0):
		_do_wall_jump(wall_dir if wall_dir != 0 else _last_wall_dir)
	elif abilities.boots and has_double_jump and not is_dashing:
		_do_double_jump()


func _do_jump() -> void:
	velocity.y = -tuning.jump_velocity * (tuning.sap_jump if in_sap else 1.0)
	_end_dash_into_jump()
	_consume_jump()
	_jump_cut_available = true
	visual.squash_for("jump")
	_spawn_dust(Vector2.ZERO, "jump")
	Sfx.play("jump")
	jumped.emit("ground")


func _do_wall_jump(side: int) -> void:
	var away := -side
	var climbing := input.move_x != away
	velocity.x = away * (tuning.wall_climb_jump_x if climbing else tuning.wall_jump_x)
	velocity.y = -tuning.wall_jump_y
	_control_lock_timer = tuning.wall_climb_jump_lock if climbing else tuning.wall_jump_lock
	_control_blend_timer = tuning.wall_jump_blend
	_end_dash_into_jump()
	_consume_jump()
	_wall_coyote_timer = 0.0
	is_wall_sliding = false
	_jump_cut_available = true
	has_double_jump = true
	facing = away
	visual.squash_for("wall_jump")
	_spawn_dust(Vector2(side * BODY_SIZE.x * 0.5, -BODY_SIZE.y * 0.5), "walljump")
	Sfx.play("wall_jump")
	jumped.emit("wall")


func _do_double_jump() -> void:
	velocity.y = -tuning.double_jump_velocity
	has_double_jump = false
	_consume_jump()
	_jump_cut_available = true
	visual.squash_for("double_jump")
	_spawn_dust(Vector2(0, -4), "feathers")
	Sfx.play("double_jump")
	jumped.emit("double")


func _consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _apply_jump_cut() -> void:
	if not _jump_cut_available:
		return
	if velocity.y >= 0.0:
		_jump_cut_available = false
	elif not input.jump_held:
		velocity.y *= tuning.jump_cut_multiplier
		_jump_cut_available = false


func _try_drop_through(on_floor: bool) -> void:
	if not (on_floor and input.down and input.jump_pressed):
		return
	var room: Variant = get_tree().get_first_node_in_group("room")
	var tile: bool = room and room.has_method("is_one_way_at") and room.is_one_way_at(global_position + Vector2(0, 2))
	if tile or _standing_on_one_way_body():
		global_position.y += 3.0
		_jump_buffer_timer = 0.0
		input.jump_pressed = false
		_coyote_timer = 0.0


## True when the floor under the feet is a one-way body that isn't a room tile
## (a Bark Knight's rooted lance), so Down + Jump drops through it as well.
func _standing_on_one_way_body() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var shape: Object = c.get_collider_shape()
		if c.get_normal().y < -0.7 and shape is CollisionShape2D and shape.one_way_collision:
			return true
	return false


# --- Ladders ---------------------------------------------------------------------

## Up with a ladder at the body (or Down standing on a ladder's top) takes hold
## of it (bible 6.11). Not mid-dash, mid-swing, swimming or drinking.
func _try_grab_ladder(on_floor: bool) -> bool:
	if _ladder_regrab > 0.0 or is_dashing or is_attacking or swimming or is_drinking:
		return false
	var room := get_tree().get_first_node_in_group("room") as Room
	if room == null:
		return false
	var probe := Vector2.INF
	if input.up:
		probe = global_position + Vector2(0, -12)
	elif input.down and on_floor:
		probe = global_position + Vector2(0, 4)
	if probe == Vector2.INF or not room.is_ladder_at(probe):
		return false
	on_ladder = true
	_set_crouch(false)
	_ladder_x = room.ladder_x(probe)
	_ladder_top = room.ladder_top(probe)
	velocity = Vector2.ZERO
	if input.down:
		# Off the top plank and onto the rungs, like a drop through.
		global_position.y += 3.0
	is_wall_sliding = false
	is_gliding = false
	_refresh_air_moves()
	_coyote_timer = 0.0
	Sfx.play("ladder", 0.1, -4.0)
	return true


func _leave_ladder() -> void:
	on_ladder = false
	_ladder_regrab = tuning.ladder_regrab


## On a ladder: Up and Down climb, no gravity, Jump leaves with a full jump.
## Climbing past the top steps you onto it; climbing down onto a floor, or off
## the bottom of a ladder that hangs in the air, lets go.
func _ladder_step(delta: float) -> void:
	var room := get_tree().get_first_node_in_group("room") as Room
	if room == null:
		_leave_ladder()
		return
	if input.jump_pressed:
		_leave_ladder()
		velocity.x = input.move_x * tuning.run_speed
		if input.move_x != 0:
			facing = input.move_x
		_do_jump()
		move_and_slide()
		_check_hazards()
		return
	var dir := int(input.down) - int(input.up)
	if input.move_x != 0:
		facing = input.move_x
	velocity = Vector2(0.0, dir * tuning.ladder_speed)
	global_position.x = move_toward(global_position.x, _ladder_x, tuning.ladder_snap * delta)
	if dir < 0 and global_position.y + velocity.y * delta <= _ladder_top:
		# Over the top: stand on it.
		global_position.y = _ladder_top
		velocity = Vector2.ZERO
		_leave_ladder()
		_ladder_regrab = 0.0
		_check_hazards()
		return
	if dir != 0:
		_ladder_rung_sound(delta)
	move_and_slide()
	if dir > 0 and is_on_floor():
		_leave_ladder()
		_ladder_regrab = 0.0
	elif not room.is_ladder_at(global_position + Vector2(0, -0.5)) and not room.is_ladder_at(global_position + Vector2(0, -20)):
		# Climbed off the bottom of a hanging ladder: fall.
		_leave_ladder()
	_check_hazards()


## A creak of the rungs about every 8 px climbed (two rungs a tile).
func _ladder_rung_sound(_delta: float) -> void:
	if _step_timer <= 0.0:
		_step_timer = 8.0 / tuning.ladder_speed
		Sfx.play("ladder", 0.12, -8.0)


# --- Gravity --------------------------------------------------------------------

func _apply_gravity(delta: float, on_floor: bool) -> void:
	var g := tuning.gravity
	if not on_floor and input.jump_held and absf(velocity.y) < tuning.apex_threshold:
		g *= tuning.apex_gravity_multiplier
	elif velocity.y > 0.0:
		g *= tuning.fall_gravity_multiplier
	velocity.y += g * gravity_scale * delta
	var max_fall := tuning.max_fast_fall_speed if input.down else tuning.max_fall_speed
	velocity.y = minf(velocity.y, max_fall * gravity_scale)


## Feather Fall (skill, bible 6.10): with the double jump spent and Jump held,
## a fall eases down to a slow glide. Down cancels it, like any fast fall.
## Returns true while gliding (it stands in for gravity that frame).
func _glide(delta: float, on_floor: bool, was_gliding: bool) -> bool:
	var can: bool = feather_fall and abilities.boots and not on_floor and not has_double_jump \
		and input.jump_held and not input.down and not is_wall_sliding and velocity.y > 0.0
	if not can:
		return false
	is_gliding = true
	if not was_gliding:
		_glide_feather_timer = 0.0
		visual.squash_for("glide")
		Sfx.play("glide", 0.05, -4.0)
	# A fast fall brakes down to glide speed; a slow one falls into it.
	var rate := tuning.glide_brake if velocity.y > tuning.glide_fall_speed else tuning.gravity * tuning.fall_gravity_multiplier
	velocity.y = move_toward(velocity.y, tuning.glide_fall_speed, rate * delta)
	_glide_feather_timer -= delta
	if _glide_feather_timer <= 0.0:
		_glide_feather_timer = GLIDE_FEATHERS
		_spawn_dust(Vector2(-facing * 6, -18), "glide")
	return true


## An updraft carries the body up toward its lift speed, and the air moves come
## back, as in water. Anything rising faster (a jump, a pogo) runs on.
func _ride_updraft(delta: float) -> void:
	_refresh_air_moves()
	if velocity.y < -updraft:
		velocity.y += tuning.gravity * delta
		return
	velocity.y = move_toward(velocity.y, -updraft, UPDRAFT_ACCEL * delta)


# --- Swimming -------------------------------------------------------------------

## In deep water a jump press is a stroke up, or, with the head above the
## surface, a full jump out onto the bank.
func _try_stroke() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if global_position.y - BODY_SIZE.y < water_surface:
		_do_jump()
		return
	_jump_buffer_timer = 0.0
	velocity.y = minf(velocity.y, -tuning.swim_stroke)
	visual.squash_for("stroke")
	Sfx.play("swim", 0.1)


## The water holds the body up: it eases toward a slow float to the surface,
## or a sink while Down is held. Anything rising faster (a jump out) runs on.
func _swim_drift(delta: float) -> void:
	var target := tuning.swim_sink if input.down else -tuning.swim_float
	if velocity.y < -tuning.swim_stroke - 1.0:
		velocity.y += tuning.gravity * delta
		return
	velocity.y = move_toward(velocity.y, target, tuning.swim_drag * delta)


# --- Dash -----------------------------------------------------------------------

func _try_dash(on_floor: bool) -> void:
	# A press is held for a moment (bible 6.5, pass 146): a dash pressed a beat
	# early (on the cooldown, or just before a landing or a refresh)
	# still goes the first frame it can.
	if _dash_buffer_timer <= 0.0 or is_dashing or _dash_cooldown > 0.0:
		return
	if not on_floor and air_dash_charges <= 0:
		return
	if not try_stand():
		# Pinned under a low roof: the press waits in its buffer for room.
		return
	_dash_buffer_timer = 0.0
	if not on_floor:
		air_dash_charges -= 1
	_dash_dir = input.move_x if input.move_x != 0 else facing
	if is_wall_sliding:
		_dash_dir = -wall_dir
	facing = _dash_dir
	_ground_dash = on_floor
	_dash_timer = tuning.dash_time
	_invuln_timer = maxf(_invuln_timer, dash_invuln())
	_jump_cut_available = false
	_attack_timer = 0.0
	is_wall_sliding = false
	velocity = Vector2(_dash_dir * tuning.dash_speed, 0.0)
	visual.squash_for("dash")
	_afterimage_timer = 0.0
	# A kick of dust off the floor, or a puff of air in midair, thrown back.
	_spawn_dust(Vector2(-_dash_dir * 6, -3 if on_floor else -14), "dash" if on_floor else "airdash")
	Sfx.play("dash")
	Feel.add_trauma(0.05)


func _dash_step(delta: float) -> void:
	velocity = Vector2(_dash_dir * tuning.dash_speed, 0.0)
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = tuning.dash_time / 3.0
		var ghost := Afterimage.new()
		get_parent().add_child(ghost)
		ghost.setup(self)
	var left := _dash_timer
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_finish_dash()
		# The last step is part dash, part run (pass 470), so a dash covers
		# dash_speed * dash_time at any step. At 70% game speed a step is 0.7 of
		# a frame, and a whole last step at a run had cut the dash 4 px short.
		if left > 0.0 and delta > 0.0:
			_dash_settle = velocity.x
			velocity.x = (_dash_dir * tuning.dash_speed * left + _dash_settle * (delta - left)) / delta


## Whether elven veils let the player through this frame: while dashing, and
## until a dash that ended inside one has carried the player clear of it.
func passes_veils() -> bool:
	var body := Rect2(global_position + Vector2(-5, -38), Vector2(10, 36))
	var inside := false
	for v in get_tree().get_nodes_in_group("stride_veil"):
		if (v as StrideVeil).rect().intersects(body):
			inside = true
			if is_dashing:
				(v as StrideVeil).flare()
	return is_dashing or inside


func _finish_dash() -> void:
	_dash_timer = 0.0
	velocity.x = _dash_dir * tuning.run_speed
	_dash_cooldown = tuning.ground_dash_cooldown


func _end_dash_into_jump() -> void:
	if is_dashing:
		_finish_dash()


# --- Attacks and pogo -----------------------------------------------------------

func _try_attack(on_floor: bool) -> void:
	if _attack_buffer_timer <= 0.0 or _attack_cooldown > 0.0 or is_dashing or is_blocking or is_drinking:
		return
	_attack_buffer_timer = 0.0
	is_heavy_swing = false
	_swing_damage = roundi(slash_damage * blade_mult())
	if not on_floor and input.down and abilities.delvers_pick:
		attack_kind = "down"
		combo_index = 0
		_swing_damage = roundi(slash_damage * blade_mult() * down_strike_mult)
		_attack_timer = tuning.down_strike_active
		_attack_cooldown = tuning.attack_cooldown
	elif crouching and on_floor:
		# The crouch's one low cut (bible 6.15): no combo, no finisher.
		attack_kind = "low"
		combo_index = 0
		_combo_timer = 0.0
		_attack_timer = tuning.slash_active
		_attack_cooldown = combat.combo_cooldowns[0]
	elif input.up:
		attack_kind = "up"
		combo_index = 0
		_attack_timer = tuning.slash_active
		_attack_cooldown = tuning.attack_cooldown
	else:
		attack_kind = "side"
		var max_combo := ground_combo_length if on_floor else combat.air_combo_length
		combo_index = combo_index + 1 if _combo_timer > 0.0 and combo_index < max_combo else 1
		_combo_timer = combat.combo_window
		_attack_timer = tuning.slash_active
		# The last hit of a ground combo is the heavy finisher.
		is_heavy_swing = on_floor and combo_index == max_combo
		var cd: Array[float] = combat.combo_cooldowns
		_attack_cooldown = cd[cd.size() - 1] if is_heavy_swing else cd[mini(combo_index - 1, cd.size() - 2)]
		if is_heavy_swing:
			_swing_damage = roundi(heavy_damage * blade_mult())
	_attack_cooldown *= swing_mult
	_attack_hits.clear()
	_up_popped = false
	swing_count += 1
	var fx := SlashFx.new()
	fx.setup(attack_kind, facing, combo_index, is_heavy_swing, 1.0 + arc_bonus / SLASH_SIZE.y)
	# The smear opens as the blade travels, not over the windup (pass 537). The
	# sprite steps its clip once in this step already; the smear runs from the next.
	var strike := PlayerVisual.strike_step(PlayerVisual.anim_for(self, "attack_" + attack_kind))
	fx.wait_for_strike(strike[1], strike[0], get_physics_process_delta_time())
	add_child(fx)
	if is_heavy_swing:
		visual.squash_for("heavy")
		velocity.x += facing * 60.0
	Sfx.play(swing_sound(), 0.1)


## The swing's sound: a two-handed blade has a heavier voice of its own (pass 190).
func swing_sound() -> String:
	var sound := "heavy" if is_heavy_swing else "slash"
	return "broad_" + sound if GameState.two_handed() else sound


## Thrust (skill, design bible 9): Attack held past combat.thrust_charge
## glints, and letting go lunges. The press still swings as usual, so the charge
## builds through the first cut. A blow, a dash, a guard or a drink spends it.
func _try_thrust(on_floor: bool, delta: float) -> void:
	if not thrust:
		return
	if is_dashing or is_blocking or is_drinking or swimming:
		_thrust_charge = 0.0
		return
	if input.attack_held:
		var was := _thrust_charge
		_thrust_charge += delta
		if was < combat.thrust_charge and thrust_ready():
			Sfx.play("thrust_ready", 0.05, -2.0)
			_thrust_glint = 0.0
		if thrust_ready():
			_tick_thrust_glint(delta)
		return
	var ready := thrust_ready()
	_thrust_charge = 0.0
	if ready and not (is_attacking and attack_kind == "thrust"):
		_thrust(on_floor)


## The charge is full: let go of Attack to thrust.
func thrust_ready() -> bool:
	return _thrust_charge >= combat.thrust_charge


func _tick_thrust_glint(delta: float) -> void:
	_thrust_glint -= delta
	if _thrust_glint <= 0.0:
		# A spark of light runs off the point while the charge is held.
		_thrust_glint = 0.12
		_spawn_dust(Vector2(facing * 14, -21), "coin")


func _thrust(on_floor: bool) -> void:
	attack_kind = "thrust"
	combo_index = 0
	is_heavy_swing = true
	_swing_damage = roundi(heavy_damage * combat.thrust_mult * blade_mult())
	_attack_timer = combat.thrust_time
	_attack_cooldown = combat.thrust_cooldown
	_attack_buffer_timer = 0.0
	_attack_hits.clear()
	_up_popped = false
	thrusts += 1
	swing_count += 1
	_thrust_lunge = on_floor
	if on_floor:
		velocity.x = facing * combat.thrust_speed
		_spawn_dust(Vector2(-facing * 6, -3), "dash")
	var fx := SlashFx.new()
	fx.setup("thrust", facing, 0, true, 1.0 + reach_bonus / SLASH_SIZE.x)
	add_child(fx)
	visual.squash_for("thrust")
	Feel.add_trauma(0.08)
	Sfx.play("thrust", 0.05)


func _attack_rect() -> Rect2:
	var center: Vector2
	var size: Vector2
	match attack_kind:
		"down":
			size = DOWN_STRIKE_SIZE
			center = Vector2(0, 8)
		"up":
			size = UP_SLASH_SIZE
			center = Vector2(0, -BODY_SIZE.y - 14)
		"thrust":
			# A long, low point: farther than a cut, half its height.
			size = Vector2(THRUST_LENGTH + reach_bonus, SLASH_SIZE.y * 0.5 + arc_bonus * 0.5)
			center = Vector2(facing * (BODY_SIZE.x * 0.5 + size.x * 0.5), -body_height() * 0.55)
		"low":
			# Along the floor, from the feet up (bible 6.15).
			size = Vector2(SLASH_SIZE.x + reach_bonus, LOW_SLASH_HEIGHT + arc_bonus * 0.5)
			center = Vector2(facing * (BODY_SIZE.x * 0.5 + 16 + reach_bonus * 0.5), -size.y * 0.5)
		_:
			size = SLASH_SIZE + Vector2(reach_bonus, arc_bonus)
			center = Vector2(facing * (BODY_SIZE.x * 0.5 + 16 + reach_bonus * 0.5), -body_height() * 0.55)
	return Rect2(global_position + center - size * 0.5, size)


func _process_attack_hits() -> void:
	_attack_timer -= get_physics_process_delta_time()
	var rect := _attack_rect()
	var bounced := false
	var hit_something := false
	var hit_foe := false
	# Something gave way: a blow a guard did not turn, or stone broken. A
	# swing that only met guards clangs (the guard's thud) and is not heard
	# as a cut (pass 446).
	var cut := false
	_blade_turned = false
	for collider: Variant in _query_rect(rect, LAYER_WORLD | LAYER_HAZARD | LAYER_ENEMY):
		var id: int = collider.get_instance_id()
		if _attack_hits.has(id):
			continue
		_attack_hits[id] = true
		if collider.is_in_group("breakable") and abilities.delvers_pick:
			collider.break_block()
			hit_something = true
			cut = true
			continue
		if collider.has_method("take_hit"):
			var dir := Vector2(facing, 0) if attack_kind in ["side", "thrust", "low"] else Vector2(0, 1 if attack_kind == "down" else -1)
			# A foe in its opening (a parry stagger, or a boss's own window, Enemy.punishable).
			var open: bool = collider.has_method("punishable") and collider.punishable()
			var damage := _swing_damage
			if executioner and open and _is_boss(collider):
				damage = roundi(damage * combat.executioner_mult)
				Sfx.play("execute", 0.05, -3.0)
			_striking = true
			_turned_now = false
			collider.take_hit(damage, dir * (1.8 if is_heavy_swing else 1.0))
			_striking = false
			cut = cut or not _turned_now
			hit_foe = true
			if bloodletting and open and hp < max_hp:
				hp = mini(hp + BLOODLETTING_HEAL, max_hp)
				health_changed.emit(hp, max_hp)
				_spawn_dust(Vector2(0, -20), "heal")
				Sfx.play(BLOODLET_SOUND, 0.06, -4.0)
			hit_something = true
			if collider is Node2D:
				HitSpark.spawn(get_parent(), _contact_point(rect, collider, dir), dir, HEAVY_SPARK if is_heavy_swing else 1.0)
			if attack_kind == "up" and rising_cut and collider.has_method("launch"):
				collider.launch()
			if collider.is_in_group("enemy"):
				mp = minf(mp + combat.mp_per_melee_hit * mp_hit_mult, max_mp)
		if attack_kind == "down" and collider.is_in_group("pogo") and not bounced:
			bounced = true
			_pogo_bounce()
	if hit_foe and attack_kind == "up" and not is_on_floor() and not _up_popped:
		# Design bible 5.3: a midair up-slash that lands holds you up a little.
		_up_popped = true
		velocity.y = minf(velocity.y, -combat.up_slash_pop)
	if hit_something and not bounced:
		Feel.hitstop(combat.heavy_hitstop if is_heavy_swing else combat.hit_hitstop)
		Feel.add_trauma(0.3 if is_heavy_swing else 0.15)
		Feel.rumble(0.3, 0.2 if is_heavy_swing else 0.0, 0.08)
		if cut:
			Sfx.play("hit", 0.08, 2.0 if is_heavy_swing else 0.0)
		if attack_kind in ["side", "thrust", "low"]:
			velocity.x = -facing * (combat.turned_blade_push if _blade_turned else tuning.slash_recoil)
			# A thrust's lunge stops at what it strikes; it doesn't carry you into it.
			_thrust_lunge = false
	if attack_kind == "down" and bounced:
		_attack_timer = 0.0


## Where a swing meets what it hits: the target's near edge, where the blade bites, pulled
## inside the swing (pass 530; it was the target's middle, so the flash covered the foe).
func _contact_point(rect: Rect2, target: Node2D, dir := Vector2.ZERO) -> Vector2:
	var c: Vector2 = target.center() if target.has_method("center") else Vector2(target.global_position.x, rect.get_center().y)
	if dir != Vector2.ZERO:
		c -= dir.normalized() * minf(_half_extent(target, dir), SPARK_EDGE_MAX)
	return c.clamp(rect.position, rect.end)


## The furthest a spark is moved from a foe's middle toward its edge (a guardian's middle
## can be far inside a broad body; the blade still bites near the swing).
const SPARK_EDGE_MAX := 14.0


## Half a target's box along `dir`, from its first rectangle or capsule shape (0 if none).
static func _half_extent(target: Node, dir: Vector2) -> float:
	for c in target.get_children():
		if c is CollisionShape2D and c.shape != null:
			var size := Vector2.ZERO
			if c.shape is RectangleShape2D:
				size = (c.shape as RectangleShape2D).size
			elif c.shape is CapsuleShape2D:
				var cap := c.shape as CapsuleShape2D
				size = Vector2(cap.radius * 2.0, cap.height)
			if size != Vector2.ZERO:
				return absf(size.x * 0.5 * dir.normalized().x) + absf(size.y * 0.5 * dir.normalized().y)
	return 0.0


func _pogo_bounce() -> void:
	velocity.y = -(tuning.pogo_bounce_held if input.jump_held else tuning.pogo_bounce)
	_refresh_air_moves()
	_jump_cut_available = false
	_coyote_timer = 0.0
	visual.squash_for("pogo")
	_spawn_dust(Vector2(0, 8), "pogo")
	Feel.hitstop(tuning.pogo_hitstop)
	Feel.add_trauma(0.12)
	Feel.rumble(0.4, 0.1, 0.08)
	Sfx.play("pogo")
	jumped.emit("pogo")


## A bounce-pod throws the player up (design bible 6.6): a full-height launch
## that jump release doesn't cut short, and the air moves come back.
func pod_launch() -> void:
	velocity.y = -tuning.pod_bounce
	_refresh_air_moves()
	_jump_cut_available = false
	_coyote_timer = 0.0
	visual.squash_for("pod")
	_spawn_dust(Vector2(0, 0), "jump")
	Feel.add_trauma(0.08)
	Feel.rumble(0.3, 0.1, 0.08)
	jumped.emit("pod")


func _query_rect(rect: Rect2, mask: int) -> Array:
	return Query.rect(get_world_2d(), rect, mask, [get_rid()])


func body_rect() -> Rect2:
	var h := body_height()
	return Rect2(global_position + Vector2(-BODY_SIZE.x * 0.5, -h), Vector2(BODY_SIZE.x, h))


## How tall the body is now: `BODY_SIZE.y`, or `tuning.crouch_height` crouched.
func body_height() -> float:
	return tuning.crouch_height if crouching else BODY_SIZE.y


# --- Crouch (bible 6.15) -------------------------------------------------------

## Down held on the ground crouches. Letting go, leaving the ground, a jump, a
## dash or a guard stands you up, when there is room overhead. In water or
## mid-dash you never crouch, and taking hold of a ladder stands you up.
func _update_crouch(on_floor: bool) -> void:
	var guarding := has_shield and input.block_held and not guard_broken
	var want := on_floor and input.down and not swimming and not is_dashing and not guarding
	if want and not crouching:
		_set_crouch(true)
		visual.squash_for("crouch")
		Sfx.play("crouch", 0.08, -6.0)
	elif not want and crouching:
		try_stand()
	crouch_pinned = crouching and not want


## Stands up if crouched and there is room overhead. True when standing.
func try_stand() -> bool:
	if not crouching:
		return true
	if not can_stand():
		return false
	_set_crouch(false)
	return true


## Whether a crouched body has room overhead to stand up in.
func can_stand() -> bool:
	if not crouching:
		return true
	return not test_move(global_transform, Vector2(0, -(BODY_SIZE.y - tuning.crouch_height)))


## Sets the body's height. The feet stay where they are; the top moves.
func _set_crouch(on: bool) -> void:
	if crouching == on:
		return
	crouching = on
	if not on:
		crouch_pinned = false
	if _body_shape:
		var h := body_height()
		_body_shape.size = Vector2(BODY_SIZE.x, h)
		_body_node.position = Vector2(0, -h * 0.5)


# --- Collision helpers ----------------------------------------------------------

## A current pressing you into a wall stops bearing you up (pass 224): you slide
## down the face. It had held you there, hanging still against a doorway's
## lintel with the opening a few px below, until you thought to hold Down.
func _pinned_by_wind() -> bool:
	return test_move(global_transform, Vector2(signf(wind), 0))


func _apply_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var motion := Vector2(0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	for i in range(1, tuning.corner_correction_px + 1):
		for s in [1, -1]:
			var offset := Vector2((i + CORRECTION_SLOP) * s, 0)
			if not test_move(global_transform, offset) and not test_move(global_transform.translated(offset), motion):
				global_position += offset
				return


func _apply_ledge_correction(delta: float, on_floor: bool) -> void:
	if on_floor or velocity.y < 0.0 or velocity.x == 0.0:
		return
	# A wall slide holds you against the wall at a crawl, so probe as far as the
	# wall contact does, and step onto the lip as well as up (pass 107: with the
	# Climbing Glove a clipped ledge used to catch you in a slide instead).
	var motion := Vector2(wall_dir * 2.0, 0) if is_wall_sliding else Vector2(velocity.x * delta, 0)
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, motion, hit):
		_apply_one_way_ledge_correction(motion)
		return
	if absf(hit.get_normal().x) <= WALL_NORMAL:
		# A slope's face: the physics walks you up it; there is no lip to clip.
		return
	for i in range(1, tuning.ledge_correction_px + 1):
		var up := Vector2(0, -(i + CORRECTION_SLOP))
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), motion):
			global_position += up
			if is_wall_sliding:
				global_position += motion
				is_wall_sliding = false
			return


## The ledge correction's mirror (pass 139): moving across in the air, level or
## falling (a dash, a jump past its peak), the head clips the top edge of an
## opening by a few px and the body would stop dead on it. Nudged down by up to
## head_correction_px, it slides into the gap instead. A wall the body meets
## below the head (a real wall) is left alone: lowered, it still blocks.
func _apply_head_correction(delta: float, on_floor: bool) -> void:
	if on_floor or velocity.y < 0.0 or velocity.x == 0.0 or is_wall_sliding:
		return
	var motion := Vector2(velocity.x * delta, 0)
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, motion, hit) or absf(hit.get_normal().x) <= WALL_NORMAL:
		return
	for i in range(1, tuning.head_correction_px + 1):
		var down := Vector2(0, i + CORRECTION_SLOP)
		if not test_move(global_transform, down) and not test_move(global_transform.translated(down), motion):
			global_position += down
			return


## A one-way platform has no side to bump, so the probe above misses its lip and
## a fall that clips it by a pixel went straight past (pass 111). Here the lip is
## found from above instead: lifted by i px and moved on, the feet would come down
## on something within i px, where unmoved they would not (so a drop-through
## isn't lifted straight back up), and unlifted they pass through it.
func _apply_one_way_ledge_correction(motion: Vector2) -> void:
	var gt := global_transform
	if test_move(gt.translated(motion), Vector2(0, 0.5)):
		return
	for i in range(1, tuning.ledge_correction_px + 1):
		var lift := i + CORRECTION_SLOP
		var up := Vector2(0, -lift)
		var down := Vector2(0, lift + 0.5)
		if test_move(gt, up) or test_move(gt.translated(up), motion):
			return
		if test_move(gt.translated(up + motion), down) and not test_move(gt.translated(up), down):
			global_position += up
			return


func _after_move(pre_velocity: Vector2, _delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		_peak_fall_speed = maxf(_peak_fall_speed, velocity.y)
		_air_top_y = minf(_air_top_y, global_position.y)
	if on_floor and not _was_on_floor:
		var impact := maxf(_peak_fall_speed, pre_velocity.y)
		var k := clampf(impact / tuning.max_fall_speed, 0.0, 1.0)
		visual.squash_for("land", k)
		if impact > 120.0:
			_spawn_dust(Vector2.ZERO, "land")
			Sfx.play("land", 0.08, lerpf(-8.0, 0.0, k))
			_footstep(lerpf(-10.0, -4.0, k))
		# Only a real drop thuds; an ordinary jump lands without a shake.
		if global_position.y - _air_top_y >= BIG_DROP and impact > 450.0:
			Feel.add_trauma(0.12)
			Feel.rumble(0.35, 0.15, 0.08)
		landed.emit(impact)
		_peak_fall_speed = 0.0
		_air_top_y = INF
	if on_floor and absf(velocity.x) > 40.0 and _step_timer <= 0.0:
		# A walk steps slower than a run (pass 183).
		_step_timer = 0.26 * clampf(tuning.run_speed / absf(velocity.x), 1.0, 1.6)
		_footstep(-10.0)
	if on_floor and not _hazard_near() and not _on_fleeting_ground():
		safe_position = global_position
	_was_on_floor = on_floor
	visual.position.y = _slope_sink(on_floor)


## On a slope the box rests on its downhill corner, up to half its width above
## the slope under its middle, so the sprite is drawn down onto the slope
## (design bible 6.1, pass 115). The body itself doesn't move.
func _slope_sink(on_floor: bool) -> float:
	if not on_floor or absf(get_floor_normal().x) < 0.1:
		return 0.0
	var reach := BODY_SIZE.x * 0.5 + 1.0
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, reach), LAYER_WORLD, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	return clampf(hit.position.y - global_position.y, 0.0, BODY_SIZE.x * 0.5)


## Plays the step sound for the ground underfoot (design bible 11), falling back
## to the plain step outside a room.
func _footstep(volume_db: float) -> void:
	var surface := _ground()
	Sfx.play("step_" + surface if surface != "" else "step", 0.15, volume_db)
	footstep.emit(surface)


# --- Shield, potion and spells -------------------------------------------------

func _update_block() -> void:
	if not has_shield:
		is_blocking = false
		return
	if input.block_pressed:
		_parry_timer = combat.parry_window
	if not input.block_held:
		guard_broken = false
	is_blocking = input.block_held and not guard_broken and not is_dashing and not is_attacking and not is_drinking and try_stand()


func _update_drink(delta: float, on_floor: bool) -> void:
	if is_drinking:
		if not on_floor or is_dashing:
			_drink_timer = 0.0
			return
		_drink_timer -= delta
		if _drink_timer <= 0.0:
			hp = mini(hp + combat.flask_heal, max_hp)
			flask_charges -= 1
			_spawn_dust(Vector2(0, -20), "heal")
			Sfx.play("heal")
			health_changed.emit(hp, max_hp)
		return
	if input.heal_pressed and flask_charges <= 0:
		# An empty flask is heard (pass 286): the cork pulls on nothing, so a
		# press in a tight spot isn't met with silence. Shrines refill it.
		Sfx.play("flask_empty", 0.0, -2.0)
		return
	if input.heal_pressed and flask_charges > 0 and on_floor and hp < max_hp and not is_attacking and not is_dashing:
		_drink_timer = combat.drink_time * drink_mult
		Sfx.play("drink")


## Next Spell: equips the next spell you own, in `Spells.ORDER`.
func _try_cycle_spell() -> void:
	if not input.spell_next_pressed:
		return
	var next := Spells.next_owned(equipped_spell, abilities)
	if next == equipped_spell:
		if not abilities.get(next, false):
			Sfx.play("fizzle")
		return
	equipped_spell = next
	Sfx.play("blip", 0.0, -2.0)
	GameState.toast.emit("Spell: " + String(Spells.DATA[next].name))


## The Stillstone (design bible A8): stop time for a moment.
func _try_stillstone() -> void:
	if not input.stillstone_pressed or not abilities.get("stillstone", false):
		return
	if not TimeStop.start(TIME_THIEF_EXTRA if time_thief else 0.0):
		Sfx.play("fizzle")
		return
	Sfx.play("stillstone")
	Feel.add_trauma(0.1)
	_spawn_dust(Vector2(0, -24), "parry")


## The glass running out (pass 230): a tick at each of its last quarter-seconds
## and a rush as time runs again, so the ear knows when frozen footholds melt
## and held shots fly on. `was` and `left` are TimeStop.left before and after
## this frame's tick.
func _glass_cues(was: float, left: float) -> void:
	if was <= 0.0:
		return
	if left <= 0.0:
		Sfx.play(GLASS_END_SOUND, 0.0)
		return
	for k in range(1, GLASS_TICKS + 1):
		if was > k * GLASS_TICK and left <= k * GLASS_TICK:
			Sfx.play(GLASS_TICK_SOUND, 0.0)


## The Rune Dagger (pass 184, bible 5.2): one in flight at a time. When its
## flight ends it breaks into rune light and reforms at your hip RuneDagger.RETURN
## later, so it never costs magic and is never lost.
func dagger_ready() -> bool:
	return not is_instance_valid(rune_dagger) and _dagger_back <= 0.0


func dagger_spent() -> void:
	rune_dagger = null
	_dagger_back = RuneDagger.RETURN


func _try_throw(delta: float) -> void:
	if rune_dagger != null and not is_instance_valid(rune_dagger):
		# Left behind in another room: it comes home all the same.
		dagger_spent()
	if _dagger_back > 0.0:
		_dagger_back -= delta
		if _dagger_back <= 0.0:
			Sfx.play("dagger_return", 0.1, -4.0)
			_spawn_dust(Vector2(facing * -4, -16), "parry")
	# Buffered like a swing (pass 192): a press while you can't throw yet (the
	# end of a swing or a dash, the dagger still reforming) goes the first frame
	# you can.
	if _throw_buffer_timer <= 0.0 or not abilities.get("rune_dagger", false):
		return
	if not GameState.offhand_free():
		# The shield is on the throwing arm (the off hand holds one or the other).
		_throw_buffer_timer = 0.0
		return
	if is_dashing or is_drinking or is_blocking or is_attacking or is_hurt or not dagger_ready():
		return
	_throw_buffer_timer = 0.0
	throw_dagger()


func throw_dagger() -> void:
	var d := RuneDagger.new()
	d.thrower = self
	d.damage = roundi(RuneDagger.DAMAGE * melee_mult)
	d.dir = Vector2.UP if input.up else Vector2(facing, 0)
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(facing * 10, -(LOW_SHOT_HEIGHT if crouching else THROW_HEIGHT))
	rune_dagger = d
	throws += 1
	visual.squash_for("throw")
	Sfx.play("dagger_throw")


func _try_cast() -> void:
	if not input.spell_pressed or _cast_cooldown > 0.0 or is_dashing or is_drinking or is_blocking:
		return
	if not abilities.get(equipped_spell, false):
		return
	var cost := spell_cost(equipped_spell)
	if mp < cost:
		Sfx.play("fizzle")
		return
	mp -= cost
	_cast_cooldown = combat.cast_cooldown
	for bolt in Spells.cast_all(equipped_spell, self):
		get_parent().add_child(bolt)
		# Crouched, a bolt leaves low, along the floor (bible 6.15).
		bolt.global_position = global_position + Vector2(facing * 12, -(LOW_SHOT_HEIGHT if crouching else CAST_HEIGHT))
	visual.squash_for("cast")
	Sfx.play("cast")


## Sounds the moment a field takes hold of you (pass 137, bible 13.3): a gust
## when a wind current or updraft catches you, a rising shimmer as a pocket of
## wrong gravity lifts your weight, and a falling hum and thud as it returns.
func _field_cues(delta: float) -> void:
	_wind_cue_wait = maxf(_wind_cue_wait - delta, 0.0)
	_drift_cue_wait = maxf(_drift_cue_wait - delta, 0.0)
	var in_wind := wind != 0.0 or updraft > 0.0
	if in_wind and not _was_in_wind and _wind_cue_wait <= 0.0:
		Sfx.play("wind_catch", 0.08, -2.0)
		_wind_cue_wait = FIELD_CUE_GAP
	var drifting := gravity_scale < 1.0
	if drifting != _was_drifting and _drift_cue_wait <= 0.0:
		Sfx.play("drift_in" if drifting else "drift_out", 0.05, -2.0)
		_drift_cue_wait = FIELD_CUE_GAP
	_was_in_wind = in_wind
	_was_drifting = drifting


## A foe's guard turned a blow (`Enemy._on_blocked`). Only the blade's own
## blow pushes you back, harder than a landed cut (pass 442): until then the
## push met every turned blow, so a Deluge cast at a Rot Dwarf's shield across
## the room shoved the caster, while a turned slash was pushed only by its
## ordinary recoil, which overwrote it.
func blade_turned() -> void:
	if _striking:
		_blade_turned = true
		_turned_now = true


## The MP a spell costs you now: Thrift for every spell, and Deep Blight
## halves Witherbloom on top.
func spell_cost(id: String) -> float:
	var cost := Spells.cost(id) * spell_cost_mult
	if id == "death" and ring_of_death:
		cost *= RING_OF_DEATH_MULT
	return cost


# --- Damage ---------------------------------------------------------------------

func _check_hazards() -> void:
	if invulnerable or dead:
		return
	var body := Rect2(global_position + Vector2(-BODY_SIZE.x * 0.5 + 1, -BODY_SIZE.y + 2), BODY_SIZE - Vector2(2, 3))
	for c: Variant in _query_rect(body, LAYER_HAZARD | LAYER_ENEMY):
		if c.is_in_group("hazard"):
			take_damage(combat.hazard_damage, true)
			return
		if c.is_in_group("enemy") and "contact_damage" in c and c.contact_damage > 0 and not c.dead:
			receive_attack(c.contact_damage, c, false)
			return


## Standing on footing that can go, so never a safe place to be set back to.
## A foothold of stilled water melts when time runs again (pass 162). Since
## pass 288 that is any floor but the room's own tiles: a cracked block you
## break, a Bark Knight's rooted lance, a crystal, a gate or a raft. Set back
## onto a block that was gone, you fell onto the spikes it had hidden, and
## again, a mask each time.
func _on_fleeting_ground() -> bool:
	for i in get_slide_collision_count():
		var k := get_slide_collision(i)
		if k.get_normal().y < -0.5 and not k.get_collider() is TileMapLayer:
			return true
		# A tile just torn away (pass 292) still holds you for a frame, until
		# the layer rebuilds its collision: it is no footing either.
		var layer := k.get_collider() as TileMapLayer
		if k.get_normal().y < -0.5 and layer != null:
			# A contact on a ledge's corner lies on the line between two cells
			# (pass 295): it is footing if the tile on either side is still there.
			var at := layer.to_local(k.get_position() + Vector2(0, 1))
			if layer.get_cell_source_id(layer.local_to_map(at + Vector2(-0.5, 0))) == -1 \
					and layer.get_cell_source_id(layer.local_to_map(at + Vector2(0.5, 0))) == -1:
				return true
	return false


## A boss, or a piece of one (BossSegment).
static func _is_boss(node: Object) -> bool:
	if node is BossSegment:
		node = (node as BossSegment).boss
	return node is Node and (node as Node).is_in_group("boss")


func _hazard_near() -> bool:
	var area := Rect2(global_position + Vector2(-20, -BODY_SIZE.y), Vector2(40, BODY_SIZE.y + 6))
	for c: Variant in _query_rect(area, LAYER_HAZARD):
		if c.is_in_group("hazard"):
			return true
	return false


## Entry point for every enemy attack. Resolves parry, guard or a clean hit.
## Returns "parried", "guarded", "hit" or "ignored".
func receive_attack(damage: int, source: Node2D, parryable := true) -> String:
	if dead:
		return "ignored"
	damage = _threatened(damage, source)
	var src_dir := int(signf(source.global_position.x - global_position.x))
	var from_front := src_dir == 0 or src_dir == facing
	var catches := reflects and source.is_in_group("small_projectile")
	if (parryable or catches) and _parry_timer > 0.0 and from_front:
		_parry_timer = 0.0
		_invuln_timer = maxf(_invuln_timer, 0.25)
		mp = minf(mp + combat.parry_mp_gain, max_mp)
		Feel.hitstop(combat.parry_hitstop)
		Feel.add_trauma(0.2)
		Feel.rumble(0.6, 0.2, 0.1)
		Sfx.play("parry")
		_spawn_dust(Vector2(facing * 12, -24), "parry")
		visual.squash_for("parry")
		if source.has_method("stagger"):
			# Feathers, gears and bolts turn back on their own.
			source.stagger()
		if riposte and source.is_in_group("enemy") and source.has_method("take_hit"):
			_riposte(source)
		elif catches:
			ReflectedShot.spawn(self, source, source.get("tint") if source.get("tint") is Color else ReflectedShot.GOLD)
			Sfx.play("zap", 0.1, 6.0)
		return "parried"
	if invulnerable:
		return "ignored"
	if magic_ward > 0.0 and source.is_in_group(MAGIC):
		damage = maxi(roundi(damage * (1.0 - magic_ward)), 1)
		Sfx.play(WARD_SOUND, 0.05)
	var kind := DamageKind.of(source)
	if kind != DamageKind.PHYSICAL:
		damage = DamageKind.reduce(damage, kind, resist)
		if damage <= 0:
			# Whole resistance is immunity: the blow is turned outright.
			Sfx.play(WARD_SOUND, 0.05)
			return "ignored"
	_hurt_kind = kind
	var knock := -src_dir if src_dir != 0 else -facing
	if is_blocking and from_front and mp >= combat.guard_mp_cost:
		mp -= combat.guard_mp_cost
		_spawn_dust(Vector2(facing * 10, -24), "guard")
		Sfx.play("guard")
		take_damage(int(round(damage * (1.0 - guard_reduction))), false, knock)
		_hurt_kind = DamageKind.PHYSICAL
		return "guarded"
	if is_blocking and from_front:
		# Too little MP to pay for the guard: it breaks, loud and plain, and the
		# blow lands whole. The shield stays down until Block is let go, so a
		# held guard never seems to stand when it can't (pass 242).
		guard_broken = true
		is_blocking = false
		_spawn_dust(Vector2(facing * 10, -24), "guard")
		Sfx.play(GUARD_BREAK_SOUND)
		Feel.add_trauma(0.25)
	take_damage(damage, false, knock)
	_hurt_kind = DamageKind.PHYSICAL
	return "hit"


## A foe's or a boss's blow, scaled by the room's threat (design bible 5.5,
## passes 194 and 196). A world hazard such as a fire seal strikes as written.
func _threatened(damage: int, source: Node2D) -> int:
	if source.is_in_group("fire_seal"):
		return damage
	var room := get_tree().get_first_node_in_group("room") as Room
	return damage if room == null else roundi(damage * room.threat())


## Riposte (skill): the parry's answer, a heavy cut at the foe that swung.
func _riposte(foe: Node2D) -> void:
	var fx := SlashFx.new()
	fx.setup("side", facing, 3, true, 1.0 + arc_bonus / SLASH_SIZE.y)
	add_child(fx)
	foe.take_hit(roundi(heavy_damage * blade_mult()), Vector2(facing, 0) * 1.8)
	var at: Vector2 = foe.center() if foe.has_method("center") else foe.global_position
	at.x -= facing * minf(_half_extent(foe, Vector2.RIGHT), SPARK_EDGE_MAX)
	HitSpark.spawn(get_parent(), at, Vector2(facing, 0), HEAVY_SPARK)
	Sfx.play("heavy", 0.05)
	ripostes += 1


func take_damage(amount: int, from_hazard := false, knock_dir := 0, kind := "") -> void:
	if invulnerable or dead:
		return
	if kind != "" and kind != DamageKind.PHYSICAL:
		# A blow with no source (a fog, a floor) names its kind here.
		amount = DamageKind.reduce(amount, kind, resist)
		if amount <= 0:
			return
		_hurt_kind = kind
	if is_inside_tree() and BossArena.any_falling(get_tree()):
		# The killing blow has landed: the win can't be lost to what is still
		# in the air while the guardian falls (pass 239).
		return
	if from_hazard and Trials.active():
		# A Ringreader Trial (bible 3.1): a miss costs time, never health.
		Sfx.play("hurt", 0.05, -4.0)
		visual.flash_hurt()
		_invuln_timer = hurt_invuln()
		set_back()
		return
	if defense > 0.0:
		amount = maxi(1, roundi(amount * (1.0 - defense)))
	if last_stand and hp < max_hp * LAST_STAND_BELOW:
		amount = maxi(1, roundi(amount * LAST_STAND_TAKEN))
	if second_wind and not second_wind_used and amount >= hp and hp > 1:
		# Second Wind (skill): the killing blow leaves you standing at 1 HP.
		amount = hp - 1
		second_wind_used = true
		GameState.toast.emit("Second Wind!")
		Sfx.play("heal", 0.0)
		_spawn_dust(Vector2(0, -16), "heal")
	if BossRush.active() and amount >= hp and elixirs <= 0:
		# A boss rush (bible 11): the blow that would kill you ends the rush
		# (an Amber Draught still saves you first).
		var world := get_tree().get_first_node_in_group("world") as World
		if world != null:
			_invuln_timer = hurt_invuln()
			BossRush.fall(world, self)
			return
	hp -= amount
	var number := DamageNumber.spawn(get_parent(), global_position + Vector2(0, -44), amount, "hurt")
	if number != null and DamageKind.COLORS.has(_hurt_kind):
		number.tint = DamageKind.COLORS[_hurt_kind]
	_hurt_kind = DamageKind.PHYSICAL
	_invuln_timer = hurt_invuln()
	if on_ladder:
		# A blow knocks you off the rungs.
		_leave_ladder()
	_drink_timer = 0.0
	_attack_timer = 0.0
	_thrust_charge = 0.0
	_thrust_lunge = false
	_dash_timer = 0.0
	Feel.hitstop(combat.hurt_hitstop)
	Feel.add_trauma(0.35)
	Feel.rumble(0.5, 0.6, 0.2)
	Sfx.play("hurt")
	if amount >= GameHud.MASK_HP:
		# A blow that costs a whole mask (design bible 5.3, pass 198): a body
		# thud under the yelp, so the deep zones' heavy hits read by ear.
		Sfx.play("hurt_heavy", 0.04)
	visual.flash_hurt()
	if hp <= 0 and elixirs > 0:
		_drink_elixir()
		return
	if hp <= 0:
		hp = 0
		health_changed.emit(hp, max_hp)
		# The purse is left on ground you can come back to (bible 5.4, pass 293):
		# where you fell if that was the room's own floor, else the last safe
		# spot. Killed in the air over a torn pit, it had lain in the pit, and
		# the floor came back whole around it when the room loaded again.
		var on_ground := is_on_floor() and not _hazard_near() and not _on_fleeting_ground()
		_die(global_position if on_ground and not from_hazard else safe_position)
		return
	if from_hazard:
		set_back()
	elif knock_dir != 0:
		velocity = Vector2(knock_dir * combat.hurt_knockback.x, -combat.hurt_knockback.y)
		_control_lock_timer = combat.hurt_control_lock
		_control_blend_timer = 0.0
	health_changed.emit(hp, max_hp)


## Rubs on an Barkbalm (from the pause menu): nothing can hurt you for
## OINTMENT_TIME seconds. False if you have none or one is already on.
func use_ointment() -> bool:
	if ointments <= 0 or _ointment_timer > 0.0 or dead:
		return false
	ointments -= 1
	_ointment_timer = OINTMENT_TIME
	Sfx.play("heal", 0.0)
	GameState.toast.emit("The Barkbalm shimmers on your skin.")
	return true


## What a blade hit is multiplied by: the skill tree's melee_mult, the War
## Glove's while it lasts, and the Acorn Charm's once found (pass 201).
func blade_mult() -> float:
	var pendant := combat.pendant_mult if abilities.get("pendant", false) else 1.0
	return melee_mult * pendant * (combat.war_glove_mult if _glove_timer > 0.0 else 1.0)


## Pulls on a War Glove (a rare drop, design bible 7): combat.war_glove_time
## seconds of harder blows. Another one found while it lasts starts it over.
func put_on_glove() -> void:
	if dead:
		return
	_glove_timer = combat.war_glove_time
	_glove_spark = 0.0
	Sfx.play("item", 0.0, -4.0)
	GameState.toast.emit("A War Glove! Your blows land half again as hard.")


func _tick_glove(delta: float) -> void:
	_glove_timer -= delta
	_glove_spark -= delta
	if _glove_spark <= 0.0 and _glove_timer > 0.0:
		# Red sparks rise off the sword hand while it lasts.
		_glove_spark = 0.18
		var d := Dust.new()
		d.setup("might")
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(facing * 7, -20)
	if _glove_timer <= 0.0:
		GameState.toast.emit("The War Glove's strength fades.")


## Drinks in poison: for POISON_TIME seconds you lose POISON_DAMAGE health
## every POISON_TICK, down to 1, scaled by the room's threat like a foe's blow
## (bible 7, pass 306). An Barkbalm keeps it off. False if it didn't take.
func poison() -> bool:
	if dead or _ointment_timer > 0.0:
		return false
	var room := get_tree().get_first_node_in_group("room") as Room
	_poison_damage = POISON_DAMAGE if room == null else roundi(POISON_DAMAGE * room.threat())
	_poison_timer = POISON_TIME
	_poison_tick = POISON_TICK
	return true


## Bread, a shrine or the Ringreader clears poison.
## A level-up is a moment (design bible 5.6): the world holds its breath for
## LEVEL_UP_PAUSE, the hero glows, and health and mana are filled at once.
const LEVEL_UP_PAUSE := 0.18

func _on_leveled_up(_rank: int) -> void:
	if dead:
		return
	hp = max_hp
	mp = max_mp
	health_changed.emit(hp, max_hp)
	Feel.hitstop(LEVEL_UP_PAUSE)
	if visual != null:
		visual.flash_level_up()


func cure_poison() -> void:
	_poison_timer = 0.0


func _tick_poison(delta: float) -> void:
	_poison_timer -= delta
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick += POISON_TICK
		if not dead and _ointment_timer <= 0.0 and hp > 1:
			var before := hp
			hp = maxi(1, hp - _poison_damage)
			# With damage numbers on, each tick shows what it took, in the
			# masks' sick green (pass 309): it varies with the zone (pass 306).
			DamageNumber.spawn(get_parent(), global_position + Vector2(0, -44), before - hp, "poison")
			# And a small wet glug (pass 310): a tick was the one loss of health
			# with no sound.
			Sfx.play("poison_tick", 0.08, -4.0)
			health_changed.emit(hp, max_hp)
	if _poison_timer <= 0.0:
		GameState.toast.emit("The poison fades.")


## Dying with an Amber Draught: it is used up and you rise where you fell, fully
## healed and with full magic, as the original's manual has it: "Medicine that
## will restore your magic and power." (bible 5.2, pass 345)
func _drink_elixir() -> void:
	elixirs -= 1
	hp = max_hp
	mp = max_mp
	_invuln_timer = hurt_invuln() * 2.0
	velocity = Vector2(0, -180)
	Feel.slowmo(0.4, 0.6)
	GameState.flash.emit(0.6)
	Sfx.play("heal", 0.0)
	var d := Dust.new()
	d.setup("heal")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -20)
	GameState.toast.emit("The Amber Draught burns. You rise again.")
	health_changed.emit(hp, max_hp)


func _die(where: Vector2) -> void:
	dead = true
	_dead_timer = combat.respawn_delay
	velocity = Vector2.ZERO
	var drop := int(floor(gold * combat.death_gold_fraction))
	if is_instance_valid(purse):
		purse.queue_free()
	purse = null
	if drop > 0:
		gold -= drop
		purse = GoldPurse.new()
		purse.value = drop
		get_parent().add_child(purse)
		purse.global_position = where
	var d := Dust.new()
	d.setup("debris")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -20)
	Feel.hitstop(combat.death_hitstop)
	Feel.add_trauma(0.5)
	Sfx.play("death")
	died.emit()


func _respawn() -> void:
	dead = false
	_poison_timer = 0.0
	_glove_timer = 0.0
	_thrust_charge = 0.0
	second_wind_used = false
	hp = max_hp
	mp = max_mp
	flask_charges = flask_max
	if respawn_handler.is_valid():
		respawn_handler.call()
	else:
		teleport(spawn_point)
	_invuln_timer = 1.0
	health_changed.emit(hp, max_hp)
	respawned.emit()


## Adds gold. Found gold (coins) gets the Gold Sense bonus; returned gold doesn't.
func add_gold(amount: int, found := false) -> void:
	if not found:
		gold += amount
		return
	var g := amount * gold_mult + _gold_frac
	var whole := floori(g)
	_gold_frac = g - whole
	gold += whole


## Refills health, magic and potion charges (save shrines, the Ringreader).
func restore() -> void:
	_poison_timer = 0.0
	second_wind_used = false
	hp = max_hp
	mp = max_mp
	flask_charges = flask_max
	health_changed.emit(hp, max_hp)


## Pressing Up on the ground next to an interactable (shrine, sign, NPC, door)
## uses it. Returns true if something was used this frame.
func _try_interact(on_floor: bool) -> bool:
	if not input.up_pressed or not on_floor or is_attacking or is_dashing or is_drinking:
		return false
	var best: Node2D = null
	var best_dist := INF
	for n: Node in get_tree().get_nodes_in_group("interactable"):
		var it := n as Node2D
		if it == null or not it.has_method("interact") or not can_reach(it):
			continue
		var d := absf(it.global_position.x - global_position.x)
		if d < best_dist:
			best = it
			best_dist = d
	if best == null:
		return false
	velocity.x = 0.0
	best.call("interact", self)
	return true


## True if `node` is close enough to interact with (about one tile either side).
func can_reach(node: Node2D) -> bool:
	var d := node.global_position - global_position
	return absf(d.x) <= 22.0 and absf(d.y) <= 24.0


## Puts you back on the last safe ground (bible 6.13). It is a fresh start
## (pass 296): a jump, dash, swing or throw pressed on the way into the hazard,
## and the ledge's grace, would fire on arrival with no press of your own.
func set_back() -> void:
	teleport(safe_position)
	forget_buffers()
	_coyote_timer = 0.0
	_wall_coyote_timer = 0.0


## Drops every buffered press (a jump, dash, swing or throw waiting for its
## moment), so a press made before a hold or a pause can't fire after it.
func forget_buffers() -> void:
	_jump_buffer_timer = 0.0
	_dash_buffer_timer = 0.0
	_attack_buffer_timer = 0.0
	_throw_buffer_timer = 0.0


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	on_ladder = false
	_set_crouch(false)
	_dash_timer = 0.0
	_attack_timer = 0.0
	_drink_timer = 0.0
	reset_physics_interpolation()
	if scarf:
		scarf.snap()
	if cloak:
		cloak.snap()
	_refresh_air_moves()


## Puts you in the next room at a door's far side, moving at `vel` (pass 443).
## A dash taken through a side door goes on there for the time it had left.
## Any other door ends it as a dash ends, at a run and on its cooldown.
## `teleport` alone had cut the dash at the door with no cooldown, and the
## World then gave back its 380 px/s, so the hero skidded into the room at
## dash speed for 8 frames without the dash, and could dash again at once.
func arrive_through_door(pos: Vector2, vel: Vector2, side: bool) -> void:
	var dash_left := _dash_timer if is_dashing else 0.0
	teleport(pos)
	velocity = vel
	if dash_left <= 0.0:
		return
	if side:
		_dash_timer = dash_left
	else:
		_dash_cooldown = tuning.ground_dash_cooldown
		velocity.x = clampf(velocity.x, -tuning.run_speed, tuning.run_speed)


# --- Effects --------------------------------------------------------------------

func _spawn_run_dust() -> void:
	if _dust_timer > 0.0:
		return
	_dust_timer = 0.1
	_spawn_dust(Vector2(-facing * 4, 0), "run")


func _spawn_dust(offset: Vector2, kind: String) -> void:
	if get_parent() == null:
		return
	var d := Dust.new()
	var ground := _ground() if kind in Dust.GROUND else ""
	d.setup(kind, facing, ground)
	get_parent().add_child(d)
	d.global_position = global_position + offset
	if ground == "wade":
		# Spray leaps from the water's surface, not from the floor under it.
		var room := get_tree().get_first_node_in_group("room") as Room
		d.global_position.y = room.to_global(Vector2(0, room.tide.row * Room.TILE)).y


## The ground underfoot (`Room.surface_at`), or "" outside a room or in mid-air.
func _ground() -> String:
	var room := get_tree().get_first_node_in_group("room") as Room if is_inside_tree() else null
	return room.surface_at(global_position + Vector2(0, 2)) if room != null else ""
