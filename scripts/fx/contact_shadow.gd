class_name ContactShadow
extends Node2D
## A soft dark pool on the ground under what stands there (design bible 12.110, pass 634).
##
## The pass 630 grade: "props are not grounded: no contact shadows under chests, steles,
## the hero or foes". The pool is pixel rows, not a smooth blur: a wide faint band and
## a narrower dark core, one row above the ground line (under the feet) and three on the
## ground's top, so it darkens the lip a body stands on. It draws in front of the tiles
## (absolute z 0) and behind its body.
##
## A body that moves (`follow`) casts it on the ground below it: as it leaves the ground
## the pool shrinks and fades, and past `REACH` there is none. A prop that stands still
## draws it at its origin, which is its foot.

## The shadow's tone: the master palette's deepest neutral.
const TONE := Color("131217")
## The faint outer band's alpha.
const EDGE := 0.36
## The core's alpha, over the band.
const CORE := 0.34
## The core's width, a share of the band's.
const CORE_SHARE := 0.6
## The rows of the pool, from the ground line: one above it, three on the ground.
const TOP := -1
const ROWS := 4
## Each row's width, a share of the pool's: a pool that tapers, not a slab. The ground
## line is the widest.
const ROW_SHARE := [0.6, 1.0, 0.78, 0.45]
## How far below a body its shadow still falls, in pixels.
const REACH := 72.0
## At the end of the reach the pool is this share of its width.
const FAR_WIDTH := 0.5

## Half the pool's width on the ground, in pixels.
var half_width := 8.0
## A moving body: the pool falls on the ground below it (see `drop`).
var follow := false
## The ground below the origin, in pixels; -1 when there is none within `REACH`.
var drop := 0.0
var _gone := false


static func make(half_w: float, moving := false) -> ContactShadow:
	var s := ContactShadow.new()
	s.half_width = half_w
	s.follow = moving
	return s


func _ready() -> void:
	z_as_relative = false
	z_index = 0
	show_behind_parent = true
	if follow:
		_find_ground()


func _physics_process(_delta: float) -> void:
	if follow:
		# Level on the ground whatever way the body turns.
		var body := get_parent() as Node2D
		if body != null:
			rotation = -body.rotation
		_find_ground()
		var gone := body_gone()
		if gone != _gone:
			_gone = gone
			queue_redraw()


## A foe that has died (and waits to come back) casts nothing.
func body_gone() -> bool:
	var e := get_parent() as Enemy
	return e != null and e.dead


func _find_ground() -> void:
	var before := drop
	var body := get_parent() as CollisionObject2D
	var from := global_position + Vector2(0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, global_position + Vector2(0, REACH), Player.LAYER_WORLD)
	if body != null:
		q.exclude = [body.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q) if is_inside_tree() else {}
	drop = maxf(0.0, (hit["position"] as Vector2).y - global_position.y) if not hit.is_empty() else -1.0
	if roundf(drop) != roundf(before):
		queue_redraw()


## The share of full strength the pool has at a drop: 1 on the ground, 0 at `REACH`.
static func strength_at(d: float) -> float:
	if d < 0.0:
		return 0.0
	return clampf(1.0 - d / REACH, 0.0, 1.0)


func _draw() -> void:
	var k := strength_at(drop) if follow else 1.0
	if k <= 0.0 or _gone:
		return
	var at := Vector2(0, roundf(drop) if follow else 0.0)
	draw_pool(self, at, half_width * lerpf(FAR_WIDTH, 1.0, k), k)


## The pool's rows on `canvas`, centred on `at` (a point on the ground line). Each row is
## a whole number of pixels wide, widest on the ground line, narrower above and below.
static func draw_pool(canvas: CanvasItem, at: Vector2, half_w: float, strength := 1.0) -> void:
	for r in ROWS:
		var hw := row_half_width(r, half_w)
		if hw < 1.0:
			continue
		var y := at.y + TOP + r
		canvas.draw_rect(Rect2(roundf(at.x - hw), y, hw * 2.0, 1.0), Color(TONE, EDGE * strength))
		var core := roundf(hw * CORE_SHARE)
		if core >= 1.0:
			canvas.draw_rect(Rect2(roundf(at.x - core), y, core * 2.0, 1.0), Color(TONE, CORE * strength))


## Half the width of row `r` (0 is the row above the ground line), whole pixels.
static func row_half_width(r: int, half_w: float) -> float:
	return roundf(half_w * float(ROW_SHARE[r]))
