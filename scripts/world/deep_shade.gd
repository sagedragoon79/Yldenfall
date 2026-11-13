class_name DeepShade
extends Node2D
## Solid mass falls off into darkness away from the walkable edge (design bible
## 12.38, pass 547). The tilesets have three depths of ground tile (the lit edge,
## one step in, and the interior), so every cell three or more tiles from open
## air drew the same interior tile: a big off-room mass read as one flat cobble
## field with its studs repeating to the frame. Now the interior sinks into
## shadow the deeper it lies, so the lit rock hugs the rooms and the rest of the
## mass reads as depth:
##
## - each solid cell's distance to the nearest open cell (8-way, in tiles) gives
##   a darkness, nothing within `START` tiles, near-black by `START + SPAN`;
## - the field is blended between cell centres, then quantised to `LEVELS`
##   steps with a 4 x 4 ordered dither in `GRAIN`-pixel blocks, so the falloff is
##   pixelled steps, never a smooth gradient or a hard ring;
## - the room's outer boundary counts as solid, so the mass past the frame sinks
##   too.
##
## It draws over the tiles and `EdgeShade`, under the actors, once per room load
## (and again when a guardian tears the floor), with no per-frame cost. Secret
## cells are left out of the main shade and drawn by a second shade parented to
## the secret layer, so it fades with the fake wall and a hidden room is never
## left dark once found.

const TILE := 16
## Near-black with the same faint cool bias as `EdgeShade`.
const COLOR := Color(0.0, 0.0, 0.02)
## Distance in tiles where the falloff begins: the tilesets' own interior tile
## starts at 3, so the lit edge and the step in are never touched.
const START := 2.5
## Tiles from START to full darkness.
const SPAN := 4.0
## Opacity at full darkness: a trace of the rock still shows at the very back.
const MAX_ALPHA := 0.86
## Quantised steps of darkness.
const LEVELS := 5
## Dither block size, world px.
const GRAIN := 2

const _BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

var _solids: Dictionary
var _size: Vector2i
var _only: Dictionary
var _skip: Dictionary
var _field: PackedFloat32Array
## The rects to fill, built once per setup: [Rect2, alpha] pairs.
var _rects: Array = []


## Reads the room's solid cells (`solids`) over the `size` tile grid. When
## `only` is not empty, only those cells are shaded; cells in `skip` never are.
func setup(solids: Dictionary, size: Vector2i, only := {}, skip := {}) -> void:
	_solids = solids
	_size = size
	_only = only
	_skip = skip
	rebuild()


## Recomputes the field and the rects (after the solid cells change).
func rebuild() -> void:
	_field = darkness_field(_solids, _size)
	_rects = build_rects(_field, _size, _only, _skip)
	queue_redraw()


## The distance in tiles from each cell to the nearest open cell, 8-way, row
## major. Open cells are 0; the room's outside counts as solid and is never a
## source, so a room with no open cell is all `INF`.
static func distance_field(solids: Dictionary, size: Vector2i) -> PackedInt32Array:
	var n := size.x * size.y
	var dist := PackedInt32Array()
	dist.resize(n)
	var queue: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if solids.has(c):
				dist[y * size.x + x] = 1 << 30
			else:
				dist[y * size.x + x] = 0
				queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := dist[c.y * size.x + c.x] + 1
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var m := c + Vector2i(dx, dy)
				if m.x < 0 or m.y < 0 or m.x >= size.x or m.y >= size.y:
					continue
				var i := m.y * size.x + m.x
				if dist[i] > d:
					dist[i] = d
					queue.append(m)
	return dist


## Darkness 0..1 per cell from its distance to open air.
static func darkness_for(distance: int) -> float:
	return clampf((float(distance) - START) / SPAN, 0.0, 1.0)


static func darkness_field(solids: Dictionary, size: Vector2i) -> PackedFloat32Array:
	var dist := distance_field(solids, size)
	var f := PackedFloat32Array()
	f.resize(dist.size())
	for i in dist.size():
		f[i] = darkness_for(dist[i])
	return f


## The field blended between cell centres at `p`, in tiles (a cell's centre is
## at its index + 0.5). Off the grid it holds the edge value.
static func field_at(field: PackedFloat32Array, size: Vector2i, p: Vector2) -> float:
	var q := p - Vector2(0.5, 0.5)
	var x0 := floori(q.x)
	var y0 := floori(q.y)
	var tx := q.x - x0
	var ty := q.y - y0
	var a := _cell(field, size, x0, y0)
	var b := _cell(field, size, x0 + 1, y0)
	var c := _cell(field, size, x0, y0 + 1)
	var d := _cell(field, size, x0 + 1, y0 + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _cell(field: PackedFloat32Array, size: Vector2i, x: int, y: int) -> float:
	return field[clampi(y, 0, size.y - 1) * size.x + clampi(x, 0, size.x - 1)]


## The dither threshold at block `b`, -0.5..0.5.
static func dither(b: Vector2i) -> float:
	return (float(_BAYER[posmod(b.y, 4)][posmod(b.x, 4)]) + 0.5) / 16.0 - 0.5


## The quantised step 0..LEVELS of darkness `v` at block `b`.
static func level_at(v: float, b: Vector2i) -> int:
	if v <= 0.0:
		return 0
	return clampi(roundi(v * LEVELS + dither(b)), 0, LEVELS)


## The opacity of step `level`.
static func alpha_for(level: int) -> float:
	return MAX_ALPHA * float(level) / LEVELS


## The rects that paint the shade: whole cells where the step is the same over
## the cell, otherwise runs of `GRAIN`-pixel blocks along each row.
static func build_rects(field: PackedFloat32Array, size: Vector2i, only := {}, skip := {}) -> Array:
	var out: Array = []
	var per := TILE / GRAIN
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if skip.has(cell) or (not only.is_empty() and not only.has(cell)):
				continue
			var lo := INF
			var hi := -INF
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var v := field_at(field, size, Vector2(cell) + corner)
				lo = minf(lo, v)
				hi = maxf(hi, v)
			if hi <= 0.0:
				continue
			var origin := Vector2(cell * TILE)
			if lo >= 1.0:
				out.append([Rect2(origin, Vector2(TILE, TILE)), alpha_for(LEVELS)])
				continue
			for by in per:
				var run_start := 0
				var run_level := -1
				for bx in per + 1:
					var lvl := -1
					if bx < per:
						var blk := cell * per + Vector2i(bx, by)
						var p := (Vector2(blk) + Vector2(0.5, 0.5)) * GRAIN / TILE
						lvl = level_at(field_at(field, size, p), blk)
					if lvl != run_level:
						if run_level > 0:
							out.append([Rect2(origin + Vector2(run_start * GRAIN, by * GRAIN),
									Vector2((bx - run_start) * GRAIN, GRAIN)), alpha_for(run_level)])
						run_start = bx
						run_level = lvl
	return out


## The step drawn at world pixel `px` (for tests): 0 where nothing is drawn.
func level_at_pixel(px: Vector2) -> int:
	for r: Array in _rects:
		if (r[0] as Rect2).has_point(px):
			return roundi(float(r[1]) / MAX_ALPHA * LEVELS)
	return 0


func rect_count() -> int:
	return _rects.size()


func _draw() -> void:
	for r: Array in _rects:
		draw_rect(r[0], Color(COLOR, r[1]))
