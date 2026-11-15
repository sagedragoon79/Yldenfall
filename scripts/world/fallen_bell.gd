class_name FallenBell
extends Node2D
## The shift bell of the Bell Loft (room prop `fallen_bell`, pass 569, bible
## 12.56), a Tower landmark: a bronze bell taller than the hero, lying on its
## side where it fell, its mouth turned to the room, split from lip to crown.
## Its clapper has rolled out onto the floor, half of its timber headstock lies
## behind it, and the other half still hangs from two iron straps under the
## ceiling with the frayed bell rope swaying from it. The room's sign had told
## of the bell since the room was made; nothing was drawn.
##
## Painted like the crucible (12.35): whole world pixels on master palette
## ramps, lit from the upper left, baked once into an image (`build_image`).
## Only the rope and a glint on the lip are drawn live. Scenery only. The
## origin is the bottom center, on the floor.

const OUTLINE := Color("120f19")  # night-0
## Bronze, dark to lit (ochre-1 to ochre-4), and its glint (ochre-5).
const BRONZE: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44"), Color("bea860")]
const GLINT := Color("ccbe8e")
## The dark inside the bell (ochre-0) and the wall the light reaches (ochre-1).
const HOLLOW := Color("1a100f")
const HOLLOW_LIT := Color("432d23")
## Verdigris where the bronze lies in shade (moss-2, moss-3).
const PATINA_DARK := Color("4f5c47")
const PATINA := Color("728061")
## Iron: the clapper and the straps (stone-1 to stone-4).
const IRON: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## Timber: the headstock (umber-1 to umber-3) and its split ends (umber-4).
const WOOD: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56")]
const SPLINTER := Color("aa9173")
## The rope (umber-3, umber-4).
const ROPE_DARK := Color("8a6e56")
const ROPE := Color("aa9173")
## Every tone above, for the palette test.
const TONES := [OUTLINE, BRONZE[0], BRONZE[1], BRONZE[2], BRONZE[3], GLINT, HOLLOW, PATINA_DARK, PATINA, IRON[0], IRON[1], IRON[2], IRON[3], WOOD[0], WOOD[1], WOOD[2], SPLINTER]

## The center of the bell's mouth, from the origin, and the way its axis runs
## from the mouth to the crown (radians; it rests on its lip and its shoulder).
const MOUTH := Vector2(-36, -35)
const LIE := 0.2
## The bell's length along its axis, the lip's radius, the waist's radius and
## how fast the flare closes to the waist.
const LENGTH := 74.0
const LIP_R := 36.0
const WAIST_R := 21.0
const FLARE := 11.0
## Where the shoulder starts to close to the crown.
const SHOULDER := 60.0
## The mouth is turned a little to the viewer: its ellipse's half width.
const MOUTH_RX := 9.0
## The thickness of the bronze at the lip.
const WALL := 3.0
## Verdigris grows where the speckle is over this.
const PATINA_OVER := 0.74
## The underside of the room's ceiling, from the origin.
const CEILING := -256
## The stub of the headstock under the ceiling, and where the rope leaves it.
const STUB := Rect2i(-30, -244, 46, 9)
const ROPE_TOP := Vector2(-18, -235)
const ROPE_LENGTH := 74.0
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-72, -258, 132, 258)
## The split's zigzag, in pixels across the bell, one value every three along it.
const JAG: Array[float] = [0.0, 1.0, 2.0, 1.0, -1.0, -2.0, -1.0, 0.0]
## The light, from the upper left and toward the viewer.
const LIGHT := Vector3(-0.55, -0.65, 0.52)

var t := 0.0
var _tex: ImageTexture


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex = ImageTexture.create_from_image(build_image())


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## A world pixel in the bell's own frame: x along the axis from the mouth to
## the crown, y across it (negative is the upper side).
static func local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5) - MOUTH).rotated(-LIE)


## The bell's radius at `s` along its axis: a flared lip, a waist, a shoulder
## that closes to the crown.
static func radius(s: float) -> float:
	var r := WAIST_R + (LIP_R - WAIST_R) * exp(-maxf(s, 0.0) / FLARE)
	if s > SHOULDER:
		var k := clampf((s - SHOULDER) / (LENGTH - SHOULDER), 0.0, 1.0)
		r *= sqrt(1.0 - k * k)
	return r


## Inside the mouth's ellipse, shrunk by `inset` pixels.
static func in_mouth(q: Vector2, inset: float) -> bool:
	return pow(q.x / (MOUTH_RX - inset), 2) + pow(q.y / (LIP_R - inset), 2) <= 1.0


## On the bronze the viewer sees from outside: past the lip's near edge.
static func in_body(q: Vector2) -> bool:
	return q.x >= 0.0 and q.x <= LENGTH and absf(q.y) <= radius(q.x) and not in_mouth(q, 0.0)


## How brightly the light falls on the body at `q`, -1 to 1: a surface of
## revolution, its normal turned with the bell.
static func body_light(q: Vector2) -> float:
	var r := radius(q.x)
	var across := clampf(q.y / maxf(r, 0.001), -1.0, 1.0)
	var slope := clampf((radius(q.x - 0.5) - radius(q.x + 0.5)), -2.0, 2.0)
	var flat := Vector2(slope, across).rotated(LIE)
	return Vector3(flat.x, flat.y, sqrt(1.0 - across * across)).normalized().dot(LIGHT.normalized())


## A 2 x 2 ordered dither, so the steps between tones are pixelled.
static func dither(c: Vector2i) -> float:
	return [[0.0, 0.5], [0.75, 0.25]][posmod(c.y, 2)][posmod(c.x, 2)] - 0.375


## A fixed speckle, 0 to 1, in streaks that run round the bell: three pixels
## along its axis, nine across it.
static func speckle(q: Vector2) -> float:
	var h := (floori(q.x / 3.0) * 73856093) ^ (floori(q.y / 9.0) * 19349663)
	return float(posmod(h, 97)) / 96.0


## Where the split runs across the bell at `s` (its middle, in the bell's
## frame) and how wide it gapes: widest at the lip, a hairline at the crown.
static func crack_at(s: float) -> Vector2:
	var k := clampf(s / LENGTH, 0.0, 1.0)
	var mid: float = -radius(s) * 0.42 + JAG[posmod(floori(s / 3.0), JAG.size())]
	return Vector2(mid, lerpf(1.7, 0.45, k))


static func on_crack(q: Vector2) -> bool:
	if q.x > LENGTH - 3.0:
		return false
	var c := crack_at(q.x)
	return absf(q.y - c.x) <= c.y


## How lit the bronze is at a body cell, 0 (dark) to 3.
static func level_at(c: Vector2i, q: Vector2) -> int:
	return clampi(floori((body_light(q) + 0.25) * 3.0 + dither(c) * 0.45), 0, 3)


## The tone at a body cell.
static func bronze_at(c: Vector2i, q: Vector2) -> Color:
	if on_crack(q):
		return OUTLINE
	var level := level_at(c, q)
	var col := BRONZE[level]
	if body_light(q) > 0.9:
		col = GLINT
	# The lower lip of the split catches the light.
	var crack := crack_at(q.x)
	if q.x <= LENGTH - 3.0 and q.y - crack.x > crack.y and q.y - crack.x <= crack.y + 1.0:
		col = BRONZE[mini(level + 1, 3)]
	# Raised bands: two above the lip, one under the shoulder. They bend with
	# the mouth, since the bell is turned a little to the viewer.
	var r := radius(q.x)
	var bulge := sqrt(maxf(0.0, 1.0 - pow(q.y / maxf(r, 0.001), 2)))
	for band: float in [12.0, 17.0, 54.0]:
		var d := q.x - (band + MOUTH_RX * radius(band) / LIP_R * bulge)
		if d >= 0.0 and d < 1.2:
			col = BRONZE[maxi(level - 1, 0)]
		elif d >= -1.2 and d < 0.0:
			col = BRONZE[mini(level + 1, 3)] if level < 3 else GLINT
	# Verdigris in the shade, in patches.
	if level <= 1 and speckle(q) > PATINA_OVER:
		col = PATINA if level == 1 else PATINA_DARK
	return col


## An outlined block of one ramp, lit along its top and left.
static func _block(put: Callable, rect: Rect2i, ramp: Array) -> void:
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var c := Vector2i(x, y)
			if not rect.has_point(c):
				put.call(c, OUTLINE)
			elif y == rect.position.y or x == rect.position.x:
				put.call(c, ramp[2])
			elif y == rect.end.y - 1 or x == rect.end.x - 1:
				put.call(c, ramp[0])
			else:
				put.call(c, ramp[1])


## A timber with its grain, and one end split into splinters.
static func _timber(put: Callable, rect: Rect2i, split_right: bool) -> void:
	_block(put, rect, WOOD)
	for y in range(rect.position.y + 2, rect.end.y - 1, 3):
		for x in range(rect.position.x + 2, rect.end.x - 2):
			if posmod(floori(x / 3.0) + y, 5) < 3:
				put.call(Vector2i(x, y), WOOD[0])
	# The split end: teeth of pale wood, longer and shorter.
	var teeth := [5, 2, 6, 3, 4, 1, 5, 3, 2]
	for i in rect.size.y:
		var length: int = teeth[i % teeth.size()]
		var y := rect.position.y + i
		for k in range(-1, length + 1):
			var x := rect.end.x + k if split_right else rect.position.x - 1 - k
			put.call(Vector2i(x, y), SPLINTER if k < length and k >= 0 else OUTLINE)


## The static half of the prop, baked once.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	var put := func(c: Vector2i, col: Color) -> void:
		var p := c - IMG.position
		if p.x >= 0 and p.y >= 0 and p.x < IMG.size.x and p.y < IMG.size.y:
			img.set_pixel(p.x, p.y, col)
	# Under the ceiling: two iron straps, and the half of the headstock they
	# still hold, split where the bell tore away.
	for x: int in [STUB.position.x + 5, STUB.end.x - 12]:
		_block(put, Rect2i(x, CEILING, 4, STUB.position.y - CEILING + STUB.size.y + 2), IRON)
	_timber(put, STUB, true)
	for x: int in [STUB.position.x + 5, STUB.end.x - 12]:
		_block(put, Rect2i(x - 1, STUB.position.y + 3, 6, 3), IRON)
	# On the floor behind the bell: the other half of the headstock.
	_timber(put, Rect2i(18, -8, 34, 8), false)
	# The bell.
	var body := {}
	for y in range(IMG.position.y + 150, 0):
		for x in range(IMG.position.x, IMG.end.x):
			var c := Vector2i(x, y)
			var q := local(c)
			if in_mouth(q, WALL):
				# Inside: dark, but for the lower wall the light reaches.
				body[c] = HOLLOW_LIT if q.y > LIP_R * 0.45 and q.x > -2.0 and dither(c) > -0.2 else HOLLOW
			elif in_mouth(q, 0.0):
				# The lip's edge: lit above, in its own shade below.
				body[c] = (GLINT if q.y < -LIP_R * 0.5 else BRONZE[3]) if q.y < 6.0 else BRONZE[1]
				if on_crack(Vector2(maxf(q.x, 0.0), q.y)):
					body[c] = OUTLINE
			elif in_body(q):
				body[c] = bronze_at(c, q)
	# The crown: the block of bronze loops the headstock was strapped through.
	for y in range(IMG.position.y + 150, 0):
		for x in range(IMG.position.x, IMG.end.x):
			var c := Vector2i(x, y)
			var q := local(c)
			if q.x > LENGTH - 2.0 and q.x <= LENGTH + 7.0 and absf(q.y) <= 8.0 and not body.has(c):
				var hole := absf(q.y) <= 3.0 and q.x > LENGTH + 1.0 and q.x <= LENGTH + 4.5
				if not hole:
					body[c] = BRONZE[2] if q.y < -4.0 else (BRONZE[1] if q.y < 4.0 else BRONZE[0])
	# A selective outline: none where the lit bronze meets the dark above it.
	var rim := {}
	for c: Vector2i in body:
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var e: Vector2i = c + s
			if body.has(e):
				continue
			var lit_face: bool = (body[c] == BRONZE[3] or body[c] == GLINT) and (s == Vector2i.LEFT or s == Vector2i.UP)
			if not lit_face:
				rim[e] = true
	for c: Vector2i in rim:
		put.call(c, OUTLINE)
	for c: Vector2i in body:
		put.call(c, body[c])
	# The clapper, rolled out of the mouth: an iron ball on the floor and its
	# shank back into the dark.
	var ball := Vector2(-56.5, -7.5)
	var shank_end := MOUTH + Vector2(4, 16)
	for i in 40:
		var p := ball.lerp(shank_end, i / 39.0)
		for dy in range(-1, 3):
			var c := Vector2i(floori(p.x), floori(p.y) + dy)
			put.call(c, OUTLINE if dy == -1 or dy == 2 else (IRON[2] if dy == 0 else IRON[0]))
	for y in range(-16, 0):
		for x in range(-66, -47):
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - ball)
			if d.length() <= 7.5:
				var c := Vector2i(x, y)
				if d.length() > 6.4:
					put.call(c, OUTLINE)
				else:
					var lit: float = Vector3(d.x / 6.4, d.y / 6.4, sqrt(maxf(0.0, 1.0 - d.length_squared() / 40.96))).dot(LIGHT.normalized())
					put.call(c, IRON[clampi(floori((lit + 0.3) * 2.6 + dither(c) * 0.45), 0, 3)])
	# Chips of bronze and plate where the lip struck.
	for chip: Array in [[-44, 3, 2], [-30, 2, 1], [-68, 2, 0], [6, 3, 1], [56, 2, 0]]:
		for y in range(-chip[1], 0):
			for x in range(chip[0], chip[0] + chip[1] + 1):
				put.call(Vector2i(x, y), BRONZE[chip[2]] if y > -chip[1] else BRONZE[mini(chip[2] + 1, 3)])
	return img


## Where the rope's `i`th two-pixel step hangs at time `at`: still at the
## headstock, swinging more toward its frayed end.
static func rope_point(i: int, at: float) -> Vector2:
	var h := i * 2.0
	var sway := sin(at * 0.9 - h * 0.035) * 5.0 * pow(h / ROPE_LENGTH, 1.5)
	return ROPE_TOP + Vector2(roundf(sway), h)


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	# The bell rope, frayed where it parted.
	var steps := int(ROPE_LENGTH / 2.0)
	for i in steps:
		var p := rope_point(i, t)
		draw_rect(Rect2(p.x - 1, p.y, 4, 2), OUTLINE)
		draw_rect(Rect2(p.x, p.y, 2, 2), ROPE if i % 3 != 2 else ROPE_DARK)
	var tip := rope_point(steps, t)
	for f: Vector2 in [Vector2(-2, 0), Vector2(0, 1), Vector2(2, 0), Vector2(-1, 3), Vector2(1, 4)]:
		draw_rect(Rect2(tip.x + f.x, tip.y + f.y, 1, 2), ROPE)
	# Now and then a glint runs down the lip.
	var cycle := fmod(t, 5.0)
	if cycle < 0.5:
		var a := lerpf(-1.3, -0.3, cycle / 0.5)
		var p := MOUTH + Vector2(-cos(a) * (MOUTH_RX - 1.5), sin(a) * (LIP_R - 1.5)).rotated(LIE)
		draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y), 3, 1), GLINT)
		draw_rect(Rect2(roundf(p.x), roundf(p.y) - 1, 1, 3), GLINT)
