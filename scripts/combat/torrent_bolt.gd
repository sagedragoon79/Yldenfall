class_name TorrentBolt
extends Node2D
## The Deluge spell: a fast water bolt. Damages enemies, splashes on walls, and
## calls `douse()` on anything in the "water_target" group (fire seals, basins),
## or `take_water(bolt)` where the side it flies in from matters.

const SIZE := Vector2(12, 8)
const LIFE := 1.2
const CORE := Color("bfe8ff")
const BODY := Color("4aa3df")
const DARK := Color("2a5d9c")

var damage := 12
var velocity := Vector2.ZERO
## Undertow (skill tree): pass through foes, striking each one once.
var pierce := false

var _struck := {}

var _life := LIFE
var _trail: Array[Vector2] = []


func _ready() -> void:
	z_index = 3
	add_to_group("projectile")


func _physics_process(delta: float) -> void:
	_life -= delta
	_trail.push_front(global_position)
	if _trail.size() > 5:
		_trail.pop_back()
	global_position += velocity * delta
	var area := Rect2(global_position - SIZE * 0.5, SIZE)
	var mask := Player.LAYER_WORLD | Player.LAYER_ENEMY
	var hits := Query.rect(get_world_2d(), area, mask)
	# Water targets first: a basin overlaps its own walls.
	for c: Variant in hits:
		if c.is_in_group("water_target") and c.has_method("take_water"):
			# A target that cares which way the water flies (the Haar Spring's
			# intakes take a bolt only into the mouth).
			c.take_water(self)
			_splash()
			return
		if c.is_in_group("water_target") and c.has_method("douse"):
			c.douse()
			_splash()
			return
	for c: Variant in hits:
		if c.is_in_group("enemy") and c.has_method("take_hit"):
			if _struck.has(c.get_instance_id()):
				continue
			_struck[c.get_instance_id()] = true
			c.take_hit(damage, Vector2(signf(velocity.x), 0))
			Feel.hitstop(0.04)
			if pierce:
				Sfx.play("splash", 0.1, -6.0)
				continue
			_splash()
			return
		if c is TileMapLayer or c is StaticBody2D:
			_splash()
			return
	if _life <= 0.0:
		_splash()
		return
	queue_redraw()


func _splash() -> void:
	var d := Dust.new()
	d.setup("splash")
	get_parent().add_child(d)
	d.global_position = global_position
	Sfx.play("splash", 0.1)
	queue_free()


func _draw() -> void:
	for i in _trail.size():
		var p := to_local(_trail[i])
		var s := 4.0 - i * 0.6
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(BODY, 0.6 - i * 0.1))
	var dir := signf(velocity.x)
	draw_rect(Rect2(-6, -3, 12, 6), DARK)
	draw_rect(Rect2(-5, -2, 10, 4), BODY)
	draw_rect(Rect2(dir * 2 - 1, -1, 3, 2), CORE)
