class_name GearTrain
extends Node2D
## The great gears of the Gear Pit (room prop `gear_train`, pass 570, bible
## 12.57), a Tower landmark: three toothed iron wheels in mesh on the back
## wall, the greatest taller than two dwarves and sunk into the floor toward
## the winch it turned in the hall below. They are seized. Rust has taken the
## shade, one tooth of the great gear has snapped off and lies on the floor,
## and the drive chain hangs broken from the pinion. Every few seconds the
## train strains a sixth of a tooth and falls back: "their teeth still bite".
## The room's sign had told of the gears since the room was made; nothing was
## drawn.
##
## Painted like the crucible (12.35) and the fallen bell (12.56): whole world
## pixels on master palette ramps, lit from the upper left, baked once (two
## images: at rest and strained). Only the chain is drawn live. Scenery only.
## The origin is on the floor under the great gear's axle.

const OUTLINE := Color("120f19")  # night-0
## Iron, dark to lit (stone-1 to stone-4).
const IRON: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## Rust where the iron stands in shade (two tones of the bark ramp).
const RUST_DARK := Color("48201e")
const RUST := Color("783c2b")
## The brass bearing caps (ochre-1 to ochre-4).
const BRASS: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44"), Color("bea860")]
## The hangers and the post behind the wheels (stone-1, stone-2).
const FRAME := Color("2f2c3a")
const FRAME_LIT := Color("4a465d")
## Every tone above, for the palette test.
const TONES := [OUTLINE, IRON[0], IRON[1], IRON[2], IRON[3], RUST_DARK, RUST, BRASS[0], BRASS[1], BRASS[2], BRASS[3]]

## The three wheels, greatest first. `r` is the pitch radius; teeth stand
## `TOOTH` over it and under it. Their tooth counts are in the ratio of their
## radii, so they share one pitch and can mesh. `at` is the axle, from the
## origin; each stands off the one before it by the sum of their radii.
const TOOTH := 4.0
## How thick a wheel is, in pixels of side shown.
const DEPTH := 2
const GEARS: Array[Dictionary] = [
	{"at": Vector2(0, -48), "r": 52.0, "teeth": 26, "spokes": 6, "rim": 9.0, "hub": 11.0, "spoke": 7.0},
	{"at": Vector2(-44, -119.554), "r": 32.0, "teeth": 16, "spokes": 5, "rim": 7.0, "hub": 8.0, "spoke": 5.0},
	{"at": Vector2(-4, -149.554), "r": 18.0, "teeth": 9, "spokes": 0, "rim": 0.0, "hub": 6.0, "spoke": 0.0},
]
## The great gear's angle at rest, and how far the train strains: a sixth of
## a tooth at the great gear.
const REST := 0.31
const STRAIN := TAU / 26.0 / 6.0
## The tooth of the great gear that snapped off, counted from its angle.
const BROKEN := 19
## The light, from the upper left.
const LIGHT := Vector2(-0.64, -0.77)
## Rust grows where the speckle is over this.
const RUST_OVER := 0.8
## The underside of the room's ceiling over the hangers, from the origin.
const CEILING := -272
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-84, -274, 144, 282)
## The train strains this often (seconds), in two short bites.
const CYCLE := 7.0
const BITES: Array[Vector2] = [Vector2(0.0, 0.1), Vector2(0.2, 0.26)]
## The broken drive chain: where it leaves the pinion, and its length.
const CHAIN_TOP := Vector2(14, -150)
const CHAIN_LENGTH := 42.0

## Both images are baked once for the whole run. The one at rest is baked as
## the room loads; the strained one on a worker thread, so the room's load
## pays for one image, like the bell's (about 0.1 s each).
static var _rest: Image
static var _bite: Image
static var _task := -1

var t := 0.0
var _tex_rest: ImageTexture
var _tex_bite: ImageTexture


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _rest == null:
		_rest = build_image(0.0)
	if _bite == null and _task == -1:
		_task = WorkerThreadPool.add_task(_bake_bite)
	_tex_rest = ImageTexture.create_from_image(_rest)


static func _bake_bite() -> void:
	_bite = build_image(1.0)


func _process(delta: float) -> void:
	t += delta
	if _tex_bite == null and _bite != null:
		if _task != -1:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
		_tex_bite = ImageTexture.create_from_image(_bite)
	queue_redraw()


## Each wheel's angle when the train is strained by `strain` (0 at rest, 1 in
## the bite). A wheel in mesh turns against its driver, faster by the ratio of
## their teeth, and its tooth stands in the driver's gap on the line between
## the axles.
static func angles(strain: float) -> Array[float]:
	var out: Array[float] = [REST + STRAIN * strain]
	for i in range(1, GEARS.size()):
		var a: Dictionary = GEARS[i - 1]
		var b: Dictionary = GEARS[i]
		var toward: float = (b.at - a.at).angle()
		var fa := fposmod((toward - out[i - 1]) * a.teeth / TAU, 1.0)
		out.append(toward + PI - (0.5 - fa) * TAU / b.teeth)
	return out


## How far the wheel's edge stands from its axle toward `ang` (in the wheel's
## own frame): the root circle between teeth, the tip on a tooth, a stub where
## the tooth snapped.
static func edge(i: int, ang: float) -> float:
	var g: Dictionary = GEARS[i]
	var turn: float = ang * g.teeth / TAU
	var f := fposmod(turn, 1.0)
	var off := minf(f, 1.0 - f)
	var rise := clampf((0.27 - off) / 0.11, 0.0, 1.0)
	if i == 0 and posmod(roundi(turn), g.teeth) == BROKEN:
		# The stub: a jagged quarter of the tooth.
		rise = minf(rise, 0.3 if f < 0.5 else 0.15)
	return g.r - TOOTH + 2.0 * TOOTH * rise


## Whether wheel `i`, turned to `angle`, covers the world pixel `cell`.
static func covers(i: int, cell: Vector2i, angle: float) -> bool:
	var g: Dictionary = GEARS[i]
	var d: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) - g.at
	var r := d.length()
	if r > g.r + TOOTH:
		return false
	var ang := d.angle() - angle
	if r > edge(i, ang):
		return false
	var rim_in: float = g.r - TOOTH - g.rim
	if g.spokes == 0 or r >= rim_in or r <= g.hub:
		return true
	# A spoke: within half its width of a line from the hub to the rim.
	var step: float = TAU / g.spokes
	var da := fposmod(ang, step)
	da = minf(da, step - da)
	return r * sin(da) <= g.spoke * 0.5


## The wheel that covers `cell` when the train is strained by `strain`, or -1.
static func wheel_at(cell: Vector2i, strain: float) -> int:
	var turned := angles(strain)
	for i in GEARS.size():
		if covers(i, cell, turned[i]):
			return i
	return -1


## A 2 x 2 ordered dither, so the steps between tones are pixelled.
static func dither(c: Vector2i) -> float:
	return [[0.0, 0.5], [0.75, 0.25]][posmod(c.y, 2)][posmod(c.x, 2)] - 0.375


## A fixed speckle, 0 to 1, in streaks that run round a wheel: `d` is the
## pixel from its axle. Two pixels deep, about seven along the rim.
static func speckle(d: Vector2) -> float:
	var r := d.length()
	var h := (floori(r / 2.0) * 73856093) ^ (floori(d.angle() * maxf(r, 6.0) / 7.0) * 19349663)
	return float(posmod(h, 97)) / 96.0


## How lit the face of wheel `i` is at `cell`, 0 (dark) to 2, before its edges:
## the upper left of each wheel is the lighter.
static func face_level(i: int, cell: Vector2i) -> int:
	var g: Dictionary = GEARS[i]
	var d: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5) - g.at) / (g.r + TOOTH)
	return clampi(floori(1.5 + d.dot(LIGHT) * 1.1 + dither(cell) * 0.35), 0, 2)


## An outlined block of two tones, lit along its left.
static func _beam(put: Callable, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var c := Vector2i(x, y)
			if x < rect.position.x or x >= rect.end.x:
				put.call(c, OUTLINE)
			else:
				put.call(c, FRAME_LIT if x == rect.position.x else FRAME)
		# A rivet every twelve pixels.
		if posmod(y, 12) == 5:
			put.call(Vector2i(rect.position.x + rect.size.x / 2, y), OUTLINE)


## The train, baked: strained by `strain` (0 at rest, 1 in the bite).
static func build_image(strain: float) -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	var put := func(c: Vector2i, col: Color) -> void:
		var p := c - IMG.position
		if p.x >= 0 and p.y >= 0 and p.x < IMG.size.x and p.y < IMG.size.y:
			img.set_pixel(p.x, p.y, col)
	# Behind the wheels: a hanger from the ceiling to each upper axle, and a
	# post from the floor to the great one.
	for i in range(1, GEARS.size()):
		var ax: Vector2 = GEARS[i].at
		_beam(put, Rect2i(floori(ax.x) - 3, CEILING, 6, floori(ax.y) - CEILING + 6))
	var great: Vector2 = GEARS[0].at
	_beam(put, Rect2i(floori(great.x) - 4, floori(great.y) - 8, 8, -floori(great.y) + 8))
	# The wheels.
	var turned := angles(strain)
	var body := {}
	var owner := {}
	for i in GEARS.size():
		var g: Dictionary = GEARS[i]
		var reach := int(g.r + TOOTH) + 2
		var axle: Vector2 = g.at
		var angle := turned[i]
		# Under the root circle a spoked wheel is rim, spoke or hub, and a
		# plain one is all iron: only the ring of teeth needs `edge`.
		var root_sq: float = (g.r - TOOTH) * (g.r - TOOTH)
		var tip_sq: float = (g.r + TOOTH) * (g.r + TOOTH)
		var plain: bool = g.spokes == 0
		for y in range(floori(axle.y) - reach, floori(axle.y) + reach + 1):
			for x in range(floori(axle.x) - reach, floori(axle.x) + reach + 1):
				var r_sq := (Vector2(x + 0.5, y + 0.5) - axle).length_squared()
				if r_sq > tip_sq:
					continue
				var c := Vector2i(x, y)
				if (plain and r_sq <= root_sq) or covers(i, c, angle):
					owner[c] = i
	for c: Vector2i in owner:
		var i: int = owner[c]
		var g: Dictionary = GEARS[i]
		var d: Vector2 = Vector2(c) + Vector2(0.5, 0.5) - g.at
		var r := d.length()
		if r <= 1.6:
			body[c] = OUTLINE  # the axle's end
			continue
		if r <= g.hub - 3.0:
			# The brass bearing cap, domed.
			body[c] = BRASS[clampi(floori(2.0 + d.normalized().dot(LIGHT) * 1.5 * r / g.hub + dither(c) * 0.5), 0, 3)]
			continue
		if r <= g.hub - 2.0:
			body[c] = OUTLINE
			continue
		var face := face_level(i, c)
		var level := face
		# An edge that faces the light is a tone up; one that faces away, a tone down.
		var lit_edge := not owner.has(c + Vector2i.LEFT) or not owner.has(c + Vector2i.UP)
		var dark_edge := not owner.has(c + Vector2i.RIGHT) or not owner.has(c + Vector2i.DOWN)
		if lit_edge and not dark_edge:
			level += 1
		elif dark_edge and not lit_edge:
			level -= 1
		# A groove round the rim, and round the pinion's face.
		var groove: float = g.r - TOOTH - (g.rim * 0.5 if g.spokes > 0 else 5.0)
		if absf(r - groove) < 0.6:
			level -= 1
		level = clampi(level, 0, 3)
		var col := IRON[level]
		if level <= 1 and face <= 1 and speckle(d) > RUST_OVER and not lit_edge:
			col = RUST if level == 1 else RUST_DARK
		body[c] = col
	# Each wheel is a slab: its side shows two pixels down and to the right.
	for c: Vector2i in owner:
		for k in range(1, DEPTH + 1):
			var side: Vector2i = c + Vector2i(k, k)
			if not owner.has(side) and not body.has(side):
				body[side] = IRON[0]
	# The pinion's bolts.
	var pin: Dictionary = GEARS[2]
	for k in 4:
		var b: Vector2 = pin.at + Vector2.from_angle(turned[2] + k * TAU / 4.0) * 9.5
		body[Vector2i(floori(b.x), floori(b.y))] = OUTLINE
	var rim := {}
	for c: Vector2i in body:
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not body.has(c + s):
				rim[c + s] = true
	for c: Vector2i in rim:
		if IMG.has_point(c):
			img.set_pixelv(c - IMG.position, OUTLINE)
	for c: Vector2i in body:
		if IMG.has_point(c):
			img.set_pixelv(c - IMG.position, body[c])
	# The snapped tooth, on the floor where it fell, and two flakes of rust.
	for y in range(-8, 0):
		for x in range(38, 49):
			var edge_px := y == -8 or x == 38 or x == 48
			var cut := x - 38 < (-1 - y) / 3 or 48 - x < (-1 - y) / 4
			if cut:
				continue
			put.call(Vector2i(x, y), OUTLINE if edge_px else (IRON[2] if y == -7 or x == 39 else (RUST if (x + y * 2) % 5 == 0 else IRON[1])))
	for flake: Array in [[-70, 2], [30, 3], [54, 2]]:
		for x in range(flake[0], flake[0] + flake[1]):
			put.call(Vector2i(x, -1), RUST)
	return img


## Whether the train is in a bite at time `at`.
static func biting(at: float) -> bool:
	var c := fposmod(at, CYCLE)
	for bite: Vector2 in BITES:
		if c >= bite.x and c < bite.y:
			return true
	return false


## Where the chain's `i`th link hangs at time `at`: still at the pinion,
## swinging more toward its broken end.
static func chain_point(i: int, at: float) -> Vector2:
	var h := i * 3.0
	var sway := sin(at * 1.1 - h * 0.05) * 3.0 * pow(h / CHAIN_LENGTH, 1.5)
	return CHAIN_TOP + Vector2(roundf(sway), h)


func _draw() -> void:
	draw_texture(_tex_bite if biting(t) and _tex_bite != null else _tex_rest, Vector2(IMG.position))
	# The drive chain, parted: links hang from the pinion's far side.
	var links := int(CHAIN_LENGTH / 3.0)
	for i in links + 1:
		var p := chain_point(i, t)
		if i % 2 == 0:
			draw_rect(Rect2(p.x - 2, p.y - 1, 6, 5), OUTLINE)
			draw_rect(Rect2(p.x - 1, p.y, 4, 3), IRON[2])
			draw_rect(Rect2(p.x, p.y + 1, 2, 1), OUTLINE)
		else:
			draw_rect(Rect2(p.x - 1, p.y, 4, 3), OUTLINE)
			draw_rect(Rect2(p.x, p.y, 2, 3), IRON[1])
