extends TestSuite
## Pass 550: what wades in Vorrhallow's standing water breaks its surface (design
## bible 4.4). A waterline crosses the body, ripples spread from it (more often
## while it moves), and the water darkens toward the floor in dithered steps.


func _hall(at := Vector2i(10, 19)) -> World:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(at.x, at.y))
	for c in w.room.get_children():
		if c is Enemy:
			c.queue_free()
	return w


func test_ripples_spread_and_fade() -> void:
	var prev := -1.0
	var spreading := true
	var fading := true
	var prev_a := 2.0
	for i in 11:
		var age := Tide.RING_LIFE * float(i) / 10.0
		var r := Tide.ring_reach(8.0, age)
		var a := Tide.ring_alpha(age)
		spreading = spreading and r > prev
		fading = fading and a < prev_a
		prev = r
		prev_a = a
	check(spreading, "a ripple only spreads outward")
	check(fading, "and only fades")
	check(Tide.ring_reach(8.0, 0.0) > 8.0, "it starts just past the body's edge")
	check(Tide.ring_alpha(Tide.RING_LIFE) == 0.0, "and is gone at the end of its life")
	check(Tide.wades(Rect2(0, 10, 10, 40), 30.0), "a box across the surface wades")
	check(not Tide.wades(Rect2(0, -40, 10, 40), 30.0), "one above it does not")
	check(not Tide.wades(Rect2(0, 31, 10, 40), 30.0), "nor one under it")


func test_water_lightens_under_the_surface_and_darkens_to_the_floor() -> void:
	var top := Tide.level_color(Tide.depth_level(0, 0))
	var bottom := Tide.level_color(Tide.depth_level(0, Room.TILE - 1))
	check(Tide.depth_level(0, 0) == 0 and Tide.depth_level(0, Room.TILE - 1) == Tide.LEVELS - 1, "shallowest at the surface, deepest at the floor")
	check(bottom.v < top.v and bottom.a > top.a, "the floor end is darker and denser")
	var mixed := 0
	var jumps := 0
	for d in range(2, Room.TILE - 2):
		for x in range(0, 4, Tide.GRAIN):
			var a := Tide.depth_level(x, d)
			var b := Tide.depth_level(x + Tide.GRAIN, d)
			mixed += 1 if a != b else 0
			jumps += 1 if absi(a - b) > 1 else 0
	check(mixed > 4, "the steps are dithered (%d mixed neighbours)" % mixed)
	check(jumps == 0, "neighbouring blocks differ by one step at most")
	var strip := Tide.body_strip()
	check(strip.get_height() == Room.TILE, "the strip is one tile deep")


func test_the_hero_wading_breaks_the_surface() -> void:
	var w := _hall()
	await frames(10)
	var tide: Tide = w.room.tide
	var p := w.player
	check(w.room.surface_at(p.global_position + Vector2(0, 2)) == "wade", "the hero stands in the water")
	var x := tide.to_local(p.global_position).x
	var line := false
	for wake: Array in tide.wakes:
		line = line or absf(float(wake[0]) - x) < 4.0
	check(line, "a waterline crosses the hero (%s)" % [tide.wakes])
	var near := 0
	for ring: Array in tide.rings:
		near += 1 if absf(float(ring[0]) - x) < 4.0 else 0
	check(near >= 1, "and a ripple has left the hero (%d)" % near)
	# Standing, one ripple a WAKE_STILL; running, one a WAKE_MOVING.
	tide.rings.clear()
	await frames(int(Tide.RING_LIFE * 60.0))
	var still := tide.rings.size()
	tide.rings.clear()
	p.input.move_x = 1
	await frames(int(Tide.RING_LIFE * 60.0))
	p.input.move_x = 0
	var moving := tide.rings.size()
	check(moving > still, "running sends ripples out faster than standing (%d against %d)" % [moving, still])


func test_nothing_out_of_the_water_makes_a_wake() -> void:
	var w := _hall()
	await frames(6)
	var tide: Tide = w.room.tide
	w.player.teleport(w.player.global_position - Vector2(0, Room.TILE * 6))
	w.player.velocity = Vector2.ZERO
	await frames(2)
	tide.rings.clear()
	await frames(2)
	check(tide.wakes.is_empty(), "a hero in the air above the water draws no waterline")
	check(tide.rings.is_empty(), "and sends no ripples")


func test_a_foe_wading_breaks_the_surface_too() -> void:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(4, 15))
	await frames(10)
	var tide: Tide = w.room.tide
	var foe: Enemy = null
	for c in w.room.get_children():
		if c is Enemy and tide.has_point((c as Enemy).global_position + Vector2(0, -4)):
			foe = c
	check(foe != null, "a foe stands in the hall's water")
	if foe == null:
		return
	var x := tide.to_local(foe.global_position).x
	var line := false
	for wake: Array in tide.wakes:
		line = line or absf(float(wake[0]) - x) < 8.0
	check(line, "a waterline crosses it")


func test_the_drained_hall_has_no_wake() -> void:
	var w := _hall()
	GameState.set_flag(Tide.DRAIN_FLAG)
	await frames(10)
	var tide: Tide = w.room.tide
	check(tide.wakes.is_empty() and tide.rings.is_empty(), "drained, nothing wades")
	GameState.data.flags.erase(Tide.DRAIN_FLAG)
