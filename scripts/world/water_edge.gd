class_name WaterEdge
extends RefCounted
## Where water meets stone (design bible 12.97, pass 620). Shared by the deep
## water (`SwimWater`) and Vorrhallow's standing water (`Tide`).
##
## - A **bank** is a place the surface ends against a square face of stone. The
##   water laps it: foam climbs the face a pixel or two with the swell, lies
##   along the surface beside it, and lets a fleck drift off. The stone over the
##   waterline is damp for a few pixels up.
## - **Sunk stone** takes the water: a face of stone that touches a water cell
##   is darkened a few pixels in, in steps, so a pier stands in the water and is
##   not laid over it.
##
## Slopes are never asked about: a bank is a square face only.

const FOAM := Color("c8fff6")
const DAMP := Color(0.02, 0.07, 0.1)
## Wet stone over the waterline: the alpha of each row above the surface,
## nearest first.
const DAMP_ROWS: Array[float] = [0.36, 0.24, 0.12]
## How far (px) into the stone the damp reaches.
const DAMP_IN := 6
## Sunk stone: the alpha of each step into the stone, from the water's side.
const SUNK_STEPS: Array[float] = [0.62, 0.46, 0.3, 0.15]
## Width (px) of one step.
const SUNK_STEP := 3
## How far (px) from the stone the foam's fleck drifts before it is gone.
const FLECK_REACH := 7

const _SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## Every bank of the surface cells `surface` (tiles): `[cell, side, tall]`.
## `cell` is the water cell, `side` is -1 with the stone on its left and 1 on its
## right, and `tall` is true if the stone rises over the waterline there.
static func banks(surface: Array, solid: Callable) -> Array:
	var out: Array = []
	for c: Vector2i in surface:
		for side: int in [-1, 1]:
			var s := c + Vector2i(side, 0)
			if solid.call(s):
				out.append([c, side, bool(solid.call(s + Vector2i.UP))])
	return out


## The foam at a bank at time `t`: `[dx, dy, alpha]` for each pixel. `dx` counts
## away from the stone (0 is the water's first pixel beside it) and `dy` from
## the surface (negative is up). `key` sets one bank's swell apart from the next.
static func lap(t: float, key: int) -> Array:
	var swell := sin(t * 2.4 + float(key) * 1.7)
	var out: Array = []
	var climb := 2 if swell > 0.25 else 1
	for k in climb:
		out.append([0, -1 - k, 0.9 if k == 0 else 0.6])
	out.append([1, -1, 0.65])
	out.append([0, 0, 0.85])
	out.append([1, 0, 0.85])
	out.append([2, 0, 0.7])
	if swell > -0.4:
		out.append([3, 0, 0.45])
	# A fleck leaves the stone and thins as it goes.
	var f := fmod(t * 0.55 + float(posmod(key, 7)) * 0.37, 1.0)
	out.append([4 + int(f * float(FLECK_REACH)), 0, 0.5 * (1.0 - f)])
	return out


## The stone's bands that touch a water cell: `[rect (px), step]`, `step` 0 at
## the water's side. `cells` are the water's cells (tiles).
static func sunk(cells: Dictionary, solid: Callable, tile: int) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		for dir: Vector2i in _SIDES:
			var n := c + dir
			if cells.has(n) or not solid.call(n):
				continue
			for k in SUNK_STEPS.size():
				var r: Rect2
				if dir.x > 0:
					r = Rect2(n.x * tile + k * SUNK_STEP, n.y * tile, SUNK_STEP, tile)
				elif dir.x < 0:
					r = Rect2((n.x + 1) * tile - (k + 1) * SUNK_STEP, n.y * tile, SUNK_STEP, tile)
				elif dir.y > 0:
					r = Rect2(n.x * tile, n.y * tile + k * SUNK_STEP, tile, SUNK_STEP)
				else:
					r = Rect2(n.x * tile, (n.y + 1) * tile - (k + 1) * SUNK_STEP, tile, SUNK_STEP)
				out.append([r, k])
	return out


## Draws a bank's foam on `ci`. `face` is the stone's face on the surface (px).
static func draw_lap(ci: CanvasItem, face: Vector2, side: int, t: float, key: int, alpha := 1.0) -> void:
	for px: Array in lap(t, key):
		var dx := int(px[0])
		var x := face.x - 1.0 - dx if side > 0 else face.x + dx
		ci.draw_rect(Rect2(x, face.y + int(px[1]), 1.0, 1.0), Color(FOAM, float(px[2]) * alpha))


## Draws the damp on the stone over a bank's waterline.
static func draw_damp(ci: CanvasItem, face: Vector2, side: int) -> void:
	var x := face.x if side > 0 else face.x - DAMP_IN
	for i in DAMP_ROWS.size():
		# The damp climbs higher at the face than deep in the stone.
		var w := DAMP_IN - i * 2
		var x0 := x if side > 0 else x + (DAMP_IN - w)
		ci.draw_rect(Rect2(x0, face.y - 1.0 - i, w, 1.0), Color(DAMP, DAMP_ROWS[i]))
