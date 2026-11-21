extends TestSuite
## TopLip: the top of the ground is not a ruled line (design bible 12.103, pass
## 627). The pass 625 grade: terrain has "no top-lip variation".

const SIZE := Vector2i(20, 12)


## A `SIZE` grid: a ceiling three rows thick, a floor two rows thick, and a
## ledge four cells long hanging in the open at row 6.
func _hall() -> Dictionary:
	var solids := {}
	for y in SIZE.y:
		for x in SIZE.x:
			if y < 3 or y >= SIZE.y - 2:
				solids[Vector2i(x, y)] = true
	for x in range(8, 12):
		solids[Vector2i(x, 6)] = true
	return solids


func _room(zone: String) -> Room:
	var rows: Array = ["zone: " + zone, "---"]
	for y in 14:
		var row := ""
		for x in 24:
			var solid := y < 3 or y >= 12 or x == 0 or x == 23
			if y == 8 and x >= 9 and x < 13:
				solid = true
			row += "#" if solid else "."
		rows.append(row)
	return make_room(rows)


func test_top_lip_a_walking_surface_takes_the_lip_and_nothing_else_does() -> void:
	var solids := _hall()
	var s := TopLip.surface_cells(solids, SIZE)
	check(s.has(Vector2i(5, 10)), "the floor's top course is a surface")
	check(s.has(Vector2i(9, 6)), "so is the ledge")
	check(not s.has(Vector2i(5, 11)), "the course under the floor's top is not")
	check(not s.has(Vector2i(5, 2)) and not s.has(Vector2i(5, 0)), "nor is any course of the ceiling")
	var slopes := {Vector2i(9, 6): true}
	check(not TopLip.surface_cells(solids, SIZE, slopes).has(Vector2i(9, 6)), "a slope takes none")
	check(not TopLip.surface_cells(solids, SIZE, {}, {Vector2i(5, 10): true}).has(Vector2i(5, 10)), "a skipped cell (a secret's cover) takes none")
	check(not TopLip.surface_cells(solids, SIZE, {}, {Vector2i(5, 9): true}).has(Vector2i(5, 10)), "nor does ground with a skipped cell (water) over it")


func test_top_lip_the_top_rises_and_falls() -> void:
	var cols := 40 * TopLip.CELL
	var level := 0
	var tall := 0
	var most := 0
	var kinds := {}
	for tx in cols:
		var h := TopLip.hummock_height(tx, 10)
		kinds[h] = true
		most = maxi(most, h)
		if h == 0:
			level += 1
		if h >= 4:
			tall += 1
	check(most <= TopLip.MAX_PEAK and most >= 5, "the tallest hummock of a long floor is 5 to MAX_PEAK texels (%d)" % most)
	check(kinds.size() >= 5, "the top line takes at least five heights (%d)" % kinds.size())
	var share := float(level) / cols
	check(share > 0.3 and share < 0.75, "between a third and three quarters of the top stays level, so the mounds read (%.2f)" % share)
	check(tall > 0 and float(tall) / cols < 0.2, "tall moss is the odd mound, not the rule (%.2f)" % (float(tall) / cols))
	# Runs: the top changes height often, and a level stretch never runs a whole screen.
	var longest := 0
	var run := 0
	for tx in cols:
		run = run + 1 if TopLip.hummock_height(tx, 10) == 0 else 0
		longest = maxi(longest, run)
	check(longest < 6 * TopLip.CELL, "no level stretch is six cells long (%d texels)" % longest)


func test_top_lip_no_two_cells_and_no_two_rows_grow_the_same() -> void:
	var first := []
	var second := []
	var other_row := []
	for i in TopLip.CELL * 4:
		first.append(TopLip.hummock_height(i, 10))
		second.append(TopLip.hummock_height(i + TopLip.CELL * 4, 10))
		other_row.append(TopLip.hummock_height(i, 6))
	check(first != second, "four cells of a floor do not repeat the four before them")
	check(first != other_row, "a ledge does not grow as the floor under it does")
	check(first == [TopLip.hummock_height(0, 10)] + first.slice(1), "and the same column always grows the same")


func test_top_lip_a_hummock_is_lit_from_the_west() -> void:
	var lit_lee := 0
	var lit := 0
	var dark_lee := 0
	var roots := 0
	for tx in 40 * TopLip.CELL:
		var h := TopLip.hummock_height(tx, 10)
		if h == 0:
			continue
		var lee := TopLip.hummock_height(tx + 1, 10) < h
		if TopLip.hummock_tone(tx, 10, h, h) == TopLip.LIGHT:
			lit += 1
			if lee:
				lit_lee += 1
		for up in range(1, h):
			if lee and TopLip.hummock_tone(tx, 10, up, h) == TopLip.DARK:
				dark_lee += 1
		if h >= 4 and TopLip.hummock_tone(tx, 10, 1, h) == TopLip.DARK:
			roots += 1
	check(lit > 0, "some tips catch the light (%d)" % lit)
	check(lit_lee == 0, "no tip on a flank that falls away east is lit (%d)" % lit_lee)
	check(dark_lee > 0, "the east flank's body is in shade (%d texels)" % dark_lee)
	check(roots > 0, "a tall mound is dark at its root")


func test_top_lip_moss_hangs_over_the_end_of_a_ledge() -> void:
	var solids := _hall()
	check(TopLip.ends_at(solids, SIZE, Vector2i(8, 6), false), "the ledge ends at open air on its west")
	check(TopLip.ends_at(solids, SIZE, Vector2i(11, 6), true), "and on its east")
	check(not TopLip.ends_at(solids, SIZE, Vector2i(9, 6), true), "a cell with ground beside it has no end there")
	check(not TopLip.ends_at(solids, SIZE, Vector2i(0, 10), false), "the room's frame is not an end")
	solids[Vector2i(12, 5)] = true
	check(not TopLip.ends_at(solids, SIZE, Vector2i(11, 6), true), "a ledge that runs under a step up has no end there")
	var lengths := {}
	for cell: Vector2i in [Vector2i(8, 6), Vector2i(3, 9), Vector2i(14, 4), Vector2i(30, 7)]:
		for east: bool in [false, true]:
			var at_edge := TopLip.drape_length(cell, east, 0)
			lengths[at_edge] = true
			check(at_edge >= 3 and at_edge <= TopLip.DRAPE_MAX, "the strand at the corner hangs 3 to DRAPE_MAX texels (%d)" % at_edge)
			check(TopLip.drape_length(cell, east, -1) >= 1, "the moss stands proud of the wall face")
			check(TopLip.drape_length(cell, east, -TopLip.DRAPE_PROUD - 1) == 0, "but no further than DRAPE_PROUD")
			check(TopLip.drape_length(cell, east, TopLip.DRAPE_WIDTH) == 0, "and the drape is DRAPE_WIDTH texels wide")
			check(TopLip.drape_length(cell, east, TopLip.DRAPE_WIDTH - 1) < at_edge, "it is shorter away from the corner (%d under %d)" % [TopLip.drape_length(cell, east, TopLip.DRAPE_WIDTH - 1), at_edge])
	check(lengths.size() >= 4, "ledge ends hang to different lengths (%d of 8)" % lengths.size())


func test_top_lip_the_tones_are_the_cap_s_own() -> void:
	check(TopLip.CAPS.size() == 8, "eight zones carry the moss cap (%d)" % TopLip.CAPS.size())
	for zone: String in TopLip.CAPS:
		var t := TopLip.tones(zone)
		if not check(t.size() == 3, "%s has a light, a mid and a dark tone" % zone):
			continue
		check(t[TopLip.LIGHT].get_luminance() > t[TopLip.MID].get_luminance() and t[TopLip.MID].get_luminance() > t[TopLip.DARK].get_luminance(), "%s: light over mid over dark" % zone)
		# Every tone is a colour the tileset paints its cap with: in the first
		# rows of the top-edge tile or one of its variants.
		var img := (load(TilesetFactory.TILES_DIR + zone + ".png") as Texture2D).get_image()
		var cap := {}
		var tiles: Array[Vector2i] = [TilesetFactory.ground(TilesetFactory.EDGE_TOP)]
		tiles.append_array(TilesetFactory.TOP_VARIANTS)
		for tile: Vector2i in tiles:
			for y in 8:
				for x in TopLip.CELL:
					cap[Color(img.get_pixel(tile.x * TopLip.CELL + x, tile.y * TopLip.CELL + y), 1.0).to_html(false)] = true
		for k in 3:
			check(cap.has(t[k].to_html(false)), "%s: tone %d (%s) is a colour of the tileset's cap" % [zone, k, t[k].to_html(false)])
	for zone: String in ["hearthroot", "tower", "trials"]:
		check(not TopLip.has_lip(zone) and TopLip.tones(zone).is_empty(), "%s has a stone or iron cap: no moss lip" % zone)


func test_top_lip_the_room_grows_it_over_the_tiles_and_under_the_light() -> void:
	var room := _room("boughs")
	var lip := room.get_node_or_null("TopLip") as TopLip
	if not check(lip != null, "the room builds a TopLip"):
		return
	check(lip.quad_count() > 0, "and it draws")
	check(room.get_node("Tiles").get_index() < lip.get_index(), "over the tiles")
	check(lip.get_index() < room.get_node("RoomLight").get_index(), "under the room's light, so under every actor after it")
	check(lip.is_surface(Vector2i(5, 12)) and lip.is_surface(Vector2i(10, 8)), "the floor and the ledge are surfaces")
	check(not lip.is_surface(Vector2i(5, 2)) and not lip.is_surface(Vector2i(5, 13)), "the ceiling and the floor's second course are not")
	var t := float(Room.TILE)
	var grown := 0
	for i in 22 * TopLip.CELL:
		if lip.height_at(t + (i + 0.5) / TopLip.DENSITY, 12) > 0:
			grown += 1
	check(grown > 0 and grown < 22 * TopLip.CELL, "the floor's top is mounds and level stretches (%d of %d columns)" % [grown, 22 * TopLip.CELL])
	check(lip.height_at(5.5 * t, 2) == 0, "nothing grows on a ceiling's row")
	check(lip.drape_at(Vector2i(9, 8), false, 0) > 0 and lip.drape_at(Vector2i(12, 8), true, 0) > 0, "moss hangs over both ends of the ledge")
	check(lip.drape_at(Vector2i(10, 8), true, 0) == 0, "and not from its middle")
	check(lip.drape_at(Vector2i(1, 12), false, 0) == 0, "nor where the floor meets the wall")


func test_top_lip_a_zone_with_no_moss_cap_grows_none() -> void:
	var lip := _room("tower").get_node_or_null("TopLip") as TopLip
	if not check(lip != null, "the room still has the node"):
		return
	check(lip.quad_count() == 0, "an iron floor grows no moss (%d quads)" % lip.quad_count())
	check(not lip.is_surface(Vector2i(5, 12)), "and has no lip surfaces")


func test_top_lip_ground_under_water_grows_none_and_a_torn_floor_loses_its_lip() -> void:
	var rows: Array = ["zone: sunken", "---"]
	for y in 14:
		var row := ""
		for x in 24:
			var solid := y < 3 or y >= 12 or x == 0 or x == 23
			row += "#" if solid else ("a" if y >= 9 and x < 12 else ".")
		rows.append(row)
	var room := make_room(rows)
	var lip := room.get_node("TopLip") as TopLip
	check(not lip.is_surface(Vector2i(5, 12)), "the bed under the water has no lip")
	check(lip.is_surface(Vector2i(16, 12)), "the dry floor beside it has")
	room.tear_floor(15, 17, 12, 12)
	check(not lip.is_surface(Vector2i(16, 12)), "a torn floor's lip goes with it")
	check(lip.is_surface(Vector2i(16, 13)), "and the pit's new floor grows its own")
	check(lip.drape_at(Vector2i(14, 12), true, 0) > 0, "the pit's rim drapes")
