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
	check(_kinds(plan) == ["post", "post", "frame"], "two posts and the frame between them: %s" % [_kinds(plan)])
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
					if s.kind == "frame":
						return false
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


func test_plank_the_evercrown_hangs_its_grown_shelves_on_sinew() -> void:
	# The Evercrown's shelves are grown (bible 12.34, pass 542): sinew, not the hot
	# crystal chains (cd51c5, a736aa) the pass 540 grade called flat magenta.
	var look: Dictionary = PlankSupports.LOOKS["evercrown"]
	check(look.hang == "sinew", "the Evercrown hangs its shelves on sinew: %s" % look.hang)
	var hot := ["cd51c5", "a736aa", "712b78"]
	for k: String in ["lit", "mid", "dark"]:
		check(not (look[k] in hot), "its %s tone is not hot stillglass: %s" % [k, look[k]])
	for w: String in look.wood:
		check(not (w in hot), "its tissue posts are not hot stillglass: %s" % w)
	var room := Room.from_text("zone: evercrown
---
##########
#........#
#........#
#..----..#
#........#
#........#
#........#
#........#
#........#
#........#
##########")
	arena.add_child(room)
	var holds := room.get_node_or_null("PlankSupports") as PlankSupports
	check(holds != null and holds._look.hang == "sinew", "an Evercrown room takes the sinew look")


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func _bounds(parts: Array) -> Rect2:
	var box: Rect2 = parts[0][0]
	for p: Array in parts:
		box = box.merge(p[0])
	return box


## Pass 596 (bible 12.81): every support tone, the bolts and footings too, is a master palette value.
func test_plank_every_support_tone_is_in_the_palette() -> void:
	var palette := _palette()
	for zone: String in PlankSupports.LOOKS:
		var look: Dictionary = PlankSupports.LOOKS[zone]
		var tones: Array = [look.lit, look.mid, look.dark, look.bolt]
		tones.append_array(look.wood)
		tones.append_array(look.foot)
		for t: String in tones:
			check(palette.has(t), "%s: %s is a palette value" % [zone, t])
		check(not (look.bolt in look.wood), "%s: its bolts stand out from the timber" % zone)


## Pass 596: a post is squared timber with a cap under the board and a footing stone, not a stick.
func test_plank_a_post_is_built_timber() -> void:
	var look: Dictionary = PlankSupports.LOOKS["tower"]
	var parts := PlankSupports.post_parts(100.0, 50.0, 98.0, look)
	var body: Rect2 = parts[0][0]
	check(body.size.x >= PlankSupports.POST_W and PlankSupports.POST_W >= 4.0, "the post is at least 4 px wide: %s" % body.size.x)
	var foot := parts.filter(func(p: Array) -> bool: return p[1] == look.foot[1])
	check(foot.size() == 1 and foot[0][0].size.x > body.size.x and is_equal_approx(foot[0][0].end.y, 98.0), "a footing stone, wider than the post, on the floor")
	var bolts := parts.filter(func(p: Array) -> bool: return p[1] == look.bolt)
	check(bolts.size() >= 1 and bolts[0][0].position.y < 53.0, "a bolt in the cap under the board")
	var box := _bounds(parts)
	check(box.position.y >= 50.0 and box.end.y <= 98.0, "it stays between the board and the floor: %s" % box)
	check(box.position.x < 100.0 - 6.0 and box.end.x > 100.0 + 6.0, "knee brackets reach out on both sides by default: %s" % box)
	var right := _bounds(PlankSupports.post_parts(100.0, 50.0, 98.0, look, [1]))
	check(right.position.x >= 100.0 - PlankSupports.POST_W * 0.5 - 2.0, "with knees to the right only, nothing reaches past the cap on the left: %s" % right)


## Pass 596: two posts under a run are tied by a rail and cross-braced bay by bay.
func test_plank_two_posts_are_framed_together() -> void:
	var look: Dictionary = PlankSupports.LOOKS["gym"]
	var size := Vector2i(16, 12)
	var plan := PlankSupports.plan(_planks(8, 2, 13), _box(size), size)
	var frames := plan.filter(func(s: Dictionary) -> bool: return s.kind == "frame")
	check(frames.size() == 1, "one frame between the two posts: %s" % [_kinds(plan)])
	if frames.is_empty():
		return
	var f: Dictionary = frames[0]
	var parts := PlankSupports.frame_parts(f.left, f.right, f.top, f.bottom, look)
	var box := _bounds(parts)
	check(box.position.x >= f.left and box.end.x <= f.right, "the frame stays between its posts: %s" % box)
	check(box.position.y >= f.top and box.end.y <= f.bottom, "and between the board and the floor: %s" % box)
	var rails := parts.filter(func(p: Array) -> bool: return p[1] == look.wood[1] and p[0].size.x > 100.0)
	check(rails.size() == 1, "one rail spans the posts")
	var studs := parts.filter(func(p: Array) -> bool: return p[1] == look.wood[1] and p[0].size.y > 8.0 and p[0].size.x <= 2.0)
	var bays := studs.size() + 1
	check((f.right - f.left) / bays <= PlankSupports.BAY_MAX + PlankSupports.POST_W, "no bay is wider than BAY_MAX (%d bays over %s px)" % [bays, f.right - f.left])
	# A run too close to the floor for a frame gets posts alone.
	plan = PlankSupports.plan(_planks(9, 2, 13), _box(size), size)
	check(_kinds(plan) == ["post", "post"], "one empty row under the run: no frame: %s" % [_kinds(plan)])


## Pass 596: in every room, no post's knee bracket juts past the end of the board it holds.
func test_plank_no_post_juts_past_its_run() -> void:
	var posts := 0
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
					if grid[y][x] == "-":
						planks[Vector2i(x, y)] = true
					elif grid[y][x] in ["#", "%", "u", "/", "\\"]:
						solid[Vector2i(x, y)] = true
			var look: Dictionary = PlankSupports.LOOKS.get(zone, PlankSupports.LOOKS["gym"])
			var runs := PlankSupports.runs(planks)
			for s: Dictionary in PlankSupports.plan(planks, solid, size):
				if s.kind != "post":
					continue
				posts += 1
				var box := _bounds(PlankSupports.post_parts(s.x, s.top, s.bottom, look, s.knees))
				var row := int(s.top / T)
				var inside := runs.any(func(r: Vector3i) -> bool: return r.x == row and box.position.x >= r.y * T - 0.01 and box.end.x <= (r.z + 1) * T + 0.01)
				check(inside, "%s/%s: the post at x %s stays under its board: %s" % [zone, file, s.x, box])
	check(posts > 20, "the game has posts to check: %d" % posts)
