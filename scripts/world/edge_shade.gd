class_name EdgeShade
extends Node2D
## Ambient-occlusion rim shading on every solid edge that meets open air (design
## bible 12.3). Before this, a lit wall, floor or platform tile ran at full
## brightness right up to its boundary with the dark background, so it read as a
## sticker laid on the backdrop. Now the air-facing rim of each solid tile is
## darkened with a short gradient that fades inward, so the surface curves away
## into shadow at its edge and reads as a lit volume:
##
## - the **underside** of ledges and platforms darkens most (it faces away from
##   the top-left key light, design bible 12.3);
## - the **vertical faces** of walls darken moderately;
## - the **walking surface** on top darkens only faintly, so the lit top edge the
##   player reads as footing is kept.
##
## Concave corners deepen for free where two rims overlap. The lit centre of a
## solid mass and the open middle of a room are left untouched, so the gameplay
## layer keeps its contrast and combat readability is unchanged. It draws over
## the tiles but under the actors, once per room load, and costs nothing per
## frame.
##
## The room's outer boundary is treated as more solid (not air), so the frame of
## a room is never rimmed. A secret wall the player later breaks open is a rare
## case the static shade does not redraw for; the reveal flash covers it.

const TILE := 16
## A near-black with a faint cool bias, blended over the lit tile.
const COLOR := Color(0.0, 0.0, 0.02)
## Thin rects per rim; 4 reads as a gradient and stays cheap.
const STEPS := 4

## Which air-facing edge of a solid cell is being rimmed.
const TOP_BAND := 1 ## air above — the lit walking surface, faintest
const LEFT_BAND := 2 ## air to the left — a wall face
const RIGHT_BAND := 4 ## air to the right — a wall face
const UNDER_BAND := 8 ## air below — an underside, darkest

## Reach of the rim into the solid tile, world px, per edge.
const UNDER_REACH := 7.0
const SIDE_REACH := 5.0
const TOP_REACH := 3.0
## Peak alpha at the boundary, per edge.
const UNDER_ALPHA := 0.50
const SIDE_ALPHA := 0.34
const TOP_ALPHA := 0.14

var _solids: Dictionary
var _size: Vector2i
## Haunch cells (bible 12.78): cell -> true for a west haunch (solid top-left),
## false for an east one. They count as solid for their neighbours, but their own
## rim runs along the diagonal, since a square rim would shade their open half.
var _haunches: Dictionary = {}
## Walking slopes (`/`, `\`): solid for their neighbours, but with no square rim of
## their own, which would draw a dark box round their open half (bible 12.150).
var _slopes: Dictionary = {}


## Reads the room's final solid cells (`solids`) and rims them over the `size`
## tile grid. `haunches` are the cells among them solid on one side of a diagonal,
## `slopes` the walking slopes among them.
func setup(solids: Dictionary, size: Vector2i, haunches := {}, slopes := {}) -> void:
	_solids = solids
	_size = size
	_haunches = haunches
	_slopes = slopes
	queue_redraw()


func _ready() -> void:
	# Over the tiles (z 0) via tree order, under the actors added after the room.
	z_index = 0


## True if `cell` is open air: inside the room and not solid. Outside the room
## counts as solid, so the room's frame is never rimmed.
static func is_air(solids: Dictionary, size: Vector2i, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	return not solids.has(cell)


## The bitmask of air-facing edges of a solid `cell`. Returns 0 for an air cell.
static func bands_for(solids: Dictionary, size: Vector2i, cell: Vector2i) -> int:
	if not solids.has(cell):
		return 0
	var m := 0
	if is_air(solids, size, cell + Vector2i.UP):
		m |= TOP_BAND
	if is_air(solids, size, cell + Vector2i.LEFT):
		m |= LEFT_BAND
	if is_air(solids, size, cell + Vector2i.RIGHT):
		m |= RIGHT_BAND
	if is_air(solids, size, cell + Vector2i.DOWN):
		m |= UNDER_BAND
	return m


func _draw() -> void:
	for y in _size.y:
		for x in _size.x:
			var cell := Vector2i(x, y)
			if _haunches.has(cell):
				_diagonal_band(Vector2(cell * TILE), _haunches[cell])
				continue
			if _slopes.has(cell):
				continue
			var m := bands_for(_solids, _size, cell)
			if m == 0:
				continue
			var o := Vector2(cell * TILE)
			if m & TOP_BAND:
				_band(o, Vector2.DOWN, TOP_REACH, TOP_ALPHA)
			if m & LEFT_BAND:
				_band(o, Vector2.RIGHT, SIDE_REACH, SIDE_ALPHA)
			if m & RIGHT_BAND:
				_band(o + Vector2(TILE, 0), Vector2.LEFT, SIDE_REACH, SIDE_ALPHA)
			if m & UNDER_BAND:
				_band(o + Vector2(0, TILE), Vector2.UP, UNDER_REACH, UNDER_ALPHA)


## Draws one rim gradient hugging the cell edge at `at` and fading `reach` pixels
## inward along `dir` (a unit axis), from `alpha` at the boundary to zero.
func _band(at: Vector2, dir: Vector2, reach: float, alpha: float) -> void:
	var step := reach / STEPS
	# The rim runs the full tile across the edge; `dir` is the fade direction.
	var across := Vector2(absf(dir.y), absf(dir.x)) * TILE
	var along := dir * (step + 0.5)
	for i in STEPS:
		var a := alpha * (1.0 - float(i) / STEPS)
		var corner := at + dir * (step * i)
		var r := Rect2(corner, across + along).abs()
		draw_rect(r, Color(COLOR, a))


## The underside rim of a haunch (bible 12.78): bands parallel to its diagonal,
## darkest at the diagonal and fading into the solid half, as an underside's
## rim does. `west` is the haunch solid in its top-left half.
func _diagonal_band(o: Vector2, west: bool) -> void:
	var step := UNDER_REACH / STEPS
	for i in STEPS:
		var a := UNDER_ALPHA * (1.0 - float(i) / STEPS)
		var k := step * i
		var pts: PackedVector2Array
		if west:
			# The diagonal runs x + y = TILE; inward is up and to the left.
			pts = [o + Vector2(0, TILE - k), o + Vector2(TILE - k, 0), o + Vector2(TILE - k - step, 0), o + Vector2(0, TILE - k - step)]
		else:
			# The diagonal runs y = x; inward is up and to the right.
			pts = [o + Vector2(k, 0), o + Vector2(TILE, TILE - k), o + Vector2(TILE, TILE - k - step), o + Vector2(k + step, 0)]
		draw_colored_polygon(pts, Color(COLOR, a))
