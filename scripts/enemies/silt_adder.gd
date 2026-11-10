class_name SiltAdder
extends Enemy
## A Silt Adder (design bible 7, pass 273): the original's serpent that floats up and
## down, most often over the ladders. A sea-green hooded serpent the length of
## a man, it rises and sinks along its own column, so a climb past it is timed
## to its swing. When you are level with it and in front, within about seven
## tiles, it draws its head back and flares its hood with a hiss (telegraph),
## then strikes straight out along that level, and glides back to its column.
## The strike is a bite, and a shield's parry meets it like any blade's: no
## harm, and the serpent reels (pass 274). Drawn from its PixelLab sheet (art pass 2).
## As in the original, a slain Silt Adder always leaves the largest bread there is,
## a great loaf (pass 281).

## How far it floats above and below its home, and how long one swing takes.
const SWING := 40.0
const SWING_TIME := 3.2
const SIGHT := 112.0
## Level with it: the player's chest within this many px of its head.
const LEVEL := 24.0
const WINDUP := 0.5
## In the coil it follows your height along its column, slower than you climb
## (pass 275): a climber who keeps climbing is still met by the strike, and the
## safe way past is in its recovery after a strike.
const COIL_TRACK := 60.0
const STRIKE_SPEED := 260.0
const STRIKE_TIME := 0.4
const RETURN_SPEED := 120.0
const COOLDOWN := 2.0
## Its body brushed against: a scrape. The strike's bite is the real harm,
## and it can be parried.
const TOUCH_DAMAGE := 8
const BITE_DAMAGE := 16

const SHEET := "silt_adder"

var _dir := Vector2.ZERO
var _cooldown := 0.0
## Whether this strike has bitten (or been parried) already.
var _bit := false
## Where in its swing it starts (0 to 1), so a room's Silt Adders need not swing
## together, and the game time it has floated (the swing follows game time,
## not the wall clock, so hitstop and slow motion hold it).
var _phase := 0.0
var _swung := 0.0


func _init() -> void:
	max_hp = 22
	contact_damage = TOUCH_DAMAGE
	gold_min = 3
	gold_max = 5
	xp = 6
	sure_drop = "loaf"
	body_size = Vector2(22, 44)
	body_centered = true
	uses_gravity = false
	knockback = 160.0
	state = "float"


func _ready() -> void:
	super._ready()
	_phase = fposmod(global_position.x * 0.013, 1.0)


## The point on its column it floats toward at swing time `t` (seconds).
func swing_point(t: float) -> Vector2:
	return home + Vector2(0, sin((t / SWING_TIME + _phase) * TAU) * SWING)


## Where the jaws close in a strike: just ahead of it, along its level.
func bite_rect() -> Rect2:
	return Rect2(center() + Vector2(facing * 18.0 - 12.0, -12.0), Vector2(24, 20))


## True when the player is level with its head and in front of it, near enough to strike.
func sees_level(off: Vector2) -> bool:
	return off.x != INF and absf(off.y) <= LEVEL and absf(off.x) <= SIGHT


func _think(delta: float) -> void:
	_cooldown -= delta
	var off := player_offset()
	# In the strike the bite does the harm (parryable), not the touch. Gliding
	# back it is harmless too (bible 6.15): a strike ducked under is not paid
	# for with a scrape as it passes back over you.
	contact_damage = 0 if state in ["strike", "return"] else TOUCH_DAMAGE
	match state:
		"float":
			_swung += delta
			var target := swing_point(_swung)
			velocity = ((target - global_position) * 4.0).limit_length(120.0)
			if off.x != INF:
				face_player()
			if _cooldown <= 0.0 and sees_level(off):
				velocity = Vector2.ZERO
				set_state("coil")
				Sfx.play("silt_adder_hiss", 0.1, -4.0)
		"coil":
			velocity = Vector2.ZERO
			if off.x != INF:
				# It draws its head level with yours (bible 6.15), so on the
				# ground a crouch ducks the strike; on a ladder you can't.
				var want := clampf(center().y + player_head_offset().y, home.y - SWING, home.y + SWING)
				velocity.y = clampf((want - global_position.y) / maxf(delta, 0.001), -COIL_TRACK, COIL_TRACK)
			face_player()
			if state_time >= WINDUP:
				_dir = Vector2(facing, 0)
				_bit = false
				set_state("strike")
				Sfx.play("silt_adder_strike", 0.1, -4.0)
		"strike":
			velocity = _dir * STRIKE_SPEED
			if not _bit and hit_player_in_rect(bite_rect(), BITE_DAMAGE) != "":
				_bit = true
			if state != "strike":
				return
			if state_time >= STRIKE_TIME or is_on_wall():
				set_state("return")
		"return":
			var d := home - global_position
			velocity = d.normalized() * RETURN_SPEED
			if absf(d.x) < 4.0 or state_time > 3.0:
				_cooldown = COOLDOWN
				set_state("float")
		_:
			set_state("return")


var _died_at := -1.0


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


## The animation and its time for what it is doing now (docs/art/enemy-style-guide.md 4).
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered():
		return ["stagger", state_time]
	if _hitstun > 0.0:
		return ["hurt", 0.0]
	if state in ["coil", "strike"]:
		return [state, state_time]
	return ["float", Time.get_ticks_msec() * 0.001 + _phase * 5.0]


func _draw() -> void:
	var white := flashing() or (state == "coil" and telegraph_pulse())
	var now := anim_now()
	var jitter := Vector2(randf_range(-1, 1), 0).round() if state == "coil" else Vector2.ZERO
	draw_sheet(SHEET, now[0], now[1], white, jitter)
