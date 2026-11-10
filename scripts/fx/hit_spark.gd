class_name HitSpark
extends Node2D
## The flash where a blade meets a foe (design bible 6.7): a white core, a ring and
## sharp rays thrown along the swing. It holds through the hit-stop, because hit-stop
## stops the game clock it counts down on, so the frozen frame shows the impact.
##
## Two looks (pass 529, bible 6.7): the code-drawn rays below, or a PixelLab VFX-tool
## sheet (assets/vfx/blade_spark.png, heavy_spark.png: a white-hot disc that opens into a
## ring while hot sparks spray forward and fall, 7 frames at 24 fps). SHEET_SHIPPED holds
## the kept decision; the game option --spark-look=code|sheet forces one for a capture.

## The kept decision after the pass-529 trial (see docs/loop/pass-529.md).
const SHEET_SHIPPED := true
## Forced look for a capture or a test: "" follows SHEET_SHIPPED, else "code" or "sheet".
static var trial := ""
## The sheets, light and heavy, as the VFX tool exported them (PNG + JSON beside it).
const SHEET := "res://assets/vfx/blade_spark"
const HEAVY_SHEET := "res://assets/vfx/heavy_spark"
## The sheets are drawn at the game's detail (GameCamera.DETAIL): two sheet pixels to a
## world pixel, like every sprite and tile, so their grain matches the hero's.
const DENSITY := 2.0
## A spark this big or bigger (Player.HEAVY_SPARK is 1.6) plays the heavy sheet.
const HEAVY_AT := 1.3

const LIFE := 0.14
const CORE := Color("ffffff")
const RAY := Color("fff4d6")
const RING := Color("ffe9a8")
## A hot rim under each ray, so the spark reads even over a foe's white hit flash.
const RIM := Color("f07a28")
const RAYS := 5

var dir := Vector2.RIGHT
var size := 1.0
var _life := LIFE
var _angles: Array[float] = []
## The sheet being played ({} for the code look): frames, pivot, fps.
var _sheet := {}
## How long this spark lives: LIFE for the code look, the sheet's run for the sheet.
var life := LIFE

static var _sheets := {}


static func uses_sheet() -> bool:
	return trial == "sheet" or (trial == "" and SHEET_SHIPPED)


## A VFX-tool sheet cut into its frames once: {"frames", "pivot", "fps"}.
static func load_sheet(base: String) -> Dictionary:
	if not _sheets.has(base):
		var tex := load(base + ".png") as Texture2D
		var meta: Dictionary = (load(base + ".json") as JSON).data
		var img := tex.get_image()
		var frames: Array[Texture2D] = []
		var pivot := Vector2.ZERO
		var ms := 0.0
		for f: Dictionary in meta.frames:
			var r: Dictionary = f.frame
			frames.append(ImageTexture.create_from_image(
					img.get_region(Rect2i(int(r.x), int(r.y), int(r.w), int(r.h)))))
			pivot = Vector2(roundf(float(f.pivot.x) * r.w), roundf(float(f.pivot.y) * r.h))
			ms += float(f.duration)
		# The exporter writes whole milliseconds (42 for 24 fps), so round back to the tool's fps.
		_sheets[base] = {"frames": frames, "pivot": pivot, "fps": roundf(1000.0 * frames.size() / ms)}
	return _sheets[base]


## Adds a spark to `parent` at global `at`, its rays thrown along `swing_dir`.
static func spawn(parent: Node, at: Vector2, swing_dir: Vector2, scale_by := 1.0) -> HitSpark:
	var s := HitSpark.new()
	s.dir = swing_dir.normalized() if swing_dir != Vector2.ZERO else Vector2.RIGHT
	s.size = scale_by
	parent.add_child(s)
	s.global_position = at
	return s


func _ready() -> void:
	z_index = 4
	if uses_sheet():
		_sheet = load_sheet(HEAVY_SHEET if size >= HEAVY_AT else SHEET)
		life = _sheet.frames.size() / float(_sheet.fps)
		_life = life
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	# Most rays fan forward along the swing; one kicks back.
	var base := dir.angle()
	for i in RAYS - 1:
		_angles.append(base + lerpf(-1.0, 1.0, float(i) / (RAYS - 2)) * 0.9 + randf_range(-0.15, 0.15))
	_angles.append(base + PI + randf_range(-0.4, 0.4))


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()


## The sheet frame showing now.
func frame() -> int:
	if _sheet.is_empty():
		return -1
	return clampi(int((life - _life) * float(_sheet.fps)), 0, _sheet.frames.size() - 1)


func _draw() -> void:
	if not _sheet.is_empty():
		_draw_sheet()
		return
	var k := clampf(_life / LIFE, 0.0, 1.0)
	var grow := 1.0 - k
	# The ring opens as it fades.
	draw_arc(Vector2.ZERO, (5.0 + 9.0 * grow) * size, 0.0, TAU, 16, Color(RING, k * 0.8), 1.5)
	for i in _angles.size():
		var a: float = _angles[i]
		var reach := (20.0 if i < _angles.size() - 1 else 10.0) * size
		var v := Vector2.from_angle(a)
		var from := v * reach * grow * 0.5
		var to := v * reach * (0.55 + 0.45 * grow)
		var w := 2.0 if i % 2 == 0 else 1.0
		draw_line(from, to, Color(RIM, k), w + 2.0)
		draw_line(from, to, Color(RAY, k), w)
	draw_circle(Vector2.ZERO, (4.0 * size + 1.5) * k, Color(RIM, k))
	draw_circle(Vector2.ZERO, 4.0 * size * k, Color(CORE, k))


## The sheet sprays to the right (+x) and its sparks fall. A leftward swing mirrors it
## (so the sparks still fall); an up or down swing turns it a quarter, which keeps
## every pixel whole.
func _draw_sheet() -> void:
	var flip := 1.0
	var turn := 0.0
	if absf(dir.y) > absf(dir.x):
		turn = -PI / 2.0 if dir.y < 0.0 else PI / 2.0
	elif dir.x < 0.0:
		flip = -1.0
	draw_set_transform(Vector2.ZERO, turn, Vector2(flip, 1.0) / DENSITY)
	draw_texture(_sheet.frames[frame()], -_sheet.pivot)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
