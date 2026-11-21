class_name WindCurrent
extends Node2D
## A wind current across the High Boughs' open sky (design bible 6.9; legend `>`
## for a current blowing east and `<` west, a rectangle of cells). In the air
## with the middle of the body inside it, the player is carried along: the run
## target shifts by wind_speed with the wind (no headway against it) and the
## current bears them level. On a floor you brace and it doesn't move you; hold
## Down to drop out. Once the Sky Spring is restored (`spring:sky`) the storm
## breaks and every current in the High Boughs blows the other way.
## Drawn as gusts of air and drifting leaves racing along the band (bible 12.108).

const FLAG := "spring:sky"
const STREAK := Color("f4fbff")
## The wash over the band at its middle, and how far in from each edge it fades
## (px, in WASH_STEPS steps), so the band has no ruled border.
const WASH := 0.05
const WASH_FEATHER := 8.0
const WASH_STEPS := 4
## A gust: a line of air a pixel thick, drawn in GUST_PARTS pieces from a faint
## tail to its head downwind, bowed GUST_BOW px along its length. One to every
## GUST_EVERY px of the band (and GUST_SPARE more), racing at GUST_SPEED px/s.
const GUST_ALPHA := 0.62
const GUST_PARTS := 5
const GUST_BOW := 2.0
const GUST_EVERY := 22.0
const GUST_SPARE := 3
const GUST_SPEED := 260.0
const LEAF := Color("7cbf52")
## The inner rings has no leaves: pale flecks of the void ride its winds.
const FLECK := Color("c9c6d6")

## The current's cells (tiles).
var cells := Rect2i()
## The way it blows as drawn in the room: 1 east, -1 west (before the reversal).
var drawn_dir := 1

var _t := 0.0


## The way it blows now: reversed once the storm over Carillon breaks. The
## inner rings has no weather: a trial's winds blow as drawn (pass 160).
func dir() -> int:
	var room := get_parent() as Room
	if room != null and room.zone == "trials":
		return drawn_dir
	return -drawn_dir if GameState.flag(FLAG) else drawn_dir


func pixel_rect() -> Rect2:
	return Rect2(Vector2(cells.position * Room.TILE), Vector2(cells.size * Room.TILE))


func _ready() -> void:
	z_index = -1
	position = Vector2(cells.position * Room.TILE)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead and not p.is_on_floor() and not p.input.down \
			and pixel_rect().has_point(p.body_rect().get_center()):
		p.wind = dir() * p.tuning.wind_speed
	queue_redraw()


## The wash as nested boxes, each [Rect2, alpha]: the alphas add up to WASH in
## the middle and step down to nothing over WASH_FEATHER px at every edge.
static func wash(w: float, h: float) -> Array:
	var out := []
	for s in WASH_STEPS:
		var inset := minf(WASH_FEATHER * s / WASH_STEPS, minf(w, h) * 0.5 - 1.0)
		out.append([Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0), WASH / WASH_STEPS])
	return out


## How many gusts cross a band `w` px long.
static func gust_count(w: float) -> int:
	return int(w / GUST_EVERY) + GUST_SPARE


## The share of GUST_ALPHA the piece `part` of a gust shows (0 its tail,
## GUST_PARTS - 1 its head): it thins out behind, so a gust has a direction.
static func gust_fade(part: int) -> float:
	return pow(float(part + 1) / GUST_PARTS, 1.3)


## Gust `i` of a band `w` by `h` px at `t` seconds, blowing `d` (1 east, -1
## west): its pieces from tail to head, each [Rect2, alpha], cut to the band.
## Empty while the gust is off either end.
static func gust(i: int, w: float, h: float, t: float, d: float) -> Array:
	var y := fmod(i * 37.0, maxf(h - 8.0, 1.0)) + 4.0
	var length := 26.0 + (i % 3) * 14.0
	var head := fmod(t * GUST_SPEED + i * 71.0, w + length)
	var piece := length / GUST_PARTS
	var out := []
	for part in GUST_PARTS:
		# From the head back: piece GUST_PARTS - 1 ends at the head.
		var x1 := head - piece * (GUST_PARTS - 1 - part)
		var x0 := x1 - piece
		var bow := roundf(sin(float(part) / (GUST_PARTS - 1) * PI + i) * GUST_BOW * 0.5)
		if d < 0.0:
			var m := x0
			x0 = w - x1
			x1 = w - m
		x0 = clampf(roundf(x0), 0.0, w)
		x1 = clampf(roundf(x1), 0.0, w)
		if x1 - x0 < 1.0:
			continue
		out.append([Rect2(x0, y + bow, x1 - x0, 1.0), GUST_ALPHA * gust_fade(part)])
	return out


func _draw() -> void:
	var w := float(cells.size.x * Room.TILE)
	var h := float(cells.size.y * Room.TILE)
	var d := float(dir())
	# A faint wash over the band, fading at its edges.
	for box: Array in wash(w, h):
		draw_rect(box[0], Color(STREAK, box[1]))
	# Gusts racing along the band, each thinning out behind its head.
	for i in gust_count(w):
		for piece: Array in gust(i, w, h, _t, d):
			draw_rect(piece[0], Color(STREAK, piece[1]))
	# A few leaves tumbling along with it.
	var room := get_parent() as Room
	var leaf := FLECK if room != null and room.zone == "trials" else LEAF
	for i in 6:
		var x := fmod(_t * 200.0 + i * w / 6.0, w)
		if d < 0.0:
			x = w - x
		var y := h * (0.15 + 0.14 * i) + sin(_t * 3.0 + i) * 4.0
		var spin := _t * 8.0 + i
		var r := Vector2(cos(spin), sin(spin)) * 3.0
		draw_line(Vector2(x, y) - r, Vector2(x, y) + r, Color(leaf.darkened(0.5), 0.8), 3.0)
		draw_line(Vector2(x, y) - r, Vector2(x, y) + r, leaf, 1.5)
