extends TestSuite
## Brick fields with structure (design bible 12.46, pass 556). The Spires' ashlar
## and the brick of the Inner Rings and the gym share one body value with the odd
## worn stone (the rule of 12.45), the Spires' gold inlay stays on the surface
## tiles, and a masonry floor carries a string course under its cap.

const PX := 32  # one tile in the atlas (TILE * DENSITY)
## The string course's rows in atlas pixels (tilegen COURSE_TOP and COURSE_ROWS at density 2).
const COURSE_LIT := 14
const COURSE_SHADOW := 18


func _atlas(zone: String) -> Image:
	var tex := load(TilesetFactory.TILES_DIR + zone + ".png") as Texture2D
	return tex.get_image()


## The share of a tier's pixels that carry its most common colour.
func _body_share(img: Image, tier: Array) -> float:
	var count := {}
	var total := 0
	for tile: Vector2i in tier:
		for y in PX:
			for x in PX:
				var key := img.get_pixel(tile.x * PX + x, tile.y * PX + y).to_rgba32()
				count[key] = int(count.get(key, 0)) + 1
				total += 1
	var best := 0
	for key: int in count:
		best = maxi(best, count[key])
	return float(best) / float(total)


## Gold pixels in a tier: red well above blue, as no stone is.
func _gold(img: Image, tier: Array) -> int:
	var n := 0
	for tile: Vector2i in tier:
		for y in PX:
			for x in PX:
				var c := img.get_pixel(tile.x * PX + x, tile.y * PX + y)
				if c.r > c.b * 1.3 and c.r > 0.24:
					n += 1
	return n


func test_the_spires_ashlar_shares_one_body_value() -> void:
	# A coin toss between two values gave each about a third of the pixels, and
	# the darkened deep tiers read as a checkerboard. One body value takes over
	# half of every tier.
	var img := _atlas("spires")
	for tier: Array in [TilesetFactory.FULL_VARIANTS, TilesetFactory.MID, TilesetFactory.DEEP]:
		var share := _body_share(img, tier)
		check(share > 0.48, "the Spires' body value takes about half of a tier, got %.3f" % share)
		check(share < 0.7, "and the tier still has courses, pits and worn blocks, got %.3f" % share)


func test_the_bricks_share_one_body_value() -> void:
	for zone in ["trials", "gym"]:
		var img := _atlas(zone)
		for tier: Array in [TilesetFactory.FULL_VARIANTS, TilesetFactory.MID, TilesetFactory.DEEP]:
			var share := _body_share(img, tier)
			check(share > 0.34, "%s: the brick's body value leads its tier, got %.3f" % [zone, share])


func test_the_gold_inlay_stays_on_the_surface() -> void:
	# Darkened two steps, the inlay was orange dashes on near-black: the loudest
	# thing in a wall's depth. It is surface dressing.
	var img := _atlas("spires")
	check(_gold(img, TilesetFactory.FULL_VARIANTS) > 10, "the surface variants keep some gold inlay")
	check(_gold(img, TilesetFactory.MID) == 0, "the mid tier has no gold, got %d" % _gold(img, TilesetFactory.MID))
	check(_gold(img, TilesetFactory.DEEP) == 0, "the deep tier has no gold, got %d" % _gold(img, TilesetFactory.DEEP))


func test_a_masonry_floor_has_a_string_course() -> void:
	# A floor tile open above and solid on both sides: the course runs its whole
	# width as one lit line over a shadow line, so it joins across a floor.
	var top := TilesetFactory.FULL & ~(TilesetFactory.N | TilesetFactory.NE | TilesetFactory.NW)
	for zone in ["spires", "trials", "gym"]:
		var img := _atlas(zone)
		var tile := TilesetFactory.ground(top)
		var lit := img.get_pixel(tile.x * PX, tile.y * PX + COURSE_LIT)
		var shadow := img.get_pixel(tile.x * PX, tile.y * PX + COURSE_SHADOW)
		var straight := true
		for x in PX:
			for k in 2:
				if not img.get_pixel(tile.x * PX + x, tile.y * PX + COURSE_LIT + k).is_equal_approx(lit):
					straight = false
				if not img.get_pixel(tile.x * PX + x, tile.y * PX + COURSE_SHADOW + k).is_equal_approx(shadow):
					straight = false
		check(straight, "%s: the string course is one lit line and one shadow line across the tile" % zone)
		check(lit.get_luminance() > shadow.get_luminance() + 0.2,
			"%s: the lit line stands well over the shadow line (%.2f against %.2f)" % [zone, lit.get_luminance(), shadow.get_luminance()])
		# The full tile under it has no course: it is a coping, not a stripe in every tile.
		var full: Vector2i = TilesetFactory.FULL_VARIANTS[0]
		var plain := false
		for x in PX:
			if not img.get_pixel(full.x * PX + x, full.y * PX + COURSE_LIT).is_equal_approx(lit):
				plain = true
		check(plain, "%s: a tile inside the wall carries no string course" % zone)
