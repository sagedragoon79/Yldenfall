class_name HydraFog
extends Node2D
## The Haar Wyrm's silent whisper (design bible 8.4): after a long wind-up one head
## breathes out a wave of superheated, nearly invisible vapour that fills the
## whole arena. The air itself shimmers and burns. There is one shelter: stand in
## the cistern's water (a third or more), which the heat cannot reach. The heat
## boils a third of that water away as it passes.

const FILL := 0.6
const BURN := 2.4
const FADE := 1.0
const TICK := 0.4
const DAMAGE := 6
const HAZE := Color("fff1dc")
const HAZE_HOT := Color("ffd9a0")
const SHIMMER := Color("ffffff")

## The arena it fills (world px) and the cistern that shelters.
var bounds := Rect2(16, 64, 928, 256)
var cistern: HydraCistern

var _time := 0.0
var _tick := 0.0
var _boiled := false


func _ready() -> void:
	z_index = 4
	add_to_group("hydra_fog")


## 0 clear .. 1 thick.
func thickness() -> float:
	if _time < FILL:
		return _time / FILL
	if _time < FILL + BURN:
		return 1.0
	return clampf(1.0 - (_time - FILL - BURN) / FADE, 0.0, 1.0)


## True while the fog burns whoever it reaches.
func burning() -> bool:
	return _time >= FILL * 0.5 and _time < FILL + BURN


func _physics_process(delta: float) -> void:
	if TimeStop.active():
		return  # held still by the Stillstone
	_time += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if burning() and p != null and not p.dead:
		var safe := cistern != null and cistern.shelters(p)
		_tick -= delta
		if _tick <= 0.0 and not safe:
			_tick = TICK
			p.take_damage(DAMAGE)
			Sfx.play("steam_hiss", 0.15, -10.0)
	if not _boiled and _time >= FILL + BURN:
		_boiled = true
		if cistern != null:
			cistern.lose_third()
	if _time >= FILL + BURN + FADE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := thickness()
	if k <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	# A thin warm veil over everything, except the water, which stays clear.
	var clear := Rect2()
	if cistern != null and cistern.level > 0:
		var top := cistern.surface_y()
		clear = Rect2(cistern.inside.position.x, top, cistern.inside.size.x, cistern.inside.end.y - top)
	var band := 8.0
	var y := bounds.position.y
	while y < bounds.end.y:
		var wob := sin(t * 2.0 + y * 0.05) * 0.04
		var heat := clampf((bounds.end.y - y) / bounds.size.y, 0.0, 1.0) * 0.5
		var col := Color(HAZE.lerp(HAZE_HOT, heat), (0.3 + wob) * k)
		var r := Rect2(bounds.position.x, y, bounds.size.x, band)
		if clear.size.x > 0.0 and r.intersects(clear):
			draw_rect(Rect2(r.position.x, y, clear.position.x - r.position.x, band), col)
			draw_rect(Rect2(clear.end.x, y, r.end.x - clear.end.x, band), col)
		else:
			draw_rect(r, col)
		y += band
	# Heat shimmer: faint wavering lines rising through the air, with a few
	# bright threads tracing the current.
	for i in 22:
		var ph := fmod(t * 0.35 + i * 0.0457, 1.0)
		var lx := bounds.position.x + fmod(i * 97.0, bounds.size.x)
		var ly := bounds.end.y - ph * bounds.size.y
		var pts := PackedVector2Array()
		for j in 6:
			pts.append(Vector2(lx + j * 6.0, ly + sin(t * 5.0 + j + i) * 2.0))
		draw_polyline(pts, Color(SHIMMER, 0.4 * k * (1.0 - ph)), 1.0)
		if i % 5 == 0:
			draw_rect(Rect2(lx + 12.0, ly, 2, 1), Color(HAZE_HOT, 0.6 * k))
