class_name WaterShaft
extends Node2D
## The light goes on under the water (design bible 12.141, pass 665). The room's
## light shafts (`LightShaft`, 12.17) rake down the open air and used to stop dead
## at the deep water's surface, so a pool was one flat teal block under lit air
## (the pass 660 grade: "flat water rectangles"). Each shaft that meets an open
## surface now carries on into the water: bent steeper where it enters (`BEND`,
## water's refraction), narrower (`NARROW`), in the water's own pale cyan, and
## fading out with depth (`FADE_DEPTH`).
##
## Drawn as pixel art, not a gradient: 2-pixel rows (`GRAIN`), edges on the 2-pixel
## grid, a three-tier core (`TIERS`) and the fall with depth in `LEVELS` clean
## steps with no dither (the light's own steps, 12.129). It sways a whole grain at
## a time on its own clock (`SWAY`), as the surface above it moves.
##
## A child of `SwimWater`, drawn just over its body and behind every actor in the
## water (additive, like the air's shafts), so a swimmer, an eel and their tells
## draw over it. A shaft enters only through an open surface, never under a roof,
## and lights only water cells: it stops at stone and at the pool's floor.

## Additive brightness at the surface, in the core of a shaft.
const PEAK := 0.2
## Depth (px below the surface) where a shaft is gone.
const FADE_DEPTH := 184.0
## How much wider a shaft has grown by `FADE_DEPTH` (it diffuses as it sinks).
const SPREAD := 0.7
## Steps of the fall with depth.
const LEVELS := 6
## The shaft's lean in the water, as a share of its lean in the air.
const BEND := 0.75
## The shaft's half-width in the water, as a share of the air shaft's `HALF`.
const NARROW := 0.62
## Row height and edge grid, world px.
const GRAIN := 2
## Across the shaft: [share of the half-width, brightness], core outward.
const TIERS: Array = [[0.34, 1.0], [0.68, 0.55], [1.0, 0.25]]
## Sway: grains each way, and its pace.
const SWAY := 1
const SWAY_PACE := 0.6
## The water's light colour (SwimWater.SURFACE).
const COLOR := Color("8ae8e0")

## Set by SwimWater before this enters the tree.
var cells := {}
var roofed := {}
## The air shafts: the x of each at the room's top, and their lean (px per px).
var centers: Array[float] = []
var slope := 0.0
## The pool's top (px): depth counts from it, as the body's does.
var top := 0.0

## Each shaft in the water: [x at the surface, y of the surface] (px).
var entries: Array = []
var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	entries = find_entries()


## Where each air shaft meets an open surface cell of this water. Pure on the
## fields, so tests read it without drawing.
func find_entries() -> Array:
	var out: Array = []
	var tile := float(Room.TILE)
	for cx: float in centers:
		# Walk down the air shaft's centre line, tile row by tile row, until it
		# meets water or the room's floor.
		var bottom := 0.0
		for c: Vector2i in cells:
			bottom = maxf(bottom, (c.y + 1) * tile)
		var y := tile * 0.5
		while y < bottom:
			var x := cx + slope * y
			var c := Vector2i(floori(x / tile), floori(y / tile))
			if cells.has(c):
				if not cells.has(c + Vector2i.UP) and not roofed.has(c):
					out.append([snappedf(cx + slope * c.y * tile, GRAIN), c.y * tile])
				break
			y += tile
	return out


## A shaft's half-width in the water `depth` px under the surface: narrow where
## it enters, widening as it sinks.
static func half_width(depth: float = 0.0) -> float:
	return LightShaft.HALF * NARROW * (1.0 + SPREAD * clampf(depth / FADE_DEPTH, 0.0, 1.0))


## The step (0 = brightest, LEVELS = gone) a shaft is at `depth` px under its
## surface.
static func depth_step(depth: float) -> int:
	return clampi(floori(clampf(depth / FADE_DEPTH, 0.0, 1.0) * LEVELS), 0, LEVELS)


## Brightness of a shaft at `depth` px down and `dx` px off its centre line.
static func alpha_at(depth: float, dx: float) -> float:
	var s := depth_step(depth)
	if s >= LEVELS:
		return 0.0
	var h := half_width(depth)
	var tier := 0.0
	for t: Array in TIERS:
		if absf(dx) < float(t[0]) * h:
			tier = float(t[1])
			break
	return PEAK * tier * (1.0 - float(s) / float(LEVELS))


## The sway (px, whole grains) of shaft `i` at time `t`.
static func sway_at(i: int, t: float) -> float:
	return float(roundi(sin(t * SWAY_PACE + i * 2.1) * SWAY) * GRAIN)


func _process(delta: float) -> void:
	if entries.is_empty():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var tile := float(Room.TILE)
	var lean := slope * BEND
	for i in entries.size():
		var e: Array = entries[i]
		var x0: float = e[0] + sway_at(i, _t)
		var y0: float = e[1]
		var d := 0.0
		while d < FADE_DEPTH:
			var y := y0 + d
			var row := floori(y / tile)
			var cx := x0 + lean * d
			var h := half_width(d)
			# Each tier is a run of whole grains either side of the centre line.
			var prev := 0.0
			for t: Array in TIERS:
				var a := alpha_at(d, prev)
				var w := snappedf(float(t[0]) * h, GRAIN)
				if a > 0.0:
					for side in [-1.0, 1.0]:
						var xa := snappedf(cx, GRAIN) + (prev if side > 0.0 else -w)
						var xb := xa + (w - prev)
						_span(xa, xb, y, row, Color(COLOR, a))
				prev = w
			d += GRAIN


## Draws a 2-pixel row from xa to xb at y, only over water cells of `row`.
func _span(xa: float, xb: float, y: float, row: int, c: Color) -> void:
	var tile := float(Room.TILE)
	var x := xa
	while x < xb:
		var col := floori(x / tile)
		var end := minf(xb, (col + 1) * tile)
		if cells.has(Vector2i(col, row)):
			draw_rect(Rect2(x, y, end - x, GRAIN), c)
		x = end
