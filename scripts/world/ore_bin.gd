class_name OreBin
extends Node2D
## Ore Bin 3 (room prop `ore_bin`, pass 574, bible 12.61), a Tower landmark:
## a plank bin on four timber posts with an iron hopper under it, a boxed
## chute down into it from the ceiling, and a slide gate over the floor. The
## room's sign says "The bin is half full still. Nobody came to empty it":
## four planks of its front have sprung, and through the breach the ore lies
## to half the bin's height under a dark empty half. The gate was left a crack
## open and a low spill lies under the spout. East of the bin the winch's
## kibble hangs on its chain and sways ("sorted ore up the winch").
##
## Painted like the ore road (12.60): whole world pixels on master palette
## ramps, lit from the upper left, baked once. Only the kibble and its chain
## are drawn live. Scenery only. The origin is the floor under the bin's
## middle.

const OUTLINE := Color("120f19")  # night-0
## Timber, shade to lit (wood-1 to wood-3).
const WOOD: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56")]
## Iron, dark to lit (stone-1 to stone-4).
const IRON: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## Rust on the hopper (bark-2).
const RUST := Color("783c2b")
## The ore (ochre-1 to ochre-4).
const ORE: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44"), Color("bea860")]
## Every tone above, for the palette test.
const TONES := [OUTLINE, WOOD[0], WOOD[1], WOOD[2], IRON[0], IRON[1], IRON[2], IRON[3], RUST, ORE[0], ORE[1], ORE[2], ORE[3]]

## The plank box: its half width, its top and its foot.
const BOX_HALF := 48
const BOX_TOP := -176
const BOX_FOOT := -104
const PLANK := 8
## The posts: how far each stands from the middle, and how wide it is.
const POST_X := 52
const POST_WIDE := 8
## The cap beam over the box.
const CAP_DEEP := 6
## The hopper under the box narrows to the spout.
const SPOUT_Y := -52
const SPOUT_HALF := 9
## The slide gate under the spout, and the crack it was left open.
const GATE_DEEP := 5
## The breach in the front: the sprung planks (from the top, first and last)
## and the columns they are gone from.
const BREACH_PLANKS := Vector2i(1, 4)
const BREACH := Vector2i(-28, 14)
## The top of the ore inside, at the bin's middle height.
const ORE_LINE := -140
## The spill on the floor under the spout.
const SPILL_HALF := 24
const SPILL_HIGH := 8
## The chute: its middle at the ceiling and at the bin's mouth, its half width.
const CHUTE_TOP := Vector2i(-40, -256)
const CHUTE_FOOT := Vector2i(-12, BOX_TOP - CAP_DEEP)
const CHUTE_HALF := 8
## The underside of the room's ceiling, from the origin.
const CEILING := -256
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-64, -256, 128, 256)
## The kibble's chain: where it hangs from the ceiling, and its length.
const CHAIN_TOP := Vector2(84, CEILING)
const CHAIN_LENGTH := 96.0

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


## The hopper's half width at row `y`: the box's at its foot, the spout's at the gate.
static func hopper_half(y: int) -> int:
	return roundi(lerpf(BOX_HALF, SPOUT_HALF, clampf(float(y - BOX_FOOT) / float(SPOUT_Y - BOX_FOOT), 0.0, 1.0)))


## The chute's middle at row `y`.
static func chute_x(y: int) -> int:
	var f := clampf(float(y - CHUTE_TOP.y) / float(CHUTE_FOOT.y - CHUTE_TOP.y), 0.0, 1.0)
	return roundi(lerpf(CHUTE_TOP.x, CHUTE_FOOT.x, f))


## The top of the ore inside at column `x`: heaped a little under the chute.
static func ore_top(x: int) -> int:
	var d := float(x - CHUTE_FOOT.x) / float(BOX_HALF)
	return ORE_LINE - 3 + roundi(6.0 * minf(d * d, 1.0))


## Whether the front plank at (`x`, `y`) has sprung: inside the breach, whose
## ends are ragged plank by plank.
static func breached(x: int, y: int) -> bool:
	if y < BOX_TOP or y >= BOX_FOOT:
		return false
	var plank := (y - BOX_TOP) / PLANK
	if plank < BREACH_PLANKS.x or plank > BREACH_PLANKS.y:
		return false
	var west := BREACH.x + posmod(plank * 7, 9) - 4
	var east := BREACH.y + posmod(plank * 5, 11) - 5
	return x >= west and x < east


## How high the spill stands at column `x`.
static func spill_high(x: int) -> int:
	var f := float(x) / SPILL_HALF
	if absf(f) >= 1.0:
		return 0
	return roundi(SPILL_HIGH * (1.0 - f * f))


## A fixed speckle, 0 to 1.
static func speckle(x: int, y: int) -> float:
	return float(posmod((x * 73856093) ^ (y * 19349663), 97)) / 96.0


static func _fill(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x - IMG.position.x, y - IMG.position.y, w, h).intersection(Rect2i(Vector2i.ZERO, IMG.size))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col)


## A timber lying level: outlined, lit along its top, shaded along its bottom.
static func _timber(img: Image, x: int, y: int, w: int, h: int) -> void:
	_fill(img, x - 1, y - 1, w + 2, h + 2, OUTLINE)
	_fill(img, x, y, w, h, WOOD[1])
	_fill(img, x, y, w, 1, WOOD[2])
	_fill(img, x, y + h - 1, w, 1, WOOD[0])


## A thin brace from `a` to `b`, three pixels wide, in the shade behind the hopper.
static func _brace(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in steps + 1:
		var f := float(k) / maxf(steps, 1.0)
		_fill(img, roundi(lerpf(a.x, b.x, f)) - 1, roundi(lerpf(a.y, b.y, f)), 3, 1, col)


## One lump of ore at a cell: mostly its body, darker and lighter lumps among it.
static func _ore_tone(x: int, y: int) -> Color:
	var lump := speckle((x + 90) / 3 + y / 2, (x + 90) / 2 - y / 3)
	if lump > 0.7:
		return ORE[0]
	if lump < 0.28:
		return ORE[2]
	return ORE[1]


static func _frame(img: Image) -> void:
	# Behind everything: a cross between the posts, under the box.
	_brace(img, Vector2i(-POST_X + 4, BOX_FOOT + 6), Vector2i(POST_X - 4, -10), WOOD[0])
	_brace(img, Vector2i(POST_X - 4, BOX_FOOT + 6), Vector2i(-POST_X + 4, -10), WOOD[1])
	# The posts, from the floor to the cap, lit down their left.
	for side: int in [-1, 1]:
		var x := side * POST_X - POST_WIDE / 2
		_fill(img, x - 1, BOX_TOP, POST_WIDE + 2, -BOX_TOP, OUTLINE)
		_fill(img, x, BOX_TOP, POST_WIDE, -BOX_TOP, WOOD[1])
		_fill(img, x, BOX_TOP, 2, -BOX_TOP, WOOD[2])
		_fill(img, x + POST_WIDE - 2, BOX_TOP, 2, -BOX_TOP, WOOD[0])
		for y in range(BOX_TOP, 0):
			if speckle(x, y / 4) > 0.86:
				_fill(img, x + 3 + posmod(y, 2), y, 1, 1, WOOD[0])
		# A stone footing under each.
		_fill(img, side * POST_X - 8, -5, 16, 5, OUTLINE)
		_fill(img, side * POST_X - 7, -4, 14, 4, IRON[1])
		_fill(img, side * POST_X - 7, -4, 14, 1, IRON[2])
	# A low tie between the posts, behind the spout.
	_timber(img, -POST_X + POST_WIDE / 2 + 1, -30, (POST_X - POST_WIDE / 2 - 1) * 2, 4)


static func _box(img: Image) -> void:
	_fill(img, -BOX_HALF, BOX_TOP - 1, BOX_HALF * 2, BOX_FOOT - BOX_TOP + 2, OUTLINE)
	for y in range(BOX_TOP, BOX_FOOT):
		var row := posmod(y - BOX_TOP, PLANK)
		var plank := (y - BOX_TOP) / PLANK
		for x in range(-BOX_HALF, BOX_HALF):
			var col := WOOD[1]
			if breached(x, y):
				# Inside: the ore to half the bin's height, the dark over it.
				var top := ore_top(x)
				if y < top:
					# The back wall's planks, far in the dark.
					col = OUTLINE if posmod(y - BOX_TOP, PLANK) == PLANK - 1 or y < top - 14 else IRON[0]
				elif y == top:
					col = ORE[3] if speckle(x, 3) > 0.4 else ORE[2]
				elif y == top + 1 and speckle(x, 9) > 0.5:
					col = ORE[2]
				else:
					col = _ore_tone(x, y)
				# The sprung planks' ends throw a shadow on what is inside.
				if not breached(x - 1, y) or not breached(x, y - 1):
					col = OUTLINE
			elif row == PLANK - 1:
				col = OUTLINE
			elif row == 0:
				col = WOOD[2]
			elif row == PLANK - 2:
				col = WOOD[0]
			elif posmod(x + plank * 23, 37) == 0:
				col = OUTLINE  # a butt joint
			elif speckle(x / 4, y) > 0.9:
				col = WOOD[0]  # the grain
			img.set_pixel(x - IMG.position.x, y - IMG.position.y, col)
	# Two iron straps down the front, a rivet in each plank.
	for sx: int in [-40, 38]:
		_fill(img, sx - 1, BOX_TOP, 5, BOX_FOOT - BOX_TOP, OUTLINE)
		_fill(img, sx, BOX_TOP, 3, BOX_FOOT - BOX_TOP, IRON[1])
		_fill(img, sx, BOX_TOP, 1, BOX_FOOT - BOX_TOP, IRON[2])
		for y in range(BOX_TOP + 3, BOX_FOOT, PLANK):
			_fill(img, sx + 1, y, 1, 1, IRON[3])
	# A sprung plank hangs by one end from the breach's east side.
	var hang := Vector2i(BREACH.y + 2, BOX_TOP + BREACH_PLANKS.y * PLANK + 4)
	for k in 22:
		var p := hang + Vector2i(-roundi(k * 0.35), k)
		_fill(img, p.x - 3, p.y, 7, 1, OUTLINE)
		_fill(img, p.x - 2, p.y, 5, 1, WOOD[1])
		_fill(img, p.x - 2, p.y, 1, 1, WOOD[2])
		_fill(img, p.x + 2, p.y, 1, 1, WOOD[0])
	# The cap beam over the box and the posts.
	_timber(img, -POST_X - POST_WIDE / 2 - 2, BOX_TOP - CAP_DEEP, POST_X * 2 + POST_WIDE + 4, CAP_DEEP)


static func _hopper(img: Image) -> void:
	for y in range(BOX_FOOT, SPOUT_Y):
		var hw := hopper_half(y)
		_fill(img, -hw - 1, y, hw * 2 + 2, 1, OUTLINE)
		_fill(img, -hw, y, hw * 2, 1, IRON[1])
		_fill(img, -hw, y, maxi(2, hw / 5), 1, IRON[2])
		_fill(img, hw - maxi(3, hw / 3), y, maxi(3, hw / 3), 1, IRON[0])
		for x in range(-hw + 3, hw - 2):
			if x > -4 and speckle(x / 3, y / 2) > 0.88:
				_fill(img, x, y, 1, 1, RUST)
	# The angle iron where the hopper hangs from the box, riveted.
	_fill(img, -BOX_HALF - 1, BOX_FOOT - 1, BOX_HALF * 2 + 2, 5, OUTLINE)
	_fill(img, -BOX_HALF, BOX_FOOT, BOX_HALF * 2, 3, IRON[2])
	_fill(img, -BOX_HALF, BOX_FOOT, BOX_HALF * 2 - 10, 1, IRON[3])
	for x in range(-BOX_HALF + 4, BOX_HALF - 2, 8):
		_fill(img, x, BOX_FOOT + 1, 1, 1, IRON[0])
	# A plate seam across its middle.
	var seam := (BOX_FOOT + SPOUT_Y) / 2
	_fill(img, -hopper_half(seam), seam, hopper_half(seam) * 2, 1, IRON[0])
	for x in range(-hopper_half(seam) + 4, hopper_half(seam) - 3, 6):
		_fill(img, x, seam - 1, 1, 1, IRON[3])
	# The slide gate: a plate across the spout, a lever out to the east.
	var gate := SPOUT_HALF + 4
	_fill(img, -gate - 1, SPOUT_Y - 1, gate * 2 + 2, GATE_DEEP + 2, OUTLINE)
	_fill(img, -gate, SPOUT_Y, gate * 2, GATE_DEEP, IRON[1])
	_fill(img, -gate, SPOUT_Y, gate * 2, 1, IRON[3])
	_fill(img, -gate, SPOUT_Y + GATE_DEEP - 1, gate * 2, 1, IRON[0])
	_fill(img, gate, SPOUT_Y, 16, 4, OUTLINE)
	_fill(img, gate, SPOUT_Y + 1, 15, 2, IRON[2])
	_fill(img, gate + 13, SPOUT_Y - 4, 5, 10, OUTLINE)
	_fill(img, gate + 14, SPOUT_Y - 3, 3, 8, WOOD[1])
	_fill(img, gate + 14, SPOUT_Y - 3, 1, 8, WOOD[2])
	# The gate was left a crack open: a thread of ore falls to the spill.
	for y in range(SPOUT_Y + GATE_DEEP + 1, -spill_high(-3)):
		if speckle(1, y) > 0.35:
			_fill(img, -3 + (1 if speckle(2, y) > 0.7 else 0), y, 1, 1, ORE[2] if speckle(3, y) > 0.5 else ORE[1])
	# The spill on the floor under it.
	for x in range(-SPILL_HALF, SPILL_HALF + 1):
		var high := spill_high(x)
		if high <= 0:
			continue
		_fill(img, x, -high - 1, 1, 1, OUTLINE)
		for k in high:
			var y := -1 - k
			var col := _ore_tone(x, y)
			if k == high - 1 and x < 6:
				col = ORE[3] if speckle(x, 5) > 0.45 else ORE[2]
			_fill(img, x, y, 1, 1, col)
	_fill(img, -SPILL_HALF, -1, 1, 1, OUTLINE)
	_fill(img, SPILL_HALF, -1, 1, 1, OUTLINE)


static func _chute(img: Image) -> void:
	for y in range(CHUTE_TOP.y, CHUTE_FOOT.y):
		var cx := chute_x(y)
		_fill(img, cx - CHUTE_HALF - 1, y, CHUTE_HALF * 2 + 2, 1, OUTLINE)
		_fill(img, cx - CHUTE_HALF, y, CHUTE_HALF * 2, 1, WOOD[1])
		_fill(img, cx - CHUTE_HALF, y, 2, 1, WOOD[2])
		_fill(img, cx + CHUTE_HALF - 3, y, 3, 1, WOOD[0])
		# The boards run down it.
		_fill(img, cx - 2, y, 1, 1, WOOD[0])
		_fill(img, cx + 2, y, 1, 1, WOOD[0] if speckle(3, y / 5) > 0.3 else WOOD[1])
		# An iron band every so often.
		if posmod(y - CHUTE_TOP.y, 24) >= 10 and posmod(y - CHUTE_TOP.y, 24) < 13:
			var k := posmod(y - CHUTE_TOP.y, 24) - 10
			_fill(img, cx - CHUTE_HALF, y, CHUTE_HALF * 2, 1, [IRON[2], IRON[1], IRON[0]][k])
			if k == 1:
				_fill(img, cx - CHUTE_HALF + 2, y, 1, 1, IRON[3])
				_fill(img, cx + CHUTE_HALF - 4, y, 1, 1, IRON[3])


## The bin, baked.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	_frame(img)
	_chute(img)
	_hopper(img)
	_box(img)
	return img


## Where the chain's `i`th link hangs at time `at`: still at the ceiling,
## swinging more toward the kibble.
static func chain_point(i: int, at: float) -> Vector2:
	var h := i * 3.0
	var sway := sin(at * 0.7 - h * 0.03) * 4.0 * pow(h / CHAIN_LENGTH, 1.5)
	return CHAIN_TOP + Vector2(roundf(sway), h)


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	var links := int(CHAIN_LENGTH / 3.0)
	for i in links + 1:
		var p := chain_point(i, t)
		if i % 2 == 0:
			draw_rect(Rect2(p.x - 2, p.y, 4, 3), OUTLINE)
			draw_rect(Rect2(p.x - 1, p.y, 2, 3), IRON[2])
		else:
			draw_rect(Rect2(p.x - 1, p.y, 2, 3), OUTLINE)
			draw_rect(Rect2(p.x - 1, p.y, 1, 3), IRON[1])
	# The kibble: a bail, and an iron bucket wider at its rim, empty.
	var end := chain_point(links, t) + Vector2(0, 3)
	draw_rect(Rect2(end.x - 8, end.y, 16, 2), OUTLINE)
	draw_rect(Rect2(end.x - 8, end.y, 2, 7), OUTLINE)
	draw_rect(Rect2(end.x + 6, end.y, 2, 7), OUTLINE)
	for k in 14:
		var hw := 9 - k / 4
		var y := end.y + 6 + k
		draw_rect(Rect2(end.x - hw - 1, y, hw * 2 + 2, 1), OUTLINE)
		draw_rect(Rect2(end.x - hw, y, hw * 2, 1), IRON[1])
		draw_rect(Rect2(end.x - hw, y, 2, 1), IRON[2])
		draw_rect(Rect2(end.x + hw - 3, y, 3, 1), IRON[0])
	draw_rect(Rect2(end.x - 10, end.y + 5, 20, 3), OUTLINE)
	draw_rect(Rect2(end.x - 9, end.y + 6, 18, 1), IRON[3])
	draw_rect(Rect2(end.x - 7, end.y + 12, 14, 1), IRON[0])
	draw_rect(Rect2(end.x - 8, end.y + 20, 16, 1), OUTLINE)
