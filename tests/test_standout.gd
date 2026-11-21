extends TestSuite
## Standout: what the player can still use catches the light (pass 630, design
## bible 12.106). The pass 625 grade: "chests, signs and pickups do not
## separate from the scenery".


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data["colors"]:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The half-pixels a chest's parts cover.
func _mask(parts: Array) -> Dictionary:
	var m := {}
	for q: Array in parts:
		for y in range(int(q[1]), int(q[1]) + int(q[3])):
			for x in range(int(q[0]), int(q[0]) + int(q[2])):
				m[Vector2i(x, y)] = true
	return m


## The halo is a few flat steps that brighten inward, faint enough at its edge
## to be light and not a second fog.
func test_standout_the_halo_is_stepped_and_faint() -> void:
	check(Standout.HALO.size() >= 3, "the halo has at least three steps (%d)" % Standout.HALO.size())
	var total := 0.0
	for i in Standout.HALO.size():
		var step: Array = Standout.HALO[i]
		total += float(step[1])
		if i > 0:
			check(float(step[0]) < float(Standout.HALO[i - 1][0]), "step %d is smaller than the one outside it" % i)
	check(float(Standout.HALO[0][0]) == 1.0, "the outermost step reaches the whole radius")
	check(float(Standout.HALO[0][1]) <= 0.1, "the halo's edge is faint (%.2f)" % float(Standout.HALO[0][1]))
	check(total >= 0.25 and total <= 0.45, "its middle is plain to see and not a solid disc (%.2f)" % total)


## A closed chest is rimmed along the whole top of its silhouette, in a tone
## that reads apart from each of its body's, and the rim's tone is its lock's.
func test_standout_a_closed_chest_is_rimmed_in_its_accent() -> void:
	for zone: String in Chest.LOOKS:
		var look: Dictionary = Chest.LOOKS[zone]
		var mask := _mask(Chest.parts(look, false))
		var columns := {}
		for c: Vector2i in mask:
			columns[c.x] = mini(int(columns.get(c.x, 999)), c.y)
		var rim := Chest.rim(look)
		check(rim.size() == columns.size(), "%s: the rim spans every column (%d of %d)" % [zone, rim.size(), columns.size()])
		var on_top := true
		for c: Vector2i in rim:
			if int(columns.get(c.x, 999)) != c.y:
				on_top = false
		check(on_top, "%s: every rim cell is the top of its column" % zone)
		for key: String in ["dark", "mid", "lit"]:
			check(Standout.separates(String(look["glow"]), String(look[key])), "%s: the rim (#%s) reads apart from the body's %s (#%s)" % [zone, look["glow"], key, look[key]])


## A chest stands out until it is opened.
func test_standout_an_opened_chest_goes_dull() -> void:
	var room := Room.from_text("zone: sunken\n---\n########\n#......#\n#..$...#\n########")
	arena.add_child(room)
	var chest: Chest = null
	for n in room.get_children():
		if n is Chest:
			chest = n
	check(chest != null, "the room has its chest")
	if chest == null:
		return
	check(chest.stands_out(), "a closed chest stands out")
	chest.pickup_id = ""
	chest.interact(null)
	check(not chest.stands_out(), "an opened chest does not")


## One glint at a time: it opens through its short arm to its long one and
## shuts again, visits every spot in a cycle, and is shut most of the time.
func test_standout_one_glint_at_a_time() -> void:
	var count := Chest.GLINTS
	var seen := {}
	var open_steps := 0
	var steps := 0
	var longest := 0
	var last := [-1, 0]
	var t := 0.0
	while t < Standout.GLINT_CYCLE:
		var g := Standout.glint_at(t, count)
		steps += 1
		if int(g[0]) >= 0:
			open_steps += 1
			seen[int(g[0])] = true
			check(int(g[1]) >= 1 and int(g[1]) <= Standout.GLINT_ARM, "an open glint has an arm of 1 to %d (%d)" % [Standout.GLINT_ARM, int(g[1])])
			longest = maxi(longest, int(g[1]))
			if int(last[0]) < 0:
				check(int(g[1]) == 1, "a glint opens through its short arm (%d)" % int(g[1]))
		elif int(last[0]) >= 0:
			check(int(last[1]) == 1, "a glint shuts through its short arm (%d)" % int(last[1]))
		last = g
		t += 1.0 / 60.0
	check(seen.size() == count, "every spot glints in a cycle (%d of %d)" % [seen.size(), count])
	check(longest == Standout.GLINT_ARM, "a glint reaches its full arm")
	var share := float(open_steps) / float(steps)
	check(share > 0.3 and share < 0.7, "a glint is open about half the time (%.2f)" % share)
	check(Standout.glint_at(1.0, 0) == [-1, 0], "nothing glints with no spots")
	check(_palette().has(Standout.GLINT), "the glint's tone is a master palette value")
	check(Standout.separates("f0c02e", "4a465d"), "gold reads apart from slate")
	check(Standout.separates("cd51c5", "797767"), "a saturated tone reads apart from a grey no darker than it")
	check(not Standout.separates("797767", "58544c") or Standout.luminance("797767") > Standout.luminance("58544c") * 1.25, "a grey separates from a grey only by light")
	check(not Standout.separates("edce6e", "ccbe8e"), "pale yellow does not read apart from pale wicker")


## The glint's spots sit on the rim, apart from each other and off its ends.
func test_standout_glints_sit_on_the_rim() -> void:
	for zone: String in Chest.LOOKS:
		var rim := Chest.rim(Chest.LOOKS[zone])
		var spots := Standout.glint_spots(rim, Chest.GLINTS)
		check(spots.size() == Chest.GLINTS, "%s: %d spots" % [zone, Chest.GLINTS])
		var xs := {}
		for s: Vector2i in spots:
			check(rim.has(s), "%s: spot %s is a rim cell" % [zone, s])
			check(s != rim[0] and s != rim[-1], "%s: spot %s is off the rim's ends" % [zone, s])
			xs[s.x] = true
		check(xs.size() == Chest.GLINTS, "%s: the spots are in different columns" % zone)
	check(Standout.glint_spots([], 3).is_empty(), "no rim, no spots")


## A stele is rimmed in its inlay's color over every column, and the inlay is
## brighter than the stone.
func test_standout_a_stele_is_rimmed_in_its_inlay() -> void:
	for shape: String in LoreTablet.SHAPES:
		var cols := LoreTablet.profile(shape)
		var rim := LoreTablet.rim(shape)
		check(rim.size() == cols.size(), "%s: the rim spans every column (%d of %d)" % [shape, rim.size(), cols.size()])
		for c: Vector2i in rim:
			check(c.y == int(cols[c.x][0]) - 1, "%s: the rim at x=%d lies on the outline over the stone" % [shape, c.x])
	for zone: String in LoreTablet.LOOKS:
		var look: Dictionary = LoreTablet.LOOKS[zone]
		check(Standout.separates(String(look["glyph"]), String(look["lit"])), "%s: the inlay (#%s) reads apart from the stone's light (#%s)" % [zone, look["glyph"], look["lit"]])
