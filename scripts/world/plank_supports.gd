class_name PlankSupports
extends Node2D
## What holds each one-way plank up (design bible 12.30). The pass 535
## independent grade read rooms as "empty boxes of unsupported floating planks":
## the plank tile's own trestle (12.20) stays inside its cell, so a run of
## planks in open air still hung on nothing. This layer gives every run of `-`
## planks a support that reaches real structure, planned from the room grid:
##
## - a **knee brace** into a wall the run's end touches;
## - a **post** down to a floor (or a plank) at most `POST_MAX` tiles below;
## - otherwise a pair of **hangers** up to the first solid cell or plank above:
##   rope in the timber and water zones, chain in the stone and iron ones. A
##   hanger with nothing above it within `HANG_MAX` tiles fades out into the
##   dark, as if hung from beyond the view.
##
## Drawn once per room load behind the tiles (z -1, like the ladders), so the
## plank sits over the hanger's foot and actors pass in front. Collision is
## untouched; it is dressing only.

const TILE := 16
## A post reaches down to footing at most this many tiles below the plank.
const POST_MAX := 4
## A hanger reaches up at most this many tiles; past it, it fades into the dark.
const HANG_MAX := 22
## How far a hanger with no anchor above runs before it has faded out, tiles.
const FADE_TILES := 5
## Hangers sit this far in from a run's outer ends, world px.
const INSET := 4.0
## The plank's board is the top 3 world px of its cell (tilegen PLANK, 6 px at density 2).
const BOARD := 3.0
## The board's full depth with its dark underside, world px: a hanger taken from
## a plank above is fixed here, not below that plank's trestle.
const BOARD_UNDER := 5.0

## Per-zone support look. `hang` is rope, chain or sinew (a strand drawn like rope); `lit`, `mid`, `dark` are the
## hanger's three tones; `wood` the post and brace timber (lit, mid, dark), in
## the plank's own strut ramp (tilegen PLANK) so the support reads as the same
## build as the board it carries.
const LOOKS := {
	"gym": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"]},
	"heartwood": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"]},
	"boughs": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"]},
	"hearthroot": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["aa6336", "783c2b", "48201e"]},
	"haar": {"hang": "rope", "lit": "aa9173", "mid": "8a6e56", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"]},
	"sunken": {"hang": "chain", "lit": "aa9173", "mid": "634a41", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"]},
	"spires": {"hang": "rope", "lit": "bea860", "mid": "9c7f44", "dark": "432d23", "wood": ["8a6e56", "634a41", "3c2c2a"]},
	"vorrhallow": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"]},
	"trials": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"]},
	"tower": {"hang": "chain", "lit": "aca1ba", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"]},
	# The Evercrown's shelves are grown, not built (bible 12.34, pass 542): they hang on
	# sinew strands (night-5, night-3, ember-1), not hot crystal chains.
	"evercrown": {"hang": "sinew", "lit": "af92c9", "mid": "5d4997", "dark": "501623", "wood": ["8265b8", "5d4997", "2c2541"]},
}

## The plan, one Dictionary per support: {kind: "brace", "post" or "hang", ...}.
var supports: Array[Dictionary] = []
var _look: Dictionary = LOOKS["gym"]


func _ready() -> void:
	z_index = -1


## Plans the supports for `planks` (cells of `-`) given which cells look solid.
func setup(zone: String, planks: Dictionary, solid: Dictionary, size: Vector2i) -> void:
	_look = LOOKS.get(zone, LOOKS["gym"])
	supports = PlankSupports.plan(planks, solid, size)
	queue_redraw()


## Horizontal runs of plank cells, each [row, first column, last column], in reading order.
static func runs(planks: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cells: Array = planks.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		if planks.has(c + Vector2i.LEFT):
			continue
		var end := c.x
		while planks.has(Vector2i(end + 1, c.y)):
			end += 1
		out.append(Vector3i(c.y, c.x, end))
	return out


static func plan(planks: Dictionary, solid: Dictionary, size: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Vector3i in runs(planks):
		var row := run.x
		var ends := [run.y, run.z]
		var held := [false, false]
		# A knee brace where an end butts against a wall that runs on below it.
		for i in 2:
			var side := -1 if i == 0 else 1
			var wall := Vector2i(ends[i] + side, row)
			if solid.has(wall) and solid.has(wall + Vector2i.DOWN):
				out.append({"kind": "brace", "cell": Vector2i(ends[i], row), "side": side})
				held[i] = true
		if held[0] and held[1]:
			continue
		# Short runs carried at one end need nothing more.
		if (held[0] or held[1]) and run.z - run.y < 3:
			continue
		for i in 2:
			if held[i] or (i == 1 and run.y == run.z):
				continue
			var col: int = ends[i]
			var x := col * TILE + (INSET if i == 0 else TILE - INSET)
			if run.y == run.z:
				x = col * TILE + TILE * 0.5
			var below := PlankSupports._gap(col, row, 1, planks, solid, size)
			if below >= 1 and below <= POST_MAX:
				out.append({"kind": "post", "x": x, "top": row * TILE + BOARD, "bottom": float((row + 1 + below) * TILE)})
				continue
			var above := PlankSupports._gap(col, row, -1, planks, solid, size)
			var anchored := above >= 0 and above <= HANG_MAX
			var top := float((row - above) * TILE) if anchored else float((row - FADE_TILES) * TILE)
			if anchored and planks.has(Vector2i(col, row - above - 1)):
				top = (row - above - 1) * TILE + BOARD_UNDER
			if not anchored:
				top = maxf(top, 0.0)
			out.append({"kind": "hang", "x": x, "top": top, "bottom": row * TILE + BOARD, "anchored": anchored})
	return out


## Empty cells between (col, row) and the first solid cell or plank in direction
## `dir` (1 down, -1 up). -1 if there is none inside the room.
static func _gap(col: int, row: int, dir: int, planks: Dictionary, solid: Dictionary, size: Vector2i) -> int:
	var y := row + dir
	var n := 0
	while y >= 0 and y < size.y:
		var c := Vector2i(col, y)
		if solid.has(c) or planks.has(c):
			return n
		n += 1
		y += dir
	return -1


func _draw() -> void:
	for s: Dictionary in supports:
		match s.kind:
			"brace":
				_draw_brace(s.cell, s.side)
			"post":
				_draw_post(s.x, s.top, s.bottom)
			"hang":
				if _look.hang == "chain":
					_draw_chain(s.x, s.top, s.bottom, s.anchored)
				else:
					_draw_rope(s.x, s.top, s.bottom, s.anchored)


func _c(hex: String, a := 1.0) -> Color:
	var col := Color(hex)
	col.a = a
	return col


## Alpha for a hanger at height y: full near the plank, fading toward `top` when unanchored.
func _fade(y: float, top: float, bottom: float, anchored: bool) -> float:
	if anchored:
		return 1.0
	return clampf((y - top) / maxf(bottom - top, 1.0), 0.0, 1.0)


func _draw_rope(x: float, top: float, bottom: float, anchored: bool) -> void:
	# A 1.5 px strand with a twist: lit and shaded half-pixels alternating every
	# 1.5 px, and a dark core line down its right side.
	var y := top
	var k := 0
	while y < bottom:
		var a := _fade(y, top, bottom, anchored)
		draw_rect(Rect2(x - 0.5, y, 1.5, 1.5), _c(_look.mid, a))
		draw_rect(Rect2(x + (-0.5 if k % 2 == 0 else 0.5), y, 0.5, 1.0), _c(_look.lit, a))
		draw_rect(Rect2(x + 0.5, y + (0.5 if k % 2 == 0 else 1.0), 0.5, 0.5), _c(_look.dark, a))
		y += 1.5
		k += 1
	if anchored:
		_draw_cleat(x, top)
	# A knot where it takes the plank.
	draw_rect(Rect2(x - 1.0, bottom - 1.5, 2.5, 1.5), _c(_look.mid))
	draw_rect(Rect2(x - 1.0, bottom - 1.5, 2.5, 0.5), _c(_look.lit))


func _draw_chain(x: float, top: float, bottom: float, anchored: bool) -> void:
	# Links 3 px long, alternating face-on (an open oval) and edge-on (a bar).
	var y := top
	var k := 0
	while y < bottom:
		var a := _fade(y, top, bottom, anchored)
		var h := minf(3.0, bottom - y)
		if k % 2 == 0:
			draw_rect(Rect2(x - 1.5, y, 0.5, h), _c(_look.lit, a))
			draw_rect(Rect2(x - 1.0, y, 0.5, h), _c(_look.mid, a))
			draw_rect(Rect2(x + 1.0, y, 0.5, h), _c(_look.dark, a))
			draw_rect(Rect2(x - 1.0, y, 2.0, 0.5), _c(_look.lit, a))
			draw_rect(Rect2(x - 1.0, y + h - 0.5, 2.0, 0.5), _c(_look.dark, a))
		else:
			draw_rect(Rect2(x - 0.25, y - 0.5, 0.5, h + 1.0), _c(_look.lit, a))
			draw_rect(Rect2(x + 0.25, y - 0.5, 0.5, h + 1.0), _c(_look.dark, a))
		y += 2.5
		k += 1
	if anchored:
		_draw_cleat(x, top)
	# A ring bolted through the board.
	draw_rect(Rect2(x - 1.5, bottom - 1.0, 3.0, 1.0), _c(_look.dark))
	draw_rect(Rect2(x - 1.0, bottom - 1.0, 2.0, 0.5), _c(_look.lit))


## The iron plate a hanger is fixed to where it meets a ceiling or plank above.
func _draw_cleat(x: float, top: float) -> void:
	draw_rect(Rect2(x - 2.0, top, 4.5, 1.5), _c(_look.dark))
	draw_rect(Rect2(x - 1.5, top, 3.5, 0.5), _c(_look.lit))


func _draw_post(x: float, top: float, bottom: float) -> void:
	var w: Array = _look.wood
	draw_rect(Rect2(x - 1.0, top, 2.5, bottom - top), _c(w[1]))
	draw_rect(Rect2(x - 1.0, top, 0.5, bottom - top), _c(w[0]))
	draw_rect(Rect2(x + 1.0, top, 0.5, bottom - top), _c(w[2]))
	# A wider foot where it meets the floor, and a cap block under the board.
	draw_rect(Rect2(x - 2.0, bottom - 1.5, 4.5, 1.5), _c(w[2]))
	draw_rect(Rect2(x - 2.0, top, 4.5, 1.5), _c(w[2]))


func _draw_brace(cell: Vector2i, side: int) -> void:
	# A diagonal strut from the wall, a tile below the board, up to the plank's
	# underside a tile in from the wall, with a bolt plate at each end.
	var w: Array = _look.wood
	var wall_x := float(cell.x * TILE if side < 0 else (cell.x + 1) * TILE)
	var top := cell.y * TILE + BOARD
	var steps := int(TILE * 2) # half-pixel steps along a 16 px diagonal
	for i in steps:
		var d := i * 0.5
		var px := wall_x - side * d
		var py := top + TILE - d
		draw_rect(Rect2(px - 0.75, py - 0.75, 2.0, 1.5), _c(w[1]))
		draw_rect(Rect2(px - 0.75, py - 0.75, 2.0, 0.5), _c(w[0]))
		draw_rect(Rect2(px - 0.75, py + 0.5, 2.0, 0.5), _c(w[2]))
	draw_rect(Rect2(wall_x - (2.0 if side > 0 else 0.0), top + TILE - 2.0, 2.0, 4.0), _c(w[2]))
