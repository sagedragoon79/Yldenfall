class_name RuneDagger
extends Node2D
## The Rune Dagger (design bible 5.2, pass 184): an elven throwing dagger bound
## by a rune. Thrown, it flies point first, straight ahead (or straight up with
## Up held), and strikes the first foe it meets, or a wall (it passes up through one-way
## planks), or runs out of
## reach. Then it breaks into motes of rune light and reforms at the thrower's
## side a moment later (Player.dagger_ready), so it costs no magic and is never
## lost. It lights the fog as it flies (group "light").

const SPEED := 420.0
## How far it flies before its rune calls it home (px).
const RANGE := 160.0
const DAMAGE := 6
const SIZE := Vector2(10, 6)
## Seconds from its end until it is whole again at the thrower's side.
const RETURN := 0.4
## A strike on stone (pass 326): steel glancing off, not a shield's clank.
const WALL_SOUND := "dagger_ping"
const BLADE := Color("dfe6ee")
const EDGE := Color("8a94a8")
const HILT := Color("5a4028")
const RUNE := Color("7ff0e0")
const OUTLINE := Color("141a22")

var damage := DAMAGE
## What was thrown: the Rune Dagger, or a counted thrown weapon's item id
## (design bible 5.6). A counted one flies at its own speed and reach, does not
## come back, and lights nothing.
var kind := "rune_dagger"
var speed := SPEED
var reach := RANGE
## Unit direction of flight.
var dir := Vector2.RIGHT
var thrower: Player
var light_radius := 28.0

var _flown := 0.0
var _trail: Array[Vector2] = []
var _done := false


func _ready() -> void:
	z_index = 3
	add_to_group("projectile")
	if returns():
		add_to_group("light")


## Only the Rune Dagger reforms at the thrower's side.
func returns() -> bool:
	return kind == "rune_dagger"


func _physics_process(delta: float) -> void:
	if _done:
		return
	_trail.push_front(global_position)
	if _trail.size() > 5:
		_trail.pop_back()
	var step := speed * delta
	global_position += dir * step
	_flown += step
	var size := SIZE if dir.x != 0.0 else Vector2(SIZE.y, SIZE.x)
	var area := Rect2(global_position - size * 0.5, size)
	for c: Variant in Query.rect(get_world_2d(), area, Player.LAYER_WORLD | Player.LAYER_ENEMY):
		if c.is_in_group("enemy") and c.has_method("take_hit"):
			var hit_dir := dir if dir.x != 0.0 else Vector2(signf(float(thrower.facing) if thrower else 1.0), 0)
			if c.has_method("take_throw"):
				c.take_throw(damage, hit_dir)
			else:
				c.take_hit(damage, hit_dir)
			Feel.hitstop(0.03)
			Sfx.play("dagger_hit", 0.1)
			_end("hit")
			return
		if c is StaticBody2D:
			_end("wall")
			return
	# Tiles by their shape, so it flies up through one-way planks (and over
	# a slope's open half) the way you can jump through them.
	var room := get_parent() as Room
	if room != null and room.is_solid_at(global_position + dir * SIZE.x * 0.5):
		_end("wall")
		return
	if _flown >= reach:
		_end("spent")
		return
	queue_redraw()


## Its flight is over: it breaks into rune light, and the thrower's sheath
## starts to call it back.
func _end(how: String) -> void:
	_done = true
	var d := Dust.new()
	d.setup("parry")
	get_parent().add_child(d)
	d.global_position = global_position
	if how == "wall":
		Sfx.play(WALL_SOUND, 0.15, -4.0)
	if returns() and thrower != null and is_instance_valid(thrower):
		thrower.dagger_spent()
	queue_free()


func _draw() -> void:
	var a := dir.angle()
	for i in _trail.size():
		var p := to_local(_trail[i])
		var s := 3.0 - i * 0.5
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(RUNE if returns() else Color("c9b18c"), (0.5 if returns() else 0.3) - i * 0.06))
	draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
	if not returns():
		# A counted weapon: a dark iron-hard spike, pale at the point.
		draw_rect(Rect2(-6, -2, 13, 4), OUTLINE)
		draw_rect(Rect2(-5, -1, 9, 2), Color("6b4a35"))
		draw_rect(Rect2(-5, -1, 9, 1), Color("9c7450"))
		draw_rect(Rect2(4, -1, 3, 1), Color("e8dcc0"))
		draw_set_transform(Vector2.ZERO)
		return
	# Point first: a slim blade with a rune lit along it, a short dark hilt behind.
	draw_rect(Rect2(-8, -2, 15, 4), OUTLINE)
	draw_rect(Rect2(-3, -1, 9, 2), BLADE)
	draw_rect(Rect2(-3, 0, 9, 1), EDGE)
	draw_rect(Rect2(6, -1, 2, 1), BLADE)
	draw_rect(Rect2(0, -1, 3, 1), RUNE)
	draw_rect(Rect2(-4, -3, 1, 6), OUTLINE)
	draw_rect(Rect2(-7, -1, 3, 2), HILT)
