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


## The room's light shafts carry on under the surface (design bible 12.141, pass
## 665): bent steeper, narrow where they enter and widening as they sink, in clean
## steps that fade out above the pool's floor, only through an open surface.
func test_the_light_goes_on_under_the_water() -> void:
	# The fall with depth: brightest at the surface, LEVELS clean steps, gone by
	# FADE_DEPTH; and the core is the brightest tier, the edge the faintest.
	check(is_equal_approx(WaterShaft.alpha_at(0.0, 0.0), WaterShaft.PEAK), "the core is full at the surface")
	var seen := {}
	var prev := INF
	var falling := true
	for d in range(0, int(WaterShaft.FADE_DEPTH) + 2, 2):
		var a := WaterShaft.alpha_at(float(d), 0.0)
		falling = falling and a <= prev
		prev = a
		seen[snappedf(a, 0.0001)] = true
	check(falling, "a shaft never brightens as it sinks")
	check(seen.size() == WaterShaft.LEVELS + 1, "it falls in %d clean steps (%d tones)" % [WaterShaft.LEVELS, seen.size()])
	check(WaterShaft.alpha_at(WaterShaft.FADE_DEPTH, 0.0) == 0.0, "and is gone by FADE_DEPTH")
	check(WaterShaft.alpha_at(7.0 * Room.TILE, 0.0) <= WaterShaft.PEAK * 0.5 + 0.0001, "by the floor of a seven-tile pool it is at half or less")
	var h := WaterShaft.half_width(0.0)
	var core := WaterShaft.alpha_at(8.0, 0.0)
	var mid := WaterShaft.alpha_at(8.0, h * 0.5)
	var rim := WaterShaft.alpha_at(8.0, h * 0.9)
	check(core > mid and mid > rim and rim > 0.0, "core, middle and rim step down (%.3f, %.3f, %.3f)" % [core, mid, rim])
	check(WaterShaft.alpha_at(8.0, h * 1.05) == 0.0, "nothing past its edge")
	check(h < LightShaft.HALF, "it enters narrower than the air's shaft")
	check(WaterShaft.half_width(WaterShaft.FADE_DEPTH) > h * 1.5, "and widens as it sinks")
	check(absf(WaterShaft.BEND) < 1.0, "it is bent steeper in the water")
	check(WaterShaft.PEAK > LightShaft.PEAK, "it is brighter than the faint air shaft, so the pool has its light")
	for t in [0.0, 1.0, 2.5, 7.0]:
		check(int(WaterShaft.sway_at(1, t)) % WaterShaft.GRAIN == 0 and absf(WaterShaft.sway_at(1, t)) <= WaterShaft.SWAY * WaterShaft.GRAIN,
			"it sways a whole grain at a time")
	# It enters only through an open surface: three shafts fall on a pool whose
	# east end is under a roof, and one misses the water.
	var shafts := WaterShaft.new()
	for x in range(1, 13):
		for y in range(3, 7):
			shafts.cells[Vector2i(x, y)] = true
	for x in range(9, 13):
		shafts.roofed[Vector2i(x, 3)] = true
	var t := float(Room.TILE)
	shafts.centers = [3.5 * t, 10.5 * t, 20.5 * t]
	shafts.slope = 0.0
	var entries := shafts.find_entries()
	check(entries.size() == 1, "only the shaft over the open surface enters (%d)" % entries.size())
	if entries.size() == 1:
		check(is_equal_approx(float(entries[0][1]), 3.0 * t), "at the surface")
		check(is_equal_approx(float(entries[0][0]), 3.5 * t), "where the air's shaft meets it")
	shafts.free()
	# In the Source Hall the air's shafts carry on into its pool, behind the actors.
	var room := Room.from_file("res://levels/sunken/source_hall.room")
	arena.add_child(room)
	await frames(2)
	var water: SwimWater = null
	for c in room.get_children():
		if c is SwimWater:
			water = c
	var under := water.get_node_or_null("Shafts") as WaterShaft if water != null else null
	check(under != null, "the pool has its shafts")
	if under != null:
		check(under.entries.size() >= 2, "at least two of the hall's shafts enter its pool (%d)" % under.entries.size())
		check(water.z_index + under.z_index < 0, "they draw under the actors")
		check(under.get_index() > water.get_node("Body").get_index(), "and over the body")
		check(is_equal_approx(under.slope, float(LightShaft.SHAFTS["sunken"]["slope"])), "they lean as the zone's air shafts do")
	room.queue_free()
	await frames(1)
