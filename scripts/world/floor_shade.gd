class_name FloorShade
extends Node2D
## A floor sinks into the ground under it (design bible 12.157, pass 680).
##
## The pass 675 grade named "uniform floor strips" in the Tower foot, the veins
## and the Source Hall: a room's floor is two to four tiles of ground between
## the walking line and the frame, so `DeepShade` (which starts 2.5 tiles from
## open air) never reaches it, and the strip stood at the walking tile's full
## value down to the frame, one tile repeated edge to edge.
##
## Now the ground under a floor falls into shadow below its walking tile:
##
## - only the foot of a column: the run of solid cells from the room's bottom
##   row up to the first open cell, at least `MIN_RUN` tiles deep, with open air
##   above it (a wall that runs from the room's top to its bottom is not a
##   floor) and no secret in it;
## - the walking tile stays lit (`FROM`), then the shade deepens on a
##   smoothstep to `MAX_ALPHA` over `SPAN` tiles, drawn with colours at the
##   corners of a few bands, so it grades smoothly (no dither, no steps);
## - at each column edge the depth is measured from the lower of the two
##   floors' tops, so the shade is continuous across a bank or a slope and never
##   reaches into a walking tile.
##
## It draws over the tiles, `EdgeShade` and `DeepShade`, under the actors, once
## per room load and again when a guardian tears the floor.

const TILE := 16
## Near-black with the same faint cool bias as `DeepShade`.
const COLOR := Color(0.0, 0.0, 0.02)
## Tiles under a floor's top that stay lit: the walking tile's upper half, its lip.
const FROM := 0.5
## Tiles from FROM to the full shade.
const SPAN := 2.0
## The shade's opacity at full: the ground still shows through.
const MAX_ALPHA := 0.7
## The fewest tiles of ground a floor needs to be shaded.
const MIN_RUN := 2
## Bands the falloff is drawn in, colours graded between them.
const BANDS := 4

## Per column, the row of the floor's top, or -1 where the column has no floor.
var tops := PackedInt32Array()
var _size := Vector2i.ZERO


## Reads the room's solid cells over the `size` tile grid; columns holding a
## cell in `skip` (a secret) are not shaded.
func setup(solids: Dictionary, size: Vector2i, skip := {}) -> void:
	_size = size
	tops = floor_tops(solids, size, skip)
	queue_redraw()


## The row of each column's floor top: the top of the run of solid cells from
## the bottom row up, or -1 where the bottom cell is open, the run is under
## `MIN_RUN` tiles, it reaches the room's top, or it holds a cell in `skip`.
static func floor_tops(solids: Dictionary, size: Vector2i, skip := {}) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(size.x)
	for x in size.x:
		out[x] = -1
		var y := size.y - 1
		var hidden := false
		while y >= 0 and solids.has(Vector2i(x, y)):
			if skip.has(Vector2i(x, y)):
				hidden = true
			y -= 1
		var top := y + 1
		if hidden or y < 0 or size.y - top < MIN_RUN:
			continue
		out[x] = top
	return out


## The shade's opacity `depth` tiles under a floor's top.
static func alpha_at_depth(depth: float) -> float:
	var t := clampf((depth - FROM) / SPAN, 0.0, 1.0)
	return MAX_ALPHA * t * t * (3.0 - 2.0 * t)


## The floor top measured at the west edge of column `x` (in rows): the lower
## of this column's and its west neighbour's, so the shade meets itself there.
func _edge_top(x: int, edge: int) -> float:
	var own := tops[x]
	var n := x + edge
	if n < 0 or n >= _size.x or tops[n] < 0:
		return float(own)
	return float(maxi(own, tops[n]))


## The opacity drawn at world pixel `px` (for tests): 0 where nothing is drawn.
func alpha_at_pixel(px: Vector2) -> float:
	var x := floori(px.x / TILE)
	if x < 0 or x >= _size.x or tops.is_empty() or tops[x] < 0:
		return 0.0
	if px.y >= _size.y * TILE:
		return 0.0
	var u := px.x / TILE - x
	var top := lerpf(_edge_top(x, -1), _edge_top(x, 1), u)
	return alpha_at_depth(px.y / TILE - top)


func _draw() -> void:
	var bottom := float(_size.y * TILE)
	for x in _size.x:
		if tops[x] < 0:
			continue
		var l := _edge_top(x, -1)
		var r := _edge_top(x, 1)
		var x0 := float(x * TILE)
		var x1 := x0 + TILE
		for k in BANDS + 1:
			var d0 := FROM + SPAN * k / BANDS
			var d1 := FROM + SPAN * (k + 1) / BANDS
			var a0 := alpha_at_depth(d0)
			var a1 := alpha_at_depth(d1)
			var yl0 := minf((l + d0) * TILE, bottom)
			var yr0 := minf((r + d0) * TILE, bottom)
			var yl1 := minf((l + d1) * TILE, bottom)
			var yr1 := minf((r + d1) * TILE, bottom)
			if k == BANDS:
				# The last band runs to the room's bottom at the full shade.
				yl1 = bottom
				yr1 = bottom
				a1 = a0
			if yl0 >= bottom and yr0 >= bottom:
				break
			var c0 := Color(COLOR, a0)
			var c1 := Color(COLOR, a1)
			# A side clamped to the bottom closes to a point: drop its doubled corner.
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for v: Array in [[Vector2(x0, yl0), c0], [Vector2(x1, yr0), c0], [Vector2(x1, yr1), c1], [Vector2(x0, yl1), c1]]:
				if pts.is_empty() or (v[0] as Vector2).distance_to(pts[pts.size() - 1]) > 0.01:
					pts.append(v[0])
					cols.append(v[1])
			if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.01:
				pts.remove_at(pts.size() - 1)
				cols.remove_at(cols.size() - 1)
			if pts.size() >= 3:
				draw_polygon(pts, cols)
