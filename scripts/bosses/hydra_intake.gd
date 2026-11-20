class_name HydraIntake
extends StaticBody2D
## One of the Haar Spring cistern's three intake pipes (design bible 8.4). Its
## mouth opens to one side, high or low on the arena's walls, and a Deluge bolt
## flying into it (group "water_target") sends a third of a cistern down the
## pipe. A bolt that strikes the pipe from behind only splashes. Each intake
## runs once until the water it gave is boiled away.
##
## The mouth is a brass bell under a water mark (Sean, 2026-11-20: "I didn't notice a
## place to shoot deluge into"): the mark pulses while the intake wants water, burns
## steady while it runs, and goes dark while the cistern takes none.

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
const RIM_LIGHT := Color("e6c48a")
const RIM_DARK := Color("6b4f2f")
const PLATE := Color("2b2925")
const MARK_DARK := Color("2b4a66")
## The bell's flare: how far out from the pipe each step begins, and its half height.
const BELL := [[2.0, 8.0], [5.0, 10.0], [8.0, 13.0]]
## The water mark: a drop, row by row (columns of a 5 px wide glyph).
const DROP := [[2], [2], [1, 2, 3], [1, 2, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [1, 2, 3]]
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


## True while a bolt into the mouth would fill a third.
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
	# The mouth: a brass bell flaring out the way it opens, big enough to aim at.
	var now := Time.get_ticks_msec() * 0.001
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
	var plate := Vector2(6.0 * f - 6.0, -34.0)
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
