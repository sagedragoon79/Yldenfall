class_name HornetNest
extends Node2D
## The great nest of the Hornet Gallery (room prop `hornet_nest`, pass 576,
## bible 12.63), a Heartwood landmark. The gallery's sign says "The hornets
## nest where the sap runs thickest": a paper nest as tall as nine tiles hangs
## from the ceiling between the two hanging trunks, banded in grey paper and
## chewed bark, with its mouth low on its face and a tear in its east side
## where the comb shows. Two young nests hang either side of it. Sap seeps
## out of the ceiling all along the nests' roots, runs down the great nest's
## face in ropes, and drips from a strand under it into the thorns.
##
## Painted like the high seat (12.62): whole world pixels on master palette
## ramps, lit from the upper left, baked once. Only the drop of sap and the
## hornets crawling at the mouth are drawn live. Scenery only. The origin is
## the ceiling's underside over the great nest's middle; y grows downward.

const OUTLINE := Color("120f19")  # night-0
## Grey paper, shade to lit (ash-1 to ash-3).
const PAPER: Array[Color] = [Color("363330"), Color("58544c"), Color("797767")]
## Chewed bark bands, shade to lit (umber-1 to umber-3).
const BAND: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56")]
## The comb in the tear: a cell's hollow, its wax, a capped cell (ochre-1 to ochre-3).
const COMB: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44")]
## The mouth's dark (umber-0).
const MOUTH_DARK := Color("181111")
## Sap, shade to glint (gold-2 to gold-4). Nothing but sap is gold.
const SAP: Array[Color] = [Color("8d4e16"), Color("cb8d16"), Color("f0c02e")]
## Every tone above, for the palette test.
const TONES := [
	OUTLINE, PAPER[0], PAPER[1], PAPER[2], BAND[0], BAND[1], BAND[2],
	COMB[0], COMB[1], COMB[2], MOUTH_DARK, SAP[0], SAP[1], SAP[2],
]

## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-72, 0, 148, 176)
## The great nest: where its paper begins under its stalk, where it ends, and
## its half width at its widest.
const TOP := 8
const BOTTOM := 150
const HALF := 50
## The stalk it hangs by: its half width.
const STALK_HALF := 8
## A band of paper is this many rows deep, and sags this far in the middle.
const BAND_DEEP := 11
const BAND_SAG := 15
## The mouth, low on the west of its face: middle and radii.
const MOUTH := Vector2i(-10, 128)
const MOUTH_R := Vector2i(8, 6)
## The tear in its east side where the comb shows: middle and radii.
const TEAR := Vector2i(21, 84)
const TEAR_R := Vector2i(13, 19)
## The two young nests: x of the middle, half width, length.
const YOUNG: Array[Vector3i] = [Vector3i(-58, 11, 34), Vector3i(63, 9, 28)]
## The strand of sap under the great nest, and the drop that falls from it:
## the column its rope holds at the nest's widest, how long the strand hangs, where the drop lands (the thorns'
## tips, just into the row 19 rows under the ceiling), seconds per drop.
const DRIP_X := 3
const STRAND := 14
const DRIP_LAND := 308
const DRIP_PERIOD := 2.6
## Hornets crawling at the mouth.
const CRAWLERS := 3

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


## The great nest's half width at row `y`: a teardrop, widest above its
## middle, cut off blunt at the bottom. 0 outside it.
static func half_at(y: int) -> int:
	if y < TOP or y >= BOTTOM:
		return 0
	var f := float(y - TOP) / float(BOTTOM - TOP) * 0.93
	return maxi(STALK_HALF, roundi(HALF * pow(sin(PI * pow(f, 0.85)), 0.65)))


## A young nest's half width at row `y`.
static func young_half(which: int, y: int) -> int:
	var n := YOUNG[which]
	if y < 4 or y >= n.z:
		return 0
	var f := float(y - 4) / float(n.z - 4) * 0.9
	return maxi(3, roundi(n.y * pow(sin(PI * pow(f, 0.8)), 0.7)))


## Which band of paper the great nest's cell (x, y) lies in: the bands sag in
## the middle, like the layers a nest is built in.
static func band_of(x: int, y: int) -> int:
	var hw := maxf(half_at(y), 1.0)
	var u := clampf(float(x) / hw, -1.0, 1.0)
	# The layers' edges are scalloped, never ruled.
	var wave := 1.4 * sin(x * 0.37) + 1.6 * sin(x * 0.13 + 1.0)
	return floori((float(y) - BAND_SAG * (1.0 - u * u) + wave + 64.0) / BAND_DEEP)


## Whether (x, y) is inside the tear.
static func in_tear(x: int, y: int) -> bool:
	var d := Vector2(float(x - TEAR.x) / TEAR_R.x, float(y - TEAR.y) / TEAR_R.y)
	# A ragged edge.
	return d.length() < 0.92 + 0.12 * speckle(x / 3, y / 3)


## Whether (x, y) is inside the mouth.
static func in_mouth(x: int, y: int) -> bool:
	return Vector2(float(x - MOUTH.x) / MOUTH_R.x, float(y - MOUTH.y) / MOUTH_R.y).length() <= 1.0


## The ropes of sap down the great nest's face: x is the column a rope would
## hold at the nest's widest, y the row it ends on. Each begins at the ceiling
## beside the stalk. The last is the one that hangs under the nest and drips.
static func sap_ropes() -> Array[Vector2i]:
	return [Vector2i(-33, 80), Vector2i(-17, 114), Vector2i(36, 68), Vector2i(DRIP_X, BOTTOM + STRAND)]


## A rope's column at row `y`: it follows the nest's face, close in at the
## stalk and out over the bulge, and it wanders a little.
static func rope_x(rope: Vector2i, y: int) -> int:
	var hw := half_at(clampi(y, TOP, BOTTOM - 1))
	var x := float(rope.x) * (0.5 + 0.5 * float(hw) / float(HALF))
	if y < BOTTOM:
		x += 1.4 * sin(y * 0.12 + rope.x)
	return roundi(x)


## The column the drop falls in: the foot of the last rope.
static func drip_x() -> int:
	var rope: Vector2i = sap_ropes().back()
	return rope_x(rope, rope.y)


## Where the drop leaves the strand.
static func drip_top() -> int:
	return BOTTOM + STRAND + 1


## A drop's row at time `at`: it swells under the strand, then falls.
static func drip_y(at: float) -> float:
	var phase := fposmod(at, DRIP_PERIOD) / DRIP_PERIOD
	var fall := clampf((phase - 0.4) / 0.6, 0.0, 1.0)
	return lerpf(drip_top(), DRIP_LAND, fall * fall)


## Where crawler `k` is at time `at`, from the origin: round the mouth's rim.
static func crawler_at(k: int, at: float) -> Vector2i:
	var a := at * (0.5 + 0.13 * k) * (1.0 if k % 2 == 0 else -1.0) + k * 2.1
	return MOUTH + Vector2i(roundi(cos(a) * (MOUTH_R.x + 3)), roundi(sin(a) * (MOUTH_R.y + 3)))


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


## One banded paper cell: `u` is -1 at the nest's west edge and 1 at its east,
## `band` its layer, `seam` whether it lies on a layer's upper edge, `lip`
## whether it lies just under one.
static func _paper(x: int, y: int, u: float, band: int, seam: bool, lip: bool) -> Color:
	if seam:
		return OUTLINE
	var ramp := PAPER if posmod(band, 2) == 0 else BAND
	# Lit from the upper left: the west third is lit, the east third in shade.
	# The shade's edge steps from layer to layer and is ragged along each.
	u += (speckle(band * 7, 3) - 0.5) * 0.3 + (speckle(x / 2, y / 3) - 0.5) * 0.14
	var tone := 1
	if u < -0.45:
		tone = 2
	elif u > 0.3:
		tone = 0
	elif lip:
		tone = 2
	# Its underside is in its own shade.
	if y > BOTTOM - 30 and tone > 0:
		tone -= 1
	# The paper's fibres run along the band.
	if tone > 0 and speckle(x / 4 + band * 5, y) > 0.9:
		tone -= 1
	return ramp[tone]


static func _stalk(img: Image) -> void:
	for y in range(0, TOP + 4):
		var hw := STALK_HALF + maxi(0, 4 - y)
		_fill(img, -hw - 1, y, hw * 2 + 2, 1, OUTLINE)
		_fill(img, -hw, y, hw * 2, 1, BAND[1])
		_fill(img, -hw, y, maxi(2, hw / 3), 1, BAND[2])
		_fill(img, hw - maxi(2, hw / 3), y, maxi(2, hw / 3), 1, BAND[0])


static func _body(img: Image) -> void:
	for y in range(TOP, BOTTOM):
		var hw := half_at(y)
		_fill(img, -hw - 1, y, hw * 2 + 2, 1, OUTLINE)
		for x in range(-hw, hw):
			var u := (float(x) + 0.5) / float(hw)
			var band := band_of(x, y)
			var seam := band_of(x, y - 1) != band
			var lip := not seam and band_of(x, y - 2) != band
			_fill(img, x, y, 1, 1, _paper(x, y, u, band, seam, lip))
	# Its blunt underside.
	var hb := half_at(BOTTOM - 1)
	_fill(img, -hb - 1, BOTTOM, hb * 2 + 2, 1, OUTLINE)
	_fill(img, -hb, BOTTOM - 2, hb * 2, 2, PAPER[0])


static func _tear(img: Image) -> void:
	for y in range(TEAR.y - TEAR_R.y - 2, TEAR.y + TEAR_R.y + 3):
		for x in range(TEAR.x - TEAR_R.x - 2, TEAR.x + TEAR_R.x + 3):
			if x >= half_at(y) - 2:
				continue
			if not in_tear(x, y):
				# The torn paper's edge.
				if in_tear(x + 1, y) or in_tear(x - 1, y) or in_tear(x, y + 1) or in_tear(x, y - 1):
					_fill(img, x, y, 1, 1, OUTLINE)
				continue
			# Cells in staggered rows, six px apart: a dark hollow in a wax
			# ring, and now and then a capped one.
			var row := floori(float(y - TEAR.y + 60) / 5.0)
			var cx := posmod(x - TEAR.x + 60 + (3 if row % 2 == 1 else 0), 6)
			var cy := posmod(y - TEAR.y + 60, 5)
			var col := COMB[1]
			if cx >= 1 and cx <= 3 and cy >= 1 and cy <= 3:
				var cell := Vector2i((x - TEAR.x + 60 + (3 if row % 2 == 1 else 0)) / 6, row)
				col = COMB[2] if speckle(cell.x * 3 + 1, cell.y * 7) > 0.72 else COMB[0]
			_fill(img, x, y, 1, 1, col)


static func _mouth(img: Image) -> void:
	for y in range(MOUTH.y - MOUTH_R.y - 2, MOUTH.y + MOUTH_R.y + 3):
		for x in range(MOUTH.x - MOUTH_R.x - 2, MOUTH.x + MOUTH_R.x + 3):
			if in_mouth(x, y):
				_fill(img, x, y, 1, 1, MOUTH_DARK if y < MOUTH.y - 2 else OUTLINE)
			elif in_mouth(x, y + 2) and not in_mouth(x, y + 1):
				pass
			elif in_mouth(x, y - 1) or in_mouth(x + 1, y) or in_mouth(x - 1, y) or in_mouth(x, y + 1):
				# A rolled paper rim, lit along its top.
				_fill(img, x, y, 1, 1, PAPER[2] if y < MOUTH.y else PAPER[0])


static func _young(img: Image) -> void:
	for which in YOUNG.size():
		var n := YOUNG[which]
		# Its stalk.
		_fill(img, n.x - 3, 0, 6, 5, OUTLINE)
		_fill(img, n.x - 2, 0, 4, 5, BAND[1])
		_fill(img, n.x - 2, 0, 1, 5, BAND[2])
		for y in range(4, n.z):
			var hw := young_half(which, y)
			_fill(img, n.x - hw - 1, y, hw * 2 + 2, 1, OUTLINE)
			for x in range(-hw, hw):
				var u := (float(x) + 0.5) / float(hw)
				var b := floori((float(y) - 4.0 * (1.0 - u * u) + 32.0) / 8.0)
				var b_up := floori((float(y - 1) - 4.0 * (1.0 - u * u) + 32.0) / 8.0)
				var b_up2 := floori((float(y - 2) - 4.0 * (1.0 - u * u) + 32.0) / 8.0)
				_fill(img, n.x + x, y, 1, 1, _paper(n.x + x, y, u, b + which, b_up != b, b_up == b and b_up2 != b))
		var hb := young_half(which, n.z - 1)
		_fill(img, n.x - hb - 1, n.z, hb * 2 + 2, 1, OUTLINE)
		# A small dark mouth at its foot.
		_fill(img, n.x - 2, n.z - 4, 4, 3, OUTLINE)


static func _sap(img: Image) -> void:
	# The seep: sap beads out of the ceiling in patches along the nests' roots.
	for x in range(-70, 71):
		if speckle(x / 6, 9) < 0.5:
			continue
		var deep := 1 + int(speckle(x / 2, 5) * 2.9)
		for k in deep:
			var c := _px(img, x, k)
			if c.a > 0.0 and c != OUTLINE:
				continue  # not over a stalk
			_fill(img, x, k, 1, 1, SAP[1] if k == deep - 1 and deep > 1 else SAP[0])
	# The ropes: from the ceiling down the stalk and over the nest's face.
	for rope: Vector2i in sap_ropes():
		for y in range(0, rope.y):
			var x := rope_x(rope, y)
			_fill(img, x, y, 1, 1, SAP[2] if posmod(y + rope.x, 13) < 3 else SAP[1])
			_fill(img, x + 1, y, 1, 1, SAP[0])
		# A bead at its foot.
		var fx := rope_x(rope, rope.y)
		_fill(img, fx - 1, rope.y - 2, 4, 3, SAP[1])
		_fill(img, fx - 1, rope.y + 1, 4, 1, SAP[0])
		_fill(img, fx + 2, rope.y - 2, 1, 3, SAP[0])
		_fill(img, fx - 1, rope.y - 2, 1, 1, SAP[2])


## The nests, baked.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	_stalk(img)
	_body(img)
	_tear(img)
	_mouth(img)
	_young(img)
	_sap(img)
	return img


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	# A bead swells under the strand, then falls into the thorns.
	var phase := fposmod(t, DRIP_PERIOD) / DRIP_PERIOD
	var y := roundf(drip_y(t))
	var dx := drip_x()
	if phase < 0.4:
		draw_rect(Rect2(dx, y, 2, 1 + roundf(phase * 5.0)), SAP[1])
	else:
		draw_rect(Rect2(dx, y, 2, 4), SAP[1])
		draw_rect(Rect2(dx, y, 1, 1), SAP[2])
	# Hornets crawl round the mouth: too small to be taken for a foe.
	for k in CRAWLERS:
		var c := crawler_at(k, t)
		draw_rect(Rect2(c.x, c.y, 3, 2), OUTLINE)
		draw_rect(Rect2(c.x + 1, c.y, 1, 2), COMB[2])
