extends TestSuite
## PlankSupports: what holds each one-way plank run up (design bible 12.30).
## The plan is pure grid logic, so these cover which support each run gets.

const T := PlankSupports.TILE


## A closed box of `size` (walls on every edge) with the given plank cells.
func _box(size: Vector2i) -> Dictionary:
	var solid := {}
	for x in size.x:
		solid[Vector2i(x, 0)] = true
		solid[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		solid[Vector2i(0, y)] = true
		solid[Vector2i(size.x - 1, y)] = true
	return solid


func _planks(row: int, from: int, to: int) -> Dictionary:
	var out := {}
	for x in range(from, to + 1):
		out[Vector2i(x, row)] = true
	return out


func _kinds(plan: Array[Dictionary]) -> Array:
	return plan.map(func(s: Dictionary) -> String: return s.kind)


func test_plank_runs_are_found_left_to_right() -> void:
	var planks := _planks(3, 2, 5)
	planks.merge(_planks(3, 8, 9))
	planks.merge(_planks(6, 4, 4))
	var runs := PlankSupports.runs(planks)
	check(runs == [Vector3i(3, 2, 5), Vector3i(3, 8, 9), Vector3i(6, 4, 4)], "three runs, in reading order: %s" % [runs])


func test_plank_a_run_in_open_air_hangs_from_the_ceiling() -> void:
	var size := Vector2i(16, 20)
	var plan := PlankSupports.plan(_planks(8, 5, 9), _box(size), size)
	check(_kinds(plan) == ["hang", "hang"], "two hangers: %s" % [_kinds(plan)])
	for s: Dictionary in plan:
		check(s.anchored, "anchored on the ceiling")
		check(is_equal_approx(s.top, 1.0 * T), "from the ceiling's underside (row 1 top): %s" % s.top)
		check(is_equal_approx(s.bottom, 8.0 * T + PlankSupports.BOARD), "down to the board")
	check(plan[0].x < 6 * T and plan[1].x > 9 * T, "one at each end of the run")


func test_plank_a_low_run_stands_on_posts() -> void:
	var size := Vector2i(16, 12)
	# The floor is row 11; the run at row 8 has two empty rows (9, 10) under it.
	var plan := PlankSupports.plan(_planks(8, 5, 9), _box(size), size)
	check(_kinds(plan) == ["post", "post"], "two posts: %s" % [_kinds(plan)])
	check(is_equal_approx(plan[0].bottom, 11.0 * T), "down to the floor's top")


func test_plank_a_post_never_reaches_past_its_limit() -> void:
	var size := Vector2i(16, 30)
	var plan := PlankSupports.plan(_planks(29 - 2 - PlankSupports.POST_MAX, 5, 9), _box(size), size)
	check(not _kinds(plan).has("post"), "a floor POST_MAX + 1 rows down is too far: %s" % [_kinds(plan)])


func test_plank_a_run_against_a_wall_is_braced_into_it() -> void:
	var size := Vector2i(16, 20)
	# Against the left wall (column 0), and short: the brace alone carries it.
	var plan := PlankSupports.plan(_planks(8, 1, 3), _box(size), size)
	check(_kinds(plan) == ["brace"], "one brace: %s" % [_kinds(plan)])
	check(plan[0].side == -1 and plan[0].cell == Vector2i(1, 8), "into the wall on its left")
	# A long run braced at one end still hangs its free end.
	plan = PlankSupports.plan(_planks(8, 1, 8), _box(size), size)
	check(_kinds(plan) == ["brace", "hang"], "brace and a hanger at the free end: %s" % [_kinds(plan)])
	check(plan[1].x > 8 * T, "the hanger is at the far end")
	# Spanning wall to wall: two braces, nothing else.
	plan = PlankSupports.plan(_planks(8, 1, 14), _box(size), size)
	check(_kinds(plan) == ["brace", "brace"], "braced at both ends: %s" % [_kinds(plan)])


func test_plank_a_hanger_takes_the_plank_above_at_its_board() -> void:
	var size := Vector2i(16, 30)
	var planks := _planks(6, 4, 10)
	planks.merge(_planks(12, 4, 10))
	var plan := PlankSupports.plan(planks, _box(size), size)
	var lower := plan.filter(func(s: Dictionary) -> bool: return is_equal_approx(s.bottom, 12.0 * T + PlankSupports.BOARD))
	check(lower.size() == 2, "the lower run has two hangers")
	for s: Dictionary in lower:
		check(is_equal_approx(s.top, 6.0 * T + PlankSupports.BOARD_UNDER), "fixed under the upper plank's board, not its trestle: %s" % s.top)


func test_plank_a_hanger_with_nothing_near_above_fades_out() -> void:
	var size := Vector2i(10, 60)
	var solid := _box(size)
	var row := 1 + PlankSupports.HANG_MAX + 2
	var plan := PlankSupports.plan(_planks(row, 3, 3), solid, size)
	check(_kinds(plan) == ["hang"], "a lone plank cell gets one hanger: %s" % [_kinds(plan)])
	check(not plan[0].anchored, "too far from the ceiling to be anchored")
	check(is_equal_approx(plan[0].top, float((row - PlankSupports.FADE_TILES) * T)), "it runs FADE_TILES up and fades")
	check(is_equal_approx(plan[0].x, 3 * T + T * 0.5), "a single cell hangs from its middle")


func test_plank_every_run_in_the_game_is_held_up() -> void:
	var runs := 0
	var faded := 0
	for zone: String in DirAccess.get_directories_at("res://levels"):
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if not file.ends_with(".room"):
				continue
			var grid: Array[String] = Room.parse(FileAccess.get_file_as_string("res://levels/%s/%s" % [zone, file])).grid
			var planks := {}
			var solid := {}
			var size := Vector2i(0, grid.size())
			for y in grid.size():
				size.x = maxi(size.x, grid[y].length())
				for x in grid[y].length():
					var ch := grid[y][x]
					if ch == "-":
						planks[Vector2i(x, y)] = true
					elif ch in ["#", "%", "u", "/", "\\"]:
						solid[Vector2i(x, y)] = true
			var plan := PlankSupports.plan(planks, solid, size)
			for run: Vector3i in PlankSupports.runs(planks):
				runs += 1
				var held := plan.any(func(s: Dictionary) -> bool:
					if s.kind == "brace":
						return s.cell.y == run.x and s.cell.x in [run.y, run.z]
					var x: float = s.x
					var row := run.x * T + PlankSupports.BOARD
					var at_row: bool = is_equal_approx(s.bottom, row) if s.kind == "hang" else is_equal_approx(s.top, row)
					return at_row and x >= run.y * T and x <= (run.z + 1) * T)
				check(held, "%s/%s: the plank run at row %d, columns %d-%d is held up" % [zone, file, run.x, run.y, run.z])
			faded += plan.filter(func(s: Dictionary) -> bool: return s.kind == "hang" and not s.anchored).size()
	check(runs > 100, "the game's rooms have plank runs to hold up: %d" % runs)
	check(faded * 4 < runs, "most hangers find something above them (%d of %d runs fade out)" % [faded, runs])


func test_plank_a_room_builds_its_supports_behind_the_tiles() -> void:
	var room := Room.from_text("zone: spires\n---\n##########\n#........#\n#........#\n#..----..#\n#........#\n#........#\n#........#\n#........#\n#........#\n#........#\n##########")
	arena.add_child(room)
	var holds := room.get_node_or_null("PlankSupports") as PlankSupports
	check(holds != null, "the room has a PlankSupports layer")
	if holds:
		check(holds.z_index < 0, "drawn behind the tiles")
		check(_kinds(holds.supports) == ["hang", "hang"], "its run hangs from the ceiling: %s" % [_kinds(holds.supports)])
		check(holds._look.hang == "rope", "the Spires hang theirs on rope")
