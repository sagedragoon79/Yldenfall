class_name Tide
extends Node2D
## The standing water of Vorrhallow's drowned halls (design bible 4.4, `tide:`
## header). Until Thane Vorrund is at rest it stands a tile deep on the floors
## and fills the pits below them: a still, dark water you wade through (your
## steps slosh), drawn translucent in front of what stands in it. The spikes
## under it keep their steel rim: the water draws it again over itself (12.49). Once he is at rest Vorrhallow drains, and all that is left
## is the tide mark where the surface stood, and silt on the floor.
##
## Pass 550: whatever wades in it (the hero, a foe) breaks the surface. A bright
## waterline crosses the body where the water meets it, and ripples spread from
## it along the surface, more often while it moves. The water itself is lighter
## just under the surface and darkens toward the floor in dithered steps.
##
## Pass 658 (design bible 12.134): the water clears over whatever wades in it. The
## body and the mirror over a wader's box (and CLEAR_PAD past it) are drawn at CLEAR
## of their strength, with a CHUNK of half strength either side, so a foe's legs show
## through the band instead of sinking under it. The line across it stays bright.

const DRAIN_FLAG := "boss:thane_vorrund"
const WATER := Color(0.16, 0.38, 0.44, 0.55)
const DEEP := Color(0.06, 0.14, 0.2, 0.35)
const SURFACE := Color("a8e4e8")
const MARK := Color(0.3, 0.55, 0.55, 0.6)
const SILT := Color(0.32, 0.36, 0.3, 0.6)

## The water just under the surface, and at the floor (the body's two ends).
const SHALLOW := Color(0.22, 0.5, 0.54, 0.45)
const FLOOR := Color(0.07, 0.2, 0.27, 0.68)
## Dither block size (px) of the body's steps, as the swim water's (pass 548).
const GRAIN := 2
## Tone steps from SHALLOW down to FLOOR.
const LEVELS := 4

## A wading body's ripples: one every WAKE_STILL seconds standing, every
## WAKE_MOVING while it moves faster than MOVING_SPEED (px/s).
const WAKE_STILL := 1.1
const WAKE_MOVING := 0.35
const MOVING_SPEED := 20.0
## A ripple's life (s) and how far (px) past the body's edge it spreads.
const RING_LIFE := 1.3
const RING_SPREAD := 30.0
const RING_ALPHA := 0.75
const MAX_RINGS := 48

## Over a wader the water is this much of its usual strength (body and mirror), from
## its box's edge CLEAR_PAD px out, in CHUNK px columns (the dither's period, so its
## pattern keeps its phase); one more CHUNK either side is half way back. At most
## MAX_CLEAR waders are cleared at once.
const CLEAR := 0.2
const CLEAR_PAD := 2.0
const CHUNK := 4
const MAX_CLEAR := 8

## Round the legs (pass 666, design bible 12.143). The water climbs a wader: at
## each edge of the body a meniscus COLLAR px high, its foot BOW_FOOT px wide on
## the line and a pixel at its top against the body, and in front of a moving one
## a bow wave BOW px long, a pixel over the line, thinning out ahead.
const COLLAR := 2
const COLLAR_FOOT := 3
const COLLAR_ALPHA := 0.8
const BOW := 6
## (The spray a moving wader kicks is the hero's own step dust: `Dust`, "wade".)
## A moving wader stirs silt off the floor: a puff every SILT_EVERY seconds at its feet that
## rises SILT_RISE px and drifts back SILT_DRIFT px over SILT_LIFE seconds, fading.
const SILT_EVERY := 0.2
const SILT_RISE := 6.0
const SILT_DRIFT := 6.0
const SILT_LIFE := 1.0
const SILT_ALPHA := 0.55
const SILT_PUFF := Color("8a9a86")
const MAX_SILT := 24

## Spikes under the water keep their steel rim (bible 12.49): the water is drawn in
## front of them and would dim it, so it draws the rim again over itself at this alpha.
const SUNK_RIM := 0.9
## The pale water lying over a sunk cluster, from its tips down: what the dark
## teeth stand against. Alpha at the tips' row, fading to nothing at the floor.
const SUNK_GLOW := 0.2

## The still water mirrors what stands over it (pass 639, design bible 12.115): the
## world above the surface, upside down and dimmed, laid over the body in runs of
## the surface row. REFLECT_FROM px under the surface line it starts (the line,
## its glints and the ripples stay on top); its alpha is REFLECT_ALPHA there and
## fades to nothing at the floor of the row. Past REFLECT_STILL px down a row
## sways sideways by up to REFLECT_SWAY whole pixels, slower than the lap.
const REFLECT_FROM := 2
const REFLECT_ALPHA := 0.5
const REFLECT_TINT := Color("3d8a94")
const REFLECT_MIX := 0.22
const REFLECT_STILL := 4
const REFLECT_SWAY := 1.0
const REFLECT_PACE := 1.4

const REFLECT_SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
// This rect's first row under the surface line (px) and its depth, and the tide's clock.
uniform float top = 2.0;
uniform float depth = 14.0;
uniform float time = 0.0;
uniform float alpha = 0.42;
uniform vec4 tint : source_color = vec4(0.24, 0.54, 0.58, 1.0);
uniform float tint_mix = 0.3;
uniform float still = 4.0;
uniform float sway = 1.0;
uniform float pace = 1.4;
// Pass 658: the water clears over a wader (Tide.CLEAR): each span [x, y] in this
// rect's parent's px, read in 4 px columns; one column either side is half way.
uniform vec4 clear_spans[8];
uniform int clear_n = 0;
uniform float clear_k = 0.35;
uniform float left = 0.0;
uniform float width = 1.0;
// How far one local pixel down and one across move in screen UV.
varying vec2 step_uv;
void vertex() {
	mat4 m = SCREEN_MATRIX * CANVAS_MATRIX * MODEL_MATRIX;
	vec4 a = m * vec4(VERTEX, 0.0, 1.0);
	vec4 b = m * vec4(VERTEX + vec2(1.0, 1.0), 0.0, 1.0);
	step_uv = abs(b.xy - a.xy) * 0.5;
}
void fragment() {
	// The row under the surface line, in whole pixels (0 is the line's own row).
	float k = floor(top + UV.y * depth);
	// Its mirror stands k + 1 px above the line: 2k + 1 rows up from here.
	float up = 2.0 * k + 1.0;
	float s = k >= still ? floor(sin(time * pace + k * 0.9) * sway + 0.5) : 0.0;
	vec4 above = texture(screen_tex, SCREEN_UV + vec2(s, -up) * step_uv);
	float fade = clamp(1.0 - (k - top) / depth, 0.0, 1.0);
	float lx = left + floor(UV.x * width / 4.0) * 4.0 + 2.0;
	float f = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i < clear_n) {
			float d = max(clear_spans[i].x - lx, lx - clear_spans[i].y);
			f = min(f, d <= 0.0 ? clear_k : (d < 4.0 ? (1.0 + clear_k) * 0.5 : 1.0));
		}
	}
	COLOR = vec4(mix(above.rgb, tint.rgb, tint_mix), alpha * fade * f);
}"

## The lap at a bank (12.97): still water laps slower and fainter than deep water.
const LAP_PACE := 0.6
const LAP_ALPHA := 0.8

const _BAYER := [[0, 2], [3, 1]]

## The water's cells (tiles) -> true.
var cells := {}
## The surface row (tiles).
var row := 0
## The room's square stone (tiles) -> true: what the water laps and darkens (12.97).
var stone := {}
## Each bank of the surface, and the stone's darkened bands (see `WaterEdge`).
var banks: Array = []
var sunk: Array = []
## Each body wading this frame: [x (local px), half width (px), its velocity's x (px/s)].
var wakes: Array = []
## Each puff of silt off the floor: [start (local px), side it drifts (-1 or 1), age (s)].
var silt: Array = []
## Each spreading ripple: [x, half width of what made it, age (s)].
var rings: Array = []
## Where the water clears this frame: one Vector2(first px, end px) per wader (local).
var clear_spans: Array[Vector2] = []

var _t := 0.0
## The reflection laid over each run of the surface row (see REFLECT_SHADER).
var reflections: Array[ColorRect] = []
## Columns (tiles) the surface spans, sorted.
var _cols: Array[int] = []
## The same columns as a set.
var _col_set := {}
## Each column's lowest water cell (tiles), where the silt settles.
var _floor := {}
## Instance id -> seconds to that body's next ripple.
var _clock := {}
## Instance id -> seconds to that body's next puff of silt.
var _silt_clock := {}
var _strip: ImageTexture
## Each spike cluster standing in the water: its bottom centre (local px).
var _sunk: Array[Vector2] = []
## The room's child count when `_sunk` was last gathered (a pit can open later).
var _sunk_at := -1


func _ready() -> void:
	# The water stands in front of what wades in it; the mark it left is on the walls behind.
	z_index = -1 if drained() else 1
	for c: Vector2i in cells:
		if c.y == row:
			_cols.append(c.x)
			_col_set[c.x] = true
		_floor[c.x] = maxi(int(_floor.get(c.x, c.y)), c.y)
	_cols.sort()
	_strip = body_strip()
	var top: Array = []
	for x in _cols:
		top.append(Vector2i(x, row))
	var solid := func(c: Vector2i) -> bool: return stone.has(c) and not cells.has(c)
	banks = WaterEdge.banks(top, solid)
	sunk = WaterEdge.sunk(cells, solid, Room.TILE)
	_lay_reflections()


## The runs of the surface row (each [first column, last column], tiles).
func surface_runs() -> Array:
	var out: Array = []
	for x in _cols:
		if out.is_empty() or int(out[-1][1]) != x - 1:
			out.append([x, x])
		else:
			out[-1][1] = x
	return out


## How strongly the mirror shows `k` px under the surface line (0 at the line).
static func reflect_alpha(k: int) -> float:
	if k < REFLECT_FROM:
		return 0.0
	var depth := float(Room.TILE - REFLECT_FROM)
	return REFLECT_ALPHA * clampf(1.0 - float(k - REFLECT_FROM) / depth, 0.0, 1.0)


func _lay_reflections() -> void:
	for r in reflections:
		r.queue_free()
	reflections.clear()
	if drained():
		return
	var shader := Shader.new()
	shader.code = REFLECT_SHADER
	var y := surface_y()
	for run: Array in surface_runs():
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(int(run[0]) * Room.TILE, y + REFLECT_FROM)
		rect.size = Vector2((int(run[1]) - int(run[0]) + 1) * Room.TILE, Room.TILE - REFLECT_FROM)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("top", float(REFLECT_FROM))
		mat.set_shader_parameter("depth", rect.size.y)
		mat.set_shader_parameter("alpha", REFLECT_ALPHA)
		mat.set_shader_parameter("tint", REFLECT_TINT)
		mat.set_shader_parameter("tint_mix", REFLECT_MIX)
		mat.set_shader_parameter("still", float(REFLECT_STILL))
		mat.set_shader_parameter("sway", REFLECT_SWAY)
		mat.set_shader_parameter("pace", REFLECT_PACE)
		mat.set_shader_parameter("clear_k", CLEAR)
		mat.set_shader_parameter("left", rect.position.x)
		mat.set_shader_parameter("width", rect.size.x)
		rect.material = mat
		add_child(rect)
		reflections.append(rect)


## True once Thane Vorrund is at rest and the water has gone.
func drained() -> bool:
	return GameState.flag(DRAIN_FLAG)


## True if the point (room pixels) is in standing water.
func has_point(pos: Vector2) -> bool:
	return not drained() and cells.has(Vector2i(floori(pos.x / Room.TILE), floori(pos.y / Room.TILE)))


## A bank's face on the surface (local px).
func bank_face(bank: Array) -> Vector2:
	var c: Vector2i = bank[0]
	return Vector2((c.x + (1 if int(bank[1]) > 0 else 0)) * Room.TILE, c.y * Room.TILE)


## The surface's height (local px).
func surface_y() -> float:
	return float(row * Room.TILE)


## The step (0 shallowest, LEVELS - 1 deepest) of the body at column `x`, `depth`
## px under the surface: an ordered dither between steps, in GRAIN blocks.
static func depth_level(x: int, depth: int) -> int:
	var f := clampf(float(depth) / float(Room.TILE - 1), 0.0, 1.0) * float(LEVELS - 1)
	var base := floori(f)
	var b: int = _BAYER[(depth / GRAIN) % 2][(x / GRAIN) % 2]
	var level := base + (1 if (f - float(base)) * 4.0 > float(b) + 0.5 else 0)
	return mini(level, LEVELS - 1)


static func level_color(level: int) -> Color:
	return SHALLOW.lerp(FLOOR, float(level) / float(LEVELS - 1))


## The water under the surface row, down a pit: one flat, dark tone.
static func pit_color() -> Color:
	return DEEP.lerp(FLOOR, 0.6)


## A sunk spike's rim as it shows: the steel drawn over the pit's water.
static func sunk_rim_color() -> Color:
	var under := Spikes.RIM.lerp(Color(pit_color(), 1.0), pit_color().a)
	return under.lerp(Spikes.RIM, SUNK_RIM)


## One tile of the surface row's body, as a texture (a 4 px wide dither period).
static func body_strip() -> ImageTexture:
	var img := Image.create(2 * GRAIN, Room.TILE, false, Image.FORMAT_RGBA8)
	for y in Room.TILE:
		for x in 2 * GRAIN:
			img.set_pixel(x, y, level_color(depth_level(x, y)))
	return ImageTexture.create_from_image(img)


## True if a body whose box is `rect` stands in the surface at `y`.
static func wades(rect: Rect2, y: float) -> bool:
	return rect.position.y < y and rect.end.y > y


## The span (local px, snapped out to whole CHUNKs) the water clears over a body
## whose middle is at `x` and half as wide as `half`.
static func clear_span(x: float, half: float) -> Vector2:
	var a := floorf((x - half - CLEAR_PAD) / CHUNK) * CHUNK
	var b := ceilf((x + half + CLEAR_PAD) / CHUNK) * CHUNK
	return Vector2(a, b)


## How strong the water is (1 its usual) in the CHUNK column whose middle is at `px`.
static func clarity_at(px: float, spans: Array[Vector2]) -> float:
	var f := 1.0
	for s in spans:
		var d := maxf(s.x - px, px - s.y)
		f = minf(f, CLEAR if d <= 0.0 else ((1.0 + CLEAR) * 0.5 if d < CHUNK else 1.0))
	return f


## How far from its middle a ripple has spread at `age` (s).
static func ring_reach(half_w: float, age: float) -> float:
	var k := clampf(age / RING_LIFE, 0.0, 1.0)
	return half_w + 2.0 + RING_SPREAD * (1.0 - (1.0 - k) * (1.0 - k))


static func ring_alpha(age: float) -> float:
	return RING_ALPHA * clampf(1.0 - age / RING_LIFE, 0.0, 1.0)


## Where a puff of silt is at `age` (s), from `start`, drifting to `side`.
static func silt_at(start: Vector2, side: float, age: float) -> Vector2:
	var k := clampf(age / SILT_LIFE, 0.0, 1.0)
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	return (start + Vector2(side * SILT_DRIFT * e, -SILT_RISE * e)).round()


static func silt_alpha(age: float) -> float:
	return SILT_ALPHA * clampf(1.0 - age / SILT_LIFE, 0.0, 1.0)


## The water climbing a wader at `x`, `half` wide, on the surface at `y`, moving
## at `vx` (px/s): [Rect2, alpha] pieces, local px. Each edge of the body takes a
## meniscus: COLLAR_FOOT px on the row over the line, narrowing a pixel a row up,
## against the body. A moving body pushes a bow wave BOW px long out in front, a
## pixel over the line, fading out ahead.
static func collar(x: float, half: float, y: float, vx: float) -> Array:
	var x0 := roundf(x - half)
	var x1 := roundf(x + half)
	var out: Array = []
	for k in COLLAR:
		var w := float(COLLAR_FOOT - k)
		var a := COLLAR_ALPHA * (1.0 - 0.3 * k)
		out.append([Rect2(x0 - w, y - 1.0 - k, w, 1.0), a])
		out.append([Rect2(x1, y - 1.0 - k, w, 1.0), a])
	if absf(vx) > MOVING_SPEED:
		var side := signf(vx)
		var lead := x1 + float(COLLAR_FOOT) if side > 0.0 else x0 - float(COLLAR_FOOT)
		for i in BOW / 2:
			var at := lead + side * float(i * 2) - (0.0 if side > 0.0 else 2.0)
			out.append([Rect2(at, y - 1.0, 2.0, 1.0), COLLAR_ALPHA * (1.0 - float(i) / float(BOW / 2))])
	return out


## A body's box (global px) from its first rectangle or capsule shape, or an empty one.
static func body_rect(body: Node2D) -> Rect2:
	for c in body.get_children():
		if c is CollisionShape2D and c.shape != null and not c.disabled:
			var size := Vector2.ZERO
			if c.shape is RectangleShape2D:
				size = (c.shape as RectangleShape2D).size
			elif c.shape is CapsuleShape2D:
				var cap := c.shape as CapsuleShape2D
				size = Vector2(cap.radius * 2.0, cap.height)
			if size != Vector2.ZERO:
				return Rect2((c as CollisionShape2D).global_position - size * 0.5, size)
	return Rect2()


func _process(delta: float) -> void:
	if drained():
		wakes.clear()
		rings.clear()
		silt.clear()
		clear_spans.clear()
		if not reflections.is_empty():
			_lay_reflections()
		return
	_t += delta
	_wake(delta)
	var spans := PackedVector4Array()
	for s in clear_spans:
		spans.append(Vector4(s.x, s.y, 0.0, 0.0))
	while spans.size() < MAX_CLEAR:
		spans.append(Vector4.ZERO)
	for r in reflections:
		var mat := r.material as ShaderMaterial
		mat.set_shader_parameter("time", _t)
		mat.set_shader_parameter("clear_spans", spans)
		mat.set_shader_parameter("clear_n", clear_spans.size())
	sunk_spikes()
	queue_redraw()


## Finds what wades this frame and lets each body's ripples go.
func _wake(delta: float) -> void:
	wakes.clear()
	clear_spans.clear()
	var y := surface_y()
	var seen := {}
	var bodies: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemy")
	for body in bodies:
		if not (body is Node2D) or not body.is_visible_in_tree():
			continue
		var g := body_rect(body)
		if g.size == Vector2.ZERO:
			continue
		var r := Rect2(to_local(g.position), g.size)
		var col := floori(r.get_center().x / Room.TILE)
		if not _col_set.has(col) or not wades(r, y):
			continue
		var x := r.get_center().x
		var half := r.size.x * 0.5
		var speed_x := (body as CharacterBody2D).velocity.x if body is CharacterBody2D else 0.0
		wakes.append([x, half, speed_x])
		if clear_spans.size() < MAX_CLEAR:
			clear_spans.append(clear_span(x, half))
		var id: int = body.get_instance_id()
		seen[id] = true
		var speed := absf((body as CharacterBody2D).velocity.x) if body is CharacterBody2D else 0.0
		var period := WAKE_MOVING if speed > MOVING_SPEED else WAKE_STILL
		var left: float = float(_clock.get(id, 0.0)) - delta
		if left <= 0.0:
			if rings.size() < MAX_RINGS:
				rings.append([x, half, 0.0])
			left = period
		_clock[id] = minf(left, period)
		# A moving wader stirs the floor's silt behind its feet.
		if speed > MOVING_SPEED:
			var back := -signf(speed_x)
			var p_left: float = float(_silt_clock.get(id, 0.0)) - delta
			if p_left <= 0.0:
				if silt.size() < MAX_SILT:
					silt.append([Vector2(roundf(x + back * half), y + Room.TILE - 2.0), back, 0.0])
				p_left = SILT_EVERY
			_silt_clock[id] = p_left
	for id in _clock.keys():
		if not seen.has(id):
			_clock.erase(id)
	for id in _silt_clock.keys():
		if not seen.has(id):
			_silt_clock.erase(id)
	var stirred: Array = []
	for p: Array in silt:
		p[2] = float(p[2]) + delta
		if float(p[2]) < SILT_LIFE:
			stirred.append(p)
	silt = stirred
	var live: Array = []
	for ring: Array in rings:
		ring[2] = float(ring[2]) + delta
		if float(ring[2]) < RING_LIFE:
			live.append(ring)
	rings = live


## The spike clusters that stand in the water (their bottom centres, local px),
## gathered again whenever the room gains or loses a child.
func sunk_spikes() -> Array[Vector2]:
	var room := get_parent()
	if room == null or drained():
		_sunk.clear()
		_sunk_at = -1
		return _sunk
	if room.get_child_count() == _sunk_at:
		return _sunk
	_sunk_at = room.get_child_count()
	_sunk.clear()
	for child in room.get_children():
		if child is Spikes:
			var at := to_local((child as Spikes).global_position)
			if cells.has(Vector2i(floori(at.x / Room.TILE), floori((at.y - 1.0) / Room.TILE))):
				_sunk.append(at)
	return _sunk


## One tile of the surface row's body, cleared in CHUNK columns where a wader stands.
func _draw_surface_cell(cell: Rect2) -> void:
	var near := false
	for s in clear_spans:
		near = near or (s.x - CHUNK < cell.end.x and s.y + CHUNK > cell.position.x)
	if not near:
		draw_texture_rect(_strip, cell, true)
		return
	for i in Room.TILE / CHUNK:
		var x := cell.position.x + i * CHUNK
		var f := clarity_at(x + CHUNK * 0.5, clear_spans)
		draw_texture_rect(_strip, Rect2(x, cell.position.y, CHUNK, Room.TILE), true, Color(1, 1, 1, f))


func _draw() -> void:
	var y := surface_y()
	if drained():
		# The tide mark along the pillars and walls, and silt left on the floor.
		for x in _cols:
			draw_rect(Rect2(x * Room.TILE, y, Room.TILE, 2), MARK)
			var fy := float((int(_floor[x]) + 1) * Room.TILE)
			for k in 3:
				var sx := x * Room.TILE + ((x * 7 + k * 5) % Room.TILE)
				draw_rect(Rect2(sx, fy - 1, 2 + (x + k) % 2, 1), SILT)
		return
	for c: Vector2i in cells:
		var cell := Rect2(Vector2(c * Room.TILE), Vector2(Room.TILE, Room.TILE))
		if c.y == row:
			_draw_surface_cell(cell)
		else:
			draw_rect(cell, pit_color())
	# Stone that stands in the water is darkened at its faces, and damp over the waterline.
	var tone := Color(FLOOR.r, FLOOR.g, FLOOR.b)
	for band: Array in sunk:
		draw_rect(band[0], Color(tone, WaterEdge.SUNK_STEPS[int(band[1])]))
	for bank: Array in banks:
		if bank[2]:
			WaterEdge.draw_damp(self, bank_face(bank), int(bank[1]))
	# The silt a wader's feet stir off the floor (12.143).
	for p: Array in silt:
		var at := silt_at(p[0], float(p[1]), float(p[2]))
		var a := silt_alpha(float(p[2]))
		draw_rect(Rect2(at, Vector2(2, 1)), Color(SILT_PUFF, a))
		draw_rect(Rect2(at + Vector2(-float(p[1]) * 2.0, 1.0), Vector2(2, 1)), Color(SILT_PUFF, a * 0.6))
	# What hurts shows through: pale water over each sunk cluster, and its steel rim again.
	for at: Vector2 in _sunk:
		for k in 5:
			draw_rect(Rect2(at.x - 8.0, at.y - 12.0 + k * 2.0, 16.0, 2.0), Color(SURFACE, SUNK_GLOW * (1.0 - k / 5.0)))
		Spikes.draw_rim(self, at, SUNK_RIM, true)
	# The still surface: a pale line that breathes, with slow glints drifting on it.
	for x in _cols:
		var a := 0.55 + 0.25 * sin(_t * 1.3 + x * 0.6)
		draw_rect(Rect2(x * Room.TILE, y, Room.TILE, 1), Color(SURFACE, a))
		if (x + int(_t * 2.0)) % 5 == 0:
			draw_rect(Rect2(x * Room.TILE + 4 + int(_t * 6.0) % 8, y + 2, 3, 1), Color(SURFACE, 0.4))
	# Where the still water meets stone it laps, slower and fainter than the deep water.
	for i in banks.size():
		var bank: Array = banks[i]
		WaterEdge.draw_lap(self, bank_face(bank), int(bank[1]), _t * LAP_PACE, i * 5 + int(bank[0].x), LAP_ALPHA)
	# Ripples: a crest and the trough under it, running out both ways.
	for ring: Array in rings:
		var age := float(ring[2])
		var reach := ring_reach(float(ring[1]), age)
		var a := ring_alpha(age)
		var w := 4.0 if age < RING_LIFE * 0.5 else 3.0
		for side in [-1.0, 1.0]:
			var cx := roundf(float(ring[0]) + side * reach)
			var x0 := cx - (w if side < 0.0 else 0.0)
			draw_rect(Rect2(x0, y - 1, w, 1), Color(SURFACE, a))
			draw_rect(Rect2(x0 + side, y + 1, w, 1), Color(FLOOR, a * 0.6))
	# Where the water meets a body: a bright line across it, lifted a pixel, and its lips.
	for wake: Array in wakes:
		var x0 := roundf(float(wake[0]) - float(wake[1])) - 2.0
		var x1 := roundf(float(wake[0]) + float(wake[1])) + 2.0
		draw_rect(Rect2(x0, y - 1, x1 - x0, 1), Color(SURFACE, 0.9))
		draw_rect(Rect2(x0, y, x1 - x0, 1), Color(SURFACE, 0.55))
		draw_rect(Rect2(x0 - 1, y, 1, 1), Color(SURFACE, 0.6))
		draw_rect(Rect2(x1, y, 1, 1), Color(SURFACE, 0.6))
		# The water climbs the legs, and a moving wader pushes a bow wave (12.143).
		for piece: Array in collar(float(wake[0]), float(wake[1]), y, float(wake[2])):
			draw_rect(piece[0], Color(WaterEdge.FOAM, float(piece[1])))

