class_name HighSeat
extends Node2D
## The high seat of the Rot Dwarf Hall (room prop `high_seat`, pass 575, bible
## 12.62), a Heartwood landmark. The hall's sign says "These were Amberlee
## dwarves once. The rot came up through the roots with the sap": the hall's
## high seat stands on its dais between two carved pillars under a carved
## lintel, and a root has come up through all of it. The dais is heaved, the
## seat's back is split and its east half has dropped, the lintel is snapped
## and lifted on the root's shoulder, and one of the two shields has fallen
## from its nail. Sap runs down the root and has pooled on the seat; the
## timber rots where the root touches it and nowhere else.
##
## Painted like the ore bin (12.61): whole world pixels on master palette
## ramps, lit from the upper left, baked once. Only the drip of sap from the
## east side root is drawn live. Scenery only. The origin is the floor under
## the seat's middle.

const OUTLINE := Color("120f19")  # night-0
## Timber, shade to lit (umber-1 to umber-3).
const WOOD: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56")]
## The root, shade to lit (bark-0 to bark-2): darker than the timber, so the
## hall's frame stays the brighter thing and the root reads as what broke it.
const ROOT: Array[Color] = [Color("1c0d0f"), Color("48201e"), Color("783c2b")]
## The lit lips of the root's bark plates where the light finds them (bark-3),
## only on the side toward the light: still darker than the timber's lit edge.
const BARK_LIT := Color("aa6336")
## Stone and iron, dark to lit (stone-1 to stone-4).
const STONE: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## Sap, shade to glint (gold-2 to gold-4). Nothing but sap is gold.
const SAP: Array[Color] = [Color("8d4e16"), Color("cb8d16"), Color("f0c02e")]
## Rot in the timber (moss-1, moss-2).
const ROT: Array[Color] = [Color("2f392d"), Color("4f5c47")]
## Every tone above, for the palette test.
const TONES := [
	OUTLINE, WOOD[0], WOOD[1], WOOD[2], ROOT[0], ROOT[1], ROOT[2], BARK_LIT,
	STONE[0], STONE[1], STONE[2], STONE[3], SAP[0], SAP[1], SAP[2], ROT[0], ROT[1],
]

## The underside of the hall's ceiling, from the origin.
const CEILING := -288
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-96, -288, 192, 288)
## The dais: its half width and its height. Too low to read as a step.
const DAIS_HALF := 80
const DAIS_HIGH := 6
## The pillars: how far each stands from the middle, and how wide it is.
const PILLAR_X := 68
const PILLAR_WIDE := 12
## The lintel: its half length, its top where it lies level, and its depth.
const LINTEL_HALF := 84
const LINTEL_TOP := -192
const LINTEL_DEEP := 16
## How far the root has lifted the snapped lintel's two ends at the break.
const WEST_LIFT := 10
const EAST_LIFT := 4
## The seat: its box, its back and the back's stepped crest.
const SEAT_HALF := 32
const SEAT_TOP := -36
const BACK_HALF := 30
const BACK_TOP := -128
## How far the back's east half has dropped.
const BACK_DROP := 5
## The shields: where the hung one hangs, where the other's nail is, and
## where it lies against the east pillar.
const SHIELD_RADIUS := 13
const SHIELD_HUNG := Vector2i(-46, -112)
const SHIELD_NAIL := Vector2i(46, -126)
const SHIELD_FALLEN := Vector2i(52, -DAIS_HIGH - SHIELD_RADIUS)
## How far from the root the timber rots.
const ROT_REACH := 14
## The root's own shadow on the timber behind it, east of it (light from the upper left).
const CAST := 5
## The root is round (pass 655, bible 12.131): the light from the upper left
## and toward the viewer, which the shading reads off a cylinder's normal.
const LIGHT := Vector3(-0.62, 0.0, 0.78)
## Its bark: furrows every `FURROW_STEP` radians round it, twisting
## `TWIST` radians a row as it climbs; the plates between them are 14 to 24 rows tall.
const FURROW_STEP := 0.72
const TWIST := 0.012
## Two knots where limbs once grew: (row, side round the root -1 to 1, radius).
const KNOTS: Array[Vector3i] = [Vector3i(-104, -5, 4), Vector3i(-226, 3, 3)]
## The east side root, from the main root to the east pillar.
const SIDE_EAST_FROM := Vector2i(0, -164)
const SIDE_EAST_TO := Vector2i(PILLAR_X - PILLAR_WIDE / 2, -140)
## How far it sags between them.
const SIDE_SAG := 8
## The drip of sap from it, and the seconds between drops.
const DRIP_X := 39
const DRIP_PERIOD := 3.2
const PUDDLE_HALF := 3
## The pool of sap on the seat: its columns and its height.
const POOL := Vector2i(3, 14)
const POOL_HIGH := 3

## Baked once for the whole run.
static var _baked: Image

var t := 0.0
var _tex: ImageTexture


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _baked == null:
		_baked = build_image()
	_tex = ImageTexture.create_from_image(_baked)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## The root's middle at row `y`: it comes up west of the seat's middle and
## wanders east on its way to the ceiling.
static func root_x(y: int) -> int:
	var f := clampf(float(-y) / float(-CEILING), 0.0, 1.0)
	return roundi(-22.0 + 34.0 * f + 7.0 * sin(f * TAU * 1.1) + 3.0 * sin(f * TAU * 3.3 + 1.0))


## The root's half width at row `y`: thick at the floor, where it flares.
static func root_half(y: int) -> int:
	var f := clampf(float(-y) / float(-CEILING), 0.0, 1.0)
	# It flares where it leaves the floor and where it goes into the ceiling,
	# and it swells and thins on the way.
	var flare := maxf(0.0, float(y + 20)) / 3.0 + maxf(0.0, float(CEILING + 18 - y)) / 3.0
	return roundi(lerpf(11.0, 6.0, f) + 1.5 * sin(f * TAU * 4.0 + 0.6) + flare)


## Where the lintel is snapped: the root's middle at the lintel's height.
static func lintel_break() -> int:
	return root_x(LINTEL_TOP + LINTEL_DEEP / 2)


## How far the lintel is lifted at column `x`: nothing over its pillar, most
## at the break.
static func lintel_lift(x: int) -> int:
	var at := lintel_break()
	if x < at:
		return roundi(WEST_LIFT * clampf(float(x + PILLAR_X) / float(at + PILLAR_X), 0.0, 1.0))
	return roundi(EAST_LIFT * clampf(float(PILLAR_X - x) / float(PILLAR_X - at), 0.0, 1.0))


## How high the seat back's crest stands over `BACK_TOP` at column `x`.
static func crest(x: int) -> int:
	if absi(x) < 10:
		return 8
	if absi(x) < 20:
		return 4
	return 0


## The back's top at column `x`: the east half has dropped.
static func back_top(x: int) -> int:
	return BACK_TOP - crest(x) + (BACK_DROP if x >= root_x(BACK_TOP) else 0)


## The east side root's row at column `x`.
static func side_east_y(x: int) -> int:
	var f := clampf(float(x - SIDE_EAST_FROM.x) / float(SIDE_EAST_TO.x - SIDE_EAST_FROM.x), 0.0, 1.0)
	return roundi(lerpf(SIDE_EAST_FROM.y, SIDE_EAST_TO.y, f) + SIDE_SAG * sin(f * PI))


## Where a drop leaves the side root.
static func drip_top() -> int:
	return side_east_y(DRIP_X) + 3


## A drop's row at time `at`: it swells under the root, then falls to the dais.
static func drip_y(at: float) -> float:
	var phase := fposmod(at, DRIP_PERIOD) / DRIP_PERIOD
	var fall := clampf((phase - 0.5) / 0.5, 0.0, 1.0)
	return lerpf(drip_top(), -DAIS_HIGH - 3, fall * fall)


## A fixed speckle, 0 to 1.
static func speckle(x: int, y: int) -> float:
	return float(posmod((x * 73856093) ^ (y * 19349663), 97)) / 96.0


static func _fill(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x - IMG.position.x, y - IMG.position.y, w, h).intersection(Rect2i(Vector2i.ZERO, IMG.size))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col)


static func _px(img: Image, x: int, y: int) -> Color:
	var p := Vector2i(x, y) - IMG.position
	if p.x < 0 or p.y < 0 or p.x >= IMG.size.x or p.y >= IMG.size.y:
		return Color(0, 0, 0, 0)
	return img.get_pixel(p.x, p.y)


static func _dais(img: Image) -> void:
	_fill(img, -DAIS_HALF - 1, -DAIS_HIGH - 1, DAIS_HALF * 2 + 2, DAIS_HIGH + 1, OUTLINE)
	_fill(img, -DAIS_HALF, -DAIS_HIGH, DAIS_HALF * 2, DAIS_HIGH, STONE[1])
	_fill(img, -DAIS_HALF, -DAIS_HIGH, DAIS_HALF * 2, 1, STONE[2])
	_fill(img, -DAIS_HALF, -1, DAIS_HALF * 2, 1, STONE[0])
	# The slabs' joints.
	for x in range(-DAIS_HALF + 19, DAIS_HALF, 20):
		_fill(img, x, -DAIS_HIGH + 1, 1, DAIS_HIGH - 1, STONE[0])


static func _pillars(img: Image) -> void:
	var top := LINTEL_TOP + LINTEL_DEEP - 4
	for side: int in [-1, 1]:
		var x := side * PILLAR_X - PILLAR_WIDE / 2
		_fill(img, x - 1, top, PILLAR_WIDE + 2, -DAIS_HIGH - top, OUTLINE)
		_fill(img, x, top, PILLAR_WIDE, -DAIS_HIGH - top, WOOD[1])
		_fill(img, x, top, 3, -DAIS_HIGH - top, WOOD[2])
		_fill(img, x + PILLAR_WIDE - 3, top, 3, -DAIS_HIGH - top, WOOD[0])
		# The grain, and a groove down its face.
		for y in range(top, -DAIS_HIGH):
			if speckle(x, y / 5) > 0.8:
				_fill(img, x + 4 + posmod(y / 5, 4), y, 1, 1, WOOD[0])
		# Carved rings.
		for y in range(-DAIS_HIGH - 40, top, -36):
			_fill(img, x - 1, y, PILLAR_WIDE + 2, 5, OUTLINE)
			_fill(img, x - 1, y + 1, PILLAR_WIDE + 2, 3, WOOD[1])
			_fill(img, x - 1, y + 1, PILLAR_WIDE + 2, 1, WOOD[2])
			_fill(img, x + PILLAR_WIDE - 2, y + 2, 3, 2, WOOD[0])
		# A foot block on the dais.
		_fill(img, x - 3, -DAIS_HIGH - 9, PILLAR_WIDE + 6, 9, OUTLINE)
		_fill(img, x - 2, -DAIS_HIGH - 8, PILLAR_WIDE + 4, 8, WOOD[1])
		_fill(img, x - 2, -DAIS_HIGH - 8, PILLAR_WIDE + 4, 1, WOOD[2])
		_fill(img, x + PILLAR_WIDE - 1, -DAIS_HIGH - 7, 3, 7, WOOD[0])


## A round shield: an iron rim, a board face, an iron boss. `squash` narrows
## one that leans.
static func _shield(img: Image, at: Vector2i, squash: float) -> void:
	var r := float(SHIELD_RADIUS)
	for dy in range(-SHIELD_RADIUS, SHIELD_RADIUS + 1):
		for dx in range(-SHIELD_RADIUS, SHIELD_RADIUS + 1):
			var d := Vector2(dx / squash, dy).length()
			if d > r + 0.3:
				continue
			var col := WOOD[1]
			if d > r - 1.0:
				col = OUTLINE
			elif d > r - 3.6:
				col = STONE[2] if dx + dy < -4 else (STONE[0] if dx + dy > 6 else STONE[1])
			elif d < 1.6:
				col = STONE[3]
			elif d < 3.6:
				col = STONE[2] if dx + dy < 0 else STONE[1]
			elif d < 4.6:
				col = OUTLINE
			elif posmod(dx + 40, 6) == 0:
				col = WOOD[0]  # the boards
			elif dx + dy < -8:
				col = WOOD[2]
			_fill(img, at.x + dx, at.y + dy, 1, 1, col)


static func _shields(img: Image) -> void:
	# The strap the hung one hangs by, and its nail.
	_fill(img, SHIELD_HUNG.x, SHIELD_HUNG.y - SHIELD_RADIUS - 5, 1, 6, WOOD[0])
	_fill(img, SHIELD_HUNG.x - 1, SHIELD_HUNG.y - SHIELD_RADIUS - 7, 3, 3, OUTLINE)
	_fill(img, SHIELD_HUNG.x, SHIELD_HUNG.y - SHIELD_RADIUS - 6, 1, 1, STONE[3])
	_shield(img, SHIELD_HUNG, 1.0)
	# The other's nail, bare.
	_fill(img, SHIELD_NAIL.x - 1, SHIELD_NAIL.y - 1, 3, 3, OUTLINE)
	_fill(img, SHIELD_NAIL.x, SHIELD_NAIL.y, 1, 1, STONE[3])
	_shield(img, SHIELD_FALLEN, 0.7)


static func _seat(img: Image) -> void:
	# The back: boards, a stepped crest, its east half dropped.
	for x in range(-BACK_HALF, BACK_HALF):
		var top := back_top(x)
		_fill(img, x, top - 1, 1, 1, OUTLINE)
		for y in range(top, SEAT_TOP):
			var col := WOOD[1]
			if x == -BACK_HALF or x == BACK_HALF - 1 or posmod(x + BACK_HALF, 11) == 10:
				col = OUTLINE
			elif posmod(x + BACK_HALF, 11) == 0 or y == top:
				col = WOOD[2]
			elif posmod(x + BACK_HALF, 11) == 9:
				col = WOOD[0]
			elif speckle(x, y / 6) > 0.88:
				col = WOOD[0]
			_fill(img, x, y, 1, 1, col)
	# The crest's steps are outlined down their sides.
	for x in range(-BACK_HALF, BACK_HALF - 1):
		var a := back_top(x)
		var b := back_top(x + 1)
		if a != b:
			_fill(img, x if a > b else x + 1, mini(a, b), 1, absi(a - b), OUTLINE)
	# A rail across the back.
	for x in range(-BACK_HALF + 1, BACK_HALF - 1):
		var y := BACK_TOP + 14 + (BACK_DROP if x >= root_x(BACK_TOP) else 0)
		_fill(img, x, y, 1, 1, OUTLINE)
		_fill(img, x, y + 1, 1, 1, WOOD[2])
		_fill(img, x, y + 2, 1, 2, WOOD[1])
		_fill(img, x, y + 4, 1, 1, OUTLINE)
	# The arms.
	for side: int in [-1, 1]:
		var x := side * SEAT_HALF - 2
		_fill(img, x - 1, SEAT_TOP - 23, 6, 23, OUTLINE)
		_fill(img, x, SEAT_TOP - 22, 4, 22, WOOD[1])
		_fill(img, x, SEAT_TOP - 22, 1, 22, WOOD[2])
		_fill(img, x + 3, SEAT_TOP - 22, 1, 22, WOOD[0])
		_fill(img, x - 3, SEAT_TOP - 26, 10, 5, OUTLINE)
		_fill(img, x - 2, SEAT_TOP - 25, 8, 3, WOOD[1])
		_fill(img, x - 2, SEAT_TOP - 25, 8, 1, WOOD[2])
	# The box under the seat board, on the dais.
	_fill(img, -SEAT_HALF - 1, SEAT_TOP, SEAT_HALF * 2 + 2, -DAIS_HIGH - SEAT_TOP, OUTLINE)
	for x in range(-SEAT_HALF, SEAT_HALF):
		var k := posmod(x + SEAT_HALF, 8)
		var col := WOOD[1]
		if k == 7:
			col = OUTLINE
		elif k == 0:
			col = WOOD[2]
		elif k == 6:
			col = WOOD[0]
		_fill(img, x, SEAT_TOP + 1, 1, -DAIS_HIGH - SEAT_TOP - 1, col)
	_fill(img, -SEAT_HALF, -DAIS_HIGH - 3, SEAT_HALF * 2, 3, WOOD[0])
	# The seat board.
	_fill(img, -SEAT_HALF - 3, SEAT_TOP - 3, SEAT_HALF * 2 + 6, 5, OUTLINE)
	_fill(img, -SEAT_HALF - 2, SEAT_TOP - 2, SEAT_HALF * 2 + 4, 3, WOOD[1])
	_fill(img, -SEAT_HALF - 2, SEAT_TOP - 2, SEAT_HALF * 2 + 4, 1, WOOD[2])


## Whether the lintel has a column at `x`: it is gone where the root is.
static func lintel_at(x: int) -> bool:
	return absi(x) < LINTEL_HALF and absi(x - lintel_break()) > root_half(LINTEL_TOP) + 1


static func _lintel(img: Image) -> void:
	var gap := root_half(LINTEL_TOP) + 1
	for x in range(-LINTEL_HALF, LINTEL_HALF):
		if not lintel_at(x):
			continue
		var top := LINTEL_TOP - lintel_lift(x)
		# Splinters at the break.
		var near := absi(x - lintel_break()) - gap
		for row in LINTEL_DEEP:
			if near <= 3 and posmod(row * 5 + x * 3, 5) > near + 1:
				continue
			var col := WOOD[1]
			if row == 0 or row == LINTEL_DEEP - 1:
				col = OUTLINE
			elif row == 1:
				col = WOOD[2]
			elif row == LINTEL_DEEP - 2:
				col = WOOD[0]
			elif row >= 4 and row <= 11:
				# A carved zigzag along its face.
				var zig := posmod(x + LINTEL_HALF, 12)
				var want := 4 + (zig if zig < 6 else 12 - zig)
				if row == want:
					col = OUTLINE
				elif row == want + 1:
					col = WOOD[2]
			_fill(img, x, top + row, 1, 1, col)
	# Its ends.
	_fill(img, -LINTEL_HALF - 1, LINTEL_TOP, 1, LINTEL_DEEP, OUTLINE)
	_fill(img, LINTEL_HALF, LINTEL_TOP, 1, LINTEL_DEEP, OUTLINE)


## The timber rots where the root touches it, and nowhere else.
static func _rot(img: Image) -> void:
	for y in range(CEILING, -DAIS_HIGH):
		var cx := root_x(y)
		var hw := root_half(y)
		for x in range(cx - hw - ROT_REACH, cx + hw + ROT_REACH + 1):
			var c := _px(img, x, y)
			if c != WOOD[1] and c != WOOD[2]:
				continue
			var d := float(absi(x - cx) - hw) / float(ROT_REACH)
			var s := speckle(x / 2 + 7, y / 2)
			if s > 0.55 + d * 0.5:
				_fill(img, x, y, 1, 1, ROT[1] if speckle(x, y) > 0.7 and c == WOOD[2] else ROT[0])


## A side root along `pts`, `wide` px thick.
static func _limb(img: Image, pts: Array[Vector2i], wide: int) -> void:
	for step in 2:
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
			for k in n + 1:
				var f := float(k) / maxf(n, 1.0)
				var x := roundi(lerpf(a.x, b.x, f))
				var y := roundi(lerpf(a.y, b.y, f))
				if step == 0:
					_fill(img, x - 1, y - 1, wide + 2, wide + 2, OUTLINE)
				else:
					_fill(img, x, y, wide, wide, ROOT[1])
					_fill(img, x, y, 1, 1, ROOT[2])
					_fill(img, x + wide - 1, y + wide - 1, 1, 1, ROOT[0])


## How lit the root's surface is at column `x` of row `y`, from 0 to 1: the
## normal of a round trunk, leaning with the root where it wanders.
static func root_light(x: int, y: int) -> float:
	var cx := root_x(y)
	var hw := root_half(y)
	var u := clampf((float(x - cx) + 0.5) / float(hw), -1.0, 1.0)
	var lean := float(root_x(y - 3) - root_x(y + 3)) / 6.0
	var n := Vector3(u, -lean * 0.4, sqrt(maxf(0.0, 1.0 - u * u))).normalized()
	return clampf(n.dot(LIGHT.normalized()), 0.0, 1.0)


## Where the bark furrow `k` crosses row `y`, round the root in radians
## (0 faces the viewer). The furrows go all the way round, `FURROW_STEP`
## apart, and twist as the root climbs.
static func furrow_angle(k: int, y: int) -> float:
	return furrow_offset(y) + FURROW_STEP * k


## The twist of the furrows at row `y`.
static func furrow_offset(y: int) -> float:
	return TWIST * float(y) + 0.12 * sin(float(y) * 0.05)


## The root's shade at a pixel: the tone from its roundness, its bark's
## furrows and plates on top.
static func root_tone(x: int, y: int) -> Color:
	var cx := root_x(y)
	var hw := root_half(y)
	if x == cx - hw:
		return ROOT[2]
	if x == cx + hw - 1:
		return ROOT[0]
	var l := root_light(x, y)
	# A lit band left of the middle, the mid tone, and the shaded east third,
	# the edge between mid and shade broken in a checker.
	var col := ROOT[0]
	if l > 0.88:
		col = ROOT[2]
	elif l > 0.5 or (l > 0.4 and posmod(x + y, 2) == 0):
		col = ROOT[1]
	# The furrows: lines round the trunk, closer together toward its edges,
	# each broken here and there so they read as bark, not stripes.
	var u := clampf((float(x - cx) + 0.5) / float(hw), -1.0, 1.0)
	var round_a := asin(u) - furrow_offset(y)
	var k := roundi(round_a / FURROW_STEP)
	if absf(round_a - k * FURROW_STEP) * float(hw) < 0.55 and speckle(k * 5 + 1, (y + k * 7) / 9) < 0.78:
		if l > 0.88:
			return ROOT[1]
		return ROOT[0] if l > 0.4 else OUTLINE
	# The plates between the furrows: each breaks off every 14 to 24 rows; its
	# foot is in shadow and its top lip catches the light on the lit side.
	var band := floori(round_a / FURROW_STEP)
	var tall := 14 + roundi(speckle(band + 40, 3) * 10.0)
	var row := posmod(y + roundi(speckle(band + 40, 9) * 23.0), tall)
	if row == tall - 1 and l > 0.4:
		return ROOT[0]
	if row == 0 and l > 0.88:
		return BARK_LIT
	return col


## The root's shadow falls east on the timber it stands in front of.
static func _cast(img: Image) -> void:
	for y in range(CEILING, -DAIS_HIGH):
		var e := root_x(y) + root_half(y) + 1
		for x in range(e, e + CAST):
			var c := _px(img, x, y)
			if c == WOOD[1] or c == WOOD[2]:
				_fill(img, x, y, 1, 1, WOOD[0])
			elif c == ROT[1]:
				_fill(img, x, y, 1, 1, ROT[0])


static func _root(img: Image) -> void:
	# The east side root reaches the east pillar; the west one comes up
	# through the dais beside the seat and grips its arm.
	var east: Array[Vector2i] = []
	for x in range(SIDE_EAST_FROM.x, SIDE_EAST_TO.x - 1, 2):
		east.append(Vector2i(x, side_east_y(x)))
	_limb(img, east, 3)
	_limb(img, [Vector2i(-SEAT_HALF - 9, -4), Vector2i(-SEAT_HALF - 8, SEAT_TOP - 20), Vector2i(-SEAT_HALF - 3, SEAT_TOP - 30), Vector2i(root_x(-84) - 4, -84)], 4)
	for y in range(CEILING, 0):
		var cx := root_x(y)
		var hw := root_half(y)
		_fill(img, cx - hw - 1, y, hw * 2 + 2, 1, OUTLINE)
		for x in range(cx - hw, cx + hw):
			_fill(img, x, y, 1, 1, root_tone(x, y))
	# The knots: a ring of bark round a dark hollow, its upper left lip lit.
	for knot: Vector3i in KNOTS:
		var ky := knot.x
		var kx := root_x(ky) + roundi(float(knot.y) / 10.0 * root_half(ky))
		var r := float(knot.z)
		for dy in range(-knot.z - 1, knot.z + 2):
			for dx in range(-knot.z - 1, knot.z + 2):
				var d := Vector2(dx, dy * 1.3).length()
				if d > r + 0.6:
					continue
				var col := ROOT[1]
				if d < r * 0.45:
					col = OUTLINE
				elif d < r * 0.75:
					col = ROOT[0]
				elif dx + dy < -1:
					col = ROOT[2]
				elif dx + dy > 1:
					col = ROOT[0]
				_fill(img, kx + dx, ky + dy, 1, 1, col)
	# The dais it came through: a slab heaved up on each side of it.
	var hw0 := root_half(-DAIS_HIGH)
	for side: int in [-1, 1]:
		for k in 12:
			var x := root_x(-DAIS_HIGH) + side * (hw0 + 1 + k)
			var lift := (12 - k) / 3
			_fill(img, x, -DAIS_HIGH - lift - 1, 1, 1, OUTLINE)
			_fill(img, x, -DAIS_HIGH - lift, 1, 1, STONE[2])
			_fill(img, x, -DAIS_HIGH - lift + 1, 1, lift + 2, STONE[1])
		_fill(img, root_x(-DAIS_HIGH) + side * (hw0 + 13), -DAIS_HIGH, 1, 3, STONE[0])


## The rows where sap runs down the root's lit side begin.
static func sap_runs() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for k in 7:
		# x: the first row; y: its length; z: its column from the root's west edge.
		out.append(Vector3i(-52 - k * 33, 9 + posmod(k * 7, 9), 2 + posmod(k * 3, 4)))
	return out


static func _sap(img: Image) -> void:
	for run: Vector3i in sap_runs():
		for k in run.y:
			var y := run.x + k
			var x := root_x(y) - root_half(y) + run.z
			_fill(img, x, y, 1, 1, SAP[2] if k == 0 else SAP[1])
		# A bead at its foot.
		var foot := run.x + run.y
		var fx := root_x(foot) - root_half(foot) + run.z
		_fill(img, fx, foot, 2, 2, SAP[1])
		_fill(img, fx, foot + 2, 2, 1, SAP[0])
		_fill(img, fx, foot, 1, 1, SAP[2])
	# The pool on the seat board, east of the root.
	for x in range(POOL.x, POOL.y):
		var f := float(x - POOL.x) / float(POOL.y - POOL.x - 1)
		var high := maxi(1, roundi(POOL_HIGH * (1.0 - f * f)))
		for k in high:
			var col := SAP[1]
			if k == high - 1:
				col = SAP[2] if speckle(x, 11) > 0.45 else SAP[1]
			elif k == 0:
				col = SAP[0]
			_fill(img, x, SEAT_TOP - 3 - k, 1, 1, col)
	# The puddle on the dais under the drip.
	for x in range(DRIP_X - PUDDLE_HALF, DRIP_X + PUDDLE_HALF + 1):
		_fill(img, x, -DAIS_HIGH - 1, 1, 1, SAP[1] if absi(x - DRIP_X) < PUDDLE_HALF - 1 else SAP[0])
	_fill(img, DRIP_X - 2, -DAIS_HIGH - 2, 4, 1, SAP[1])
	_fill(img, DRIP_X - 1, -DAIS_HIGH - 2, 1, 1, SAP[2])


## The high seat, baked.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	_dais(img)
	_pillars(img)
	_shields(img)
	_seat(img)
	_lintel(img)
	_rot(img)
	_cast(img)
	_root(img)
	_sap(img)
	return img


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	# A bead swells under the side root, then falls.
	var phase := fposmod(t, DRIP_PERIOD) / DRIP_PERIOD
	var y := roundf(drip_y(t))
	if phase < 0.5:
		draw_rect(Rect2(DRIP_X - 1, y, 2, 1 + roundf(phase * 4.0)), SAP[1])
	else:
		draw_rect(Rect2(DRIP_X - 1, y, 2, 3), SAP[1])
		draw_rect(Rect2(DRIP_X - 1, y, 1, 1), SAP[2])
