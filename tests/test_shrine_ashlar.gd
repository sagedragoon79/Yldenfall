extends TestSuite
## The Spires' ashlar runs through the tile seams (design bible 12.70, pass 583).
## Each scattered variant used to have its own block size, so two side by side
## met with their bed joints at different heights and their blocks cut off at
## the seam, and the wall showed its grid (independent grade, pass 580).

const PX := 32  # one tile in the atlas (TILE * DENSITY)
## The last row of each course (5, 6 and 5 world pixels, two to a pixel).
const BEDS: Array[int] = [9, 21, 31]


func _atlas() -> Image:
	return (load(TilesetFactory.TILES_DIR + "spires.png") as Texture2D).get_image()


## Every tile a wall's inside is drawn with: the full blob tile, the surface
## variants, MID and DEEP.
func _fields() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in 64:
		var c := TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, 3), 1)
		if not out.has(c):
			out.append(c)
	for c: Vector2i in TilesetFactory.MID + TilesetFactory.DEEP:
		out.append(c)
	return out


func _px(img: Image, tile: Vector2i, x: int, y: int) -> Color:
	return img.get_pixel(tile.x * PX + x, tile.y * PX + y)


func test_bed_joints_sit_at_the_same_heights_in_every_tile() -> void:
	var img := _atlas()
	var tiles := _fields()
	check(tiles.size() == 12, "12 field tiles were measured, got %d" % tiles.size())
	for tile in tiles:
		var joint := _px(img, tile, 16, BEDS[0])
		for y in PX:
			var n := 0
			for x in PX:
				if _px(img, tile, x, y).is_equal_approx(joint):
					n += 1
			if BEDS.has(y):
				check(n == PX, "tile %s: row %d is a bed joint from edge to edge (%d of %d)" % [tile, y, n, PX])
			else:
				check(n * 2 < PX, "tile %s: row %d is no bed joint (%d of %d)" % [tile, y, n, PX])


func test_no_block_is_cut_at_the_tile_seam() -> void:
	# No head joint within 4 world pixels of the tile's edge, so a block passes
	# through the seam into whichever variant is next.
	var img := _atlas()
	for tile in _fields():
		var joint := _px(img, tile, 16, BEDS[0])
		var heads := 0
		for x in PX:
			# A head joint is a column of the joint colour through the top course.
			var n := 0
			for y in range(1, BEDS[0] - 1):
				if _px(img, tile, x, y).is_equal_approx(joint):
					n += 1
			if n == BEDS[0] - 2:
				heads += 1
				check(x >= 8 and x <= PX - 8, "tile %s: a head joint at x %d is clear of the tile's edge" % [tile, x])
		check(heads >= 1 and heads <= 2, "tile %s: one or two head joints in a course, got %d" % [tile, heads])


func test_the_variants_still_differ() -> void:
	# The joints are keyed to the seed: no two surface tiles share them.
	var img := _atlas()
	var seen := {}
	for tile: Vector2i in TilesetFactory.FULL_VARIANTS:
		var joint := _px(img, tile, 16, BEDS[0])
		var key := ""
		for y: int in [4, 15, 26]:
			for x in PX:
				if _px(img, tile, x, y).is_equal_approx(joint):
					key += "%d," % x
			key += "/"
		check(not seen.has(key), "tile %s has joints of its own (%s)" % [tile, key])
		seen[key] = true
