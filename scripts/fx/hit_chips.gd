class_name HitChips
extends Node2D
## A blow knocks chips off the foe (design bible 6.7, pass 621). The pass 615 grade
## read a landed hit as "one small spark with no foe flash, streak or debris in the
## frame": the spark and the streak are white and gold whatever is struck, so nothing
## in the frame was *of the foe*. A blow that wounds now breaks a few chips off the
## body, in the foe's own colors (`Enemy.chip_colors`), thrown on along the blow and
## a little up, falling under their own weight. Each chip is a splinter, a small kite
## that points the way it flies, over a near-black copy of itself one pixel lower, like
## the sprites' outline, so it reads over any backdrop and never as a square hole.
##
## The chips count down on the game clock, so the hit-stop holds them in the air with
## the spark; they leap out fast and are braked hard, so they are already clear of the
## body in the first frames after it.

## Chips from an ordinary blow, and from a heavy one (a finisher, a thrust: its
## push comes in longer than `HEAVY_AT`).
const COUNT := 6
const HEAVY_COUNT := 10
const HEAVY_AT := 1.5
## Thrown within `SPREAD` radians of the blow's line, which is tipped up by `LIFT`.
const SPREAD := 0.7
const LIFT := 0.45
const SPEED_MIN := 260.0
const SPEED_MAX := 420.0
## Braked each step (the leap out), then pulled down.
const DRAG := 0.94
const GRAVITY := 620.0
const LIFE_MIN := 0.34
const LIFE_MAX := 0.5
## A chip is a splinter `LONG` world pixels long and `WIDE` across until its last
## `SHRINK` of life, then `SMALL` of that. It never fades: pixel art has no
## half-there pixels.
const LONG := 6.0
const WIDE := 3.0
const SMALL := 0.6
const SHRINK := 0.35
## Every chip starts `AHEAD_MIN` to `AHEAD_MAX` on from the middle of the body, the
## way the blow leaves it, and within `SCATTER` above or below.
const AHEAD_MIN := 6.0
const AHEAD_MAX := 12.0
const SCATTER := 6.0
## A chip is lit by the blow: its tone is mixed this far toward the flash's warm cream.
const LIT := 0.2
const CREAM := Color(1.0, 0.92, 0.76)
const UNDER := Color("120c16")
## What a foe with no sheet to sample is chipped in: pale bone and its shade.
const BONE: Array[Color] = [Color("d9cdb4"), Color("8f8472")]
## Drawn over a struck foe (`Enemy.STRUCK_Z` 3) and under the spark (4).
const Z := 3

## The chips' own dice: a blow must not move the game's (a seeded drop, a foe's next
## choice), so nothing here draws on the global generator.
static var _rng := RandomNumberGenerator.new()

## The blow's line and the colors it was set up with (tests).
var dir := Vector2.RIGHT
var colors: Array[Color] = []
## Each chip: [position, velocity, life left, whole life, color].
var chips: Array = []


## Adds chips to `parent` at global `at`, thrown along `blow` (a push: longer than
## `HEAVY_AT` for a heavy blow), in `tones` (the first is used most).
static func spawn(parent: Node, at: Vector2, blow: Vector2, tones: Array[Color]) -> HitChips:
	var c := HitChips.new()
	c.setup(blow, tones)
	parent.add_child(c)
	c.global_position = at
	return c


func setup(blow: Vector2, tones: Array[Color]) -> void:
	dir = blow.normalized() if blow != Vector2.ZERO else Vector2.RIGHT
	colors = tones if not tones.is_empty() else BONE
	var line := (dir + Vector2(0, -LIFT)).normalized()
	var count := HEAVY_COUNT if blow.length() > HEAVY_AT else COUNT
	for i in count:
		var way := line.rotated(_rng.randf_range(-SPREAD, SPREAD))
		var life := _rng.randf_range(LIFE_MIN, LIFE_MAX)
		# Two chips in three take the body's main tone.
		var tone: Color = colors[0] if i % 3 != 2 else colors[colors.size() - 1]
		tone = tone.lerp(CREAM, LIT)
		var from := dir * _rng.randf_range(AHEAD_MIN, AHEAD_MAX) + Vector2(0, _rng.randf_range(-SCATTER, SCATTER))
		chips.append([from, way * _rng.randf_range(SPEED_MIN, SPEED_MAX), life, life, tone])
	z_index = Z


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var alive := false
	for c: Array in chips:
		c[2] -= delta
		if c[2] > 0.0:
			alive = true
			c[1] = (c[1] as Vector2) * DRAG + Vector2(0, GRAVITY) * delta
			c[0] += (c[1] as Vector2) * delta
	if not alive:
		queue_free()
	queue_redraw()


## How many chips are still in the air.
func flying() -> int:
	var n := 0
	for c: Array in chips:
		if c[2] > 0.0:
			n += 1
	return n


## How much of its full size a chip with `left` of its `whole` life is drawn at.
static func size_at(left: float, whole: float) -> float:
	return 1.0 if left / whole > SHRINK else SMALL


## A splinter at `at`, pointing along `way`: a kite, long ahead and short behind.
static func splinter(at: Vector2, way: Vector2, k: float) -> PackedVector2Array:
	var along := way * LONG * k
	var across := way.orthogonal() * WIDE * 0.5 * k
	return PackedVector2Array([at + along * 0.6, at + across, at - along * 0.4, at - across])


func _draw() -> void:
	for c: Array in chips:
		if c[2] <= 0.0:
			continue
		var k := size_at(c[2], c[3])
		var vel: Vector2 = c[1]
		var way := vel.normalized() if vel != Vector2.ZERO else dir
		var at := ((c[0] as Vector2) * 2.0).round() / 2.0
		draw_colored_polygon(splinter(at + Vector2(0, 1), way, k), UNDER)
		draw_colored_polygon(splinter(at, way, k), c[4])
