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
## Posts are built timber, not sticks (design bible 12.81, pass 596): a squared
## post with a cap block and knee brackets under the board, a footing stone where
## it meets the floor, and bolts in the zone's accent. Two posts under one run
## are tied by a rail and cross-braced, bay by bay, so the run reads as a built
## trestle rather than a table on legs.
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
## A post's width, world px (pass 596: it was 2.5, and read as a stick).
const POST_W := 4.0
## A frame's widest bay, world px; a longer span is split into bays.
const BAY_MAX := 48.0
## A frame needs this much height between board and footing, world px (a post
## over one empty row, 29 px, is too squat to cross-brace).
const FRAME_MIN_H := 40.0

## Per-zone support look. `hang` is rope, chain or sinew (a strand drawn like rope); `lit`, `mid`, `dark` are the
## hanger's three tones; `wood` the post and brace timber (lit, mid, dark), in
## the plank's own strut ramp (tilegen PLANK) so the support reads as the same
## build as the board it carries; `bolt` the fastener accent (tilegen PLANK
## `nail`), and `foot` the footing stone (lit, mid, dark).
const LOOKS := {
	"gym": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "aca1ba", "foot": ["797767", "58544c", "363330"]},
	"heartwood": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "f0c02e", "foot": ["797767", "58544c", "363330"]},
	"boughs": {"hang": "rope", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "a1d684", "foot": ["797767", "58544c", "363330"]},
	"hearthroot": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "f0c02e", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"haar": {"hang": "rope", "lit": "aa9173", "mid": "8a6e56", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "989885", "foot": ["797767", "58544c", "363330"]},
	"sunken": {"hang": "chain", "lit": "aa9173", "mid": "634a41", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "84cbd6", "foot": ["797767", "58544c", "363330"]},
	"spires": {"hang": "rope", "lit": "bea860", "mid": "9c7f44", "dark": "432d23", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "edce6e", "foot": ["797767", "58544c", "363330"]},
	"vorrhallow": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "d684c6", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"trials": {"hang": "chain", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "b4b4a7", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"tower": {"hang": "chain", "lit": "aca1ba", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "84cbd6", "foot": ["867ba2", "645e82", "2f2c3a"]},
	# The Evercrown's shelves are grown, not built (bible 12.34, pass 542): they hang on
	# sinew strands (night-5, night-3, crystal-1: wine, not red, bible 12.48), not hot crystal chains.
	"evercrown": {"hang": "sinew", "lit": "af92c9", "mid": "5d4997", "dark": "421e48", "wood": ["8265b8", "5d4997", "2c2541"], "bolt": "b5e3e1", "foot": ["8265b8", "5d4997", "2c2541"]},
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
		var posts: Array[Dictionary] = []
		for i in 2:
			if held[i] or (i == 1 and run.y == run.z):
				continue
			var col: int = ends[i]
			var x := col * TILE + (INSET if i == 0 else TILE - INSET)
			if run.y == run.z:
				x = col * TILE + TILE * 0.5
			var below := PlankSupports._gap(col, row, 1, planks, solid, size)
			if below >= 1 and below <= POST_MAX:
				# Knee brackets toward the run's middle only, so none juts past its end.
				var knees: Array = [-1, 1] if run.y == run.z else [1 if i == 0 else -1]
				var post := {"kind": "post", "x": x, "top": row * TILE + BOARD, "bottom": float((row + 1 + below) * TILE), "knees": knees}
				out.append(post)
				posts.append(post)
				continue
			var above := PlankSupports._gap(col, row, -1, planks, solid, size)
			var anchored := above >= 0 and above <= HANG_MAX
			var top := float((row - above) * TILE) if anchored else float((row - FADE_TILES) * TILE)
			if anchored and planks.has(Vector2i(col, row - above - 1)):
				top = (row - above - 1) * TILE + BOARD_UNDER
			if not anchored:
				top = maxf(top, 0.0)
			out.append({"kind": "hang", "x": x, "top": top, "bottom": row * TILE + BOARD, "anchored": anchored})
		# Two posts under one run are tied by a rail and cross-braced (pass 596).
		if posts.size() == 2:
			var low := minf(posts[0].bottom, posts[1].bottom)
			if low - posts[0].top >= FRAME_MIN_H:
				out.append({"kind": "frame", "left": posts[0].x, "right": posts[1].x, "top": posts[0].top, "bottom": low})
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
				_draw_parts(PlankSupports.post_parts(s.x, s.top, s.bottom, _look, s.get("knees", [-1, 1])))
			"frame":
				_draw_parts(PlankSupports.frame_parts(s.left, s.right, s.top, s.bottom, _look))
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


func _draw_parts(parts: Array) -> void:
	for p: Array in parts:
		draw_rect(p[0], _c(p[1]))


## The rects of a post, each [Rect2, hex tone], back to front (pass 596): a
## squared post with a lit and a shaded edge and grain ticks, a cap block under
## the board with a bolt, knee brackets on the `knees` sides (-1 left, 1 right),
## and a footing stone.
static func post_parts(x: float, top: float, bottom: float, look: Dictionary, knees: Array = [-1, 1]) -> Array:
	var w: Array = look.wood
	var f: Array = look.foot
	var h := bottom - top
	var half := POST_W * 0.5
	var out: Array = []
	out.append([Rect2(x - half, top, POST_W, h), w[1]])
	out.append([Rect2(x - half, top, 1.0, h), w[0]])
	out.append([Rect2(x + half - 1.0, top, 1.0, h), w[2]])
	# Grain: short dark ticks down the face, alternating sides.
	var y := top + 6.0
	var k := 0
	while y < bottom - 6.0:
		out.append([Rect2(x - 0.5 + (0.5 if k % 2 else -0.5), y, 1.0, 1.5), w[2]])
		y += 5.0
		k += 1
	# Knee brackets: a short strut from the post up to the board, on the `knees` sides.
	if h >= 12.0:
		for side: int in knees:
			for i in 6:
				var px := x + side * (half + i * 0.75) - (1.0 if side < 0 else 0.0)
				var py := top + 6.5 - i * 0.75
				out.append([Rect2(px, py, 1.5, 1.5), w[1]])
				out.append([Rect2(px, py, 1.5, 0.5), w[0]])
	# The cap block the board rests on, with a bolt through it.
	out.append([Rect2(x - half - 2.0, top, POST_W + 4.0, 2.0), w[2]])
	out.append([Rect2(x - half - 2.0, top + 1.5, POST_W + 4.0, 0.5), w[1]])
	out.append([Rect2(x - 0.5, top + 0.5, 1.0, 1.0), look.bolt])
	# The footing stone: wider than the post, lit along its top.
	out.append([Rect2(x - half - 2.0, bottom - 3.0, POST_W + 4.0, 3.0), f[1]])
	out.append([Rect2(x - half - 2.0, bottom - 3.0, POST_W + 4.0, 0.5), f[0]])
	out.append([Rect2(x - half - 2.0, bottom - 0.5, POST_W + 4.0, 0.5), f[2]])
	out.append([Rect2(x + half + 1.0, bottom - 2.5, 1.0, 2.5), f[2]])
	return out


## The rects of the frame between a run's two posts: a rail low down and a
## cross-brace in every bay (no bay wider than BAY_MAX), with a stud between bays
## and a bolt where each brace meets a post or the rail.
static func frame_parts(left: float, right: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var half := POST_W * 0.5
	var x0 := left + half
	var x1 := right - half
	var out: Array = []
	if x1 - x0 < 8.0:
		return out
	var rail := bottom - 9.0
	var high := top + 9.0
	var bays := maxi(1, ceili((x1 - x0) / BAY_MAX))
	var bay := (x1 - x0) / bays
	for b in bays:
		var a := x0 + b * bay
		var e := a + bay
		for diag: int in 2:
			var ya := high if diag == 0 else rail
			var ye := rail if diag == 0 else high
			var n := maxi(2, ceili(maxf(e - a, absf(ye - ya)) / 0.75))
			for i in n + 1:
				var t := float(i) / n
				var px := lerpf(a, e, t)
				var py := lerpf(ya, ye, t)
				out.append([Rect2(px - 0.75, py - 0.75, 1.5, 1.5), w[1]])
				out.append([Rect2(px - 0.75, py - 0.75, 1.5, 0.5), w[0]])
		if b > 0:
			out.append([Rect2(a - 1.0, top, 2.0, rail - top), w[1]])
			out.append([Rect2(a - 1.0, top, 0.5, rail - top), w[0]])
			out.append([Rect2(a + 0.5, top, 0.5, rail - top), w[2]])
	# The rail, over the braces' feet.
	out.append([Rect2(x0, rail - 1.0, x1 - x0, 2.5), w[1]])
	out.append([Rect2(x0, rail - 1.0, x1 - x0, 0.5), w[0]])
	out.append([Rect2(x0, rail + 1.0, x1 - x0, 0.5), w[2]])
	for bx: float in [x0 + 1.0, x1 - 2.0]:
		out.append([Rect2(bx, rail - 0.5, 1.0, 1.0), look.bolt])
		out.append([Rect2(bx, high - 0.5, 1.0, 1.0), look.bolt])
	return out


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
