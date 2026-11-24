extends TestSuite
## Edge variants and a trim of the zone's own material (design bible 12.53, pass
## 565). A floor's top tile, a ceiling's bottom tile and a wall's faces scatter
## over several tiles; every code-painted zone has a lit line over a shadow line
## under its floor's cap, and the same on the underside of a ceiling.

const PX := 32  # one tile in the atlas (TILE * DENSITY)
## The floor trim's rows in atlas pixels (tilegen COURSE_TOP at density 2).
const TRIM_LIT := 14
const TRIM_SHADOW := 18
## The soffit's rows (tilegen SOFFIT_BOTTOM and SOFFIT_ROWS).
const SOFFIT_LIT := 22
const SOFFIT_SHADOW := 26
const PAINTED := ["gym", "heartwood", "tower", "haar", "boughs", "vorrhallow", "evercrown", "sunken", "trials", "spires"]
## The zones that had no string course before this pass.
const GROWN := ["heartwood", "tower", "haar", "boughs", "evercrown"]
const EDGES := [TilesetFactory.EDGE_TOP, TilesetFactory.EDGE_BOTTOM, TilesetFactory.EDGE_WEST, TilesetFactory.EDGE_EAST]


func _atlas(zone: String) -> Image:
	var tex := load(TilesetFactory.TILES_DIR + zone + ".png") as Texture2D
	return tex.get_image()


## The colour of two atlas rows of a tile if they are all one colour, else null.
func _line(img: Image, tile: Vector2i, row: int) -> Variant:
	var first := img.get_pixel(tile.x * PX, tile.y * PX + row)
	for x in PX:
		for k in 2:
			if not img.get_pixel(tile.x * PX + x, tile.y * PX + row + k).is_equal_approx(first):
				return null
	return first


func _same(img: Image, a: Vector2i, b: Vector2i) -> bool:
	for y in PX:
		for x in PX:
			if not img.get_pixel(a.x * PX + x, a.y * PX + y).is_equal_approx(img.get_pixel(b.x * PX + x, b.y * PX + y)):
				return false
	return true


func _tiles_of(mask: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [TilesetFactory.ground(mask)]
	out.append_array(TilesetFactory.edge_variants(TilesetFactory.reduce_mask(mask)))
	return out


func test_a_long_edge_scatters_over_its_variants() -> void:
	for mask: int in EDGES:
		var want := TilesetFactory.edge_variants(mask).size() + 1
		var seen := {}
		var repeats := 0
		for x in 64:
			var here := TilesetFactory.ground(mask, Vector2i(x, 20), 1, true)
			seen[here] = true
			if here == TilesetFactory.ground(mask, Vector2i(x + 1, 20), 1, true):
				repeats += 1
		check(seen.size() == want, "edge %d draws its base tile and every variant, got %d of %d" % [mask, seen.size(), want])
		check(repeats < 64 * (1.0 / want + 0.2), "edge %d: neighbours match about as often as chance, got %d of 64" % [mask, repeats])
		# Without the row (Hearthroot's PixelLab atlas) an edge stays one tile.
		for x in 16:
			check(TilesetFactory.ground(mask, Vector2i(x, 20), 1) == TilesetFactory.ground(mask), "edge %d does not vary without edge variants" % mask)
	# A corner has no variants: only the four straight edges do.
	var corner := TilesetFactory.FULL & ~(TilesetFactory.N | TilesetFactory.NE | TilesetFactory.NW | TilesetFactory.W | TilesetFactory.SW)
	for x in 16:
		check(TilesetFactory.ground(corner, Vector2i(x, 3), 1, true) == TilesetFactory.ground(corner), "a corner tile does not vary")


func test_every_painted_zone_has_the_variants_and_hearthroot_has_none() -> void:
	for zone: String in PAINTED:
		check(TilesetFactory.has_edges(zone), "%s: the atlas carries the edge variants" % zone)
		var src := TilesetFactory.build(zone, false).get_source(TilesetFactory.SOURCE_ID) as TileSetAtlasSource
		var img := _atlas(zone)
		for mask: int in EDGES:
			var tiles := _tiles_of(mask)
			for tile in tiles:
				check(src.has_tile(tile), "%s: the tile set has edge tile %s" % [zone, tile])
			if mask == TilesetFactory.EDGE_TOP or mask == TilesetFactory.EDGE_BOTTOM:
				var differ := 0
				for i in range(1, tiles.size()):
					if not _same(img, tiles[0], tiles[i]):
						differ += 1
				check(differ >= 2, "%s: edge %d's variants are not copies of its base tile (%d differ)" % [zone, mask, differ])
	check(not TilesetFactory.has_edges("hearthroot"), "Hearthroot's PixelLab atlas has no edge variants")
	var town := TilesetFactory.build("hearthroot", false).get_source(TilesetFactory.SOURCE_ID) as TileSetAtlasSource
	check(not town.has_tile(TilesetFactory.TOP_VARIANTS[0]), "Hearthroot's tile set makes no tile where its atlas has none")


func test_a_room_lays_the_variants_along_a_floor_and_a_ceiling() -> void:
	var rows := grid_rows(40, 23)
	for x in range(2, 38):
		for y in 4:
			put_tiles(rows, x, y, "#")
	put_tiles(rows, 3, 19, "P")
	var room := Room.from_text(room_text(["name: T", "zone: heartwood"], rows), "t/edges")
	arena.add_child(room)
	var floor_seen := {}
	var ceiling_seen := {}
	for x in range(4, 36):
		floor_seen[room.tiles.get_cell_atlas_coords(Vector2i(x, 20))] = true
		ceiling_seen[room.tiles.get_cell_atlas_coords(Vector2i(x, 3))] = true
	check(floor_seen.size() == 4, "the floor's top row uses its base tile and three variants, got %s" % [floor_seen.keys()])
	check(ceiling_seen.size() == 4, "the ceiling's bottom row uses its base tile and three variants, got %s" % [ceiling_seen.keys()])
	for coords: Vector2i in floor_seen:
		check(coords == TilesetFactory.ground(TilesetFactory.EDGE_TOP) or coords in TilesetFactory.TOP_VARIANTS, "a floor cell draws a top tile (%s)" % coords)
	for coords: Vector2i in ceiling_seen:
		check(coords == TilesetFactory.ground(TilesetFactory.EDGE_BOTTOM) or coords in TilesetFactory.BOTTOM_VARIANTS, "a ceiling cell draws a bottom tile (%s)" % coords)
	check(room.is_solid_at(Vector2(20.5, 20.5) * Room.TILE), "a variant floor tile is solid")


func test_every_zone_has_a_trim_under_its_floors_cap() -> void:
	# One lit line over one shadow line, the same in the base tile and in every
	# variant, so the trim joins along a floor whichever tile a cell draws.
	for zone: String in PAINTED:
		var img := _atlas(zone)
		var tiles := _tiles_of(TilesetFactory.EDGE_TOP)
		var lit: Variant = _line(img, tiles[0], TRIM_LIT)
		var shadow: Variant = _line(img, tiles[0], TRIM_SHADOW)
		check(lit != null and shadow != null, "%s: the floor's trim is one lit line and one shadow line" % zone)
		if lit == null or shadow == null:
			continue
		check((lit as Color).get_luminance() > (shadow as Color).get_luminance() + 0.1,
			"%s: the lit line stands over the shadow line (%.2f against %.2f)" % [zone, (lit as Color).get_luminance(), (shadow as Color).get_luminance()])
		for tile in tiles:
			check(_line(img, tile, TRIM_LIT) == lit and _line(img, tile, TRIM_SHADOW) == shadow, "%s: variant %s carries the same trim" % [zone, tile])
		# Inside the wall there is none: it is a trim, not a stripe in every tile.
		check(_line(img, TilesetFactory.FULL_VARIANTS[0], TRIM_LIT) != lit, "%s: a tile inside the wall has no trim" % zone)


func test_a_ceiling_has_a_soffit_and_a_thin_ledge_has_none() -> void:
	var ledge := TilesetFactory.E | TilesetFactory.W
	for zone: String in PAINTED:
		var img := _atlas(zone)
		var tiles := _tiles_of(TilesetFactory.EDGE_BOTTOM)
		var lit: Variant = _line(img, tiles[0], SOFFIT_LIT)
		var shadow: Variant = _line(img, tiles[0], SOFFIT_SHADOW)
		check(lit != null and shadow != null, "%s: the soffit is one lit line and one shadow line" % zone)
		if lit == null or shadow == null:
			continue
		check((lit as Color).get_luminance() > (shadow as Color).get_luminance() + 0.05, "%s: the soffit's lit line stands over its shadow" % zone)
		for tile in tiles:
			check(_line(img, tile, SOFFIT_LIT) == lit and _line(img, tile, SOFFIT_SHADOW) == shadow, "%s: variant %s carries the same soffit" % [zone, tile])
		# The soffit is in the shade: dimmer than the floor's trim.
		var floor_lit: Variant = _line(img, TilesetFactory.ground(TilesetFactory.EDGE_TOP), TRIM_LIT)
		if floor_lit != null:
			check((lit as Color).get_luminance() < (floor_lit as Color).get_luminance(), "%s: the soffit is dimmer than the floor's trim" % zone)
		# A ledge one tile thick already has a cap and a trim: no soffit as well.
		var thin := TilesetFactory.ground(ledge)
		check(_line(img, thin, SOFFIT_LIT) != lit or _line(img, thin, SOFFIT_SHADOW) != shadow, "%s: a ledge one tile thick has no soffit" % zone)


func test_each_grown_zone_trims_in_its_own_material() -> void:
	# The Tower's flange has rivets, the wood's rind has notches where its grain meets it,
	# the Evercrown's skin is pinched: the band between the two lines is not one
	# flat colour, and no two materials share a lit line.
	var lits := {}
	for zone: String in GROWN:
		var img := _atlas(zone)
		var tile := TilesetFactory.ground(TilesetFactory.EDGE_TOP)
		check(_line(img, tile, TRIM_LIT + 2) == null, "%s: the trim's band is broken by its material's marks" % zone)
		lits[zone] = img.get_pixel(tile.x * PX, tile.y * PX + TRIM_LIT)
	check(lits["tower"] != lits["heartwood"] and lits["heartwood"] != lits["evercrown"] and lits["tower"] != lits["evercrown"],
		"iron, bark and the Evercrown's cells each trim in their own colour")
	# A wall on a grown floor stands on a footing, as on masonry (12.47).
	for zone: String in GROWN:
		var img := _atlas(zone)
		var foot := TilesetFactory.ground(TilesetFactory.FULL & ~TilesetFactory.NW)
		var top := TilesetFactory.ground(TilesetFactory.EDGE_TOP)
		check(img.get_pixel(foot.x * PX + PX / 2, foot.y * PX + TRIM_LIT).is_equal_approx(img.get_pixel(top.x * PX, top.y * PX + TRIM_LIT)),
			"%s: the trim carries on under a wall's foot" % zone)
