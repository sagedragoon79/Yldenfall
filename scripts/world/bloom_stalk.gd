class_name BloomStalk
extends Node2D
## The Everbloom's stalk (room prop `bloom_stalk`, pass 572, bible 12.59), the
## back of the Veins: three strands of stillglass flesh, braided, as thick as
## the hero is tall, that rise from roots sunk in the floor of the shaft to the
## vault where the core hangs, and spread there into the stone round it. The
## room's sign had always told that "the light that fled the throne runs up
## these veins to the core"; the room showed six small crystals in a dark
## shaft.
##
## Six channels are cut along the strands, one for each LightVein in the room,
## lowest first. While its vein is whole a channel carries light up to the
## core: a dim line with beads climbing it. Cut the vein and its channel goes
## dark, for good once the core is starved (the veins stay cut). It is the
## core's health bar at the scale of the room.
##
## Painted like the crucible (12.35) and the Three Mouths (12.58): whole world
## pixels on master palette ramps, lit from the upper left, baked once
## (`build`). The light is drawn live, stepped like the veins' own (12.37).
## Scenery only. The origin is the bottom center of the prop's tile, on the
## floor; the stalk's axis is `AXIS` to its right, the middle of the shaft.

const OUTLINE := Color("120f19")  # night-0
## The flesh: in shadow (crystal-0), its body (night-1), where the light
## falls (night-2), and a glint (night-3).
const FLESH: Array[Color] = [Color("190d1c"), Color("2c2541"), Color("44386b"), Color("5d4997")]
## A crease round a strand (crystal-1, the Evercrown's seams, 12.48).
const CREASE := Color("421e48")
## A channel with no light in it (sky-0).
const GROOVE := Color("0d131c")
## Light in a channel, drawn live: the line (sky-2), a bead (sky-3) and its
## head (sky-4). The veins themselves go up to sky-7, so they stay the
## brightest things in the shaft.
const LINE := Color("2b5278")
const BEAD := Color("3677aa")
const HEAD := Color("51a5cd")
## Every baked tone, for the palette test.
const TONES := [OUTLINE, FLESH[0], FLESH[1], FLESH[2], FLESH[3], CREASE, GROOVE]

## How tall the stalk stands: from the Veins' floor to its vault.
const HEIGHT := 992
## The stalk's axis, from the origin.
const AXIS := 8
## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(AXIS - 128, -HEIGHT, 256, HEIGHT)
const STRANDS := 3
## Two channels a strand: where each lies across it (-1 its left edge, 1 its right).
const CHANNEL_U: Array[float] = [-0.3, 0.38]
const CHANNELS := 6
## The braid: one full turn of a strand, how far it swings from the axis, and
## its half width.
const TURN := 232.0
const SWING := 15.0
const HALF := 12.0
## The roots (the lowest part) and the crown (the highest): there the strands
## swing wide and thicken.
const ROOT := 96.0
const CROWN := 136.0
const ROOT_SWING := 34.0
const CROWN_SWING := 50.0
## Side limbs: lesser roots into the floor, and buttresses into the vault.
## [side, reach from the axis at its end].
const SIDE_LIMBS: Array = [[-1, 62.0], [1, 70.0], [-1, 104.0], [1, 96.0]]
const LIMB_RISE := 72.0
## Beads on a lit channel, how fast they climb (px a second), and the steps a
## second the light is drawn at (the veins' own, 12.37).
const BEADS := 7
const CLIMB := 46.0
const STEP_FPS := 10.0

## Baked once for the whole run: the image, and for each channel the pixels of
## it that show, from the floor up.
static var _baked: Image
static var _channels: Array[PackedVector2Array] = []

var t := 0.0
var _step := -1
var _state := -1
var _tex: ImageTexture
var _veins: Array = []
var _found := false


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bake()
	_tex = ImageTexture.create_from_image(_baked)


static func bake() -> void:
	if _baked == null:
		build()


func _process(delta: float) -> void:
	# The Stillstone holds the core and its beams (8.9), and the light with them.
	if not TimeStop.active():
		t += delta
	var step := int(t * STEP_FPS)
	var state := lit_mask()
	if step != _step or state != _state:
		_step = step
		_state = state
		queue_redraw()


## The room's veins, lowest first: channel `i` is fed by vein `i`.
func veins() -> Array:
	if not _found and get_parent() != null:
		_found = true
		for n: Node in get_parent().get_children():
			if n is LightVein:
				_veins.append(n)
		_veins.sort_custom(func(a: LightVein, b: LightVein) -> bool: return a.position.y > b.position.y)
	return _veins


## Whether channel `i` carries light: its vein is whole.
func lit(i: int) -> bool:
	var v := veins()
	if i < 0 or i >= v.size():
		return false
	return is_instance_valid(v[i]) and not (v[i] as LightVein).is_cut


## The lit channels, as bits.
func lit_mask() -> int:
	var mask := 0
	for i in CHANNELS:
		if lit(i):
			mask |= 1 << i
	return mask


## How far the roots (0 to 1, at the floor) and the crown (0 to 1, at the
## vault) flare at height `h` over the floor.
static func root_flare(h: float) -> float:
	var k := clampf(1.0 - h / ROOT, 0.0, 1.0)
	return k * k


static func crown_flare(h: float) -> float:
	var k := clampf(1.0 - (HEIGHT - h) / CROWN, 0.0, 1.0)
	return k * k


## A strand's angle round the braid at height `h`.
static func angle(k: int, h: float) -> float:
	return TAU * h / TURN + TAU * k / STRANDS


## Where strand `k`'s middle lies at height `h`, from the axis.
static func strand_x(k: int, h: float) -> float:
	return sin(angle(k, h)) * (SWING + ROOT_SWING * root_flare(h) + CROWN_SWING * crown_flare(h))


## How near the viewer strand `k` is at height `h` (-1 behind, 1 in front).
static func strand_depth(k: int, h: float) -> float:
	return cos(angle(k, h))


## A strand's half width at height `h`.
static func strand_half(h: float) -> float:
	return HALF + 4.0 * root_flare(h) + 5.0 * crown_flare(h)


## Side limb `j` at height `h`: [its middle from the axis, its half width], or
## an empty array where it has not left the stalk.
static func side_limb(j: int, h: float) -> Array:
	var limb: Array = SIDE_LIMBS[j]
	var top := j % 2 == 1
	var k := (1.0 - (HEIGHT - h) / LIMB_RISE) if top else (1.0 - h / LIMB_RISE)
	if k <= 0.0:
		return []
	return [float(limb[0]) * (10.0 + (float(limb[1]) - 10.0) * pow(k, 2.2)), 5.0 + 5.0 * k]


## A fixed speckle, 0 to 999.
static func speckle(a: int, b: int) -> int:
	return posmod((a * 73856093) ^ (b * 19349663), 1000)


## A 2 x 2 ordered dither, so the steps between tones are pixelled.
static func dither(x: int, y: int) -> float:
	return [[0.0, 0.5], [0.75, 0.25]][posmod(y, 2)][posmod(x, 2)] - 0.375


## The tone index of a limb's flesh at `u` across it (-1 its left edge, 1 its
## right), lit from the upper left: 0 shadow, 1 body, 2 lit, 3 a glint,
## 4 a crease.
static func flesh_level(id: int, u: float, x: int, row: int) -> int:
	# Creases ring the limb, bowed down in the middle like the folds of a stem.
	if posmod(row + int(u * u * 5.0) + id * 5, 15) == 0 and absf(u) < 0.86:
		return 4
	var v := u + dither(x, row) * 0.1
	if v < -0.52:
		# A broken glint along the edge that faces the light.
		return 3 if u > -0.86 and u < -0.6 and speckle(id, row / 6) % 3 == 0 else 2
	return 1 if v < 0.42 else 0


## Bakes the stalk and finds each channel's pixels.
static func build() -> void:
	var w := IMG.size.x
	var h_px := IMG.size.y
	var mid := float(AXIS - IMG.position.x)
	# Per pixel: tone index (255 none; 5 a channel's groove), the limb that
	# owns it, and the channel that runs through it.
	var tone := PackedByteArray()
	tone.resize(w * h_px)
	tone.fill(255)
	var owner := tone.duplicate()
	var chan := tone.duplicate()
	for row in h_px:
		var h := float(h_px - row) - 0.5
		# The limbs in this row, the farthest first: [depth, id, middle, half].
		var limbs: Array = []
		for j in SIDE_LIMBS.size():
			var s := side_limb(j, h)
			if not s.is_empty():
				limbs.append([-2.0, STRANDS + j, mid + float(s[0]), float(s[1])])
		for k in STRANDS:
			limbs.append([strand_depth(k, h), k, mid + strand_x(k, h), strand_half(h)])
		limbs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var base := row * w
		for limb: Array in limbs:
			var id: int = limb[1]
			var cx: float = limb[2]
			var half: float = limb[3]
			var x0 := maxi(0, floori(cx - half))
			var x1 := mini(w - 1, ceili(cx + half) - 1)
			var grooves: Array[int] = []
			if id < STRANDS:
				for u: float in CHANNEL_U:
					grooves.append(floori(cx + u * half))
			for x in range(x0, x1 + 1):
				var u := (x + 0.5 - cx) / half
				if absf(u) > 1.0:
					continue
				owner[base + x] = id
				var g := grooves.find(x)
				if g >= 0:
					tone[base + x] = 5
					chan[base + x] = id * CHANNEL_U.size() + g
				else:
					tone[base + x] = flesh_level(id, u, x, row)
					chan[base + x] = 255
			# It throws its shadow on whatever lies behind it, to its right.
			for x in range(x1 + 1, mini(w, x1 + 4)):
				if owner[base + x] != 255 and owner[base + x] != id and tone[base + x] != 5:
					tone[base + x] = 0
	var colors: Array[Color] = [FLESH[0], FLESH[1], FLESH[2], FLESH[3], CREASE, GROOVE]
	var img := Image.create(w, h_px, false, Image.FORMAT_RGBA8)
	_channels.clear()
	for i in CHANNELS:
		_channels.append(PackedVector2Array())
	for row in range(h_px - 1, -1, -1):
		var base := row * w
		for x in w:
			var at := tone[base + x]
			if at == 255:
				continue
			# An outline wherever the flesh meets the air, to either side.
			if x == 0 or x == w - 1 or tone[base + x - 1] == 255 or tone[base + x + 1] == 255:
				img.set_pixel(x, row, OUTLINE)
				continue
			img.set_pixel(x, row, colors[at])
			if at == 5:
				_channels[chan[base + x]].append(Vector2(x + IMG.position.x, row + IMG.position.y))
	_baked = img


## The pixels of channel `i` that show, from the floor up.
static func channel(i: int) -> PackedVector2Array:
	bake()
	return _channels[i]


## How far up channel `i` (an index into its pixels) bead `k` is at step `step`.
static func bead_at(i: int, k: int, step: int) -> int:
	var n := channel(i).size()
	if n == 0:
		return 0
	return posmod(int(step * CLIMB / STEP_FPS) + k * n / BEADS + i * 31, n)


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	for i in CHANNELS:
		if not lit(i):
			continue
		var pts := channel(i)
		# The line, in runs down each column it keeps to.
		var start := 0
		for p in range(1, pts.size() + 1):
			if p == pts.size() or pts[p].x != pts[start].x or pts[p].y != pts[p - 1].y - 1.0:
				draw_rect(Rect2(pts[start].x, pts[p - 1].y, 1, pts[start].y - pts[p - 1].y + 1.0), LINE)
				start = p
		# Beads of light climb it to the core: three pixels, the head brightest.
		for k in BEADS:
			var at := bead_at(i, k, _step)
			for d in 3:
				if at + d < pts.size():
					draw_rect(Rect2(pts[at + d].x, pts[at + d].y, 1, 1), HEAD if d == 2 else BEAD)
