extends TestSuite
## DeepShade: solid mass falls off into darkness away from the walkable edge
## (design bible 12.38, pass 546).


## A `size` grid that is solid except the open cells in `open` (a Rect2i).
func _mass(size: Vector2i, open: Rect2i) -> Dictionary:
	var solids := {}
	for y in size.y:
		for x in size.x:
			if not open.has_point(Vector2i(x, y)):
				solids[Vector2i(x, y)] = true
	return solids


func test_distance_counts_tiles_to_open_air_8_way() -> void:
	var size := Vector2i(12, 5)
	var solids := _mass(size, Rect2i(0, 0, 2, 5))
	var d := DeepShade.distance_field(solids, size)
	check(d[2 * size.x + 1] == 0, "an open cell is 0")
	check(d[2 * size.x + 2] == 1, "the first solid column is 1")
	check(d[2 * size.x + 6] == 5, "five columns in is 5")
	check(d[0 * size.x + 6] == 5, "a diagonal neighbour counts as one step, so the top row is no deeper")


func test_room_outside_counts_as_solid() -> void:
	var size := Vector2i(10, 3)
	var solids := _mass(size, Rect2i(0, 0, 1, 3))
	var d := DeepShade.distance_field(solids, size)
	check(d[1 * size.x + 9] == 9, "the cell at the room's far edge is measured from the open air, not the frame")
	var all := _mass(size, Rect2i(0, 0, 0, 0))
	var none := DeepShade.distance_field(all, size)
	check(DeepShade.darkness_for(none[0]) == 1.0, "a room with no open air is all dark")


func test_the_lit_edge_and_the_step_in_are_untouched() -> void:
	check(DeepShade.darkness_for(1) == 0.0, "the edge tile is not darkened")
	check(DeepShade.darkness_for(2) == 0.0, "the step-in tile is not darkened")
	check(DeepShade.darkness_for(3) > 0.0, "the interior tile begins to fall off")


func test_darkness_deepens_with_distance_to_full() -> void:
	var last := -1.0
	for d in range(0, 12):
		var v := DeepShade.darkness_for(d)
		check(v >= last, "darkness never lightens deeper in (d %d)" % d)
		last = v
	check(DeepShade.darkness_for(7) == 1.0, "full darkness by START + SPAN")
	check(DeepShade.alpha_for(DeepShade.LEVELS) < 1.0, "a trace of the rock still shows at the back")
	check(DeepShade.alpha_for(DeepShade.LEVELS) > 0.75, "the back is close to black")


func test_falloff_is_dithered_steps_not_a_hard_ring() -> void:
	var size := Vector2i(16, 4)
	var solids := _mass(size, Rect2i(0, 0, 1, 4))
	var shade := DeepShade.new()
	arena.add_child(shade)
	shade.setup(solids, size)
	var y := 2 * DeepShade.TILE + 1
	var levels := []
	var mixed := false
	for x in range(0, size.x * DeepShade.TILE, DeepShade.GRAIN):
		var here := shade.level_at_pixel(Vector2(x + 0.5, y + 0.5))
		var below := shade.level_at_pixel(Vector2(x + 0.5, y + DeepShade.GRAIN + 0.5))
		check(here >= 0 and here <= DeepShade.LEVELS, "every pixel is a quantised step")
		if here != below:
			mixed = true
		if not here in levels:
			levels.append(here)
	check(levels.size() == DeepShade.LEVELS + 1, "every step from bare to full appears along the falloff (%s)" % [levels])
	check(mixed, "neighbouring blocks in a column differ inside the falloff (an ordered dither)")
	check(shade.level_at_pixel(Vector2(1.5 * DeepShade.TILE, y)) == 0, "the edge tile is bare")
	check(shade.level_at_pixel(Vector2(14.5 * DeepShade.TILE, y)) == DeepShade.LEVELS, "deep in it is full")


func test_deep_cells_are_one_rect_each() -> void:
	var size := Vector2i(20, 20)
	var solids := _mass(size, Rect2i(0, 0, 0, 0))
	var shade := DeepShade.new()
	arena.add_child(shade)
	shade.setup(solids, size)
	check(shade.rect_count() == size.x * size.y, "a uniformly deep cell is one rect, not 64 blocks (%d rects)" % shade.rect_count())


func test_skip_and_only_split_the_cells() -> void:
	var size := Vector2i(12, 3)
	var solids := _mass(size, Rect2i(0, 0, 1, 3))
	var secret := {Vector2i(10, 1): true}
	var main := DeepShade.new()
	arena.add_child(main)
	main.setup(solids, size, {}, secret)
	var hidden := DeepShade.new()
	arena.add_child(hidden)
	hidden.setup(solids, size, secret)
	var inside := Vector2(10.5, 1.5) * DeepShade.TILE
	var beside := Vector2(9.5, 1.5) * DeepShade.TILE
	check(main.level_at_pixel(inside) == 0, "the main shade leaves secret cells out")
	check(hidden.level_at_pixel(inside) > 0, "the secret shade draws them")
	check(main.level_at_pixel(beside) > 0, "the main shade draws the rest")
	check(hidden.level_at_pixel(beside) == 0, "the secret shade draws nothing else")


func test_a_room_sinks_its_deep_mass_and_the_secret_layer_fades_its_own() -> void:
	var text := "zone: evercrown\nsecret: 12, 2, 13, 3\n---\n"
	var rows: Array[String] = []
	for y in 14:
		rows.append("#".repeat(16))
	rows[2] = "#......#####..##"
	rows[3] = "1......#####..##"
	rows[4] = "################"
	var room := Room.from_text(text + "\n".join(rows))
	arena.add_child(room)
	var shade := room.get_node("DeepShade") as DeepShade
	check(shade != null, "the room has a deep shade")
	check(shade.level_at_pixel(Vector2(3.5, 12.5) * Room.TILE) == DeepShade.LEVELS, "mass far below the floor is dark")
	check(shade.level_at_pixel(Vector2(3.5, 4.5) * Room.TILE) == 0, "the floor's lit edge is bare")
	check(shade.level_at_pixel(Vector2(12.5, 2.5) * Room.TILE) == 0, "the hidden room under its cover is not darkened by the main shade")
	check(room.secrets != null and room.secrets.get_node_or_null("DeepShade") != null, "the secret layer carries its own shade, so it fades with the cover")
