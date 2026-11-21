extends TestSuite
## Props are not copies of each other (design bible 12.100, pass 624): no two decor
## pieces near each other are the same picture, and Hearthroot hangs three
## banners that differ in outline, not one.

const ROOMS := ["hearthroot/plaza", "hearthroot/market", "heartwood/root_shrine", "vorrhallow/flooded_hall", "spires/storm_ledge", "haar/lampwick_causeway"]
const ZONES := ["heartwood", "hearthroot", "tower", "haar", "boughs", "spires", "vorrhallow", "evercrown", "trials", "sunken"]
## The banners' columns in Hearthroot's ceiling row (tools/art/decorgen.py).
const BANNERS := [2, 4, 7]
const KINDS := ["floor", "ceiling", "wall", "wall"]


func _meta(zone: String) -> Dictionary:
	return (load(Decor.DIR + zone + ".json") as JSON).data


func _cell(zone: String, row: int, col: int) -> Image:
	var meta := _meta(zone)
	var size := Vector2i(int(meta.cell[0]), int(meta.cell[1])) * int(meta.density)
	var tex: Texture2D = load(Decor.DIR + zone + ".png")
	return tex.get_image().get_region(Rect2i(Vector2i(col, row) * size, size))


## The share of the pixels either cell covers that only one of them covers.
func _outline_differs(a: Image, b: Image) -> float:
	var either := 0
	var one := 0
	for y in a.get_height():
		for x in a.get_width():
			var in_a := a.get_pixel(x, y).a > 0.5
			var in_b := b.get_pixel(x, y).a > 0.5
			if in_a or in_b:
				either += 1
				if in_a != in_b:
					one += 1
	return float(one) / maxi(1, either)


## The colour most of a cell is painted in (its cloth, not its outline or trim).
func _main_colour(img: Image) -> Color:
	var counts := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				counts[c] = counts.get(c, 0) + 1
	var best := Color.BLACK
	for c: Color in counts:
		if counts[c] > counts.get(best, 0):
			best = c
	return best


func test_no_two_neighbouring_pieces_are_the_same_picture() -> void:
	for id: String in ROOMS:
		var room := Room.from_file(World.room_path(id))
		arena.add_child(room)
		var decor := room.get_node("Decor") as Decor
		var meta := _meta(room.zone)
		var by_cell := {}
		for piece: Array in decor.pieces:
			by_cell[[KINDS[piece[0]], piece[2]]] = piece[1]
		var copies := 0
		var could := 0
		for piece: Array in decor.pieces:
			var kind: String = KINDS[piece[0]]
			if (meta[kind] as Array).size() <= Decor.NO_REPEAT.x:
				continue  # too few pictures to tell every neighbour apart
			could += 1
			var cell: Vector2i = piece[2]
			for dy in range(-Decor.NO_REPEAT.y, Decor.NO_REPEAT.y + 1):
				for dx in range(-Decor.NO_REPEAT.x, Decor.NO_REPEAT.x + 1):
					if (dx != 0 or dy != 0) and by_cell.get([kind, cell + Vector2i(dx, dy)], -1) == piece[1]:
						copies += 1
		check(copies == 0, "%s: no piece repeats a neighbour of its kind (%d of %d do)" % [id, copies, could])
		check(decor.pieces.size() > 6, "%s is dressed (%d pieces)" % [id, decor.pieces.size()])
		room.queue_free()
		await frames(1)


func test_a_piece_takes_the_next_picture_its_neighbours_lack() -> void:
	var decor := Decor.new()
	arena.add_child(decor)
	check(decor._unlike_neighbours("ceiling", 2, 4, Vector2i(10, 3)) == 2, "the first piece keeps its picture")
	check(decor._unlike_neighbours("ceiling", 2, 4, Vector2i(12, 3)) == 3, "a neighbour with the same roll takes the next one")
	check(decor._unlike_neighbours("ceiling", 2, 4, Vector2i(14, 4)) == 0, "and the one after takes the one after that")
	check(decor._unlike_neighbours("floor", 2, 4, Vector2i(12, 3)) == 2, "another kind of piece is not a neighbour")
	check(decor._unlike_neighbours("ceiling", 2, 4, Vector2i(10 + Decor.NO_REPEAT.x + 1, 3 - Decor.NO_REPEAT.y - 1)) == 2, "nor is a piece out of reach")
	check(decor._unlike_neighbours("wall", 0, 1, Vector2i(1, 1)) == 0 and decor._unlike_neighbours("wall", 0, 1, Vector2i(1, 2)) == 0, "a kind with one picture repeats it")
	decor.queue_free()


func test_hearthroot_hangs_three_banners() -> void:
	check((_meta("hearthroot").ceiling as Array).size() == 8, "Hearthroot's ceiling row holds eight pieces")
	var cells: Array[Image] = []
	for col: int in BANNERS:
		cells.append(_cell("hearthroot", 1, col))
	var cloths: Array[Color] = []
	for img in cells:
		cloths.append(_main_colour(img))
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var d := _outline_differs(cells[i], cells[j])
			check(d > 0.3, "banners %d and %d differ in outline (%.2f of their pixels)" % [i, j, d])
			check(cloths[i] != cloths[j], "and in the colour of their cloth (%s and %s)" % [cloths[i].to_html(false), cloths[j].to_html(false)])


func test_no_atlas_row_holds_the_same_picture_twice() -> void:
	for zone: String in ZONES:
		var meta := _meta(zone)
		for row in 3:
			var count: int = (meta[KINDS[row]] as Array).size()
			for i in count:
				for j in range(i + 1, count):
					var a := _cell(zone, row, i)
					var b := _cell(zone, row, j)
					check(a.get_data() != b.get_data(), "%s %s: pieces %d and %d are different pictures" % [zone, KINDS[row], i, j])
