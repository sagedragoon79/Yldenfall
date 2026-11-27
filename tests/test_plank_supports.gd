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
		tones.append_array(look.get("moss", []))
		for t: String in tones:
			check(palette.has(t), "%s: %s is a palette value" % [zone, t])
		check(not (look.bolt in look.wood), "%s: its bolts stand out from the timber" % zone)


## Pass 596: a post is squared timber with a cap under the board and a footing stone, not a stick.
func test_plank_a_post_is_built_timber() -> void:
	# The town's post: the Tower's is an iron column since pass 629 (bible 12.105).
	var look: Dictionary = PlankSupports.LOOKS["hearthroot"]
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
			for s: Dictionary in PlankSupports.place(PlankSupports.plan(planks, solid, size), look):
				if s.kind != "post":
					continue
				posts += 1
				var box := _bounds(PlankSupports.post_parts(s.x, s.top, s.bottom, look, s.knees))
				var row := int(s.top / T)
				var inside := runs.any(func(r: Vector3i) -> bool: return r.x == row and box.position.x >= r.y * T - 0.01 and box.end.x <= (r.z + 1) * T + 0.01)
				check(inside, "%s/%s: the post at x %s stays under its board: %s" % [zone, file, s.x, box])
	check(posts > 20, "the game has posts to check: %d" % posts)


## Pass 604: the pass 600 grade saw "the same X-braced trestle" in nearly every
## area. Each family of zones frames two posts its own way: the town's carpenter's
## trestle, lashed timber in the woods and the Spires, pilings in the marsh and the
## spring, a riveted iron truss in the Tower and the Trials, a stone arch in the
## dwarf halls and grown sinew in the Evercrown.
func test_plank_each_zone_family_frames_its_own_way() -> void:
	var by_style := {}
	for zone: String in PlankSupports.LOOKS:
		var style := String(PlankSupports.LOOKS[zone].get("frame", ""))
		check(style in PlankSupports.FRAMES, "%s frames its runs a known way (%s)" % [zone, style])
		if not by_style.has(style):
			by_style[style] = zone
	check(by_style.size() == PlankSupports.FRAMES.size(), "every style is used (%s)" % [by_style.keys()])
	# The Boughs and the Spires too since pass 625 (bible 12.101): the pass 620 grade saw
	# the canopy bridge and the root shrine on one lashed scaffold.
	var graded := ["hearthroot", "heartwood", "tower", "haar", "boughs", "spires"].map(func(z: String) -> String: return PlankSupports.LOOKS[z].frame)
	var distinct := {}
	for s: String in graded:
		distinct[s] = true
	check(distinct.size() == 6, "the town, the woods, the Tower, the marsh, the Boughs and the Spires each build their own (%s)" % [graded])
	var left := 100.0
	var right := 260.0
	var top := 50.0
	var bottom := 110.0
	var seen := {}
	for style: String in by_style:
		var look: Dictionary = PlankSupports.LOOKS[by_style[style]]
		var parts := PlankSupports.frame_parts(left, right, top, bottom, look)
		var box := _bounds(parts)
		check(box.position.x >= left and box.end.x <= right and box.position.y >= top and box.end.y <= bottom,
			"%s: the frame stays between its posts, the board and the floor (%s)" % [style, box])
		var w: Array = look.wood
		var beams := parts.filter(func(p: Array) -> bool: return p[1] == w[1] and p[0].size.x > 100.0)
		var struts := parts.filter(func(p: Array) -> bool: return p[0].size == Vector2(1.5, 1.5))
		var bolts := parts.filter(func(p: Array) -> bool: return p[1] == look.bolt)
		match style:
			"x":
				check(beams.size() == 1 and struts.size() > 40, "the trestle: one rail and cross-braces")
			"lashed":
				var wraps := parts.filter(func(p: Array) -> bool: return p[0].size == Vector2(3.0, 0.5))
				check(wraps.size() >= 16 and bolts.is_empty(), "lashed timber: rope wrapped at the joints, no bolts (%d wraps)" % wraps.size())
			"piling":
				check(beams.size() == 2 and struts.is_empty(), "pilings: two stringers and no bracing (%d, %d)" % [beams.size(), struts.size()])
			"truss":
				check(beams.size() == 2 and bolts.size() >= 6 and struts.size() > 40, "an iron truss: two chords, a web, rivets at its nodes (%d rivets)" % bolts.size())
			"arch":
				var f: Array = look.foot
				var stone := parts.filter(func(p: Array) -> bool: return p[1] == f[1])
				var key := stone.filter(func(p: Array) -> bool: return p[0].size == Vector2(4.0, 5.0))
				check(stone.size() > 100 and key.size() == 1 and absf(key[0][0].get_center().x - (left + right) * 0.5) < 1.0,
					"a stone arch with its keystone at the crown")
				check(beams.is_empty() and struts.is_empty(), "and no timber")
			"forked":
				var wraps := parts.filter(func(p: Array) -> bool: return p[0].size == Vector2(3.0, 0.5))
				check(beams.is_empty() and struts.size() > 100, "forked limbs: no rail, only limbs (%d)" % struts.size())
				check(bolts.size() >= 8 and wraps.size() >= 12, "still in leaf, and bound with vine at each fork (%d leaves, %d wraps)" % [bolts.size(), wraps.size()])
				# The limbs reach the board wider than the trunks stand on the floor.
				var high := struts.filter(func(p: Array) -> bool: return p[0].position.y < top + 6.0)
				var low := struts.filter(func(p: Array) -> bool: return p[0].end.y > bottom - 4.0)
				var hx: Array = high.map(func(p: Array) -> float: return p[0].position.x)
				var lx: Array = low.map(func(p: Array) -> float: return p[0].position.x)
				check(hx.max() - hx.min() > lx.max() - lx.min() + 20.0, "the limbs spread wider under the board than the trunks stand on the floor")
			"pier":
				var f: Array = look.foot
				var stone := parts.filter(func(p: Array) -> bool: return p[1] == f[1])
				var timber := parts.filter(func(p: Array) -> bool: return p[1] in w)
				check(struts.is_empty() and beams.is_empty() and timber.is_empty() and bolts.is_empty(), "stone piers: no timber and no bolts between the posts")
				var x0 := left + PlankSupports.POST_W * 0.5
				var x1 := right - PlankSupports.POST_W * 0.5
				var corbels := stone.filter(func(p: Array) -> bool: return p[0].size.y == 3.0 and (is_equal_approx(p[0].position.x, x0) or is_equal_approx(p[0].end.x, x1)))
				var reach: Array = corbels.map(func(p: Array) -> float: return p[0].size.x)
				check(corbels.size() == 6 and reach.max() == 12.0 and reach.min() == 4.0, "corbels step out under both ends of the board (%s)" % [reach])
				var shafts := stone.filter(func(p: Array) -> bool: return p[0].size.x == 6.0)
				check(shafts.size() >= 18, "and a coursed pier stands between bays (%d courses)" % shafts.size())
			"web":
				var strand := parts.filter(func(p: Array) -> bool: return p[1] == w[1])
				var mids := strand.filter(func(p: Array) -> bool: return absf(p[0].get_center().x - (left + right) * 0.5) < 4.0)
				var ys: Array = mids.map(func(p: Array) -> float: return p[0].get_center().y)
				check(beams.is_empty() and struts.is_empty() and strand.size() > 100, "grown sinew: strands, no beams or struts")
				check(not ys.is_empty() and ys.max() > top + 20.0, "and they sag toward the middle")
		var key_str := str(parts.map(func(p: Array) -> String: return "%s%s" % [p[0], p[1]]))
		check(not seen.has(key_str), "%s draws a frame of its own" % style)
		seen[key_str] = true


## Pass 629 (bible 12.105): the pass 625 grade still saw "the same cross-braced plank
## platform in nearly every frame, recoloured". The frames differ by zone, so what
## repeated was the plank on two upright squared posts. Each family of zones now
## builds the post itself its own way, and the run's outline changes with it.
func test_plank_each_zone_family_builds_its_own_post() -> void:
	var by_style := {}
	for zone: String in PlankSupports.LOOKS:
		var style := String(PlankSupports.LOOKS[zone].get("post", ""))
		check(style in PlankSupports.POSTS, "%s builds its posts a known way (%s)" % [zone, style])
		if not by_style.has(style):
			by_style[style] = zone
	check(by_style.size() == PlankSupports.POSTS.size(), "every post is used (%s)" % [by_style.keys()])
	var graded := ["hearthroot", "heartwood", "tower", "haar", "boughs", "spires"].map(func(z: String) -> String: return PlankSupports.LOOKS[z].post)
	var distinct := {}
	for g: String in graded:
		distinct[g] = true
	check(distinct.size() == 6, "the town, the woods, the Tower, the marsh, the Boughs and the Spires each build their own post (%s)" % [graded])
	var x := 100.0
	var top := 50.0
	var bottom := 98.0
	var seen := {}
	for style: String in by_style:
		var look: Dictionary = PlankSupports.LOOKS[by_style[style]]
		var w: Array = look.wood
		var f: Array = look.foot
		# The post at a run's left end: its one knee side is the run's middle, to the right.
		var parts := PlankSupports.post_parts(x, top, bottom, look, [1])
		var box := _bounds(parts)
		check(box.position.x >= x - PlankSupports.INSET - 0.01, "%s: nothing reaches past the board's end (%s)" % [style, box])
		check(box.end.y <= bottom + 0.01, "%s: nothing goes into the floor (%s)" % [style, box])
		var timber := parts.filter(func(q: Array) -> bool: return q[1] in w)
		var stone := parts.filter(func(q: Array) -> bool: return q[1] in f)
		var bolts := parts.filter(func(q: Array) -> bool: return q[1] == look.bolt)
		var wraps := parts.filter(func(q: Array) -> bool: return q[0].size.y == 0.5 and q[0].size.x >= 3.0 and q[1] in [look.lit, look.mid])
		var high := parts.filter(func(q: Array) -> bool: return q[0].position.y < top + 3.0)
		var low := parts.filter(func(q: Array) -> bool: return q[0].end.y > bottom - 3.0)
		match style:
			"squared":
				check(is_equal_approx(box.position.y, top) and absf(_bounds(high).get_center().x - _bounds(low).get_center().x) < 4.5, "the squared post stands upright under the board")
			"raked":
				var lean := _bounds(high).get_center().x - _bounds(low).get_center().x
				check(lean >= 6.0 and is_equal_approx(PlankSupports.rake(bottom - top), PlankSupports.RAKE), "the raked leg leans in under the board (%s px)" % lean)
				check(wraps.size() >= 2 and bolts.is_empty() and not stone.is_empty(), "lashed under its cap, no bolt, on a footing stone")
				var other := _bounds(PlankSupports.post_parts(x, top, bottom, look, [-1]).filter(func(q: Array) -> bool: return q[0].position.y < top + 3.0))
				check(other.get_center().x < x - 6.0, "and the leg at the run's other end leans the other way (%s)" % other)
				var lone := PlankSupports.post_parts(x, top, bottom, look)
				check(absf(_bounds(lone).get_center().x - x) < 1.0, "a lone post under a one-cell plank stands square")
			"trunk":
				var caps := parts.filter(func(q: Array) -> bool: return q[0].size.x >= 8.0 and q[0].position.y < top + 3.0)
				check(stone.is_empty() and caps.is_empty(), "the cut limb has no footing stone and no cap block")
				var struts := parts.filter(func(q: Array) -> bool: return q[0].size == Vector2(1.5, 1.5))
				var hx: Array = struts.filter(func(q: Array) -> bool: return q[0].position.y < top + 4.0).map(func(q: Array) -> float: return q[0].get_center().x)
				check(hx.min() < x - 1.5 and hx.max() > x + 6.0, "it forks under the board, the longer limb toward the run's middle (%s to %s)" % [hx.min(), hx.max()])
				check(wraps.size() >= 2 and bolts.size() == 2, "bound with vine at the fork and still in leaf")
			"pile":
				check(is_equal_approx(box.position.y, top - PlankSupports.BOARD - PlankSupports.PILE_HEAD), "the pile's head stands above the deck (%s)" % box.position.y)
				check(parts[0][0].size.x == 5.0 and wraps.size() >= 2, "a round pile 5 px thick, rope wrapped under the board")
				var stones := parts.filter(func(q: Array) -> bool: return q[1] == f[1] and q[0].size.y >= 3.0)
				check(stones.is_empty(), "driven into the mud: no footing stone")
				var lone := _bounds(PlankSupports.post_parts(x, top, bottom, look))
				check(lone.position.y >= top, "a lone pile under a one-cell plank stops under the board (%s)" % lone)
			"column":
				check(stone.is_empty(), "the iron column stands on a base plate, not a stone")
				check(bolts.size() >= 6, "riveted down its web, through its gusset and its base plate (%d)" % bolts.size())
				var gusset := parts.filter(func(q: Array) -> bool: return q[1] == w[1] and q[0].size.y == 1.0 and q[0].position.x >= x + 2.0)
				check(gusset.size() == 7, "a gusset plate steps out to the board on the knee side (%d rows)" % gusset.size())
				check(parts[0][1] == w[2] and parts[1][1] == w[0], "an H-section: lit flanges on a dark web")
			"stone":
				check(timber.filter(func(q: Array) -> bool: return not (q[1] in f)).is_empty() and bolts.is_empty(), "the stone pier has no timber and no bolt")
				var courses := parts.filter(func(q: Array) -> bool: return q[1] == f[1] and q[0].size.x == 6.0)
				check(courses.size() >= 7, "coursed blocks (%d)" % courses.size())
				check(box.end.x >= x + 7.0, "its head corbels out toward the run's middle (%s)" % box)
		var key := str(parts.map(func(q: Array) -> String: return "%s%s" % [q[0], q[1]]))
		check(not seen.has(key), "%s draws a post of its own" % style)
		seen[key] = true


## Pass 629: the Tower and the Trials set a long run's columns in from its ends, so
## the deck overhangs them; a short run's posts stay where the plan put them.
func test_plank_iron_columns_stand_in_from_the_boards_ends() -> void:
	var look: Dictionary = PlankSupports.LOOKS["tower"]
	var size := Vector2i(16, 12)
	var plan := PlankSupports.plan(_planks(8, 2, 13), _box(size), size)
	var placed := PlankSupports.place(plan, look)
	check(_kinds(placed) == _kinds(plan), "the same supports, placed: %s" % [_kinds(placed)])
	var before := plan.filter(func(s: Dictionary) -> bool: return s.kind == "post")
	var posts := placed.filter(func(s: Dictionary) -> bool: return s.kind == "post")
	var set_in: float = look.set_in
	check(set_in >= 8.0, "set in by at least half a tile (%s)" % set_in)
	check(is_equal_approx(posts[0].x, before[0].x + set_in) and is_equal_approx(posts[1].x, before[1].x - set_in), "both columns move toward the middle: %s, %s" % [posts[0].x, posts[1].x])
	check(int(posts[0].x / T) == 2 and int(posts[1].x / T) == 13, "each still over the floor cell it was planned on")
	check(posts[0].knees == [-1, 1] and posts[1].knees == [-1, 1], "gusseted on both sides, under the overhang too")
	check(is_equal_approx(before[0].x, 2 * T + PlankSupports.INSET), "and the plan itself is unchanged")
	var frame: Dictionary = placed.filter(func(s: Dictionary) -> bool: return s.kind == "frame")[0]
	check(is_equal_approx(frame.left, posts[0].x) and is_equal_approx(frame.right, posts[1].x), "the truss spans the moved columns")
	for q: Dictionary in posts:
		var box := _bounds(PlankSupports.post_parts(q.x, q.top, q.bottom, look, q.knees))
		check(box.position.x >= 2 * T and box.end.x <= 14 * T, "a column's gussets stay under its board: %s" % box)
		check(box.position.x - 2 * T >= 3.0 or 14 * T - box.end.x >= 3.0, "and the board overhangs them")
	# A two-cell run is too short to overhang.
	var short := PlankSupports.plan(_planks(8, 6, 7), _box(size), size)
	var same := PlankSupports.place(short, look)
	check(same.filter(func(s: Dictionary) -> bool: return s.kind == "post").all(func(s: Dictionary) -> bool: return s.knees.size() == 1), "a two-cell run keeps its posts at its ends")
	# A zone with no set-in takes the plan as it is.
	check(PlankSupports.place(plan, PlankSupports.LOOKS["hearthroot"]) == plan, "the town takes the plan as it is")
	var zones := PlankSupports.LOOKS.keys().filter(func(z: String) -> bool: return PlankSupports.LOOKS[z].has("set_in"))
	zones.sort()
	check(zones == ["tower", "trials"], "only the iron zones set their posts in: %s" % [zones])


## Pass 629: between raked legs the lashed frame's upper corners come in with the legs.
func test_plank_the_lashed_frame_follows_raked_legs() -> void:
	var look: Dictionary = PlankSupports.LOOKS["heartwood"]
	var square := look.duplicate()
	square["post"] = "squared"
	var top := 50.0
	var bottom := 110.0
	var upper := func(l: Dictionary) -> Rect2:
		return _bounds(PlankSupports.frame_parts(100.0, 140.0, top, bottom, l).filter(func(q: Array) -> bool: return q[0].end.y < top + 12.0))
	var raked: Rect2 = upper.call(look)
	var plain: Rect2 = upper.call(square)
	check(raked.end.x <= plain.end.x - 4.0, "the frame's top corner stays inside the leaning leg (%s, %s upright)" % [raked.end.x, plain.end.x])
	var leg := _bounds(PlankSupports.post_parts(140.0, top, bottom, look, [-1]).filter(func(q: Array) -> bool: return q[0].position.y >= top + 6.0 and q[0].end.y < top + 12.0))
	check(raked.end.x <= leg.end.x + 0.01, "it does not poke out past the leg (%s, leg %s)" % [raked.end.x, leg.end.x])


## Pass 637 (bible 12.113): the pass 635 grade saw "the same orange A-frame trestle" in the
## root shrine, the plaza and the Heartwood tell. The Heartwood's timber is old grey wood
## grown over with moss and lashed with flax; the town keeps its fresh bark.
func test_plank_the_heartwood_builds_in_old_grey_timber_with_moss() -> void:
	var wood: Array = PlankSupports.LOOKS["heartwood"].wood
	var hw: Dictionary = PlankSupports.LOOKS["heartwood"]
	for other: String in ["hearthroot", "boughs"]:
		var theirs: Array = PlankSupports.LOOKS[other].wood
		for t: String in wood:
			check(not (t in theirs), "the Heartwood's timber %s is not %s's" % [t, other])
	var mid := Color(wood[1])
	var town := Color(PlankSupports.LOOKS["hearthroot"].wood[1])
	check(mid.s < 0.25 and mid.s < town.s - 0.3, "the Heartwood's timber is grey, not orange (saturation %.2f, the town's %.2f)" % [mid.s, town.s])
	var town_lit := Color(PlankSupports.LOOKS["hearthroot"].wood[0])
	check(absf(Color(wood[0]).get_luminance() - town_lit.get_luminance()) < 0.1, "it is lit about as the town's is, so it still reads (%.2f, %.2f)" % [Color(wood[0]).get_luminance(), town_lit.get_luminance()])
	for k: String in ["lit", "mid", "dark"]:
		check(Color(hw[k]).s < 0.45 and not (hw[k] in PlankSupports.LOOKS["hearthroot"].wood), "its lashing is flax, not orange rope: %s" % hw[k])
	check(hw.has("moss") and hw.moss.size() == 3, "the Heartwood has moss")
	var moss: Array = hw.moss
	var is_moss := func(q: Array) -> bool: return q[1] in moss
	var top := 50.0
	var bottom := 110.0
	var frame := PlankSupports.frame_parts(100.0, 196.0, top, bottom, hw)
	var on_frame := frame.filter(is_moss)
	check(on_frame.size() >= 6, "moss grows along the rail (%d parts)" % on_frame.size())
	var rail := bottom - 9.0
	for q: Array in on_frame:
		var r: Rect2 = q[0]
		check(r.position.x >= 100.0 and r.end.x <= 196.0, "moss stays on the rail's length: %s" % r)
		check(r.position.y >= rail - 2.5 and r.end.y <= rail + 7.0, "moss sits on the rail or hangs just under it: %s" % r)
	var leg := PlankSupports.post_parts(100.0, top, bottom, hw, [1]).filter(is_moss)
	check(leg.size() >= 3, "moss climbs a leg (%d parts)" % leg.size())
	for q: Array in leg:
		check(q[0].position.y >= bottom - 3.0 - 8.5 and q[0].end.y <= bottom - 1.5, "it climbs only from the footing: %s" % q[0])
	var lone := PlankSupports.post_parts(100.0, top, bottom, hw, [-1, 1]).filter(is_moss)
	check(lone.size() >= 3, "and a lone square post (%d parts)" % lone.size())
	# Zones with no moss grow none.
	var town_look: Dictionary = PlankSupports.LOOKS["hearthroot"]
	var town_parts := PlankSupports.frame_parts(100.0, 196.0, top, bottom, town_look)
	town_parts.append_array(PlankSupports.post_parts(100.0, top, bottom, town_look))
	check(town_parts.filter(is_moss).is_empty(), "the town's trestle grows no moss")
	check(PlankSupports.post_parts(100.0, top, bottom, town_look).all(func(q: Array) -> bool: return not (q[1] in wood)), "and is not built of the Heartwood's timber")


## Pass 652 (bible 12.128): a run that hangs is a deck, a girder as deep as its cell
## with a shadow under it, not a 3 px board on hairs.
func test_plank_a_hung_run_is_a_deck() -> void:
	var size := Vector2i(16, 20)
	var planks := _planks(8, 5, 9)
	var plan := PlankSupports.plan(planks, _box(size), size)
	var decks := PlankSupports.hung_decks(planks, plan)
	check(decks.size() == 1, "the hung run is one deck: %s" % [decks])
	if decks.is_empty():
		return
	var d: Dictionary = decks[0]
	check(is_equal_approx(d.left, 5.0 * T) and is_equal_approx(d.right, 10.0 * T) and is_equal_approx(d.y, 8.0 * T), "it spans the run's cells: %s" % [d])
	for zone: String in ["tower", "spires", "haar", "sunken"]:
		var look: Dictionary = PlankSupports.LOOKS[zone]
		var parts := PlankSupports.deck_parts(d.left, d.right, d.y, look)
		var opaque := parts.filter(func(p: Array) -> bool: return p.size() == 2)
		var box := _bounds(opaque)
		check(box.position.y <= d.y + PlankSupports.DECK_WEB and box.end.y >= d.y + PlankSupports.DECK_FOOT, "%s: the girder runs from under the board to the cell's foot: %s" % [zone, box])
		check(box.position.x <= d.left and box.end.x >= d.right, "%s: and the whole run across" % zone)
		# One mass: every column between the board and the chord is covered.
		var x: float = d.left + 0.5
		while x < d.right:
			var covered := 0.0
			for p: Array in opaque:
				var r: Rect2 = p[0]
				if x >= r.position.x and x < r.end.x and r.position.y <= d.y + PlankSupports.DECK_WEB + covered:
					covered = maxf(covered, r.end.y - d.y - PlankSupports.DECK_WEB)
			check(covered >= PlankSupports.DECK_FOOT - PlankSupports.DECK_WEB, "%s: solid at x %s (%s px deep)" % [zone, x, covered])
			x += 8.0
		var webs := opaque.filter(func(p: Array) -> bool: return p[1] == look.wood[2] and p[0].size.x >= d.right - d.left - 0.5)
		check(not webs.is_empty(), "%s: a dark web across the run, so the deck stands off the backdrop" % zone)
		var bolts := opaque.filter(func(p: Array) -> bool: return p[1] == look.bolt)
		check(bolts.size() >= 8, "%s: bolted under each trestle foot: %d" % [zone, bolts.size()])
		var shadow := parts.filter(func(p: Array) -> bool: return p.size() > 2 and p[0].position.y >= d.y + PlankSupports.DECK_FOOT)
		check(not shadow.is_empty() and shadow.all(func(p: Array) -> bool: return p[2] < 1.0), "%s: a soft shadow under it" % zone)


func test_plank_a_grown_shelf_swells_underneath() -> void:
	var look: Dictionary = PlankSupports.LOOKS["evercrown"]
	var parts := PlankSupports.deck_parts(0.0, 80.0, 0.0, look)
	var foot := func(x0: float, x1: float) -> float:
		var y := 0.0
		for p: Array in parts:
			var r: Rect2 = p[0]
			if p.size() == 2 and r.position.x >= x0 and r.end.x <= x1:
				y = maxf(y, r.end.y)
		return y
	var ends: float = foot.call(0.0, 4.0)
	var mid: float = foot.call(38.0, 42.0)
	check(ends >= PlankSupports.DECK_FOOT - 0.5, "its ends reach the cell's foot: %s" % ends)
	check(mid >= ends + PlankSupports.DECK_SWELL - 1.0, "it is deepest at the middle: %s against %s" % [mid, ends])
	var lit := parts.filter(func(p: Array) -> bool: return p.size() == 2 and p[1] == look.wood[1])
	var dark := parts.filter(func(p: Array) -> bool: return p.size() == 2 and p[1] == look.wood[2])
	var area := func(a: Array) -> float: return a.reduce(func(s: float, p: Array) -> float: return s + p[0].get_area(), 0.0)
	check(area.call(dark) > area.call(lit), "it faces down: more of it in shadow than lit")


func test_plank_a_held_run_is_no_deck_and_hangers_are_heavy() -> void:
	var size := Vector2i(16, 12)
	var planks := _planks(8, 5, 9)
	var plan := PlankSupports.plan(planks, _box(size), size)
	check(PlankSupports.hung_decks(planks, plan).is_empty(), "a run on posts needs no girder")
	check(PlankSupports.CHAIN_W >= 4.0 and PlankSupports.ROPE_W >= 2.5, "chains and ropes are not hairs: %s, %s" % [PlankSupports.CHAIN_W, PlankSupports.ROPE_W])


func test_plank_a_room_takes_its_decks_chord_in_stirrups() -> void:
	var room := Room.from_text("zone: tower
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
	check(holds != null and holds.decks.size() == 1, "the room builds one deck")
	if holds:
		for s: Dictionary in holds.supports:
			if s.kind == "hang":
				check(s.has("stirrup") and is_equal_approx(s.stirrup, 3.0 * T + PlankSupports.DECK_FOOT), "each hanger takes the chord at the cell's foot: %s" % [s])


func test_plank_a_hung_run_meets_its_hangers_in_a_bridle() -> void:
	# The pass 665 grade read hung runs as "platforms hung on chains and ropes from
	# nothing" (design bible 12.147): two loose lines rising out of the frame.
	var size := Vector2i(16, 20)
	var planks := _planks(8, 5, 9)
	var plan := PlankSupports.plan(planks, _box(size), size)
	var bridles := PlankSupports.bridle(planks, _box(size), size, plan)
	check(bridles.size() == 1, "the run hangs from one bridle: %s" % [bridles])
	if bridles.size() == 1:
		var br: Dictionary = bridles[0]
		var board := 8.0 * T + PlankSupports.BOARD
		check(plan.all(func(s: Dictionary) -> bool: return s.get("bridled", false)), "both its hangers are the bridle's legs")
		check(is_equal_approx(br.x, (plan[0].x + plan[1].x) * 0.5), "the ring is over the run's middle: %s" % br.x)
		var rise: float = board - br.apex
		check(rise >= PlankSupports.BRIDLE_MIN and rise <= PlankSupports.BRIDLE_MAX, "the ring stands over the board: %s" % rise)
		check(absf(rise - minf((br.right - br.left) * 0.5, PlankSupports.BRIDLE_MAX)) <= 1.0, "the legs rise at 45 degrees: %s over %s" % [rise, (br.right - br.left) * 0.5])
		check(is_equal_approx(br.top, 1.0 * T), "one hanger runs on from the ring to the ceiling: %s" % br.top)
	# A plank close above: the ring stays clear of it, and a run right under another keeps two straight hangers.
	planks = _planks(6, 4, 10)
	planks.merge(_planks(8, 4, 10))
	plan = PlankSupports.plan(planks, _box(size), size)
	bridles = PlankSupports.bridle(planks, _box(size), size, plan)
	var low := bridles.filter(func(b: Dictionary) -> bool: return is_equal_approx(b.foot, 8.0 * T + PlankSupports.BOARD))
	check(low.size() == 1, "the lower run is bridled under the upper")
	if low.size() == 1:
		check(low[0].apex - low[0].top >= PlankSupports.BRIDLE_CLEAR, "its ring is clear of the plank above: %s" % [low[0]])
		check(is_equal_approx(low[0].top, 6.0 * T + PlankSupports.BOARD_UNDER), "and hangs from that plank's board")
	planks = _planks(7, 4, 10)
	planks.merge(_planks(8, 4, 10))
	plan = PlankSupports.plan(planks, _box(size), size)
	bridles = PlankSupports.bridle(planks, _box(size), size, plan)
	check(not bridles.any(func(b: Dictionary) -> bool: return is_equal_approx(b.foot, 8.0 * T + PlankSupports.BOARD)), "no room for a bridle right under a plank")
	# Nothing over the middle within reach: the two hangers stay as they were.
	size = Vector2i(10, 60)
	var solid := _box(size)
	solid[Vector2i(2, 20)] = true
	solid[Vector2i(7, 20)] = true
	planks = _planks(30, 2, 7)
	plan = PlankSupports.plan(planks, solid, size)
	bridles = PlankSupports.bridle(planks, solid, size, plan)
	check(_kinds(plan) == ["hang", "hang"] and bridles.is_empty(), "no bridle when nothing is over the middle: %s" % [bridles])
	check(not plan.any(func(s: Dictionary) -> bool: return s.get("bridled", false)), "and no hanger is marked as a leg")
	# The rooms the grade named hang their decks on bridles.
	for path: String in ["res://levels/tower/foot.room", "res://levels/evercrown/veins.room"]:
		var room := Room.from_file(path)
		arena.add_child(room)
		var holds := room.get_node_or_null("PlankSupports") as PlankSupports
		check(holds != null and holds.bridles.size() >= 4, "%s hangs its decks on bridles: %d" % [path, holds.bridles.size() if holds else -1])
		room.queue_free()
