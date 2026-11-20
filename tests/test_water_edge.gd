extends TestSuite
## Pass 620: the water meets the stone (design bible 12.97). The deep water's
## surface is a swell with glints, dim under a roof; water laps a square face of
## stone at its surface; and stone that stands in water is darkened at its faces.

const ROWS := [
	"################",
	"#..............#",
	"#..........###.#",
	"#..............#",
	"#.....##.......#",
	"#aaaaa##aaaaaaa#",
	"#aaaaa##aaaaaaa#",
	"#aaaaaaaaaaaaaa#",
	"################",
]


func _water(room: Room) -> SwimWater:
	for c in room.get_children():
		if c is SwimWater:
			return c
	return null


func test_water_surface_is_a_swell_not_a_ruled_line() -> void:
	var lifts := {}
	var smooth := true
	var glints := 0
	var pieces := 0
	var thin := 2.0
	var thick := 0.0
	for step in 40:
		var t := step * 0.13
		var prev := SwimWater.crest_lift(0.0, t)
		for i in range(1, 160):
			var x := float(i * SwimWater.CREST_STEP)
			var l := SwimWater.crest_lift(x, t)
			lifts[l] = true
			smooth = smooth and absi(l - prev) <= 1
			prev = l
			pieces += 1
			if SwimWater.glint(x, t):
				glints += 1
				check(SwimWater.crest_alpha(x, t, false) == 1.0, "a glint is whole") if glints == 1 else null
			else:
				var a := SwimWater.crest_alpha(x, t, false)
				thin = minf(thin, a)
				thick = maxf(thick, a)
	check(lifts.size() >= 3, "the crest rises and falls (%d heights)" % lifts.size())
	check(smooth, "and never jumps more than a pixel between neighbouring pieces")
	var share := float(glints) / float(pieces)
	check(share > 0.01 and share < 0.2, "glints are on a small part of the crest (%.3f)" % share)
	check(thick - thin >= 0.25 and thick < 1.0, "the line thins and thickens along its length (%.2f to %.2f)" % [thin, thick])
	var falls := true
	var last := 2.0
	for band: Array in SwimWater.SHEEN:
		falls = falls and float(band[1]) < last
		last = float(band[1])
	check(falls and SwimWater.SHEEN.size() >= 3, "a sheen under the crest falls off in steps")


func test_water_body_steps_are_close_in_tone() -> void:
	check(SwimWater.LEVELS >= 8, "the body has at least eight steps (%d)" % SwimWater.LEVELS)
	var a := SwimWater.level_color(0)
	var b := SwimWater.level_color(1)
	check(absf(a.a - b.a) <= 0.1, "one step is at most a tenth of alpha from the next (%.3f)" % absf(a.a - b.a))


func test_water_surface_is_dim_under_a_roof() -> void:
	var room := make_room(ROWS)
	var water := _water(room)
	if not check(water != null, "the room has its water"):
		return
	# The slab at row 2 hangs three tiles over columns 11 to 13.
	check(water.shaded.has(Vector2i(11, 5)) and water.shaded.has(Vector2i(13, 5)), "the surface under the slab is in shade")
	check(not water.shaded.has(Vector2i(9, 5)) and not water.shaded.has(Vector2i(2, 5)), "the surface under open air is not")
	check(not water.shaded.has(Vector2i(14, 5)), "nor the cell beside the slab")
	var dim := true
	for i in 200:
		var x := float(i * 2)
		var t := float(i) * 0.07
		dim = dim and SwimWater.crest_alpha(x, t, true) < SwimWater.crest_alpha(x, t, false)
	check(dim, "the crest is dimmer in shade everywhere, glint or not")
	check(SwimWater.SHEEN_SHADE < 1.0, "and its sheen is thinner")


func test_water_laps_the_stone_at_its_surface() -> void:
	var room := make_room(ROWS)
	var water := _water(room)
	if not check(water != null, "the room has its water"):
		return
	var found := {}
	for bank: Array in water.banks:
		found[[bank[0], bank[1]]] = bank[2]
	check(found.size() == 4, "four banks: the two walls and the pier's two faces (%d)" % found.size())
	check(found.get([Vector2i(1, 5), -1], false) == true, "the west wall, which rises over the waterline")
	check(found.get([Vector2i(14, 5), 1], false) == true, "the east wall")
	check(found.get([Vector2i(5, 5), 1], false) == true, "the pier's west face")
	check(found.has([Vector2i(8, 5), -1]), "the pier's east face")
	check(water.bank_face([Vector2i(5, 5), 1, true]) == Vector2(6 * Room.TILE, 5 * Room.TILE), "a bank's face is the stone's edge on the surface")
	check(water.bank_face([Vector2i(8, 5), -1, true]) == Vector2(8 * Room.TILE, 5 * Room.TILE), "on either side")
	# The foam: at the stone, on the surface and up the face; it moves, and a fleck drifts off.
	var climbs := {}
	var far := 0
	for step in 60:
		var px: Array = WaterEdge.lap(step * 0.1, 3)
		var top := 0
		var on_surface := 0
		for p: Array in px:
			check(int(p[0]) >= 0 and float(p[2]) >= 0.0 and float(p[2]) <= 1.0, "foam lies on the water's side") if step == 0 else null
			top = mini(top, int(p[1]))
			on_surface += 1 if int(p[1]) == 0 else 0
			far = maxi(far, int(p[0]))
		climbs[top] = true
		if step == 0:
			check(on_surface >= 3, "foam lies along the surface beside the stone (%d px)" % on_surface)
	check(climbs.has(-1) and climbs.has(-2) and climbs.size() == 2, "the foam climbs the face one or two pixels with the swell")
	check(far >= 6 and far <= 4 + WaterEdge.FLECK_REACH, "a fleck drifts off and no farther than its reach (%d)" % far)
	# A slope is not a bank.
	var sloped := make_room([
		"##########",
		"#........#",
		"#aaaa/####",
		"#aaaa#####",
		"##########",
	])
	var w2 := _water(sloped)
	var east := false
	for bank: Array in w2.banks:
		east = east or int(bank[1]) > 0
	check(w2.banks.size() == 1 and not east, "a slope beside the surface gets no foam (%d banks)" % w2.banks.size())


func test_stone_that_stands_in_water_takes_it() -> void:
	var room := make_room(ROWS)
	var water := _water(room)
	if not check(water != null, "the room has its water"):
		return
	var steps := WaterEdge.SUNK_STEPS.size()
	var reach := steps * WaterEdge.SUNK_STEP
	check(reach >= 8 and reach < Room.TILE, "the band reaches well into the stone and less than a tile (%d px)" % reach)
	var falls := true
	for k in range(1, steps):
		falls = falls and WaterEdge.SUNK_STEPS[k] < WaterEdge.SUNK_STEPS[k - 1]
	check(falls, "it fades in steps from the water's side")
	var in_stone := true
	var by_cell := {}
	for band: Array in water.sunk:
		var r: Rect2 = band[0]
		var c := Vector2i((r.position / float(Room.TILE)).floor())
		var c2 := Vector2i(((r.end - Vector2.ONE) / float(Room.TILE)).floor())
		in_stone = in_stone and c == c2 and not water.cells.has(c) and water.stone.has(c)
		by_cell[c] = int(by_cell.get(c, 0)) + 1
	check(in_stone, "every band lies inside one cell of stone, never on the water")
	# The pier's cell at the surface row touches water on one side; its foot (row 6) on a side and from below.
	check(by_cell.get(Vector2i(6, 5), 0) == steps, "the pier's west cell takes one face (%s)" % by_cell.get(Vector2i(6, 5), 0))
	check(by_cell.get(Vector2i(6, 6), 0) == steps * 2, "its foot takes two: the side and the underside (%s)" % by_cell.get(Vector2i(6, 6), 0))
	check(by_cell.get(Vector2i(5, 8), 0) == steps, "the floor under the pool takes its top")
	check(not by_cell.has(Vector2i(6, 4)), "stone over the waterline takes none")
	# The first step lies against the water.
	for band: Array in water.sunk:
		var r: Rect2 = band[0]
		if int(band[1]) == 0 and Vector2i((r.position / float(Room.TILE)).floor()) == Vector2i(6, 5):
			check(r.end.x == 7.0 * Room.TILE - 0.0 or r.position.x == 6.0 * Room.TILE, "the darkest step is at the face")
			check(r.position.x == 6.0 * Room.TILE, "on the side the water is (x %s)" % r.position.x)
	check(water.get_node_or_null("Stone") != null, "the stone's part is its own layer, drawn once")


func test_standing_water_meets_the_stone_too() -> void:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(10, 19))
	await frames(2)
	var tide: Tide = w.room.tide
	if not check(tide != null, "the hall has its water"):
		return
	check(tide.banks.size() >= 2, "the still water has banks (%d)" % tide.banks.size())
	var ok := true
	for bank: Array in tide.banks:
		var c: Vector2i = bank[0]
		ok = ok and c.y == tide.row and tide.cells.has(c) and tide.stone.has(c + Vector2i(int(bank[1]), 0))
	check(ok, "each is a surface cell with square stone beside it")
	check(tide.sunk.size() >= tide.banks.size() * WaterEdge.SUNK_STEPS.size(), "and the stone in it is darkened (%d bands)" % tide.sunk.size())
	check(Tide.LAP_PACE < 1.0 and Tide.LAP_ALPHA < 1.0, "still water laps slower and fainter than deep water")
