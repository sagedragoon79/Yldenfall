class_name FireSeal
extends StaticBody2D
## One tile of a fire seal (room legend `Z`, a column of three is usual, bible
## 4.5): red runic flames that block like a wall and burn whoever touches them.
## A Deluge bolt (group "water_target") douses every seal in the room for good,
## in a hiss of steam. The flames light the Haar's fog (group "light").
##
## Pass 544 (bible 12.36): the pass 540 grade called the seals "the Haar's
## stacked orange blocks". Each tile drew the same four rectangle tongues and
## a rune, so a column read as a stack of identical crates. The flames are now
## one sheet of fire painted in whole world pixels on the master palette's heat
## ramp (`cells`): the field is sampled in world coordinates, so tiles that touch
## join without a seam; only a side with no seal beside it is ragged, only the
## top of a column licks upward in tongues, and only its foot sits on a bed of
## coals. Every other tile down a seal's left edge carries one dark rune,
## ringed with gold heat, from a set of three. It steps at `STEP_FPS`, like hand-drawn frames.

## Damage for touching the flames, and how often they can burn you.
const BURN := 10
const BURN_EVERY := 0.6
const DOUSE_TIME := 0.7
## The fire, coolest to white heat (red-1 to red-4, gold-4, gold-5, gold-7).
const HEAT: Array[Color] = [Color("501623"), Color("861d25"), Color("c02a20"), Color("e55439"), Color("f0c02e"), Color("edce6e"), Color("f7f1de")]
## The rune, burnt dark into the fire (red-0).
const RUNE := Color("1f0a11")
## The coal bed at a column's foot (bark-1, red-0) and its scorched socket (ash-0 to ash-2).
const COAL := Color("48201e")
const ASH: Array[Color] = [Color("161413"), Color("363330"), Color("58544c")]
## Steam off doused flames (stone-6, stone-7).
const STEAM: Array[Color] = [Color("cec5d3"), Color("ece8ed")]
## Every tone above, for the palette test.
const TONES := [HEAT[0], HEAT[1], HEAT[2], HEAT[3], HEAT[4], HEAT[5], HEAT[6], RUNE, COAL, ASH[0], ASH[1], ASH[2], STEAM[0], STEAM[1]]
## The flames' frames per second.
const STEP_FPS := 10.0
## How far the top of a column licks above its tile, at most.
const TONGUE := 5
## Which sides have a seal beside them (bits of `open`'s complement).
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8
## Three runes, 5 x 7, one per tile by its place in the column.
const RUNES := [
	["..#..", ".###.", "#.#.#", "..#..", "..#..", ".#.#.", "#...#"],
	["#...#", ".#.#.", "..#..", ".###.", "..#..", ".#.#.", "#...#"],
	["..#..", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "..#.."],
]

## The flag that remembers the room's seals went out: "seal:<room id>".
var flag_id := ""
var doused := false
var light_radius := 30.0
## 0 burning, 1 out.
var _t := 0.0
var _burn_cd := 0.0
var _shape: CollisionShape2D
var _clock := 0.0
var _step := -1
## The sides with a seal beside them (UP | DOWN | LEFT | RIGHT), found on the first draw.
var _joined := -1


func _ready() -> void:
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	add_to_group("fire_seal")
	add_to_group("water_target")
	add_to_group("light")
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	_shape.shape = rect
	add_child(_shape)
	_clock = fmod(global_position.x * 0.53 + global_position.y * 0.29, 10.0)
	if flag_id != "" and GameState.flag(flag_id):
		_go_out(true)


## A Deluge bolt struck this tile: every seal in the room goes out and stays out.
func douse() -> void:
	if doused:
		return
	if flag_id != "":
		GameState.set_flag(flag_id)
	for s in get_tree().get_nodes_in_group("fire_seal"):
		(s as FireSeal)._go_out(false)
	Sfx.play("douse", 0.0)
	Feel.add_trauma(0.15)


func _go_out(instant: bool) -> void:
	if doused:
		return
	doused = true
	_t = 1.0 if instant else 0.0
	_shape.set_deferred("disabled", true)
	remove_from_group("water_target")
	remove_from_group("light")
	queue_redraw()


func _physics_process(delta: float) -> void:
	_clock += delta
	var step := int(_clock * STEP_FPS)
	if doused:
		if _t < 1.0:
			_t = minf(1.0, _t + delta / DOUSE_TIME)
			queue_redraw()
		return
	if step != _step:
		_step = step
		queue_redraw()
	_burn_cd -= delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead or _burn_cd > 0.0:
		return
	if p.body_rect().grow(1.5).intersects(Rect2(global_position - Vector2(8, 8), Vector2(16, 16))):
		if p.receive_attack(BURN, self, false) != "":
			_burn_cd = BURN_EVERY


## The sides of this tile that touch another seal tile.
func joined() -> int:
	var bits := 0
	for s in get_tree().get_nodes_in_group("fire_seal"):
		if s == self:
			continue
		var d: Vector2 = (s as Node2D).global_position - global_position
		if d.distance_to(Vector2(0, -16)) < 2.0:
			bits |= UP
		elif d.distance_to(Vector2(0, 16)) < 2.0:
			bits |= DOWN
		elif d.distance_to(Vector2(-16, 0)) < 2.0:
			bits |= LEFT
		elif d.distance_to(Vector2(16, 0)) < 2.0:
			bits |= RIGHT
	return bits


func _draw() -> void:
	if _joined < 0:
		_joined = joined()
	var step := int(_clock * STEP_FPS)
	var px := cells(global_position, step, _joined, _t if doused else 0.0)
	# Draw each row as runs of one colour.
	var clear := Color(0, 0, 0, 0)
	for y in range(-8 - TONGUE - (30 if doused else 0), 8):
		var start := 0
		var col := clear
		for x in range(-8, 9):
			var c2: Color = px.get(Vector2i(x, y), clear) if x < 8 else clear
			if c2 == col:
				continue
			if col.a > 0.0:
				draw_rect(Rect2(start, y, x - start, 1), col)
			start = x
			col = c2


## An integer hash, 0 to 1.
static func hash01(a: int, b: int, c: int = 0) -> float:
	var h := (a * 374761393 + b * 668265263 + c * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Smooth value noise on an integer lattice, 0 to 1.
static func vnoise(x: float, y: float, layer: int = 0) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := hash01(ix, iy, layer)
	var b := hash01(ix + 1, iy, layer)
	var c := hash01(ix, iy + 1, layer)
	var d := hash01(ix + 1, iy + 1, layer)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Where the heat steps from one ramp tone to the next.
const STEPS: Array[float] = [0.28, 0.4, 0.52, 0.64, 0.76, 0.88]
## The flame field, sampled once: two octaves of value noise that tile every
## `FIELD_W` by `FIELD_H` world pixels, so a seal reads it rather than
## computing noise for every pixel every frame (pass 544, the frame budget).
const FIELD_W := 50
const FIELD_H := 100
static var _field := PackedFloat32Array()


## The tone for a heat from 0 to 1, or clear below the flame's edge.
static func tone(h: float) -> Color:
	if h < 0.16:
		return Color(0, 0, 0, 0)
	for i in STEPS.size():
		if h < STEPS[i]:
			return HEAT[i]
	return HEAT[6]


## Value noise whose lattice wraps every `wx` by `wy` cells, 0 to 1.
static func vnoise_wrap(x: float, y: float, layer: int, wx: int, wy: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := hash01(posmod(ix, wx), posmod(iy, wy), layer)
	var b := hash01(posmod(ix + 1, wx), posmod(iy, wy), layer)
	var c := hash01(posmod(ix, wx), posmod(iy + 1, wy), layer)
	var d := hash01(posmod(ix + 1, wx), posmod(iy + 1, wy), layer)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## The flame field at a world pixel (x) and a rise (y), 0 to 1.
static func field(x: int, y: int) -> float:
	if _field.is_empty():
		_field.resize(FIELD_W * FIELD_H)
		for fy in FIELD_H:
			for fx in FIELD_W:
				# 0.32 and 0.7 across 50 pixels, 0.16 and 0.4 down 100: whole lattices, so it tiles.
				_field[fy * FIELD_W + fx] = vnoise_wrap(fx * 0.32, fy * 0.16, 1, 16, 16) * 0.65 + vnoise_wrap(fx * 0.7, fy * 0.4, 2, 35, 40) * 0.35
	return _field[posmod(y, FIELD_H) * FIELD_W + posmod(x, FIELD_W)]


## Whether a tile carries a rune: the leftmost tile of a seal, every other
## row, so a column holds a few runes rather than a grid of them.
static func has_rune(origin: Vector2, joined: int) -> bool:
	return joined & LEFT == 0 and posmod(floori(origin.y / 16.0), 2) == 0


## The tile's pixels at frame `step`: local cell (from the tile's center, the
## tile spanning -8 to 7) to colour. `origin` is the tile's world position,
## `joined` the sides with a seal beside it, `out` 0 burning to 1 doused.
static func cells(origin: Vector2, step: int, joined: int, out: float = 0.0) -> Dictionary:
	var px := {}
	var ox := roundi(origin.x)
	var oy := roundi(origin.y)
	var top := joined & UP == 0
	var foot := joined & DOWN == 0
	if out >= 1.0:
		# Out: a scorched socket of ash at the column's foot, nothing else.
		if foot:
			for x in range(-8, 8):
				var r := hash01(ox + x, oy, 7)
				var hgt: int = (1 + int(r * 3.0)) if absi(x) < 7 else 1
				for k in hgt:
					px[Vector2i(x, 7 - k)] = ASH[0] if k == 0 else (ASH[2] if r > 0.8 and k == hgt - 1 else ASH[1])
		return px
	var lo := -8 - (TONGUE if top else 0)
	var lift := floori(step * 1.5)
	var reaches := PackedFloat32Array()
	if top:
		reaches.resize(16)
		for x in range(-8, 8):
			reaches[x + 8] = vnoise((ox + x) * 0.38, float(step) * 0.35, 4)
	for y in range(lo, 8):
		var wy := oy + y
		# Each open side rags on its own.
		var rag_l := vnoise(float(wy) * 0.45 + float(step) * 0.9, float(ox) * 0.05, 3) * 3.0
		var rag_r := vnoise(float(wy) * 0.45 + float(step) * 0.9, float(ox) * 0.05 + 7.3, 3) * 3.0
		for x in range(-8, 8):
			var wx := ox + x
			# The fire rises: the field scrolls up a pixel and a half a frame.
			var n := field(wx, wy + lift)
			# Deeper from an open side is hotter.
			var d := 99.0
			if joined & LEFT == 0:
				d = minf(d, float(x + 8) - rag_l)
			if joined & RIGHT == 0:
				d = minf(d, float(7 - x) - rag_r)
			var side := clampf((d + 1.5) / 4.0, -1.0, 1.0)
			var h := 0.12 + 0.6 * side + 0.7 * (n - 0.5)
			if y < -8:
				# Tongues above the column: each lick has its own height this frame.
				var reach := 3.0 + TONGUE * 0.9 * reaches[x + 8] * side
				var up := float(-8 - y)
				if up > reach:
					continue
				h -= 0.55 * up / maxf(reach, 1.0)
			if foot and y >= 6:
				# The coal bed the column stands on.
				var r := hash01(wx, wy, 5 + floori(step / 4.0))
				px[Vector2i(x, y)] = HEAT[3] if r > 0.86 else (HEAT[1] if r > 0.55 else COAL)
				continue
			h -= out * 1.1
			var c := tone(h + (hash01(wx, wy, step) - 0.5) * 0.06)
			if c.a > 0.0:
				px[Vector2i(x, y)] = c
	if out <= 0.0:
		if not has_rune(origin, joined):
			return px
		# The rune, burnt dark into the fire, ringed with gold heat that pulses.
		var glyph: Array = RUNES[posmod(floori(origin.y / 16.0) + floori(origin.x / 16.0), RUNES.size())]
		var ring := HEAT[5] if posmod(step, 8) < 4 else HEAT[4]
		for gy in glyph.size():
			var line: String = glyph[gy]
			for gx in line.length():
				if line[gx] != "#":
					continue
				for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					px[Vector2i(gx - 2, gy - 4) + o] = ring
		for gy in glyph.size():
			var line: String = glyph[gy]
			for gx in line.length():
				if line[gx] == "#":
					px[Vector2i(gx - 2, gy - 4)] = RUNE
	else:
		# Steam rises off the dying flames.
		for i in 4:
			var sx := -5 + i * 3 + roundi(sin(float(step) * 0.6 + i) * 2.0)
			var sy := -6 - roundi(out * 18.0) - (i % 2) * 4
			var puff := STEAM[1] if out < 0.5 else STEAM[0]
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, -1)]:
				if out < 0.85 or hash01(i, q.x, q.y) > 0.5:
					px[Vector2i(sx, sy) + q] = puff
	return px
