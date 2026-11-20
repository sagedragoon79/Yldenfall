extends TestSuite
## The darker interior tiers (design bible 12.8) settle their specks (12.95,
## pass 618): a tier is drawn only where three cells of it join edge to edge, so
## no lone dark tile sits in a lit field.

const ROOMS := ["vorrhallow/flooded_hall", "spires/storm_ledge", "sunken/drowned_aqueduct"]
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## The tier an atlas tile is painted in (1 to 3).
func _tier_of(coords: Vector2i) -> int:
	if TilesetFactory.DEEP.has(coords):
		return 3
	if TilesetFactory.MID.has(coords):
		return 2
	if TilesetFactory.is_patch(coords):
		return coords.y - TilesetFactory.PATCH_ROW + 1
	return 1


## The sizes of the groups of cells at `tier` or deeper, joined edge to edge.
func _groups(tiers: Dictionary, tier: int) -> Array[int]:
	var sizes: Array[int] = []
	var seen := {}
	for start: Vector2i in tiers:
		if seen.has(start) or int(tiers[start]) < tier:
			continue
		var group: Array[Vector2i] = [start]
		seen[start] = true
		var i := 0
		while i < group.size():
			for d in SIDES:
				var n := group[i] + d
				if not seen.has(n) and int(tiers.get(n, 0)) >= tier:
					seen[n] = true
					group.append(n)
			i += 1
		sizes.append(group.size())
	return sizes


func test_a_speck_takes_the_tier_above() -> void:
	# A 9 by 7 field of the middle tier with a lone deep cell, a pair of deep
	# cells and a bar of three.
	var depths := {}
	for y in 7:
		for x in 9:
			depths[Vector2i(x, y)] = 2
	depths[Vector2i(1, 1)] = 3
	depths[Vector2i(4, 1)] = 3
	depths[Vector2i(5, 1)] = 3
	for x in [2, 3, 4]:
		depths[Vector2i(x, 4)] = 3
	var out := TilesetFactory.settle_tiers(depths)
	check(out[Vector2i(1, 1)] == 2, "a lone deep cell takes the middle tier")
	check(out[Vector2i(4, 1)] == 2 and out[Vector2i(5, 1)] == 2, "a pair of deep cells takes the middle tier")
	for x in [2, 3, 4]:
		check(out[Vector2i(x, 4)] == 3, "three deep cells in a row stay deep")
	check(out[Vector2i(7, 5)] == 2, "the field keeps its tier")
	check(depths[Vector2i(1, 1)] == 3, "the depths handed in are not changed")


func test_what_the_deep_tier_gives_up_joins_the_middle_one() -> void:
	# One deep cell beside two of the middle tier, in a lit field: the three stay
	# together as the middle tier. Two middle cells alone do not.
	var depths := {}
	for y in 5:
		for x in 9:
			depths[Vector2i(x, y)] = 1
	depths[Vector2i(1, 2)] = 2
	depths[Vector2i(2, 2)] = 3
	depths[Vector2i(3, 2)] = 2
	depths[Vector2i(6, 2)] = 2
	depths[Vector2i(7, 2)] = 2
	var out := TilesetFactory.settle_tiers(depths)
	for x in [1, 2, 3]:
		check(out[Vector2i(x, 2)] == 2, "a deep cell that settles joins its middle neighbours")
	check(out[Vector2i(6, 2)] == 1 and out[Vector2i(7, 2)] == 1, "a pair of middle cells takes the surface tier")


func test_no_room_draws_a_speck_of_a_darker_tier() -> void:
	for id: String in ROOMS:
		var room := Room.from_file(World.room_path(id))
		arena.add_child(room)
		var tiers := {}
		var raw := {}
		for cell: Vector2i in room.tiles.get_used_cells():
			var coords := room.tiles.get_cell_atlas_coords(cell)
			if TilesetFactory.is_ground(coords) or TilesetFactory.is_patch(coords):
				tiers[cell] = _tier_of(coords)
				raw[cell] = room._raw_depth(cell)
		var darker := 0
		for cell: Vector2i in tiers:
			darker += int(tiers[cell] >= 2)
			if not check(tiers[cell] <= raw[cell], "%s: no cell is drawn darker than its depth (%s)" % [id, cell]):
				break
		check(darker > 20, "%s still has its darker tiers (%d cells)" % [id, darker])
		for tier in [2, 3]:
			var sizes := _groups(tiers, tier)
			check(not sizes.is_empty(), "%s draws tier %d somewhere" % [id, tier])
			check(sizes.min() >= TilesetFactory.TIER_GROUP, "%s: the smallest group of tier %d is %d cells" % [id, tier, sizes.min()])
		# The room had specks to settle: without the rule this pass would be idle.
		var raw_small := 0
		for tier in [2, 3]:
			for n: int in _groups(raw, tier):
				raw_small += int(n < TilesetFactory.TIER_GROUP)
		print("  %s: %d specks settled" % [id, raw_small])


const PX := TilesetFactory.TILE * TilesetFactory.DENSITY
## The full-solid blob tile: the last of the 47.
const FULL_TILE := Vector2i(6, 5)


## A tile's mean value (0 to 255).
func _value(img: Image, tile: Vector2i) -> float:
	var sum := 0.0
	for y in PX:
		for x in PX:
			sum += img.get_pixel(tile.x * PX + x, tile.y * PX + y).get_luminance()
	return sum * 255.0 / float(PX * PX)


## The share of a tile's upper course (the block the width of the tile) that
## is darker than the same pixels of `body`.
func _upper_darker(img: Image, tile: Vector2i, body: Vector2i) -> float:
	var n := 0
	var total := 0
	for y in range(2, PX / 2 - 3):
		for x in range(2, PX):
			total += 1
			var a := img.get_pixel(tile.x * PX + x, tile.y * PX + y).get_luminance()
			var b := img.get_pixel(body.x * PX + x, body.y * PX + y).get_luminance()
			n += int(a < b - 0.01)
	return float(n) / float(total)


func test_vorrhallows_field_tiles_are_one_value_a_tier() -> void:
	# With four tiles to a tier, a worn block the width of the tile made every
	# fourth tile of a field a dark slab (the Flooded Hall's ceiling). A tier's
	# tiles now stand within a tenth of each other; the DEEP tier ran from 30
	# to 41, and the MID from 53 to 68.
	var img := (load("res://assets/tiles/vorrhallow.png") as Texture2D).get_image()
	var surface: Array[Vector2i] = [FULL_TILE]
	surface.append_array(TilesetFactory.FULL_VARIANTS)
	var limits := {"surface": 0.1, "MID": 0.13, "DEEP": 0.05}
	var tiers := {"surface": surface, "MID": TilesetFactory.MID, "DEEP": TilesetFactory.DEEP}
	for name: String in tiers:
		var values: Array[float] = []
		for tile: Vector2i in tiers[name]:
			values.append(_value(img, tile))
		var spread: float = (values.max() - values.min()) / values.max()
		check(spread < limits[name], "Vorrhallow's %s tiles stand within %.2f of each other, got %.3f (%s)" % [name, limits[name], spread, values])
	# No field tile's upper course is a worn slab: it matches the tier's first tile.
	for name: String in tiers:
		var set: Array = tiers[name]
		for tile: Vector2i in set:
			var share := _upper_darker(img, tile, set[1])
			check(share < 0.3, "the upper course of %s tile %s is not worn, %.2f of it is darker" % [name, tile, share])
