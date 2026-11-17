extends TestSuite
## The Storm Ledge (pass 589, bible 12.76): the grade after pass 585 named it
## among the rooms that read as rectangular boxes, "flat ceilings, straight
## walls and one thick tile border", and saw the same chest on the same thin
## table in nearly every room. The ledge is a hollow under a broken island of
## stone: its overhang is ragged, open to the storm at its crown and hung with
## spurs, its walls bulge, and the chest stands on a crag, not a table.

const ROOM := "res://levels/spires/storm_ledge.room"
const CHEST := Vector2i(26, 15)


func _grid() -> Array[String]:
	var text := FileAccess.get_file_as_string(ROOM)
	var rows: Array[String] = []
	for line: String in text.split("---\n", false, 1)[1].split("\n", false):
		rows.append(line)
	return rows


func _solid(grid: Array[String], x: int, y: int) -> bool:
	return grid[y][x] == "#"


## The first open row under the ceiling in column x.
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


func test_the_overhang_is_ragged_and_open_to_the_storm() -> void:
	var grid := _grid()
	var w := grid[0].length()
	var heights := {}
	var crown: Array[int] = []
	var spurs: Array[int] = []
	for x in range(1, w - 1):
		var u := _underside(grid, x)
		heights[u] = true
		check(_solid(grid, x, 0), "the room's top row still stands over column %d" % x)
		if u == 1:
			crown.append(x)
		if x >= 2 and x <= w - 3 and u >= maxi(_underside(grid, x - 1), _underside(grid, x + 1)) + 2:
			spurs.append(x)
	check(heights.size() >= 6, "the overhang's underside stands at six heights or more (%s)" % [heights.keys()])
	check(crown.size() >= 4, "it breaks open to the storm up to the top row over four columns or more (%s)" % [crown])
	check(spurs.size() >= 2, "and two spurs of rock hang from it or more (%s)" % [spurs])
	check(_underside(grid, 1) >= 5 and _underside(grid, w - 2) >= 5, "its corners come down low into the walls")


func test_the_walls_bulge() -> void:
	var grid := _grid()
	for west: bool in [true, false]:
		var faces := {}
		for y in range(4, 14):
			faces[_face(grid, y, west)] = true
		check(faces.size() >= 3, "the %s wall's face stands at three depths or more (%s)" % ["west" if west else "east", faces.keys()])


func test_the_chest_stands_on_a_crag_not_a_table() -> void:
	var grid := _grid()
	for y in grid.size():
		check(not grid[y].contains("-"), "the ledge has no plank (row %d)" % y)
	check(grid[CHEST.y][CHEST.x] == "$" and _solid(grid, CHEST.x, CHEST.y + 1), "the chest stands on rock")
	# The crag rises sheer from the floor on its west and steps down to the ledge on its east.
	var west := CHEST.x
	while _solid(grid, west - 1, CHEST.y + 1):
		west -= 1
	var sheer := 0
	while _solid(grid, west, CHEST.y + 1 + sheer) and not _solid(grid, west - 1, CHEST.y + 1 + sheer):
		sheer += 1
	check(sheer >= 3, "its west face drops sheer three rows or more (%d)" % sheer)
	var east := CHEST.x
	while _solid(grid, east + 1, CHEST.y + 1):
		east += 1
	check(_solid(grid, east + 1, CHEST.y + 2) and not _solid(grid, east + 1, CHEST.y + 1),
		"its east side steps down toward the ledge")
