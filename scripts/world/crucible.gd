class_name Crucible
extends Node2D
## The great crucible of the Smelter (room prop `crucible`), a Tower landmark:
## an iron pot as wide as a house hung on chains, tipped to pour molten ore
## in a glowing stream into a stone trough. The stream ripples, the trough
## crusts and glows, and sparks jump where the metal lands. Scenery only (the
## metal never touches the walkway). The origin is the bottom center of the
## trough, on the floor.
##
## Pass 543 (bible 12.35): the pass 540 grade called it "the smelter's clean
## vector lava cauldron". It was smooth polygons in two iron tones with a flat
## orange disc for the metal. Now it is painted in whole world pixels on master
## palette ramps, lit from the upper left: the pot, its hoops, rivets, lugs and
## chains, and the trough's stone blocks are baked once into an image
## (`build_image`); the molten surface, the stream and the channel are pixel
## cells recoloured as the metal rolls, stepped at `STEP_FPS` like hand-drawn
## frames.

const OUTLINE := Color("120f19")  # night-0
## Iron, dark to lit (stone-1 to stone-5).
const IRON: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
const IRON_GLINT := Color("aca1ba")
## The molten light thrown back up onto the pot's lower right (bark-2, bark-3).
const BOUNCE := Color("783c2b")
const BOUNCE_HOT := Color("aa6336")
## The trough's stone (ash-1 to ash-4).
const MORTAR := Color("363330")
const STONE_DARK := Color("58544c")
const STONE := Color("797767")
const STONE_LIGHT := Color("989885")
## The metal, cold crust to white heat (bark-1, bark-2, ember-3, ember-4, gold-4, gold-5, gold-7).
const HEAT: Array[Color] = [Color("48201e"), Color("783c2b"), Color("c02a20"), Color("e55439"), Color("f0c02e"), Color("edce6e"), Color("f7f1de")]
const MOLTEN := Color("e55439")
const HOT := Color("f0c02e")
const WHITE_HOT := Color("f7f1de")
## Every tone above, for the palette test.
const TONES := [OUTLINE, IRON[0], IRON[1], IRON[2], IRON[3], IRON_GLINT, BOUNCE, BOUNCE_HOT, MORTAR, STONE_DARK, STONE, STONE_LIGHT, HEAT[0], HEAT[1], HEAT[2], HEAT[3], HEAT[4], HEAT[5], HEAT[6]]

## Where the pot hangs, from the origin, and how far it is tipped (radians).
const POT := Vector2(-34, -132)
const TIP := 0.38
## The pot's half width, the depth of its bowl and the half height of its mouth.
const POT_RX := 34.0
const BOWL_RY := 41.0
const MOUTH_RY := 11.0
## The lip of iron round the mouth, and the metal inside it.
const RIM := 2.0
const TROUGH_W := 150
## Where the chains end, above the room's ceiling.
const CHAIN_TOP := -320
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-90, -330, 180, 330)
## The light, from the upper left and toward the viewer.
const LIGHT := Vector3(-0.55, -0.65, 0.52)
## The metal's frames per second.
const STEP_FPS := 10.0

var t := 0.0
## Live sparks: [position, velocity, life].
var sparks: Array = []
var _rng := RandomNumberGenerator.new()
var _glow: Node2D
var _tex: ImageTexture
## The molten surface: [cell, local position on the mouth, 0 to 1 from center to rim].
var _mouth: Array = []


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 11
	_tex = ImageTexture.create_from_image(build_image())
	_mouth = mouth_cells()
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.z_index = 1
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## The point on the pot's lip the stream leaves from: the rim's low end.
func lip() -> Vector2:
	return lip_at()


static func lip_at() -> Vector2:
	return POT + Vector2(POT_RX + RIM, -1.0).rotated(TIP)


## A world pixel's position in the pot's own frame (untipped, from its center).
static func local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5) - POT).rotated(-TIP)


static func in_bowl(q: Vector2) -> bool:
	return q.y >= 0.0 and pow(q.x / POT_RX, 2) + pow(q.y / BOWL_RY, 2) <= 1.0


## Inside the mouth's ellipse, grown by `grow` pixels.
static func in_mouth(q: Vector2, grow: float) -> bool:
	return pow(q.x / (POT_RX + grow), 2) + pow(q.y / (MOUTH_RY + grow), 2) <= 1.0


## How brightly the light falls on the bowl at `q`, -1 to 1: the bowl as half
## an ellipsoid, its normal tipped with the pot.
static func bowl_light(q: Vector2) -> float:
	var n2 := Vector2(q.x / POT_RX, q.y / BOWL_RY)
	var nz := sqrt(maxf(0.0, 1.0 - n2.length_squared()))
	var w := n2.rotated(TIP)
	return Vector3(w.x, w.y, nz).normalized().dot(LIGHT.normalized())


## A 2 x 2 ordered dither, so the steps between iron tones are pixelled
## rather than banded.
static func dither(c: Vector2i) -> float:
	return [[0.0, 0.5], [0.75, 0.25]][posmod(c.y, 2)][posmod(c.x, 2)] - 0.375


## The iron tone at a bowl cell.
static func iron_at(c: Vector2i, q: Vector2) -> Color:
	var lit := bowl_light(q)
	var level := clampi(floori((lit + 0.18) * 2.8 + dither(c) * 0.45), 0, 3)
	var col := IRON[level]
	if lit > 0.93:
		col = IRON_GLINT
	# Two hoops round the bowl: a dark band with a lit upper edge.
	var across := sqrt(maxf(0.0, 1.0 - pow(q.x / POT_RX, 2)))
	for hoop: Vector2 in [Vector2(9.0, 5.0), Vector2(23.0, 8.0)]:
		var d := q.y - (hoop.x + hoop.y * across)
		if d >= -1.0 and d < 1.0:
			col = IRON[0] if level <= 1 else IRON[1]
			# Rivets along the hoop.
			if d < 0.0 and posmod(roundi(q.x), 7) == 0:
				col = IRON_GLINT if level >= 2 else IRON[3]
		elif d >= -2.0 and d < -1.0:
			col = IRON[mini(level + 1, 3)]
	# The metal's glow caught on the silhouette facing the trough.
	var n := Vector2(q.x / POT_RX, q.y / BOWL_RY)
	var edge := n.length()
	if edge > 0.93 and level <= 1:
		var toward := n.rotated(TIP).normalized().dot(Vector2(0.45, 0.89))
		if toward > 0.9 and edge > 0.97:
			col = BOUNCE_HOT
		elif toward > 0.6:
			col = BOUNCE
	return col


## The static half of the prop, baked once: chains, the pot and the trough.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	var put := func(c: Vector2i, col: Color) -> void:
		var p := c - IMG.position
		if p.x >= 0 and p.y >= 0 and p.x < IMG.size.x and p.y < IMG.size.y:
			img.set_pixel(p.x, p.y, col)
	# Chains from the dark above to the pot's two lugs.
	for hook: Vector2i in hooks():
		_chain(put, hook)
	# The pot.
	var body := {}
	var lo := Vector2i(POT - Vector2(50, 50))
	for y in range(lo.y, lo.y + 100):
		for x in range(lo.x, lo.x + 100):
			var c := Vector2i(x, y)
			var q := local(c)
			if in_mouth(q, RIM) and not in_mouth(q, 0.0):
				# The lip: its far side lit on top, its near side in its own shade.
				if q.y < 0.0:
					body[c] = IRON[3] if q.x < 4.0 else IRON[2]
				else:
					body[c] = IRON[2] if q.x < -4.0 else IRON[1]
			elif in_bowl(q) and not in_mouth(q, 0.0):
				body[c] = iron_at(c, q)
			elif in_mouth(q, 0.0):
				body[c] = Color.TRANSPARENT  # the metal, drawn live
	# A selective outline: none where the lit upper-left iron meets the dark.
	var rim := {}
	for c: Vector2i in body:
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var e: Vector2i = c + s
			if body.has(e):
				continue
			var lit_face: bool = (body[c] == IRON[2] or body[c] == IRON[3] or body[c] == IRON_GLINT) and (s == Vector2i.LEFT or s == Vector2i.UP)
			if not lit_face:
				rim[e] = true
	for c: Vector2i in rim:
		put.call(c, OUTLINE)
	for c: Vector2i in body:
		if body[c].a > 0.0:
			put.call(c, body[c])
	# The lugs the chains hold.
	for hook: Vector2i in hooks():
		for y in range(-2, 3):
			for x in range(-2, 3):
				var edge := absi(x) == 2 or absi(y) == 2
				var col := OUTLINE if edge else IRON[2]
				if not edge and (x < 0 or y < 0) and x + y < 0:
					col = IRON[3]
				elif not edge and x + y > 0:
					col = IRON[1]
				if edge and absi(x) == 2 and absi(y) == 2:
					continue
				put.call(hook + Vector2i(x, y), col)
	_trough(put)
	return img


## Where the chains meet the pot, on its rim.
static func hooks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for side: float in [-1.0, 1.0]:
		out.append(Vector2i((POT + Vector2(side * POT_RX * 0.88, -MOUTH_RY * 0.55).rotated(TIP)).floor()))
	return out


## A chain of iron links, face-on and edge-on in turn, every 8 pixels.
static func _chain(put: Callable, hook: Vector2i) -> void:
	var x := hook.x
	var y0 := hook.y - 2
	while y0 > CHAIN_TOP:
		var top := y0 - 8
		# The face-on link: an oval ring, lit on its left.
		for dy in range(1, 5):
			put.call(Vector2i(x - 2, top + dy), OUTLINE)
			put.call(Vector2i(x - 1, top + dy), IRON[3])
			put.call(Vector2i(x + 1, top + dy), IRON[1])
			put.call(Vector2i(x + 2, top + dy), OUTLINE)
		for dx in [-1, 1]:
			put.call(Vector2i(x + dx, top), OUTLINE)
			put.call(Vector2i(x + dx, top + 5), OUTLINE)
		put.call(Vector2i(x, top), IRON[2])
		put.call(Vector2i(x, top + 5), IRON[2])
		# The edge-on link through it.
		for dy in range(6, 8):
			put.call(Vector2i(x - 1, top + dy), OUTLINE)
			put.call(Vector2i(x, top + dy), IRON[2])
			put.call(Vector2i(x + 1, top + dy), OUTLINE)
		y0 = top


## The trough: dressed stone blocks round a channel, lit along its top.
static func _trough(put: Callable) -> void:
	var x0 := -TROUGH_W / 2
	var x1 := x0 + TROUGH_W
	for y in range(-13, 0):
		for x in range(x0 - 1, x1 + 1):
			var c := Vector2i(x, y)
			if x == x0 - 1 or x == x1 or y == -13:
				put.call(c, OUTLINE)
				continue
			# Two courses of blocks, the lower one offset by half a block.
			var course := 0 if y < -6 else 1
			var bx := posmod(x - x0 + course * 8, 16)
			var col := STONE_DARK
			if y == -12:
				col = STONE_LIGHT if posmod(x * 7 + 3, 23) > 1 else STONE  # a few chips in the lit top
			elif y == -6 or bx == 0:
				col = MORTAR
			elif bx == 1 or y == -11 or y == -5:
				col = STONE
			elif y == -1:
				col = MORTAR
			put.call(c, col)
	# The channel cut along the top, crusted cold (the live metal draws over it).
	for x in range(x0 + 4, x1 - 4):
		put.call(Vector2i(x, -11), OUTLINE)
		for y in range(-10, -7):
			put.call(Vector2i(x, y), HEAT[0])
		put.call(Vector2i(x, -7), OUTLINE)


## The cells of the molten surface, each with its place on the mouth.
static func mouth_cells() -> Array:
	var out: Array = []
	var lo := Vector2i(POT - Vector2(45, 45))
	for y in range(lo.y, lo.y + 90):
		for x in range(lo.x, lo.x + 90):
			var c := Vector2i(x, y)
			var q := local(c)
			if in_mouth(q, 0.0):
				out.append([c, q, sqrt(pow(q.x / POT_RX, 2) + pow(q.y / MOUTH_RY, 2))])
	return out


## The metal's tone at `q` on the mouth, `r` from its center to its rim, at
## frame time `tq`: a bright pool under a rolling skin of crust, cooler at the
## iron's edge.
static func molten_tone(q: Vector2, r: float, tq: float) -> Color:
	var skin := sin(q.x * 0.31 + tq * 1.4 + 1.7 * sin(q.y * 0.45)) * sin(q.y * 0.8 - tq * 0.9 + q.x * 0.13)
	skin += 0.4 * sin(q.x * 0.87 - q.y * 0.6 + tq * 2.1)
	var level := 4
	if r > 0.92:
		level = 2
	elif r > 0.8:
		level = 3
	if skin > 0.85:
		level = mini(level, 1)
	elif skin > 0.6:
		level = mini(level, 3)
	elif skin < -0.95 and r < 0.7:
		level = 6 if skin < -1.2 else 5
	return HEAT[level]


## The stream's pixels at frame time `tq`: from the lip to the trough, a
## wavering column with a white-hot core.
static func stream_cells(tq: float) -> Array:
	var out: Array = []
	var top := lip_at()
	var y0 := floori(top.y)
	var y1 := -10
	for y in range(y0, y1):
		var k := float(y - y0) / float(y1 - y0)
		var wob := roundi(sin(tq * 9.0 + y * 0.06) * 0.8)
		var cx := floori(top.x + 4.0 * sqrt(k) + wob)
		var w := 5 if k < 0.35 else (4 if k < 0.75 else 3)
		var left := cx - w / 2
		for i in w:
			var col := MOLTEN if i == 0 or i == w - 1 else HOT
			if i == w / 2 and posmod(y + floori(tq * 30.0), 7) < 3:
				col = WHITE_HOT
			out.append([Vector2i(left + i, y), col])
	return out


## The channel's glow at frame time `tq`: hottest where the stream lands.
static func channel_tone(x: int, row: int, tq: float) -> Color:
	var heat := clampf(1.0 - absf(x - lip_at().x - 4.0) / (TROUGH_W * 0.6), 0.0, 1.0)
	var flick := 0.5 + 0.5 * sin(tq * 4.0 + x * 0.3)
	var level := floori(heat * 4.6 + flick * 0.8 + dither(Vector2i(x, row)) * 0.8)
	if row == 0:
		level += 1  # the top of the run is brightest
	return HEAT[clampi(level, 0, 5)]


func _process(delta: float) -> void:
	t += delta
	if _rng.randf() < delta * 14.0:
		var at := Vector2(lip().x + 4.0 + _rng.randf_range(-3, 3), -12)
		sparks.append([at, Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-150, -60)), _rng.randf_range(0.3, 0.6)])
	for s: Array in sparks:
		s[1].y += 380.0 * delta
		s[0] += s[1] * delta
		s[2] -= delta
	sparks = sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	queue_redraw()
	_glow.queue_redraw()


func _px(c: Vector2i, col: Color) -> void:
	draw_rect(Rect2(c.x, c.y, 1, 1), col)


func _draw() -> void:
	var tq := floorf(t * STEP_FPS) / STEP_FPS
	draw_texture(_tex, Vector2(IMG.position))
	for m: Array in _mouth:
		_px(m[0], molten_tone(m[1], m[2], tq))
	for x in range(-TROUGH_W / 2 + 4, TROUGH_W / 2 - 4):
		for row in 3:
			_px(Vector2i(x, -10 + row), channel_tone(x, row, tq))
	for s: Array in stream_cells(tq):
		_px(s[0], s[1])
	# Sparks off the landing point.
	for s: Array in sparks:
		var life: float = s[2]
		_px(Vector2i(s[0].floor()), WHITE_HOT if life > 0.35 else HEAT[5])


func _draw_glow() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	var warm := Color(MOLTEN.r, MOLTEN.g * 0.7, MOLTEN.b * 0.3, 0.014 + 0.008 * pulse)
	for i in 9:
		_glow.draw_circle(Vector2(lip().x, -14), 110.0 - i * 11.0, warm)
	for i in 5:
		_glow.draw_circle(POT, 60.0 - i * 10.0, Color(warm.r, warm.g, warm.b, 0.012))
	var top := lip()
	_glow.draw_rect(Rect2(top.x - 6, top.y, 12, -top.y - 10), Color(HOT.r, HOT.g, HOT.b, 0.08))
