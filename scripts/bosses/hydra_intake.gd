class_name HydraIntake
extends StaticBody2D
## One of the Haar Spring cistern's three intake pipes (design bible 8.4). Its
## mouth opens to one side, and a Deluge bolt flying into it (group "water_target")
## sends a share of a cistern down the pipe. A bolt that strikes the pipe from behind
## only splashes. Each intake runs once until the water it gave is boiled away.
##
## Each pipe feeds one head (Sean, 2026-11-22: "each pipe represents a head and depending
## on which one is filled last, determines which head becomes vulnerable"): a side head's
## pipe stands on its own pillar of the arch, the middle head's hangs from the ceiling
## over the cistern, and a plate by the mouth bears its head's breath. The pipe filled
## last picks the head a full cistern douses (`HaarWyrm._fight`), and its head reacts as it
## fills. A dead head's pipe still runs (it was capped until 2026-11-24), its plate dark:
## filled last, it douses nothing.
##
## The mouth is a brass bell under a water mark (Sean, 2026-11-20: "I didn't notice a
## place to shoot deluge into"): the mark pulses while the intake wants water, burns
## steady while it runs, and goes dark while the cistern takes none. A running pipe
## pours from its spout into the cistern, foaming where it lands (Sean, 2026-11-22:
## "a vfx for water coming out of the pipe into the cistern").

## Which way the mouth opens: -1 west, 1 east. A bolt must fly against it.
var facing := 1
var cistern: HydraCistern
## Running: its share of the water is in the cistern.
var flowing := false
## Counts down the gush drawn as it starts to run.
var gush := 0.0
## The head it feeds (an index into `HaarWyrm.heads`, -1 for none) and that head's breath.
var head := -1
var breath := ""
## Its head is dead: the pipe still runs, but its plate goes dark.
var head_dead := false
## Hung from the ceiling (the middle head's): the pipe comes down from `ceiling_y` (world)
## to the mouth, and its spout pours straight down into the cistern under it.
var hung := false
var ceiling_y := 64.0

const SIZE := 16.0
const PIPE := Color("5b4a3a")
const PIPE_LIGHT := Color("8a6f52")
const PIPE_DARK := Color("2e241c")
const RIM := Color("b08a5a")
const RIM_LIGHT := Color("e6c48a")
const RIM_DARK := Color("6b4f2f")
const PLATE := Color("2b2925")
const MARK_DARK := Color("2b4a66")
const IRON := Color("565b63")
const IRON_LIGHT := Color("9aa1ab")
const IRON_DARK := Color("1c1f24")
const SIGIL := Color("f4d24c")
const SIGIL_DARK := Color("6b5a2a")
## The bell's flare: how far out from the pipe each step begins, and its half height.
const BELL := [[2.0, 8.0], [5.0, 10.0], [8.0, 13.0]]
## The water mark: a drop, row by row (columns of a 5 px wide glyph).
const DROP := [[2], [2], [1, 2, 3], [1, 2, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [1, 2, 3]]
## Each head's breath, as a 5 by 5 mark on the pipe's second plate.
const SIGILS := {
	"plume": [".##..", "####.", "#####", ".....", "#####"],
	"geyser": ["#.#.#", ".###.", "..#..", "..#..", "#####"],
	"fog": [".###.", "#...#", "#.#.#", "#...#", ".###."],
}
const WATER := Color("4aa3df")
const WATER_LIGHT := Color("bfe8ff")
const WATER_DEEP := Color("2a5d9c")
const FOAM := Color("eef8ff")

## Draws the stream's foot over the cistern's water (it is a layer above it).
var _foam: Node2D


func _ready() -> void:
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	# Behind the hero: the pipe runs along the wall at his back.
	z_index = -1
	add_to_group("water_target")
	add_to_group("hydra_intake")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	shape.shape = rect
	add_child(shape)
	_foam = Node2D.new()
	_foam.z_as_relative = false
	# Over the cistern's water (2; the pipes come after it in the room), under the grate (3).
	_foam.z_index = 2
	_foam.draw.connect(_draw_foam)
	add_child(_foam)


## True while a bolt into the mouth would fill a share.
func wants() -> bool:
	return not flowing and cistern != null and cistern.accepts()


## A Deluge bolt struck the intake (TorrentBolt): only one flying into the mouth counts.
func take_water(bolt: Node2D) -> bool:
	var v: Vector2 = bolt.get("velocity") if bolt.get("velocity") is Vector2 else Vector2.ZERO
	if signf(v.x) != -facing:
		return false
	douse()
	return true


func douse() -> void:
	if flowing or cistern == null or not cistern.accepts():
		Sfx.play("splash", 0.1, -6.0)
		return
	flowing = true
	gush = 0.8
	cistern.fill_from(self)


func reset() -> void:
	flowing = false


## Where its water leaves the spout, in the world.
func spout() -> Vector2:
	return global_position + _spout_local()


func _spout_local() -> Vector2:
	if hung:
		return Vector2(-float(facing) * 22.0, 14.0)
	if cistern == null:
		return Vector2.ZERO
	var c := cistern.inside
	var west := global_position.x < c.get_center().x
	var wall_x := (c.position.x - 8.0 if west else c.end.x + 8.0) - global_position.x
	var rim_y := c.position.y - HydraCistern.LIP - global_position.y
	var into := 1.0 if west else -1.0
	return Vector2(wall_x + into * 17.0, rim_y - 6.0)


func _process(delta: float) -> void:
	gush -= delta
	queue_redraw()
	_foam.queue_redraw()


func _draw() -> void:
	var f := float(facing)
	var now := Time.get_ticks_msec() * 0.001
	if hung:
		_draw_hung_pipe(f)
	elif cistern != null:
		_draw_wall_pipe()
	if flowing and cistern != null:
		_draw_stream(now)
	draw_rect(Rect2(-8, -7, 16, 14), PIPE_DARK)
	draw_rect(Rect2(-8, -6, 16, 12), PIPE)
	draw_rect(Rect2(-8, -6, 16, 3), PIPE_LIGHT)
	# The mouth: a brass bell flaring out the way it opens, big enough to aim at.
	for step: Array in BELL:
		var x0 := minf(float(step[0]) * f, (float(step[0]) + 3.0) * f)
		var hh := float(step[1])
		draw_rect(Rect2(x0, -hh - 1.0, 3, hh * 2.0 + 2.0), PIPE_DARK)
		draw_rect(Rect2(x0, -hh, 3, hh * 2.0), RIM)
		draw_rect(Rect2(x0, -hh, 3, 2), RIM_LIGHT)
		draw_rect(Rect2(x0, hh - 2.0, 3, 2), RIM_DARK)
	# Its rolled lip, and the dark of the throat just inside it.
	var mx := 11.0 * f
	draw_rect(Rect2(minf(mx, mx + 2.0 * f), -15, 2, 30), PIPE_DARK)
	draw_rect(Rect2(minf(mx, mx + 2.0 * f), -14, 2, 28), RIM_LIGHT)
	draw_rect(Rect2(minf(mx - 2.0 * f, mx), -11, 2, 22), Color.BLACK if not flowing else Color("1d3a52"))
	# The water mark over it: a drop cut in a brass-bound plate.
	var want := wants()
	var mark := MARK_DARK
	if flowing:
		mark = WATER
	elif want:
		mark = WATER.lerp(WATER_LIGHT, 0.5 + 0.5 * sin(now * 4.0 + position.x * 0.05))
	# Over the mouth; under it on the hung pipe, whose top is in the ceiling.
	var plate := Vector2(6.0 * f - 6.0, 18.0 if hung else -34.0)
	if want or flowing:
		draw_circle(plate + Vector2(6.5, 7.5), 12.0 + (2.0 * sin(now * 4.0 + position.x * 0.05) if want else 0.0), Color(WATER, 0.16))
		draw_circle(plate + Vector2(6.5, 7.5), 8.0, Color(WATER, 0.14))
	draw_rect(Rect2(plate, Vector2(13, 15)), RIM_DARK)
	draw_rect(Rect2(plate, Vector2(13, 1)), RIM)
	draw_rect(Rect2(plate + Vector2(1, 1), Vector2(11, 13)), PLATE)
	for row in DROP.size():
		for col: int in DROP[row]:
			draw_rect(Rect2(plate + Vector2(4 + col, 4 + row), Vector2(1, 1)), mark)
	if want or flowing:
		draw_rect(Rect2(plate + Vector2(5, 8), Vector2(1, 2)), WATER_LIGHT)
	_draw_sigil(plate + Vector2(-12.0 if f > 0.0 else 14.0, 2.0))
	if want:
		# A beckoning drip of condensation off the lip: it wants water.
		var d := fmod(now * 0.8 + position.x * 0.01, 1.0)
		draw_rect(Rect2(mx - 1, 15 + d * 10.0, 2, 2), Color(WATER_LIGHT, 0.7 * (1.0 - d)))
	if gush > 0.0:
		var g := clampf(gush / 0.8, 0.0, 1.0)
		draw_rect(Rect2(mx - 3.0 * f - 2.0, -6, 5, 12), Color(WATER, g))
		draw_rect(Rect2(mx - 3.0 * f - 1.0, -4, 2, 8), Color(WATER_LIGHT, g))
		# The splash thrown back out of the bell.
		for k in 4:
			var out := (1.0 - g) * 14.0 + float(k) * 2.0
			draw_rect(Rect2(mx + out * f, -8.0 + float(k) * 5.0 + (1.0 - g) * 6.0, 2, 2), Color(WATER_LIGHT, g))


## A side pipe: back behind the mouth to the cistern's nearer end, down to its lip, and
## a short elbow turning in over the pit.
func _draw_wall_pipe() -> void:
	var c := cistern.inside
	var west := global_position.x < c.get_center().x
	var wall_x := (c.position.x - 8.0 if west else c.end.x + 8.0) - global_position.x
	var rim_y := c.position.y - HydraCistern.LIP - global_position.y
	var into := 1.0 if west else -1.0
	var spout_x := wall_x + into * 14.0
	draw_rect(Rect2(minf(0.0, wall_x) - 4.0, -6, absf(wall_x) + 8.0, 12), PIPE_DARK)
	draw_rect(Rect2(minf(0.0, wall_x) - 4.0, -5, absf(wall_x) + 8.0, 10), PIPE)
	draw_rect(Rect2(minf(0.0, wall_x) - 4.0, -5, absf(wall_x) + 8.0, 2), PIPE_LIGHT)
	draw_rect(Rect2(wall_x - 6.0, -6, 12, rim_y + 6.0), PIPE_DARK)
	draw_rect(Rect2(wall_x - 5.0, -5, 10, rim_y + 5.0), PIPE)
	draw_rect(Rect2(wall_x - 5.0, -5, 2, rim_y + 5.0), PIPE_LIGHT)
	# Bands where the pipe was riveted together.
	var y := 8.0
	while y < rim_y - 4.0:
		draw_rect(Rect2(wall_x - 6.0, y, 12, 2), RIM)
		y += 24.0
	# The spout: a short elbow in over the pit.
	draw_rect(Rect2(minf(wall_x, spout_x) - 1.0, rim_y - 11.0, absf(spout_x - wall_x) + 2.0, 12), PIPE_DARK)
	draw_rect(Rect2(minf(wall_x, spout_x), rim_y - 10.0, absf(spout_x - wall_x), 10), PIPE)
	draw_rect(Rect2(minf(wall_x, spout_x), rim_y - 10.0, absf(spout_x - wall_x), 2), PIPE_LIGHT)
	draw_rect(Rect2(spout_x - 1.0, rim_y - 12.0, 3, 14), RIM)


## The middle head's pipe: down from the ceiling, an elbow turning the mouth sideways, and
## under the elbow a spout that pours straight down into the cistern.
func _draw_hung_pipe(f: float) -> void:
	var drop_x := -f * 22.0
	var top := ceiling_y - global_position.y
	# The run from the ceiling, with a bracket where it is bolted to the stone.
	draw_rect(Rect2(drop_x - 6.0, top, 12, -top + 6.0), PIPE_DARK)
	draw_rect(Rect2(drop_x - 5.0, top, 10, -top + 5.0), PIPE)
	draw_rect(Rect2(drop_x - 5.0, top, 2, -top + 5.0), PIPE_LIGHT)
	draw_rect(Rect2(drop_x - 9.0, top, 18, 3), IRON_DARK)
	draw_rect(Rect2(drop_x - 9.0, top, 18, 1), IRON_LIGHT)
	var y := top + 10.0
	while y < -8.0:
		draw_rect(Rect2(drop_x - 6.0, y, 12, 2), RIM)
		y += 14.0
	# Across to the mouth.
	draw_rect(Rect2(minf(0.0, drop_x) - 2.0, -6, absf(drop_x) + 4.0, 12), PIPE_DARK)
	draw_rect(Rect2(minf(0.0, drop_x) - 2.0, -5, absf(drop_x) + 4.0, 10), PIPE)
	draw_rect(Rect2(minf(0.0, drop_x) - 2.0, -5, absf(drop_x) + 4.0, 2), PIPE_LIGHT)
	# The spout under the elbow, ringed in brass.
	draw_rect(Rect2(drop_x - 4.0, 5, 8, 8), PIPE_DARK)
	draw_rect(Rect2(drop_x - 3.0, 5, 6, 7), PIPE)
	draw_rect(Rect2(drop_x - 5.0, 11, 10, 3), RIM)
	draw_rect(Rect2(drop_x - 5.0, 11, 10, 1), RIM_LIGHT)


## Its head's breath on a small brass plate beside the water mark.
func _draw_sigil(at: Vector2) -> void:
	if not SIGILS.has(breath):
		return
	draw_rect(Rect2(at, Vector2(9, 9)), RIM_DARK)
	draw_rect(Rect2(at, Vector2(9, 1)), RIM)
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(7, 7)), PLATE)
	var col := SIGIL_DARK if head_dead else SIGIL
	var rows: Array = SIGILS[breath]
	for r in rows.size():
		var line: String = rows[r]
		for c in line.length():
			if line[c] == "#":
				draw_rect(Rect2(at + Vector2(2 + c, 2 + r), Vector2(1, 1)), col)


## The water falling from the spout to the water already there (or the bed): a body that
## wavers as it falls, a bright core, and beads breaking off its edges. Thick while it gushes.
func _draw_stream(now: float) -> void:
	var from := _spout_local()
	var to := cistern.surface_y() - global_position.y
	var length := to - from.y
	if length <= 0.0:
		return
	var g := clampf(gush / 0.8, 0.0, 1.0)
	var half := 2.5 + g * 1.5
	var y := 0.0
	while y < length:
		var seg := minf(3.0, length - y)
		# It wavers more the further it has fallen, and narrows to a rope as it speeds up.
		var k := y / maxf(length, 1.0)
		var wx := roundf(sin(now * 5.0 + y * 0.08 + position.x) * (0.3 + k * 0.7))
		var w := half * (1.0 - k * 0.25)
		draw_rect(Rect2(from.x + wx - w, from.y + y, w * 2.0, seg), Color(WATER, 0.85))
		draw_rect(Rect2(from.x + wx - w, from.y + y, 1, seg), Color(WATER_DEEP, 0.7))
		draw_rect(Rect2(from.x + wx - 0.5, from.y + y, 1, seg), Color(WATER_LIGHT, 0.95))
		y += 3.0
	# Ripples racing down the stream.
	var r := fmod(now * 90.0, 8.0)
	while r < length - 2.0:
		draw_rect(Rect2(from.x - half, from.y + r, half * 2.0, 1), Color(FOAM, 0.55))
		r += 8.0
	# Beads peeling off its edges as it falls.
	for i in 6:
		var ph := fmod(now * 1.3 + float(i) * 0.173 + position.x * 0.01, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var by := from.y + ph * length
		var bx := from.x + side * (half + 1.0 + ph * 3.0)
		draw_rect(Rect2(bx, by, 1, 2), Color(WATER_LIGHT, 0.8 * (1.0 - ph * 0.6)))
	# A breath of mist where it leaves the spout.
	draw_circle(from + Vector2(0, 2), 3.0 + g * 2.0, Color(FOAM, 0.18 + g * 0.2))


## Where the stream strikes the water: churning foam, rings spreading out over the surface,
## and spray thrown up and falling back. Bigger while the pipe gushes.
func _draw_foam() -> void:
	if not flowing or cistern == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	var g := clampf(gush / 0.8, 0.0, 1.0)
	var at := Vector2(spout().x, cistern.surface_y()) - global_position
	var lo := cistern.inside.position.x - global_position.x
	var hi := cistern.inside.end.x - global_position.x
	# Rings running out from the foot of the stream.
	for i in 3:
		var ph := fmod(now * 0.9 + float(i) / 3.0, 1.0)
		var rw := 4.0 + ph * (26.0 + g * 14.0)
		var a := (1.0 - ph) * 0.6
		var x0 := maxf(at.x - rw, lo)
		var x1 := minf(at.x + rw, hi)
		if x1 > x0:
			_foam.draw_rect(Rect2(x0, at.y - 1.0, 2, 1), Color(FOAM, a))
			_foam.draw_rect(Rect2(x1 - 2.0, at.y - 1.0, 2, 1), Color(FOAM, a))
			_foam.draw_rect(Rect2(x0 + 2.0, at.y, maxf(x1 - x0 - 4.0, 0.0), 1), Color(WATER_LIGHT, a * 0.4))
	# The churn: white blobs boiling up at the foot.
	for i in 5:
		var ph := fmod(now * 2.2 + float(i) * 0.31, 1.0)
		var bx := at.x + sin(float(i) * 2.1 + now * 3.0) * (3.0 + g * 3.0)
		_foam.draw_circle(Vector2(bx, at.y - 1.0 - ph * 2.0), 1.5 + (1.0 - ph) * (1.5 + g * 1.5), Color(FOAM, 0.75 * (1.0 - ph)))
	# Spray: beads thrown up and out, falling back.
	for i in 6:
		var ph := fmod(now * 1.7 + float(i) * 0.167, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var reach := 4.0 + float(i % 3) * 3.0 + g * 6.0
		var sx := at.x + side * reach * ph
		var sy := at.y - (sin(ph * PI) * (6.0 + g * 8.0))
		_foam.draw_rect(Rect2(sx, sy, 1, 1), Color(WATER_LIGHT, 0.9 * (1.0 - ph)))
