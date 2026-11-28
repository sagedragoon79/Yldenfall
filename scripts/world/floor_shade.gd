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
##
## It never stacks on the deep shade (pass 681). The pass 680 grade read a
## heavy dark ellipse under the Source Hall's floor: where a floor runs over
## deep mass, `DeepShade` already darkens the ground, and this shade laid its
## own 0.7 over it (0.96 together). Now it only adds the darkness the deep shade
## has not already given, so the two together are as dark as the darker of them
## and no more: `1 - (1 - floor) (1 - deep) = max(floor shade, deep shade)`.

const TILE := 16
## Near-black with the same faint cool bias as `DeepShade`.
const COLOR := Color(0.0, 0.0, 0.02)
## Tiles under a floor's top that stay lit: the walking tile's upper half, its lip.
const FROM := 0.5
## Tiles from FROM to the full shade.
const SPAN := 2.0
## The shade's opacity at full: the ground still shows through.
const MAX_ALPHA := 0.7
## Columns are drawn in this many strips, so the easing follows the deep shade
## (whose field is blended between cell centres: two strips meet its corners).
const STRIPS := 2
## Below the falloff, rows of this many tiles, so the easing follows the deep shade down.
const ROW := 1.0
## The fewest tiles of ground a floor needs to be shaded.
const MIN_RUN := 2
## Bands the falloff is drawn in, colours graded between them.
const BANDS := 4

## Per column, the row of the floor's top, or -1 where the column has no floor.
var tops := PackedInt32Array()
var _size := Vector2i.ZERO
## The deep shade's field over the same grid (`DeepShade.field()`), or empty.
var _deep := PackedFloat32Array()


## Reads the room's solid cells over the `size` tile grid; columns holding a
## cell in `skip` (a secret) are not shaded. `deep` is the deep shade's field
## (`DeepShade.field()`), which this shade eases off; empty for none.
func setup(solids: Dictionary, size: Vector2i, skip := {}, deep := PackedFloat32Array()) -> void:
	_size = size
	tops = floor_tops(solids, size, skip)
	_deep = deep if deep.size() == size.x * size.y else PackedFloat32Array()
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


## The opacity this shade adds over a deep shade of opacity `deep` so the two
## together reach `want` and never more: none where the deep is already as dark.
static func eased(want: float, deep: float) -> float:
	if deep >= want:
		return 0.0
	return (want - deep) / (1.0 - deep)


## The deep shade's opacity at world pixel `px`, its field unquantised.
func deep_alpha_at_pixel(px: Vector2) -> float:
	if _deep.is_empty():
		return 0.0
	# `DeepShade.field_at` inlined: this runs for every corner the shade draws.
	var qx := px.x / TILE - 0.5
	var qy := px.y / TILE - 0.5
	var x0 := floori(qx)
	var y0 := floori(qy)
	var tx := qx - x0
	var ty := qy - y0
	var w := _size.x
	var xa := clampi(x0, 0, w - 1)
	var xb := clampi(x0 + 1, 0, w - 1)
	var ra := clampi(y0, 0, _size.y - 1) * w
	var rb := clampi(y0 + 1, 0, _size.y - 1) * w
	var top := _deep[ra + xa] + (_deep[ra + xb] - _deep[ra + xa]) * tx
	var low := _deep[rb + xa] + (_deep[rb + xb] - _deep[rb + xa]) * tx
	return DeepShade.MAX_ALPHA * (top + (low - top) * ty)


## The floor top measured at the west edge of column `x` (in rows): the lower
## of this column's and its west neighbour's, so the shade meets itself there.
func _edge_top(x: int, edge: int) -> float:
	var own := tops[x]
	var n := x + edge
	if n < 0 or n >= _size.x or tops[n] < 0:
		return float(own)
	return float(maxi(own, tops[n]))


## The darkness this floor wants at world pixel `px`, before easing: 0 off a floor.
func want_at_pixel(px: Vector2) -> float:
	var x := floori(px.x / TILE)
	if x < 0 or x >= _size.x or tops.is_empty() or tops[x] < 0:
		return 0.0
	if px.y >= _size.y * TILE:
		return 0.0
	var u := px.x / TILE - x
	var top := lerpf(_edge_top(x, -1), _edge_top(x, 1), u)
	return alpha_at_depth(px.y / TILE - top)


## The opacity drawn at world pixel `px` (for tests): 0 where nothing is drawn.
func alpha_at_pixel(px: Vector2) -> float:
	return eased(want_at_pixel(px), deep_alpha_at_pixel(px))


## This shade and the deep shade together at world pixel `px` (for tests).
func combined_alpha_at_pixel(px: Vector2) -> float:
	return 1.0 - (1.0 - alpha_at_pixel(px)) * (1.0 - deep_alpha_at_pixel(px))


func _draw() -> void:
	# One triangle list for the room: per column, STRIPS strips across, and rows
	# at the falloff's bands then every ROW tiles to the bottom, each corner
	# coloured with the eased opacity there, so it grades smoothly. Each row's
	# corners are worked out once and shared with the quads under them; a column
	# stops once a row past the falloff adds nothing and the deep shade holds
	# every cell under it at least as dark (the load budget, bible 14).
	var bottom := float(_size.y * TILE)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var depths := PackedFloat32Array()
	for k in BANDS + 1:
		depths.append(FROM + SPAN * k / BANDS)
	var d := FROM + SPAN
	while d < float(_size.y) + ROW:
		d += ROW
		depths.append(d)
	var covered := _covered_from()
	for x in _size.x:
		if tops[x] < 0:
			continue
		var l := _edge_top(x, -1)
		var r := _edge_top(x, 1)
		var prev_p := PackedVector2Array()
		var prev_a := PackedFloat32Array()
		for k in depths.size():
			var row_p := PackedVector2Array()
			var row_a := PackedFloat32Array()
			var want := alpha_at_depth(depths[k])
			var any := false
			for sx in STRIPS + 1:
				var u := float(sx) / STRIPS
				var p := Vector2((x + u) * TILE, minf((lerpf(l, r, u) + depths[k]) * TILE, bottom))
				var a := eased(want, deep_alpha_at_pixel(p))
				row_p.append(p)
				row_a.append(a)
				any = any or a > 0.002
			if k > 0:
				var lit := any
				for a in prev_a:
					lit = lit or a > 0.002
				if lit:
					for sx in STRIPS:
						var base := pts.size()
						pts.append_array([prev_p[sx], prev_p[sx + 1], row_p[sx + 1], row_p[sx]])
						cols.append_array([Color(COLOR, prev_a[sx]), Color(COLOR, prev_a[sx + 1]),
								Color(COLOR, row_a[sx + 1]), Color(COLOR, row_a[sx])])
						idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			if row_p[0].y >= bottom and row_p[STRIPS].y >= bottom:
				break
			if not any and depths[k] >= FROM + SPAN and covered[x] >= 0 and row_p[0].y >= covered[x] * TILE and row_p[STRIPS].y >= covered[x] * TILE:
				break
			prev_p = row_p
			prev_a = row_a
	if not idx.is_empty() and is_inside_tree():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Per column, the row from which the deep shade holds every cell down to the
## bottom, in this column and its neighbours, at least as dark as the floor
## shade's full; -1 where it never does or there is no deep shade.
func _covered_from() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_size.x)
	out.fill(-1)
	if _deep.is_empty():
		return out
	var need := MAX_ALPHA / DeepShade.MAX_ALPHA - 0.001
	var from := PackedInt32Array()
	from.resize(_size.x)
	for x in _size.x:
		var y := _size.y
		while y > 0 and _deep[(y - 1) * _size.x + x] >= need:
			y -= 1
		from[x] = y
	for x in _size.x:
		var y := from[x]
		if x > 0:
			y = maxi(y, from[x - 1])
		if x < _size.x - 1:
			y = maxi(y, from[x + 1])
		# The field blends between cell centres: a cell further down is safe.
		if y < _size.y - 1:
			out[x] = y + 1
	return out
