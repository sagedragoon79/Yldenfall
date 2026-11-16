class_name Cloak
extends Node2D
## The hero's cloak, a layer of its own over the body sets (paper doll, design
## bible 13.4): a cape of two verlet chains hung from the frame's neck and back
## points, so it trails real movement, and a hood that is down in a town and
## up anywhere else (Sean, 2026-10-27), raised or lowered over HOOD_TIME when
## that changes. Shapes from Sean's side views (/mnt/project-files/armor/
## cloak-hood-up.jpg and cloak-hood-down.jpg): ankle length, flaring behind,
## gold trim down the front edge and the hem, a brooch at the shoulder, a
## pointed hood, and down, a cowl bunched at the nape. Under a helmet the hood stays down. It takes the worn dye's
## color; Warden Green is its own. The ranger's sheet draws its own cloak, so
## this shows only while a body set plays.

const SEGMENTS := 8
## The edge by the body and the outer edge: the outer one is longer, so the
## hem slants back like the concept's.
const INNER_LENGTH := 4.0
const OUTER_LENGTH := 4.4
const GRAVITY := 700.0
const DAMPING := 0.86
## Cloth is heavy: no point swings more than this a frame against the body
## (damping too works against the body's own motion, and the wind gives the
## lean), so a sudden pull (a landing's squash) drags the cape instead of
## whipping it.
const MAX_SWING := 2.0
const HOOD_TIME := 0.35
const GREEN := Color("3f6a3f")
const TRIM := Color("cba040")
const OUTLINE := Color("120f19")

## The hood, relative to the frame's head point (crown of the skull), facing
## right: the outer edge from the front lip over the crown to the nape, then
## the face opening back up. Down, the same points bunch into a cowl on the
## shoulders, around the frame's back point.
const HOOD_UP: Array[Vector2] = [Vector2(4, 1.5), Vector2(2.5, -2), Vector2(-0.5, -3), Vector2(-4.5, -2.5),
	Vector2(-5, 2), Vector2(-5, 6), Vector2(-3.5, 9), Vector2(0, 10.5), Vector2(1.5, 9.5),
	Vector2(0.5, 6.5), Vector2(0, 3.5), Vector2(1.5, 1), Vector2(3, 0.5)]
const HOOD_DOWN: Array[Vector2] = [Vector2(2.5, -1), Vector2(1.5, -2), Vector2(0, -2.5), Vector2(-1.5, -2.5),
	Vector2(-2.5, -1.5), Vector2(-3, 0), Vector2(-2.5, 1.5), Vector2(-1, 2.5), Vector2(0.5, 2),
	Vector2(0.5, 1), Vector2(1, 0), Vector2(1.5, -0.5), Vector2(2, -0.5)]
## How far the outer edge stands out behind the inner one, per segment down:
## even hanging still the cape flares toward its hem.
const FLARE := 1.5

var player: Player
## 1 with the hood up, 0 down, and between while it is raised or lowered.
var hood := 1.0

var _inner: Array[Vector2] = []
var _outer: Array[Vector2] = []
var _inner_prev: Array[Vector2] = []
var _outer_prev: Array[Vector2] = []
## Where the body was last frame: the cape follows how it really moved (not
## its velocity, which a run into a wall keeps up).
var _body := Vector2.INF
var _moved := Vector2.ZERO


func _ready() -> void:
	# Not top_level, unlike the scarf: a top-level item draws over its parent's
	# later children, and the cape must stay behind the body. Its points live in
	# world space and are drawn shifted into the player's.
	hood = hood_target()


## Shown while a body set plays (its frames carry the back point).
func shown() -> bool:
	var sheet := player.visual.sheet
	# A body set drawn with its cloak on (manifest flag "cloak") needs no layer.
	return player.visual.visible and sheet != PlayerVisual.SHEET_NAME and not Sheet.flag(sheet, "cloak", false)


## Up outside a town, down in one or under a helmet. A circlet is a thin band: the hood goes over it.
func hood_target() -> float:
	var head := String(GameState.data.equipment.get("helmet", ""))
	if head != "" and not bool(GameData.item(head).get("circlet", false)):
		return 0.0
	var room := player.get_parent() as Room
	return 0.0 if room != null and room.is_town() else 1.0


func snap() -> void:
	_inner.clear()
	_outer.clear()
	var a := _anchors()
	for i in SEGMENTS + 1:
		_inner.append(a[0] + Vector2(0, INNER_LENGTH * i))
		_outer.append(a[1] + Vector2(0, OUTER_LENGTH * i))
	_inner_prev = _inner.duplicate()
	_outer_prev = _outer.duplicate()


## The cape's top corners in world space: by the neck and at the back.
func _anchors() -> Array[Vector2]:
	var info := player.visual.frame_info()
	var neck: Array = info.get("neck", [0, -38])
	var back: Array = info.get("back", [neck[0] - 3, neck[1] + 2])
	return [player.visual.point(Vector2(neck[0] - 1, neck[1] + 1)), player.visual.point(Vector2(back[0], back[1]))]


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		# Hit-stop (a pogo's 45 ms) freezes time: the cloak's wind would divide by zero.
		return
	hood = move_toward(hood, hood_target(), delta / HOOD_TIME)
	_moved = Vector2.ZERO if _body == Vector2.INF else player.global_position - _body
	if _moved.length() > 16.0:
		# A teleport (a door, a respawn), not a step.
		_moved = Vector2.ZERO
	_body = player.global_position
	var a := _anchors()
	if _inner.is_empty() or _inner[0].distance_to(a[0]) > 12.0:
		# First frame, or a teleport: hang it afresh.
		snap()
	var wind := Vector2(-player.facing * 40.0, 0.0) - _moved / delta * 1.5
	_step(_inner, _inner_prev, a[0], INNER_LENGTH, wind * 0.6, delta)
	_step(_outer, _outer_prev, a[1], OUTER_LENGTH, wind, delta)
	# The outer edge keeps behind the inner one (across the inner edge's run:
	# behind it hanging, under it streaming), flaring toward the hem.
	for i in range(1, SEGMENTS + 1):
		var n := (_inner[i] - _inner[0]).normalized().orthogonal() * -player.facing
		var gap := (_outer[i] - _inner[i]).dot(n)
		var want := 1.0 + FLARE * i
		if gap < want:
			var push := n * (want - gap)
			_outer[i] += push
			_outer_prev[i] += push
	queue_redraw()


func _step(points: Array[Vector2], prev: Array[Vector2], top: Vector2, length: float, wind: Vector2, delta: float) -> void:
	var carry := _moved
	for i in range(1, points.size()):
		var p := points[i]
		var v := carry + ((p - prev[i] - carry) * DAMPING).limit_length(MAX_SWING)
		prev[i] = p
		points[i] = p + v + (Vector2(0, GRAVITY) + wind) * delta * delta
	points[0] = top
	prev[0] = top
	var back_line := top.x
	for _iter in 3:
		for i in range(1, points.size()):
			var d := points[i] - points[i - 1]
			var len := d.length()
			if len > length:
				points[i] = points[i - 1] + d / len * length
			# The cape hangs behind the body, never through it, and rests on the ground.
			# (Corrections move the last position too, so they add no swing.)
			if (points[i].x - back_line) * player.facing > 1.0:
				prev[i].x += back_line + player.facing - points[i].x
				points[i].x = back_line + player.facing
			points[i].y = minf(points[i].y, player.global_position.y - 0.5)


## The cloth's lit tone: the worn dye's, or Warden Green.
static func color() -> Color:
	var look := PlayerVisual.dye_look()
	return GREEN if look.is_empty() else look[0]


func _draw() -> void:
	if not shown() or _inner.is_empty():
		return
	draw_set_transform(-global_position)
	var base := color()
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in SEGMENTS + 1:
		points.append(_outer[i])
		points.append(_inner[i])
		# The outside of the cape lit, the side against the body in shadow.
		colors.append(base)
		colors.append(base.darkened(0.45))
		if i < SEGMENTS:
			var k := i * 2
			indices.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)
	var rim := PackedVector2Array(_outer)
	var hem := [_outer[SEGMENTS], _inner[SEGMENTS]]
	draw_polyline(rim, OUTLINE, 1.0)
	draw_polyline(PackedVector2Array(_inner), OUTLINE, 1.0)
	draw_line(hem[0], hem[1], OUTLINE, 1.5)
	# Gold down the front edge and along the hem.
	draw_polyline(PackedVector2Array(_inner.slice(1)), TRIM, 0.5)
	draw_line(hem[0] + Vector2(0, -0.5), hem[1] + Vector2(0, -0.5), TRIM, 0.5)


## Draws the hood on the visual (its local space: facing right, feet at the
## origin), between down and up by `hood`.
func draw_hood(ci: CanvasItem, info: Dictionary, tint: Color) -> void:
	if not info.has("head") or not info.has("back"):
		return
	var head := Vector2(info.head[0], info.head[1])
	var back := Vector2(info.back[0], info.back[1])
	var t := smoothstep(0.0, 1.0, hood)
	var shape := PackedVector2Array()
	for i in HOOD_UP.size():
		shape.append((back + HOOD_DOWN[i]).lerp(head + HOOD_UP[i], t))
	var base := color() * tint
	var outline := shape.duplicate()
	outline.append(shape[0])
	if Geometry2D.triangulate_polygon(shape).is_empty():
		return
	ci.draw_colored_polygon(shape, base)
	ci.draw_polyline(outline, OUTLINE, 1.0)
	if t > 0.5:
		# Up: the rim of the face opening, gold.
		var lip := shape.slice(8)
		lip.append(shape[0])
		ci.draw_polyline(lip, TRIM * tint, 0.5)
	else:
		# Down: the cowl's gold rim on top.
		ci.draw_polyline(shape.slice(0, 5), TRIM * tint, 0.5)
	# The brooch at the front of the shoulder.
	if info.has("neck"):
		var brooch := Vector2(info.neck[0] + 1.5, info.neck[1] + 2.5)
		ci.draw_circle(brooch, 1.3, OUTLINE)
		ci.draw_circle(brooch, 0.8, TRIM.lightened(0.2) * tint)
