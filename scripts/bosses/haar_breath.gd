class_name SteamBreath
extends Node2D
## The Haar Wyrm's choking plume (design bible 8.4): a thick, heavy cloud of
## scalding grey-white steam that one head vents down onto the floor, where it
## rolls along the ground toward you. It stays under a jump's height, so you jump
## it, stand on a platform, or duck into the cistern below its rim; it rides over
## the cistern's walls. It hurts once and can't be parried.

## What its blow is made of (design bible 5.6).
const DAMAGE_KIND := DamageKind.FIRE
const WIDTH := 56.0
## The tallest it billows: under a single jump's apex (movement_tuning jump_height, 72 px).
const HEIGHT := 56.0
const SPEED := 105.0
const LIFE := 4.8
const DAMAGE := 14
## How the cloud swells as it rolls: a burst at the jaws, broad and heavy after.
const SPREAD_START := 0.5
const SPREAD_END := 1.6
const STEAM := Color("eef2f1")
const STEAM_HOT := Color("fff3e0")
const STEAM_EDGE := Color("aebcc0")
const STEAM_DARK := Color("7d8a8e")
const ASH := Color("5e5650")

var dir := 1.0
## The ground it rolls along (world y), and the arena's sides.
var ground_y := 0.0
var left := 0.0
var right := 0.0
## Optional: the ground's height at a given x (the boss lends its own, so the
## plume rides over the cistern's walls). Without it, `ground_y` everywhere.
var ground_at := Callable()

var _time := 0.0
var _hit := false


func _ready() -> void:
	z_index = 3


## How far through its run the plume is (0 at the jaws, 1 as it fades).
func _k() -> float:
	return clampf(_time / LIFE, 0.0, 1.0)


func spread() -> float:
	return lerpf(SPREAD_START, SPREAD_END, minf(_k() * 2.5, 1.0))


func _ground(x: float) -> float:
	return ground_at.call(x) if ground_at.is_valid() else ground_y


## The hurt rect: as wide as it has billowed, never taller than a jump clears.
func rect() -> Rect2:
	var w := WIDTH * spread()
	var h := HEIGHT * lerpf(0.55, 1.0, minf(_k() * 2.5, 1.0))
	var g := _ground(global_position.x)
	return Rect2(global_position.x - w * 0.5, g - h, w, h)


func _physics_process(delta: float) -> void:
	if TimeStop.active():
		return  # held still by the Stillstone
	_time += delta
	global_position.x += dir * SPEED * delta
	global_position.y = _ground(global_position.x)
	var p := get_tree().get_first_node_in_group("player") as Player
	if not _hit and p != null and not p.dead and rect().intersects(p.body_rect()):
		_hit = true
		p.receive_attack(DAMAGE, self, false)
	if _time >= LIFE or global_position.x < left - WIDTH or global_position.x > right + WIDTH:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _k()
	var rise := clampf(_time / 0.25, 0.0, 1.0)
	var fade := clampf((LIFE - _time) / 0.9, 0.0, 1.0)
	var a := rise * fade
	var s := spread()
	var w := WIDTH * s
	var h := HEIGHT * lerpf(0.55, 1.0, minf(k * 2.5, 1.0))
	# Heavy rolling billows: a dense bank of overlapping cloud, darker and ashy
	# underneath, each billow turning over toward the way it rolls.
	var n := 9
	for row in 2:
		for i in n:
			var q := float(i) / (n - 1)
			var roll := _time * 2.2 * dir + i * 0.9 + row * 1.7
			var x := (q - 0.5) * w * 0.9 + sin(roll) * 3.0
			var r := (h * (0.34 if row == 0 else 0.26)) * (0.75 + 0.25 * sin(q * PI)) + 1.5 * sin(roll * 1.3)
			var y := -r - (0.0 if row == 0 else h * 0.42) - 1.0
			# The leading billows are hottest; the tail cools and lifts.
			var lead := q if dir > 0.0 else 1.0 - q
			draw_circle(Vector2(x, y + 2.0), r + 1.5, Color(STEAM_DARK, 0.55 * a))
			draw_circle(Vector2(x, y), r, Color(STEAM_EDGE, 0.8 * a))
			draw_circle(Vector2(x - 1.5, y - r * 0.25), r * 0.75, Color(STEAM.lerp(STEAM_HOT, lead * 0.6), 0.85 * a))
			draw_circle(Vector2(x - r * 0.3, y - r * 0.45), r * 0.3, Color(Color.WHITE, 0.45 * a))
	# Mineral ash glinting in the cloud, and the scald hugging the ground.
	for i in 6:
		var ph := fmod(_time * 0.7 + i * 0.29, 1.0)
		var ax := (fmod(i * 0.41, 1.0) - 0.5) * w * 0.8
		draw_rect(Rect2(ax, -ph * h, 1.5, 1.5), Color(ASH, (1.0 - ph) * 0.8 * a))
	draw_rect(Rect2(-w * 0.5, -4, w, 4), Color(STEAM, 0.75 * a))
