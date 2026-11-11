extends TestSuite
## ThornBulb (pass 540, bible 12.32): a thorn pod grows from the surface beside
## it, and pods side by side on one surface share a bramble vine, so a column of
## them down a shaft wall reads as a bramble instead of a stack of red orbs.


func _thorny(cells: Array) -> Callable:
	return func(c: Vector2i) -> bool: return cells.has(c)


## Every tone the pod and its vine use is a master palette value.
func test_thorn_tones_are_master_palette() -> void:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	for tone: Color in ThornBulb.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))


## A pod grows from a wall first, then the floor, then the ceiling, and floats
## free with nothing beside it.
func test_thorn_a_pod_picks_its_surface() -> void:
	var at := Vector2i(5, 5)
	check(ThornBulb.anchor_for(at, _thorny([Vector2i(4, 5), Vector2i(5, 6)])) == Vector2i.LEFT, "a wall to the west wins over the floor")
	check(ThornBulb.anchor_for(at, _thorny([Vector2i(6, 5)])) == Vector2i.RIGHT, "a wall to the east")
	check(ThornBulb.anchor_for(at, _thorny([Vector2i(5, 6), Vector2i(5, 4)])) == Vector2i.DOWN, "the floor before the ceiling")
	check(ThornBulb.anchor_for(at, _thorny([Vector2i(5, 4)])) == Vector2i.UP, "the ceiling")
	check(ThornBulb.anchor_for(at, _thorny([])) == Vector2i.ZERO, "nothing beside it: it floats free")


## The bud stays inside its own cell, covers the hitbox's center, tapers out
## to a tip that points away from its surface, and alternate pods along a surface droop opposite ways.
func test_thorn_the_bud_fits_its_cell_and_points_out() -> void:
	for a: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.ZERO]:
		for tilt: float in [0.0, ThornBulb.TILT, -ThornBulb.TILT]:
			var dir := ThornBulb.pod_dir(a, tilt)
			var cells := ThornBulb.pod_cells(dir)
			check(cells.size() > 60, "%s: a full bud (%d px)" % [a, cells.size()])
			check(cells.has(Vector2i(0, 0)) and cells.has(Vector2i(-1, -1)), "%s: it covers the hitbox's center" % a)
			var tip_reach := 0.0
			var stem_reach := 0.0
			for c: Vector2i in cells:
				check(absi(c.x) <= ThornBulb.HALF - 1 and absi(c.y) <= ThornBulb.HALF - 1, "%s: pixel %s stays in the cell" % [a, c])
				var u := (Vector2(c) + Vector2(0.5, 0.5)).dot(dir)
				tip_reach = maxf(tip_reach, u)
				stem_reach = maxf(stem_reach, -u)
			check(tip_reach > stem_reach + 0.5, "%s: the bud reaches farther to its tip (%.1f) than its stem (%.1f)" % [a, tip_reach, stem_reach])
			if a != Vector2i.ZERO:
				check(dir.dot(Vector2(-a)) > 0.85, "%s: it points away from its surface" % a)
	check(ThornBulb.tilt_for(Vector2i(1, 4), Vector2i.LEFT) == -ThornBulb.tilt_for(Vector2i(1, 5), Vector2i.LEFT), "neighbours on a wall droop opposite ways")
	check(ThornBulb.tilt_for(Vector2i(4, 9), Vector2i.DOWN) == -ThornBulb.tilt_for(Vector2i(5, 9), Vector2i.DOWN), "neighbours on a floor lean opposite ways")
	check(ThornBulb.tilt_for(Vector2i(4, 9), Vector2i.ZERO) == 0.0, "a free pod stands straight")


## A room grows each pod from its wall and links a column of them, whose vine
## then runs unbroken from one pod's cell to the next.
func test_thorn_a_room_roots_a_column_in_its_wall() -> void:
	var room := Room.from_text("zone: spires\n---\n########\n#o..o..#\n#o.....#\n#o.....#\n#......#\n#...o..#\n#......#\n#..ooo.#\n########")
	arena.add_child(room)
	var by_cell := {}
	for c in room.get_children():
		if c is ThornBulb:
			by_cell[Vector2i((c.position / Room.TILE).floor())] = c
	check(by_cell.size() == 8, "eight pods: %d" % by_cell.size())
	if by_cell.size() != 8:
		return
	var top: ThornBulb = by_cell[Vector2i(1, 1)]
	var mid: ThornBulb = by_cell[Vector2i(1, 2)]
	check(mid.anchor == Vector2i.LEFT, "the column grows from the west wall")
	check(top.links.size() == 1 and top.links[0] == Vector2i.DOWN, "the top pod links down only: %s" % [top.links])
	check(mid.links.size() == 2, "the middle pod links both ways: %s" % [mid.links])
	check((by_cell[Vector2i(4, 5)] as ThornBulb).anchor == Vector2i.ZERO, "a pod in open air floats free")
	var hang: ThornBulb = by_cell[Vector2i(4, 1)]
	check(hang.anchor == Vector2i.UP, "a pod under the ceiling hangs from it")
	check(hang.links.is_empty(), "with no pod beside it on the ceiling, it links to none: %s" % [hang.links])
	var floor_mid: ThornBulb = by_cell[Vector2i(4, 7)]
	check(floor_mid.anchor == Vector2i.DOWN and floor_mid.links.size() == 2, "a row on the floor links both ways: %s %s" % [floor_mid.anchor, floor_mid.links])
	# The middle pod's vine reaches both cell edges along the wall.
	var ys := {}
	for px: Array in mid.vine_pixels():
		var p: Vector2i = px[0]
		if p.x <= -ThornBulb.HALF + 3:
			ys[p.y] = true
	for y in range(-ThornBulb.HALF, ThornBulb.HALF + 1):
		check(ys.has(y), "the vine is unbroken along the wall at y %d" % y)
	# A lone pod's vine is only a short root clutch.
	var lone_ys := {}
	for px: Array in hang.vine_pixels():
		var p: Vector2i = px[0]
		if true:
			lone_ys[p.x] = true
	check(not lone_ys.has(-ThornBulb.HALF) and not lone_ys.has(ThornBulb.HALF), "an unlinked vine stops short of the cell's edges")


## Every thorn bulb in the game grows from something or floats free on purpose,
## and the shaft-wall columns (the grade's "red orb columns") are linked.
func test_thorn_every_bulb_in_the_game_is_rooted() -> void:
	var linked := 0
	var rooted := 0
	var total := 0
	for zone in DirAccess.get_directories_at("res://levels"):
		for file in DirAccess.get_files_at("res://levels/" + zone):
			if not file.ends_with(".room"):
				continue
			var text := FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])
			if not text.contains("o"):
				continue
			var grid: Array = text.split("---", true, 1)[1].strip_edges().split("\n")
			var solid := func(c: Vector2i) -> bool:
				if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= String(grid[c.y]).length():
					return false
				return String(grid[c.y])[c.x] in Room.THORN_HOLDS
			for y in grid.size():
				var line := String(grid[y])
				for x in line.length():
					if line[x] != "o":
						continue
					total += 1
					var a := ThornBulb.anchor_for(Vector2i(x, y), solid)
					if a == Vector2i.ZERO:
						continue
					rooted += 1
					for d: Vector2i in ThornBulb.along(a):
						var n := Vector2i(x, y) + d
						if n.y >= 0 and n.y < grid.size() and n.x < String(grid[n.y]).length() and String(grid[n.y])[n.x] == "o" and ThornBulb.anchor_for(n, solid) == a:
							linked += 1
							break
	check(total > 150, "the game has its thorn bulbs: %d" % total)
	check(rooted * 10 > total * 8, "most bulbs grow from a surface: %d of %d" % [rooted, total])
	check(linked * 10 > rooted * 8, "most rooted bulbs share a vine with a neighbour: %d of %d" % [linked, rooted])
