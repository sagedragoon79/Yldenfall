extends TestSuite
## The Tower's plates are a tile wide and quiet (design bible 12.54, pass 566).
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
	# The seam is the tile's left column and top row. With plates of 8 world
	# pixels a second seam ran down column 16 and across row 16.
	var img := _atlas()
	var tiles := 0
	for tier: Array in _tiers():
		for tile: Vector2i in tier:
			tiles += 1
			var seam := _px(img, tile, 0, 9)
			check(_px(img, tile, 9, 0).is_equal_approx(seam), "tile %s: the top row is the seam too" % tile)
			var mid := 0
			for k in range(2, PX):
				if _px(img, tile, HALF, k).is_equal_approx(seam):
					mid += 1
				if _px(img, tile, k, HALF).is_equal_approx(seam):
					mid += 1
			check(mid * 4 < (PX - 2) * 2, "tile %s: no seam crosses the middle of the tile (%d of %d pixels)" % [tile, mid, (PX - 2) * 2])
	check(tiles == 12, "12 interior tiles were measured, got %d" % tiles)


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
