class_name Tide
extends Node2D
## The standing water of Vorrhallow's drowned halls (design bible 4.4, `tide:`
## header). Until Thane Vorrund is at rest it stands a tile deep on the floors
## and fills the pits below them: a still, dark water you wade through (your
## steps slosh), drawn translucent in front of what stands in it so the spikes
## under it still show. Once he is at rest Vorrhallow drains, and all that is left
## is the tide mark where the surface stood, and silt on the floor.
##
## Pass 550: whatever wades in it (the hero, a foe) breaks the surface. A bright
## waterline crosses the body where the water meets it, and ripples spread from
## it along the surface, more often while it moves. The water itself is lighter
## just under the surface and darkens toward the floor in dithered steps.

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

const _BAYER := [[0, 2], [3, 1]]

## The water's cells (tiles) -> true.
var cells := {}
## The surface row (tiles).
var row := 0
## Each body wading this frame: [x (local px), half width (px)].
var wakes: Array = []
## Each spreading ripple: [x, half width of what made it, age (s)].
var rings: Array = []

var _t := 0.0
## Columns (tiles) the surface spans, sorted.
var _cols: Array[int] = []
## The same columns as a set.
var _col_set := {}
## Each column's lowest water cell (tiles), where the silt settles.
var _floor := {}
## Instance id -> seconds to that body's next ripple.
var _clock := {}
var _strip: ImageTexture


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


## True once Thane Vorrund is at rest and the water has gone.
func drained() -> bool:
	return GameState.flag(DRAIN_FLAG)


## True if the point (room pixels) is in standing water.
func has_point(pos: Vector2) -> bool:
	return not drained() and cells.has(Vector2i(floori(pos.x / Room.TILE), floori(pos.y / Room.TILE)))


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


## How far from its middle a ripple has spread at `age` (s).
static func ring_reach(half_w: float, age: float) -> float:
	var k := clampf(age / RING_LIFE, 0.0, 1.0)
	return half_w + 2.0 + RING_SPREAD * (1.0 - (1.0 - k) * (1.0 - k))


static func ring_alpha(age: float) -> float:
	return RING_ALPHA * clampf(1.0 - age / RING_LIFE, 0.0, 1.0)


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
		return
	_t += delta
	_wake(delta)
	queue_redraw()


## Finds what wades this frame and lets each body's ripples go.
func _wake(delta: float) -> void:
	wakes.clear()
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
		wakes.append([x, half])
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
	for id in _clock.keys():
		if not seen.has(id):
			_clock.erase(id)
	var live: Array = []
	for ring: Array in rings:
		ring[2] = float(ring[2]) + delta
		if float(ring[2]) < RING_LIFE:
			live.append(ring)
	rings = live


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
			draw_texture_rect(_strip, cell, true)
		else:
			draw_rect(cell, DEEP.lerp(FLOOR, 0.6))
	# The still surface: a pale line that breathes, with slow glints drifting on it.
	for x in _cols:
		var a := 0.55 + 0.25 * sin(_t * 1.3 + x * 0.6)
		draw_rect(Rect2(x * Room.TILE, y, Room.TILE, 1), Color(SURFACE, a))
		if (x + int(_t * 2.0)) % 5 == 0:
			draw_rect(Rect2(x * Room.TILE + 4 + int(_t * 6.0) % 8, y + 2, 3, 1), Color(SURFACE, 0.4))
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
