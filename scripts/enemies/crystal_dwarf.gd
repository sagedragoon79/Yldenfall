class_name CrystalDwarf
extends Enemy
## A dwarf of Vorrhallow fused with the Everbloom (design bible 7, Vorrhallow). Magenta
## crystal has grown out of his back like a shell and swallowed his right arm.
## He trudges toward you, and with you ahead of him he raises the crystal fist
## (it brightens: the telegraph) and drives it into the floor. A chain of crystal
## spikes erupts along the floor toward you, one after another: jump them. His
## fist stays rooted for a moment after, and that is the time to hit him. His
## crystal back turns any blow from behind; only a pogo from above gets past it.

const WALK_SPEED := 22.0
const SIGHT := Vector2(150, 48)
const REACH := 120.0
const WINDUP := 0.6
const ROOTED := 0.9
const RECOVER := 0.35
const COOLDOWN := 0.8
const TURN_DELAY := 0.6
const SPIKES := 6
const SPIKE_GAP := 20.0
const SPIKE_STEP := 0.09
const FIST_DAMAGE := 16
## The sheet's animation for each state (docs/art/enemy-style-guide.md 4).
const ANIMS := {"idle": "idle", "walk": "walk", "windup": "windup", "rooted": "rooted", "recover": "recover"}
## The raised crystal fist in the windup (world px from his feet, facing right), where it blazes.
const FIST_AT := Vector2(6, -30)
const CRYSTAL_LIGHT := Color("f0a0f0")
## The lane his spikes will rise along, lit through the windup (bible 12.144, pass 667):
## a crack of crystal light runs along the floor from his fist over `LANE_RUN` of the
## windup, and a seam opens at each spike's spot as it passes, so the tell shows the
## attack and where it lands, not only a glow on his fist.
const LANE_RUN := 0.4
## The lane draws on its own layer over the tide (`Tide`, z 1), so it reads under water
## as a glow through it, and under the struck foe (`Enemy.STRUCK_Z`, 3).
const LANE_Z := 2
## From the windup's first frame every seam shows faint, at this share of its light,
## and comes up to full as the crack reaches it.
const SEAM_FAINT := 0.4
const LANE_HOT := Color("fff0ff")
## Since pass 674 the tips stand 10 px (7 before) and the lane and every tip are keyed in
## `LANE_KEY`, a near-black pixel round them (12.151): the pass 670 grade still read the
## lane as a "thin spike tell", pale pink on the Flooded Hall's pale tide.
const SEAM_HEIGHT := 10.0
const LANE_KEY := Color("1a0f22")
const LANE_KEY_ALPHA := 0.85
## The glow standing over the lane: two clean steps, this high (world px).
const GLOW_LOW := 4.0
const GLOW_HIGH := 9.0
## The crystal on his back (world px from his feet, facing right): where his glow sits
## (`FoeGlow`, bible 12.52), and its half extents.
const CRYSTAL_AT := Vector2(-3, -20)
const GLOW_REACH := Vector2(40, 34)

var _struck := false
var _behind_time := 0.0
var _cool := 0.0
var _died_at := -1.0
## The light his crystal throws on the dark behind him.
var glow: FoeGlow
## The layer the lit lane is drawn on (LANE_Z).
var lane_fx: Node2D


## Draws the dwarf's lit lane on its own layer.
class LaneFx extends Node2D:
	var dwarf: CrystalDwarf

	func _draw() -> void:
		dwarf.draw_lane(self)


func _init() -> void:
	max_hp = 48
	gold_min = 9
	gold_max = 15
	poison_drops = true
	xp = 24
	contact_damage = 14
	body_size = Vector2(20, 28)
	knockback = 30.0


func _ready() -> void:
	super._ready()
	glow = FoeGlow.new()
	glow.color = CRYSTAL_LIGHT
	glow.reach = GLOW_REACH
	glow.at = CRYSTAL_AT
	add_child(glow)
	lane_fx = LaneFx.new()
	lane_fx.dwarf = self
	lane_fx.z_as_relative = false
	lane_fx.z_index = LANE_Z
	add_child(lane_fx)


## How strongly his crystal glows now: out when he is dead, swelling through the windup.
func glow_strength() -> float:
	if dead:
		return 0.0
	if state == "windup":
		return 1.0 + clampf(state_time / WINDUP, 0.0, 1.0)
	return 1.0


## True while his fist is rooted in the floor.
func rooted() -> bool:
	return state == "rooted"


func _modify_damage(damage: int, dir: Vector2) -> int:
	# The crystal on his back turns a blow from behind, unless it comes down from
	# above or his fist is stuck in the floor.
	if dir.y > 0.0 or rooted() or is_staggered():
		return damage
	if dir.x != 0.0 and signf(dir.x) == facing:
		return 0
	return damage


func _think(delta: float) -> void:
	_cool -= delta
	var off := player_offset()
	var seen := off.x != INF and absf(off.x) < SIGHT.x and absf(off.y) < SIGHT.y
	var in_front := seen and signf(off.x) == facing
	match state:
		"idle", "walk":
			if state == "idle":
				set_state("walk")
			if in_front and absf(off.x) < REACH and is_on_floor() and _cool <= 0.0:
				velocity.x = 0.0
				set_state("windup")
				Sfx.play("swell", 0.1, -4.0)
				return
			_behind_time = _behind_time + delta if seen and not in_front else 0.0
			if _behind_time > TURN_DELAY:
				facing = -facing
				_behind_time = 0.0
			if is_on_floor() and (_wall_ahead() or not _floor_ahead()):
				facing = -facing
			velocity.x = facing * WALK_SPEED
		"windup":
			velocity.x = 0.0
			if state_time >= WINDUP:
				_struck = false
				set_state("rooted")
		"rooted":
			velocity.x = 0.0
			if not _struck:
				_struck = true
				hit_player_in_rect(fist_rect(), FIST_DAMAGE, false)
				_erupt()
			if state_time >= ROOTED:
				set_state("recover")
		"recover":
			velocity.x = 0.0
			if state_time >= RECOVER:
				_cool = COOLDOWN
				set_state("walk")
		_:
			set_state("walk")


## Where the fist comes down, just in front of him.
func fist_rect() -> Rect2:
	var x := global_position.x + facing * (body_size.x * 0.5 + 6.0)
	return Rect2(Vector2(x - 8.0, global_position.y - 16.0), Vector2(16, 16))


## The spikes burst along the floor away from him, stopping at a wall or a ledge.
func _erupt() -> void:
	Feel.add_trauma(0.25)
	Sfx.play("break", 0.05, 3.0)
	var spots := spike_spots()
	for i in spots.size():
		var s := CrystalSpike.new()
		s.delay = i * SPIKE_STEP
		get_parent().add_child(s)
		s.global_position = spots[i]


## Where the spikes will rise (world positions on the floor), stopping at a wall or a
## ledge: the eruption and the lane lit through the windup both read it.
func spike_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var room := get_parent() as Room
	for i in SPIKES:
		var at := Vector2(global_position.x + facing * (body_size.x * 0.5 + 14.0 + i * SPIKE_GAP), global_position.y)
		if room != null and (room.is_solid_at(at + Vector2(0, -6)) or not (room.is_solid_at(at + Vector2(0, 4)) or room.is_one_way_at(at + Vector2(0, 4)))):
			break
		out.append(at)
	return out


## How far along the lane the crack has run (0 to 1) at this point in the windup.
func lane_lit() -> float:
	if state != "windup" or dead:
		return 0.0
	return clampf(maxf(state_time, 1.0 / 60.0) / (WINDUP * LANE_RUN), 0.0, 1.0)


## The lit lane in his own space: the crack's start and end x on the floor line, every
## spike spot (each seam's x) and those the crack has reached. Empty while nothing is lit.
func lane_now() -> Dictionary:
	var lit := lane_lit()
	if lit <= 0.0:
		return {}
	var spots := spike_spots()
	if spots.is_empty():
		return {}
	var x0 := facing * (body_size.x * 0.5 - 4.0)
	var x1 := spots[spots.size() - 1].x - global_position.x + facing * 6.0
	var tip := lerpf(x0, x1, lit)
	var seams: Array[float] = []
	var reached: Array[float] = []
	for s in spots:
		var sx := s.x - global_position.x
		seams.append(sx)
		if (sx - x0) * facing <= (tip - x0) * facing:
			reached.append(sx)
	return {"from": x0, "to": tip, "seams": seams, "reached": reached}


func _wall_ahead() -> bool:
	return test_move(global_transform, Vector2(facing * 4, 0))


func _floor_ahead() -> bool:
	var t := global_transform.translated(Vector2(facing * (body_size.x * 0.5 + 2), 0))
	return test_move(t, Vector2(0, 6))


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	if glow != null:
		glow.strength = glow_strength()
	if lane_fx != null:
		lane_fx.queue_redraw()
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


## The animation and its time for what he is doing now.
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered():
		return ["stagger", state_time]
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	var a: String = ANIMS.get(state, "idle")
	if a == "walk" and absf(velocity.x) < 1.0:
		a = "idle"
	return [a, state_time if a != "idle" and a != "walk" else Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var glow := state == "windup" and telegraph_pulse()
	var now := anim_now()
	draw_sheet("crystal_dwarf", now[0], now[1], flashing() or glow)
	if state == "windup" and not dead:
		# The raised fist brightens: the tell.
		draw_circle(FIST_AT * Vector2(facing, 1), 8.0 + 3.0 * sin(state_time * 30.0), Color(CRYSTAL_LIGHT, 0.25))


## The crack along the floor to where the spikes will rise: a jagged line of crystal
## light on the floor's top with a white-hot core, a low glow standing over it, a hot
## running tip, and a small crystal tip at each spike's spot, faint until the crack
## reaches it.
func draw_lane(on: CanvasItem) -> void:
	var lane := lane_now()
	if lane.is_empty():
		return
	var x0: float = lane["from"]
	var x1: float = lane["to"]
	var pulse := 0.8 + 0.2 * sin(state_time * 30.0)
	var a := floorf(minf(x0, x1))
	var b := ceilf(maxf(x0, x1))
	# The glow over the lane, in two clean steps (no dither, as the air's shade, 12.3).
	on.draw_rect(Rect2(a, -GLOW_LOW, b - a, GLOW_LOW), Color(CRYSTAL_LIGHT, 0.22 * pulse))
	on.draw_rect(Rect2(a, -GLOW_HIGH, b - a, GLOW_HIGH - GLOW_LOW), Color(CRYSTAL_LIGHT, 0.1 * pulse))
	var x := a
	while x < b:
		# A step of three pixels, rising a pixel on every other step: a crack, not a rule.
		var up := 1.0 if int(absf(x) / 3.0) % 2 == 0 else 0.0
		var w := minf(3.0, b - x)
		# The key: a dark pixel over the crack and down to the floor's top under it.
		on.draw_rect(Rect2(x, -3.0 - up, w, 3.0 + up), Color(LANE_KEY, LANE_KEY_ALPHA))
		on.draw_rect(Rect2(x, -2.0 - up, w, 2.0), Color(CRYSTAL_LIGHT, pulse))
		on.draw_rect(Rect2(x, -1.0 - up, w, 1.0), Color(LANE_HOT, 0.9 * pulse))
		x += 3.0
	# The running tip burns white.
	on.draw_rect(Rect2(x1 - 2.5, -4.0, 5.0, 4.0), Color(LANE_KEY, LANE_KEY_ALPHA))
	on.draw_rect(Rect2(x1 - 1.5, -3.0, 3.0, 3.0), Color(LANE_HOT, pulse))
	var reached: Array = lane["reached"]
	for sx: float in lane["seams"]:
		var k := pulse if reached.has(sx) else SEAM_FAINT
		_draw_tip(on, sx, k)


## A small crystal tip standing out of the floor where a spike will rise: a pointed
## shard SEAM_HEIGHT tall, rim-lit on its left (the key light, 12.3).
func _draw_tip(on: CanvasItem, sx: float, k: float) -> void:
	var x := roundf(sx)
	# The key first: the shard a pixel wider each side and a pixel taller, in near-black.
	for row in int(SEAM_HEIGHT) + 1:
		var kh := floorf((SEAM_HEIGHT - row) / 3.0) + 1.0
		on.draw_rect(Rect2(x - kh - 1.0, -1.0 - row, kh * 2.0 + 2.0, 1.0), Color(LANE_KEY, LANE_KEY_ALPHA * maxf(k, SEAM_FAINT)))
	for row in int(SEAM_HEIGHT):
		var half := floorf((SEAM_HEIGHT - row) / 3.0)
		var y := -1.0 - row
		on.draw_rect(Rect2(x - half - 1.0, y, half * 2.0 + 2.0, 1.0), Color(CRYSTAL_LIGHT, 0.85 * k))
		on.draw_rect(Rect2(x - half - 1.0, y, 1.0, 1.0), Color(LANE_HOT, 0.9 * k))
