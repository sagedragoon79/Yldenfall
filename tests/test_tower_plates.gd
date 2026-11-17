extends TestSuite
## The Tower's plates are a tile tall and quiet (design bible 12.54, pass 566),
## in sheets one to three tiles long (12.70, pass 583).
## Plates of 8 world pixels put four seams and sixteen rivets in every tile, and
## a worn plate a whole shade darker made dark squares: a floor three tiles thick
## read as a test pattern that fought the crucible (independent grade, pass 565).

const PX := 32  # one tile in the atlas (TILE * DENSITY)
const HALF := 16
## A ramp step is about 20 in luminance (0 to 255); see test_calm_frame_tiles.
const WORN_GAP := 10.0


func _atlas() -> Image:
	return (load(TilesetFactory.TILES_DIR + "tower.png") as Texture2D).get_image()


## The twelve interior tiles, by tier: the surface field and its variants, MID
## and DEEP.
func _tiers() -> Array:
	var full: Array[Vector2i] = []
	for y in 8:
		for x in 8:
			var c := TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), 1)
			if not TilesetFactory.FULL_VARIANTS.has(c) and not full.has(c):
				full.append(c)
	full.append_array(TilesetFactory.FULL_VARIANTS)
	return [full, TilesetFactory.MID, TilesetFactory.DEEP]


func _px(img: Image, tile: Vector2i, x: int, y: int) -> Color:
	return img.get_pixel(tile.x * PX + x, tile.y * PX + y)


func test_a_plate_is_a_whole_tile() -> void:
	# The seam is the tile's top row (and its left column, unless the sheet runs
	# on from the west: 12.70). With plates of 8 world pixels a second seam ran
	# down column 16 and across row 16.
	var img := _atlas()
	var tiles := 0
	for tier: Array in _tiers():
		for tile: Vector2i in tier:
			tiles += 1
			var seam := _px(img, tile, 9, 0)
			check(_px(img, tile, 20, 0).is_equal_approx(seam), "tile %s: the top row is one seam" % tile)
			var mid := 0
			for k in range(2, PX):
				if _px(img, tile, HALF, k).is_equal_approx(seam):
					mid += 1
				if _px(img, tile, k, HALF).is_equal_approx(seam):
					mid += 1
			check(mid * 4 < (PX - 2) * 2, "tile %s: no seam crosses the middle of the tile (%d of %d pixels)" % [tile, mid, (PX - 2) * 2])
	check(tiles == 12, "12 interior tiles were measured, got %d" % tiles)


## True if the tile's left column is a seam: the colour of its top row, for
## most of its height.
func _west_seam(img: Image, tile: Vector2i) -> bool:
	var seam := _px(img, tile, 9, 0)
	var n := 0
	for y in range(2, PX):
		if _px(img, tile, 0, y).is_equal_approx(seam):
			n += 1
	return n * 2 > PX


func test_sheets_run_longer_than_a_tile() -> void:
	# A plate to a tile made the field graph paper (independent grade, pass 580).
	# In every set the factory scatters, some tiles have no west seam, so the
	# sheet from the west runs through them, and some start a sheet (12.70).
	var img := _atlas()
	var sets: Array = _tiers()
	for tiles: Array in sets:
		var joined := 0
		for tile: Vector2i in tiles:
			if not _west_seam(img, tile):
				joined += 1
				# Nothing to rivet where there is no joint: the west rivets are gone.
				var body := _px(img, tile, 9, 9)
				for y: int in [3, PX - 4]:
					check(_px(img, tile, 3, y).get_luminance() < body.get_luminance() + 0.06,
						"tile %s: no rivet head on the side with no joint" % tile)
		check(joined >= 1, "a set of %d plates has one with no west seam, got %d" % [tiles.size(), joined])
		check(joined < tiles.size(), "and one that starts a sheet")
	# A floor's top and a ceiling's bottom join up too. Their top row is the cap
	# or the soffit, so count the seam's colour down the left column instead.
	var full_seam := _px(img, TilesetFactory.FULL_VARIANTS[0], 9, 0)
	for variants: Array in [TilesetFactory.TOP_VARIANTS, TilesetFactory.BOTTOM_VARIANTS]:
		var joined := 0
		for tile: Vector2i in variants:
			var n := 0
			for y in range(2, PX - 2):
				if _px(img, tile, 0, y).is_equal_approx(full_seam):
					n += 1
			if n * 4 < PX:
				joined += 1
		check(joined >= 1 and joined < variants.size(), "some edge variants join the sheet to the west, got %d of %d" % [joined, variants.size()])
	# In a long course the sheets differ in length: one, two and three tiles.
	var lengths := {}
	var run := 1
	for x in range(1, 200):
		if _west_seam(img, TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, 5), 1)):
			lengths[run] = true
			run = 1
		else:
			run += 1
	check(lengths.has(1) and lengths.has(2) and lengths.has(3), "a course has sheets of one, two and three tiles: %s" % [lengths.keys()])
	# The 47 blob tiles keep their seam: an inside corner starts a sheet.
	var corner := TilesetFactory.ground(TilesetFactory.FULL & ~TilesetFactory.NE, Vector2i.ZERO, 1)
	check(_west_seam(img, corner), "a corner tile starts a sheet")


## The mean luminance (0 to 255) of one 16 px quarter of a tile.
func _quarter(img: Image, tile: Vector2i, q: Vector2i) -> float:
	var total := 0.0
	for y in HALF:
		for x in HALF:
			total += _px(img, tile, q.x * HALF + x, q.y * HALF + y).get_luminance()
	return total / float(HALF * HALF) * 255.0


func test_no_plate_is_a_dark_square() -> void:
	# A worn plate is pitted, not a shade darker: no tile's mean stands a ramp
	# step off its tier's body, darker or brighter.
	var img := _atlas()
	for tier: Array in _tiers():
		var lums: Array[float] = []
		for tile: Vector2i in tier:
			var l := 0.0
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				l += _quarter(img, tile, q) / 4.0
			lums.append(l)
		var sorted := lums.duplicate()
		sorted.sort()
		var body: float = (sorted[1] + sorted[2]) / 2.0
		for l in lums:
			check(absf(l - body) < WORN_GAP, "no plate stands a step off its tier's body (%.1f against %.1f)" % [l, body])


## The share of a plate's face (inside the bevel) that is darker than its body
## colour, the commonest one.
func _pits(img: Image, tile: Vector2i) -> float:
	var counts := {}
	for y in range(3, PX - 2):
		for x in range(3, PX - 2):
			var c := _px(img, tile, x, y).to_rgba32()
			counts[c] = int(counts.get(c, 0)) + 1
	var body := 0
	for c: int in counts:
		if int(counts[c]) > int(counts.get(body, 0)):
			body = c
	var body_l := Color.hex(body).get_luminance()
	var dark := 0
	var all := 0
	for c: int in counts:
		all += int(counts[c])
		if Color.hex(c).get_luminance() < body_l - 0.01:
			dark += int(counts[c])
	return float(dark) / float(all)


func test_the_odd_plate_is_pitted() -> void:
	# The field is not one tile repeated: a few plates are pitted (about a
	# quarter of the face a shade down), most are sound (a few percent).
	var img := _atlas()
	var pitted := 0
	var tiles := 0
	for tier: Array in _tiers():
		for tile: Vector2i in tier:
			tiles += 1
			var p := _pits(img, tile)
			if p > 0.15:
				pitted += 1
			else:
				check(p < 0.1, "tile %s: a sound plate is clean (%.2f of its face is pitted)" % [tile, p])
	check(pitted >= 1, "at least one interior plate is pitted, got %d" % pitted)
	check(pitted * 2 <= tiles, "at most half the interior plates are pitted, got %d of %d" % [pitted, tiles])


func test_rivets_are_few_and_dim() -> void:
	# Four rivets to a tile, not sixteen, and no brighter than the plate's lit
	# bevel: the brightest pixel inside a surface plate is one step over its
	# body, where the old rivet head stood three over.
	var img := _atlas()
	var tile: Vector2i = _tiers()[0][0]
	var bevel := _px(img, tile, 1, 9).get_luminance()
	var brighter := 0
	for y in range(2, PX - 1):
		for x in range(2, PX - 1):
			if _px(img, tile, x, y).get_luminance() > bevel + 0.09:
				brighter += 1
	check(brighter <= 4, "at most four rivet heads stand over the bevel in a tile, got %d" % brighter)
