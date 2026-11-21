class_name RainLanding
extends Node2D
## Rain lands, and lightning lights the stone (design bible 12.107, pass 631).
## Carillon's rain (`SheetRain`) is a sheet in front of the play field: it fell
## past every floor without touching one, and the far layer's bolts (12.71) lit
## nothing. The pass 625 grade: "the rain is one even overlay with no splash or
## wet stone, and the lightning lights nothing". Three things answer it, all
## drawn on the ground the rain can reach:
##
## - **Wet stone.** A top with open sky over it carries a broken line of pale
##   sheen, a dash or two a cell, that shimmers slowly. A top with a roof within
##   `SHELTER` cells over it is dry, so the ground under an island or an
##   overhang reads as shelter.
## - **Splashes.** Drops strike the wet tops: a streak, a crown, four
##   droplets flying apart, in a fifth of a second. They thin with the rain
##   (`SheetRain.density`).
## - **Lightning's light.** Every few seconds a far stroke: the sky behind the
##   ground lifts for two beats and every wet top takes a pale rim, so the mass
##   of the room stands dark against a lit sky. It is weather (12.71): fainter
##   than a tell, scaled by the player's flashes option, and it stops with the
##   storm once the Sky Spring is restored.
##
## Nothing is stored per drop: a splash and a stroke are worked out from the
## clock and the cell, so a frame costs a few hashes per visible cell.

const TILE := 16
## The zones it rains in (`World` runs `SheetRain` or the code rain there).
const ZONES: Array[String] = ["spires"]
## A top with ground or a board this many cells or fewer above it is dry.
const SHELTER := 4

## The palette's pale sky tone (sky-6): the rain's own white, a shade cool.
const PALE := Color("b5e3e1")
## The storm's light: the far bolts' own hue (crystal, 12.71) at its palest step.
const STORM := Color("e3b5d4")

## Sheen: how strong a dash is at rest, and how far its shimmer moves it.
const SHEEN_ALPHA := 0.6
const SHEEN_SWAY := 0.15
## Seconds for one shimmer.
const SHEEN_BEAT := 2.6

## Splashes: each wet cell rolls once a `SLOT`; a splash lives `LIFE` seconds.
const SLOT := 0.3
const LIFE := 0.2
## The share of slots a wet cell splashes in at the storm's height.
const CHANCE := 0.55
## A splash's three frames, in pixels from where the drop lands (y up is negative),
## each [x, y, alpha as a share of `SPLASH_ALPHA`].
const FRAMES := [
	[[0, -2, 1.0], [0, -1, 1.0]],
	[[-1, -3, 1.0], [1, -3, 1.0], [-2, -2, 0.8], [2, -2, 0.8], [0, -1, 0.6]],
	[[-2, -4, 0.8], [2, -4, 0.8], [-3, -2, 0.8], [3, -2, 0.8]],
]
## `SheetRain.MAX_ALPHA`: a splash is no brighter than a drop may be.
const SPLASH_ALPHA := 0.5

## Lightning: one stroke in every `PERIOD` seconds, starting in its first `SPREAD`.
const PERIOD := 7.0
const SPREAD := 4.0
## A stroke's light: [seconds from its start, strength]; straight lines between.
## Two beats and a fade, under half a second.
const STROKE := [[0.0, 1.0], [0.06, 1.0], [0.07, 0.25], [0.14, 0.25], [0.15, 0.8], [0.2, 0.8], [0.5, 0.0]]
## The most the stroke lifts the sky and rims a top (12.71: weather stays under a tell).
const SKY_ALPHA := 0.16
const RIM_ALPHA := 0.5

## Where the storm's clock starts (--storm-at=T, so a capture can catch a stroke).
static var clock_from := 0.0

var _tops: Array[Vector2i] = []
## Column -> the rows of its wet tops, for culling to the view.
var _columns := {}
var _t := 0.0
var _sky: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = clock_from
	# Over the moss and the room's grass: a splash stands on the top, not behind it.
	z_index = 1
	# The sky's lift is drawn behind the tiles and over the backdrop (-50).
	_sky = Node2D.new()
	_sky.name = "StormSky"
	_sky.z_index = -40
	_sky.draw.connect(_draw_sky)
	add_child(_sky)


static func falls_in(zone: String) -> bool:
	return zone in ZONES


## `solids` is the room's ground look, `slopes` its half-open cells, `planks`
## its boards; cells in `skip` (water, secrets) take no rain.
func setup(solids: Dictionary, planks: Dictionary, size: Vector2i, slopes := {}, skip := {}) -> void:
	_tops = wet_tops(solids, planks, size, slopes, skip)
	_columns.clear()
	for c in _tops:
		if not _columns.has(c.x):
			_columns[c.x] = []
		_columns[c.x].append(c.y)
	queue_redraw()


## The cells whose top the rain reaches: level ground or a board, with nothing
## over it for `SHELTER` cells (the room's top edge is open sky).
static func wet_tops(solids: Dictionary, planks: Dictionary, size: Vector2i, slopes := {}, skip := {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if skip.has(cell) or slopes.has(cell):
				continue
			if not solids.has(cell) and not planks.has(cell):
				continue
			if is_open_above(solids, planks, cell):
				out.append(cell)
	return out


static func is_open_above(solids: Dictionary, planks: Dictionary, cell: Vector2i) -> bool:
	for dy in range(1, SHELTER + 1):
		var over := cell + Vector2i(0, -dy)
		if over.y < 0:
			return dy > 1  # the top row of the room is wall, not a floor
		if solids.has(over) or planks.has(over):
			return false
	return true


func tops() -> Array[Vector2i]:
	return _tops


## A number in 0..1 from three whole numbers, the same every run.
static func roll(a: int, b: int, c: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65536.0


## The sheen's dashes on a wet cell: [x, length] in pixels along its top, one
## or two a cell, never the whole cell, so the line is broken.
static func sheen(cell: Vector2i) -> Array:
	var out := []
	var x := int(roll(cell.x, cell.y, 1) * 5.0)
	var first := 2 + int(roll(cell.x, cell.y, 2) * 4.0)
	out.append([x, first])
	if roll(cell.x, cell.y, 3) < 0.6:
		var gap := 3 + int(roll(cell.x, cell.y, 4) * 3.0)
		var from := x + first + gap
		var length := mini(2 + int(roll(cell.x, cell.y, 5) * 3.0), TILE - 1 - from)
		if length >= 2:
			out.append([from, length])
	return out


## The splash on `cell` at time `t`, or an empty array: [x in the cell (px), frame].
## `density` is the rain's (1 in the storm, less in the drizzle).
static func splash(cell: Vector2i, t: float, density := 1.0) -> Array:
	var at := t / SLOT + roll(cell.x, cell.y, 6)
	var slot := floori(at)
	if roll(cell.x * 31 + slot, cell.y, 7) >= CHANCE * density:
		return []
	var age := (at - slot) * SLOT
	if age >= LIFE:
		return []
	var x := 1 + int(roll(cell.x, cell.y * 17 + slot, 8) * (TILE - 2))
	return [x, mini(int(age / LIFE * FRAMES.size()), FRAMES.size() - 1)]


## When the stroke of period `k` starts.
static func stroke_start(k: int) -> float:
	return k * PERIOD + roll(k, 11, 9) * SPREAD


## The lightning's light at time `t`, 0..1, before the player's flashes option.
static func flash(t: float) -> float:
	var k := floori(t / PERIOD)
	var e := t - stroke_start(k)
	if e < 0.0:
		return 0.0
	for i in range(1, STROKE.size()):
		var a: Array = STROKE[i - 1]
		var b: Array = STROKE[i]
		if e <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (e - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
	return 0.0


## The light this frame: none once the Sky Spring has broken the storm, and
## scaled by the flashes option (design bible 14).
func light() -> float:
	if GameState.flag("spring:sky"):
		return 0.0
	return flash(_t) * Feel.flash_scale


## How hard it rains (as `SheetRain.density`).
func density() -> float:
	return 0.35 if GameState.flag("spring:sky") else 1.0


func _process(delta: float) -> void:
	if _tops.is_empty():
		return
	_t += delta
	queue_redraw()
	_sky.queue_redraw()


func _view() -> Rect2:
	var t := get_viewport().get_canvas_transform()
	var seen := get_viewport().get_visible_rect().size / t.get_scale()
	return Rect2(-t.origin / t.get_scale(), seen)


func _draw_sky() -> void:
	var lit := light()
	if lit <= 0.0:
		return
	_sky.draw_rect(_view().grow(8.0), Color(STORM, SKY_ALPHA * lit))


func _draw() -> void:
	if _tops.is_empty():
		return
	var view := _view()
	var lit := light()
	var dens := density()
	var x0 := floori(view.position.x / TILE) - 1
	var x1 := floori(view.end.x / TILE) + 1
	for x in range(x0, x1 + 1):
		if not _columns.has(x):
			continue
		for y: int in _columns[x]:
			var cell := Vector2i(x, y)
			var top := Vector2(cell * TILE)
			if top.y < view.position.y - TILE or top.y > view.end.y + TILE:
				continue
			# The stroke rims the whole top; the sheen's dashes ride on it.
			if lit > 0.0:
				draw_rect(Rect2(top, Vector2(TILE, 1)), Color(STORM, RIM_ALPHA * lit))
			var sway := sin((_t / SHEEN_BEAT + roll(x, y, 10)) * TAU) * SHEEN_SWAY
			for dash: Array in sheen(cell):
				draw_rect(Rect2(top + Vector2(int(dash[0]), 0), Vector2(int(dash[1]), 1)), Color(PALE, (SHEEN_ALPHA + sway) * (0.6 + 0.4 * dens)))
			var hit := splash(cell, _t, dens)
			if not hit.is_empty():
				var at := top + Vector2(int(hit[0]), 0)
				for px: Array in FRAMES[int(hit[1])]:
					draw_rect(Rect2(at + Vector2(int(px[0]), int(px[1])), Vector2.ONE), Color(PALE, SPLASH_ALPHA * float(px[2])))
