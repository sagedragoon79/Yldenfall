class_name AirShade
extends Node2D
## The play plane stands off the backdrop (design bible 12.129, pass 653). The
## pass 650 grade saw "no value split between the play plane and the backdrop"
## in the Evercrown's veins, the Tower's foot and the Spires: the parallax
## layers behind a room sat at the value of its walls and decks, so a ledge's
## edge was told from the air behind it only by its lit top. Now the air next to
## every solid edge, plank board and hung deck darkens toward it, a short
## falloff on the backdrop's side of the edge, so each solid mass stands on a
## shadow of its own and the backdrop recedes behind it:
##
## - the darkness is deepest where the air meets the solid (`MAX_ALPHA`) and
##   falls off with the key light from the top left (12.3): furthest below an
##   underside (`DOWN_REACH`), less beside a wall (`SIDE_REACH`), and only a
##   thin line over a walking surface (`UP_REACH`), whose lit top stays the
##   brightest thing at the edge;
## - it is quantised to `LEVELS` clean steps in `GRAIN`-pixel blocks, with no
##   dither: against the Boughs' pale day air a checker dither read as grime;
## - slopes cast none (a dark band would float over their low side), and the
##   room's outside casts none (its frame stays as it was);
## - a haunch (12.78) casts from its diagonal, so the falloff runs along the
##   slope the tile draws (12.136, pass 660). Left out, the square cells behind a
##   vault's slope cast square steps across its open half, and against the
##   Boughs' soft day air every vault wore a staircase of grey boxes.
##
## It draws on the backdrop's side: behind the tiles, the set pieces, the light
## shafts and every actor (`z_index` -3), once per room load, as one texture, so
## it costs nothing per frame.

const TILE := 16
## World px from the edge where the darkness ends: under a mass, beside it and
## over it.
const DOWN_REACH := 16.0
const SIDE_REACH := 10.0
const UP_REACH := 4.0
## Opacity where the air meets the solid.
const MAX_ALPHA := 0.6
## Quantised steps of darkness.
const LEVELS := 8
## Dither block size, world px.
const GRAIN := 2
## Near-black with the same faint cool bias as `EdgeShade` and `DeepShade`.
const COLOR := Color(0.0, 0.0, 0.02)
## How deep a plank's board reads from the top of its cell, world px: the board
## and the dark trestle under it (PlankSupports.BOARD_UNDER).
const BOARD_DEPTH := 5.0

## What a cell is to the shade.
const AIR := 0
const SOLID := 1
const BOARD := 2
## A haunch solid in its top-left half (`` ` ``) and one solid in its top-right
## half (`'`), bible 12.78.
const HAUNCH_WEST := 3
const HAUNCH_EAST := 4
## How many kinds a cell can be, the base of a neighbourhood's key.
const KINDS := 5

var _size := Vector2i.ZERO
var _image: Image
var _texture: ImageTexture
## Cells the shade painted, for tests.
var _painted := 0


func _ready() -> void:
	z_index = -3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Builds the shade for a room of `size` tiles: `solids` cast it (slopes left
## out by the caller), `boards` are plank cells whose board casts it, and `decks`
## are plank cells that hang as a full-depth deck and cast it like a solid.
## `haunches` (cell -> true for a west one) cast from their diagonal.
func setup(solids: Dictionary, boards: Dictionary, decks: Dictionary, size: Vector2i, haunches := {}) -> void:
	_size = size
	var out := paint(solids, boards, decks, size, haunches)
	_image = out.image
	_painted = out.cells
	_texture = ImageTexture.create_from_image(_image) if _image != null else null
	queue_redraw()


## The rect a neighbour of `kind` at offset `off` (in cells) covers, in the
## local px of the cell being shaded, or an empty rect.
static func source_rect(kind: int, off: Vector2i) -> Rect2:
	var o := Vector2(off * TILE)
	if kind == SOLID:
		return Rect2(o, Vector2(TILE, TILE))
	if kind == BOARD:
		return Rect2(o, Vector2(TILE, BOARD_DEPTH))
	return Rect2()


## The corners of a haunch of `kind` at offset `off` (in cells), in the local
## px of the cell being shaded: the half above its diagonal (Room.is_solid_at).
static func haunch_corners(kind: int, off: Vector2i) -> PackedVector2Array:
	var o := Vector2(off * TILE)
	var t := float(TILE)
	if kind == HAUNCH_WEST:
		return PackedVector2Array([o, o + Vector2(t, 0.0), o + Vector2(0.0, t)])
	return PackedVector2Array([o, o + Vector2(t, 0.0), o + Vector2(t, t)])


## True if `p` lies in the solid half of the haunch with `corners`.
static func in_haunch(kind: int, corners: PackedVector2Array, p: Vector2) -> bool:
	var l := p - corners[0]
	if l.x < 0.0 or l.y < 0.0 or l.x > TILE or l.y > TILE:
		return false
	return l.y <= TILE - l.x if kind == HAUNCH_WEST else l.y <= l.x


## How far `p` lies from a haunch in reaches, as `reach_distance` for a rect:
## the offset to its nearest point, each axis against its own reach.
static func haunch_distance(kind: int, corners: PackedVector2Array, p: Vector2) -> float:
	if in_haunch(kind, corners, p):
		return 0.0
	var best := Vector2.INF
	for i in 3:
		var q := Geometry2D.get_closest_point_to_segment(p, corners[i], corners[(i + 1) % 3])
		if (p - q).length_squared() < best.length_squared():
			best = p - q
	return scaled_offset(best)


## An offset from a source's nearest point, in reaches: `SIDE_REACH` across,
## `DOWN_REACH` below it and `UP_REACH` above it.
static func scaled_offset(d: Vector2) -> float:
	var dy := d.y / DOWN_REACH if d.y > 0.0 else -d.y / UP_REACH
	return Vector2(d.x / SIDE_REACH, dy).length()


## How far local point `p` lies from `r` in reaches: 0 at its edge (and
## inside), 1 where the darkness ends. Each axis is measured against its own
## reach: `DOWN_REACH` below the rect, `UP_REACH` above it, `SIDE_REACH` beside.
static func reach_distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var below := p.y - r.end.y
	var above := r.position.y - p.y
	var dy := 0.0
	if below > 0.0:
		dy = below / DOWN_REACH
	elif above > 0.0:
		dy = above / UP_REACH
	return Vector2(dx / SIDE_REACH, dy).length()


## How dark the air is `n` reaches from the nearest edge, 0..1.
static func darkness_for(n: float) -> float:
	return clampf(1.0 - n, 0.0, 1.0)


## The quantised step 0..LEVELS of darkness `v`.
static func level_at(v: float) -> int:
	if v <= 0.0:
		return 0
	return clampi(ceili(v * LEVELS), 0, LEVELS)


## The opacity of step `level`.
static func alpha_for(level: int) -> float:
	return MAX_ALPHA * float(level) / LEVELS


## The 8 x 8 block pattern for a cell of kind `self_kind` with the neighbour
## kinds `around` (3 x 3, row major, the centre ignored). Each cell repeats the
## same steps, so a pattern is the same wherever its key comes up.
static func pattern(self_kind: int, around: PackedInt32Array) -> Image:
	var per := TILE / GRAIN
	var img := Image.create(per, per, false, Image.FORMAT_RGBA8)
	var own := source_rect(BOARD, Vector2i.ZERO) if self_kind == BOARD else Rect2()
	var own_haunch := haunch_corners(self_kind, Vector2i.ZERO) if self_kind >= HAUNCH_WEST else PackedVector2Array()
	var sources: Array[Rect2] = []
	var haunches: Array[PackedVector2Array] = []
	var haunch_kinds: Array[int] = []
	for i in 9:
		var off := Vector2i(i % 3 - 1, i / 3 - 1)
		if i == 4:
			continue
		if around[i] >= HAUNCH_WEST:
			haunches.append(haunch_corners(around[i], off))
			haunch_kinds.append(around[i])
			continue
		var r := source_rect(around[i], off)
		if r.has_area():
			sources.append(r)
	if own.has_area():
		sources.append(own)
	if not own_haunch.is_empty():
		haunches.append(own_haunch)
		haunch_kinds.append(self_kind)
	for by in per:
		for bx in per:
			var p := (Vector2(bx, by) + Vector2(0.5, 0.5)) * GRAIN
			if own.has_area() and own.has_point(p):
				continue
			var d := INF
			for r in sources:
				d = minf(d, reach_distance(p, r))
			for h in haunches.size():
				d = minf(d, haunch_distance(haunch_kinds[h], haunches[h], p))
			var lvl := level_at(darkness_for(d))
			if lvl > 0:
				img.set_pixel(bx, by, Color(COLOR, alpha_for(lvl)))
	return img


## The whole room's shade as one image, `GRAIN` px to a pixel (`image`, null for
## an empty room), and how many cells it painted (`cells`).
static func paint(solids: Dictionary, boards: Dictionary, decks: Dictionary, size: Vector2i, haunches := {}) -> Dictionary:
	if size.x <= 0 or size.y <= 0:
		return {"image": null, "cells": 0}
	var count := 0
	var per := TILE / GRAIN
	var img := Image.create(size.x * per, size.y * per, false, Image.FORMAT_RGBA8)
	# The kinds as a grid with a border of air, so each cell reads its neighbours
	# by index (a room holds tens of thousands of cells; dictionary lookups round
	# every one cost the load budget, bible 14).
	var w := size.x + 2
	var grid := PackedByteArray()
	grid.resize(w * (size.y + 2))
	for c: Vector2i in boards:
		if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y:
			grid[(c.y + 1) * w + c.x + 1] = BOARD
	for src: Dictionary in [solids, decks]:
		for c: Vector2i in src:
			if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y:
				grid[(c.y + 1) * w + c.x + 1] = SOLID
	for c: Vector2i in haunches:
		if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y:
			grid[(c.y + 1) * w + c.x + 1] = HAUNCH_WEST if haunches[c] else HAUNCH_EAST
	var cache := {}
	var whole := Rect2i(0, 0, per, per)
	for y in size.y:
		var row := (y + 1) * w + 1
		for x in size.x:
			var at := row + x
			var own := grid[at]
			if own == SOLID:
				continue
			var key := own
			for i in 9:
				key = key * KINDS + grid[at + (i / 3 - 1) * w + (i % 3 - 1)]
			if key == 0:
				continue
			var pat: Image = cache.get(key)
			if pat == null:
				var around := PackedInt32Array()
				around.resize(9)
				for i in 9:
					around[i] = grid[at + (i / 3 - 1) * w + (i % 3 - 1)]
				pat = pattern(own, around)
				cache[key] = pat
			img.blit_rect(pat, whole, Vector2i(x, y) * per)
			count += 1
	return {"image": img, "cells": count}


## The opacity drawn at world pixel `px` (for tests).
func alpha_at(px: Vector2) -> float:
	if _image == null:
		return 0.0
	var p := Vector2i(floori(px.x / GRAIN), floori(px.y / GRAIN))
	if p.x < 0 or p.y < 0 or p.x >= _image.get_width() or p.y >= _image.get_height():
		return 0.0
	return _image.get_pixelv(p).a


## How many cells the shade painted.
func painted() -> int:
	return _painted


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_size * TILE)), false)
