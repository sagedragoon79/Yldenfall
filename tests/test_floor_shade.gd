extends TestSuite
## FloorShade: a floor sinks into the ground under it (design bible 12.157,
## pass 680). The pass 675 grade named "uniform floor strips" in the Tower foot,
## the veins and the Source Hall: the ground between the walking line and the
## frame stood at the walking tile's value all the way down.

const ROOMS := ["tower/foot", "evercrown/veins", "sunken/source_hall"]


## A `size` grid of open air with the solid cells listed per column as
## [x, top row] (solid from the top row to the bottom), and whole columns in `walls`.
func _ground(size: Vector2i, floors: Array, walls: Array) -> Dictionary:
	var solids := {}
	for f: Array in floors:
		for y in range(int(f[1]), size.y):
			solids[Vector2i(int(f[0]), y)] = true
	for x: int in walls:
		for y in size.y:
			solids[Vector2i(x, y)] = true
	return solids


func test_only_the_foot_of_a_column_is_a_floor() -> void:
	var size := Vector2i(7, 8)
	# Column 0 a wall from top to bottom, 1 and 2 a floor from row 5, 3 a floor
	# from row 3 (a bank), 4 a pit, 5 a floor one tile deep, 6 a floor with a secret.
	var solids := _ground(size, [[1, 5], [2, 5], [3, 3], [5, 7], [6, 5]], [0])
	var tops := FloorShade.floor_tops(solids, size, {Vector2i(6, 6): true})
	check(tops[0] == -1, "a wall from the room's top to its bottom is not a floor")
	check(tops[1] == 5 and tops[2] == 5, "a floor's top is the top of its run from the bottom row")
	check(tops[3] == 3, "a bank's top is its own")
	check(tops[4] == -1, "a pit is not a floor")
	check(tops[5] == -1, "ground one tile deep is not shaded")
	check(tops[6] == -1, "a column holding a secret is not shaded")
	# Solid over open air over the floor: only the run from the bottom counts.
	solids[Vector2i(1, 1)] = true
	check(FloorShade.floor_tops(solids, size)[1] == 5, "mass hanging over the floor does not join it")


func test_the_walking_tile_stays_lit_and_the_ground_falls_into_shade() -> void:
	check(FloorShade.alpha_at_depth(0.0) == 0.0, "the floor's top is not shaded")
	check(FloorShade.alpha_at_depth(FloorShade.FROM) == 0.0, "nor its lip")
	var last := 0.0
	for i in range(1, 30):
		var a := FloorShade.alpha_at_depth(i * 0.2)
		check(a >= last, "the shade never lightens deeper in (%.1f tiles)" % [i * 0.2])
		last = a
	check(FloorShade.alpha_at_depth(2.0) >= 0.35, "two tiles down the floor is well into shade (%.2f)" % FloorShade.alpha_at_depth(2.0))
	check(is_equal_approx(FloorShade.alpha_at_depth(FloorShade.FROM + FloorShade.SPAN), FloorShade.MAX_ALPHA), "the full shade by FROM + SPAN")
	check(FloorShade.MAX_ALPHA < 0.8, "the ground still shows through the full shade")


func test_the_shade_meets_itself_across_a_bank() -> void:
	var size := Vector2i(6, 10)
	var solids := _ground(size, [[0, 6], [1, 6], [2, 4], [3, 4], [4, 6], [5, 6]], [])
	var shade := FloorShade.new()
	arena.add_child(shade)
	shade.setup(solids, size)
	var t := float(FloorShade.TILE)
	for y in range(6 * FloorShade.TILE, size.y * FloorShade.TILE, 3):
		var west := shade.alpha_at_pixel(Vector2(2 * t - 0.01, y + 0.5))
		var east := shade.alpha_at_pixel(Vector2(2 * t + 0.01, y + 0.5))
		check(absf(west - east) < 0.02, "no seam at the bank's edge (row px %d: %.2f, %.2f)" % [y, west, east])
	# No walking tile is shaded, the bank's included.
	for x in size.x:
		var top := shade.tops[x]
		for u in [0.05, 0.5, 0.95]:
			var a := shade.alpha_at_pixel(Vector2((x + u) * t, (top + FloorShade.FROM * 0.9) * t))
			check(a == 0.0, "the walking tile of column %d stays lit (%.2f)" % [x, a])
	check(shade.alpha_at_pixel(Vector2(0.5 * t, size.y * t - 1.0)) > 0.5, "the floor is dark at the room's foot")


func test_the_named_floors_fall_into_shade() -> void:
	for id: String in ROOMS:
		var world := make_world({}, id)
		await frames(1)
		var shade := world.room.get_node_or_null("FloorShade") as FloorShade
		if not check(shade != null, "%s has a floor shade" % id):
			world.queue_free()
			continue
		var t := float(FloorShade.TILE)
		var floors := 0
		var dark := 0
		var stretch := 0
		for x in shade.tops.size():
			var top := shade.tops[x]
			if top < 0:
				continue
			floors += 1
			var lip := shade.alpha_at_pixel(Vector2((x + 0.5) * t, (top + 0.25) * t))
			check(lip == 0.0, "%s column %d keeps its lip lit" % [id, x])
			# On a flat stretch (beside a step down the shade eases to meet the lower floor).
			var flat := x > 0 and x < shade.tops.size() - 1 and shade.tops[x - 1] == top and shade.tops[x + 1] == top
			if not flat or world.room.size_tiles.y - top < 3:
				continue
			stretch += 1
			if shade.combined_alpha_at_pixel(Vector2((x + 0.5) * t, (top + 2.5) * t)) >= 0.5:
				dark += 1
		check(floors >= world.room.size_tiles.x / 2, "%s: most columns stand on a floor (%d of %d)" % [id, floors, world.room.size_tiles.x])
		check(stretch > 0 and dark == stretch, "%s: every flat floor is in shade two and a half tiles down (%d of %d)" % [id, dark, stretch])
		world.queue_free()
		await frames(1)


## Pass 681: the pass 680 grade read a heavy dark ellipse under the Source
## Hall's floor, the floor shade laid on the deep shade over eight tiles of ground.

func test_the_floor_shade_only_adds_what_the_deep_shade_has_not_given() -> void:
	check(FloorShade.eased(0.7, 0.0) == 0.7, "over open ground the floor shade is its own")
	check(FloorShade.eased(0.7, 0.86) == 0.0, "over a deeper shade it adds nothing")
	check(FloorShade.eased(0.7, 0.7) == 0.0, "nor over one as dark")
	for i in 10:
		var deep := i * 0.069
		var add := FloorShade.eased(0.7, deep)
		var both := 1.0 - (1.0 - add) * (1.0 - deep)
		check(absf(both - 0.7) < 0.001, "together they reach the floor's darkness and no more (deep %.2f: %.3f)" % [deep, both])


func test_the_ground_under_a_floor_sinks_no_darker_than_the_floor_shade() -> void:
	# A floor from row 4 of a 16-row room, ten tiles of ground under it, and a
	# wall from the top to the bottom at column 0.
	var size := Vector2i(14, 16)
	var floors := []
	for x in range(1, size.x):
		floors.append([x, 4])
	var solids := _ground(size, floors, [0])
	var plain := DeepShade.new()
	arena.add_child(plain)
	plain.setup(solids, size)
	var shade := DeepShade.new()
	arena.add_child(shade)
	shade.setup(solids, size, {}, {}, "", 0, true)
	var cap := FloorShade.MAX_ALPHA / DeepShade.MAX_ALPHA
	var deepest := 0.0
	for y in range(4, size.y):
		for x in range(1, size.x):
			deepest = maxf(deepest, shade.field()[y * size.x + x])
	check(plain.field()[(size.y - 1) * size.x + 7] >= 1.0, "without floors the ground's foot is full deep shade")
	check(deepest <= cap + 0.0001, "under a floor the deep shade stops at the floor shade's full (%.2f, cap %.2f)" % [deepest, cap])
	check(deepest >= cap - 0.0001, "and still reaches it, deep in")
	# The rock over open air elsewhere is untouched: a hanging mass sinks to full.
	var hang := _ground(Vector2i(14, 16), [], [])
	for y in range(0, 9):
		for x in 14:
			hang[Vector2i(x, y)] = true
	var hung := DeepShade.new()
	arena.add_child(hung)
	hung.setup(hang, Vector2i(14, 16), {}, {}, "", 0, true)
	check(hung.field()[1 * 14 + 7] >= 1.0, "mass hanging over the room still sinks to full")


func test_the_source_hall_has_no_dark_ellipse_under_its_floor() -> void:
	var world := make_world({}, "sunken/source_hall")
	await frames(1)
	var shade := world.room.get_node_or_null("FloorShade") as FloorShade
	if not check(shade != null, "the source hall has a floor shade"):
		world.queue_free()
		return
	var t := float(FloorShade.TILE)
	var size: Vector2i = world.room.size_tiles
	var samples := 0
	var worst := 0.0
	for x in size.x:
		var top := shade.tops[x]
		if top < 0:
			continue
		for y in range(top * FloorShade.TILE, size.y * FloorShade.TILE, 4):
			for u in [0.1, 0.5, 0.9]:
				var px := Vector2((x + u) * t, y + 0.5)
				var both := shade.combined_alpha_at_pixel(px)
				worst = maxf(worst, both)
				samples += 1
				check(both <= maxf(shade.want_at_pixel(px), shade.deep_alpha_at_pixel(px)) + 0.002,
						"the two shades never stack (%.1f, %.1f)" % [px.x, px.y])
	check(samples > 500, "the hall's floors were sampled (%d)" % samples)
	check(worst <= FloorShade.MAX_ALPHA + 0.002, "the ground under the floor is never darker than the floor shade's full (%.2f)" % worst)
	check(worst >= FloorShade.MAX_ALPHA - 0.002, "and reaches it deep down (%.2f)" % worst)
	world.queue_free()
	await frames(1)
