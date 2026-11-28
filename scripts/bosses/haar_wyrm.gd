class_name HaarWyrm
extends Enemy
## The Haar Wyrm (design bible 8.4): a colossal three-headed steam hydra lying in
## the dark mouth of a tunnel behind the Haar Spring's great cistern. Its body is
## never seen; only its three heads come out on their long necks, and each owns
## one breath:
##
## - the plume head vents a heavy cloud that rolls along the floor (jump it,
##   take a platform, or drop into the cistern, which is sunk under the floor);
## - the geyser head fires a straight, locked jet of boiling water (leave the line);
## - the fog head, after a long wind-up, fills the whole arena with thermal fog
##   that only the cistern's water shelters you from.
##
## Each round the plume and the geyser go in a random order, and the fog always
## comes third. Deluge is the only water: a bolt into each of the cistern's three
## intakes fills it a third, and each intake feeds one head. A head can't be beaten
## below HEAD_FLOOR until a full cistern douses it: at the next pause between breaths,
## the head whose pipe was filled last is drenched by it and sags onto the lip, weak,
## for WEAK_TIME (a dead head's pipe filled last douses nothing). Then the hydra rages and
## boils the cistern dry, and the loop begins again. A weakened head at 0 dies; the fight
## ends with the third. Each fog breath boils the cistern dry as its burn ends; once the
## fog head is dead, the cistern loses a third every DRAIN_EVERY instead (the pipe filled
## last), so the pipes are still a race. A head reacts as its pipe fills (`_react`).
##
## Drawn on a skeleton from Sean's PixelLab art (`WyrmRig`, since 2026-11-19): the body
## crouches in the tunnel's dark and the three necks grow from its shoulders. The
## code-drawn heads and necks below are what it wore while the fight was being built
## (`_px` takes half-pixels); `use_rig` off, or --wyrm-drawn, brings them back.

signal defeated

const DISPLAY_NAME := "The Haar Wyrm"
const EPITHET := "Three Heads of Steam"
const HEAD_HP := 100
const MAX_HP := 300
## A head's health can't fall below this until a full cistern weakens it.
const HEAD_FLOOR := 50
## No health marks: the fight turns as each head dies (`phase` = 1 + the dead),
## and BossArena rings the phase break on that.
const PHASES := []
## Each head's breath, in head order (west, middle, east).
const BREATHS := [HydraHead.PLUME, HydraHead.FOG, HydraHead.GEYSER]
## Where each head rests, out of the tunnel, from the tunnel's centre.
const HOMES := [Vector2(-170, -28), Vector2(0, -62), Vector2(170, -28)]
## Where each waits, deep in the tunnel, before it comes out.
const HIDDEN := [Vector2(-46, 58), Vector2(0, 42), Vector2(46, 58)]
## How low a head sags after it breathes (in reach of a jumping blade). All three sag
## to one height: the middle head is struck from the grate over the cistern, which is
## the floor's own level.
const SAG := [Vector2(-150, 50), Vector2(0, 50), Vector2(150, 50)]
## Where a doused head droops onto the cistern's lip.
const DROOP := [Vector2(-78, 122), Vector2(0, 116), Vector2(78, 122)]
## How low a dead head hangs.
const HANG := 110.0
## The cistern is sunk in the floor (Sean, 2026-11-20): its lip stands on these two
## columns and its inside is the pit between them, on these rows (the room is cut to match).
const CISTERN_COLS := Vector2i(22, 37)
const CISTERN_ROWS := Vector2i(20, 23)
## The intakes, one to a head (Sean, 2026-11-22): tile, which way the mouth opens, and the
## head it feeds. The side heads' pipes stand on their pillars of the arch, under their
## heads; the middle head's hangs from the ceiling over the cistern, its mouth reached with
## a jumping shot from the high west ledge.
const INTAKES := [[Vector2i(19, 11), -1, 0], [Vector2i(25, 5), -1, 1], [Vector2i(40, 11), 1, 2]]
## The room's ceiling, which the middle head's pipe hangs from (the first open row).
const CEILING_ROW := 4

## The wind-ups (each at least Enemy.MIN_TELEGRAPH, before the speed-up).
const PLUME_TELL := 0.9
const GEYSER_TELL := 1.1
## The geyser's line locks this long before it fires.
const GEYSER_LOCK := 0.45
## The fog's wind-up is long on purpose: it is the time to get water in.
const FOG_TELL := 3.0
const PLUME_BREATHE := 0.6
const SAG_TIME := 1.6
const RISE_TIME := 0.5
## Between one head's breath and the next.
const GAP := 1.4
const WEAK_TIME := 6.5
const RAGE_TIME := 2.2
## Each dead head quickens the rest by this much (never under MIN_TELEGRAPH). Not the
## fog's wind-up: that is the time to get water in, and it stays whole.
const QUICKEN := 0.85
## A dead head keeps its turn in the round, as a rest this long added to the gap: the
## breath and the gap it would have taken. Without it, each death shortened the round,
## and the fog came sooner with less time to fill the cistern (Sean, 2026-11-22: "not
## enough time to hit all 3 after killing the first head"; "the whisper comes faster").
const REST := 3.0
## Once the fog head is dead nothing boils the cistern, so it loses a third on its own this
## often (Sean, 2026-11-24: "20 seconds feel right to make it a little of a challenge to get
## to all the pipes"; after playing it, he raised it to 25 s the same day). The clock runs only while there is water in it, and stops while a
## head is doused and while the cistern boils dry; it steams for the last DRAIN_WARN.
const DRAIN_EVERY := 25.0
const DRAIN_WARN := 3.0
## A head's reaction as its pipe fills (Sean, 2026-11-24: "Players may not realize the
## correlation"): it rears, snaps toward the pipe with its jaws open, and light runs up its
## neck, with a hiss-roar. Drawn on the rig; a `react` clip in the head art, when Sean
## adds one, plays instead of the placeholder jaws (`WyrmRig._head_frame`).
const REACT_TIME := 0.9
const EMERGE_TIME := 1.2
## The intro: darkness, three pairs of eyes, breathing, then the heads come out.
const INTRO_TIME := 6.8
const EYES_AT := [1.0, 1.7, 2.4]
const SNORTS_AT := [3.0, 3.6, 4.2]
const EMERGE_AT := [4.6, 5.0, 5.4]
## A second look at the fight skips the darkness and the eyes.
const INTRO_SEEN_FROM := 4.4
const SEEN_FLAG := "seen:haar_wyrm"
const DYING_TIME := 1.8

const OUTLINE := Color("141a1c")
const SCALE := Color("4f6b52")
const SCALE_LIGHT := Color("7d9c74")
const SCALE_DARK := Color("2d3f30")
const BRONZE := Color("8a7a45")
const BONE := Color("ddd5c0")
const EYE := Color("f4d24c")
const STEAM := Color("f4f7f6")
const STEAM_HOT := Color("fff1dc")
const STONE := Color("4a4640")
const STONE_LIGHT := Color("6b655b")
const DARK := Color("07090a")
const DRENCHED := Color("6f8a9c")
const DRENCHED_LIGHT := Color("9fb8c8")
const DRENCHED_DARK := Color("4a5f6e")
const LIMP := Color("3d4440")

## The heads, necks and body are Sean's PixelLab art on a skeleton (`WyrmRig`). Off, they
## are the code-drawn ones the fight was built with (the game's --wyrm-drawn, to compare).
## The fight is the same either way, but for where the geyser leaves the jaws.
static var use_rig := true
## Films: the breaths in the same order every run (0 leaves them to chance).
static var seed_with := 0

## The arena's interior in pixels (the room sets it).
var arena := Rect2(16, 64, 928, 256)
var phase := 1
var heads: Array[HydraHead] = []
var cistern: HydraCistern
var rng := RandomNumberGenerator.new()

## Where the fight's round stands: gap, attack, weak, rage.
var step := "gap"
var step_time := 0.0
## Heads still to breathe this round, by index.
var order: Array[int] = []
var attacker: HydraHead
## The head that breathed last (the douse once fell on it; now the pipes choose).
var last_breather: HydraHead
var weakened: HydraHead
## How long the cistern has held water since it last lost a third (fog head dead only).
var drain_time := 0.0

var _intro_t := 0.0
var _beat := 0
var _hinted := {}
var _lair: Node2D
var rig: WyrmRig


func _init() -> void:
	max_hp = MAX_HP
	hp = MAX_HP
	contact_damage = 0
	gold_min = 80
	gold_max = 100
	xp = 200
	body_size = Vector2(8, 8)
	body_centered = true
	uses_gravity = false
	knockback = 0.0
	state = "dormant"
	if seed_with != 0:
		rng.seed = seed_with
	else:
		rng.randomize()


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	# Only the heads are ever hit.
	collision_layer = 0
	collision_mask = 0
	_lair = Node2D.new()
	_lair.z_index = -1
	_lair.draw.connect(_draw_lair)
	add_child(_lair)
	if use_rig:
		rig = WyrmRig.new()
		add_child(rig)
	for i in 3:
		var h := HydraHead.new()
		h.boss = self
		h.index = i
		h.is_head = true
		h.breath = BREATHS[i]
		h.hp = HEAD_HP
		h.max_hp = HEAD_HP
		heads.append(h)
		h.position = global_position + HIDDEN[i]
		get_parent().add_child.call_deferred(h)
	cistern = build_cistern(get_parent(), false)
	cistern.pipe_filled.connect(_on_pipe_filled)


## The room's cells under the cistern's grate: the pit's top row, between its walls.
## The room lays them as a one-way floor itself (its `grate:` header), so the floor is
## there from the room's first frame; the cistern, which comes with the fight, draws it.
static func grate_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col in range(CISTERN_COLS.x + 1, CISTERN_COLS.y):
		out.append(Vector2i(col, CISTERN_ROWS.x))
	return out


## The great cistern and its three intakes, in `room` (full once he is beaten).
static func build_cistern(room: Node, full: bool) -> HydraCistern:
	var t := float(Room.TILE)
	var c := HydraCistern.new()
	c.inside = Rect2((CISTERN_COLS.x + 1) * t, CISTERN_ROWS.x * t, (CISTERN_COLS.y - CISTERN_COLS.x - 1) * t, (CISTERN_ROWS.y - CISTERN_ROWS.x + 1) * t)
	room.add_child(c)
	for spec: Array in INTAKES:
		var i := HydraIntake.new()
		var cell: Vector2i = spec[0]
		i.facing = spec[1]
		i.head = spec[2]
		i.breath = BREATHS[i.head]
		i.hung = i.head == 1
		i.ceiling_y = CEILING_ROW * t
		i.position = Vector2(cell) * t + Vector2(t, t) * 0.5
		room.add_child(i)
		c.add_intake(i)
	if full:
		c.fill_now()
	return c


## Starts the fight (called by the arena once the player is inside).
func begin() -> void:
	set_state("intro")
	_beat = 0
	# A boss rush keeps no flags, and plays the short reveal.
	_intro_t = INTRO_SEEN_FROM if GameState.flag(SEEN_FLAG) or BossRush.active() else 0.0
	if not BossRush.active():
		GameState.set_flag(SEEN_FLAG)


## Tests and a retry: straight to the heads coming out.
func skip_intro() -> void:
	_intro_t = maxf(_intro_t, EMERGE_AT[0] - 0.01)


## Where to aim at him: the nearest head that is out and alive (his body lies
## out of reach in the tunnel).
func center() -> Vector2:
	var p := player()
	var best: HydraHead = null
	for h in heads:
		if h.dead or not h.active:
			continue
		if best == null or p != null and h.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = h
	return best.global_position if best != null else global_position


func health_fraction() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)


## A wind-up, quickened as heads die, never under Enemy.MIN_TELEGRAPH.
func tell(base: float) -> float:
	if base == FOG_TELL:
		return FOG_TELL
	return maxf(Enemy.MIN_TELEGRAPH, base * pow(QUICKEN, dead_heads()))


func dead_heads() -> int:
	var n := 0
	for h in heads:
		if h.dead:
			n += 1
	return n


func head_for(breath_id: String) -> HydraHead:
	for h in heads:
		if h.breath == breath_id:
			return h
	return null


## The ground the plume rolls along at `x`: the floor, all the way across. The cistern
## is sunk in it, and the plume rolls straight over its mouth (it used to climb the
## cistern's walls and come down again, which looked wrong; Sean, 2026-11-20).
func ground_at(_x: float) -> float:
	return arena.end.y


func home_of(h: HydraHead) -> Vector2:
	return global_position + HOMES[h.index]


func _modify_damage(_damage: int, _dir: Vector2) -> int:
	return 0


## A blow on a head. Its hot scales hold it at HEAD_FLOOR until it is doused.
func hit_segment(seg: BossSegment, damage: int, dir: Vector2) -> void:
	var h := seg as HydraHead
	if h == null or h.dead or state != "fight":
		return
	hits_taken += 1
	var lowest := 0 if h.weak else mini(h.hp, HEAD_FLOOR)
	var dealt := clampi(damage, 0, h.hp - lowest)
	if dealt <= 0:
		# Scale too hot to wound deeper: the blade glances off.
		h.flash = 0.06
		var g := Dust.new()
		g.setup("guard")
		get_parent().add_child(g)
		g.global_position = h.global_position
		Sfx.play("guard", 0.1, -4.0)
		_hint("floor", "Its scales are scalding hot and turn your blade. Fill the cistern through its intakes to douse it: the pipe you fill last picks the head.")
		return
	h.hp -= dealt
	h.flash = 0.12
	hp = 0
	for o in heads:
		hp += maxi(o.hp, 0)
	DamageNumber.spawn(get_parent(), h.global_position + Vector2(0, -16), dealt, "heavy" if dir.length() > 1.5 else "hit")
	var d := Dust.new()
	d.setup("hit")
	get_parent().add_child(d)
	d.global_position = h.global_position
	if h.hp <= 0:
		_kill_head(h)


## The head is open while it sags after a breath or lies doused (Enemy.punishable).
func segment_punishable(seg: BossSegment) -> bool:
	var h := seg as HydraHead
	return h != null and not h.dead and (h.weak or h.mode == "sag")


func stagger_head(_h: HydraHead) -> void:
	pass


func stagger() -> void:
	pass


func _on_blocked(_dir: Vector2) -> void:
	pass


func _kill_head(h: HydraHead) -> void:
	h.kill()
	# Its pipe still runs, but filled last it douses nothing; its plate goes dark.
	var pipe := intake_of(h)
	if pipe != null:
		pipe.head_dead = true
	phase = 1 + dead_heads()
	order.erase(h.index)
	if h == attacker:
		attacker = null
	if dead_heads() >= heads.size():
		die()
		return
	Feel.add_trauma(0.5)
	Sfx.play("hydra_roar", 0.1, 2.0)
	GameState.toast.emit("The %s head falls limp." % _head_name(h))


## The pipe that feeds `h`.
func intake_of(h: HydraHead) -> HydraIntake:
	if cistern == null:
		return null
	for i in cistern.intakes:
		if i.head == h.index:
			return i
	return null


## The head a full cistern douses: the one whose pipe filled it last.
func chosen_head() -> HydraHead:
	var pipe := cistern.last_filled() if cistern != null else null
	if pipe == null or pipe.head < 0 or pipe.head >= heads.size():
		return null
	var h := heads[pipe.head]
	return null if h.dead else h


## A pipe began to run: its head, if it lives, rears and snaps toward it.
func _on_pipe_filled(pipe: HydraIntake) -> void:
	if state != "fight" or pipe.head < 0 or pipe.head >= heads.size():
		return
	var h := heads[pipe.head]
	if h.dead:
		return
	h.react = 0.0
	h.react_dir = (pipe.global_position - h.global_position).normalized()
	h.set_meta("react_off", Vector2.ZERO)
	Sfx.play("hydra_hiss", 0.1, -2.0)
	_hint("react", "The %s head rears and hisses as its pipe fills. The pipe you fill last picks the head the water douses." % _head_name(h))


## How far a reacting head is thrown off its place `t` seconds in: up and back from the
## pipe, then a snap toward it, settling.
static func react_offset(dir: Vector2, t: float) -> Vector2:
	if t < 0.0 or t >= REACT_TIME:
		return Vector2.ZERO
	var back := -dir * 8.0 + Vector2(0, -12.0)
	var snap := dir * 12.0 + Vector2(0, -4.0)
	if t < 0.22:
		return back * smoothstep(0.0, 0.22, t)
	if t < 0.4:
		return back.lerp(snap, smoothstep(0.22, 0.4, t))
	return snap * (1.0 - smoothstep(0.4, REACT_TIME, t))


func _head_name(h: HydraHead) -> String:
	return ["western", "middle", "eastern"][h.index]


func _hint(key: String, text: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	GameState.toast.emit(text)


func _think(delta: float) -> void:
	velocity = Vector2.ZERO
	match state:
		"intro":
			_intro(delta)
		"fight":
			_fight(delta)
	_move_heads(delta)


func _intro(delta: float) -> void:
	_intro_t += delta
	# Each beat once, in order, as its moment passes.
	var beats := []
	for i in 3:
		beats.append([EYES_AT[i], "eyes", i])
	for i in 3:
		beats.append([SNORTS_AT[i], "snort", i])
	for i in 3:
		beats.append([EMERGE_AT[i], "emerge", i])
	while _beat < beats.size() and _intro_t >= beats[_beat][0]:
		var b: Array = beats[_beat]
		_beat += 1
		match b[1]:
			"eyes":
				if _intro_t < INTRO_SEEN_FROM:
					Sfx.play("hydra_bite", 0.15, -14.0)
			"snort":
				if _intro_t < INTRO_SEEN_FROM + 0.2:
					Sfx.play("steam_hiss", 0.15, -6.0)
					Sfx.play("swell", 0.1, -10.0)
			"emerge":
				var h := heads[b[2]]
				h.set_mode("emerge")
				h.set_out(true)
				Sfx.play("swell", 0.1, -4.0)
				Feel.add_trauma(0.15)
	if _intro_t >= INTRO_TIME:
		set_state("fight")
		Sfx.play("hydra_roar", 0.0, 2.0)
		Feel.add_trauma(0.35)
		GameState.banner.emit(DISPLAY_NAME, EPITHET)
		_new_round()
		_to("gap")


func _to(s: String) -> void:
	step = s
	step_time = 0.0


## A round: the plume and the geyser in a random order, then the fog. A dead head
## keeps its place, as a rest (`REST`).
func _new_round() -> void:
	order.clear()
	if dead_heads() >= heads.size():
		return
	var pair: Array[int] = []
	for h in heads:
		if h.breath != HydraHead.FOG:
			pair.append(h.index)
	if pair.size() == 2 and rng.randf() < 0.5:
		pair.reverse()
	order.append_array(pair)
	var fog := head_for(HydraHead.FOG)
	if fog != null:
		order.append(fog.index)


func _fight(delta: float) -> void:
	step_time += delta
	_drain(delta)
	match step:
		"gap":
			if cistern.full() and chosen_head() != null:
				_weaken(chosen_head())
				return
			if cistern.full():
				_hint("dead_pipe", "The water brims, but the pipe you filled last feeds a dead head. It douses nothing.")
			if step_time >= GAP * pow(QUICKEN, dead_heads()):
				_next_breath()
		"attack":
			if attacker == null or attacker.mode not in ["tell", "breathe"]:
				if attacker != null:
					last_breather = attacker
				attacker = null
				_to("gap")
		"weak":
			if weakened == null or weakened.dead or step_time >= WEAK_TIME:
				_rage()
		"rage":
			if step_time >= RAGE_TIME:
				for h in heads:
					if not h.dead and h.mode == "rage":
						h.set_mode("idle")
				_new_round()
				_to("gap")


## Once the fog head is dead, the cistern loses a third every DRAIN_EVERY it holds water.
func _drain(delta: float) -> void:
	var fog := head_for(HydraHead.FOG)
	if fog == null or not fog.dead or step not in ["gap", "attack"] or cistern.boiling or cistern.level <= 0:
		drain_time = 0.0
		cistern.simmer = 0.0
		return
	drain_time += delta
	cistern.simmer = clampf((drain_time - (DRAIN_EVERY - DRAIN_WARN)) / DRAIN_WARN, 0.0, 1.0)
	if drain_time >= DRAIN_EVERY:
		drain_time = 0.0
		cistern.simmer = 0.0
		cistern.lose_third()
		_hint("drain", "With the fog head dead, the cistern's water steams away a third at a time. Keep the pipes running.")


func _next_breath() -> void:
	if order.is_empty():
		_new_round()
	if order.is_empty():
		return
	var h := heads[order.pop_front()]
	if h.dead:
		# Its turn passes as a longer gap; a cistern filled in it still douses.
		_to("gap")
		step_time = -REST
		return
	attacker = h
	h.set_mode("tell")
	match h.breath:
		HydraHead.PLUME:
			Sfx.play("steam_hiss", 0.1, -2.0)
		HydraHead.GEYSER:
			Sfx.play("swell", 0.1, 0.0)
		HydraHead.FOG:
			# Near-silent: a low drone under a long indrawn breath.
			Sfx.play("swell", 0.05, -12.0)
			_hint("fog", "The middle head draws a long, slow breath, and the air begins to shimmer. Get into the cistern's water!")
	_to("attack")


## A full cistern douses the head whose pipe filled it last: that pipe bursts over it,
## and it droops on the lip, weak.
func _weaken(h: HydraHead) -> void:
	weakened = h
	h.weak = true
	drain_time = 0.0
	cistern.simmer = 0.0
	var pipe := intake_of(h)
	if pipe != null:
		var d := HydraDrench.new()
		d.from = pipe.spout()
		d.target = h
		d.life = WEAK_TIME
		get_parent().add_child(d)
		Sfx.play("flood", 0.05, 2.0)
	h.set_mode("weak")
	h.flash = 0.2
	order.clear()
	Sfx.play("douse", 0.0, 2.0)
	Sfx.play("hydra_roar", 0.2, -6.0)
	Feel.add_trauma(0.3)
	GameState.toast.emit("The brimming cistern douses the %s head! Strike now." % _head_name(h))
	_to("weak")


## The hydra rages and boils the cistern dry; the round begins again.
func _rage() -> void:
	if weakened != null:
		weakened.weak = false
		if not weakened.dead:
			weakened.set_mode("rise")
	weakened = null
	last_breather = null
	for h in heads:
		if not h.dead and h.mode != "rise":
			h.set_mode("rage")
	cistern.boil()
	Sfx.play("hydra_roar", 0.0, 3.0)
	Feel.add_trauma(0.5)
	_to("rage")


func _move_heads(delta: float) -> void:
	var p := player()
	for h in heads:
		if not is_instance_valid(h) or not h.is_inside_tree():
			continue
		h.mode_time += delta
		h.flash -= delta
		if p != null:
			h.set_meta("face", 1.0 if p.global_position.x >= h.global_position.x else -1.0)
		var k := 1.0 - exp(-5.0 * delta)
		var sway := Vector2(sin(game_time * 1.3 + h.index * 2.0) * 6.0, sin(game_time * 2.1 + h.index) * 4.0)
		match h.mode:
			"hidden":
				h.global_position = global_position + HIDDEN[h.index]
			"emerge":
				var r := clampf(h.mode_time / EMERGE_TIME, 0.0, 1.0)
				h.global_position = h.from.lerp(home_of(h), smoothstep(0.0, 1.0, r))
				if r >= 1.0:
					h.set_mode("idle")
			"idle":
				h.global_position = h.global_position.lerp(home_of(h) + sway, k)
			"rise":
				var r := clampf(h.mode_time / RISE_TIME, 0.0, 1.0)
				h.global_position = h.from.lerp(home_of(h), smoothstep(0.0, 1.0, r))
				if r >= 1.0:
					h.set_mode("idle")
			"tell":
				_tell(h, k)
			"breathe":
				_breathe_hold(h, k)
			"sag":
				h.global_position = h.global_position.lerp(global_position + SAG[h.index], k)
				if h.mode_time >= SAG_TIME:
					h.set_mode("rise")
			"weak":
				var droop: Vector2 = global_position + DROOP[h.index] + Vector2(0, sin(game_time * 1.5) * 2.0)
				h.global_position = h.global_position.lerp(droop, k)
			"rage":
				var shake := Vector2(sin(game_time * 40.0 + h.index) * 3.0, -10.0 + sin(game_time * 9.0) * 4.0)
				h.global_position = h.global_position.lerp(home_of(h) + shake, k)
			"limp":
				var hang: Vector2 = global_position + Vector2(HOMES[h.index].x * 0.8, HANG)
				h.global_position = h.global_position.lerp(hang, 1.0 - exp(-2.0 * delta))
		_react(h, delta)


## A head reacting to its pipe filling is thrown off its place and back (`react_offset`),
## over whatever it is doing.
func _react(h: HydraHead, delta: float) -> void:
	if h.react < 0.0:
		return
	h.react += delta
	if h.dead or h.mode in ["hidden", "emerge", "rise", "limp"]:
		h.react = -1.0
		return
	var was: Vector2 = h.get_meta("react_off", Vector2.ZERO)
	var now := react_offset(h.react_dir, h.react)
	h.global_position += now - was
	h.set_meta("react_off", now)
	if h.react >= REACT_TIME:
		h.react = -1.0


func _face(h: HydraHead) -> float:
	return float(h.get_meta("face", 1.0))


func _tell(h: HydraHead, k: float) -> void:
	var p := player()
	match h.breath:
		HydraHead.PLUME:
			# It rears up and back, steam leaking from its jaws.
			h.global_position = h.global_position.lerp(home_of(h) + Vector2(-_face(h) * 10.0, -16.0), k)
			if h.mode_time >= tell(PLUME_TELL):
				var b := SteamBreath.new()
				b.dir = _face(h)
				b.ground_at = ground_at
				b.ground_y = arena.end.y
				b.left = arena.position.x
				b.right = arena.end.x
				get_parent().add_child(b)
				b.global_position = Vector2(h.global_position.x + _face(h) * 20.0, ground_at(h.global_position.x))
				Sfx.play("haar_breath", 0.08, 0.0)
				Feel.add_trauma(0.2)
				h.set_mode("breathe")
		HydraHead.GEYSER:
			# It draws its head back and aims; the line locks before it fires.
			h.global_position = h.global_position.lerp(home_of(h) + Vector2(-_face(h) * 8.0, -8.0), k)
			if p != null and h.mode_time < tell(GEYSER_TELL) - GEYSER_LOCK:
				h.aim = (p.body_rect().get_center() - mouth_of(h)).normalized()
			if h.mode_time >= tell(GEYSER_TELL):
				var g := HydraGeyser.new()
				g.head = h
				g.dir = h.aim
				g.bounds = arena
				g.pit = cistern.inside
				g.mouth = mouth_of(h)
				get_parent().add_child(g)
				h.set_meta("geyser", g)
				Sfx.play("flood", 0.05, 2.0)
				Sfx.play("haar_breath", 0.05, 0.0)
				Feel.add_trauma(0.3)
				h.set_mode("breathe")
		HydraHead.FOG:
			# It rises high and draws a long breath; the air starts to shimmer.
			h.global_position = h.global_position.lerp(home_of(h) + Vector2(0, -22.0), k * 0.6)
			if h.mode_time >= tell(FOG_TELL):
				var f := HydraFog.new()
				f.bounds = arena
				f.cistern = cistern
				# The heat comes off its jaws, wherever they go while it holds the breath.
				f.source = mouth_of.bind(h)
				get_parent().add_child(f)
				h.set_meta("fog", f)
				Sfx.play("steam_hiss", 0.05, -8.0)
				h.set_mode("breathe")


func _breathe_hold(h: HydraHead, k: float) -> void:
	var finished := false
	match h.breath:
		HydraHead.PLUME:
			h.global_position = h.global_position.lerp(home_of(h) + Vector2(_face(h) * 12.0, 30.0), k)
			finished = h.mode_time >= PLUME_BREATHE
		HydraHead.GEYSER:
			# The jet's force shoves the head back along its line.
			h.global_position = h.global_position.lerp(home_of(h) - h.aim * 10.0, k)
			var g = h.get_meta("geyser", null)
			finished = g == null or not is_instance_valid(g)
		HydraHead.FOG:
			h.global_position = h.global_position.lerp(home_of(h) + Vector2(0, -10.0), k)
			finished = h.mode_time >= HydraFog.FILL + HydraFog.BURN
	if finished:
		h.set_mode("sag")


## Where a head's breath leaves its jaws.
func mouth_of(h: HydraHead) -> Vector2:
	if rig != null:
		# On the rig the head turns to its aim, and the breath leaves its jaws.
		return rig.mouth(h.index, h.global_position)
	return h.global_position + Vector2(_face(h) * 22.0, 6.0)


func _process(delta: float) -> void:
	if state == "dying":
		state_time += delta
		if state_time >= DYING_TIME:
			state = "dead"
			for h in heads:
				if is_instance_valid(h):
					h.queue_free()
			defeated.emit()
			super.die()
	if rig != null and state != "dead":
		rig.pose(self, delta)
	queue_redraw()
	if is_instance_valid(_lair):
		_lair.queue_redraw()


func die() -> void:
	if state == "dying":
		return
	set_state("dying")
	dead = true
	collision_layer = 0
	for h in heads:
		if not h.dead:
			h.kill()
	for n in get_tree().get_nodes_in_group("hydra_fog"):
		n.queue_free()
	Feel.boss_kill(1.0)
	Feel.add_trauma(0.7)
	Sfx.play("hydra_roar", 0.0, 4.0)


# --- Drawing ---------------------------------------------------------------------

## The tunnel mouth behind the cistern, and what lies in it.
func _draw_lair() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var l := _lair
	# The arch: a ring of dark stone around a mouth of black.
	# It stands on the cistern's lip, which is as wide as the arch.
	var w := 118.0
	var top := -100.0
	var bottom := cistern.inside.position.y - HydraCistern.LIP - global_position.y if cistern != null else 152.0
	for i in 26:
		var a := PI + PI * i / 25.0
		var c := Vector2(cos(a) * w, top + 100.0 + sin(a) * 100.0)
		l.draw_rect(Rect2(c - Vector2(9, 7), Vector2(18, 14)), STONE)
		l.draw_rect(Rect2(c - Vector2(9, 7), Vector2(18, 3)), STONE_LIGHT)
	l.draw_rect(Rect2(-w - 9.0, 0.0, 18.0, bottom), STONE)
	l.draw_rect(Rect2(w - 9.0, 0.0, 18.0, bottom), STONE)
	var inner := w - 9.0
	var y := top + 9.0
	while y < bottom:
		var half := inner if y >= 0.0 else sqrt(maxf(0.0, 1.0 - pow((y - (top + 100.0)) / 91.0, 2.0))) * inner
		l.draw_rect(Rect2(-half, y, half * 2.0, minf(9.0, bottom - y)), DARK)
		y += 9.0
	# Something vast breathing in the dark: the barest glint of scale. (The rig has
	# the body itself there, and the heads' own eyes.)
	var breathe := 0.5 + 0.5 * sin(t * 0.7)
	for i in (7 if rig == null else 0):
		var a := i * 0.9 + t * 0.05
		var c := Vector2(sin(a) * 60.0, 52.0 + cos(a * 1.3) * 26.0)
		l.draw_arc(c, 22.0 + i * 3.0, PI * 1.1, PI * 1.9, 10, Color(SCALE_DARK, 0.12 + 0.08 * breathe), 2.0)
	# The intro: three pairs of eyes, one after another, then snorts of steam.
	if state == "intro":
		for i in 3:
			var on: float = clampf((_intro_t - EYES_AT[i]) / 0.4, 0.0, 1.0)
			var h := heads[i]
			if rig == null and on > 0.0 and h.mode == "hidden":
				var e: Vector2 = HIDDEN[i] + Vector2(0, -4)
				var blink := 0.0 if fmod(t + i, 4.0) < 0.12 else 1.0
				l.draw_rect(Rect2(e + Vector2(-8, 0), Vector2(5, 2)), Color(EYE, on * blink))
				l.draw_rect(Rect2(e + Vector2(3, 0), Vector2(5, 2)), Color(EYE, on * blink))
				l.draw_rect(Rect2(e + Vector2(-9, -1), Vector2(7, 4)), Color(EYE, 0.18 * on * blink))
				l.draw_rect(Rect2(e + Vector2(2, -1), Vector2(7, 4)), Color(EYE, 0.18 * on * blink))
		for i in 3:
			var s: float = _intro_t - SNORTS_AT[i]
			if s > 0.0 and s < 1.2:
				var c: Vector2 = HIDDEN[i] + Vector2(0, 4)
				for j in 4:
					var ph := clampf(s / 1.2 + j * 0.08, 0.0, 1.0)
					l.draw_circle(c + Vector2((j - 1.5) * 5.0, -ph * 26.0), 3.0 + ph * 7.0, Color(STEAM, (1.0 - ph) * 0.7))


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var fade := 1.0
	if state == "dying":
		fade = 1.0 - clampf(state_time / DYING_TIME, 0.0, 1.0)
	for h in heads:
		if rig == null and is_instance_valid(h) and h.mode != "hidden":
			_draw_neck(h, fade)
	for h in heads:
		if is_instance_valid(h) and h.mode != "hidden":
			if rig == null:
				_draw_head(h, t, fade)
			_draw_head_health(h, fade)
	if state == "fight":
		_draw_tells(t)


## The neck: from deep in the tunnel to the head, thick and scaled.
func _draw_neck(h: HydraHead, fade: float) -> void:
	var base: Vector2 = HIDDEN[h.index] + Vector2(0, 30)
	var head := h.global_position - global_position
	var ctrl := Vector2(lerpf(base.x, head.x, 0.35), minf(base.y, head.y) - 40.0)
	var steps := 30
	var body := LIMP if h.dead else (DRENCHED if h.weak else SCALE)
	var light := LIMP.lightened(0.15) if h.dead else (DRENCHED_LIGHT if h.weak else SCALE_LIGHT)
	for i in steps:
		var k := float(i) / steps
		var pt := base.lerp(ctrl, k).lerp(ctrl.lerp(head, k), k)
		var r := lerpf(13.0, 7.0, k)
		draw_circle(pt, r + 1.0, Color(OUTLINE, fade))
		draw_circle(pt, r, Color(body, fade))
		draw_circle(pt + Vector2(-1, -2), r * 0.45, Color(light, 0.5 * fade))
		if i % 3 == 0:
			draw_rect(Rect2(pt + Vector2(-1, -r), Vector2(2, 3)), Color(BRONZE, fade))


func _draw_head(h: HydraHead, t: float, fade: float) -> void:
	var f := _face(h)
	var gape := 0.0
	match h.mode:
		"tell":
			gape = 0.3 if h.breath != HydraHead.FOG else 0.6
		"breathe":
			gape = 1.0
		"sag":
			gape = 0.5
		"weak":
			gape = 0.4
		"rage":
			gape = 1.0
		"limp":
			gape = 0.6
	var white := h.flash > 0.0 or h.mode == "tell" and int(h.mode_time * 12.0) % 2 == 0 and h.mode_time > tell(_tell_of(h)) - 0.35
	var a := fade
	var body := SCALE
	var light := SCALE_LIGHT
	var dark := SCALE_DARK
	if h.weak:
		body = DRENCHED
		light = DRENCHED_LIGHT
		dark = DRENCHED_DARK
	elif h.dead:
		body = LIMP
		light = LIMP.lightened(0.15)
		dark = LIMP.darkened(0.3)
	# The head's pixels are whole world pixels (twice the body's): it reads big.
	draw_set_transform(h.global_position - global_position, 0.0, Vector2(f * 2.0, 2.0))
	var g := roundi(gape * 8.0)
	_px(-18, -14, 28, 26, OUTLINE, a)
	_px(0, -8, 26, 16, OUTLINE, a)
	_px(-16, -12, 24, 22, body, a)
	_px(2, -6, 22, 10, body, a)
	_px(-12, -10, 12, 4, light, a)
	_px(4, -4, 16, 2, light, a)
	_px(0, 4 + g, 24, 6, OUTLINE, a)
	_px(2, 4 + g, 20, 4, dark, a)
	for i in 4:
		_px(5 + i * 5, 2 + g, 2, 3, BONE, a)
		_px(5 + i * 5, 3, 2, 2, BONE, a)
	# Horns and a bronze crest of spines.
	_px(-18, -18, 16, 4, BRONZE, a)
	_px(-22, -24, 6, 8, BONE, a)
	_px(-14, -26, 4, 8, BONE, a)
	_px(-6, -22, 3, 5, BRONZE, a)
	if h.dead:
		_px(4, -7, 5, 1, OUTLINE, a)
	elif h.weak:
		_px(4, -7, 5, 1, DRENCHED_DARK, 0.9 * a)
		for i in 3:
			var drop := fmod(t * 1.6 + i * 0.37 + h.index * 0.2, 1.0)
			_px(6 + i * 7, 10 + roundi(drop * 26.0), 2, 3, Color("9fd0f0"), (1.0 - drop) * 0.9 * a)
	else:
		_px(4, -8, 5, 3, Color.WHITE if h.mode == "tell" else EYE, a)
	if h.mode in ["tell", "breathe"] or h.mode == "idle" and fmod(t + h.index * 1.3, 5.0) < 0.5:
		# Steam leaking at the jaws: a snort at rest, pressure before a breath.
		for i in 3:
			var ph := fmod(t * 1.3 + i * 0.4, 1.0)
			draw_circle(Vector2(11 + i - 1, 2 - ph * 14.0), 2.0 + ph * 2.0, Color(STEAM, (1.0 - ph) * 0.6 * a))
	if h.mode == "tell" and h.breath == HydraHead.GEYSER:
		# The throat glows hotter as the pressure builds.
		var heat := clampf(h.mode_time / tell(GEYSER_TELL), 0.0, 1.0)
		draw_circle(Vector2(12, 4 + g * 0.5), 3.0 + heat * 3.0, Color(STEAM_HOT, 0.4 + 0.5 * heat))
	if white:
		_px(-16, -12, 24, 22, Color.WHITE, 0.6 * a)
		_px(2, -6, 22, 10, Color.WHITE, 0.6 * a)
	draw_set_transform(Vector2.ZERO)


## A head's own health: a notch at the floor its hot scales hold it to.
func _draw_head_health(h: HydraHead, a: float) -> void:
	if not h.dead and state == "fight":
		var at := h.global_position - global_position + Vector2(-14, -34)
		draw_rect(Rect2(at, Vector2(28, 3)), Color(OUTLINE, 0.8 * a))
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(26.0 * h.fraction(), 1)), Color(EYE if h.weak else Color("c0503a"), a))
		draw_rect(Rect2(at + Vector2(13.5, -1), Vector2(1, 5)), Color(BONE, 0.9 * a))


func _tell_of(h: HydraHead) -> float:
	match h.breath:
		HydraHead.GEYSER:
			return GEYSER_TELL
		HydraHead.FOG:
			return FOG_TELL
	return PLUME_TELL


## What a wind-up shows the player beyond the head itself.
func _draw_tells(t: float) -> void:
	if attacker == null or attacker.mode != "tell":
		return
	var h := attacker
	var k := clampf(h.mode_time / tell(_tell_of(h)), 0.0, 1.0)
	match h.breath:
		HydraHead.PLUME:
			# Steam gathers on the ground below before the plume pours down.
			var gx := h.global_position.x - global_position.x
			var gy := ground_at(h.global_position.x) - global_position.y
			var w := 10.0 + 30.0 * k
			draw_rect(Rect2(gx - w, gy - 5.0, w * 2.0, 5.0), Color(STEAM, 0.6))
		HydraHead.GEYSER:
			# The line it will fire along: a thin spray, solid once it locks.
			var m := mouth_of(h) - global_position
			var locked := h.mode_time >= tell(GEYSER_TELL) - GEYSER_LOCK
			var seg := 10.0
			var d := 0.0
			while d < 900.0:
				var pt := m + h.aim * d
				var world := pt + global_position
				if not arena.grow(8.0).has_point(world):
					break
				if locked or int(d / seg + t * 10.0) % 2 == 0:
					draw_rect(Rect2(pt - Vector2(1, 1), Vector2(2, 2)), Color(Color("9fd4f2") if not locked else Color.WHITE, 0.5 + 0.4 * k))
				d += seg * 0.5
		HydraHead.FOG:
			# Heat building over the whole arena, and steam drawn into the jaws.
			var r := arena
			r.position -= global_position
			draw_rect(r, Color(STEAM_HOT, 0.08 * k))
			var m := mouth_of(h) - global_position
			for i in 10:
				var ph := fmod(t * 0.8 + i * 0.1, 1.0)
				var from := Vector2(cos(i * 0.63) * 120.0, sin(i * 0.63) * 60.0 + 40.0)
				draw_circle(m.lerp(m + from, 1.0 - ph), 2.0 + 3.0 * (1.0 - ph), Color(STEAM, ph * 0.5))
			for i in 16:
				var ph := fmod(t * 0.4 + i * 0.0625, 1.0)
				var lx := r.position.x + fmod(i * 61.0, r.size.x)
				var ly := r.end.y - ph * r.size.y
				draw_line(Vector2(lx, ly), Vector2(lx + 8.0, ly + sin(t * 4.0 + i) * 2.0), Color(Color.WHITE, 0.25 * k * (1.0 - ph)), 1.0)


func _px(x: int, y: int, w: int, h: int, color: Color, alpha: float) -> void:
	draw_rect(Rect2(x * 0.5, y * 0.5, w * 0.5, h * 0.5), Color(color, color.a * alpha))
