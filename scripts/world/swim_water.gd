class_name SwimWater
extends Node2D
## Deep water (the Sunken Spring, design bible 6.8 and 8.10; legend `a`). Every
## `a` cell in a room belongs to one SwimWater. While the centre of the player's
## body is in a water cell the player swims (Player.in_water): they float up to
## the surface, sink while holding Down, and a jump press is a stroke up; with
## the head above the surface it is a full jump out. Enemies are not slowed.
##
## Drawn in two layers (design bible 12.39, pass 548). Behind the actors, the
## body: a teal that darkens with depth below the surface, in `LEVELS` steps with
## a 4 x 4 ordered dither in `GRAIN`-pixel blocks, built once as a strip texture.
## In front of the bodies in it, a light tint (`FRONT_ALPHA`), the moving surface
## line, caustic light that is brightest just under the surface and gone by
## `CAUSTIC_DEPTH`, and bubbles. The older water was one flat translucent fill in
## front of everything, which the independent grade (pass 545) read as "a flat
## fill"; the light front tint also lets a swimmer and the eels read clearly.

const WATER := Color("1f6a78")
const SURFACE := Color("8ae8e0")
const BUBBLE := Color("c8fff6")
## The body just under the surface and at full depth (behind the actors).
const SHALLOW := Color(0.18, 0.54, 0.6, 0.2)
const ABYSS := Color(0.03, 0.12, 0.2, 0.82)
## Depth (px below the surface) where the body reaches `ABYSS`.
const DEPTH_FULL := 144.0
## Quantised steps of the body's depth.
const LEVELS := 5
## Dither block size, world px.
const GRAIN := 2
## Height of the body's strip texture; deeper rows draw flat `ABYSS`.
const STRIP_H := 160
## Opacity of the tint drawn in front of the bodies in the water.
const FRONT_ALPHA := 0.2
## Caustic light: its opacity at the surface, and the depth where it is gone.
const CAUSTIC_ALPHA := 0.3
const CAUSTIC_DEPTH := 56.0
## Speed (px/s) a body must hit the surface at to throw spray.
const SPLASH_SPEED := 140.0

## The water's cells (tiles) -> true.
var cells := {}
## Cells with rock right above them: no waterline is drawn there.
var roofed := {}

const _BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

static var _strip: ImageTexture

var _t := 0.0
var _runs: Array[Rect2] = []
## Depth (px) of each run's top below the pool's top, matching `_runs`.
var _run_depth: Array[float] = []
## The body, drawn behind the actors.
var _body: Node2D
var _surface: Array[Rect2] = []
var _was_in := false
var _splashes: Array[Vector3] = []   # x, y, age


func _ready() -> void:
	z_index = 1
	_build_runs()
	_body = Node2D.new()
	_body.name = "Body"
	_body.z_index = -2   # relative to this node's 1: under the actors, with the decor
	_body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_body.draw.connect(_draw_body)
	add_child(_body)


## The colour of the body's dither step `level`, from `SHALLOW` (0) to `ABYSS`
## (`LEVELS` - 1).
static func level_color(level: int) -> Color:
	return SHALLOW.lerp(ABYSS, float(level) / float(LEVELS - 1))


## The body's dithered level (0 to LEVELS - 1) at a pixel `depth` px below the
## surface, `x` px along (world aligned, so neighbouring runs line up).
static func depth_level(x: int, depth: int) -> int:
	# Square root: the light falls off fastest just under the surface.
	var v := sqrt(clampf(float(depth) / DEPTH_FULL, 0.0, 1.0)) * float(LEVELS - 1)
	var b: int = _BAYER[posmod(depth / GRAIN, 4)][posmod(x / GRAIN, 4)]
	return clampi(floori(v + (float(b) + 0.5) / 16.0), 0, LEVELS - 1)


## The body as a strip, 4 dither blocks wide and `STRIP_H` tall, built once.
static func depth_strip() -> ImageTexture:
	if _strip == null:
		var img := Image.create(4 * GRAIN, STRIP_H, false, Image.FORMAT_RGBA8)
		for y in STRIP_H:
			for x in 4 * GRAIN:
				img.set_pixel(x, y, level_color(depth_level(x, y)))
		_strip = ImageTexture.create_from_image(img)
	return _strip


## How bright the caustic light is `depth` px below the surface.
static func caustic_alpha(depth: float) -> float:
	return CAUSTIC_ALPHA * clampf(1.0 - depth / CAUSTIC_DEPTH, 0.0, 1.0)


func _draw_body() -> void:
	var tex := depth_strip()
	for i in _runs.size():
		var r := _runs[i]
		var d := _run_depth[i]
		if d >= STRIP_H - Room.TILE:
			_body.draw_rect(r, level_color(LEVELS - 1))
		else:
			_body.draw_texture_rect_region(tex, r, Rect2(posmod(int(r.position.x), 4 * GRAIN), d, r.size.x, r.size.y))


## Horizontal runs of water cells per row, and the cells at the surface (open above).
func _build_runs() -> void:
	_runs.clear()
	_run_depth.clear()
	_surface.clear()
	var rows := {}
	# Depth counts from the pool's top, not from a rock overhead, so the water
	# under a pillar is as deep as the water beside it.
	var top := INF
	for c: Vector2i in cells:
		top = minf(top, c.y * Room.TILE)
	for c: Vector2i in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
		if not cells.has(c + Vector2i.UP) and not roofed.has(c):
			_surface.append(Rect2(Vector2(c * Room.TILE), Vector2(Room.TILE, Room.TILE)))
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			var x: int = xs[i] if i < xs.size() else -999
			if x != prev + 1:
				var run := Rect2(start * Room.TILE, y * Room.TILE, (prev - start + 1) * Room.TILE, Room.TILE)
				_runs.append(run)
				_run_depth.append(run.position.y - top)
				start = x
			prev = x


## True if the point (room pixels) is in the water.
func has_point(pos: Vector2) -> bool:
	return cells.has(Vector2i(floori(pos.x / Room.TILE), floori(pos.y / Room.TILE)))


## The y (pixels) of the water's surface above the point.
func surface_above(pos: Vector2) -> float:
	var c := Vector2i(floori(pos.x / Room.TILE), floori(pos.y / Room.TILE))
	while cells.has(c + Vector2i.UP):
		c += Vector2i.UP
	return float(c.y * Room.TILE)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	var now := false
	if p != null and not p.dead:
		var mid := p.body_rect().get_center() - global_position
		if has_point(mid):
			now = true
			p.in_water = true
			p.water_surface = surface_above(mid) + global_position.y
		if now != _was_in and absf(p.velocity.y) > SPLASH_SPEED:
			var x := mid.x
			var y := surface_above(mid if now else mid + Vector2(0, Room.TILE * 1.5))
			_splashes.append(Vector3(x, y, 0.0))
			Sfx.play("dive", 0.1, -4.0 if now else -8.0)
	_was_in = now
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i].z += delta
		if _splashes[i].z > 0.6:
			_splashes.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for ri in _runs.size():
		var r := _runs[ri]
		draw_rect(r, Color(WATER, FRONT_ALPHA))
		if _run_depth[ri] >= CAUSTIC_DEPTH:
			continue
		# Caustic light: short wavering bands drifting under the surface, each
		# fading with its own depth.
		var n := int(r.size.x / 24.0) + 1
		for i in n:
			var x := fmod(_t * (10.0 + (i % 3) * 3.0) + i * 29.0 + r.position.y * 0.7, r.size.x)
			var y := roundf(fmod(i * 7.0, 14.0) + sin(_t * 1.7 + i * 1.3))
			var a := caustic_alpha(_run_depth[ri] + y)
			if a <= 0.0:
				continue
			var w := roundf(5.0 + 4.0 * sin(_t * 1.3 + i))
			draw_rect(Rect2(r.position.x + x, r.position.y + y, minf(w, r.size.x - x), 1.0), Color(SURFACE, a))
			if x + w + 3.0 < r.size.x:
				draw_rect(Rect2(r.position.x + x + w, r.position.y + y + 1.0, 3.0, 1.0), Color(SURFACE, a * 0.6))
	for s in _surface:
		# A bright rippling waterline along the top of every open cell.
		for k in 4:
			var x := s.position.x + k * 4.0
			var lift := roundf(sin(_t * 3.0 + x * 0.15) * 1.0)
			draw_rect(Rect2(x, s.position.y + lift, 4.0, 2.0), Color(SURFACE, 0.75))
		draw_rect(Rect2(s.position + Vector2(0, 3), Vector2(s.size.x, 2.0)), Color(SURFACE, 0.18))
	# Bubbles rising from fixed spots in the deep water.
	var count := mini(cells.size() / 12, 40)
	var keys := cells.keys()
	for i in count:
		var c: Vector2i = keys[(i * 97) % keys.size()]
		if cells.has(c + Vector2i.UP + Vector2i.UP):
			var x := c.x * Room.TILE + 8.0 + sin(_t * 2.0 + i) * 2.0
			var y := c.y * Room.TILE + 16.0 - fmod(_t * 18.0 + i * 13.0, 32.0)
			draw_rect(Rect2(x, y, 2.0, 2.0), Color(BUBBLE, 0.5))
	for sp in _splashes:
		var k := sp.z / 0.6
		for side in [-1.0, 1.0]:
			for j in 3:
				var dx: float = side * (4.0 + j * 5.0) * (0.3 + k)
				var dy := -(14.0 - j * 3.0) * sin(k * PI)
				draw_rect(Rect2(sp.x + dx, sp.y + dy, 2.0, 2.0), Color(BUBBLE, 1.0 - k))
