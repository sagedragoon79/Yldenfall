extends TestSuite
## TilesetFactory: the atlas-variant scatter that keeps large solid fields from
## reading as a 32 px grid (design bible 12.8), and the depth tiers it preserves.
## A field is mostly FULL-mask cells, so `ground()` scatters several masonry
## variants across them by cell position; edges (non-FULL masks) stay stable.


## The distinct atlas tiles a block of FULL cells map to at a given depth.
func _field(depth: int) -> Dictionary:
	var seen := {}
	for y in 16:
		for x in 16:
			seen[TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), depth)] = true
	return seen


func test_full_surface_scatters_several_variants() -> void:
	# depth 1 is a field's visible interior: base tile plus the three row-7
	# variants, so a solid wall does not band. (Dropping the scatter fails here.)
	var seen := _field(1)
	check(seen.size() == TilesetFactory.FULL_VARIANTS.size() + 1,
		"a FULL surface field spreads over base + %d variants, got %d distinct tiles"
			% [TilesetFactory.FULL_VARIANTS.size(), seen.size()])


func test_full_surface_uses_base_plus_variants_only() -> void:
	var seen := _field(1)
	var extra: Array[Vector2i] = []
	for coord: Vector2i in seen:
		if not TilesetFactory.FULL_VARIANTS.has(coord):
			extra.append(coord)
	check(extra.size() == 1, "exactly one non-variant tile (the base) is used, got %s" % [extra])
	check(extra[0].y < 7, "the base FULL tile is a blob tile (rows 0-6), not a row-7 variant: %s" % extra[0])


func test_deep_tiers_scatter_within_their_darker_sets() -> void:
	# Two tiles in uses the MID set, three or more the DEEP set, and each still
	# scatters so a thick interior does not band either.
	var mid := _field(2)
	for coord: Vector2i in mid:
		check(TilesetFactory.MID.has(coord), "a depth-2 cell draws a MID tile, got %s" % coord)
	check(mid.size() >= 2, "the MID interior scatters more than one tile, got %d" % mid.size())
	var deep := _field(3)
	for coord: Vector2i in deep:
		check(TilesetFactory.DEEP.has(coord), "a depth-3 cell draws a DEEP tile, got %s" % coord)
	check(deep.size() >= 2, "the DEEP interior scatters more than one tile, got %d" % deep.size())


func test_edges_are_stable_across_cells() -> void:
	# A non-FULL mask (an exposed top face) is the same tile wherever it sits, so
	# the variant scatter never disturbs edge continuity.
	var mask := TilesetFactory.E | TilesetFactory.S | TilesetFactory.W | TilesetFactory.SE | TilesetFactory.SW
	var first := TilesetFactory.ground(mask, Vector2i.ZERO, 1)
	for y in 8:
		for x in 8:
			check(TilesetFactory.ground(mask, Vector2i(x, y), 1) == first, "edge tiles do not vary by cell")


func test_every_variant_tile_exists_in_the_built_atlas() -> void:
	# Guards the atlas-coord contract: every coord ground() can return must be a
	# real tile in the built TileSet, or walls would draw blank. (Removing the
	# FULL_VARIANTS from build(), or the row-7 atlas tiles from tilegen, fails this.)
	for zone in ["gym", "hearthroot"]:  # a painted zone and the pixellab zone
		var ts := TilesetFactory.build(zone, false)
		var src := ts.get_source(TilesetFactory.SOURCE_ID) as TileSetAtlasSource
		var coords: Array[Vector2i] = []
		coords.append_array(TilesetFactory.FULL_VARIANTS)
		coords.append_array(TilesetFactory.MID)
		coords.append_array(TilesetFactory.DEEP)
		for coord in coords:
			check(src.has_tile(coord), "%s atlas has variant tile %s" % [zone, coord])
