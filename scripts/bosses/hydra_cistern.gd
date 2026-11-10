class_name HydraCistern
extends Node2D
## The great cistern in the middle of the Haar Spring (design bible 8.4). It fills
## a third at a time, one third through each of its three intakes, and Deluge is
## the only water there is. Standing in it with a third or more shelters you from
## the hydra's thermal fog; full, it douses the head that breathed last. The fog
## boils a third of it away, and the hydra's rage boils it dry.

signal filled(level: int)

const THIRDS := 3
## How long the water takes to rise or fall a third, and to boil dry.
const RISE_TIME := 0.6
const BOIL_TIME := 1.6
const WATER := Color("3f7fb8")
const WATER_DEEP := Color("27527a")
const WATER_TOP := Color("cfe6f4")
const STEAM := Color("f4f7f6")

## The cistern's inside in world pixels (between its walls, rim to floor).
var inside := Rect2(368, 272, 224, 48)
var intakes: Array[HydraIntake] = []
## Thirds of water in it, 0 to 3.
var level := 0
## The water as drawn, easing toward `level`.
var shown := 0.0
var boiling := false
var _boil := 0.0
## The intakes that are running, in the order they began.
var _running: Array[HydraIntake] = []


var _back: Node2D


func _ready() -> void:
	z_index = 2
	add_to_group("hydra_cistern")
	# The tank's inner wall and floor, behind whoever stands in it.
	_back = Node2D.new()
	_back.z_index = -1
	_back.z_as_relative = false
	_back.draw.connect(_draw_back)
	add_child(_back)


func add_intake(i: HydraIntake) -> void:
	i.cistern = self
	intakes.append(i)


## Full from the start (once the hydra is beaten, for good).
func fill_now() -> void:
	for i in intakes:
		i.flowing = true
		_running.append(i)
	level = mini(intakes.size(), THIRDS)
	shown = level


func full() -> bool:
	return level >= THIRDS


## Takes water unless the hydra is boiling it away.
func accepts() -> bool:
	return not boiling and level < THIRDS


func fill_from(intake: HydraIntake) -> void:
	_running.append(intake)
	level = mini(level + 1, THIRDS)
	Sfx.play("splash", 0.1, 0.0)
	Sfx.play("flood", 0.1, -8.0 if level < THIRDS else 0.0)
	filled.emit(level)


## The fog's heat boils a third away; its intake runs dry and opens again.
func lose_third() -> void:
	if level <= 0 or _running.is_empty():
		return
	var i: HydraIntake = _running.pop_back()
	i.reset()
	level -= 1
	Sfx.play("steam_hiss", 0.1, -4.0)


## The hydra rages and boils the cistern dry; every intake opens again.
func boil() -> void:
	boiling = true
	_boil = 0.0
	Sfx.play("steam_hiss", 0.0, 2.0)


## The surface's world y for `thirds` of water.
func surface_at(thirds: float) -> float:
	return inside.end.y - inside.size.y * thirds / THIRDS


func surface_y() -> float:
	return surface_at(shown)


## True if the player stands in the water (a third or more, feet inside).
func shelters(p: Player) -> bool:
	if p == null or level < 1 or boiling:
		return false
	var feet := p.global_position
	return feet.x > inside.position.x and feet.x < inside.end.x and feet.y > inside.position.y + 2.0


func _physics_process(delta: float) -> void:
	if boiling:
		_boil += delta
		level = 0
		if _boil >= BOIL_TIME:
			boiling = false
			for i in intakes:
				i.reset()
			_running.clear()
	shown = move_toward(shown, level, delta * (THIRDS / BOIL_TIME if boiling else 1.0 / RISE_TIME))
	queue_redraw()
	_back.queue_redraw()


const STONE := Color("3a3833")
const STONE_LIGHT := Color("5a554c")
const STONE_DARK := Color("24221f")
const STAIN := Color("6f8a7a")


func _draw_back() -> void:
	var r := inside
	_back.draw_rect(r, STONE_DARK)
	# Courses of dressed stone, offset in a running bond.
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var off := 8.0 if row % 2 == 1 else 0.0
		var x := r.position.x - off
		while x < r.end.x:
			var bx := maxf(x, r.position.x)
			var bw := minf(x + 16.0, r.end.x) - bx
			if bw > 1.0:
				_back.draw_rect(Rect2(bx + 1.0, y + 1.0, bw - 2.0, 6.0), STONE)
				_back.draw_rect(Rect2(bx + 1.0, y + 1.0, bw - 2.0, 1.0), STONE_LIGHT)
			x += 16.0
		y += 8.0
		row += 1
	# Water lines where each third once stood.
	for i in range(1, THIRDS + 1):
		var sy := surface_at(i)
		_back.draw_rect(Rect2(r.position.x, sy, r.size.x, 1.0), Color(STAIN, 0.7))
	# The rim's dressed coping, on both walls.
	_back.draw_rect(Rect2(r.position.x - 18.0, r.position.y - 3.0, 18.0, 3.0), STONE_LIGHT)
	_back.draw_rect(Rect2(r.end.x, r.position.y - 3.0, 18.0, 3.0), STONE_LIGHT)


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	if shown > 0.01:
		var top := surface_y()
		var r := Rect2(inside.position.x, top, inside.size.x, inside.end.y - top)
		draw_rect(r, Color(WATER, 0.55))
		draw_rect(Rect2(r.position.x, r.position.y + 6.0, r.size.x, maxf(r.size.y - 6.0, 0.0)), Color(WATER_DEEP, 0.3))
		var x := inside.position.x
		while x < inside.end.x:
			var w := minf(12.0, inside.end.x - x)
			var y := top + roundf(sin(t * 3.0 + x * 0.09))
			draw_rect(Rect2(x, y, w, 1), Color(WATER_TOP, 0.85))
			x += 12.0
	if boiling:
		# A rolling boil: bubbles and steam pouring off the surface.
		var k := clampf(_boil / BOIL_TIME, 0.0, 1.0)
		for i in 14:
			var ph := fmod(t * 1.4 + i * 0.137, 1.0)
			var bx := inside.position.x + 8.0 + fmod(i * 37.0, inside.size.x - 16.0)
			var by := surface_y() - ph * 70.0
			draw_circle(Vector2(bx + sin(t * 3.0 + i) * 4.0, by), 3.0 + ph * 7.0, Color(STEAM, (1.0 - ph) * 0.55 * (1.0 - k * 0.5)))
