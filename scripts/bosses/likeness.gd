class_name Likeness
extends Enemy
## the Likeness, the Mirror (design bible 8.8): a shadow copy of the player,
## made from every fight the Everbloom has watched. It waits before the gate of
## the Evercrown as your reflection: the hall is mirrored down its middle, and the
## shadow stands where you would stand on the far side of the glass.
##
## Phase 1, the mirror: it does what you did DELAY seconds ago, mirrored. Walk
## left and it walks right; jump and it jumps. Swing and it swings back at
## you DELAY later, its blade glinting for SWING_TELL first, so a blow you land
## on it comes back at you: step away or parry the echo, and a parried echo
## leaves it reeling. Only where you meet at the mirror line are you in reach
## of each other. Hold still too long and it steps through the glass to cut
## at you from behind, rising out of the floor beside you with its blade
## raised (the tell) before it strikes.
##
## Phase 2 (below half), its own: the mirror shatters and the shadow steps out
## of the glass to fight as you would, with the skill tree branch you have put
## the most into (Blade on a tie or an empty tree):
##   Blade: it walks you down and cuts twice, then lunges with a heavy blow.
##   Arcana: it keeps its distance and casts shadow bolts; parry one and it
##     flies back at the shadow. Come close and it cuts once.
##   Wanderer: it air-dashes through you, and once, low on health, stops to
##     drink a draught that a blow can spill.
## Every blow has a tell of at least MIN_TELEGRAPH, and a parried cut, heavy or
## dash leaves it reeling.
##
## Phase 3 (below a fifth), two of you: it splits in two, and the two come on
## together, both fighting as in phase 2. Only the real one casts a reflection
## in the polished floor. Strike the false one and it swells (BURST_TELL) and
## bursts, hurting you if you stay beside it; the real one splits again a
## little later.

signal defeated

const DISPLAY_NAME := "The Likeness"
const EPITHET := "Kept by the Glass"
const MAX_HP := 320
## Health fractions where later phases begin: below half it breaks the mirror.
const PHASES := [0.5, 0.2]
## How far behind you the reflection runs (s).
const DELAY := 0.6
## How long its blade glints before an echoed swing lands (within DELAY).
const SWING_TELL := 0.4
const SWING_DAMAGE := 14
const SWING_TIME := 0.15
## Hold still this long and it comes through the mirror after you.
const STILL_TIME := 2.2
const STILL_SPEED := 20.0
## Sinking into the floor's reflection, untouchable.
const SINK_TIME := 0.5
## Risen beside you, blade raised: the tell before the cut.
const RISE_TELL := 0.45
## Where it rises, behind you.
const BEHIND := 30.0
const RECOVER := 0.6
const BLINK_TIME := 0.35
const STAGGER := 1.2
const INTRO_TIME := 1.2
## Phase 2: the mirror shatters, untouchable this long.
const SHATTER_TIME := 1.0
const WALK := 96.0
const BLADE_RANGE := 46.0
const CUT_TELL := 0.4
const HEAVY_TELL := 0.5
const HEAVY_DAMAGE := 20
const HEAVY_LUNGE := 220.0
const HEAVY_TIME := 0.2
const FREE_RECOVER := 0.6
## Arcana: how far it keeps from you, and its casting.
const KEEP := 150.0
const CAST_TELL := 0.5
const CAST_GAP := 1.4
## Wanderer: the air-dash through you, and its one draught.
const DASH_RANGE := 150.0
const DASH_TELL := 0.45
const DASH_SPEED := 380.0
const DASH_TIME := 0.4
const DASH_DAMAGE := 14
const DRAUGHT_AT := 0.25
const DRAUGHT_TIME := 0.8
const DRAUGHT_HEAL := 0.12
## Phase 3: splitting in two (both untouchable), the false one's burst, and how
## soon the real one splits again once the false one is gone.
const SPLIT_TIME := 0.8
const BURST_TELL := 0.45
const BURST_DAMAGE := 10
const BURST_SIZE := Vector2(72, 60)
const RESPLIT := 3.5
const DYING_TIME := 1.6

const SHADOW := Color("120a1c")
const SHADOW_LIGHT := Color("2e1f44")
const RIM := Color("9a5ae0")
const CRYSTAL := Color("e05ad0")
const CRYSTAL_LIGHT := Color("ffb8f0")
const EYE := Color("ffe0f8")

## The hall's interior in pixels; the mirror runs down its middle.
var arena := Rect2(16, 64, 928, 256)
## What the player did, oldest first: {t, pos, facing, anim, frame}.
var _history: Array[Dictionary] = []
## Echoes of the player's swings still to come: {at, kind}.
var _echoes: Array[Dictionary] = []
var _clock := 0.0
var _swings := -1
var _still := 0.0
var _anim := "idle"
var _frame := 0
## The echo being struck now ("" when none) and whether it has landed.
var _cut := ""
var _cut_time := 0.0
var _struck := false
var phase := 1
## The skill tree branch it fights with in phase 2.
var branch := "Blade"
var _cuts := 0
var _cast_wait := 0.0
var _drunk := false
var _spilled := false
## Phase 3: the false shadow (no reflection, no health of its own) and, on the
## real one, its current false double and the wait before splitting again.
var decoy := false
var real: Likeness
var double: Likeness
var _resplit := 0.0


func _init() -> void:
	max_hp = MAX_HP
	contact_damage = 10
	gold_min = 140
	gold_max = 180
	xp = 450
	body_size = Player.BODY_SIZE
	knockback = 0.0
	launchable = false
	uses_gravity = false
	state = "dormant"


func _ready() -> void:
	super._ready()
	collision_mask = Player.LAYER_WORLD if phase > 1 else 0
	if not decoy:
		add_to_group("boss")
	z_index = 1


## Starts the fight (called by the arena once the player is inside).
func begin() -> void:
	_record()
	_follow(true)
	set_state("intro")
	Sfx.play("wail", 0.0, -4.0)
	Feel.add_trauma(0.25)
	GameState.banner.emit(DISPLAY_NAME, EPITHET)


func health_fraction() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)


## The x of the mirror line down the middle of the hall.
func axis() -> float:
	return arena.get_center().x


## Where `pos` falls on the other side of the mirror.
func mirrored(pos: Vector2) -> Vector2:
	return Vector2(2.0 * axis() - pos.x, pos.y)


## True while it is copying you (not reeling, not out of the glass).
func mirroring() -> bool:
	return state in ["mirror", "echo"]


## Seconds until the next echoed swing lands, or INF.
func next_echo_in() -> float:
	return _echoes[0].at - _clock if not _echoes.is_empty() else INF


## True while its blade glints before a blow.
func telling() -> bool:
	if state in ["rise", "cut_tell", "heavy_tell", "cast_tell", "dash_tell", "burst_tell"]:
		return true
	return mirroring() and next_echo_in() <= SWING_TELL


## The skill tree branch the player has put the most into (Blade on a tie).
static func strongest_branch() -> String:
	var counts := {"Blade": 0, "Arcana": 0, "Wanderer": 0}
	for n: Dictionary in Skills.nodes():
		if GameState.has_skill(n.id) and counts.has(n.branch):
			counts[n.branch] += 1
	var best := "Blade"
	for b: String in ["Arcana", "Wanderer"]:
		if counts[b] > counts[best]:
			best = b
	return best


func _modify_damage(damage: int, _dir: Vector2) -> int:
	if state in ["dormant", "intro", "dying", "sink", "blink", "shatter", "split"]:
		return 0
	return damage


## True for the real shadow: the only one the floor reflects.
func reflects() -> bool:
	return not decoy


func take_hit(damage: int, dir: Vector2) -> void:
	if decoy:
		# The false one has no life to lose: struck, it swells and bursts.
		if state not in ["split", "burst_tell", "dying"]:
			_flash = 0.08
			velocity.x = 0.0
			_cut = ""
			set_state("burst_tell")
			Sfx.play("swell", 0.1, 3.0)
		return
	super.take_hit(damage, dir)
	_hitstun = 0.0
	if state == "drink" and not dead:
		_spilled = true
	if not dead and phase == 1 and health_fraction() <= PHASES[0]:
		_break_free()
	if not dead and phase == 2 and health_fraction() <= PHASES[1]:
		phase = 3
		_split()
		GameState.toast.emit("Your shadow splits in two. Only one of them casts a reflection.")


## Splits in two: the false double appears on your far side, and half the time
## the two trade places as they part, so only the reflection tells them apart.
func _split() -> void:
	_cut = ""
	_stagger = 0.0
	velocity = Vector2.ZERO
	set_state("split")
	Sfx.play("tell_charge", 0.05, -2.0)
	var p := player()
	var px := p.global_position.x if p != null else axis()
	var other := clampf(2.0 * px - global_position.x, arena.position.x + 16.0, arena.end.x - 16.0)
	if absf(other - global_position.x) < 40.0 or not _clear_at(Vector2(other, global_position.y)):
		# No room on your far side (too close, or in the wall): toward the middle instead.
		other = clampf(global_position.x + (80.0 if global_position.x < axis() else -80.0), arena.position.x + 16.0, arena.end.x - 16.0)
	var d := Likeness.new()
	d.decoy = true
	d.real = self
	d.phase = 3
	d.branch = branch
	d.arena = arena
	d.uses_gravity = true
	d.state = "split"
	d.contact_damage = contact_damage
	var here := global_position
	var there := Vector2(other, global_position.y)
	if randf() < 0.5:
		var swap := here
		here = there
		there = swap
	global_position = here
	get_parent().add_child(d)
	d.global_position = there
	d.reset_physics_interpolation()
	double = d
	for at: Vector2 in [here, there]:
		var dust := Dust.new()
		dust.setup("debris")
		get_parent().add_child(dust)
		dust.global_position = at + Vector2(0, -20)
	Sfx.play("wail", 0.05, 0.0)
	Feel.add_trauma(0.35)


## True when a body standing with its feet at `feet` would be out of the walls.
func _clear_at(feet: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = Player.LAYER_WORLD
	for y: float in [-4.0, -20.0, -36.0]:
		q.position = feet + Vector2(0, y)
		if not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
			return false
	return true


## The false double is gone: the real one splits again a little later.
func _double_gone() -> void:
	double = null
	_resplit = RESPLIT


## The false double bursts, hurting a player beside it.
func _burst() -> void:
	var c := center()
	hit_player_in_rect(Rect2(c - BURST_SIZE * 0.5, BURST_SIZE), BURST_DAMAGE, false)
	for i in 6:
		var dust := Dust.new()
		dust.setup("debris")
		get_parent().add_child(dust)
		dust.global_position = c + Vector2(randf_range(-14, 14), randf_range(-18, 18))
	Sfx.play("break", 0.1, 4.0)
	Feel.add_trauma(0.25)
	if is_instance_valid(real):
		real._double_gone()
	dead = true
	queue_free()


## Below half the mirror shatters and it steps out to fight on its own.
func _break_free() -> void:
	phase = 2
	branch = strongest_branch()
	_echoes.clear()
	_cut = ""
	_stagger = 0.0
	velocity = Vector2.ZERO
	uses_gravity = true
	collision_mask = Player.LAYER_WORLD
	set_state("shatter")
	Sfx.play("break", 0.05, 2.0)
	# The glass down the middle of the hall bursts.
	for i in 8:
		var d := Dust.new()
		d.setup("debris")
		get_parent().add_child(d)
		d.global_position = Vector2(axis(), arena.position.y + arena.size.y * (i + 0.5) / 8.0)
	Sfx.play("break", 0.0, 2.0)
	Sfx.play("wail", 0.05, -2.0)
	Feel.add_trauma(0.5)
	Feel.rumble(0.8, 0.6, 0.3)
	GameState.toast.emit("The mirror shatters. Your shadow fights with your %s." % branch.to_lower())


## A parried echo leaves it reeling: it stops copying you and stands open.
## Reeling from a parry, or spent after a blow of its own (pass 314): the cut
## from behind (recover) or any free blow, cast or dash (f_recover). A hero with
## no shield (the Rune Dagger in hand, or a two-hander) can't parry, and still
## needs a window for Executioner and Bloodletting.
func punishable() -> bool:
	return is_staggered() or (not decoy and state in ["recover", "f_recover"])


func stagger() -> void:
	if dead or state in ["dormant", "intro", "dying", "sink", "blink", "shatter"]:
		return
	super.stagger()
	_stagger = STAGGER
	velocity.x = -facing * 60.0
	_echoes.clear()
	_cut = ""


func _think(delta: float) -> void:
	_clock += delta
	_record()
	if phase >= 2:
		_think_free(delta)
		return
	match state:
		"dormant":
			pass
		"intro":
			_follow(false)
			if state_time >= INTRO_TIME:
				_echoes.clear()
				set_state("mirror")
		"idle":
			# Out of a stagger: back behind the glass.
			_blink_out()
		"mirror", "echo":
			velocity = Vector2.ZERO
			_follow(false)
			_strike_echoes(delta)
			if _still >= STILL_TIME and _cut == "":
				_still = 0.0
				_echoes.clear()
				set_state("sink")
				Sfx.play("wail", 0.1, -6.0)
		"sink":
			if state_time >= SINK_TIME:
				_rise_behind()
		"rise":
			face_player()
			if state_time >= RISE_TELL:
				_cut = "side"
				_cut_time = 0.0
				_struck = false
				Sfx.play("slash", 0.05, -2.0)
				set_state("cut")
		"cut":
			_strike(delta)
			if state_time >= SWING_TIME:
				_cut = ""
				set_state("recover")
		"recover":
			if state_time >= RECOVER:
				_blink_out()
		"blink":
			if state_time >= BLINK_TIME:
				_follow(true)
				_echoes.clear()
				_still = 0.0
				set_state("mirror")
		_:
			set_state("mirror")


## Notes what the player is doing this frame, and any new swing to echo.
func _record() -> void:
	var p := player()
	if p == null:
		return
	var vis := p.visual
	var anim := vis.anim if vis != null else "idle"
	var frame := vis.frame if vis != null else 0
	if not Sheet.has_anim(PlayerVisual.SHEET_NAME, anim):
		# A clip only the body sets have (the Rune Dagger's flick): the old
		# sheet's nearest, the cast's outthrust hand.
		anim = "cast"
		frame = 0
	elif vis != null and vis.sheet != PlayerVisual.SHEET_NAME:
		# A body set's clip has its own frame count: take the same point in the
		# old sheet's clip, which the shadow is drawn from.
		var mine: int = Sheet.get_sheet(vis.sheet).animations[anim].frames.size()
		var its: int = Sheet.get_sheet(PlayerVisual.SHEET_NAME).animations[anim].frames.size()
		frame = mini(frame * its / maxi(mine, 1), its - 1)
	_history.append({"t": _clock, "pos": p.global_position, "facing": p.facing, "anim": anim, "frame": frame})
	while _history.size() > 2 and _history[1].t <= _clock - DELAY:
		_history.pop_front()
	if _swings >= 0 and p.swing_count != _swings and state in ["intro", "mirror", "echo"]:
		_echoes.append({"at": _clock + DELAY, "kind": p.attack_kind})
	_swings = p.swing_count
	if mirroring() and p.velocity.length() < STILL_SPEED and not p.is_attacking:
		_still += get_physics_process_delta_time()
	else:
		_still = 0.0


## Takes up the place, facing and pose the player had DELAY ago, mirrored.
## Before DELAY has passed (or when `now`), it mirrors the present instead.
func _follow(now: bool) -> void:
	if _history.is_empty():
		return
	var h: Dictionary = _history[_history.size() - 1] if now else _history[0]
	global_position = mirrored(h.pos)
	facing = -int(h.facing)
	if _cut == "":
		_anim = h.anim
		_frame = h.frame


## Strikes back each swing the player made DELAY ago, from the mirrored spot.
func _strike_echoes(delta: float) -> void:
	if _cut != "":
		_strike(delta)
		if _cut_time >= SWING_TIME:
			_cut = ""
			set_state("mirror")
		return
	if not _echoes.is_empty() and _clock >= _echoes[0].at:
		var e: Dictionary = _echoes.pop_front()
		_cut = e.kind
		_cut_time = 0.0
		_struck = false
		set_state("echo")
		Sfx.play("slash", 0.1, -3.0)


func _strike(delta: float) -> void:
	_cut_time += delta
	if not _struck:
		_struck = hit_player_in_rect(blade_rect(), SWING_DAMAGE) != ""


## Where its blade bites: the player's own swing, mirrored.
func blade_rect() -> Rect2:
	var center: Vector2
	var size: Vector2
	match _cut:
		"down":
			size = Player.DOWN_STRIKE_SIZE
			center = Vector2(0, 8)
		"up":
			size = Player.UP_SLASH_SIZE
			center = Vector2(0, -body_size.y - 14)
		"low":
			# A crouch's low cut, echoed along the floor (bible 6.15).
			size = Vector2(Player.SLASH_SIZE.x, Player.LOW_SLASH_HEIGHT)
			center = Vector2(facing * (body_size.x * 0.5 + 16), -size.y * 0.5)
		_:
			size = Player.SLASH_SIZE
			center = Vector2(facing * (body_size.x * 0.5 + 16), -body_size.y * 0.55)
	return Rect2(global_position + center - size * 0.5, size)


## Up out of the floor just behind the player, blade raised.
func _rise_behind() -> void:
	var p := player()
	var x := global_position.x
	var y := global_position.y
	if p != null:
		x = clampf(p.global_position.x - p.facing * BEHIND, arena.position.x + 12.0, arena.end.x - 12.0)
		y = p.global_position.y
	global_position = Vector2(x, y)
	face_player()
	_anim = "slash1"
	_frame = 0
	set_state("rise")
	Sfx.play("swell", 0.1, -4.0)


## Sinks away and comes back up in the mirror.
func _blink_out() -> void:
	_cut = ""
	velocity = Vector2.ZERO
	set_state("blink")
	Sfx.play("whoosh", 0.1, -6.0)


## Phase 2: out of the glass, fighting with your strongest branch.
func _think_free(delta: float) -> void:
	if state not in ["heavy", "dash"]:
		velocity.x = 0.0
	_cast_wait -= delta
	var p := player()
	var dx := (p.global_position.x - global_position.x) if p != null else 0.0
	var dy := (p.global_position.y - global_position.y) if p != null else 0.0
	if phase == 3 and not decoy and not is_instance_valid(double):
		_resplit -= delta
		if _resplit <= 0.0 and state == "stalk":
			_split()
			return
	match state:
		"split":
			if state_time >= SPLIT_TIME and is_on_floor():
				set_state("stalk")
		"burst_tell":
			velocity.x = 0.0
			if state_time >= BURST_TELL:
				_burst()
		"shatter":
			if state_time >= SHATTER_TIME and is_on_floor():
				set_state("stalk")
		"idle", "stalk":
			if state == "idle":
				set_state("stalk")
			face_player()
			if branch == "Wanderer" and not _drunk and health_fraction() <= DRAUGHT_AT and absf(dx) > 80.0:
				_drunk = true
				_spilled = false
				set_state("drink")
				return
			var close := absf(dx) <= BLADE_RANGE and absf(dy) < 48.0
			match branch:
				"Arcana":
					if close:
						_tell("cut_tell")
					elif _cast_wait <= 0.0 and absf(dy) < 64.0:
						_tell("cast_tell")
					elif absf(dx) < KEEP - 24.0:
						velocity.x = -signf(dx) * WALK * 0.8
					elif absf(dx) > KEEP + 40.0:
						velocity.x = signf(dx) * WALK
				"Wanderer":
					if close:
						_tell("cut_tell")
					elif absf(dx) <= DASH_RANGE and absf(dy) < 48.0 and state_time > 0.3:
						_tell("dash_tell")
					else:
						velocity.x = signf(dx) * WALK
				_:
					if close:
						_cuts = 0
						_tell("cut_tell")
					else:
						velocity.x = signf(dx) * WALK
		"cut_tell":
			if state_time >= CUT_TELL:
				_swing("side", "f_cut")
		"f_cut":
			_strike(delta)
			if state_time >= SWING_TIME:
				_cut = ""
				_cuts += 1
				if branch == "Blade" and _cuts < 2:
					_tell("cut_tell")
				elif branch == "Blade":
					_tell("heavy_tell")
				else:
					set_state("f_recover")
		"heavy_tell":
			if state_time >= HEAVY_TELL:
				_swing("side", "heavy")
				velocity.x = facing * HEAVY_LUNGE
		"heavy":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if not _struck:
				_struck = hit_player_in_rect(blade_rect(), HEAVY_DAMAGE) != ""
			if state_time >= HEAVY_TIME:
				_cut = ""
				set_state("f_recover")
				Feel.add_trauma(0.15)
		"cast_tell":
			if state_time >= CAST_TELL:
				_cast()
				_cast_wait = CAST_GAP
				set_state("f_recover")
		"dash_tell":
			if state_time >= DASH_TELL:
				_struck = false
				velocity = Vector2(facing * DASH_SPEED, 0.0)
				set_state("dash")
				Sfx.play("dash", 0.05, -2.0)
		"dash":
			velocity.y = 0.0
			if not _struck:
				_struck = hit_player_in_rect(Rect2(center() - body_size * 0.5, body_size).grow(4.0), DASH_DAMAGE) != ""
			if state_time >= DASH_TIME:
				velocity.x = 0.0
				set_state("f_recover")
		"drink":
			if _spilled:
				set_state("f_recover")
			elif state_time >= DRAUGHT_TIME:
				hp = mini(max_hp, hp + roundi(max_hp * DRAUGHT_HEAL))
				Sfx.play("item", 0.0, -4.0)
				set_state("stalk")
		"f_recover":
			if state_time >= FREE_RECOVER:
				set_state("stalk")
		_:
			set_state("stalk")


func _tell(s: String) -> void:
	velocity.x = 0.0
	face_player()
	set_state(s)
	# Heard as it starts (bible 13.3), with the hero's own shared tells.
	Sfx.play({"heavy_tell": "tell_heavy", "cast_tell": "tell_charge"}.get(s, "tell_blade"), 0.05, -2.0)


func _swing(kind: String, next: String) -> void:
	_cut = kind
	_cut_time = 0.0
	_struck = false
	set_state(next)
	Sfx.play("heavy" if next == "heavy" else "slash", 0.05, -2.0)


## A bolt of shadow from its hand, straight at you.
func _cast() -> void:
	var b := ShadowBolt.new()
	b.boss = self
	b.direction = facing
	b.bounds = arena
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(facing * 14.0, -body_size.y * 0.6)
	Sfx.play("swell", 0.1, 2.0)


func die() -> void:
	if state == "dying":
		return
	if is_instance_valid(double):
		# The false one goes with it.
		double.real = null
		double._burst_quietly()
	set_state("dying")
	dead = true
	collision_layer = 0
	velocity = Vector2.ZERO
	_echoes.clear()
	_cut = ""
	Feel.boss_kill(1.0)
	Feel.add_trauma(0.7)
	Sfx.play("wail", 0.0, 0.0)


func _process(delta: float) -> void:
	if state != "dying":
		return
	state_time += delta
	if int(state_time * 10.0) % 3 == 0:
		var d := Dust.new()
		d.setup("debris")
		get_parent().add_child(d)
		d.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-36, -4))
	if state_time >= DYING_TIME:
		state = "dead"
		defeated.emit()
		super.die()


func _burst_quietly() -> void:
	var dust := Dust.new()
	dust.setup("debris")
	get_parent().add_child(dust)
	dust.global_position = center()
	dead = true
	queue_free()


## Its own pose once it fights on its own: [anim, frame].
func _free_pose() -> Array:
	match state:
		"cut_tell", "heavy_tell":
			return ["slash1", 0]
		"f_cut":
			return ["slash1", 2]
		"heavy":
			return ["slash3", 2]
		"cast_tell":
			return ["cast", 0]
		"dash_tell":
			return ["idle", 0]
		"dash":
			return ["dash", 0]
		"drink":
			return ["drink", PlayerVisual.frame_at("drink", state_time)]
		"stagger":
			return ["hurt", 0]
	if not is_on_floor():
		return ["fall", 0]
	if absf(velocity.x) > 10.0:
		return ["run", PlayerVisual.frame_at("run", state_time)]
	return ["idle", PlayerVisual.frame_at("idle", state_time)]


## How solid it is drawn: it fades into the floor and back.
func presence() -> float:
	match state:
		"intro":
			return clampf(state_time / INTRO_TIME, 0.0, 1.0)
		"sink":
			return 1.0 - clampf(state_time / SINK_TIME, 0.0, 1.0)
		"rise":
			return clampf(state_time / 0.2, 0.0, 1.0)
		"blink":
			return absf(1.0 - 2.0 * clampf(state_time / BLINK_TIME, 0.0, 1.0))
		"dying":
			return 1.0 - clampf(state_time / DYING_TIME, 0.0, 1.0)
		"split":
			return clampf(state_time / 0.3, 0.0, 1.0)
	return 1.0


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	# The mirror line: a faint seam of light down the middle of the hall.
	if phase == 1 and (state != "dormant" and not dead or state == "dying"):
		var ax := axis() - global_position.x
		var top := arena.position.y - global_position.y
		var k := 0.5 + 0.5 * sin(t * 1.5)
		draw_rect(Rect2(ax - 0.5, top, 1.0, arena.size.y), Color(RIM, 0.10 + 0.06 * k))
		for i in 6:
			var sy := fmod(t * 24.0 + i * arena.size.y / 6.0, arena.size.y)
			draw_rect(Rect2(ax - 0.5, top + sy, 1.0, 6.0), Color(CRYSTAL_LIGHT, 0.18))
	var a := presence()
	if a <= 0.01:
		return
	var anim := _anim
	var frame := _frame
	if state == "rise" or state == "cut":
		anim = "slash1"
		frame = 0 if state == "rise" else 2
	elif phase >= 2:
		var pose := _free_pose()
		anim = pose[0]
		frame = pose[1]
	if phase == 3 and reflects() and is_on_floor():
		# Its reflection in the polished floor, upside down under its feet: the
		# false one has none.
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(facing, -1))
		PlayerVisual.draw_frame(self, anim, frame, Color(RIM, 0.32 * a), true)
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(facing, -0.5))
		PlayerVisual.draw_frame(self, anim, frame, Color(CRYSTAL_LIGHT, 0.12 * a), true)
	if state == "burst_tell":
		# Struck, the false one swells with light before it bursts.
		var k := clampf(state_time / BURST_TELL, 0.0, 1.0)
		draw_circle(Vector2(0, -body_size.y * 0.5), 10.0 + 22.0 * k, Color(CRYSTAL, 0.18 + 0.25 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	# A violet rim around a body of shadow: you, cut out of the dark.
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_set_transform(o, 0.0, Vector2(facing, 1))
		PlayerVisual.draw_frame(self, anim, frame, Color(RIM, 0.55 * a), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	PlayerVisual.draw_frame(self, anim, frame, Color(SHADOW, 0.95 * a), true)
	var info := Sheet.info(PlayerVisual.SHEET_NAME, anim, frame)
	# Eyes where yours would be, lit pale.
	var neck: Array = info.get("neck", [0, -32])
	var eye := Vector2(neck[0] + 2.0, neck[1] - 6.0)
	draw_rect(Rect2(eye, Vector2(2, 1)), Color(EYE, a))
	draw_rect(Rect2(eye + Vector2(-3, 0), Vector2(1, 1)), Color(EYE, 0.6 * a))
	# Its blade, a shard of the Everbloom, glinting before each blow.
	if info.has("blade"):
		var hand := Vector2(info.hand[0], info.hand[1])
		var dir := Vector2.from_angle(deg_to_rad(float(info.blade)))
		var base := hand + dir * 2.0
		var tip := base + dir * PlayerVisual.BLADE_LENGTH
		draw_line(base, tip + dir, Color(SHADOW, a), 4.0)
		draw_line(base, tip, Color(CRYSTAL, a), 2.0)
	if telling():
		var k := 0.5 + 0.5 * absf(sin(t * 18.0))
		var hand := Vector2(info.hand[0], info.hand[1]) if info.has("hand") else Vector2(6, -22)
		draw_rect(Rect2(hand + Vector2(-1, -7), Vector2(3, 14)), Color(CRYSTAL_LIGHT, 0.9 * k * a))
		draw_rect(Rect2(hand + Vector2(-6, -1), Vector2(13, 3)), Color(CRYSTAL_LIGHT, 0.9 * k * a))
		PlayerVisual.draw_frame(self, anim, frame, Color(CRYSTAL, 0.35 * k * a), true)
	if flashing() or (state == "dying" and int(state_time * 12.0) % 2 == 0):
		PlayerVisual.draw_frame(self, anim, frame, Color(1, 1, 1, 0.8 * a), true)
	draw_set_transform(Vector2.ZERO)
