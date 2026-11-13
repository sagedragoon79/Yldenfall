class_name ThunderBeetle
extends Enemy
## A Thunder Beetle of Carillon (design bible 7): a beetle as big as a dog,
## its storm-violet shell striped with gold, that trundles the shrine stones
## soaking up the storm. The shell turns blows from the side, but not from
## above: pogo it. Linger near it and its wing cases lift and crackle (the
## telegraph), then it discharges a ring of lightning around itself that
## can't be parried, above it as much as beside it. Spent, its wing cases hang
## open and every blow lands in full. Legend `t`.

## How near you must come (px, centre to centre) before it charges.
## What its blow is made of (design bible 5.6).
const DAMAGE_KIND := DamageKind.LIGHTNING
const TRIGGER := 64.0
const WALK_SPEED := 28.0
const CHARGE := 0.6
const DISCHARGE := 0.3
const SPENT := 1.1
## After a discharge it walks a while before it can charge again.
const COOLDOWN := 1.4
## The lightning's reach from the centre of the shell.
const RADIUS := 46.0
const DISCHARGE_DAMAGE := 14
const TOUCH_DAMAGE := 12
## Share of a side blow that gets through the shell.
const SHELL := 0.3

## Sparks crackle this high over its feet while the wing cases are up (world px).
const SPARK_Y := -22.0
const SPARK := Color("f8f0b0")
const ARC := Color("b8a8ff")

var _cool := 0.0
var _struck := false


func _init() -> void:
	max_hp = 44
	gold_min = 6
	gold_max = 12
	xp = 14
	body_size = Vector2(30, 18)
	knockback = 40.0
	contact_damage = TOUCH_DAMAGE
	state = "walk"


func _think(delta: float) -> void:
	_cool -= delta
	var off := player_offset()
	var near := off.x != INF and off.length() < TRIGGER
	match state:
		"walk":
			if _edge_ahead():
				facing = -facing
			velocity.x = facing * WALK_SPEED
			if near and _cool <= 0.0:
				velocity.x = 0.0
				set_state("charge")
				Sfx.play("static", 0.05, -3.0)
		"charge":
			velocity.x = 0.0
			if state_time >= CHARGE:
				_struck = false
				set_state("discharge")
				Sfx.play("zap", 0.05)
				Feel.add_trauma(0.2)
		"discharge":
			velocity.x = 0.0
			if not _struck and _player_in_ring():
				_struck = true
				var p := player()
				p.receive_attack(DISCHARGE_DAMAGE, self, false)
			if state_time >= DISCHARGE:
				set_state("spent")
		"spent":
			velocity.x = 0.0
			if state_time >= SPENT:
				_cool = COOLDOWN
				set_state("walk")
		_:
			set_state("walk")


## Is any part of the player's body within the lightning's reach?
func _player_in_ring() -> bool:
	var p := player()
	if p == null or p.dead:
		return false
	var r := p.body_rect()
	var c := center()
	var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return nearest.distance_to(c) <= RADIUS


## Shell open or not, a blow from above lands in full.
func exposed() -> bool:
	return state == "spent"


func _modify_damage(damage: int, dir: Vector2) -> int:
	if exposed() or dir.y > 0.0:
		return damage
	return maxi(1, roundi(damage * SHELL))


func _edge_ahead() -> bool:
	if not is_on_floor():
		return false
	if test_move(global_transform, Vector2(facing * 4, 0)):
		return true
	var t := global_transform.translated(Vector2(facing * (body_size.x * 0.5 + 2), 0))
	return not test_move(t, Vector2(0, 6))


## The sheet's animation for each state (docs/art/enemy-style-guide.md 4).
const ANIMS := {"walk": "walk", "charge": "charge", "discharge": "discharge", "spent": "spent"}

var _died_at := -1.0


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
	if _hitstun > 0.0:
		return ["hurt", HITSTUN - _hitstun]
	if is_staggered():
		return ["spent", state_time]
	var a: String = ANIMS.get(state, "walk")
	if a == "walk" and absf(velocity.x) < 1.0:
		a = "idle"
	return [a, state_time if a != "idle" and a != "walk" else Time.get_ticks_msec() * 0.001]


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var now := anim_now()
	draw_sheet("thunder_beetle", now[0], now[1], flashing() or (state == "charge" and telegraph_pulse()))
	# Static: sparks jumping between the lifted wing cases.
	if not dead and (state == "charge" or state == "discharge"):
		var bright := telegraph_pulse() or state == "discharge"
		for k in 3:
			var sx := -10.0 + fposmod(t * 37.0 + k * 7.3, 20.0)
			var sy := SPARK_Y - fposmod(t * 23.0 + k * 3.1, 4.0)
			draw_rect(Rect2(sx, sy, 1, 2), SPARK if bright else ARC)
	if state == "discharge" and not dead:
		_draw_ring(t)


## The discharge: a jagged ring of lightning around the shell.
func _draw_ring(t: float) -> void:
	var c := center() - global_position
	var k := clampf(state_time / DISCHARGE, 0.0, 1.0)
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var a := TAU * i / n
		var jag := 1.0 + (0.12 if (i + int(t * 30.0)) % 2 == 0 else -0.08)
		pts.append(c + Vector2(cos(a), sin(a)) * RADIUS * jag)
	var col := Color(SPARK, 1.0 - k * 0.6)
	draw_polyline(pts, Color(ARC, 0.5 * (1.0 - k)), 3.0)
	draw_polyline(pts, col, 1.0)
	draw_circle(c, RADIUS * 0.9, Color(ARC, 0.12 * (1.0 - k)))
