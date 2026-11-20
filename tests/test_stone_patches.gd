extends TestSuite
## Patches of other stone (design bible 12.91, pass 614): inside a wall of the
## Flooded Hall's, the storm ledge's and the aqueduct's zones, stretches a few
## tiles tall and several wide are laid in courses of another height, so a long
## field is not one coursing from end to end.

const PX := TilesetFactory.TILE * TilesetFactory.DENSITY
const ZONES := ["vorrhallow", "spires", "sunken"]
## Bed joints (rows of one color the width of the tile) in a patch tile.
const BED_ROWS := {"vorrhallow": 4, "spires": 2, "sunken": 6}
const ROOMS := ["vorrhallow/flooded_hall", "spires/storm_ledge", "sunken/drowned_aqueduct"]


func _atlas(zone: String) -> Image:
	return (load("res://assets/tiles/%s.png" % zone) as Texture2D).get_image()


## The rows of a tile that are one color from edge to edge.
func _flat_rows(img: Image, tile: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for y in PX:
		var first := img.get_pixel(tile.x * PX, tile.y * PX + y)
		var flat := true
		for x in range(1, PX):
			if img.get_pixel(tile.x * PX + x, tile.y * PX + y) != first:
				flat = false
				break
		if flat:
			out.append(y)
	return out


func _value(img: Image, tile: Vector2i) -> float:
	var sum := 0.0
	for y in PX:
		for x in PX:
			sum += img.get_pixel(tile.x * PX + x, tile.y * PX + y).get_luminance()
	return sum / (PX * PX)


func test_the_noise_lays_wide_low_patches() -> void:
	var inside := 0
	var runs := 0
	var columns := 0
	for y in 60:
		for x in 200:
			if not TilesetFactory.in_patch(Vector2i(x, y)):
				continue
			inside += 1
			if not TilesetFactory.in_patch(Vector2i(x - 1, y)):
				runs += 1
			if not TilesetFactory.in_patch(Vector2i(x, y - 1)):
				columns += 1
	var share := inside / 12000.0
	check(share > 0.15 and share < 0.4, "between 15 and 40 percent of a field is patch, got %.2f" % share)
	var wide := float(inside) / maxi(runs, 1)
	var tall := float(inside) / maxi(columns, 1)
	check(wide >= 4.0, "a patch runs four tiles or more along a course, got %.1f" % wide)
	check(wide > 1.5 * tall, "and is wider than it is tall (%.1f against %.1f)" % [wide, tall])
	# Off the room's west edge the noise runs on without a seam at zero.
	var steps := 0
	for y in 60:
		if TilesetFactory.in_patch(Vector2i(-1, y)) != TilesetFactory.in_patch(Vector2i(0, y)):
			steps += 1
	check(steps < 12, "the noise has no seam at the room's edge (%d of 60 rows change there)" % steps)


func test_a_patch_tile_is_its_tier_and_its_ends() -> void:
	var seen := {}
	for depth in [1, 2, 3]:
		for x in 40:
			var cell := Vector2i(x, 4)
			var plain := TilesetFactory.patch(cell, depth)
			check(plain.y == TilesetFactory.PATCH_ROW + depth - 1, "depth %d draws its own row" % depth)
			check(plain.x % 4 == 0, "a tile inside a patch has no end joint")
			check(TilesetFactory.patch(cell, depth, true).x == plain.x + 1, "a west end is the next tile")
			check(TilesetFactory.patch(cell, depth, false, true).x == plain.x + 2, "an east end the one after")
			check(TilesetFactory.patch(cell, depth, true, true).x == plain.x + 3, "and both the last")
			check(TilesetFactory.is_patch(plain) and TilesetFactory.is_ground(plain), "a patch tile is ground")
			seen[plain.x] = true
	check(seen.size() == TilesetFactory.PATCH_VARIANTS, "a patch scatters its %d variants" % TilesetFactory.PATCH_VARIANTS)
	check(TilesetFactory.patch(Vector2i.ZERO, 7).y == TilesetFactory.PATCH_ROWS - 1, "deeper than three tiles is the deep tier")
	check(not TilesetFactory.is_patch(TilesetFactory.FULL_VARIANTS[0]) and not TilesetFactory.is_patch(TilesetFactory.HAUNCH_WEST), "no other tile is a patch")


func test_three_zones_carry_a_second_coursing() -> void:
	for zone: String in ZONES:
		if not check(TilesetFactory.has_patches(zone), "%s's atlas has the patch rows" % zone):
			continue
		var img := _atlas(zone)
		var usual := _flat_rows(img, TilesetFactory.MID[0]).size()
		for v in TilesetFactory.PATCH_VARIANTS:
			var plain := Vector2i(v * 4, TilesetFactory.PATCH_ROW)
			var beds := _flat_rows(img, plain)
			check(beds.size() == BED_ROWS[zone], "%s: a patch tile has %d rows of bed joint, got %d" % [zone, BED_ROWS[zone], beds.size()])
			check(beds.size() != usual, "%s: which is not the zone's usual coursing (%d)" % [zone, usual])
			check(beds.has(PX - 1), "%s: a patch tile ends on a bed joint, so it sits on any tile" % zone)
			var joint := img.get_pixel(plain.x * PX, plain.y * PX + PX - 1)
			# The ends: a head joint the height of the tile at that edge, and only there.
			for ends in 4:
				var tile := plain + Vector2i(ends, 0)
				var west := true
				var east := true
				for y in PX:
					west = west and img.get_pixel(tile.x * PX, tile.y * PX + y) == joint
					east = east and img.get_pixel(tile.x * PX + PX - 1, tile.y * PX + y) == joint
				check(west == bool(ends & 1), "%s: tile %d %s a joint down its west edge" % [zone, ends, "has" if ends & 1 else "has not"])
				check(east == bool(ends & 2), "%s: tile %d %s a joint down its east edge" % [zone, ends, "has" if ends & 2 else "has not"])
			# The tiers darken as the zone's own do.
			var surface := _value(img, plain)
			var mid := _value(img, plain + Vector2i(0, 1))
			var deep := _value(img, plain + Vector2i(0, 2))
			check(mid < surface and deep < mid, "%s: the patch darkens with depth (%.3f, %.3f, %.3f)" % [zone, surface, mid, deep])
			# One body value: a patch is other coursing, not another shade.
			var body := _value(img, TilesetFactory.FULL_VARIANTS[0])
			check(absf(surface - body) < 0.06, "%s: a patch is as light as the wall round it (%.3f against %.3f)" % [zone, surface, body])
	for zone: String in ["gym", "hearthroot", "tower", "heartwood"]:
		check(not TilesetFactory.has_patches(zone), "%s has no patches" % zone)
	var ts := TilesetFactory.build("sunken")
	var src := ts.get_source(TilesetFactory.SOURCE_ID) as TileSetAtlasSource
	var tile := Vector2i(3, TilesetFactory.PATCH_ROW + 1)
	check(src.has_tile(tile) and src.get_tile_data(tile, 0).get_collision_polygons_count(0) == 1, "a patch tile is solid")


func test_the_named_rooms_show_their_patches() -> void:
	for id: String in ROOMS:
		var room := Room.from_file(World.room_path(id))
		arena.add_child(room)
		var patch := 0
		var usual := 0
		var wrong := 0
		for cell: Vector2i in room.tiles.get_used_cells():
			var coords := room.tiles.get_cell_atlas_coords(cell)
			if not TilesetFactory.is_patch(coords):
				if TilesetFactory.is_ground(coords) and room._ground_mask(cell) == TilesetFactory.FULL:
					usual += 1
				continue
			patch += 1
			var west := room.tiles.get_cell_atlas_coords(cell + Vector2i.LEFT)
			var east := room.tiles.get_cell_atlas_coords(cell + Vector2i.RIGHT)
			var west_open := cell.x > 0 and not TilesetFactory.is_patch(west)
			var east_open := cell.x < room.size_tiles.x - 1 and not TilesetFactory.is_patch(east)
			if room._ground_mask(cell) != TilesetFactory.FULL:
				wrong += 1
			if cell.x > 0 and bool(coords.x & 1) != west_open:
				wrong += 1
			if cell.x < room.size_tiles.x - 1 and bool(coords.x & 2) != east_open:
				wrong += 1
		check(patch >= 8, "%s: some of its wall is patch (%d cells)" % [id, patch])
		check(usual > patch, "%s: and most is the zone's usual stone (%d against %d)" % [id, usual, patch])
		check(wrong == 0, "%s: a patch lies inside the wall and closes its blocks where it ends (%d wrong)" % [id, wrong])
		room.queue_free()
	var gym := make_room(["####################", "####################", "####################", "####################", "####################", "....................", "####################"])
	for cell: Vector2i in gym.tiles.get_used_cells():
		if not check(not TilesetFactory.is_patch(gym.tiles.get_cell_atlas_coords(cell)), "a zone without patch rows draws none"):
			break
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("### 12.91 ", 1).get_slice("\n### ", 0)
	check(note.contains("`tests/test_stone_patches.gd`"), "12.91 names the test")
