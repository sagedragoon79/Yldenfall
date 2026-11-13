class_name LightVein
extends Area2D
## One of the veins of light the Everbloom's core feeds through (the Everbloom,
## phase 2: The Veins, design bible 8.9; legend `x`). A knot of cyan crystal
## grown into the shaft, pulsing up toward the core. One blow cuts it and its
## light goes out; cut them all and the core starves. A pogo bounces off it.
## The origin is its centre.
##
## Pass 545 (bible 12.37): the pass 535 grade called these "flat cyan diamonds".
## Each was one smooth pentagon of a single cyan with a lighter inner diamond.
## Now the knot is painted in whole world pixels on master palette ramps, lit
## from the upper left: three crystal shards, each a faceted prism (a lit left
## face, a front face, a shaded right face and a pointed cap), grown from a
## fleshy node of the Evercrown's night ramp, hung on a vein that climbs toward
## the core. The bodies are baked once (`build_image`); the light that pulses up
## the main shard and runs up the vein is stepped at `STEP_FPS` like
## hand-drawn frames (`pulse_cells`, `thread_cells`). Cut, the main shard is
## snapped off, the crystal goes dead night-violet and the vein goes slack.

signal cut

const SIZE := Vector2(14, 22)
const OUTLINE := Color("120f19")  # night-0
## The crystal, deep to white light (sky-1 to sky-7).
const SKY: Array[Color] = [Color("1e3148"), Color("2b5278"), Color("3677aa"), Color("51a5cd"), Color("84cbd6"), Color("b5e3e1"), Color("e2f3ef")]
## The flesh it grows from, and the dead crystal once cut (night-1 to night-4).
const NIGHT: Array[Color] = [Color("2c2541"), Color("44386b"), Color("5d4997"), Color("8265b8")]
## Every tone above, for the palette test.
const TONES := [OUTLINE, SKY[0], SKY[1], SKY[2], SKY[3], SKY[4], SKY[5], SKY[6], NIGHT[0], NIGHT[1], NIGHT[2], NIGHT[3]]
## Kept for older callers: the light, the crystal and its dead tone.
const LIGHT := Color("e2f3ef")
const CYAN := Color("51a5cd")
const DEEP := Color("1e3148")
const DEAD := Color("44386b")

## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-11, -15, 23, 32)
## The main shard's tip, and the row where the shards meet the node.
const TIP := -13
const BASE := 6
## Where a cut shard snaps off.
const SNAP := -3
## How far the vein climbs above the knot.
const THREAD := 44
## The light's frames per second.
const STEP_FPS := 10.0

## The three shards, back to front: [outline polygon, apex, base middle, tone offset].
## A side shard sits a step darker than the main one.
const SHARDS := [
	[[Vector2(-8, -4), Vector2(-5, -1), Vector2(-3, 7), Vector2(-7, 7), Vector2(-9.5, 1)], Vector2(-8, -4), Vector2(-5, 7), -1],
	[[Vector2(7, -1), Vector2(9.5, 3), Vector2(7, 7), Vector2(3, 7), Vector2(4, 2)], Vector2(7, -1), Vector2(5, 7), -2],
	[[Vector2(0, -13.5), Vector2(4.5, -6), Vector2(4.5, 7), Vector2(-4.5, 7), Vector2(-4.5, -6)], Vector2(0, -13), Vector2(0, 7), 0],
]

static var _tex_lit: ImageTexture
static var _tex_cut: ImageTexture

var is_cut := false
var _t := 0.0
var _flash := 0.0
var _step := -1


func _ready() -> void:
	collision_layer = Player.LAYER_ENEMY
	collision_mask = 0
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("pogo")
	add_to_group("light_vein")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	if is_cut:
		collision_layer = 0
	# Neighbouring veins pulse out of step.
	_t = fmod(absf(position.x * 0.37 + position.y * 0.11), 1.2)


## Called by the player's blade.
func take_hit(_damage: int, _dir: Vector2) -> void:
	if is_cut:
		return
	is_cut = true
	_flash = 0.15
	set_deferred("collision_layer", 0)
	var d := Dust.new()
	d.setup("parry")
	get_parent().add_child(d)
	d.global_position = global_position
	Sfx.play("lantern_break", 0.05, 0.0)
	Feel.hitstop(0.08)
	cut.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var was := _flash
	_flash -= delta
	var step := int(_t * STEP_FPS)
	if (step != _step and not is_cut) or (was > 0.0) != (_flash > 0.0):
		_step = step
		queue_redraw()


func _draw() -> void:
	if _tex_lit == null:
		_tex_lit = ImageTexture.create_from_image(build_image(false))
		_tex_cut = ImageTexture.create_from_image(build_image(true))
	if is_cut:
		for c: Vector2i in slack_cells():
			_px(c, NIGHT[0])
		if _flash > 0.0:
			for c: Vector2i in body_cells(true):
				_px(c, SKY[6])
		else:
			draw_texture(_tex_cut, Vector2(IMG.position))
		return
	for p: Array in thread_cells(_step):
		_px(p[0], p[1])
	draw_texture(_tex_lit, Vector2(IMG.position))
	for p: Array in pulse_cells(_step):
		_px(p[0], p[1])


func _px(c: Vector2i, col: Color) -> void:
	draw_rect(Rect2(c.x, c.y, 1, 1), col)


static func _inside(poly: Array, q: Vector2) -> bool:
	var inside := false
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if (a.y > q.y) != (b.y > q.y) and q.x < a.x + (q.y - a.y) / (b.y - a.y) * (b.x - a.x):
			inside = not inside
	return inside


## Which face of a shard a cell is on, lit to shaded: 0 the cap's lit side,
## 1 the left face, 2 the front face, 3 the cap's shaded side, 4 the right face.
static func face(shard: Array, q: Vector2) -> int:
	var apex: Vector2 = shard[1]
	var mid: Vector2 = shard[2]
	# The ridge runs from the apex down the middle of the shard.
	var axis := (mid - apex).normalized()
	var side := axis.x * (q.y - apex.y) - axis.y * (q.x - apex.x)
	var along := (q - apex).dot(axis)
	var cap := along < 6.5
	if cap:
		return 0 if side > 0.0 else 3
	if side > 1.0:
		return 1
	if side > -1.5:
		return 2
	return 4


## The crystal tone of a cell: lit from the upper left, a step darker toward the node.
static func crystal_tone(shard: Array, q: Vector2) -> int:
	var f := face(shard, q)
	var base: int = [5, 4, 3, 2, 1][f]
	if q.y > 3.0:
		base -= 1
	return clampi(base + int(shard[3]), 0, 6)


## The cells of the crystal (and the cut shard's stump), not the node.
static func body_cells(cut_off: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for shard: Array in SHARDS:
		for y in range(IMG.position.y, BASE + 1):
			for x in range(IMG.position.x, IMG.end.x):
				var q := Vector2(x + 0.5, y + 0.5)
				if _inside(shard[0], q) and not (cut_off and _snapped(shard, x, y)) and not seen.has(Vector2i(x, y)):
					seen[Vector2i(x, y)] = true
					out.append(Vector2i(x, y))
	return out


## Whether a cell of a shard is gone once the vein is cut: the main shard
## breaks off along a jagged line, the side shards lose their tips.
static func _snapped(shard: Array, x: int, y: int) -> bool:
	var apex: Vector2 = shard[1]
	if apex.y < -10.0:
		return y < SNAP + [0, 1, -1, 1, 0, -1, 1, 0, -1][posmod(x, 9)]
	return y < int(apex.y) + 3


## The fleshy node the shards grow from, with root hairs: [cell, tone].
static func node_cells() -> Array:
	var out := []
	for y in range(BASE - 1, 12):
		for x in range(-9, 10):
			var q := Vector2(x + 0.5, y + 0.5)
			var d := pow(q.x / 9.5, 2.0) + pow((q.y - 8.5) / 3.6, 2.0)
			if d > 1.0:
				continue
			var tone := 1
			if q.y < 7.5 and q.x < 3.0:
				tone = 3
			elif q.y < 8.5:
				tone = 2
			elif q.y > 10.0 or q.x > 5.0:
				tone = 0
			out.append([Vector2i(x, y), tone])
	for hair: Array in [[-5, 3], [-1, 2], [3, 4], [6, 2]]:
		for i in hair[1]:
			out.append([Vector2i(hair[0] + (1 if i > 1 else 0), 12 + i), 0])
	return out


## The knot baked into an image: node, shards and the outline round them all.
static func build_image(cut_off: bool) -> Image:
	var img := Image.create_empty(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	var put := func(c: Vector2i, col: Color) -> void:
		var p := c - IMG.position
		if p.x >= 0 and p.y >= 0 and p.x < IMG.size.x and p.y < IMG.size.y:
			img.set_pixelv(p, col)
	for n: Array in node_cells():
		put.call(n[0], NIGHT[n[1]])
	for shard: Array in SHARDS:
		for y in range(IMG.position.y, BASE + 1):
			for x in range(IMG.position.x, IMG.end.x):
				var q := Vector2(x + 0.5, y + 0.5)
				if not _inside(shard[0], q):
					continue
				if cut_off and _snapped(shard, x, y):
					continue
				var tone := crystal_tone(shard, q)
				if cut_off:
					put.call(Vector2i(x, y), NIGHT[clampi(tone - 2, 0, 3)])
				else:
					put.call(Vector2i(x, y), SKY[tone])
	if cut_off:
		# A crack down what is left of the main shard.
		for c: Vector2i in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3)]:
			put.call(c, OUTLINE)
	else:
		# A glint on the lit edge of each cap.
		for c: Vector2i in [Vector2i(-1, -11), Vector2i(-2, -9), Vector2i(-8, -3)]:
			put.call(c, SKY[6])
	# Close every shape in the outline.
	var filled := {}
	for y in IMG.size.y:
		for x in IMG.size.x:
			if img.get_pixel(x, y).a > 0.0:
				filled[Vector2i(x, y)] = true
	for c: Vector2i in filled:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var e := c + d
			if not filled.has(e) and e.x >= 0 and e.y >= 0 and e.x < IMG.size.x and e.y < IMG.size.y:
				img.set_pixelv(e, OUTLINE)
	return img


## The light climbing the main shard's front face: [cell, tone]. A bright head
## runs up from the node to the tip every 15 steps, with a tail behind it.
static func pulse_cells(step: int) -> Array:
	var out := []
	var head := BASE - posmod(step, 15) * 1.4
	for y in range(TIP + 4, BASE - 1):
		var d := float(y) - head
		var tone := -1
		if d >= 0.0 and d < 1.5:
			tone = 6
		elif d >= 1.5 and d < 3.5:
			tone = 5
		elif d >= 3.5 and d < 6.0:
			tone = 4
		if tone < 0:
			continue
		if y > 3:
			tone -= 1
		for x in [-1, 0]:
			out.append([Vector2i(x, y), SKY[tone]])
	return out


## The vein the knot hangs on, climbing toward the core, with beads of light
## running up it: [cell, tone].
static func thread_cells(step: int) -> Array:
	var out := []
	var top := TIP - THREAD
	var lit := {}
	for i in 4:
		var head := TIP - 2 - posmod(step * 3 + i * 11, THREAD)
		for k in 3:
			var y := head + k
			if y < TIP - 1 and y >= top:
				var fade := 1 if y < top + THREAD / 3 else 0
				lit[y] = maxi(lit.get(y, -1), [4, 3, 2][k] - fade)
	for y in range(top, TIP - 1):
		var x := _sway(y)
		out.append([Vector2i(x, y), SKY[lit[y]] if lit.has(y) else SKY[0]])
	return out


## The vein's slight wander off the vertical.
static func _sway(y: int) -> int:
	return [0, 0, 0, 1, 1, 0, 0, -1, -1, 0][posmod(y, 40) / 4]


## Cut, the vein hangs slack and dark: a short stub above the stump.
static func slack_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(TIP - THREAD, TIP - THREAD + 16):
		out.append(Vector2i(_sway(y), y))
	return out
