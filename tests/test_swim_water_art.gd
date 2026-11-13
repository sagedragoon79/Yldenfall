extends TestSuite
## SwimWater's look: a dithered body that darkens with depth behind the actors,
## a light tint in front, and caustics that fade with depth (design bible 12.39,
## pass 548).


func _mean_level(depth: int) -> float:
	var sum := 0
	for x in 4 * SwimWater.GRAIN:
		sum += SwimWater.depth_level(x, depth)
	return float(sum) / float(4 * SwimWater.GRAIN)


func test_water_body_darkens_with_depth_in_dithered_steps() -> void:
	var top := true
	for x in 8:
		top = top and SwimWater.depth_level(x, 0) == 0
	check(top, "just under the surface the body is the shallowest step")
	var full := true
	for x in 8:
		full = full and SwimWater.depth_level(x, int(SwimWater.DEPTH_FULL)) == SwimWater.LEVELS - 1
	check(full, "at full depth it is the deepest step")
	var prev := -1.0
	var rising := true
	for d in range(0, int(SwimWater.DEPTH_FULL) + 1, 8):
		var m := _mean_level(d)
		rising = rising and m >= prev
		prev = m
	check(rising, "the body never lightens as it deepens")
	# Between two steps neighbouring dither blocks take different levels, and no
	# two neighbours are more than one step apart (an ordered dither, not noise).
	var mixed := 0
	var jumps := 0
	for d in range(4, int(SwimWater.DEPTH_FULL), 2):
		for x in range(0, 6, SwimWater.GRAIN):
			var a := SwimWater.depth_level(x, d)
			var b := SwimWater.depth_level(x + SwimWater.GRAIN, d)
			if a != b:
				mixed += 1
			if absi(a - b) > 1:
				jumps += 1
	check(mixed > 20, "the steps are dithered (%d mixed neighbours)" % mixed)
	check(jumps == 0, "neighbouring blocks differ by one step at most (%d jumps)" % jumps)
	var tex := SwimWater.depth_strip()
	check(tex.get_width() == 4 * SwimWater.GRAIN and tex.get_height() == SwimWater.STRIP_H, "the strip is one dither period wide")


func test_water_light_falls_off_fastest_under_the_surface() -> void:
	var quarter := _mean_level(int(SwimWater.DEPTH_FULL / 4.0))
	check(quarter >= (SwimWater.LEVELS - 1) * 0.4,
		"a quarter of the way down the body is already %.2f steps dark" % quarter)
	var a0 := SwimWater.level_color(0)
	var a1 := SwimWater.level_color(SwimWater.LEVELS - 1)
	check(a1.a > a0.a + 0.4 and a1.v < a0.v, "the deepest step is darker and denser than the shallowest")


func test_water_caustics_fade_with_depth() -> void:
	check(is_equal_approx(SwimWater.caustic_alpha(0.0), SwimWater.CAUSTIC_ALPHA), "brightest at the surface")
	check(SwimWater.caustic_alpha(SwimWater.CAUSTIC_DEPTH * 0.5) < SwimWater.CAUSTIC_ALPHA, "dimmer below it")
	check(SwimWater.caustic_alpha(SwimWater.CAUSTIC_DEPTH) == 0.0, "gone by CAUSTIC_DEPTH")


func test_water_pool_draws_its_body_behind_the_actors() -> void:
	var rows := [
		"##############",
		"#............#",
		"#.....##.....#",
		"#aaaaa##aaaaa#",
		"#aaaaa##aaaaa#",
		"#aaaaaaaaaaaa#",
		"#aaaaaaaaaaaa#",
		"##############",
	]
	var room := make_room(rows)
	var water: SwimWater = null
	for c in room.get_children():
		if c is SwimWater:
			water = c
	check(water != null, "the room has its water")
	var body := water.get_node_or_null("Body") as Node2D
	check(body != null, "the water has a body layer")
	if body == null:
		return
	check(body.z_as_relative and water.z_index + body.z_index < 0, "the body draws under the actors")
	check(water.z_index > 0, "the tint, caustics and surface draw in front of them")
	check(SwimWater.FRONT_ALPHA <= 0.25, "the front tint is light, so a swimmer reads")
	# The row under the pillar is as deep as the rows beside it: depth counts
	# from the pool's top, not from the rock overhead.
	var by_row := {}
	for i in water._runs.size():
		by_row[int(water._runs[i].position.y / Room.TILE)] = water._run_depth[i]
	check(is_equal_approx(by_row[5], 2.0 * Room.TILE), "the row under the pillar is two tiles deep (%s)" % by_row[5])
	check(is_equal_approx(by_row[3], 0.0), "the top row is at the surface")
