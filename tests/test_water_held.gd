extends TestSuite
## Pass 666 (design bible 12.142): water stands only where something holds it.
## No room's swim water stands against open air at its side or under it, and
## whatever is set in the water (a chest, a figure) is under
## it, not in a dry pocket of its own.


func _rooms() -> Dictionary:
	var out := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if file.ends_with(".room"):
				out[zone + "/" + file.trim_suffix(".room")] = FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])
	return out


## The swim water a room's grid lays (legend `a`, and `l`, an eel's cell), with the
## room's own filling of its holes.
func _water(grid: Array[String]) -> Dictionary:
	var water := {}
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] in ["a", "l"]:
				water[Vector2i(x, y)] = true
	for c: Vector2i in Room.water_holes(grid, water):
		water[c] = true
	return water


func test_no_room_holds_water_up_with_nothing() -> void:
	var bad: Array[String] = []
	var wet := 0
	var rooms := _rooms()
	for id: String in rooms:
		var grid: Array[String] = Room.parse(rooms[id]).grid
		var water := _water(grid)
		wet += 1 if not water.is_empty() else 0
		var open := Room.unheld_water(grid, water)
		if not open.is_empty():
			bad.append("%s %s" % [id, open.slice(0, 4)])
	check(wet >= 4, "the rooms with swim water are read (%d)" % wet)
	check(bad.is_empty(), "every room's water is held at its sides and under it: %s" % [bad])
	# The rule itself: a wall of water beside open air is not held; one beside stone,
	# another water cell or a door is.
	var g: Array[String] = ["#....", "#aa.#", "#aa##", "1aa##", "#####"]
	var w := {Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(1, 2): true, Vector2i(2, 2): true, Vector2i(1, 3): true, Vector2i(2, 3): true}
	check(Room.unheld_water(g, w) == [Vector2i(2, 1)], "only the cell beside the air is open (%s)" % [Room.unheld_water(g, w)])


func test_the_source_halls_pool_lies_level_with_its_ledge() -> void:
	var grid: Array[String] = Room.parse(_rooms()["sunken/source_hall"]).grid
	var water := _water(grid)
	var top := 999
	var edge := 0
	for c: Vector2i in water:
		top = mini(top, c.y)
		edge = maxi(edge, c.x)
	var ledge := top - 2
	while ledge < grid.size() and grid[ledge][edge + 1] != "#":
		ledge += 1
	check(top == ledge, "the surface (row %d) is the ledge's top (row %d)" % [top, ledge])



## Pass 679 (bible 12.156): the Source Hall's pool was a box, one depth from wall to
## ledge. Its bed now climbs to the ledge in steps under the water and a fallen block
## lies on it, so the pool takes three depths or more.
func test_the_source_halls_basin_climbs_to_its_ledge() -> void:
	var grid: Array[String] = Room.parse(_rooms()["sunken/source_hall"]).grid
	var water := _water(grid)
	var depth := {}
	for c: Vector2i in water:
		depth[c.x] = int(depth.get(c.x, 0)) + 1
	var cols: Array = depth.keys()
	cols.sort()
	var kinds := {}
	for x: int in cols:
		kinds[depth[x]] = true
	check(kinds.size() >= 3, "the pool takes three depths or more (%s)" % [kinds.keys()])
	var last: int = cols.back()
	check(int(depth[last]) < int(depth[last - 4]) - 1, "the bed climbs toward the ledge (%d at the ledge, %d four columns west)" % [depth[last], depth[last - 4]])
	var bump := false
	for i in range(2, cols.size() - 6):
		var x: int = cols[i]
		if int(depth[x]) < int(depth[cols[i - 1]]) and int(depth[x]) < int(depth[cols[i + 2]]):
			bump = true
	check(bump, "a fallen block lies on the bed away from the ledge")

func test_what_is_set_in_the_water_is_under_it() -> void:
	var grid: Array[String] = Room.parse(_rooms()["sunken/spring_gate"]).grid
	var water := {}
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] in ["a", "l"]:
				water[Vector2i(x, y)] = true
	var holes := Room.water_holes(grid, water)
	var kinds := {}
	for c in holes:
		kinds[grid[c.y][c.x]] = true
	check(kinds.has("$") and kinds.has("F"), "the chest and the figure are holes (%s)" % [kinds.keys()])
	# A hole needs water over it and something holding it each side and under it;
	# it fills from the top down, so a pocket two cells deep fills whole.
	var g: Array[String] = ["#aaa#", "#a$a#", "#a.a#", "#####"]
	var w := {}
	for y in 3:
		for x in [1, 3]:
			w[Vector2i(x, y)] = true
	w[Vector2i(2, 0)] = true
	var found := Room.water_holes(g, w)
	check(found.size() == 2 and found.has(Vector2i(2, 1)) and found.has(Vector2i(2, 2)), "the chest's cell and the one under it fill (%s)" % [found])
	w.erase(Vector2i(3, 2))
	var open_side := Room.water_holes(["#aaa#", "#a$a#", "#a...", "#####"], w)
	check(open_side.is_empty(), "a pocket open at its side stays dry (%s)" % [open_side])
	var g_air: Array[String] = ["#a.a#", "#a$a#", "#####"]
	check(Room.water_holes(g_air, {Vector2i(1, 0): true, Vector2i(3, 0): true, Vector2i(1, 1): true, Vector2i(3, 1): true}).is_empty(), "nor does one under the open air over the surface")
	# In the loaded room the chest sits in the water.
	var world := make_world({}, "sunken/spring_gate")
	await frames(2)
	var swim: SwimWater = null
	for c in world.room.get_children():
		if c is SwimWater:
			swim = c
	var chest: Chest = null
	for c in world.room.get_children():
		if c is Chest:
			chest = c
	check(swim != null and chest != null, "the room has its water and its chest")
	if swim != null and chest != null:
		var at := Vector2i((world.room.to_local(chest.global_position) - Vector2(0, 2)) / Room.TILE)
		check(swim.cells.has(at), "the chest's cell %s is water" % [at])
