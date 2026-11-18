extends TestSuite
## StoneKeel: what a floating stone hangs from (design bible 12.82, pass 597).
## The pass 595 grade read the Spires' bridge stones as "floating brick blocks";
## each floating mass now hangs on a keel of the rock it tore free with.

const T := StoneKeel.TILE


## A closed box of `size` (walls on every edge).
func _box(size: Vector2i) -> Dictionary:
	var solid := {}
	for x in size.x:
		solid[Vector2i(x, 0)] = true
		solid[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		solid[Vector2i(0, y)] = true
		solid[Vector2i(size.x - 1, y)] = true
	return solid


func _block(solid: Dictionary, from: Vector2i, to: Vector2i) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			solid[Vector2i(x, y)] = true


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func test_keel_every_tone_is_in_the_palette() -> void:
	var palette := _palette()
	for t: String in StoneKeel.ROCK + [StoneKeel.LINE]:
		check(palette.has(t), "%s is a palette value" % t)


func test_keel_only_a_floating_mass_gets_one() -> void:
	var size := Vector2i(20, 14)
	var solid := _box(size)
	_block(solid, Vector2i(5, 5), Vector2i(8, 6))  # floats
	_block(solid, Vector2i(1, 8), Vector2i(3, 9))  # a ledge on the left wall
	_block(solid, Vector2i(13, 1), Vector2i(16, 3))  # a mass hung from the ceiling: held, not floating
	for x in range(13, 17):
		solid.erase(Vector2i(x, size.y - 1))  # over a pit, so nothing else shares its columns
	var keels := StoneKeel.plan(solid, solid, size, 7)
	check(keels.size() == 1, "one keel, under the floating block: %d" % keels.size())
	if keels.is_empty():
		return
	var k: Dictionary = keels[0]
	check(k.left == 5 and k.right == 8, "under columns 5 to 8: %s..%s" % [k.left, k.right])
	check(is_equal_approx(k.origin.y, 7.0 * T), "it hangs from the block's underside: %s" % k.origin)
	check(k.depth >= StoneKeel.DEPTH_MIN, "it hangs at least DEPTH_MIN deep: %s" % k.depth)
	check(k.depth <= StoneKeel.DEPTH_MAX, "and no deeper than DEPTH_MAX: %s" % k.depth)
	var tones := {}
	for p: Vector2i in k.pixels:
		tones[k.pixels[p]] = true
	check(tones.has(StoneKeel.LINE), "it is outlined")
	check(tones.size() >= 4, "it is shaded in several tones, not one flat fill: %s" % [tones.keys()])
	check(not k.pebbles.is_empty(), "loose pebbles drift under it")


func test_keel_stops_above_what_is_below() -> void:
	var size := Vector2i(20, 14)
	var solid := _box(size)
	_block(solid, Vector2i(5, 5), Vector2i(10, 6))
	var blocked := solid.duplicate()
	blocked[Vector2i(7, 8)] = true  # a plank one row under the block's middle
	var keels := StoneKeel.plan(solid, blocked, size, 3)
	check(keels.size() == 1, "one keel")
	if keels.is_empty():
		return
	var k: Dictionary = keels[0]
	var limit := 8.0 * T - StoneKeel.CLEAR
	for p: Vector2i in k.pixels:
		var world: Vector2 = k.origin + Vector2(p)
		if int(world.x) / T == 7:
			check(world.y < limit, "over the plank the keel ends CLEAR px above it: %s" % world)


func test_keel_only_the_floating_zones_take_one() -> void:
	var text := "zone: %s
---
############
#..........#
#..........#
#...###....#
#..........#
#..........#
#..........#
#..........#
############"
	var spires := Room.from_text(text % "spires")
	arena.add_child(spires)
	var keel := spires.get_node_or_null("StoneKeel") as StoneKeel
	check(keel != null and keel.keels.size() == 1, "a Spires room hangs its floating stone on a keel")
	if keel:
		check(keel.z_index < 0, "drawn behind the tiles")
	var tower := Room.from_text(text % "tower")
	arena.add_child(tower)
	check(tower.get_node_or_null("StoneKeel") == null, "a Tower room has no keels")


## In every room of the floating zones, no keel pixel or pebble lies in a solid or plank cell.
func test_keel_never_enters_a_solid_cell_in_any_room() -> void:
	var checked := 0
	for zone: String in StoneKeel.ZONES:
		for file: String in DirAccess.get_files_at("res://levels/" + zone):
			if not file.ends_with(".room"):
				continue
			var room := Room.from_file("res://levels/%s/%s" % [zone, file])
			arena.add_child(room)
			var keel := room.get_node_or_null("StoneKeel") as StoneKeel
			if keel == null:
				room.queue_free()
				continue
			var blocked: Dictionary = room._solid_look.duplicate()
			blocked.merge(room._planks)
			for k: Dictionary in keel.keels:
				checked += 1
				var bad := 0
				for p: Vector2i in k.pixels:
					var world: Vector2 = k.origin + Vector2(p)
					if blocked.has(Vector2i(int(world.x) / T, int(world.y) / T)):
						bad += 1
				for pb: Array in k.pebbles:
					var r: Rect2 = pb[0]
					if blocked.has(Vector2i(int(r.position.x) / T, int(r.end.y - 0.01) / T)):
						bad += 1
				check(bad == 0, "%s: the keel under column %d stays in open air (%d px in solid)" % [file, k.left, bad])
			room.queue_free()
	check(checked >= 4, "the Spires have floating stones to hang: %d" % checked)


func test_keel_the_fallen_bridge_hangs_every_floating_stone() -> void:
	var room := Room.from_file("res://levels/spires/fallen_bridge.room")
	arena.add_child(room)
	var keel := room.get_node_or_null("StoneKeel") as StoneKeel
	check(keel != null, "the Fallen Bridge has a keel layer")
	if keel == null:
		return
	# Its four floating bridge stones (rows 12 to 15, columns 13, 24, 34 and 44).
	var lefts := keel.keels.map(func(k: Dictionary) -> int: return k.left)
	for col: int in [13, 24, 34, 44]:
		check(col in lefts, "the stone at column %d hangs on a keel: %s" % [col, lefts])
