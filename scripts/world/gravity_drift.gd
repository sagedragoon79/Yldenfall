class_name GravityDrift
extends Node2D
## A pocket where the Everbloom's pull is wrong (the Evercrown, design bible 8.9; legend
## `v`, a rectangle of cells). Inside it the player weighs a fraction of what
## they should: they fall slowly, and a jump carries them about two and a half
## times as high, up ledges no jump could reach. Leave the pocket mid-flight
## and the true pull takes hold again. Drawn as a faint column of light with
## motes drifting up through it.

## How much of their weight the player keeps inside (gravity and top fall speed).
const PULL := 0.4
const WASH := Color("7a4ac8")
const MOTE := Color("8af0e8")
const EDGE := Color("4ae0d8")
## Peak opacity of the wash down the shaft's core.
const WASH_A := 0.26
## Rising speed of the motes (px/s).
const RISE := 26.0
## Column width (px) drawn per wash strip, and the number of fade sub-bands at
## the shaft's floor and crown.
const STRIP := 4.0
const FADE_BANDS := 5

## The pocket's cells (tiles).
var cells := Rect2i()

var _t := 0.0


func _ready() -> void:
	z_index = -1
	position = Vector2(cells.position * Room.TILE)


func pixel_rect() -> Rect2:
	return Rect2(Vector2(cells.position * Room.TILE), Vector2(cells.size * Room.TILE))


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	# The body's centre decides: half in, half out still floats.
	if p != null and not p.dead and pixel_rect().has_point(p.body_rect().get_center()):
		p.gravity_scale = PULL
	queue_redraw()


## The soft horizontal profile of the light column: ~0 at the two sides and
## full across the interior, with a brighter core down the middle, so the pocket
## reads as a shaft of light instead of a flat slab with hard box edges (bible
## 8.9, 12.16).
static func column_alpha(x: float, w: float) -> float:
	var feather: float = minf(16.0, w * 0.45)
	var side: float = clampf(minf(x, w - x) / maxf(feather, 1.0), 0.0, 1.0)
	var d: float = absf(x - w * 0.5) / maxf(w * 0.5, 1.0)
	var core: float = 0.55 + 0.45 * (1.0 - d * d)
	return side * core


## The vertical envelope of the shaft: the rising light fades in at the floor and
## out at the crown, so the column is not read as a capped rectangle.
static func rise_alpha(y: float, h: float) -> float:
	var feather: float = minf(24.0, h * 0.3)
	return minf(clampf(y / maxf(feather, 1.0), 0.0, 1.0),
			clampf((h - y) / maxf(feather, 1.0), 0.0, 1.0))


func _draw() -> void:
	var w := float(cells.size.x * Room.TILE)
	var h := float(cells.size.y * Room.TILE)
	var shimmer := 0.9 + 0.1 * sin(_t * 2.2)
	var feather := minf(24.0, h * 0.3)
	var seg := feather / float(FADE_BANDS)
	var body := maxf(h - 2.0 * feather, 0.0)
	# The wash as feathered vertical strips: soft at the sides, brighter at the
	# core, and faded in at the floor and out at the crown — a column of light,
	# not a translucent box.
	var sx := 0.0
	while sx < w:
		var a := WASH_A * column_alpha(sx + STRIP * 0.5, w) * shimmer
		if a > 0.004:
			draw_rect(Rect2(sx, feather, STRIP, body), Color(WASH, a))
			for b in FADE_BANDS:
				var ba := a * float(b + 1) / float(FADE_BANDS)
				draw_rect(Rect2(sx, seg * b, STRIP, seg), Color(WASH, ba))
				draw_rect(Rect2(sx, h - seg * (b + 1), STRIP, seg), Color(WASH, ba))
		sx += STRIP
	# Bands of light climbing the shaft, kept within the feathered interior so
	# their ends never draw a hard edge.
	var edge := minf(16.0, w * 0.45)
	for i in 3:
		var y := h - fmod(_t * RISE * 0.6 + i * h / 3.0, h)
		draw_rect(Rect2(edge, y, maxf(w - 2.0 * edge, 0.0), 10.0), Color(EDGE, 0.08 * rise_alpha(y, h)))
	# A bright updraft core pulsing down the centre — "where the light drifts
	# upward, so will you" (the Drift Well's sign).
	draw_rect(Rect2(w * 0.5 - 1.0, feather, 2.0, body), Color(MOTE, 0.12 * shimmer))
	# Motes drifting up, each on its own column and pace, swaying a little.
	var count := int(w * h / 380.0) + 4
	for i in count:
		var speed := RISE * (0.6 + float((i * 37) % 10) / 10.0)
		var y := h - fmod(_t * speed + float((i * 131) % 977), h)
		var x := fmod(float(i * 53 % 997), w) + sin(_t * 1.7 + i) * 2.0
		var k := clampf(minf(y, h - y) / 24.0, 0.0, 1.0)
		var sz := 1.0 + float(i % 2)
		# A short streak below each mote: they are rising, not falling.
		draw_rect(Rect2(x, y + sz, sz * 0.5 + 0.5, 4.0), Color(MOTE, 0.25 * k))
		draw_rect(Rect2(x, y, sz, sz), Color(MOTE, 0.9 * k))
