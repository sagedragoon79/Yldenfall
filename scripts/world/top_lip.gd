class_name TopLip
extends Node2D
## The top of the ground is not a ruled line (design bible 12.103, pass 627).
## Every walking surface ended in the tileset's moss cap (12.7): varied in tone,
## but dead level, so a floor's silhouette was a ruler laid on the room and a
## ledge ended in a square corner. The cap now grows past its tile:
##
## - **Hummocks.** Moss mounds stand on the top line, in the open cell above:
##   low ones often, a tall one now and then, each a dome with ragged blades.
##   A stretch between two mounds stays level, so the top rises and falls.
## - **Drapes.** Where a surface ends at open air, the moss hangs down the wall
##   face in strands of uneven length and stands a texel or two proud of it, so
##   a ledge's corner is a lip and not a right angle.
##
## Drawn in three tones of the zone's own cap ramp, at the tiles'
## texel size. Only the moss-capped zones take it. Built once per room load into
## one mesh, over the tiles and under the room's light and every actor, so it
## costs nothing a frame and never covers a foot.

const TILE := 16
## Texels to a world pixel, and to a cell: the tiles' density.
const DENSITY := TilesetFactory.DENSITY
const CELL := TILE * DENSITY
## The zones whose tileset carries the moss cap, with the cap's ramp and its
## brightest step (`cap: moss`, `light` and `cap_top` in tools/art/tilegen.py).
const CAPS := {
	"gym": ["leaf", 5], "heartwood": ["leaf", 4], "haar": ["leaf", 3], "boughs": ["leaf", 6],
	"vorrhallow": ["sky", 4], "evercrown": ["crystal", 4], "sunken": ["sky", 3], "spires": ["leaf", 5],
}
## The master palette's ramps a cap is drawn in, dark to light.
const RAMPS := {
	"leaf": ["0d1c12", "1e4825", "2b782c", "49aa36", "74cd51", "a1d684", "c8e3b5"],
	"sky": ["0d131c", "1e3148", "2b5278", "3677aa", "51a5cd", "84cbd6", "b5e3e1"],
	"crystal": ["190d1c", "421e48", "712b78", "a736aa", "cd51c5", "d684c6", "e3b5d4"],
}

## A hummock may start in each slot of this many texels along a row.
const SLOT := 16
## The share of slots that grow one.
const GROWN := 0.6
## The tallest hummock, texels above the top line.
const MAX_PEAK := 7
## How far in from a ledge's end the drape hangs, texels.
const DRAPE_WIDTH := 5
## How far outside the wall face it stands.
const DRAPE_PROUD := 2
## Where the drape starts under the top line (inside the cap), and its longest strand.
const DRAPE_FROM := 4
const DRAPE_MAX := 16

const LIGHT := 0
const MID := 1
const DARK := 2

var _surface := {}
var _solids := {}
var _size := Vector2i.ZERO
var _slopes := {}
var _colors: Array[Color] = []
var _mesh: ArrayMesh
var _quads := 0


static func has_lip(zone: String) -> bool:
	return CAPS.has(zone)


static func _hash(a: int, b: int, c: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0


## The walking surfaces: ground (not a slope) with plain open air above it.
## Cells in `skip` (a secret's cover, ground under water) take no lip.
static func surface_cells(solids: Dictionary, size: Vector2i, slopes := {}, skip := {}) -> Dictionary:
	var out := {}
	for cell: Vector2i in solids:
		if slopes.has(cell) or skip.has(cell) or cell.y <= 0 or cell.x < 0 or cell.x >= size.x or cell.y >= size.y:
			continue
		var above := cell + Vector2i.UP
		if solids.has(above) or skip.has(above):
			continue
		out[cell] = true
	return out


## The hummock's height, in texels above the top line, at texel column `tx`
## (counted along the whole room) of surface row `row`. 0 between hummocks.
static func hummock_height(tx: int, row: int) -> int:
	var best := 0
	# A hummock can be wider than its slot: ask this slot and the one before.
	for s: int in [tx / SLOT - 1, tx / SLOT]:
		if s < 0 or _hash(s, row, 11) > GROWN:
			continue
		var size := _hash(s, row, 12)
		var peak := 2 + int(_hash(s, row, 13) * 2.0)
		if size > 0.85:
			peak = 6 + int(_hash(s, row, 13) * 2.0)
		elif size > 0.5:
			peak = 4 + int(_hash(s, row, 13) * 2.0)
		var width := 5 + int(peak * 1.5) + int(_hash(s, row, 14) * 5.0)
		var start := s * SLOT + int(_hash(s, row, 15) * (SLOT - 4))
		var i := tx - start
		if i < 0 or i >= width:
			continue
		var h := roundi(peak * sin(PI * (i + 0.5) / width))
		# A ragged blade: the odd column stands or sits a texel off the dome.
		var j := _hash(tx, row, 16)
		if j > 0.8:
			h += 1
		elif j < 0.25:
			h -= 1
		best = maxi(best, clampi(h, 0, MAX_PEAK))
	return best


## How far the drape's strand hangs under `DRAPE_FROM`, in texels, `inward`
## texels in from the end of a ledge (negative: outside the wall face).
## `cell` is the end cell, `east` the side its end is on.
static func drape_length(cell: Vector2i, east: bool, inward: int) -> int:
	if inward < -DRAPE_PROUD or inward >= DRAPE_WIDTH:
		return 0
	var side := 21 if east else 22
	var base := 6 + int(_hash(cell.x, cell.y, side) * (DRAPE_MAX - 6))
	var jit := int(_hash(cell.x * 7 + inward, cell.y, side + 2) * 4.0)
	if inward < 0:
		# Proud of the wall: short tips that hang free.
		return maxi(1, base / 3 - (-inward - 1) * 2 - jit / 2)
	return maxi(0, base - inward * 2 - jit)


## True if the surface cell ends at open air on that side: nothing solid beside
## it or diagonally above, inside the room.
static func ends_at(solids: Dictionary, size: Vector2i, cell: Vector2i, east: bool) -> bool:
	var side := cell + (Vector2i.RIGHT if east else Vector2i.LEFT)
	if side.x < 0 or side.x >= size.x:
		return false
	return not solids.has(side) and not solids.has(side + Vector2i.UP)


## The cap's light, mid and dark tones: the three steps of the zone's cap ramp
## under its brightest (the tips the tileset keeps for its own lit blades).
## Empty for a zone with no moss cap.
static func tones(zone: String) -> Array[Color]:
	var out: Array[Color] = []
	if not CAPS.has(zone):
		return out
	var ramp: Array = RAMPS[CAPS[zone][0]]
	var top: int = CAPS[zone][1]
	for k in [1, 2, 3]:
		out.append(Color.html(ramp[maxi(0, top - k)]))
	return out


## The tone of the hummock texel `up` texels above the top line (1 is the
## lowest) in a column `h` tall. The key light is up and to the left (12.3):
## a tip that faces it is lit, the flank that falls away east is in shade, and
## a tall mound is dark at its root.
static func hummock_tone(tx: int, row: int, up: int, h: int) -> int:
	var lee := hummock_height(tx + 1, row) < h
	if up == h:
		return LIGHT if h >= 2 and not lee and _hash(tx, row, 17) > 0.3 else MID
	if up == 1 and h >= 4:
		return DARK
	return DARK if lee and up < h else MID


func setup(zone: String, solids: Dictionary, size: Vector2i, slopes := {}, skip := {}) -> void:
	_solids = solids
	_size = size
	_slopes = slopes
	_surface = {}
	_mesh = null
	_quads = 0
	_colors = tones(zone)
	if _colors.size() == 3:
		_surface = surface_cells(solids, size, slopes, skip)
		_build()
	queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _build() -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var px := 1.0 / DENSITY
	for cell: Vector2i in _surface:
		var top := cell.y * CELL
		for i in CELL:
			var tx := cell.x * CELL + i
			var h := hummock_height(tx, cell.y)
			# One quad per run of a tone, from the top of the column down.
			var up := h
			while up >= 1:
				var tone := hummock_tone(tx, cell.y, up, h)
				var low := up
				while low > 1 and hummock_tone(tx, cell.y, low - 1, h) == tone:
					low -= 1
				_quad(verts, cols, Rect2(tx, top - up, 1, up - low + 1), _colors[tone], px)
				up = low - 1
		for east: bool in [false, true]:
			if not ends_at(_solids, _size, cell, east):
				continue
			for inward in range(-DRAPE_PROUD, DRAPE_WIDTH):
				var n := drape_length(cell, east, inward)
				if n <= 0:
					continue
				var tx := cell.x * CELL + (CELL - 1 - inward if east else inward)
				var from := top + (1 if inward < 0 else DRAPE_FROM)
				if n > 1:
					_quad(verts, cols, Rect2(tx, from, 1, n - 1), _colors[MID], px)
				_quad(verts, cols, Rect2(tx, from + n - 1, 1, 1), _colors[DARK], px)
	_quads = verts.size() / 6
	if _quads == 0:
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


static func _quad(verts: PackedVector2Array, cols: PackedColorArray, r: Rect2, color: Color, px: float) -> void:
	var a := r.position * px
	var b := r.end * px
	verts.append_array([a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)])
	for k in 6:
		cols.append(color)


## True if `cell` takes a lip.
func is_surface(cell: Vector2i) -> bool:
	return _surface.has(cell)


## The height of the lip above the top line at world x `x` of surface row `row`,
## in texels (0 off a surface).
func height_at(x: float, row: int) -> int:
	var tx := int(floor(x * DENSITY))
	if not _surface.has(Vector2i(tx / CELL, row)):
		return 0
	return hummock_height(tx, row)


## How far the drape hangs at the `east` end of `cell`, `inward` texels in (0
## where the cell has no such end).
func drape_at(cell: Vector2i, east: bool, inward: int) -> int:
	if not _surface.has(cell) or not ends_at(_solids, _size, cell, east):
		return 0
	return drape_length(cell, east, inward)


func quad_count() -> int:
	return _quads


func _draw() -> void:
	if _mesh != null:
		draw_mesh(_mesh, null)
