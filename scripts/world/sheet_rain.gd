class_name SheetRain
extends Node2D
## Trial (pass 498): Carillon's rain drawn from a PixelLab rain sheet instead of
## the code streak field in Motes, to weigh the two by eye. The sheet
## (assets/vfx/carillon_rain.png, 32 frames of 160x120 wind-slanted drops in three
## depths) is tiled screen-wide in two parallax layers at different scales, speeds
## and phases, so the 1 s loop and the 160 px tile never read as a repeat. It leans
## with the storm wind (the slant is baked, plus a slow horizontal drift) and thins
## to a drizzle once the Sky Spring is restored, matching Motes.SETTLES ("spring:sky").
##
## Whether Carillon uses this or the code rain is set in scenes by World: the trial
## flag --sheet-rain turns it on for a capture; SHIPPED holds the kept decision.

## The kept decision after the pass-498 trial: the PixelLab sheet is Carillon's rain.
## It reads as a driven storm with real depth, where the code streak field barely
## showed. The streak field (Motes zone "spires") stays as the fallback: set this
## false and World draws it again. --sheet-rain forces the sheet on for a capture.
const SHIPPED := true

const SHEET := "res://assets/vfx/carillon_rain.png"
const FRAME := Vector2i(160, 120)
const COLS := 6
const FRAMES := 32
const FPS := 30.0
const VIEW := Vector2(640, 360)

## The most a rain layer may cover what is behind it (design bible 12.71, pass 584).
## The rain falls in front of the play field, so every drop crosses the hero, the
## foes and their tells. At 0.85 the near layer was a screen of white dashes over the
## fight (the pass 580 grade: "noisy"); under this it is weather, and the figures
## keep the brightest marks in the room.
const MAX_ALPHA := 0.5

## Two layers: [scale, frame fps, phase (frames), alpha, wind drift px/s].
const LAYERS := [
	[2.0, 20.0, 16.0, 0.26, 10.0],   # far: big, slow, faint, drifts slowly
	[1.0, 30.0, 0.0, 0.46, 24.0],    # near: crisp, fast, drifts faster
]

var active := false
var _frames: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slice()


func set_active(on: bool) -> void:
	active = on
	_t = 0.0
	queue_redraw()


## How hard it rains now: 1.0 in the full storm, thinned to a drizzle once the Sky
## Spring breaks it (the same "spring:sky" flag that thins the code rain, Motes.SETTLES).
func density() -> float:
	return 0.35 if GameState.flag("spring:sky") else 1.0


## Cuts the sheet into its 32 frames once.
func _slice() -> void:
	var tex := load(SHEET) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	for i in FRAMES:
		var cell := Vector2i(i % COLS, i / COLS) * FRAME
		var cut := img.get_region(Rect2i(cell, FRAME))
		_frames.append(ImageTexture.create_from_image(cut))


func _process(delta: float) -> void:
	if not active or _frames.is_empty():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not active or _frames.is_empty():
		return
	var origin := _view_origin()
	var t := get_viewport().get_canvas_transform()
	var seen := get_viewport().get_visible_rect().size / t.get_scale()
	var dens := density()
	for layer: Array in LAYERS:
		var scale: float = layer[0]
		var fps: float = layer[1]
		var phase: float = layer[2]
		var a: float = layer[3] * dens
		var wind: float = layer[4]
		var frame: int = int(_t * fps + phase) % FRAMES
		var tex := _frames[frame]
		var tile := Vector2(FRAME) * scale
		# A slow horizontal drift of the whole field, wrapped by the tile width, so
		# the far layer's repeat seam is never still long enough to be seen.
		var slip := Vector2(fposmod(-_t * wind, tile.x), 0.0)
		var cols := ceili(seen.x / tile.x) + 1
		var rows := ceili(seen.y / tile.y) + 1
		for row in rows:
			for col in cols:
				var at := (origin + slip + Vector2(col, row) * tile).floor()
				at.x -= tile.x
				draw_texture_rect(tex, Rect2(at, tile), false, Color(1, 1, 1, a))


## The world position of the screen's top-left corner (as Motes computes it).
func _view_origin() -> Vector2:
	var t := get_viewport().get_canvas_transform()
	return -t.origin / t.get_scale()
