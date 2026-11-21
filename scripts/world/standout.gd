class_name Standout
extends RefCounted
## What the player can still use catches the light (pass 630, design bible
## 12.106). The pass 625 grade: "chests, signs and pickups do not separate from
## the scenery". A zone's chest and stele are built from the zone's own stone
## and timber (12.31, 12.80), so their body tones are the wall's. Three things
## set a thing apart without leaving its zone's colors:
##
## - a halo behind it, in its accent, stepped in three flat discs (no dither);
## - a rim: the top of its silhouette drawn in its accent, where its dark
##   outline was;
## - a glint: a small four-armed star that opens and shuts at one of a few
##   spots on that rim in turn.
##
## A closed chest carries all three and an opened one none, so "still to do"
## reads from across the room. A stele carries the halo and the rim.

## The halo's steps, outermost first: [fraction of the radius, alpha]. The
## alphas stack, since each disc lies on the last.
const HALO := [[1.0, 0.09], [0.66, 0.10], [0.36, 0.14]]

## A glint's color: the master palette's lightest warm white.
const GLINT := "f7f1de"
## Seconds for the glint to visit every spot once.
const GLINT_CYCLE := 2.7
## Seconds one glint stays open.
const GLINT_OPEN := 0.5
## The longest arm of a glint, in pixels out from its center.
const GLINT_ARM := 2


## Draws the halo on `ci`, centered at `at`. It breathes by a pixel.
static func draw_halo(ci: CanvasItem, at: Vector2, radius: float, color: Color, t: float) -> void:
	var breath := sin(t * 3.0)
	for step: Array in HALO:
		ci.draw_circle(at, radius * float(step[0]) + breath, Color(color, float(step[1])))


## The top cell of every column the rects cover: [Vector2i(x, y), ...] sorted
## by x. `rects` are [x, y, w, h, ...] in whole cells.
static func top_cells(rects: Array) -> Array:
	var tops := {}
	for q: Array in rects:
		for x in range(int(q[0]), int(q[0]) + int(q[2])):
			if not tops.has(x) or int(q[1]) < int(tops[x]):
				tops[x] = int(q[1])
	var xs: Array = tops.keys()
	xs.sort()
	var out: Array = []
	for x: int in xs:
		out.append(Vector2i(x, int(tops[x])))
	return out


## `count` spots along a rim, spread evenly and kept off its two ends.
static func glint_spots(rim: Array, count: int) -> Array:
	var out: Array = []
	if rim.is_empty():
		return out
	for i in count:
		var f := (i + 0.5) / float(count)
		# Visit them out of order (middle, left, right) so the eye is not led
		# along the lid like a scanner.
		out.append(rim[clampi(int(f * rim.size()), 1, maxi(1, rim.size() - 2))])
	if out.size() >= 2:
		var mid: Vector2i = out[out.size() / 2]
		out.remove_at(out.size() / 2)
		out.push_front(mid)
	return out


## Which spot is glinting at time `t`, and how far its arms reach (0 to
## GLINT_ARM): [index, arm]. The index is -1 between glints. Only one spot is
## ever open, and each opens and shuts through the shorter arm.
static func glint_at(t: float, count: int) -> Array:
	if count <= 0:
		return [-1, 0]
	var slot := GLINT_CYCLE / float(count)
	var u := fposmod(t, GLINT_CYCLE)
	var i := int(u / slot)
	var local := u - i * slot
	if local >= GLINT_OPEN:
		return [-1, 0]
	var k := sin(local / GLINT_OPEN * PI)
	return [i, clampi(int(ceilf(k * GLINT_ARM)), 1, GLINT_ARM)]


## Draws a glint centered on `at` (pixels), its arms `arm` whole pixels long
## and one pixel thick: a plus sign that grows from 3 px to 5 px across.
static func draw_glint(ci: CanvasItem, at: Vector2, arm: int) -> void:
	var c := Color(GLINT)
	var o := at.floor()
	ci.draw_rect(Rect2(o.x - arm, o.y, 2 * arm + 1, 1), c)
	ci.draw_rect(Rect2(o.x, o.y - arm, 1, 2 * arm + 1), c)


## Relative luminance of a hex tone, for tests and for choosing a rim.
static func luminance(hex: String) -> float:
	var c := Color(hex)
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Whether an accent tone reads apart from a body tone: a quarter brighter, or
## far more saturated (Vorrhallow's magenta is no lighter than its stone, and
## is the one strong color in the hall).
static func separates(accent: String, body: String) -> bool:
	if luminance(accent) > luminance(body) * 1.25:
		return true
	return Color(accent).s >= Color(body).s + 0.3
