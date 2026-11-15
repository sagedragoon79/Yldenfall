class_name AqueductSpill
extends Node2D
## The broken aqueduct (room prop `aqueduct_spill`, pass 371), a Sunken Spring
## landmark in the Drowned Aqueduct: the end of the dwarves' stone channel,
## snapped off where it left the ceiling, still pouring the spring in a white
## fall into the flood below. The sheet ripples, foam churns where it lands,
## and spray jumps off the surface. Scenery only (the fall never pushes the
## player). The origin is the channel's mouth, under the ceiling; the fall
## drops FALL pixels to the water.
##
## It is heard (pass 374): a looping pour (`falls_pour`) that is loudest beside
## the fall and fades over HEAR pixels, silent beyond, the way the forge's
## anvil carries (`heard_db`).

const FALL := 112.0
const WIDTH := 10.0
## How much wider the sheet is where it lands than where it leaves the lip.
const SPREAD := 4.0
## The trough is the aqueduct's own travertine (the zone's `umber` ramp), and the
## water the palette's `sky` ramp, so the landmark sits in the room's colours.
const OUTLINE := Color("120f19")
const STONE := Color("aa9173")
const STONE_LIGHT := Color("c0b09b")
const STONE_DARK := Color("8a6e56")
const STONE_JOINT := Color("3c2c2a")
const MOSS := Color("728061")
const MOSS_DARK := Color("4f5c47")
const WATER := Color("84cbd6")
const WATER_LIGHT := Color("b5e3e1")
const WATER_DARK := Color("51a5cd")
const WATER_DEEP := Color("3677aa")
const FOAM := Color("e2f3ef")
## The sheet is drawn a column at a time (design bible 12.55). A column's tone
## goes by how far it is from the middle: EDGE, BODY, CORE.
enum Tone { EDGE, BODY, CORE }
## Below this many pixels above the water the sheet's rim columns tear into
## falling drops.
const TEAR := 26.0
## The mist where it lands: stepped bands (half width, height), each one a flat
## tint, never a gradient.
const MIST: Array[Vector2] = [Vector2(24, 5), Vector2(17, 10), Vector2(11, 16)]
const MIST_ALPHA := 0.1
## Rings run out along the surface from the foot: how far, and how many a side.
const RING_REACH := 44.0
const RINGS := 3
## The plunge under the surface: how deep the bubbles are driven.
const PLUNGE := 30.0

## The pour's loop and how far it carries: LOUD dB over the sound volume where
## the water lands, falling FADE dB across HEAR pixels, and silent past it.
const SOUND := "falls_pour"
const HEAR := 320.0
const LOUD := -4.0
const FADE := 22.0

var t := 0.0
var _voice: AudioStreamPlayer


func _ready() -> void:
	z_index = -1
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Sfx"
	var wav := load(Sfx.SFX_DIR + SOUND + ".wav") as AudioStreamWAV
	if wav != null:
		wav = wav.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_voice.stream = wav
	add_child(_voice)


## Where the water lands, in the world.
func foot() -> Vector2:
	return global_position + Vector2(0, FALL)


## How loud the pour is for a listener at `at` (dB, over the sound volume), or
## -INF out of earshot.
func heard_db(at: Vector2) -> float:
	var d := at.distance_to(foot())
	if d >= HEAR:
		return -INF
	return LOUD - FADE * d / HEAR


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var db := heard_db(p.global_position) if p != null else -INF
	if db == -INF or Sfx.silent or _voice.stream == null:
		if _voice.playing:
			_voice.stop()
		return
	_voice.volume_db = Sfx.volume_db + db
	if not _voice.playing:
		_voice.play()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


## Half the sheet's width `y` pixels under the mouth: it spreads as it drops.
static func half_width(y: float) -> float:
	return (WIDTH + SPREAD * clampf(y / FALL, 0.0, 1.0)) * 0.5


## The leftmost and one past the rightmost column of the sheet at its widest.
static func columns() -> Vector2i:
	var hw := int(ceil(half_width(FALL)))
	return Vector2i(-hw, hw)


## The tone of column `x` (its left edge, in pixels from the middle) at height
## `y`: the sheet's two rims are its darkest, and the middle its lightest.
static func column_tone(x: int, y: float) -> Tone:
	var hw := half_width(y)
	var d := absf(x + 0.5)
	if d > hw - 1.5:
		return Tone.EDGE
	if d < hw * 0.4:
		return Tone.CORE
	return Tone.BODY


## Where column `x` starts: the sheet's outer columns begin lower, as it spreads.
static func column_top(x: int) -> float:
	var d := absf(x + 0.5)
	if d <= WIDTH * 0.5:
		return 8.0
	return clampf((d * 2.0 - WIDTH) / SPREAD * FALL, 8.0, FALL)


## True where the sheet has torn into drops: its rim columns, near the water.
static func torn(x: int, y: float) -> bool:
	return y > FALL - TEAR and column_tone(x, y) == Tone.EDGE


static func _hash(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Streak `k` of column `x`: x is how far apart its repeats are (px), y its
## length (px), z how fast it falls (px/s). Every column carries its own, so the
## sheet runs in threads and never slides down as one block.
static func streak(x: int, k: int) -> Vector3:
	var period := 34.0 + floorf(_hash(x, k * 7 + 1) * 5.0) * 6.0
	var length := 4.0 + floorf(_hash(x, k * 7 + 2) * 9.0)
	var speed := 130.0 + floorf(_hash(x, k * 7 + 3) * 7.0) * 12.0
	return Vector3(period, length, speed)


## Ring `i` on one side of the foot at time `at`: x is how far out it has run,
## y its width, z its alpha. It runs out, thins and fades.
static func ring(i: int, at: float) -> Vector3:
	var phase := fmod(at * 0.55 + float(i) / RINGS, 1.0)
	return Vector3(9.0 + phase * RING_REACH, 7.0 - phase * 4.0, (1.0 - phase) * 0.7)


func _tone_color(tone: Tone) -> Color:
	match tone:
		Tone.EDGE:
			return Color(WATER_DARK, 0.75)
		Tone.CORE:
			return WATER_LIGHT.lerp(WATER, 0.55)
	return WATER


func _draw() -> void:
	_draw_trough()
	_draw_sheet()
	_draw_foot()


## The channel: a trough of dressed travertine jutting from the left, its
## broken end jagged, moss under it and the spring running along its bed.
func _draw_trough() -> void:
	_px(-41, -1, 38, 13, OUTLINE)
	_px(-40, 0, 36, 11, STONE)
	_px(-40, 0, 36, 1, STONE_LIGHT)
	_px(-40, 8, 36, 3, STONE_DARK)
	for jx: float in [-29.0, -16.0]:
		_px(jx, 1, 1, 10, STONE_JOINT)
		_px(jx + 1, 3, 1, 5, STONE_LIGHT)
	# The water in its bed, seen over the near wall, sliding to the lip.
	_px(-40, 1, 35, 2, WATER_DARK)
	for i in 4:
		var gx := -40.0 + fmod(t * 26.0 + i * 9.0, 32.0)
		_px(gx, 1, 3, 1, WATER_LIGHT)
	# The broken end.
	for j: Vector2 in [Vector2(-5, 3), Vector2(-3, 6), Vector2(-6, 8)]:
		_px(j.x, j.y, 3, 3, OUTLINE)
	# Brackets that once held it to the wall, one still there, one sheared.
	_px(-34, 11, 4, 8, OUTLINE)
	_px(-33, 11, 2, 7, STONE_DARK)
	_px(-33, 11, 1, 7, STONE)
	_px(-14, 11, 4, 3, OUTLINE)
	# Moss hanging under it where it has dripped for an age.
	for m: Vector3 in [Vector3(-27, 11, 3), Vector3(-25, 11, 5), Vector3(-23, 11, 2), Vector3(-21, 11, 4), Vector3(-10, 11, 3), Vector3(-8, 11, 2)]:
		_px(m.x, m.y, 2, m.z, MOSS_DARK)
		_px(m.x, m.y, 2, 1, MOSS)
	# The lip of water leaving the trough and curving down.
	_px(-WIDTH * 0.5 - 1, 0, WIDTH + 2, 8, OUTLINE)
	_px(-WIDTH * 0.5, 1, WIDTH, 7, WATER)
	_px(-WIDTH * 0.5, 1, WIDTH, 1, FOAM)
	_px(-WIDTH * 0.5, 2, WIDTH - 2, 1, WATER_LIGHT)
	_px(-WIDTH * 0.5, 6, 1, 2, WATER_DARK)
	_px(WIDTH * 0.5 - 2, 2, 2, 6, WATER_DARK)


## The fall, a column at a time: dark rims, a light middle, each column running
## its own streaks, the rims torn into drops above the water.
func _draw_sheet() -> void:
	var cols := columns()
	for x in range(cols.x, cols.y):
		var top := column_top(x)
		if top >= FALL:
			continue
		var solid_end := FALL
		if torn(x, FALL - 1.0):
			solid_end = maxf(top, FALL - TEAR + floorf(_hash(x, 91) * 8.0))
		var mid := (top + solid_end) * 0.5
		# A column is one tone above its middle and may be another below it (the
		# sheet spreads, so a rim column higher up is a body column lower down).
		_px(x, top, 1, mid - top, _tone_color(column_tone(x, top + 1.0)))
		_px(x, mid, 1, solid_end - mid, _tone_color(column_tone(x, solid_end - 1.0)))
		if solid_end < FALL:
			# Drops: short dashes falling the rest of the way.
			var s0 := streak(x, 2)
			var y := solid_end + fmod(t * s0.z + _hash(x, 92) * 12.0, 12.0) - 12.0
			while y < FALL:
				if y >= solid_end:
					_px(x, y, 1, minf(4.0, FALL - y), Color(WATER, 0.8))
				y += 12.0
			continue
		if column_tone(x, mid) == Tone.EDGE:
			continue
		for k in 2:
			var s := streak(x, k)
			# The first streak is light (a thread of foam), the second a dark
			# gap between threads.
			var col := WATER_DARK
			if k == 0:
				col = FOAM if column_tone(x, mid) == Tone.CORE else WATER_LIGHT
			var sy := top + fmod(t * s.z + _hash(x, 93 + k) * s.x, s.x) - s.x
			while sy < FALL:
				var a := maxf(sy, top)
				var b := minf(sy + (s.y if k == 0 else s.y * 0.5), FALL)
				if b > a:
					_px(x, a, 1, b - a, col)
				sy += s.x


## Where it lands: the plunge under the surface, mist, foam, spray and rings.
func _draw_foot() -> void:
	# The plunge: a pale shaft driven under the surface, and bubbles in it.
	_px(-6, FALL, 12, 6, Color(FOAM, 0.35))
	_px(-4, FALL + 6, 8, 8, Color(FOAM, 0.2))
	_px(-2, FALL + 14, 4, 8, Color(FOAM, 0.1))
	for i in 9:
		var phase := fmod(t * (0.7 + 0.1 * (i % 3)) + _hash(i, 94), 1.0)
		# Driven down fast, then wandering back up and out.
		var depth := sin(phase * PI) * PLUNGE * (0.5 + 0.5 * _hash(i, 95))
		var bx := (_hash(i, 96) - 0.5) * 12.0 + (phase - 0.5) * (18.0 if i % 2 == 0 else -18.0)
		var size := 2.0 if i % 3 == 0 else 1.0
		_px(bx, FALL + 2.0 + depth, size, size, Color(FOAM, 0.75 - 0.4 * phase))
	# Mist: stepped bands of one flat tint, swaying a little.
	for i in MIST.size():
		var m := MIST[i]
		var sway := roundf(sin(t * 1.3 + i * 1.7) * 2.0)
		_px(-m.x + sway, FALL - m.y, m.x * 2.0, m.y, Color(FOAM, MIST_ALPHA))
	# Rings running out along the surface on both sides.
	for i in RINGS:
		var r := ring(i, t)
		for side: float in [-1.0, 1.0]:
			var rx := side * r.x - (r.y if side < 0.0 else 0.0)
			_px(rx, FALL, r.y, 1, Color(WATER_LIGHT, r.z))
			_px(rx + side, FALL + 1.0, r.y * 0.5, 1, Color(WATER_DEEP, r.z * 0.6))
	# Foam where it lands, churning.
	for i in 7:
		var fx := -17.0 + i * 5.0 + sin(t * 6.0 + i) * 1.5
		var fh := 2.0 + 3.0 * (0.5 + 0.5 * sin(t * 9.0 + i * 1.9)) * (1.0 - absf(i - 3.0) / 5.0)
		_px(fx, FALL - fh, 5, fh + 1, FOAM)
		_px(fx + 1, FALL - fh + 1, 2, 1, WATER_LIGHT)
	# Spray thrown off either side.
	for i in 6:
		var phase := fmod(t * 1.6 + i * 0.17, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var px := side * (7.0 + phase * (12.0 + 3.0 * (i % 3)))
		var py := FALL - 4.0 - sin(phase * PI) * (9.0 + 3.0 * (i % 3))
		var size := 2.0 if i < 2 else 1.0
		_px(px, py, size, size, Color(FOAM, 1.0 - phase))
