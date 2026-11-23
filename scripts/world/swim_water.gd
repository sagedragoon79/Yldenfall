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
##
## Pass 620 (design bible 12.97): the surface is a swell, not a ruled line. A
## thin crest rides it with a sheen under it, glints run along it under open
## air, and it is dim under a roof. Where it meets stone it laps (`WaterEdge`),
## and stone that stands in the water is darkened at its faces. The body has
## `LEVELS` 8 steps (it was 5), so its bands are half as far apart in tone.

const WATER := Color("1f6a78")
const SURFACE := Color("8ae8e0")
const BUBBLE := Color("c8fff6")
## The body just under the surface and at full depth (behind the actors).
const SHALLOW := Color(0.18, 0.54, 0.6, 0.2)
const ABYSS := Color(0.03, 0.12, 0.2, 0.82)
## Depth (px below the surface) where the body reaches `ABYSS`.
const DEPTH_FULL := 144.0
## Quantised steps of the body's depth.
const LEVELS := 8
## Dither block size, world px.
const GRAIN := 2
## Height of the body's strip texture; deeper rows draw flat `ABYSS`.
const STRIP_H := 160
## Opacity of the tint drawn in front of the bodies in the water.
const FRONT_ALPHA := 0.2
## Caustic light: its opacity at the surface, and the depth where it is gone.
const CAUSTIC_ALPHA := 0.3
const CAUSTIC_DEPTH := 56.0
## The surface. Width (px) of one piece of the crest.
const CREST_STEP := 2
## The sheen under the crest: `[rows, alpha]`, from the crest down.
const SHEEN: Array = [[1, 0.32], [2, 0.17], [3, 0.08]]
## The crest's alpha under a roof, and how much of the sheen is left there.
const CREST_SHADE := 0.36
const SHEEN_SHADE := 0.45
## A surface cell is under a roof if stone hangs within this many tiles over it.
const ROOF_REACH := 3
## The tone stone takes where it stands in the water.
const SUNK_TONE := Color(0.05, 0.2, 0.27)
## Speed (px/s) a body must hit the surface at to throw spray.
const SPLASH_SPEED := 140.0
## The deep water mirrors what stands over it, as the still tide does (pass 640,
## design bible 12.116; `Tide.REFLECT_SHADER`). Its alpha just under the line;
## it fades to nothing at the floor of the surface row. Under a roof the mirror
## is dimmer (there is less light above to show), by REFLECT_SHADE.
const REFLECT_ALPHA := 0.6
const REFLECT_SHADE := 0.5
## Pass 641 (design bible 12.117): the mirror reaches two rows down where the
## water goes on under the surface row (one where it does not), so a pier's
## image hangs as deep as its first course.
const REFLECT_ROWS := 2

## Pass 641 (design bible 12.117): stone that stands in the water (water on both
## sides of it along its row) is drowned. It takes the body's tone by depth, from
## DROWN_MIN just under the surface to DROWN_MAX at DEPTH_FULL, in DROWN_STEP-px
## bands, so a pier fades into the water instead of standing on it as a cut-out.
const DROWN_MIN := 0.22
const DROWN_MAX := 0.62
const DROWN_STEP := 4
## Everything under the surface wavers: each pixel row slides sideways by up to
## WAVER whole pixels on a slow wave (WAVER_PACE rad/s, WAVER_FREQ rad per row).
## The top WAVER_STILL px under the pool's top hold still, under the mirror.
const WAVER := 1.0
const WAVER_PACE := 1.1
const WAVER_FREQ := 0.32
const WAVER_STILL := 3
const WAVER_SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
// Depth (px) of this rect's top under the pool's top, and the water's clock.
uniform float top = 0.0;
uniform float time = 0.0;
uniform float waver = 1.0;
uniform float pace = 1.1;
uniform float freq = 0.32;
uniform float still = 3.0;
uniform vec2 size = vec2(16.0, 16.0);
varying vec2 step_uv;
void vertex() {
	mat4 m = SCREEN_MATRIX * CANVAS_MATRIX * MODEL_MATRIX;
	vec4 a = m * vec4(VERTEX, 0.0, 1.0);
	vec4 b = m * vec4(VERTEX + vec2(1.0, 1.0), 0.0, 1.0);
	step_uv = abs(b.xy - a.xy) * 0.5;
}
void fragment() {
	float d = top + floor(UV.y * size.y);
	float s = d >= still ? floor(sin(time * pace + d * freq) * waver + 0.5) : 0.0;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + vec2(s, 0.0) * step_uv).rgb, 1.0);
}"

## The water's cells (tiles) -> true.
var cells := {}
## Cells with rock right above them: no waterline is drawn there.
var roofed := {}
## The room's square stone (tiles) -> true: what the water laps and darkens.
var stone := {}
## Surface cells with a roof within `ROOF_REACH` over them.
var shaded := {}
## Each bank of the surface (see `WaterEdge.banks`).
var banks: Array = []
## The stone's darkened bands (see `WaterEdge.sunk`).
var sunk: Array = []

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
## The mirror laid over each run of surface cells (see `Tide.REFLECT_SHADER`).
var reflections: Array[ColorRect] = []
## Stone standing in the water (tiles) -> its depth (px) under the pool's top.
var drowned := {}
## The drowned cells that are the bed's course (their tone fades down the tile).
var bed := {}
## The waver laid over each row of water and drowned stone (see `WAVER_SHADER`).
var wavers: Array[ColorRect] = []
## The pool's top (px).
var _top := 0.0


func _ready() -> void:
	z_index = 1
	_build_runs()
	_body = Node2D.new()
	_body.name = "Body"
	_body.z_index = -2   # relative to this node's 1: under the actors, with the decor
	_body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_body.draw.connect(_draw_body)
	add_child(_body)
	_build_edges()
	# The stone's part and the drowned stone's tone are drawn once, behind this
	# node's front and before the waver reads the screen, so they waver with the
	# stone under them.
	var edge := Node2D.new()
	edge.name = "Stone"
	edge.show_behind_parent = true
	edge.draw.connect(_draw_stone.bind(edge))
	add_child(edge)
	var drown := Node2D.new()
	drown.name = "Drowned"
	drown.show_behind_parent = true
	drown.draw.connect(_draw_drowned.bind(drown))
	add_child(drown)
	_lay_wavers()
	_lay_reflections()


## The runs of surface cells, row by row: each [row, first column, last column,
## shaded] (tiles). A run breaks where the cells stop or where the roof starts
## or ends, so a run is lit or shaded all along.
func surface_runs() -> Array:
	var top: Array = surface_cells()
	top.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	for c: Vector2i in top:
		var dim := shaded.has(c)
		if out.is_empty() or int(out[-1][0]) != c.y or int(out[-1][2]) != c.x - 1 or bool(out[-1][3]) != dim:
			out.append([c.y, c.x, c.x, dim])
		else:
			out[-1][2] = c.x
	return out


func _lay_reflections() -> void:
	for r in reflections:
		r.queue_free()
	reflections.clear()
	var shader := Shader.new()
	shader.code = Tide.REFLECT_SHADER
	for run: Array in surface_runs():
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Drawn before this node's own front: the crest, its sheen and the caustics stay on top.
		rect.show_behind_parent = true
		rect.position = Vector2(int(run[1]) * Room.TILE, int(run[0]) * Room.TILE + Tide.REFLECT_FROM)
		rect.size = Vector2((int(run[2]) - int(run[1]) + 1) * Room.TILE, mirror_rows(run) * Room.TILE - Tide.REFLECT_FROM)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("top", float(Tide.REFLECT_FROM))
		mat.set_shader_parameter("depth", rect.size.y)
		mat.set_shader_parameter("alpha", REFLECT_ALPHA * (REFLECT_SHADE if bool(run[3]) else 1.0))
		mat.set_shader_parameter("tint", WATER)
		mat.set_shader_parameter("tint_mix", Tide.REFLECT_MIX)
		mat.set_shader_parameter("still", float(Tide.REFLECT_STILL))
		mat.set_shader_parameter("sway", Tide.REFLECT_SWAY)
		mat.set_shader_parameter("pace", Tide.REFLECT_PACE)
		rect.material = mat
		add_child(rect)
		reflections.append(rect)


## How many rows (tiles) a run's mirror reaches down: REFLECT_ROWS where the
## water goes on under every cell of the run, else fewer.
func mirror_rows(run: Array) -> int:
	for k in range(1, REFLECT_ROWS):
		for c in range(int(run[1]), int(run[2]) + 1):
			if not cells.has(Vector2i(c, int(run[0]) + k)):
				return k
	return REFLECT_ROWS


## Stone in the water: solid cells that fill a gap in a row of water (water on
## both sides along the row), and the first course of the bed and the walls.
## Each maps to its depth (px) under the pool's top.
func find_drowned() -> Dictionary:
	var out := {}
	var rows := {}
	for c: Vector2i in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		for i in xs.size() - 1:
			var a: int = xs[i]
			var b: int = xs[i + 1]
			if b - a <= 1:
				continue
			var all_solid := true
			for x in range(a + 1, b):
				if not _solid(Vector2i(x, y)):
					all_solid = false
					break
			if all_solid:
				for x in range(a + 1, b):
					out[Vector2i(x, y)] = float(y * Room.TILE) - _top
	# The shore's first course: the bed under the water (and under stone standing
	# in it) and a wall's face beside it are under the surface too.
	# The bed's course fades out down the tile (it meets dry stone under it).
	bed.clear()
	for c: Vector2i in cells:
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + dir
			if _solid(n) and not out.has(n):
				out[n] = float(n.y * Room.TILE) - _top
	for c: Vector2i in out.keys() + cells.keys():
		var under: Vector2i = c + Vector2i.DOWN
		if _solid(under) and not out.has(under):
			out[under] = float(under.y * Room.TILE) - _top
			bed[under] = true
	return out


## The drowned tone's alpha `depth` px under the pool's top.
static func drown_alpha(depth: float) -> float:
	return lerpf(DROWN_MIN, DROWN_MAX, sqrt(clampf(depth / DEPTH_FULL, 0.0, 1.0)))


func _draw_drowned(ci: Node2D) -> void:
	for c: Vector2i in drowned:
		var d: float = drowned[c]
		var y := 0
		while y < Room.TILE:
			var a := drown_alpha(d + y)
			if bed.has(c):
				a *= 1.0 - float(y) / float(Room.TILE)
			ci.draw_rect(Rect2(c.x * Room.TILE, c.y * Room.TILE + y, Room.TILE, DROWN_STEP), Color(SUNK_TONE, a))
			y += DROWN_STEP


## The rows the waver covers: each [row, first column, last column] (tiles),
## water and drowned stone together.
func waver_runs() -> Array:
	var all := {}
	for c: Vector2i in cells:
		all[c] = true
	for c: Vector2i in drowned:
		all[c] = true
	var keys := all.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	for c: Vector2i in keys:
		if out.is_empty() or int(out[-1][0]) != c.y or int(out[-1][2]) != c.x - 1:
			out.append([c.y, c.x, c.x])
		else:
			out[-1][2] = c.x
	return out


func _lay_wavers() -> void:
	for r in wavers:
		r.queue_free()
	wavers.clear()
	var shader := Shader.new()
	shader.code = WAVER_SHADER
	for run: Array in waver_runs():
		var rect := ColorRect.new()
		rect.name = "Waver"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.show_behind_parent = true
		rect.position = Vector2(int(run[1]) * Room.TILE, int(run[0]) * Room.TILE)
		rect.size = Vector2((int(run[2]) - int(run[1]) + 1) * Room.TILE, Room.TILE)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("top", rect.position.y - _top)
		mat.set_shader_parameter("size", rect.size)
		mat.set_shader_parameter("waver", WAVER)
		mat.set_shader_parameter("pace", WAVER_PACE)
		mat.set_shader_parameter("freq", WAVER_FREQ)
		mat.set_shader_parameter("still", float(WAVER_STILL))
		rect.material = mat
		add_child(rect)
		wavers.append(rect)


## The row slide (whole px) the waver gives `d` px under the pool's top at `t`
## (the shader's own sum, for tests).
static func waver_shift(d: float, t: float) -> int:
	if d < WAVER_STILL:
		return 0
	return floori(sin(t * WAVER_PACE + d * WAVER_FREQ) * WAVER + 0.5)


## The crest's lift (px, negative is up) at `x` (px) and time `t`: two swells
## crossing, so the line is never ruled and never jumps more than a pixel
## between neighbouring pieces.
static func crest_lift(x: float, t: float) -> int:
	return roundi(sin(t * 2.2 + x * 0.09) * 0.8 + sin(t * 1.3 - x * 0.23) * 0.5)


## True where a glint of light runs along the crest.
static func glint(x: float, t: float) -> bool:
	return sin(x * 0.31 - t * 1.6) + sin(x * 0.11 + t * 0.9) > 1.5


## The crest's alpha at `x`: it thins and thickens along its length, a glint is
## whole, and under a roof it is dim and carries no glint.
static func crest_alpha(x: float, t: float, in_shade: bool) -> float:
	if in_shade:
		return CREST_SHADE
	if glint(x, t):
		return 1.0
	return 0.56 + 0.2 * sin(x * 0.17 + t * 0.8)


func _solid(c: Vector2i) -> bool:
	return stone.has(c) and not cells.has(c)


## The surface cells (tiles), from `_surface`.
func surface_cells() -> Array:
	var out: Array = []
	for s in _surface:
		out.append(Vector2i(s.position / float(Room.TILE)))
	return out


func _build_edges() -> void:
	shaded.clear()
	var top: Array = surface_cells()
	for c: Vector2i in top:
		for k in range(1, ROOF_REACH + 1):
			if _solid(c + Vector2i(0, -k)):
				shaded[c] = true
				break
	banks = WaterEdge.banks(top, _solid)
	sunk = WaterEdge.sunk(cells, _solid, Room.TILE)
	drowned = find_drowned()


func _draw_stone(edge: Node2D) -> void:
	var tone := SUNK_TONE
	for band: Array in sunk:
		edge.draw_rect(band[0], Color(tone, WaterEdge.SUNK_STEPS[int(band[1])]))
	for bank: Array in banks:
		if bank[2]:
			WaterEdge.draw_damp(edge, bank_face(bank), int(bank[1]))


## A bank's face on the surface (px).
func bank_face(bank: Array) -> Vector2:
	var c: Vector2i = bank[0]
	return Vector2((c.x + (1 if int(bank[1]) > 0 else 0)) * Room.TILE, c.y * Room.TILE)


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
	_top = top if top < INF else 0.0
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
	for r in reflections:
		(r.material as ShaderMaterial).set_shader_parameter("time", _t)
	for r in wavers:
		(r.material as ShaderMaterial).set_shader_parameter("time", _t)
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
		# The crest rides the swell, with a sheen under it; glints under open air.
		var dim: bool = shaded.has(Vector2i(s.position / float(Room.TILE)))
		var k := 0
		while k < Room.TILE:
			var x := s.position.x + k
			var y := s.position.y + crest_lift(x, _t)
			var lit := not dim and glint(x, _t)
			draw_rect(Rect2(x, y, CREST_STEP, 1.0), Color(BUBBLE if lit else SURFACE, crest_alpha(x, _t, dim)))
			var row := 1.0
			for band: Array in SHEEN:
				draw_rect(Rect2(x, y + row, CREST_STEP, float(band[0])), Color(SURFACE, float(band[1]) * (SHEEN_SHADE if dim else 1.0)))
				row += float(band[0])
			k += CREST_STEP
	# Where the surface meets stone, it laps.
	for i in banks.size():
		var bank: Array = banks[i]
		WaterEdge.draw_lap(self, bank_face(bank), int(bank[1]), _t, i * 5 + int(bank[0].x))
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
