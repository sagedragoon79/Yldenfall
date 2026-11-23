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


## Pass 640 (design bible 12.116): the pass 635 grade said "the waterfall has no
## splash or mist". The foot now boils, throws spray, sheds lace and puffs, and
## drives a cone of white water under the surface.
func test_the_fall_boils_where_it_lands() -> void:
	var tallest := 0.0
	var mid_taller := true
	var heaves := false
	var covers := true
	for at: float in [0.0, 0.3, 0.7, 1.1, 1.6]:
		var hs: Array[float] = []
		var left := INF
		var right := -INF
		for i in AqueductSpill.CROWN_LUMPS:
			var c := AqueductSpill.crown(i, at)
			hs.append(c.z)
			left = minf(left, c.x)
			right = maxf(right, c.x + c.y)
			tallest = maxf(tallest, c.z)
			if absf(c.z - AqueductSpill.crown(i, at + 0.2).z) >= 2.0:
				heaves = true
		@warning_ignore("integer_division")
		var m := AqueductSpill.CROWN_LUMPS / 2
		mid_taller = mid_taller and hs[m] >= hs[0] and hs[m] >= hs[-1]
		covers = covers and left <= -AqueductSpill.CROWN_HALF and right >= AqueductSpill.CROWN_HALF - 1.0
	check(covers, "the boil spans the foot from side to side, unbroken")
	check(AqueductSpill.CROWN_HALF >= AqueductSpill.half_width(AqueductSpill.FALL) * 3.0, "and is far wider than the sheet")
	check(mid_taller, "it stands tallest in the middle")
	check(tallest >= 8.0 and tallest <= AqueductSpill.CROWN_HIGH, "a mound you see at 1x (%.0f px)" % tallest)
	check(heaves, "every lump heaves")


func test_spray_is_thrown_up_and_falls_back() -> void:
	var high := 0.0
	var wide := 0.0
	var sides := {}
	var back := true
	for i in AqueductSpill.SPRAY:
		var at := 0.0
		var lowest := INF
		while at < 3.0:
			var d := AqueductSpill.spray_drop(i, at)
			high = maxf(high, -d.y)
			wide = maxf(wide, absf(d.x))
			sides[signf(d.x)] = true
			check(d.y <= 0.0 and d.z >= 0.0 and d.z <= 1.0, "a drop never sinks under the surface (%d at %.2f)" % [i, at])
			lowest = minf(lowest, -d.y)
			at += 0.04
		back = back and lowest <= 3.0
	check(high >= 18.0 and high <= AqueductSpill.SPRAY_HIGH + 2.0, "spray leaps well above the boil (%.0f px)" % high)
	check(wide >= 20.0, "and lands well out from it (%.0f px)" % wide)
	check(sides.has(-1.0) and sides.has(1.0), "on both sides")
	check(back, "every drop comes back down to the boil")


func test_lace_drifts_off_and_mist_climbs_the_fall() -> void:
	var a := AqueductSpill.lace(0, 0.1)
	var b := AqueductSpill.lace(0, 3.5)
	check(b.x > a.x and b.z < a.z, "lace drifts out along the surface and fades (%.0f to %.0f)" % [a.x, b.x])
	var far := 0.0
	var at := 0.0
	while at < 6.0:
		far = maxf(far, AqueductSpill.lace(0, at).x)
		at += 0.1
	check(far >= AqueductSpill.RING_REACH, "past the rings (%.0f px)" % far)
	check(AqueductSpill.lace(0, 0.0).x >= AqueductSpill.half_width(AqueductSpill.FALL), "and starts outside the sheet")
	# The mist climbs a third of the way up the fall and spreads wider than the boil.
	check(AqueductSpill.MIST[-1].y >= AqueductSpill.FALL / 3.0, "the mist climbs a third of the fall (%.0f px)" % AqueductSpill.MIST[-1].y)
	check(AqueductSpill.MIST[0].x > AqueductSpill.CROWN_HALF, "and spreads wider than the boil")
	# Puffs break off it, rise and thin.
	var p0 := AqueductSpill.puff(1, 0.0)
	var p1 := AqueductSpill.puff(1, 1.5)
	check(p1.y < p0.y - 20.0 and p1.w < p0.w and p1.z > p0.z, "a puff drifts up, swells and thins")
	check(AqueductSpill.PUFF_ALPHA <= 0.2, "a puff never hides what is behind it")


func test_the_plunge_is_a_cone_of_white_water() -> void:
	var p := AqueductSpill.PLUME
	check(p.size() >= 3, "the plunge has three bands or more")
	var cone := true
	for i in range(1, p.size()):
		cone = cone and p[i].x < p[i - 1].x and p[i].y > p[i - 1].y
	check(cone, "each band is narrower and deeper than the last: a cone, palest at its heart")
	check(p[-1].y >= 30.0, "driven well under the surface (%.0f px)" % p[-1].y)
	check(p[0].x > AqueductSpill.half_width(AqueductSpill.FALL), "wider than the sheet where it goes in")
	check(AqueductSpill.PLUME_ALPHA * p.size() <= 0.6, "the water behind it still shows")
	check(AqueductSpill.PLUNGE >= p[-1].y, "the bubbles are driven to the cone's tip")
