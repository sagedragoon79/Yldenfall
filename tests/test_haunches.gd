extends TestSuite
## The haunches (pass 591, bible 12.78): the ceiling's slopes. The pass 590
## grade saw the four reshaped rooms' ceilings as "stair-stepped tile blocks";
## a vault of square tiles climbs one tile at a time and every step shows. A
## haunch is solid on one side of a diagonal, above it, the mirror of a floor
## slope: `` ` `` keeps the top-left half, `'` the top-right.

const ROOMS: Array[String] = ["boughs/canopy_bridge", "vorrhallow/flooded_hall", "sunken/drowned_aqueduct", "spires/storm_ledge"]
const PX := TilesetFactory.TILE * TilesetFactory.DENSITY


func _grid(id: String) -> Array[String]:
	var text := FileAccess.get_file_as_string("res://levels/%s.room" % id)
	var rows: Array[String] = []
	for line: String in text.split("---\n", false, 1)[1].split("\n", false):
		rows.append(line)
	return rows


## A walled box, ceiling rows 0 to 6, floor from row 12, with `cells` (Vector2i
## -> legend char) laid in.
func _box(cells: Dictionary) -> Array:
	var rows := []
	for y in 15:
		var row := []
		for x in 20:
			row.append("#" if y <= 6 or y >= 12 or x <= 1 or x >= 18 else ".")
		rows.append(row)
	for c: Vector2i in cells:
		rows[c.y][c.x] = cells[c]
	var out := []
	for row: Array in rows:
		out.append("".join(PackedStringArray(row)))
	return out


func test_every_painted_atlas_has_both_haunches() -> void:
	for zone: String in ["boughs", "vorrhallow", "sunken", "spires", "haar", "tower", "gym"]:
		var img: Image = (load("res://assets/tiles/%s.png" % zone) as Texture2D).get_image()
		if not check(TilesetFactory.has_haunches(zone), "%s's atlas has the haunch row" % zone):
			continue
		var w := TilesetFactory.HAUNCH_WEST * PX
		var e := TilesetFactory.HAUNCH_EAST * PX
		var last := PX - 1
		check(img.get_pixel(w.x + 2, w.y + 2).a > 0.5 and img.get_pixel(w.x + last - 2, w.y + last - 2).a < 0.5,
			"%s: the west haunch is solid at its top left and open at its bottom right" % zone)
		check(img.get_pixel(e.x + last - 2, e.y + 2).a > 0.5 and img.get_pixel(e.x + 2, e.y + last - 2).a < 0.5,
			"%s: the east haunch is solid at its top right and open at its bottom left" % zone)
		# The cut runs along the diagonal: a pixel just above it is solid, one
		# just below it clear, the whole way across.
		var along := 0
		for x in range(2, PX - 2):
			if img.get_pixel(w.x + x, w.y + PX - 1 - x - 2).a > 0.5 and img.get_pixel(w.x + x, w.y + PX - 1 - x + 2).a < 0.5:
				along += 1
		check(along >= PX - 6, "%s: the west haunch's edge is one diagonal (%d of %d columns)" % [zone, along, PX - 4])
	check(not TilesetFactory.has_haunches("hearthroot"), "Hearthroot's PixelLab atlas has none")


func test_a_haunch_collides_as_a_triangle() -> void:
	var ts := TilesetFactory.build("boughs")
	var src := ts.get_source(TilesetFactory.SOURCE_ID) as TileSetAtlasSource
	for coords: Vector2i in [TilesetFactory.HAUNCH_WEST, TilesetFactory.HAUNCH_EAST]:
		var poly := src.get_tile_data(coords, 0).get_collision_polygon_points(0, 0)
		check(poly.size() == 3, "%s collides as a triangle" % coords)
	var room := make_room(["zone: boughs", "---"] + _box({Vector2i(2, 7): "`", Vector2i(17, 7): "'"}))
	var o := Vector2(2, 7) * Room.TILE
	check(room.is_solid_at(o + Vector2(3, 3)), "the west haunch is solid at its top left")
	check(not room.is_solid_at(o + Vector2(13, 13)), "and open at its bottom right")
	var e := Vector2(17, 7) * Room.TILE
	check(room.is_solid_at(e + Vector2(13, 3)), "the east haunch is solid at its top right")
	check(not room.is_solid_at(e + Vector2(3, 13)), "and open at its bottom left")
	check(room.tiles.get_cell_atlas_coords(Vector2i(2, 7)) == TilesetFactory.HAUNCH_WEST, "` lays the west haunch")
	check(room.tiles.get_cell_atlas_coords(Vector2i(17, 7)) == TilesetFactory.HAUNCH_EAST, "' lays the east haunch")


## Jump straight up against a wall into the corner of the vault: a square corner
## stops the head, and a haunch turns the jump along its slope, away from the wall.
func test_a_jump_into_a_haunch_slides_along_it() -> void:
	var drift := {}
	for ch: String in ["#", "`"]:
		var room := make_room(["zone: boughs", "---"] + _box({Vector2i(2, 7): ch}))
		var p := make_player(room, Vector2i(2, 11))
		p.position.x = 2 * Room.TILE + Player.BODY_SIZE.x * 0.5 + 0.5
		await frames(10)
		var x0 := p.global_position.x
		p.input.jump_pressed = true
		p.input.jump_held = true
		await frames(1)
		p.input.jump_pressed = false
		await frames(40)
		p.input.jump_held = false
		drift[ch] = p.global_position.x - x0
		room.queue_free()
		await frames(1)
	check(absf(drift["#"]) < 1.0, "a square corner stops the head where it is (moved %.1f px)" % drift["#"])
	check(drift["`"] > 3.0, "a haunch turns the jump out from the wall along its slope (moved %.1f px)" % drift["`"])


## The four rooms the grade named have no stair left in their vaults: no open
## cell is an inner ceiling corner the haunches would round.
func test_the_four_vaults_curve_instead_of_stepping() -> void:
	for id in ROOMS:
		var g := _grid(id)
		var count := 0
		var steps: Array[Vector2i] = []
		var solid := func(x: int, y: int) -> bool:
			return y < 0 or y >= g.size() or x < 0 or x >= g[y].length() or "#u".contains(g[y][x])
		for y in range(1, g.size() - 1):
			for x in range(1, g[y].length() - 1):
				var ch := g[y][x]
				if ch == "`" or ch == "'":
					count += 1
					# A haunch hangs from ground and leans on its solid side.
					var side := x - 1 if ch == "`" else x + 1
					check(solid.call(x, y - 1) and solid.call(side, y), "%s (%d, %d): the haunch hangs from ground" % [id, x, y])
				if ch != "." or not solid.call(x, y - 1) or solid.call(x, y + 1):
					continue
				var west: bool = solid.call(x - 1, y) and not solid.call(x + 1, y) and not solid.call(x + 1, y + 1)
				var east: bool = solid.call(x + 1, y) and not solid.call(x - 1, y) and not solid.call(x - 1, y + 1)
				if west or east:
					steps.append(Vector2i(x, y))
		check(count >= 25, "%s's vault carries its haunches (%d)" % [id, count])
		check(steps.is_empty(), "%s has no square inner corner left in its ceiling (%s)" % [id, steps])
