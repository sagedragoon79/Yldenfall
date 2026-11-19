class_name BouncePod
extends Node2D
## A bounce-pod (High Boughs, design bible 3.2 and 6.6): a fat seed-pod growing on
## the bough. Land on it from above and it squashes and throws you about nine
## tiles up (MovementTuning.pod_bounce). It isn't solid: walk into it and you
## walk through, so a hop onto it is all it takes. Legend `@`, standing on the
## floor of its cell.

## The pod's top, above its base (world pixels), and its half width.
const HEIGHT := 10.0
const HALF_W := 9.0
## How far below the top the feet may be and still count as landing on it.
const CATCH := 10.0
const SQUASH_TIME := 0.3
## Pass 610 (bible 12.87): the pod was eleven plain rectangles in three leaf
## greens, and in the green Canopy Bridge the pass 605 grade called it "a flat
## green placeholder block". It is now a pixel-drawn ripe gourd: a round,
## ribbed, pale gold bulb lit from the upper left, with the dried flower's nub
## on its crown, seated in three green sepals. Gold on green, it stands out
## from the leaves it grows among. Its size, its top and the catch are unchanged.
const OUTLINE := Color("161413")
const POD_DEEP := Color("6e5135")
const POD_DARK := Color("9c7f44")
const POD_MID := Color("bea860")
const POD := Color("edce6e")
const POD_LIT := Color("f0dfa8")
const SHINE := Color("f7f1de")
const NUB := Color("432d23")
const LEAF_LINE := Color("0d1c12")
const LEAF_DARK := Color("1e4825")
const LEAF := Color("2b782c")
const LEAF_LIT := Color("49aa36")
const LEAF_TIP := Color("74cd51")
## The bulb's ramp, deep to shine.
const RAMP := [POD_DEEP, POD_DARK, POD_MID, POD, POD_LIT, SHINE]
## Every tone above, for the palette test.
const TONES := [OUTLINE, POD_DEEP, POD_DARK, POD_MID, POD, POD_LIT, SHINE, NUB, LEAF_LINE, LEAF_DARK, LEAF, LEAF_LIT, LEAF_TIP]
## The bulb, in half-pixels (the 2x render density): its radii and its center's height.
const RX := 17.0
const RY := 9.5
const CY := 10.5
## Where the ribs cross the bulb, as a share of its half width at each row.
const RIBS := [-0.74, -0.34, 0.34, 0.74]
## The three sepals: [polygon, base of the midrib, tip], in half-pixels, y up.
const SEPALS := [
	[[Vector2(-13, 0), Vector2(-4, 0), Vector2(-8, 4), Vector2(-14, 7), Vector2(-20, 8), Vector2(-17, 4)], Vector2(-9, 0), Vector2(-19, 8)],
	[[Vector2(13, 0), Vector2(4, 0), Vector2(8, 4), Vector2(14, 7), Vector2(20, 8), Vector2(17, 4)], Vector2(9, 0), Vector2(19, 8)],
	[[Vector2(-5, 0), Vector2(5, 0), Vector2(3, 5), Vector2(0, 8), Vector2(-3, 5)], Vector2(0, 0), Vector2(0, 8)],
]

static var _pixels: Dictionary = {}

var _squash := 0.0
var _feet_before := INF


func _ready() -> void:
	add_to_group("bounce_pod")


func top_y() -> float:
	return global_position.y - HEIGHT


func _physics_process(delta: float) -> void:
	_squash = maxf(0.0, _squash - delta)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead:
		return
	var feet := p.global_position
	var over := absf(feet.x - global_position.x) <= HALF_W + 4.0
	# Landing: the feet come down through the pod's top while falling.
	if over and p.velocity.y >= 0.0 and _feet_before <= top_y() + 2.0 and feet.y >= top_y() and feet.y <= top_y() + CATCH:
		launch(p)
	_feet_before = feet.y
	if _squash > 0.0:
		queue_redraw()


func launch(p: Player) -> void:
	p.global_position.y = top_y()
	p.pod_launch()
	_squash = SQUASH_TIME
	_feet_before = INF
	Sfx.play("pod", 0.1, 0.0)
	queue_redraw()


## The pod's art: half-pixel cell (x right, y up from the base) to color.
## Built once. For the draw and for tests.
static func pixels() -> Dictionary:
	if not _pixels.is_empty():
		return _pixels
	var art := {}
	# The bulb: a plump ellipse shaded as a ball lit from the upper left.
	for y in range(1, 21):
		var ny := (y + 0.5 - CY) / RY
		var half := RX * pow(maxf(0.0, 1.0 - pow(absf(ny), 2.4)), 1.0 / 2.4)
		for x in range(-18, 18):
			var dx := x + 0.5
			if absf(dx) > half:
				continue
			var nx := dx / RX
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var l := -0.45 * nx + 0.6 * ny + 0.55 * nz
			var step := 0
			for edge: float in [-0.35, -0.05, 0.25, 0.68, 0.9]:
				if l > edge:
					step += 1
			for rib: float in RIBS:
				if x == floori(rib * half):
					step = maxi(0, step - 1)
			art[Vector2i(x, y)] = RAMP[step]
	# The dried flower's nub on the crown.
	art[Vector2i(-1, 20)] = NUB
	art[Vector2i(0, 20)] = NUB
	# The sepals, over the bulb's foot: lit on the side toward the light, a dark midrib.
	for sepal: Array in SEPALS:
		var poly := PackedVector2Array(sepal[0])
		var base: Vector2 = sepal[1]
		var tip: Vector2 = sepal[2]
		var along := (tip - base).normalized()
		var leaf := {}
		for y in range(0, 10):
			for x in range(-21, 21):
				var c := Vector2(x + 0.5, y + 0.5)
				if not Geometry2D.is_point_in_polygon(c, poly):
					continue
				var off := (c - base) - along * along.dot(c - base)
				leaf[Vector2i(x, y)] = LEAF_DARK if off.length() < 0.6 else (LEAF_LIT if off.dot(Vector2(-0.6, 0.8)) > 0.0 else LEAF)
		for cell: Vector2i in leaf:
			if not leaf.has(cell + Vector2i(0, 1)) and leaf[cell] == LEAF_LIT:
				leaf[cell] = LEAF_TIP
			art[cell] = leaf[cell]
	# One dark line round the whole of it: the leaves' own near them, the bulb's elsewhere.
	var line := {}
	for cell: Vector2i in art:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := cell + d
			if not art.has(n) and n.y >= 0:
				line[n] = LEAF_LINE if art[cell] in [LEAF_DARK, LEAF, LEAF_LIT, LEAF_TIP] else OUTLINE
	art.merge(line)
	_pixels = art
	return _pixels


func _draw() -> void:
	# Squashed flat at the launch, then springing back past round.
	var k := _squash / SQUASH_TIME
	var sy := 1.0 - 0.45 * k * k + 0.15 * sin(k * PI) * (1.0 - k)
	var sx := 1.0 + 0.3 * k * k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	var art := pixels()
	for cell: Vector2i in art:
		draw_rect(Rect2(cell.x * 0.5, -(cell.y + 1) * 0.5, 0.5, 0.5), art[cell])
	draw_set_transform(Vector2.ZERO)
