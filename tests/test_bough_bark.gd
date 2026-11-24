extends TestSuite
## The High Boughs' bark (design bible 12.92, pass 615): a bough's terrain is
## plates of one body value between dark furrows that fork and join, where it
## was the Heartwood's two-value strands ("flat vertical brown stripes", the
## pass 610 grade).

const PX := TilesetFactory.TILE * TilesetFactory.DENSITY
## The surface field's tiles: the full tile and its three variants.
const FIELD: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)]


func _atlas(zone: String) -> Image:
	return (load(TilesetFactory.TILES_DIR + zone + ".png") as Texture2D).get_image()


func _tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = [TilesetFactory.ground(TilesetFactory.FULL)]
	out.append_array(FIELD)
	return out


## The commonest color of a tile and the share of the tile it fills.
func _body(img: Image, tile: Vector2i) -> Array:
	var seen := {}
	for y in PX:
		for x in PX:
			var c := img.get_pixel(tile.x * PX + x, tile.y * PX + y)
			seen[c] = seen.get(c, 0) + 1
	var best := Color.BLACK
	for c: Color in seen:
		if seen[c] > seen.get(best, 0):
			best = c
	return [best, float(seen[best]) / float(PX * PX)]


## The longest run down one column of pixels darker than the body, with the
## tile stacked on itself (a furrow may cross the seam).
func _longest_dark_run(img: Image, tile: Vector2i, body: Color) -> int:
	var best := 0
	for x in PX:
		var run := 0
		for k in 2 * PX:
			var c := img.get_pixel(tile.x * PX + x, tile.y * PX + k % PX)
			if c.get_luminance() < body.get_luminance() - 0.02:
				run += 1
				best = maxi(best, run)
			else:
				run = 0
	return best


func test_a_bough_is_one_body_value() -> void:
	var img := _atlas("boughs")
	for tile in _tiles():
		var body := _body(img, tile)
		check(body[1] > 0.7, "tile %s: one value fills the plates, got %.2f" % [tile, body[1]])
	# The Heartwood is its own wood (12.126): a body value under a dense grain,
	# not the boughs' plates.
	var wood := _body(_atlas("heartwood"), FIELD[0])
	check(wood[1] < 0.7, "the Heartwood's grain covers more of it than the boughs' furrows (%.2f)" % wood[1])


func test_no_furrow_is_a_stripe() -> void:
	var img := _atlas("boughs")
	for tile in _tiles():
		var body: Color = _body(img, tile)[0]
		var run := _longest_dark_run(img, tile, body)
		check(run > 3 and run <= 2 * PX / 3, "tile %s: the longest straight furrow is %d px (a stripe is %d or more)" % [tile, run, PX])
	# The Heartwood's strands ran the height of every tile; since pass 650 its
	# grain ends too (12.126).
	var wood := _atlas("heartwood")
	check(_longest_dark_run(wood, FIELD[0], _body(wood, FIELD[0])[0]) < PX, "no grain streak runs the whole Heartwood tile")


func test_the_plates_are_the_same_in_every_tile() -> void:
	# One layout, so a plate runs on across a seam whichever variant is next to
	# it; the variants differ only in the marks on the plates.
	var img := _atlas("boughs")
	var tiles := _tiles()
	var first := tiles[0]
	var body: Color = _body(img, first)[0]
	for tile: Vector2i in tiles.slice(1):
		var same := 0
		var edge_same := true
		for y in PX:
			for x in PX:
				var a := img.get_pixel(first.x * PX + x, first.y * PX + y)
				var b := img.get_pixel(tile.x * PX + x, tile.y * PX + y)
				if a.is_equal_approx(b):
					same += 1
				elif x == 0 or y == 0 or x == PX - 1 or y == PX - 1:
					# At the seam only a lit edge may differ, never a furrow.
					if a.get_luminance() < body.get_luminance() - 0.02 or b.get_luminance() < body.get_luminance() - 0.02:
						edge_same = false
		check(same > PX * PX * 85 / 100 and same < PX * PX, "tile %s shares the layout and differs in its marks (%d of %d)" % [tile, same, PX * PX])
		check(edge_same, "tile %s: the furrows meet the seam where the first tile's do" % tile)
	# The darker tiers are the same bark, a shade and two shades down.
	for tier: Array in [TilesetFactory.MID, TilesetFactory.DEEP]:
		var deep := _body(img, tier[0])
		check(deep[1] > 0.7 and (deep[0] as Color).get_luminance() < body.get_luminance(), "a darker tier is plates too")


func test_the_canopy_bridge_is_built_of_it() -> void:
	var room := Room.from_file(World.room_path("boughs/canopy_bridge"))
	arena.add_child(room)
	var field := 0
	for cell: Vector2i in room.tiles.get_used_cells():
		if _tiles().has(room.tiles.get_cell_atlas_coords(cell)):
			field += 1
	check(field > 20, "the canopy bridge's walls are the bark field (%d cells)" % field)
	room.queue_free()
	var note := FileAccess.get_file_as_string("res://docs/design-bible.md").get_slice("### 12.92 ", 1).get_slice("\n### ", 0)
	check(note.contains("`tests/test_bough_bark.gd`"), "12.92 names the test")
