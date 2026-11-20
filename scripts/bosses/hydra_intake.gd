class_name HydraIntake
extends StaticBody2D
## One of the Haar Spring cistern's three intake pipes (design bible 8.4). Its
## mouth opens to one side, high or low on the arena's walls, and a Deluge bolt
## flying into it (group "water_target") sends a third of a cistern down the
## pipe. A bolt that strikes the pipe from behind only splashes. Each intake
## runs once until the water it gave is boiled away.

## Which way the mouth opens: -1 west, 1 east. A bolt must fly against it.
var facing := 1
var cistern: HydraCistern
## Running: its third of the water is in the cistern.
var flowing := false
## Counts down the gush drawn as it runs.
var gush := 0.0

const SIZE := 16.0
const PIPE := Color("5b4a3a")
const PIPE_LIGHT := Color("8a6f52")
const PIPE_DARK := Color("2e241c")
const RIM := Color("b08a5a")
const WATER := Color("4aa3df")
const WATER_LIGHT := Color("bfe8ff")


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


func _process(delta: float) -> void:
	gush -= delta
	queue_redraw()


func _draw() -> void:
	# The pipe's flared mouth, opening `facing`, the pipe running back behind it
	# to the cistern's nearer end and down to its lip, where a spout turns in over the pit.
	var f := float(facing)
	if cistern != null:
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
		if flowing:
			# Water falling from the spout into the pit, down to the water that is there.
			var t := Time.get_ticks_msec() * 0.001
			var from := Vector2(spout_x + into * 3.0, rim_y - 6.0)
			var to := cistern.surface_y() - global_position.y
			draw_rect(Rect2(from.x - 1.0, from.y, 3, maxf(to - from.y, 0.0)), Color(WATER, 0.8))
			draw_rect(Rect2(from.x, from.y, 1, maxf(to - from.y, 0.0)), Color(WATER_LIGHT, 0.9))
			var fall := from.y + fmod(t * 60.0, 6.0)
			while fall < to - 2.0:
				draw_rect(Rect2(from.x - 1.0, fall, 1, 2), Color(WATER_LIGHT, 0.7))
				fall += 6.0
			draw_rect(Rect2(from.x - 4.0, to - 1.0, 9, 2), Color(WATER_LIGHT, 0.6 + 0.3 * sin(t * 14.0)))
	draw_rect(Rect2(-8, -7, 16, 14), PIPE_DARK)
	draw_rect(Rect2(-8, -6, 16, 12), PIPE)
	draw_rect(Rect2(-8, -6, 16, 3), PIPE_LIGHT)
	# The flange at the mouth, and its dark throat.
	var mx := 6.0 * f
	draw_rect(Rect2(mx - 2, -9, 4, 18), RIM)
	draw_rect(Rect2(mx - 1 + f, -6, 2, 12), Color.BLACK if not flowing else Color("1d3a52"))
	if not flowing:
		# A faint beckoning drip of condensation: it wants water.
		var t := Time.get_ticks_msec() * 0.001
		var d := fmod(t * 0.8 + position.x * 0.01, 1.0)
		draw_rect(Rect2(mx - 1, 8 + d * 10.0, 2, 2), Color(WATER_LIGHT, 0.6 * (1.0 - d)))
	if gush > 0.0:
		var g := clampf(gush / 0.8, 0.0, 1.0)
		draw_rect(Rect2(mx - 2 * f - 1, -3, 3, 6), Color(WATER, g))
		draw_rect(Rect2(mx - 2 * f, -2, 1, 4), Color(WATER_LIGHT, g))
