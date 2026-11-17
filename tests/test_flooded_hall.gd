extends TestSuite
## The Flooded Hall (pass 587, bible 12.74): the grade after pass 585 named it
## among the rooms that read as rectangular boxes, "flat ceilings, straight
## walls and one thick tile border", with the chest on a thin table as in
## nearly every room. The hall's two bays are vaulted, the east one has fallen
## in, and the fallen vault lies in a heap under the hole with the chest on it.

const HALL := "res://levels/vorrhallow/flooded_hall.room"
const BAYS := [Vector2i(10, 28), Vector2i(31, 49)]


func _grid() -> Array[String]:
	var text := FileAccess.get_file_as_string(HALL)
	var rows: Array[String] = []
	for line: String in text.split("---\n", false, 1)[1].split("\n", false):
		rows.append(line)
	return rows


## The first open row under the ceiling in column x.
func _underside(grid: Array[String], x: int) -> int:
	var y := 0
	while y < grid.size() and grid[y][x] == "#":
		y += 1
	return y


func test_the_hall_is_vaulted_and_the_east_vault_has_fallen() -> void:
	var grid := _grid()
	var heights := {}
	for x in range(BAYS[0].x, BAYS[1].y + 1):
		heights[_underside(grid, x)] = true
	check(heights.size() >= 6, "the ceiling's underside steps at six heights or more (%s)" % [heights.keys()])
	var bay: Vector2i = BAYS[0]
	var mid := (bay.x + bay.y) / 2
	check(_underside(grid, mid) <= _underside(grid, bay.x) - 3 and _underside(grid, mid) <= _underside(grid, bay.y) - 3,
		"the west bay rises to its crown (%d at the middle, %d and %d at its feet)" % [_underside(grid, mid), _underside(grid, bay.x), _underside(grid, bay.y)])
	check(_underside(grid, BAYS[1].x) >= 5 and _underside(grid, BAYS[1].y) >= 5, "the east bay springs low from its pillars too")
	# The hole: open to the top row of rock over five columns or more.
	var hole: Array[int] = []
	for x in range(BAYS[1].x, BAYS[1].y + 1):
		if _underside(grid, x) <= 2:
			hole.append(x)
	check(hole.size() >= 5, "the east vault has fallen in (open to row 2 over %s)" % [hole])
	var holed_through := 0
	for x: int in hole:
		check(grid[0][x] == "#", "the room's top row still stands over the hole (%d)" % x)
		if _underside(grid, x) == 1:
			holed_through += 1
	check(holed_through >= 3, "and up to the room's top row in places (%d)" % holed_through)
	var jagged := {}
	for x: int in hole:
		jagged[_underside(grid, x)] = true
	check(jagged.size() >= 2, "its edge is broken, not ruled (%s)" % [jagged.keys()])
	var hanging := false
	for x in range(hole.max() + 1, BAYS[1].y):
		if _underside(grid, x) >= _underside(grid, x - 1) + 3 and _underside(grid, x) >= _underside(grid, x + 1) + 2:
			hanging = true
	check(hanging, "a broken voussoir hangs at the hole's east edge")
	# Each pillar has a capital and a broken foot.
	for p: Vector2i in [Vector2i(8, 9), Vector2i(50, 51)]:
		check(grid[4][p.x - 1] == "#" and grid[4][p.y + 1] == "#", "the pillar at %d has a capital" % p.x)
		var foot_a := p.x
		var foot_b := p.y
		var ya := 4
		while grid[ya][foot_a] == "#":
			ya += 1
		var yb := 4
		while grid[yb][foot_b] == "#":
			yb += 1
		check(ya != yb, "and its foot is broken off unevenly (%d, %d)" % [ya, yb])


func test_the_fallen_vault_lies_under_the_hole_with_the_chest_on_it() -> void:
	var grid := _grid()
	var hole: Array[int] = []
	for x in range(BAYS[1].x, BAYS[1].y + 1):
		if _underside(grid, x) <= 2:
			hole.append(x)
	var heap: Array[int] = []
	for x in range(1, grid[0].length() - 1):
		if x > 20 and grid[18][x] in "#/\\":
			heap.append(x)
	check(heap.size() >= 5, "a heap stands in the water (%s)" % [heap])
	if heap.is_empty() or hole.is_empty():
		return
	check(heap.min() >= hole.min() - 2 and heap.max() <= hole.max() + 1, "right under the hole (%s under %s)" % [heap, hole])
	var chest := Vector2i(-1, -1)
	for y in grid.size():
		var x := grid[y].find("$")
		if x >= 0:
			chest = Vector2i(x, y)
	check(chest == Vector2i(40, 15), "the chest has not moved (%s), so it is not new to collect again" % chest)
	check(grid[chest.y + 1][chest.x] == "#", "it stands on the heap's stone")
	var planks := 0
	for row: String in grid:
		planks += row.count("-")
	check(planks == 0, "the hall has no thin table (%d plank cells)" % planks)
	check(grid[19].count("#") <= 9, "and the heap leaves the water most of the floor (%d cells of rock in it)" % grid[19].count("#"))
	# Walked for real: out of the water and up the heap to the chest, no jump.
	var w := make_world({}, "vorrhallow/flooded_hall")
	await frames(3)
	for e: Node in runner.get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await frames(2)
	var p := w.player
	p.global_position = cell_feet(31, 19)
	p.velocity = Vector2.ZERO
	await frames(10)
	var from_y := p.global_position.y
	p.input.move_x = 1
	var steps := 0
	while p.global_position.x < 40 * Room.TILE + 4 and steps < 400:
		await frames(1)
		steps += 1
	p.input.move_x = 0
	await frames(10)
	check(p.global_position.x >= 40 * Room.TILE, "a walk east out of the water reaches the chest (x %.0f after %d frames)" % [p.global_position.x, steps])
	check_near(from_y - p.global_position.y, 4.0 * Room.TILE, 2.0, "four tiles up, by the heap's slope alone")
	check(p.is_on_floor(), "standing on it")
	w.queue_free()
	await frames(2)
