class_name SlashFx
extends Node2D
## The smear arc for a sword swing or Delver's Pick down-strike. Follows the player.
##
## Two looks (pass 535, bible 6.7): the code-drawn arcs below, or a PixelLab VFX-tool
## sheet (assets/vfx/slash_smear.png, heavy_smear.png: a cream crescent whose edge whips
## down the front of the swing and crumbles from the tail, 5 frames at 30 fps). The sheet
## is drawn for a side cut facing right, sweeping top to bottom; the other cuts mirror or
## quarter-turn it, which keeps every pixel whole. The thrust keeps its code streak.
## SHEET_SHIPPED holds the kept decision; --slash-look=code|sheet forces one for a capture.
## Since pass 537 a swing's smear waits for the blade to travel (wait_for_strike):
## the hero's windup frames show no smear.

## The kept decision after the pass-535 trial (see docs/loop/pass-535.md).
const SHEET_SHIPPED := true
## Forced look for a capture or a test: "" follows SHEET_SHIPPED, else "code" or "sheet".
static var trial := ""
const SHEET := "res://assets/vfx/slash_smear"
const HEAVY_SHEET := "res://assets/vfx/heavy_smear"
## Two sheet pixels to a world pixel (GameCamera.DETAIL), like the hit spark.
const DENSITY := 2.0

const LIFE := 0.12
const COLOR := Color("f6eed2")
const EDGE := Color("ffffff")
const HEAVY := Color("ffe9a8")

var _kind := "side"
var _facing := 1
var _combo := 1
var _heavy := false
var _life := LIFE
## Scales the smear for a bigger blade (the Dwarvish Broad Sword's arc).
var _size := 1.0
## The sheet being played ({} for the code look): frames, pivot, fps.
var _sheet := {}
## How long this smear lives: LIFE for the code look, one run of the sheet for the sheet.
var life := LIFE
## The swing clip's windup (pass 537): the smear runs the clip's own clock, its fps
## and the sequence step of its strike frame, and starts on the step the hero's
## sprite reaches that frame, not while the sword is still raised. The same sum of
## step deltas as PlayerVisual's anim_time lands on the same step.
var _clip_fps := 0.0
var _clip_strike := 0
var _clip_time := 0.0


static func uses_sheet() -> bool:
	return trial == "sheet" or (trial == "" and SHEET_SHIPPED)


func setup(kind: String, facing: int, combo := 1, heavy := false, size := 1.0) -> void:
	_size = size
	_kind = kind
	_facing = facing
	_combo = combo
	_heavy = heavy
	z_index = 3
	if kind != "thrust" and uses_sheet():
		_sheet = HitSpark.load_sheet(HEAVY_SHEET if heavy else SHEET)
		life = _sheet.frames.size() / float(_sheet.fps)
		_life = life
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The sheet frame showing now (-1 for the code look).
func frame() -> int:
	if _sheet.is_empty():
		return -1
	return clampi(int((life - _life) * float(_sheet.fps)), 0, _sheet.frames.size() - 1)


## Waits out a swing clip's windup: `strike` is the sequence step the blade travels
## on at `fps`, and `clip_time` how far the clip has already played.
func wait_for_strike(fps: float, strike: int, clip_time: float) -> void:
	_clip_fps = fps
	_clip_strike = strike
	_clip_time = clip_time


## True while the smear waits out the windup and draws nothing.
func waiting() -> bool:
	return _clip_strike > 0 and int(_clip_time * _clip_fps) < _clip_strike


func _physics_process(delta: float) -> void:
	if waiting():
		_clip_time += delta
		if not waiting():
			# The blade travels: the smear's first frame shows this step.
			queue_redraw()
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if waiting():
		return
	if not _sheet.is_empty():
		_draw_sheet()
		return
	var k := clampf(_life / LIFE, 0.0, 1.0)
	if _kind == "thrust":
		_draw_thrust(k)
		return
	var center: Vector2
	var from: float
	var to: float
	match _kind:
		"up":
			center = Vector2(0, -38)
			from = deg_to_rad(-170)
			to = deg_to_rad(-10)
		"down":
			center = Vector2(0, -6)
			from = deg_to_rad(20)
			to = deg_to_rad(160)
		_:
			center = Vector2(_facing * 6, -22)
			from = deg_to_rad(-70) if _facing > 0 else deg_to_rad(250)
			to = deg_to_rad(70) if _facing > 0 else deg_to_rad(110)
	# The second combo hit sweeps the other way, so a chain reads as back-and-forth cuts.
	if _combo == 2:
		var t := from
		from = to
		to = t
	var radius := (26.0 if _heavy else 20.0) * _size
	var width := (9.0 if _heavy else 6.0) * _size
	var sweep := lerpf(0.35, 1.0, 1.0 - k)
	var end := lerpf(from, to, sweep)
	draw_arc(center, radius, from, end, 12, Color(HEAVY if _heavy else COLOR, k), width)
	draw_arc(center, radius + 3.0, from, end, 12, Color(EDGE, k), 2.0)


## The sheet's arc sweeps down the right of its pivot (the arc's centre). A side cut
## facing left mirrors it; the up cut turns it a quarter back (over the head, left to
## right) and the down cut a quarter on (under the feet, right to left). The second
## combo hit runs the other way, so a chain still reads as back-and-forth cuts.
func _draw_sheet() -> void:
	draw_set_transform_matrix(placement())
	draw_texture(_sheet.frames[frame()], -_sheet.pivot)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Where the sheet lands: its pivot (the arc's centre) moved to the cut's centre, turned
## for an up or down cut, mirrored for a side cut facing left, flipped for the back cut.
func placement() -> Transform2D:
	var at := Vector2(_facing * 6, -22)
	var turn := 0.0
	var flip := Vector2.ONE
	match _kind:
		"up":
			at = Vector2(0, -38)
			turn = -PI / 2.0
		"down":
			at = Vector2(0, -6)
			turn = PI / 2.0
		_:
			flip.x = float(_facing)
	if _combo == 2:
		# Flipping the sheet across its own sweep axis (before the turn) reverses the sweep.
		flip.y = -1.0
	return Transform2D(turn, flip * _size / DENSITY, 0.0, at)


## A Thrust: a straight streak of light from the hand to the point, thinning
## toward the tip, that shoots out and fades.
func _draw_thrust(k: float) -> void:
	var length := (Player.THRUST_LENGTH + 10.0) * _size * lerpf(0.5, 1.0, 1.0 - k)
	var y := -22.0
	var x0 := _facing * 6.0
	var tip := Vector2(x0 + _facing * length, y)
	draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 4), tip, Vector2(x0, y + 4)]), Color(HEAVY, k * 0.85))
	draw_line(Vector2(x0, y), tip, Color(EDGE, k), 2.0)
	draw_circle(tip, 2.5, Color(EDGE, k))
