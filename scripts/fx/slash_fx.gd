class_name SlashFx
extends Node2D
## The smear arc for a sword swing or Delver's Pick down-strike. Follows the player.

const LIFE := 0.12
const COLOR := Color("f6eed2")
const EDGE := Color("ffffff")
const HEAVY := Color("ffe9a8")

var _kind := "side"
var _facing := 1
var _combo := 1
var _heavy := false
var _life := LIFE
## Scales the smear for a bigger blade (the Dwarvish Broad Sword's arc).
var _size := 1.0


func setup(kind: String, facing: int, combo := 1, heavy := false, size := 1.0) -> void:
	_size = size
	_kind = kind
	_facing = facing
	_combo = combo
	_heavy = heavy
	z_index = 3


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_life / LIFE, 0.0, 1.0)
	if _kind == "thrust":
		_draw_thrust(k)
		return
	var center: Vector2
	var from: float
	var to: float
	match _kind:
		"up":
			center = Vector2(0, -38)
			from = deg_to_rad(-170)
			to = deg_to_rad(-10)
		"down":
			center = Vector2(0, -6)
			from = deg_to_rad(20)
			to = deg_to_rad(160)
		"low":
			# A crouch's cut (bible 6.15): a flat sweep along the floor.
			center = Vector2(_facing * 6, -4)
			from = deg_to_rad(-40) if _facing > 0 else deg_to_rad(220)
			to = deg_to_rad(5) if _facing > 0 else deg_to_rad(175)
		_:
			center = Vector2(_facing * 6, -22)
			from = deg_to_rad(-70) if _facing > 0 else deg_to_rad(250)
			to = deg_to_rad(70) if _facing > 0 else deg_to_rad(110)
	# The second combo hit sweeps the other way, so a chain reads as back-and-forth cuts.
	if _combo == 2:
		var t := from
		from = to
		to = t
	var radius := (26.0 if _heavy else 20.0) * _size
	var width := (9.0 if _heavy else 6.0) * _size
	var sweep := lerpf(0.35, 1.0, 1.0 - k)
	var end := lerpf(from, to, sweep)
	draw_arc(center, radius, from, end, 12, Color(HEAVY if _heavy else COLOR, k), width)
	draw_arc(center, radius + 3.0, from, end, 12, Color(EDGE, k), 2.0)


## A Thrust: a straight streak of light from the hand to the point, thinning
## toward the tip, that shoots out and fades.
func _draw_thrust(k: float) -> void:
	var length := (Player.THRUST_LENGTH + 10.0) * _size * lerpf(0.5, 1.0, 1.0 - k)
	var y := -22.0
	var x0 := _facing * 6.0
	var tip := Vector2(x0 + _facing * length, y)
	draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 4), tip, Vector2(x0, y + 4)]), Color(HEAVY, k * 0.85))
	draw_line(Vector2(x0, y), tip, Color(EDGE, k), 2.0)
	draw_circle(tip, 2.5, Color(EDGE, k))
