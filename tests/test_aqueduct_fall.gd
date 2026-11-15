extends TestSuite
## The Drowned Aqueduct's fall and its worn stone (design bible 12.55, pass 568).
## The independent grade after pass 565: "brick repeats uniformly with no edge
## wear or moss, the waterfall is a flat cyan strip". The fall is now drawn a
## column at a time, and the Sunken Spring's ashlar is chipped, cracked and
## mossed on the tiles that have variants.

const PX := 32  # one tile in the atlas (TILE * DENSITY)
const MOSS := Color("728061")  # moss-3, the clump's body
const STONE_BODY := Color("aa9173")  # umber-4, the ashlar's body (12.39)


func _columns() -> Array[int]:
	var out: Array[int] = []
	var c := AqueductSpill.columns()
	for x in range(c.x, c.y):
		out.append(x)
	return out


func test_the_fall_is_a_sheet_with_rims_and_a_light_middle() -> void:
	var mid := AqueductSpill.FALL * 0.5
	check(AqueductSpill.half_width(AqueductSpill.FALL) >= AqueductSpill.half_width(0.0) + 1.5, "the sheet spreads as it drops")
	var tones := {}
	var cols: Array[int] = []
	for x in _columns():
		if AqueductSpill.column_top(x) < mid:
			cols.append(x)
			tones[AqueductSpill.column_tone(x, mid)] = true
	check(cols.size() >= int(AqueductSpill.WIDTH), "the sheet is %d columns wide half way down" % cols.size())
	check(tones.size() == 3, "it has three tones across it, not one fill (%d)" % tones.size())
	check(AqueductSpill.column_tone(cols[0], mid) == AqueductSpill.Tone.EDGE and AqueductSpill.column_tone(cols[-1], mid) == AqueductSpill.Tone.EDGE, "both rims are the dark tone")
	check(AqueductSpill.column_tone(0, mid) == AqueductSpill.Tone.CORE and AqueductSpill.column_tone(-1, mid) == AqueductSpill.Tone.CORE, "the middle is the light tone")
	var mirrored := true
	for x in cols:
		if AqueductSpill.column_tone(x, mid) != AqueductSpill.column_tone(-x - 1, mid):
			mirrored = false
	check(mirrored, "the tones mirror about the middle")
	# The outer columns start lower: the sheet is narrow at the lip.
	var c := AqueductSpill.columns()
	check(AqueductSpill.column_top(c.x) > AqueductSpill.column_top(0) + 20.0, "the outermost column starts well under the lip")
	check(AqueductSpill.column_top(c.x) < AqueductSpill.FALL, "and is drawn before the water")


func test_every_column_runs_its_own_streaks() -> void:
	# One streak pattern scrolled down the whole sheet reads as a strip sliding;
	# each column has its own spacing, length and speed.
	var speeds := {}
	var periods := {}
	var lengths := {}
	for x in _columns():
		var s := AqueductSpill.streak(x, 0)
		speeds[s.z] = true
		periods[s.x] = true
		lengths[s.y] = true
		check(s.x >= 30.0 and s.y >= 4.0 and s.y < s.x * 0.5, "column %d: a streak is shorter than half its spacing (%s)" % [x, s])
		check(s.z >= 120.0 and s.z <= 220.0, "column %d: it falls fast, like water (%.0f px/s)" % [x, s.z])
	check(speeds.size() >= 4, "the columns fall at four speeds or more (%d)" % speeds.size())
	check(periods.size() >= 3, "and are spaced three ways or more (%d)" % periods.size())
	check(lengths.size() >= 4, "and are four lengths or more (%d)" % lengths.size())


func test_the_rims_tear_into_drops_above_the_water() -> void:
	var c := AqueductSpill.columns()
	var foot := AqueductSpill.FALL - 2.0
	check(AqueductSpill.torn(c.x, foot) and AqueductSpill.torn(c.y - 1, foot), "both rims are torn at the foot")
	check(not AqueductSpill.torn(0, foot) and not AqueductSpill.torn(-1, foot), "the middle lands whole")
	var high := AqueductSpill.FALL - AqueductSpill.TEAR - 4.0
	var whole := true
	for x in _columns():
		if AqueductSpill.torn(x, high):
			whole = false
	check(whole, "the sheet is whole above the tear")
	check(AqueductSpill.TEAR >= 16.0 and AqueductSpill.TEAR <= AqueductSpill.FALL * 0.35, "the tear is the last part of the fall (%.0f px)" % AqueductSpill.TEAR)


func test_rings_run_out_from_the_foot_and_mist_stands_in_steps() -> void:
	# A ring runs out along the surface, thins and fades.
	var a := AqueductSpill.ring(0, 0.1)
	var b := AqueductSpill.ring(0, 0.9)
	check(b.x > a.x + 10.0, "a ring runs outward (%.0f to %.0f px)" % [a.x, b.x])
	check(b.y < a.y and b.z < a.z, "thinning and fading as it goes")
	check(a.x >= AqueductSpill.half_width(AqueductSpill.FALL), "it starts outside the sheet's foot")
	var far := 0.0
	var at := 0.0
	while at < 2.0:
		far = maxf(far, AqueductSpill.ring(0, at).x)
		check(AqueductSpill.ring(0, at).z >= 0.0 and AqueductSpill.ring(0, at).y > 0.0, "a ring is never inside out (t %.2f)" % at)
		at += 0.05
	check(far > AqueductSpill.RING_REACH * 0.8 and far <= AqueductSpill.RING_REACH + 9.0, "it reaches about %.0f px (%.0f)" % [AqueductSpill.RING_REACH, far])
	var spread := {}
	for i in AqueductSpill.RINGS:
		spread[snappedf(AqueductSpill.ring(i, 0.3).x, 1.0)] = true
	check(spread.size() == AqueductSpill.RINGS, "the rings are staggered, not stacked")
	# Mist: three flat bands or more, each narrower and taller than the last, so
	# it thickens toward the foot in steps and never as a gradient.
	check(AqueductSpill.MIST.size() >= 3, "the mist has three bands or more")
	var stepped := true
	for i in range(1, AqueductSpill.MIST.size()):
		if AqueductSpill.MIST[i].x >= AqueductSpill.MIST[i - 1].x or AqueductSpill.MIST[i].y <= AqueductSpill.MIST[i - 1].y:
			stepped = false
	check(stepped, "each band is narrower and taller than the one before")
	check(AqueductSpill.MIST_ALPHA * AqueductSpill.MIST.size() <= 0.4, "the mist never hides what is behind it")
	check(AqueductSpill.PLUNGE >= 16.0, "the plunge drives bubbles under the surface")


func test_the_channel_is_the_aqueducts_own_stone() -> void:
	# The trough was a blue-grey slab in a room of warm travertine.
	check(AqueductSpill.STONE.is_equal_approx(STONE_BODY), "the trough's body is the ashlar's body colour")
	check(AqueductSpill.STONE.r > AqueductSpill.STONE.b + 0.1, "warm stone, not blue-grey")
	check(AqueductSpill.STONE_LIGHT.get_luminance() > AqueductSpill.STONE.get_luminance() and AqueductSpill.STONE_DARK.get_luminance() < AqueductSpill.STONE.get_luminance(), "lit above and shaded below")
	check(AqueductSpill.WATER_DARK.get_luminance() < AqueductSpill.WATER.get_luminance() and AqueductSpill.WATER.get_luminance() < AqueductSpill.WATER_LIGHT.get_luminance() and AqueductSpill.WATER_LIGHT.get_luminance() < AqueductSpill.FOAM.get_luminance(), "the water is a ramp of four steps")
	var img := (load(TilesetFactory.TILES_DIR + "sunken.png") as Texture2D).get_image()
	var counts := {}
	for y in PX:
		for x in PX:
			var p := img.get_pixel(TilesetFactory.FULL_VARIANTS[1].x * PX + x, TilesetFactory.FULL_VARIANTS[1].y * PX + y)
			counts[p] = int(counts.get(p, 0)) + 1
	var body := Color.BLACK
	var most := 0
	for p: Color in counts:
		if int(counts[p]) > most:
			most = int(counts[p])
			body = p
	check(body.is_equal_approx(AqueductSpill.STONE), "which is the colour the room's blocks are painted in")


## The longest run of moss along one row of a tile, in world pixels.
func _moss_run(img: Image, tile: Vector2i) -> int:
	var best := 0
	for y in range(0, PX, 2):
		var run := 0
		for x in range(0, PX, 2):
			if img.get_pixel(tile.x * PX + x, tile.y * PX + y).is_equal_approx(MOSS):
				run += 1
				best = maxi(best, run)
			else:
				run = 0
	return best


func test_the_sunken_ashlar_is_mossed_where_it_has_variants() -> void:
	var img := (load(TilesetFactory.TILES_DIR + "sunken.png") as Texture2D).get_image()
	check(img.get_height() >= TilesetFactory.EDGE_ROWS * PX, "the atlas has its edge row")
	var mossed := 0
	for tile: Vector2i in TilesetFactory.FULL_VARIANTS:
		if _moss_run(img, tile) >= 4:
			mossed += 1
	check(mossed == 2, "two of the three surface variants carry a clump of moss (%d)" % mossed)
	check(_moss_run(img, TilesetFactory.WEST_VARIANTS[0]) >= 4, "the west face's variant is mossed")
	check(_moss_run(img, TilesetFactory.EAST_VARIANTS[0]) >= 4, "the east face's variant is mossed")
	# The tiles with no variant of their own stay clean, or the mark would
	# repeat down every pier: the 47 blob tiles in rows 0 to 5.
	var clean := true
	for ty in 6:
		for tx in 8:
			if _moss_run(img, Vector2i(tx, ty)) >= 4:
				clean = false
	check(clean, "no blob tile carries a clump")
	# A pier's face in the room uses both its base tile and its mossed variant.
	var w := make_world({}, "sunken/drowned_aqueduct")
	var faces := {}
	for cell: Vector2i in w.room.tiles.get_used_cells():
		var at := w.room.tiles.get_cell_atlas_coords(cell)
		if TilesetFactory.WEST_VARIANTS.has(at) or TilesetFactory.EAST_VARIANTS.has(at):
			faces[at] = true
	check(faces.size() == 2, "the room lays both mossed face variants (%d)" % faces.size())
	w.free()
