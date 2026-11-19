extends TestSuite
## BouncePod's art (pass 610, bible 12.87): the pod is a pixel-drawn ripe gourd
## in green sepals, not the flat green block of rectangles it was.


## Every tone the pod uses is a master palette value, and it uses them all.
func test_pod_tones_are_master_palette() -> void:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	for tone: Color in BouncePod.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
	var used := {}
	for color: Color in BouncePod.pixels().values():
		used[color.to_html(false)] = true
		check(BouncePod.TONES.has(color), "#%s is one of the pod's tones" % color.to_html(false))
	check(used.size() == BouncePod.TONES.size(), "the art uses every tone (%d of %d)" % [used.size(), BouncePod.TONES.size()])


## The pod is a round bulb, not a block: it narrows to its crown, its corners
## are empty, no flat field of one tone covers it, and it keeps its old size.
func test_the_pod_is_a_round_gourd_not_a_block() -> void:
	var art := BouncePod.pixels()
	var top := 0
	var rows := {}
	for cell: Vector2i in art:
		top = maxi(top, cell.y)
		check(absi(cell.x) <= 21 and cell.y >= 0, "pixel %s stays by the pod" % cell)
		if not rows.has(cell.y):
			rows[cell.y] = [cell.x, cell.x]
		rows[cell.y] = [mini(rows[cell.y][0], cell.x), maxi(rows[cell.y][1], cell.x)]
	# The art is in half-pixels: its body's top is where the catch is, and the outline one above.
	check(top == int(BouncePod.HEIGHT * 2.0) + 1, "the outline tops out one half-pixel over the catch (%d)" % top)
	var widest := 0
	for y: int in rows:
		widest = maxi(widest, rows[y][1] - rows[y][0] + 1)
	var crown: int = rows[top - 1][1] - rows[top - 1][0] + 1
	check(crown * 2 < widest, "the crown (%d) is under half the widest row (%d)" % [crown, widest])
	var steps := {}
	for y in range(10, top):
		steps[rows[y][1] - rows[y][0]] = true
	check(steps.size() >= 5, "the upper half curves in over at least five widths (%d)" % steps.size())
	check(not art.has(Vector2i(-17, top - 2)) and not art.has(Vector2i(16, top - 2)), "the block's upper corners are empty")
	# Shaded as a ball: lit on the upper left, dark on the lower right, and no tone holds half of it.
	var counts := {}
	var bulb := 0
	for cell: Vector2i in art:
		var c: Color = art[cell]
		if BouncePod.RAMP.has(c):
			counts[c] = int(counts.get(c, 0)) + 1
			bulb += 1
	for c: Color in counts:
		check(counts[c] * 2 < bulb, "#%s covers under half the bulb (%d of %d)" % [c.to_html(false), counts[c], bulb])
	check(BouncePod.RAMP.find(art[Vector2i(-8, 16)]) > BouncePod.RAMP.find(art[Vector2i(13, 6)]) + 1, "the upper left is lit and the lower right in shade")
	# Gold in green sepals: the bulb's tones are warm, so it stands out from the leaves.
	for c: Color in BouncePod.RAMP:
		check(c.r > c.b and c.r >= c.g, "#%s is a warm tone, not a leaf green" % c.to_html(false))
	var leaves := 0
	for cell: Vector2i in art:
		if art[cell] in [BouncePod.LEAF, BouncePod.LEAF_LIT, BouncePod.LEAF_TIP, BouncePod.LEAF_DARK]:
			leaves += 1
			check(cell.y <= 9, "sepal pixel %s stays at the pod's foot" % cell)
	check(leaves >= 60 and leaves * 2 < bulb, "the sepals are a collar (%d px), not the pod (%d px)" % [leaves, bulb])


## A pod in a room draws that art and still squashes at a launch.
func test_a_pod_in_a_room_is_the_gourd() -> void:
	var room := Room.from_text("zone: boughs\n---\n########\n#......#\n#......#\n#...@..#\n########")
	arena.add_child(room)
	var pods: Array[Node] = arena.get_tree().get_nodes_in_group("bounce_pod")
	check(pods.size() == 1, "the room grows one pod")
	var pod := pods[0] as BouncePod
	check_near(pod.global_position.y - pod.top_y(), BouncePod.HEIGHT, 0.001, "its top is where it was")
