class_name OreRoad
extends Node2D
## The ore road of the Rail Gallery (room prop `ore_road`, pass 573, bible
## 12.60), a Tower landmark: a rail carried the length of the gallery under its
## ceiling on eight timber bents, the road the carts ran east on to the Haar
## cut. One loaded cart still stands on it. East of the cart a span has
## fallen: the stringer is snapped, the rail hangs bent into the gap and a
## timber lies on the floor below. A hoist chain with a hook hangs from the
## deck and sways. The room's sign had told of the ore road and its carts
## since the room was made; nothing was drawn.
##
## Painted like the crucible (12.35) and the great gears (12.57): whole world
## pixels on master palette ramps, lit from the upper left, baked once. Only
## the chain is drawn live. Scenery only. The origin is the floor under the
## prop's tile, at the gallery's west end; the road runs east from it. Since
## pass 577 the floor under it is not level: see `FOOT_Y`.

const OUTLINE := Color("120f19")  # night-0
## Timber, shade to lit (wood-1 to wood-3).
const WOOD: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56")]
## Iron, dark to lit (stone-1 to stone-4).
const IRON: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## Rust on the rail and the cart (bark-2).
const RUST := Color("783c2b")
## The ore in the cart (ochre-1 to ochre-4).
const ORE: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44"), Color("bea860")]
## Every tone above, for the palette test.
const TONES := [OUTLINE, WOOD[0], WOOD[1], WOOD[2], IRON[0], IRON[1], IRON[2], IRON[3], RUST, ORE[0], ORE[1], ORE[2], ORE[3]]

## The road's two ends, from the origin: the faces of the gallery's walls.
const WEST := -8
const EAST := 1240
## The top of the rail, and the rows under it: the rail, the sleepers that
## carry it, the stringer that carries them.
const RAIL_Y := -216
const RAIL_DEEP := 2
const SLEEPER_DEEP := 3
const STRINGER_DEEP := 7
## The underside of the stringer, where the bents' caps sit.
const DECK_BOTTOM := RAIL_Y + RAIL_DEEP + SLEEPER_DEEP + STRINGER_DEEP
## A sleeper every this many pixels, this wide.
const SLEEPER_STEP := 12
const SLEEPER_WIDE := 6
## Where each bent stands (its middle), from the origin. They stand clear of
## the gallery's pillar and of the way down to the vault.
const BENTS: Array[int] = [128, 256, 400, 544, 688, 832, 992, 1168]
## The floor under each bent's two feet, from the origin (pass 577, bible
## 12.64): the gallery's floor is no longer level, and the trestle crosses
## it as a trestle does, on legs of the length each footing needs. The second
## and third bents stand in the dip (a tile down), the fifth in the spiked pit
## (two tiles down).
const FOOT_Y: Array[int] = [0, 16, 16, 0, 32, 0, 0, 0]
## Where the origin stands in the room (the middle of the prop's tile, 1),
## and the pit's two walls in room pixels: what fell from the span lies west
## of its brink.
const PROP_X := 24
const PIT := Vector2i(640, 800)
## The deepest footing: the baked image reaches this far under the origin.
const DEEPEST := 32
## A bent whose feet stand this far or more under the last girt gets a sill
## girt, and a cross in the tier it makes.
const SILL_FROM := 70
const SILL_STEP := 54
## How far a bent's legs stand from its middle, at the cap and at the floor.
const LEG_TOP := 5
const LEG_FOOT := 16
## The rows of a bent's three girts (their top row).
const GIRTS: Array[int] = [-150, -96, -42]
## The fallen span: no deck from here to here.
const BREAK := Vector2i(590, 650)
## How far the bent rail reaches into the gap, and how far its end hangs.
const DROOP_REACH := 26
const DROOP := 18
## The cart: its middle, and its tub (top half width, bottom half width, depth).
const CART_X := 328
const TUB_TOP := 17
const TUB_FOOT := 13
const TUB_DEEP := 16
const WHEEL_R := 4
## The underside of the room's ceiling, from the origin.
const CEILING := -256
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(WEST, -252, EAST - WEST, 252 + DEEPEST)
## The hoist chain: where it hangs from the stringer, and its length.
const CHAIN_TOP := Vector2(470, DECK_BOTTOM)
const CHAIN_LENGTH := 60.0

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


## Whether the deck stands at column `x`: between the walls, outside the break.
static func deck_at(x: int) -> bool:
	return x >= WEST and x < EAST and (x < BREAK.x or x >= BREAK.y)


## How far a leg's middle stands from its bent's middle at row `y`, for a bent
## whose feet stand at `foot` (the level floor unless given).
static func leg_off(y: int, foot := 0) -> int:
	var top := DECK_BOTTOM + 5
	return roundi(lerpf(LEG_TOP, LEG_FOOT, clampf(float(y - top) / float(foot - 1 - top), 0.0, 1.0)))


## The rows of the girts of a bent whose feet stand at `foot`: the three every
## bent has, and a sill girt where the legs run on far below them.
static func girts_for(foot: int) -> Array[int]:
	var rows: Array[int] = GIRTS.duplicate()
	if foot - GIRTS[2] >= SILL_FROM:
		rows.append(GIRTS[2] + SILL_STEP)
	return rows


## How far the bent rail hangs below the rail's line, `i` pixels into the gap.
static func droop(i: int) -> int:
	var f := clampf(float(i) / DROOP_REACH, 0.0, 1.0)
	return roundi(f * f * DROOP)


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


## A thin brace from `a` to `b`, two pixels wide, in the shade behind the legs.
static func _brace(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in steps + 1:
		var f := float(k) / maxf(steps, 1.0)
		_fill(img, roundi(lerpf(a.x, b.x, f)), roundi(lerpf(a.y, b.y, f)), 2, 1, col)


static func _bent(img: Image, bx: int, foot: int) -> void:
	var top := DECK_BOTTOM + 5
	var girts := girts_for(foot)
	# Behind the legs: a cross in each tier, and a knee out to the stringer on each side.
	var tiers: Array[int] = [top]
	tiers.append_array(girts)
	for k in tiers.size() - 1:
		var y0 := tiers[k] + 5
		var y1 := tiers[k + 1]
		_brace(img, Vector2i(bx - leg_off(y0, foot), y0), Vector2i(bx + leg_off(y1, foot) - 1, y1), WOOD[0])
		_brace(img, Vector2i(bx + leg_off(y0, foot) - 1, y0), Vector2i(bx - leg_off(y1, foot), y1), WOOD[1])
	for side: int in [-1, 1]:
		_brace(img, Vector2i(bx + side * 7, DECK_BOTTOM + 26), Vector2i(bx + side * 30, DECK_BOTTOM), WOOD[1] if side < 0 else WOOD[0])
	# The legs, splayed, lit down their left.
	for y in range(top, foot):
		var off := leg_off(y, foot)
		for side: int in [-1, 1]:
			var cx := bx + side * off
			_fill(img, cx - 3, y, 7, 1, OUTLINE)
			_fill(img, cx - 2, y, 1, 1, WOOD[2])
			_fill(img, cx - 1, y, 3, 1, WOOD[1])
			_fill(img, cx + 2, y, 1, 1, WOOD[0])
			# The grain: a short dark check now and then.
			if speckle(cx, y / 3) > 0.9:
				_fill(img, cx, y, 1, 1, WOOD[0])
	# The girts, bolted across the legs.
	for g: int in girts:
		var off := leg_off(g + 2, foot)
		_timber(img, bx - off - 4, g, off * 2 + 8, 5)
		for side: int in [-1, 1]:
			_fill(img, bx + side * off, g + 2, 1, 1, IRON[3])
	# The cap under the stringer, strapped with iron.
	_timber(img, bx - 11, DECK_BOTTOM, 22, 5)
	_fill(img, bx - 1, DECK_BOTTOM, 2, 5, IRON[1])
	_fill(img, bx - 1, DECK_BOTTOM, 1, 5, IRON[2])
	# A stone footing under each leg.
	for side: int in [-1, 1]:
		var fx := bx + side * LEG_FOOT
		_fill(img, fx - 6, foot - 4, 12, 4, OUTLINE)
		_fill(img, fx - 5, foot - 3, 10, 3, IRON[1])
		_fill(img, fx - 5, foot - 3, 10, 1, IRON[2])


static func _deck(img: Image) -> void:
	var stringer_y := RAIL_Y + RAIL_DEEP + SLEEPER_DEEP
	for span: Vector2i in [Vector2i(WEST, BREAK.x), Vector2i(BREAK.y, EAST)]:
		var w := span.y - span.x
		_timber(img, span.x, stringer_y, w, STRINGER_DEEP)
		# A second lit row and a seam, so the stringer reads as one heavy baulk.
		_fill(img, span.x, stringer_y + 3, w, 1, WOOD[0])
		for x in range(span.x, span.y):
			if posmod(x, SLEEPER_STEP) == 0 and x + SLEEPER_WIDE <= span.y:
				_fill(img, x - 1, RAIL_Y + RAIL_DEEP - 1, SLEEPER_WIDE + 2, SLEEPER_DEEP + 1, OUTLINE)
				_fill(img, x, RAIL_Y + RAIL_DEEP, SLEEPER_WIDE, SLEEPER_DEEP, WOOD[1])
				_fill(img, x, RAIL_Y + RAIL_DEEP, 1, SLEEPER_DEEP, WOOD[2])
				_fill(img, x + SLEEPER_WIDE - 1, RAIL_Y + RAIL_DEEP, 1, SLEEPER_DEEP, WOOD[0])
		# The rail: a lit head on a darker web, rusted here and there.
		_fill(img, span.x, RAIL_Y - 1, w, RAIL_DEEP + 1, OUTLINE)
		_fill(img, span.x, RAIL_Y, w, 1, IRON[3])
		_fill(img, span.x, RAIL_Y + 1, w, 1, IRON[1])
		for x in range(span.x, span.y):
			if speckle(x / 3, 7) > 0.82:
				_fill(img, x, RAIL_Y, 1, 1, RUST)
	# The snapped ends of the stringer, splintered.
	for y in range(stringer_y - 1, stringer_y + STRINGER_DEEP + 1):
		var jag := posmod(y * 5, 4)
		_fill(img, BREAK.x - jag, y, jag, 1, Color(0, 0, 0, 0))
		_fill(img, BREAK.x - jag - 1, y, 1, 1, OUTLINE)
		var jag_e := posmod(y * 3 + 1, 4)
		_fill(img, BREAK.y, y, jag_e, 1, Color(0, 0, 0, 0))
		_fill(img, BREAK.y + jag_e, y, 1, 1, OUTLINE)
	# The rail hangs bent into the gap from the west, and a stub stands out from the east.
	for i in DROOP_REACH:
		var y := RAIL_Y + droop(i)
		_fill(img, BREAK.x + i, y - 1, 1, RAIL_DEEP + 2, OUTLINE)
	_fill(img, BREAK.x + DROOP_REACH, RAIL_Y + DROOP - 1, 1, RAIL_DEEP + 2, OUTLINE)
	for i in DROOP_REACH:
		var y := RAIL_Y + droop(i)
		_fill(img, BREAK.x + i, y, 1, 1, IRON[3] if i < DROOP_REACH / 2 else IRON[2])
		_fill(img, BREAK.x + i, y + 1, 1, 1, RUST if speckle(i / 2, 3) > 0.6 else IRON[1])
	_fill(img, BREAK.y - 7, RAIL_Y - 1, 7, RAIL_DEEP + 2, OUTLINE)
	_fill(img, BREAK.y - 6, RAIL_Y, 6, 1, IRON[3])
	_fill(img, BREAK.y - 6, RAIL_Y + 1, 6, 1, RUST)
	# The fallen timber, on the floor under the gap with its east end out over
	# the pit's brink, and a sleeper beside it on the floor.
	_timber(img, BREAK.x + 4, -5, 30, 5)
	_timber(img, BREAK.x - 8, -3, SLEEPER_WIDE + 2, 3)


static func _cart(img: Image) -> void:
	var wheel_y := RAIL_Y - WHEEL_R  # the wheels' middle: they stand on the rail
	var tub_foot := RAIL_Y - WHEEL_R - 3
	var tub_top := tub_foot - TUB_DEEP
	# The heap of ore over the tub's rim, drawn first so the rim cuts it.
	for dx in range(-TUB_TOP + 2, TUB_TOP - 1):
		var f := float(dx + 2) / (TUB_TOP - 1)
		var high := roundi(7.0 * (1.0 - f * f) + (1.0 if speckle(dx, 11) > 0.5 else 0.0))
		for k in range(0, high + 1):
			var y := tub_top - k
			var col := OUTLINE
			if k < high:
				var lump := speckle((dx + 40) / 3 + k, (dx + 40) / 2 - k)
				col = ORE[1]
				if lump > 0.7:
					col = ORE[0]
				elif lump < 0.3:
					col = ORE[2]
				if k == high - 1 and dx < 2:
					col = ORE[3] if speckle(dx, 5) > 0.45 else ORE[2]
			_fill(img, CART_X + dx, y, 1, 1, col)
	# The tub: a riveted iron box, wider at the rim.
	for k in TUB_DEEP:
		var y := tub_top + k
		var hw := roundi(lerpf(TUB_TOP, TUB_FOOT, float(k) / (TUB_DEEP - 1)))
		_fill(img, CART_X - hw - 1, y, hw * 2 + 2, 1, OUTLINE)
		_fill(img, CART_X - hw, y, hw * 2, 1, IRON[1])
		_fill(img, CART_X - hw, y, 2, 1, IRON[2])
		_fill(img, CART_X + hw - 4, y, 4, 1, IRON[0])
		for x in range(CART_X - hw + 3, CART_X + hw - 4):
			if k > 5 and x > CART_X - 2 and speckle(x / 2, y) > 0.78:
				_fill(img, x, y, 1, 1, RUST)
	var rim := TUB_TOP + 1
	_fill(img, CART_X - rim - 1, tub_top - 1, rim * 2 + 2, 4, OUTLINE)
	_fill(img, CART_X - rim, tub_top, rim * 2, 2, IRON[2])
	_fill(img, CART_X - rim, tub_top, rim * 2 - 6, 1, IRON[3])
	# A strap round its middle, riveted.
	var strap := tub_top + 8
	_fill(img, CART_X - TUB_TOP + 2, strap, TUB_TOP * 2 - 4, 2, IRON[0])
	for x in range(CART_X - 12, CART_X + 13, 6):
		_fill(img, x, strap, 1, 1, IRON[3])
	# The frame under the tub, and the coupling hook at its east end.
	_fill(img, CART_X - 17, tub_foot - 1, 34, 4, OUTLINE)
	_fill(img, CART_X - 16, tub_foot, 32, 2, IRON[0])
	_fill(img, CART_X - 16, tub_foot, 32, 1, IRON[1])
	_fill(img, CART_X + 17, tub_foot - 1, 4, 3, OUTLINE)
	_fill(img, CART_X + 17, tub_foot, 3, 1, IRON[2])
	# Two wheels on the rail.
	for side: int in [-1, 1]:
		var wx := CART_X + side * 9
		for y in range(-WHEEL_R, WHEEL_R):
			for x in range(-WHEEL_R, WHEEL_R):
				var d := Vector2(x + 0.5, y + 0.5).length()
				if d > WHEEL_R + 0.2:
					continue
				var col := OUTLINE
				if d < WHEEL_R - 1.0:
					col = IRON[2] if x + y < 0 else IRON[1]
				if d < 1.0:
					col = IRON[3] if x + y < -1 else OUTLINE
				_fill(img, wx + x, wheel_y + y, 1, 1, col)


## The road, baked.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	for i in BENTS.size():
		_bent(img, BENTS[i], FOOT_Y[i])
	_deck(img)
	_cart(img)
	return img


## Where the chain's `i`th link hangs at time `at`: still at the stringer,
## swinging more toward the hook.
static func chain_point(i: int, at: float) -> Vector2:
	var h := i * 3.0
	var sway := sin(at * 0.9 - h * 0.04) * 4.0 * pow(h / CHAIN_LENGTH, 1.5)
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
	# The hook: a shank, a bend to the east and a point.
	var end := chain_point(links, t) + Vector2(0, 3)
	draw_rect(Rect2(end.x - 2, end.y, 4, 7), OUTLINE)
	draw_rect(Rect2(end.x - 1, end.y, 2, 6), IRON[2])
	draw_rect(Rect2(end.x - 2, end.y + 6, 8, 4), OUTLINE)
	draw_rect(Rect2(end.x - 1, end.y + 6, 6, 2), IRON[2])
	draw_rect(Rect2(end.x + 3, end.y + 2, 4, 5), OUTLINE)
	draw_rect(Rect2(end.x + 4, end.y + 3, 2, 4), IRON[3])
