extends TestSuite
## A wall's tiers meet block by block (design bible 12.99, pass 623): where a
## darker tier touches the tier above, the cell draws a blend, a field tile
## whose blocks stand in one tier or the other, so the shade inside a wall is
## not a stair of rectangles on the tile grid.

const ROOMS := ["sunken/drowned_aqueduct", "boughs/canopy_bridge", "vorrhallow/flooded_hall", "spires/storm_ledge"]
const ZONES := ["gym", "heartwood", "tower", "haar", "boughs", "vorrhallow", "evercrown", "sunken", "trials", "spires"]
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PX := TilesetFactory.TILE * TilesetFactory.DENSITY


func _atlas(zone: String) -> Image:
	var tex: Texture2D = load(TilesetFactory.TILES_DIR + zone + ".png")
	return tex.get_image()


func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## The mean value of an atlas tile.
func _mean(img: Image, coords: Vector2i) -> float:
	var sum := 0.0
	for y in PX:
		for x in PX:
			sum += _lum(img.get_pixel(coords.x * PX + x, coords.y * PX + y))
	return sum / (PX * PX)


func _mean_of(img: Image, tiles: Array[Vector2i]) -> float:
	var sum := 0.0
	for t in tiles:
		sum += _mean(img, t)
	return sum / tiles.size()


## The share of a tile's pixels that differ from `other`'s at the same place.
func _differs(img: Image, a: Vector2i, b: Vector2i) -> float:
	var n := 0
	for y in PX:
		for x in PX:
			if img.get_pixel(a.x * PX + x, a.y * PX + y) != img.get_pixel(b.x * PX + x, b.y * PX + y):
				n += 1
	return float(n) / (PX * PX)


func test_a_darker_cell_beside_a_lighter_tier_draws_a_blend() -> void:
	var full := TilesetFactory.FULL
	for x in 12:
		var cell := Vector2i(x, 5)
		check(TilesetFactory.ground(full, cell, 2, false, true) in TilesetFactory.BLEND_MID, "a mid cell that blends draws a mid blend")
		check(TilesetFactory.ground(full, cell, 3, false, true) in TilesetFactory.BLEND_DEEP, "a deep cell that blends draws a deep blend")
		check(TilesetFactory.ground(full, cell, 2) in TilesetFactory.MID, "a mid cell that does not blend keeps the mid tier")
		check(TilesetFactory.ground(full, cell, 3) in TilesetFactory.DEEP, "a deep cell that does not blend keeps the deep tier")
		check(not TilesetFactory.is_blend(TilesetFactory.ground(full, cell, 1, false, true)), "a surface cell never blends")
	check(not TilesetFactory.is_blend(TilesetFactory.ground(TilesetFactory.EDGE_TOP, Vector2i(3, 3), 2, true, true)), "an edge tile never blends")
	var seen := {}
	for x in 60:
		seen[TilesetFactory.ground(full, Vector2i(x, 9), 2, false, true)] = true
	check(seen.size() == TilesetFactory.BLEND_MID.size(), "the blends scatter by cell, got %d of them" % seen.size())
	check(is_equal_approx(TilesetFactory.tier_of(TilesetFactory.BLEND_MID[0]), 1.5), "a mid blend stands half a tier above the mid")
	check(is_equal_approx(TilesetFactory.tier_of(TilesetFactory.BLEND_DEEP[0]), 2.5), "a deep blend stands half a tier above the deep")


func test_a_blend_stands_between_its_two_tiers() -> void:
	for zone: String in ZONES:
		check(TilesetFactory.has_blends(zone), "%s has blends" % zone)
		var img := _atlas(zone)
		var surface: Array[Vector2i] = [TilesetFactory.ground(TilesetFactory.FULL)]
		surface.append_array(TilesetFactory.FULL_VARIANTS)
		var top := _mean_of(img, surface)
		var mid := _mean_of(img, TilesetFactory.MID)
		var deep := _mean_of(img, TilesetFactory.DEEP)
		for t in TilesetFactory.BLEND_MID:
			var m := _mean(img, t)
			var at := (top - m) / (top - mid)
			check(at > 0.1 and at < 0.9, "%s: a mid blend %s stands between the surface and the mid (%.2f of the way)" % [zone, t, at])
		for t in TilesetFactory.BLEND_DEEP:
			var m := _mean(img, t)
			var at := (mid - m) / (mid - deep)
			check(at > 0.1 and at < 0.9, "%s: a deep blend %s stands between the mid and the deep (%.2f of the way)" % [zone, t, at])
		# The three of a kind are three tiles, not one.
		for pair: Array in [[0, 1], [0, 2], [1, 2]]:
			var share := _differs(img, TilesetFactory.BLEND_MID[pair[0]], TilesetFactory.BLEND_MID[pair[1]])
			check(share > 0.1, "%s: mid blends %d and %d differ (%.2f of their pixels)" % [zone, pair[0], pair[1], share])
	check(not TilesetFactory.has_blends("hearthroot"), "Hearthroot's PixelLab set has no blends")


## The mean value of a part of an atlas tile, `rect` in tile pixels.
func _mean_in(img: Image, coords: Vector2i, rect: Rect2i) -> float:
	var sum := 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			sum += _lum(img.get_pixel(coords.x * PX + x, coords.y * PX + y))
	return sum / (rect.size.x * rect.size.y)


## No half of a blend is one tier: each of its west, east, upper and lower
## halves stands between the two, so a tier never ends on a line the width or
## the height of the tile.
func test_no_half_of_a_blend_is_one_tier() -> void:
	const H := PX / 2
	var halves: Array[Rect2i] = [Rect2i(0, 0, H, PX), Rect2i(H, 0, H, PX), Rect2i(0, 0, PX, H), Rect2i(0, H, PX, H)]
	for zone: String in ZONES:
		var img := _atlas(zone)
		for pair: Array in [[TilesetFactory.BLEND_MID, TilesetFactory.FULL_VARIANTS, TilesetFactory.MID], [TilesetFactory.BLEND_DEEP, TilesetFactory.MID, TilesetFactory.DEEP]]:
			var blends: Array[Vector2i] = pair[0]
			var above: Array[Vector2i] = pair[1]
			var below: Array[Vector2i] = pair[2]
			for t in blends:
				for half in halves:
					var hi := 0.0
					var lo := 0.0
					for a in above:
						hi += _mean_in(img, a, half) / above.size()
					for b in below:
						lo += _mean_in(img, b, half) / below.size()
					var at := (hi - _mean_in(img, t, half)) / (hi - lo)
					check(at > 0.05 and at < 0.95, "%s: the half %s of blend %s holds both tiers (%.2f of the way down)" % [zone, half, t, at])


func test_the_named_rooms_blend_their_tiers() -> void:
	for id: String in ROOMS:
		var room := Room.from_file(World.room_path(id))
		arena.add_child(room)
		var blends := 0
		var hard := 0
		for cell: Vector2i in room.tiles.get_used_cells():
			var coords := room.tiles.get_cell_atlas_coords(cell)
			if TilesetFactory.is_blend(coords):
				blends += 1
				check(not TilesetFactory.is_patch(coords), "a blend is not a patch")
				continue
			var tier := TilesetFactory.tier_of(coords)
			if tier < 2.0:
				continue
			# A cell drawn in a whole darker tier (a field tile or a patch) never
			# stands edge to edge with ground of a lighter tier: a blend does.
			for d in SIDES:
				var n := cell + d
				if room.tiles.get_cell_source_id(n) < 0:
					continue
				var other := room.tiles.get_cell_atlas_coords(n)
				if not TilesetFactory.is_ground(other):
					continue
				if maxf(ceilf(TilesetFactory.tier_of(other)), 1.0) < tier:
					hard += 1
		check(blends >= 10, "%s draws blends, got %d" % [id, blends])
		check(hard == 0, "%s: no tier meets the one above along a tile's edge, got %d such edges" % [id, hard])
