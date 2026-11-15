class_name SpringWall
extends Node2D
## The Three Mouths (room prop `spring_wall`, pass 571, bible 12.58), the
## Fountain Plaza's back wall: a carved stone headwall taller than two
## fountains, with three arched niches. In each a carved mouth once poured one
## of the three springs of the Ylden into the long trough at its foot, and the
## trough fed the fountain. The plaza's sign had always told of the three
## springs; the room showed a small fountain in a dark hall.
##
## A mouth runs again when its spring is restored (heartwood on the left, the
## Haar in the middle, the sky on the right), and the sign cut over it lights.
## Two lanterns on the outer piers warm the stone round them.
##
## Painted like the crucible (12.35) and the gear train (12.57): whole world
## pixels on master palette ramps, lit from the upper left, baked once
## (`build_image`). The water, the lit signs and the flames are drawn live.
## Scenery only. The origin is the bottom center, on the floor.

const OUTLINE := Color("120f19")  # night-0
## Stone, dark to lit (stone-1 to stone-4).
const STONE: Array[Color] = [Color("2f2c3a"), Color("4a465d"), Color("645e82"), Color("867ba2")]
## The same stone in lantern light (umber-1 to umber-4).
const WARM: Array[Color] = [Color("3c2c2a"), Color("634a41"), Color("8a6e56"), Color("aa9173")]
## The back of a niche: in the pier's shadow (stone-0), where the light
## reaches (night-1), and in lantern light (umber-0).
const HOLLOW := Color("131217")
const HOLLOW_LIT := Color("2c2541")
const HOLLOW_WARM := Color("181111")
## Lime scale under a dry mouth (ash-2, ash-3) and the dry bed of the trough.
const SCALE_DARK := Color("58544c")
const SCALE := Color("797767")
const BED := Color("363330")
## Moss on the ledges (moss-2, moss-3).
const MOSS_DARK := Color("4f5c47")
const MOSS := Color("728061")
## The bronze lips (ochre-1 to ochre-3).
const BRONZE: Array[Color] = [Color("432d23"), Color("6e5135"), Color("9c7f44")]
## The lanterns: iron (stone-0), glass (gold-3, gold-4) and the flame's heart (gold-6).
const IRON := Color("131217")
const GLASS: Array[Color] = [Color("cb8d16"), Color("f0c02e")]
const FLAME := Color("f0dfa8")
## Water, dark to light (sky-2 to sky-6), drawn live.
const WATER: Array[Color] = [Color("2b5278"), Color("3677aa"), Color("51a5cd"), Color("84cbd6"), Color("b5e3e1")]
## The leaf in the crown, lit when all three run (green-5).
const LEAF_LIT := Color("a1d684")
## Every baked tone, for the palette test.
const TONES := [OUTLINE, STONE[0], STONE[1], STONE[2], STONE[3], WARM[0], WARM[1], WARM[2], WARM[3], HOLLOW, HOLLOW_LIT, HOLLOW_WARM, SCALE_DARK, SCALE, BED, MOSS_DARK, MOSS, BRONZE[0], BRONZE[1], BRONZE[2], GLASS[0], GLASS[1], FLAME]

## The baked image's rectangle, in world pixels from the origin.
const IMG := Rect2i(-104, -164, 208, 164)
## The wall's steps, bottom to top: [top y, bottom y, half width].
const STEPS: Array = [[-10, 0, 104], [-132, -10, 100], [-140, -132, 104], [-150, -140, 60], [-164, -150, 34]]
## The niches: their centers, half width, where the arch springs, and the top
## of the trough that stands across their feet.
const NICHE_X: Array[int] = [-62, 0, 62]
const NICHE_HALF := 22.0
const SPRING_Y := -96.0
const TROUGH_TOP := -24
const TROUGH_HALF := 92
## The band of the trough that shows its bed, or its water.
const BED_RECT := Rect2i(-88, -23, 176, 2)
## A mouth: its stone boss and the bronze lip the water leaves, from the
## niche's center line.
const BOSS := Rect2i(-6, -98, 12, 12)
const LIP := Rect2i(-3, -86, 6, 3)
const LIP_Y := -83
## The sign cut in each keystone, five pixels square: a leaf on its stem, the
## Haar's water, the sky's bolt. Its upper left corner from the niche's center.
const GLYPH_AT := Vector2i(-2, -129)
const GLYPHS: Array = [
	["..#..", ".###.", ".###.", "..#..", "..#.."],
	[".#.#.", "#.#.#", ".....", ".#.#.", "#.#.#"],
	["...#.", "..#..", ".###.", "..#..", ".#..."],
]
## The leaf in the crown's roundel, its center and the leaf's pixels from it.
const ROUNDEL := Vector2(0.0, -157.0)
const LEAF: Array[Vector2i] = [Vector2i(0, -3), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 2)]
## The lanterns on the outer piers, and how far their light warms the stone.
const LAMPS: Array[Vector2] = [Vector2(-92.0, -72.0), Vector2(92.0, -72.0)]
const LAMP_REACH := 54.0
## The stone is warm where the lantern light is over this.
const WARM_OVER := 0.42
## How fast the water falls (px a second) and the glints in each thread.
const FALL_SPEED := 96.0
const GLINTS := 4
## The light, from the upper left.
const LIGHT := Vector2(-0.64, -0.77)

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


## Whether mouth `i` runs: its spring is restored.
static func flows(i: int) -> bool:
	return GameState.flag("spring:" + String(Fountain.SPRINGS[i]))


## How far a thread of water falls: from the lip to the trough.
static func fall() -> float:
	return float(TROUGH_TOP - LIP_Y)


## How far below the lip glint `k` of a thread is at time `at`.
static func glint_drop(k: int, at: float) -> float:
	return fposmod(at * FALL_SPEED + k * fall() / GLINTS, fall())


## Inside the wall's outline.
static func in_wall(c: Vector2i) -> bool:
	for s: Array in STEPS:
		if c.y >= s[0] and c.y < s[1]:
			return c.x >= -s[2] and c.x < s[2]
	return false


## The niche that `c` lies in (above the trough), or -1.
static func niche_at(c: Vector2i) -> int:
	if c.y >= TROUGH_TOP:
		return -1
	var p := Vector2(c) + Vector2(0.5, 0.5)
	for i in NICHE_X.size():
		var dx := p.x - NICHE_X[i]
		if absf(dx) >= NICHE_HALF:
			continue
		if p.y >= SPRING_Y or dx * dx + (p.y - SPRING_Y) * (p.y - SPRING_Y) < NICHE_HALF * NICHE_HALF:
			return i
	return -1


## A fixed speckle, 0 to 999.
static func speckle(a: int, b: int) -> int:
	return posmod((a * 73856093) ^ (b * 19349663), 1000)


## A 2 x 2 ordered dither, so the steps between tones are pixelled.
static func dither(c: Vector2i) -> float:
	return [[0.0, 0.5], [0.75, 0.25]][posmod(c.y, 2)][posmod(c.x, 2)] - 0.375


## How much lantern light reaches `c`, 0 to 1.
static func lamp_light(c: Vector2i) -> float:
	var p := Vector2(c) + Vector2(0.5, 0.5)
	var best := 0.0
	for lamp: Vector2 in LAMPS:
		best = maxf(best, 1.0 - p.distance_to(lamp) / LAMP_REACH)
	return best


## Whether the sign of mouth `i` has a cut at `c`.
static func glyph_at(i: int, c: Vector2i) -> bool:
	var g := c - GLYPH_AT - Vector2i(NICHE_X[i], 0)
	if g.x < 0 or g.y < 0 or g.x > 4 or g.y > 4:
		return false
	return String(GLYPHS[i][g.y])[g.x] == "#"


## The baked tone of the back of niche `i` at `c`: its mouth, its stain, its
## shadow.
static func _niche_tone(i: int, c: Vector2i) -> Color:
	var p := Vector2(c) + Vector2(0.5, 0.5)
	var local := Vector2i(c.x - NICHE_X[i], c.y)
	if LIP.has_point(local):
		return BRONZE[2] if local.y == LIP.position.y else (BRONZE[0] if local.y == LIP.end.y - 1 else BRONZE[1])
	if BOSS.grow(1).has_point(local):
		if not BOSS.has_point(local):
			return OUTLINE
		# The mouth: a dark slot over the lip.
		if absi(local.x * 2 + 1) < 7 and local.y >= -91 and local.y < -88:
			return OUTLINE
		if local.y == BOSS.position.y or local.x == BOSS.position.x:
			return STONE[2]
		return STONE[0] if local.x == BOSS.end.x - 1 or local.y == BOSS.end.y - 1 else STONE[1]
	# Lime scale where the water ran: a streak down from the lip, thinning.
	if absi(local.x * 2 + 1) < 6 and local.y >= LIP.end.y:
		# Each of its five columns runs its own length; the middle ones longest.
		var run := fall() * (0.95 - absf(local.x + 0.5) * 0.22) - speckle(local.x, 3) % 9
		if local.y - LIP.end.y < run:
			return SCALE if speckle(local.x, local.y / 3) % 4 == 0 else SCALE_DARK
	var dx := p.x - NICHE_X[i]
	# The right jamb's reveal faces the light.
	if dx > NICHE_HALF - 3.0 and p.y >= SPRING_Y:
		return STONE[2]
	# The left jamb and the arch throw their shadow down and to the right.
	var roof := SPRING_Y - sqrt(maxf(NICHE_HALF * NICHE_HALF - dx * dx, 0.0))
	var lit := dx + NICHE_HALF > 9.0 and p.y - roof > 8.0 + (dx + NICHE_HALF) * 0.25
	if not lit:
		return HOLLOW
	return HOLLOW_WARM if lamp_light(c) + dither(c) * 0.2 > WARM_OVER else HOLLOW_LIT


## How lit the stone is at `c`, 0 (a joint, a shadow) to 3, before the
## lanterns: courses of blocks, lit ledges, the arches' ring stones.
static func stone_level(c: Vector2i) -> int:
	var p := Vector2(c) + Vector2(0.5, 0.5)
	# The trough: a lit rim and a plain face.
	if c.y >= TROUGH_TOP and c.y < -10 and absi(c.x * 2 + 1) < TROUGH_HALF * 2:
		if c.y == TROUGH_TOP:
			return 3
		if c.y == -11 or (c.y == BED_RECT.end.y):
			return 0
		return 2 if posmod(c.x, 46) != 0 else 0
	# The plinth.
	if c.y >= -10:
		return 2 if c.y == -10 else (0 if posmod(c.x + 9, 26) == 0 else 1)
	# The cornice and the crown's steps: a lit top, a plain face, a shadow under.
	for s: Array in STEPS:
		if s[0] >= -132 or c.y < s[0] or c.y >= s[1]:
			continue
		if c.y == s[0]:
			return 3
		if c.y == s[1] - 1:
			return 0 if s[0] == -140 else 1
		return 2
	# The shadow under the cornice.
	if c.y < -129:
		return 0
	# The ring stones of an arch, and its keystone.
	for i in NICHE_X.size():
		var d := p - Vector2(NICHE_X[i], SPRING_Y)
		if absi(c.x - NICHE_X[i]) <= 4 and c.y >= -131 and c.y < -118:
			return 1 if glyph_at(i, c) else (3 if c.x - NICHE_X[i] == -4 else 2)
		if p.y < SPRING_Y and d.length() < NICHE_HALF + 5.0:
			var joint := fposmod(d.angle() * 9.0 / PI, 1.0)
			if joint < 0.12 or d.length() > NICHE_HALF + 4.0:
				return 0
			return 3 if d.normalized().dot(LIGHT) > 0.8 else 2
	# Courses of blocks, eight pixels high, laid half over half.
	var row := floori((c.y + 132) / 8.0)
	var along := c.x + 104 + (8 if row % 2 == 1 else 0)
	if posmod(c.y + 132, 8) == 7 or posmod(along, 16) == 15:
		return 0
	var block := speckle(row, floori(along / 16.0))
	var level := 2 if block % 4 == 0 else 1
	# A pier's edge on a niche: the one that faces the light is a tone up.
	if niche_at(c + Vector2i.LEFT) >= 0:
		level += 1
	elif niche_at(c + Vector2i.RIGHT) >= 0:
		level -= 1
	return clampi(level, 0, 3)


## A lantern's baked pixel at `c`, or a clear color: an iron arm from the
## pier, a cap, and a glass of two tones round the flame.
static func _lamp_tone(c: Vector2i) -> Color:
	for lamp: Vector2 in LAMPS:
		var d := c - Vector2i(floori(lamp.x), floori(lamp.y))
		if d.x < -4 or d.x > 3 or d.y < -9 or d.y > 5:
			continue
		if d.y < -5:
			# The arm, and the hook the lantern hangs from.
			if d.y == -9 or ((d.x == -1 or d.x == 0) and d.y > -9):
				return IRON
			continue
		if d.x < -3 or d.x > 2:
			continue
		if d.y == -5 or d.y == 5 or d.x == -3 or d.x == 2:
			return IRON
		if absi(d.x * 2 + 1) < 2 and d.y >= -1 and d.y <= 2:
			return FLAME
		return GLASS[1] if d.y >= -2 and d.y <= 3 else GLASS[0]
	return Color(0, 0, 0, 0)


## The tone of the wall at `c`, or a clear color outside it.
static func tone_at(c: Vector2i) -> Color:
	if not in_wall(c):
		return Color(0, 0, 0, 0)
	for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if not in_wall(c + s):
			return OUTLINE
	var lamp := _lamp_tone(c)
	if lamp.a > 0.0:
		return lamp
	if BED_RECT.has_point(c):
		return BED
	var i := niche_at(c)
	if i >= 0:
		return _niche_tone(i, c)
	# The roundel in the crown: a ring and a leaf, cut in.
	var from_roundel := Vector2(c) + Vector2(0.5, 0.5) - ROUNDEL
	if (from_roundel.length() > 4.6 and from_roundel.length() < 5.7) or LEAF.has(c - Vector2i(floori(ROUNDEL.x), floori(ROUNDEL.y))):
		return STONE[0]
	var level := stone_level(c)
	# Moss on the ledges' tops, and a little hanging under the cornice.
	if (c.y == -140 and absi(c.x) > 60) or c.y == -10 or c.y == TROUGH_TOP:
		var m := speckle(floori(c.x / 3.0), c.y)
		if m < 300:
			return MOSS if m < 150 else MOSS_DARK
	if c.y >= -132 and c.y < -126 and speckle(floori(c.x / 2.0), 7) < 90 + (c.y + 132) * -12:
		return MOSS_DARK
	var glow := lamp_light(c) + dither(c) * 0.16
	if glow > WARM_OVER + 0.3:
		level = mini(level + 1, 3)
	return WARM[level] if glow > WARM_OVER else STONE[level]


## The wall, baked.
static func build_image() -> Image:
	var img := Image.create(IMG.size.x, IMG.size.y, false, Image.FORMAT_RGBA8)
	for y in IMG.size.y:
		for x in IMG.size.x:
			var col := tone_at(Vector2i(x, y) + IMG.position)
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return img


func _draw() -> void:
	draw_texture(_tex, Vector2(IMG.position))
	# The flames breathe: the heart of each grows a pixel now and then.
	for k in LAMPS.size():
		if sin(t * 7.0 + k * 2.1) > 0.3:
			draw_rect(Rect2(floorf(LAMPS[k].x) - 1, floorf(LAMPS[k].y) - 2, 2, 1), FLAME)
	var running := 0
	for i in NICHE_X.size():
		if not flows(i):
			continue
		running += 1
		var cx := float(NICHE_X[i])
		# The thread: four pixels of water from the lip to the trough, its
		# left edge lit, glints sliding down it.
		draw_rect(Rect2(cx - 2, LIP_Y, 4, fall()), WATER[1])
		draw_rect(Rect2(cx - 2, LIP_Y, 1, fall()), WATER[2])
		for k in GLINTS:
			var drop := floorf(glint_drop(k, t + i * 0.37))
			var len := minf(5.0, fall() - drop)
			draw_rect(Rect2(cx - 1 + (k % 2), LIP_Y + drop, 1, len), WATER[3 if k % 2 == 0 else 4])
		# Where it lands: two beads that hop.
		var hop := floorf(fposmod(t * 9.0 + i, 3.0))
		draw_rect(Rect2(cx - 4 - hop, TROUGH_TOP - 1 - hop, 1, 1), WATER[4])
		draw_rect(Rect2(cx + 3 + hop, TROUGH_TOP - 2 + hop, 1, 1), WATER[3])
		# Its sign, lit.
		for gy in 5:
			for gx in 5:
				if String(GLYPHS[i][gy])[gx] == "#":
					draw_rect(Rect2(cx + GLYPH_AT.x + gx, GLYPH_AT.y + gy, 1, 1), WATER[3])
	if running > 0:
		# The trough holds water: brighter, and livelier, with each spring.
		draw_rect(Rect2(BED_RECT), WATER[running - 1])
		draw_rect(Rect2(BED_RECT.position.x, BED_RECT.position.y, BED_RECT.size.x, 1), WATER[running])
		for k in running * 5:
			var gx := fposmod(k * 37.0 + floorf(t * 6.0) * 3.0, float(BED_RECT.size.x - 3))
			draw_rect(Rect2(BED_RECT.position.x + gx, BED_RECT.position.y, 3, 1), WATER[4])
	if running == NICHE_X.size():
		for leaf: Vector2i in LEAF:
			draw_rect(Rect2(ROUNDEL.x + leaf.x, ROUNDEL.y + leaf.y, 1, 1), LEAF_LIT)
