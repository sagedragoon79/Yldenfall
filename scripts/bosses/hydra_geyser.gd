class_name HydraGeyser
extends Node2D
## The Haar Wyrm's roaring geyser (design bible 8.4): a pressurised jet of boiling
## water and steam forced out of one head's jaws in a straight line. It is not a
## cone: it shoots out from the mouth at one width, holds with pressure surges
## and rolling vortices running down it, and breaks into rising steam where it
## strikes. The line is locked before it fires, so you dodge it by leaving the
## line. It hits once, hard, and throws you back; it can't be parried.

const WIDTH := 18.0
## How fast the jet shoots out, and how long it holds and retracts.
const EXTEND_SPEED := 1100.0
const HOLD := 1.4
const RETRACT := 0.3
const DAMAGE := 18
const CORE := Color("f6fbff")
const WATER := Color("9fd4f2")
const WATER_DEEP := Color("4a8fc4")
const STEAM := Color("e8eef0")
const STEAM_HOT := Color("fff3e0")

## Where it comes from (the head, so it stays on the jaws) and its line.
var head: Node2D
var mouth := Vector2.ZERO
var dir := Vector2.DOWN
## The arena it is cut off by (world px).
var bounds := Rect2(0, 0, 960, 320)

var _time := 0.0
var _hit := false
var _max := 600.0


func _ready() -> void:
	z_index = 4
	dir = dir.normalized()
	_place()
	_max = _reach()


## How far the line runs before it leaves the arena.
func _reach() -> float:
	var best := 2000.0
	for axis in 2:
		var d := dir[axis]
		if absf(d) < 0.0001:
			continue
		var edge := bounds.end[axis] if d > 0.0 else bounds.position[axis]
		var t := (edge - mouth[axis]) / d
		if t > 0.0:
			best = minf(best, t)
	return best


func _place() -> void:
	if is_instance_valid(head) and head.has_method("mouth_point"):
		mouth = head.mouth_point()
	global_position = mouth
	rotation = dir.angle()


## How far out the jet reaches now.
func length() -> float:
	if _time < HOLD:
		return minf(_time * EXTEND_SPEED, _max)
	return _max


## Where the jet begins: once it stops, it lets go of the jaws and runs off.
func _start() -> float:
	if _time < HOLD:
		return 0.0
	return _max * clampf((_time - HOLD) / RETRACT, 0.0, 1.0)


func done() -> bool:
	return _time >= HOLD + RETRACT


## True if the jet's line, as long as it is now, touches `r`.
func touches(r: Rect2) -> bool:
	var a := _start()
	var b := length()
	var d := a
	while d <= b:
		var pt := mouth + dir * d
		if Rect2(pt - Vector2(WIDTH, WIDTH) * 0.5, Vector2(WIDTH, WIDTH)).intersects(r):
			return true
		d += 6.0
	return false


func _physics_process(delta: float) -> void:
	if TimeStop.active():
		return  # held still by the Stillstone
	_time += delta
	_place()
	var p := get_tree().get_first_node_in_group("player") as Player
	if not _hit and p != null and not p.dead and _time < HOLD and touches(p.body_rect()):
		_hit = true
		p.receive_attack(DAMAGE, self, false)
	if done():
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := _start()
	var b := length()
	if b <= a:
		return
	var t := _time
	# Pressure surges: the jet swells a little in pulses as it holds.
	var surge := 1.0 + 0.12 * maxf(0.0, sin(t * 14.0))
	var hw := WIDTH * 0.5 * surge
	# Turbulence held tight around the stream, then the stream, then its core.
	draw_rect(Rect2(a, -hw - 3.0, b - a, hw * 2.0 + 6.0), Color(STEAM, 0.35))
	draw_rect(Rect2(a, -hw, b - a, hw * 2.0), Color(WATER_DEEP, 0.85))
	draw_rect(Rect2(a, -hw + 2.0, b - a, hw * 2.0 - 4.0), Color(WATER, 0.95))
	draw_rect(Rect2(a, -2.0, b - a, 4.0), CORE)
	# Rolling vortices of steam riding down the jet, always moving downstream.
	var spacing := 22.0
	var x := a + fmod(t * EXTEND_SPEED * 0.35, spacing)
	var i := 0
	while x < b:
		var side := 1.0 if i % 2 == 0 else -1.0
		var r := 4.0 + 2.0 * sin(x * 0.07 + t * 9.0)
		draw_circle(Vector2(x, side * (hw - 1.0)), r + 1.0, Color(STEAM, 0.55))
		draw_circle(Vector2(x - 1.0, side * (hw - 2.0)), r * 0.6, Color(Color.WHITE, 0.6))
		x += spacing
		i += 1
	# Heavy droplets thrown off the stream.
	for k in 10:
		var ph := fmod(t * 2.5 + k * 0.173, 1.0)
		var dx := a + fmod(k * 53.0 + t * 400.0, maxf(b - a, 1.0))
		var dy := (hw + 2.0 + ph * 10.0) * (1.0 if k % 2 == 0 else -1.0)
		draw_rect(Rect2(dx, dy, 2, 2), Color(WATER, 1.0 - ph))
	# At the jaws: the emission, a hot white flare.
	if a <= 0.0:
		draw_circle(Vector2(2, 0), hw + 3.0, Color(STEAM_HOT, 0.8))
		draw_circle(Vector2(2, 0), hw * 0.6, Color(CORE, 0.95))
	# Where it strikes: spray and steam breaking up and rising (drawn upright).
	if _time < HOLD and b >= _max - 1.0:
		draw_set_transform(Vector2(b, 0), -rotation)
		for k in 7:
			var ph := fmod(t * 1.8 + k * 0.141, 1.0)
			draw_circle(Vector2(sin(k * 2.3) * 14.0 * ph, -ph * 46.0), 4.0 + ph * 9.0, Color(STEAM, (1.0 - ph) * 0.7))
		for k in 6:
			var ph := fmod(t * 3.0 + k * 0.2, 1.0)
			draw_rect(Rect2(cos(k * 1.1) * 18.0 * ph, -sin(k * 0.7 + 0.5) * 20.0 * ph, 2, 2), Color(WATER, 1.0 - ph))
		draw_set_transform(Vector2.ZERO)
