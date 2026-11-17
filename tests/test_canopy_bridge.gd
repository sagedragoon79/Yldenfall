extends TestSuite
## The Canopy Bridge (pass 590, bible 12.77): the grade after pass 585 named it
## among the rooms that read as rectangular boxes, "flat ceilings, straight
## walls and one thick tile border", and saw the chest on a thin table hung
## by ropes in room after room. The bridge now crosses a hollow in the Tree's
## crown: the canopy overhead is ragged, notched up toward the sky and hung
## with knots of wood, the trunk walls bulge, and the chest stands on a bough
## that grows out of the east trunk, not on a plank.

const ROOM := "res://levels/boughs/canopy_bridge.room"
const CHEST := Vector2i(26, 9)


func _grid() -> Array[String]:
	var text := FileAccess.get_file_as_string(ROOM)
	var rows: Array[String] = []
	for line: String in text.split("---\n", false, 1)[1].split("\n", false):
		rows.append(line)
	return rows


func _solid(grid: Array[String], x: int, y: int) -> bool:
	return grid[y][x] == "#"


## The first open row under the canopy in column x.
func _underside(grid: Array[String], x: int) -> int:
	var y := 0
	while y < grid.size() and _solid(grid, x, y):
		y += 1
	return y


## The first open column in from the west (or east) wall in row y.
func _face(grid: Array[String], y: int, west: bool) -> int:
	var w := grid[y].length()
	var x := 0 if west else w - 1
	var step := 1 if west else -1
	while _solid(grid, x, y):
		x += step
	return x


func test_the_canopy_is_ragged_and_hung_with_knots() -> void:
	var grid := _grid()
	var w := grid[0].length()
	var heights := {}
	var notches: Array[int] = []
	var knots: Array[int] = []
	for x in range(1, w - 1):
		var u := _underside(grid, x)
		heights[u] = true
		check(_solid(grid, x, 0), "the room's top row still stands over column %d" % x)
		if u == 1:
			notches.append(x)
		# A knot: a column hanging two rows or more below the nearest open
		# column on each side that rises higher.
		if x >= 2 and x <= w - 3:
			var left := x - 1
			while left > 0 and _underside(grid, left) == u:
				left -= 1
			var right := x + 1
			while right < w - 1 and _underside(grid, right) == u:
				right += 1
			if u >= _underside(grid, left) + 2 and u >= _underside(grid, right) + 2:
				knots.append(x)
	check(heights.size() >= 6, "the canopy's underside stands at six heights or more (%s)" % [heights.keys()])
	check(notches.size() >= 4, "it notches up toward the sky over four columns or more (%s)" % [notches])
	check(knots.size() >= 2, "and knots of wood hang from it (%s)" % [knots])
	check(_underside(grid, 1) >= 6 and _underside(grid, w - 2) >= 6, "its corners come down low into the trunk")


func test_the_wind_still_blows_through_open_air() -> void:
	# The current is a whole rectangle over open sky (levels/README.md), so the
	# canopy's knots hang only above it.
	var grid := _grid()
	var wind := 0
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] == ">":
				wind += 1
				check(y >= 4 and y <= 6 and x >= 10 and x <= 30, "the wind at (%d, %d) is inside its band" % [x, y])
	check(wind == 63, "the wind band is whole, 21 by 3 (%d)" % wind)


func test_the_trunk_walls_bulge() -> void:
	var grid := _grid()
	for west: bool in [true, false]:
		var faces := {}
		for y in range(4, 16):
			faces[_face(grid, y, west)] = true
		check(faces.size() >= 4, "the %s trunk's face stands at four depths or more (%s)" % ["west" if west else "east", faces.keys()])


func test_the_chest_stands_on_a_bough_not_a_table() -> void:
	var grid := _grid()
	check(grid[CHEST.y][CHEST.x] == "$" and _solid(grid, CHEST.x, CHEST.y + 1), "the chest stands on wood")
	for y in range(0, 16):
		check(not grid[y].contains("-"), "no plank hangs over the bridge (row %d)" % y)
	# The bough runs unbroken from under the chest to the east trunk.
	var row := CHEST.y + 1
	var x := CHEST.x
	while x < grid[row].length() and _solid(grid, x, row):
		x += 1
	check(x == grid[row].length(), "the bough under the chest grows out of the east trunk (breaks at %d)" % x)
	# It tapers: thin at the tip, thicker toward the trunk.
	var tip := CHEST.x
	while _solid(grid, tip - 1, row):
		tip -= 1
	var thick_tip := 0
	while _solid(grid, tip, row + thick_tip):
		thick_tip += 1
	var thick_root := 0
	var root := grid[row].length() - 3
	var top := row
	while _solid(grid, root, top - 1):
		top -= 1
	while _solid(grid, root, top + thick_root):
		thick_root += 1
	check(thick_tip == 1, "its tip is one tile thick (%d)" % thick_tip)
	check(thick_root >= 4, "its root at the trunk is four tiles thick or more (%d)" % thick_root)
