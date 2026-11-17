extends TestSuite
## The Drowned Aqueduct (pass 588, bible 12.75): the grade after pass 585 named
## it among the rooms that read as rectangular boxes, "flat ceilings, straight
## walls and one thick tile border". Its three bays are vaulted, springing low
## from the hanging piers and the walls, the piers' feet are broken off, the
## four arch tops are broken wedges of voussoirs over their piers' stumps on
## the bed, and the east gallery stands on a corbel.

const ROOM := "res://levels/sunken/drowned_aqueduct.room"
## The bays between the walls and the two hanging piers.
const BAYS := [Vector2i(1, 19), Vector2i(26, 51), Vector2i(58, 78)]
const PIERS := [Vector2i(20, 25), Vector2i(52, 57)]
## The four arch tops (their columns at the water's surface).
const ARCHES := [Vector2i(13, 17), Vector2i(30, 34), Vector2i(45, 49), Vector2i(62, 65)]
const FLOOR := 21  # the bed's top row of rock
const SPILL_X := 40


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


func test_the_aqueduct_is_vaulted_and_its_piers_are_broken_off() -> void:
	var grid := _grid()
	var heights := {}
	for x in range(1, 79):
		heights[_underside(grid, x)] = true
	check(heights.size() >= 5, "the ceiling's underside steps at five heights or more (%s)" % [heights.keys()])
	for bay: Vector2i in BAYS:
		var crown := 99
		for x in range(bay.x, bay.y + 1):
			crown = mini(crown, _underside(grid, x))
		var feet := mini(_underside(grid, bay.x), _underside(grid, bay.y))
		check(feet - crown >= 3, "the bay %s rises three tiles or more to its crown (%d at its feet, %d at the crown)" % [bay, feet, crown])
		check(_underside(grid, bay.x) > crown + 2 and _underside(grid, bay.y) > crown + 2, "the bay %s springs low at both sides" % [bay])
	# The broken channel still hangs at the crown, under the old ceiling.
	check(_underside(grid, SPILL_X) == 2, "the spill's column keeps its ceiling at row 1 (%d)" % _underside(grid, SPILL_X))
	for pier: Vector2i in PIERS:
		var feet := {}
		var lowest := 0
		for x in range(pier.x, pier.y + 1):
			var y := _underside(grid, x)
			while _solid(grid, x, y):
				y += 1
			feet[y] = true
			lowest = maxi(lowest, y)
		check(feet.size() >= 2, "the pier %s has a broken foot (%s)" % [pier, feet.keys()])
		check(FLOOR - lowest >= 8, "and you still swim under it (%d rows)" % (FLOOR - lowest))
	# The walls are not straight: each has a buttress under the water.
	for x: int in [1, 78]:
		var under := 0
		for y in range(9, 16):
			if _solid(grid, x, y):
				under += 1
		check(under >= 3, "the wall at column %d has a buttress (%d cells)" % [x, under])
	check(_solid(grid, 77, 9) and _solid(grid, 78, 10) and not _solid(grid, 75, 9), "the gallery stands on a corbel")


func test_the_arch_tops_are_broken_wedges_over_their_stumps() -> void:
	var grid := _grid()
	for arch: Vector2i in ARCHES:
		var widths: Array[int] = []
		var y := 8
		var bottom := 8
		while true:
			var w := 0
			for x in range(arch.x - 1, arch.y + 2):
				if _solid(grid, x, y):
					w += 1
			if w == 0:
				break
			widths.append(w)
			bottom = y
			y += 1
		check(widths.size() >= 4, "the arch top over %s is four rows deep or more (%s)" % [arch, widths])
		if widths.is_empty():
			continue
		check(widths[0] > widths[widths.size() - 1] + 1, "it narrows downward like a broken arch (%s)" % [widths])
		var distinct := {}
		for w: int in widths:
			distinct[w] = true
		check(distinct.size() >= 3, "in three steps or more (%s)" % [widths])
		# Its pier, snapped off on the bed below, with a ragged top.
		var tops := {}
		var highest := FLOOR
		for x in range(arch.x - 1, arch.y + 2):
			var t := FLOOR
			while t > 0 and _solid(grid, x, t - 1):
				t -= 1
			if t < FLOOR:
				tops[t] = true
				highest = mini(highest, t)
		check(tops.size() >= 2, "a stump with a ragged top stands under it (%s)" % [tops.keys()])
		check(highest - bottom - 1 >= Reach.BODY_ROWS, "with room for a swimmer between, %d rows or more (%d)" % [Reach.BODY_ROWS, highest - bottom - 1])
