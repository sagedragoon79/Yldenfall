class_name GrubLump
extends Enemy
## A Heartwood grub (design bible 7) that crawls over floors, walls and
## ceilings, wrapping around corners. Crossing a ceiling with you below, it
## stops, rears and shivers (the telegraph), then lets go and drops on you.
## It lands stunned for a moment, then crawls on along the floor.
##
## It moves cell to cell over the room's tiles rather than by physics: `_cell`
## is the open tile it is in, `_side` points at the solid tile it clings to and
## `_dir` is the way it is crawling (always at right angles to `_side`).

const SPEED := 34.0
const WINDUP := 0.45
const DROP_DAMAGE := 16
const LAND_TIME := 0.6
## How far below a ceiling grub you must be, and how close sideways, for it to drop.
const DROP_SIGHT := Vector2(14, 180)
## Body center to the surface it clings to, in pixels.
const LIFT := 5.0
const SHEET := "grub_lump"

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)

var room: Room
var _cell := Vector2i.ZERO
var _side := DOWN
var _dir := Vector2i(-1, 0)
## Waypoints still to reach: {pos: Vector2, normal: Vector2}.
var _path: Array[Dictionary] = []
## The way the drawn body's back faces (lerped, so corners turn smoothly).
var _normal := Vector2.UP
var _angle := 0.0


func _init() -> void:
	max_hp = 18
	gold_min = 2
	gold_max = 4
	xp = 5
	contact_damage = 14
	body_size = Vector2(16, 10)
	body_centered = true
	uses_gravity = false
	knockback = 0.0


func _ready() -> void:
	super._ready()
	# It moves itself along the tiles; the world must not push it out of the wall it hugs.
	collision_mask = 0
	room = get_parent() as Room
	_attach()


## Clings to the nearest surface around its tile (the floor first), or falls.
func _attach() -> void:
	_path.clear()
	if room == null:
		return
	_cell = room.cell_at(global_position)
	for s: Vector2i in [DOWN, UP, Vector2i(-1, 0), Vector2i(1, 0)]:
		if _solid(_cell + s):
			_side = s
			# Along a floor or ceiling it sets off the way it faces; up a wall, upward.
			_dir = Vector2i(facing, 0) if s.y != 0 else UP
			global_position = _surface_pos(_cell, _side)
			_normal = -Vector2(_side)
			_angle = _normal.angle() + PI * 0.5
			set_state("crawl")
			return
	set_state("drop")


func _solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= room.size_tiles.x or cell.y >= room.size_tiles.y:
		return true
	var at := (Vector2(cell) + Vector2(0.5, 0.5)) * Room.TILE
	return room.is_solid_at(at) or room.is_secret_at(at)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Room.TILE


## Where the body's center sits in `cell` when clinging toward `side`.
func _surface_pos(cell: Vector2i, side: Vector2i) -> Vector2:
	return _cell_center(cell) + Vector2(side) * (Room.TILE * 0.5 - LIFT)


func on_ceiling() -> bool:
	return state == "crawl" and _side == UP


func clinging_side() -> Vector2i:
	return _side


func _think(delta: float) -> void:
	if state != "drop":
		velocity = Vector2.ZERO
	match state:
		"crawl":
			if _side == UP and _path.is_empty() and _player_below():
				set_state("windup")
				Sfx.play("buzz", 0.15, -10.0)
				return
			_crawl(delta)
			hit_player_in_rect(_body_rect(), contact_damage, false)
		"windup":
			if state_time >= WINDUP:
				set_state("drop")
				velocity = Vector2.ZERO
		"drop":
			_fall(delta)
		"land":
			if state_time >= LAND_TIME:
				set_state("crawl")
		_:
			set_state("crawl")


func _player_below() -> bool:
	var off := player_offset()
	if off.x == INF or absf(off.x) > DROP_SIGHT.x or off.y <= 0.0 or off.y > DROP_SIGHT.y:
		return false
	# Only with nothing solid between them.
	var c := _cell
	var bottom := room.cell_at(global_position + off)
	while c.y < bottom.y:
		c.y += 1
		if _solid(c):
			return false
	return true


func _crawl(delta: float) -> void:
	if _path.is_empty():
		_plan_step()
	var step := SPEED * delta
	while step > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0].pos
		var to := target - global_position
		if to.length() <= step:
			global_position = target
			step -= to.length()
			_normal = _path[0].normal
			_path.pop_front()
		else:
			global_position += to.normalized() * step
			step = 0.0
	_angle = lerp_angle(_angle, _normal.angle() + PI * 0.5, minf(1.0, delta * 14.0))
	# Head first: flip the sprite so it faces the way it crawls.
	var along := Vector2(cos(_angle), sin(_angle))
	facing = 1 if along.dot(Vector2(_dir)) >= 0.0 else -1


## Queues the waypoints to the next tile: straight on, up an inside corner,
## or around an outside corner.
func _plan_step() -> void:
	var s := Vector2(_side)
	var d := Vector2(_dir)
	var c := _cell_center(_cell)
	var lift := Room.TILE * 0.5 - LIFT
	if _solid(_cell + _dir):
		# A wall ahead: climb onto it.
		_path.append({pos = c + (s + d).normalized() * lift, normal = -(s + d).normalized()})
		_path.append({pos = c + d * lift, normal = -d})
		var new_side := _dir
		_dir = -_side
		_side = new_side
	elif _solid(_cell + _dir + _side):
		_cell += _dir
		_path.append({pos = _surface_pos(_cell, _side), normal = -s})
	else:
		# The surface ends: wrap around the corner of the tile it clings to.
		var corner := c + (s + d) * Room.TILE * 0.5
		_path.append({pos = corner + (d - s).normalized() * LIFT, normal = (d - s).normalized()})
		_cell += _dir + _side
		var new_side := -_dir
		_dir = _side
		_side = new_side
		_path.append({pos = _surface_pos(_cell, _side), normal = -Vector2(_side)})


func _fall(delta: float) -> void:
	_path.clear()
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	_angle = lerp_angle(_angle, 0.0, minf(1.0, delta * 10.0))
	hit_player_in_rect(_body_rect(), DROP_DAMAGE, true)
	var below := global_position + Vector2(0, LIFT + velocity.y * delta)
	var floor_cell := room.cell_at(below)
	if room.is_solid_at(below) or room.is_one_way_at(below) or floor_cell.y >= room.size_tiles.y:
		_cell = floor_cell + UP
		_side = DOWN
		var off := player_offset()
		_dir = Vector2i(int(signf(off.x)) if off.x != INF and absf(off.x) > 2.0 else facing, 0)
		global_position = _surface_pos(_cell, _side)
		velocity = Vector2.ZERO
		_normal = Vector2.UP
		_angle = 0.0
		Feel.add_trauma(0.12)
		Sfx.play("land", 0.1, -6.0)
		set_state("land")


func _body_rect() -> Rect2:
	var size := body_size if absf(_normal.x) < 0.5 else Vector2(body_size.y, body_size.x)
	return Rect2(global_position - size * 0.5, size)


func stagger() -> void:
	super.stagger()
	velocity = Vector2.ZERO


func _respawn() -> void:
	super._respawn()
	_attach()


## The animation and its time for what it is doing now (docs/art/enemy-style-guide.md 4).
func anim_now() -> Array:
	if dead:
		return ["death", Time.get_ticks_msec() * 0.001 - _died_at]
	if is_staggered() or _hitstun > 0.0:
		return ["hurt", 0.0]
	if state in ["windup", "drop", "land"]:
		return [state, state_time]
	return ["crawl", Time.get_ticks_msec() * 0.001]


var _died_at := -1.0


func die() -> void:
	_died_at = Time.get_ticks_msec() * 0.001
	super.die()


func _process(_delta: float) -> void:
	# The dissolve runs after death, when the body no longer redraws itself: keep
	# the collapse playing under it.
	if dead and dissolving():
		queue_redraw()


func _draw() -> void:
	var white := flashing() or (state == "windup" and telegraph_pulse())
	var now := anim_now()
	var anim: String = now[0]
	var t: float = now[1]
	var shiver := Vector2(randf_range(-0.6, 0.6), 0) if state == "windup" else Vector2.ZERO
	# The sheet draws it on a floor with its feet at the origin; turn it so its
	# feet are on whatever it clings to.
	var feet := Vector2(0, LIFT).rotated(_angle) + shiver
	var f := Sheet.frame_at(SHEET, anim, t)
	draw_set_transform(feet.round(), _angle, Vector2(facing, 1))
	Sheet.draw(self, SHEET, anim, f)
	var over := flash_overlay(white)
	if white:
		Sheet.draw(self, SHEET, anim, f, over, true)
	draw_set_transform(Vector2.ZERO)
