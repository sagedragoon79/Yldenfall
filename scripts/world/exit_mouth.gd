class_name ExitMouth
extends Node2D
## A side exit is the mouth of a passage, not a gap under a hanging wall (design
## bible 12.125, pass 649). A door on a room's left or right edge is an opening
## with floor under it and, in most rooms, a wall above it a tile or two thick.
## The backdrop showed through the opening at full light right to the screen's
## edge, so the wall over it read as a slab that ended in mid-air (the pass 645
## grade: "walls that end mid-air at the screen's edge").
##
## Now the opening darkens toward the edge, as a passage does that runs on past
## the frame under that wall:
##
## - from nothing `DEPTH` world px in to `MAX_ALPHA` at the edge, on a curve, so
##   the room's own light reaches a little way in and the rest falls into shadow;
## - darker under the lintel (`LINTEL_ROWS`), where the passage's roof is;
## - quantised to `DeepShade`'s steps and ordered dither in 2-pixel blocks, so it
##   is pixelled steps, never a smooth gradient;
## - behind the tiles and every actor (`z_index` -1, over the light shafts), so the
##   lintel, the threshold and the hero stay lit and only the backdrop seen
##   through the mouth is shaded.
##
## An opening with open sky over it (no wall above it at the edge) has no roof and
## is left alone. Built once per room load; no cost per frame.

const TILE := 16
const COLOR := Color(0.0, 0.0, 0.02)
## How far in from the edge the shade reaches, world px.
const DEPTH := 56.0
## Opacity at the edge.
const MAX_ALPHA := 0.9
## The falloff's curve: above 1 keeps the dark close to the edge.
const CURVE := 1.4
## Rows under the lintel that darken further, world px, and by how much.
const LINTEL_ROWS := 12.0
const LINTEL_BOOST := 0.35
const LEVELS := 6
const GRAIN := DeepShade.GRAIN

## Past the wall's end the mouth has no roof: its top fades in over this many px.
const OPEN_FADE := 24.0

## Each mouth: {rect: Rect2 (world px, the shaded opening), left: bool, roof: int}.
## `roof` is how many px in from the edge the wall above it reaches.
var mouths: Array = []
## The rects to fill, built once per setup: [Rect2, alpha] pairs.
var _rects: Array = []


func _ready() -> void:
	# Behind the tiles (z 0), over the light shafts (z -1, added earlier).
	z_index = -1


## `doors` maps a door number to {rect: Rect2i (tiles), edge}, as
## `Room.scan_doors` returns. `solids` is the room's ground look over `size`.
func setup(doors: Dictionary, solids: Dictionary, size: Vector2i) -> void:
	mouths = find_mouths(doors, solids, size)
	_rects.clear()
	for m: Dictionary in mouths:
		_rects.append_array(build_rects(m.rect, m.left, m.roof))
	queue_redraw()


## The openings to shade. A side door's opening runs up its edge column through
## open air to the wall above it; with no wall there it is open sky and skipped.
static func find_mouths(doors: Dictionary, solids: Dictionary, size: Vector2i) -> Array:
	var out: Array = []
	for n: int in doors:
		var edge: String = doors[n].edge
		if edge != "left" and edge != "right":
			continue
		var r: Rect2i = doors[n].rect
		var x := 0 if edge == "left" else size.x - 1
		var top := r.position.y
		while top > 0 and not solids.has(Vector2i(x, top - 1)):
			top -= 1
		if top == 0:
			continue
		# How far in the opening runs before a wall closes it: never past DEPTH.
		var inward := 0
		var limit := ceili(DEPTH / TILE)
		var step := 1 if edge == "left" else -1
		while inward < limit:
			var cx := x + step * inward
			if cx < 0 or cx >= size.x or solids.has(Vector2i(cx, r.end.y - 1)):
				break
			inward += 1
		if inward == 0:
			continue
		var roof := 0
		while roof < inward and solids.has(Vector2i(x + step * roof, top - 1)):
			roof += 1
		var w := inward * TILE
		var px := 0 if edge == "left" else (size.x * TILE - w)
		out.append({
			"rect": Rect2(px, top * TILE, w, (r.end.y - top) * TILE),
			"left": edge == "left",
			"roof": roof * TILE,
		})
	return out


## The shade at a point `d` px in from the edge and `below` px under the mouth's
## top, 0..1. Under the wall (`d` < `roof`) it darkens toward the lintel; past it
## the top fades in, so no hard edge is drawn across open air.
static func shade_at(d: float, below: float, roof := INF) -> float:
	if d >= DEPTH:
		return 0.0
	var v := pow(1.0 - d / DEPTH, CURVE)
	if d >= roof:
		return v * clampf(below / OPEN_FADE, 0.0, 1.0)
	if below < LINTEL_ROWS:
		v += LINTEL_BOOST * (1.0 - below / LINTEL_ROWS) * (1.0 - d / DEPTH)
	return clampf(v, 0.0, 1.0)


## The quantised step of `v` at block `b`.
static func level_at(v: float, b: Vector2i) -> int:
	if v <= 0.0:
		return 0
	return clampi(roundi(v * LEVELS + DeepShade.dither(b)), 0, LEVELS)


static func alpha_for(level: int) -> float:
	return MAX_ALPHA * float(level) / LEVELS


## Runs of `GRAIN` blocks along each row of `rect`, one per step of shade.
static func build_rects(rect: Rect2, left: bool, roof := INF) -> Array:
	var out: Array = []
	var cols := int(rect.size.x) / GRAIN
	var rows := int(rect.size.y) / GRAIN
	for by in rows:
		var y := rect.position.y + by * GRAIN
		var below := by * GRAIN + GRAIN * 0.5
		var run_start := 0
		var run_level := -1
		for bx in cols + 1:
			var level := 0
			if bx < cols:
				var x := rect.position.x + bx * GRAIN
				var d := (bx * GRAIN + GRAIN * 0.5) if left else (rect.size.x - bx * GRAIN - GRAIN * 0.5)
				level = level_at(shade_at(d, below, roof), Vector2i(int(x) / GRAIN, int(y) / GRAIN))
			if level != run_level or bx == cols:
				if run_level > 0:
					out.append([Rect2(rect.position.x + run_start * GRAIN, y, (bx - run_start) * GRAIN, GRAIN), alpha_for(run_level)])
				run_start = bx
				run_level = level
	return out


## The opacity drawn at world point `p`, for tests.
func alpha_at(p: Vector2) -> float:
	var a := 0.0
	for pair: Array in _rects:
		if (pair[0] as Rect2).has_point(p):
			a = maxf(a, pair[1])
	return a


func _draw() -> void:
	for pair: Array in _rects:
		draw_rect(pair[0], Color(COLOR, pair[1]))
