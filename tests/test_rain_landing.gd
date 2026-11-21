extends TestSuite
## RainLanding: rain lands, and lightning lights the stone (design bible 12.107,
## pass 631). The pass 625 grade: "the rain is one even overlay with no splash
## or wet stone, and the lightning lights nothing".

const SIZE := Vector2i(12, 12)


## A floor along row 10, an awning two cells over its west end (columns 1 to 3,
## row 7), a board at row 5 over columns 8 and 9, and a wall down column 0.
func _yard() -> Array:
	var solids := {}
	for x in SIZE.x:
		solids[Vector2i(x, 10)] = true
		solids[Vector2i(x, 11)] = true
	for y in SIZE.y:
		solids[Vector2i(0, y)] = true
	for x in range(1, 4):
		solids[Vector2i(x, 7)] = true
	var planks := {Vector2i(8, 5): true, Vector2i(9, 5): true}
	return [solids, planks]


func _has(cells: Array[Vector2i], cell: Vector2i) -> bool:
	return cells.has(cell)


## Rain reaches a top with open sky over it and no other.
func test_rain_landing_rain_lands_only_where_the_sky_is_open() -> void:
	var yard := _yard()
	var tops := RainLanding.wet_tops(yard[0], yard[1], SIZE)
	check(_has(tops, Vector2i(6, 10)), "a floor under open sky is wet")
	check(_has(tops, Vector2i(2, 7)), "so is the top of the awning")
	check(_has(tops, Vector2i(8, 5)), "and a board")
	check(not _has(tops, Vector2i(2, 10)), "the floor under the awning is dry")
	check(_has(tops, Vector2i(8, 10)), "a board five cells up is too high to shelter the floor")
	check(not _has(tops, Vector2i(6, 11)), "ground under ground takes no rain")
	check(not _has(tops, Vector2i(0, 0)), "the room's top row is wall, not a floor")
	# A lower roof shelters; one just past SHELTER does not.
	var solids := {Vector2i(1, 9): true, Vector2i(1, 9 - RainLanding.SHELTER): true, Vector2i(3, 9): true, Vector2i(3, 8 - RainLanding.SHELTER): true}
	var two := RainLanding.wet_tops(solids, {}, SIZE)
	check(not _has(two, Vector2i(1, 9)), "a roof %d cells up keeps a top dry" % RainLanding.SHELTER)
	check(_has(two, Vector2i(3, 9)), "a roof %d cells up does not" % (RainLanding.SHELTER + 1))
	# Slopes, water and secrets are left out.
	var skipped := RainLanding.wet_tops(yard[0], yard[1], SIZE, {Vector2i(6, 10): true}, {Vector2i(7, 10): true})
	check(not _has(skipped, Vector2i(6, 10)) and not _has(skipped, Vector2i(7, 10)), "a slope and a skipped cell take none")


## The sheen is a broken line: a dash or two a cell, never the whole top, and
## not the same on every cell.
func test_rain_landing_wet_stone_is_a_broken_line() -> void:
	var shapes := {}
	for x in 40:
		var cell := Vector2i(x, 9)
		var dashes := RainLanding.sheen(cell)
		if dashes.size() < 1 or dashes.size() > 2:
			check(false, "cell %d carries one or two dashes (%d)" % [x, dashes.size()])
		var covered := 0
		var last_end := -1
		for dash: Array in dashes:
			var from := int(dash[0])
			var length := int(dash[1])
			covered += length
			if from < 0 or from + length > RainLanding.TILE or length < 2 or from <= last_end:
				check(false, "cell %d: a dash [%d, %d] lies inside the cell, after the last one, with a gap" % [x, from, length])
			last_end = from + length
		if covered > RainLanding.TILE * 0.7:
			check(false, "cell %d: the sheen covers %d of 16 px; it must stay broken" % [x, covered])
		shapes[str(dashes)] = true
	check(shapes.size() >= 12, "forty cells carry at least twelve different sheens (%d)" % shapes.size())
	check(RainLanding.SHEEN_ALPHA + RainLanding.SHEEN_SWAY <= 0.8, "the sheen never becomes a solid white line (%.2f)" % (RainLanding.SHEEN_ALPHA + RainLanding.SHEEN_SWAY))
	check(RainLanding.SHEEN_ALPHA - RainLanding.SHEEN_SWAY >= 0.3, "and never fades out (%.2f)" % (RainLanding.SHEEN_ALPHA - RainLanding.SHEEN_SWAY))


## Drops strike the wet tops: some cells at any moment, not all, each for a
## fifth of a second through three frames, and fewer in the drizzle.
func test_rain_landing_drops_splash_and_thin_with_the_rain() -> void:
	var storm := 0
	var drizzle := 0
	var samples := 0
	var frames_seen := {}
	var places := {}
	for i in 300:
		var t := i * 0.037
		for x in 20:
			samples += 1
			var hit := RainLanding.splash(Vector2i(x, 9), t)
			if not hit.is_empty():
				storm += 1
				frames_seen[int(hit[1])] = true
				places[int(hit[0])] = true
				if int(hit[0]) < 1 or int(hit[0]) > RainLanding.TILE - 2:
					check(false, "a splash lands inside its cell (%d)" % int(hit[0]))
			if not RainLanding.splash(Vector2i(x, 9), t, 0.35).is_empty():
				drizzle += 1
	var share := float(storm) / samples
	check(share > 0.15 and share < 0.5, "in the storm %.0f%% of wet cells show a splash at a time: plain, not a carpet" % (share * 100.0))
	check(drizzle > 0 and drizzle < storm * 0.55, "the drizzle splashes well under the storm (%d against %d)" % [drizzle, storm])
	check(frames_seen.size() == RainLanding.FRAMES.size(), "a splash runs through all %d frames" % RainLanding.FRAMES.size())
	check(places.size() >= 10, "splashes land all along a cell (%d places)" % places.size())
	# One cell does not splash without a rest, and its splash is short.
	var lit := 0
	for i in 600:
		if not RainLanding.splash(Vector2i(4, 9), i / 60.0).is_empty():
			lit += 1
	check(lit > 30 and lit < 420, "one cell splashes on and off over ten seconds (%d of 600 frames)" % lit)
	check(RainLanding.LIFE < RainLanding.SLOT, "a splash is over before the cell's next roll")
	# A splash widens as it ages and is no brighter than a drop.
	var widths: Array[int] = []
	for frame: Array in RainLanding.FRAMES:
		var lo := 99
		var hi := -99
		for px: Array in frame:
			lo = mini(lo, int(px[0]))
			hi = maxi(hi, int(px[0]))
			if int(px[1]) >= 0 or float(px[2]) > 1.0:
				check(false, "every pixel of a splash stands above the top, at no more than the splash's alpha")
		widths.append(hi - lo)
	check(widths[0] < widths[1] and widths[1] < widths[2], "the splash spreads: %s px wide" % str(widths))
	check(RainLanding.SPLASH_ALPHA <= SheetRain.MAX_ALPHA, "a splash is no brighter than a drop may be (%.2f)" % RainLanding.SPLASH_ALPHA)


## A stroke of lightning is two beats and a fade, seconds apart, and it is
## weather: fainter than a tell.
func test_rain_landing_lightning_is_two_beats_seconds_apart() -> void:
	var starts: Array[float] = []
	for k in 40:
		starts.append(RainLanding.stroke_start(k))
	var shortest := INF
	var longest := 0.0
	for k in range(1, starts.size()):
		shortest = minf(shortest, starts[k] - starts[k - 1])
		longest = maxf(longest, starts[k] - starts[k - 1])
	check(shortest >= 3.0, "strokes are at least three seconds apart (%.1f)" % shortest)
	check(longest <= 11.0 and longest - shortest > 2.0, "and come unevenly, at most eleven apart (%.1f to %.1f)" % [shortest, longest])
	var s := starts[3]
	check_near(RainLanding.flash(s + 0.03), 1.0, 0.001, "the first beat is at full strength")
	check(RainLanding.flash(s + 0.1) < 0.4, "it dips between the beats (%.2f)" % RainLanding.flash(s + 0.1))
	check(RainLanding.flash(s + 0.17) > 0.6 and RainLanding.flash(s + 0.17) < 1.0, "the second beat is the weaker one (%.2f)" % RainLanding.flash(s + 0.17))
	check(RainLanding.flash(s + 0.35) < RainLanding.flash(s + 0.25), "then it fades")
	check_near(RainLanding.flash(s + 0.6), 0.0, 0.001, "and is gone inside six tenths of a second")
	check_near(RainLanding.flash(s - 0.05), 0.0, 0.001, "nothing before the stroke")
	# Lit for a small share of the time.
	var lit := 0
	for i in 6000:
		if RainLanding.flash(i / 60.0) > 0.0:
			lit += 1
	check(lit > 100 and lit < 600, "the sky is lit under a tenth of the time (%d of 6000 frames)" % lit)
	check(RainLanding.SKY_ALPHA <= 0.2, "the stroke lifts the sky by no more than a fifth (%.2f): weather, not a white-out" % RainLanding.SKY_ALPHA)
	check(RainLanding.RIM_ALPHA > RainLanding.SKY_ALPHA * 2.0, "the stone takes more of the light than the sky (%.2f over %.2f)" % [RainLanding.RIM_ALPHA, RainLanding.SKY_ALPHA])
	check(RainLanding.RIM_ALPHA <= 0.6, "and stays under a tell (%.2f)" % RainLanding.RIM_ALPHA)


## The flashes option scales the lightning, and the storm's end stops it.
func test_rain_landing_lightning_obeys_the_flashes_option_and_the_spring() -> void:
	var room := make_room(["zone: spires", "---", "........", "........", "........", "........", "........", "........", "########"])
	var rain := room.get_node_or_null("RainLanding") as RainLanding
	if not check(rain != null, "a Spires room carries a RainLanding"):
		return
	check(rain.tops().size() == 8, "its whole floor is wet (%d of 8)" % rain.tops().size())
	check(rain.get_node("StormSky").z_index < 0, "the sky's lift is drawn behind the ground")
	rain._t = RainLanding.stroke_start(2) + 0.03
	check_near(rain.light(), 1.0, 0.001, "a stroke at full flashes")
	Feel.flash_scale = 0.35
	check_near(rain.light(), 0.35, 0.001, "reduced flashes dim it")
	Feel.flash_scale = 0.0
	check_near(rain.light(), 0.0, 0.001, "flashes off: no lightning")
	Feel.flash_scale = 1.0
	check_near(rain.density(), 1.0, 0.001, "the storm at its height")
	GameState.set_flag("spring:sky")
	check_near(rain.light(), 0.0, 0.001, "the Sky Spring breaks the storm: no lightning")
	var sheet := SheetRain.new()
	check_near(rain.density(), sheet.density(), 0.001, "and the splashes thin as the rain does")
	sheet.free()
	GameState.data.flags.erase("spring:sky")


## It rains in the Spires and nowhere else, and never under water or a roof.
func test_rain_landing_only_the_spires_rooms_catch_rain() -> void:
	var dry := make_room(["zone: boughs", "---", "........", "........", "########"])
	check(dry.get_node_or_null("RainLanding") == null, "a Boughs room has no RainLanding")
	check(RainLanding.falls_in("spires") and not RainLanding.falls_in("haar"), "the rain falls in the Spires only")
	var dir := DirAccess.open("res://levels/spires")
	var rooms := 0
	for file: String in dir.get_files():
		if not file.ends_with(".room"):
			continue
		var room := Room.from_text(FileAccess.get_file_as_string("res://levels/spires/" + file), "spires/" + file.get_basename())
		arena.add_child(room)
		var rain := room.get_node_or_null("RainLanding") as RainLanding
		rooms += 1
		if not check(rain != null, "%s carries a RainLanding" % file):
			continue
		check(rain.tops().size() >= 6, "%s: rain lands somewhere (%d tops)" % [file, rain.tops().size()])
		var bad := 0
		for cell: Vector2i in rain.tops():
			var above := Vector2(cell * Room.TILE) + Vector2(8, -8)
			if cell.y > 0 and room.is_solid_at(above):
				bad += 1
		check(bad == 0, "%s: no wet top lies under ground (%d)" % [file, bad])
		room.queue_free()
	check(rooms >= 9, "every Spires room was walked (%d)" % rooms)
