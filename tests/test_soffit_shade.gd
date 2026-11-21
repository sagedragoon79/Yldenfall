extends TestSuite
## SoffitShade: mass that hangs over open air is in shadow (design bible 12.102,
## pass 626). The pass 625 grade: terrain has "no shadowed underside".

const SIZE := Vector2i(16, 12)


## A `SIZE` grid: a ceiling `ceil` rows thick, a floor two rows thick, and a
## wall two cells thick up the west side.
func _hall(ceil := 6) -> Dictionary:
	var solids := {}
	for y in SIZE.y:
		for x in SIZE.x:
			if y < ceil or y >= SIZE.y - 2 or x < 2:
				solids[Vector2i(x, y)] = true
	return solids


func _at(field: PackedFloat32Array, x: int, y: int) -> float:
	return field[y * SIZE.x + x]


func test_soffit_a_ceiling_is_shaded_from_its_underside_and_a_floor_is_not() -> void:
	var solids := _hall()
	var f := SoffitShade.shade_field(solids, SIZE)
	check(SoffitShade.is_source(solids, SIZE, {}, {}, Vector2i(8, 5)), "the ceiling's lowest course hangs over open air")
	check(not SoffitShade.is_source(solids, SIZE, {}, {}, Vector2i(8, 10)), "a floor does not")
	check_near(_at(f, 8, 5), 1.0, 0.001, "the lowest course is at full shade")
	check_near(_at(f, 8, 4), 1.0 - SoffitShade.RISE, 0.001, "the course above it has lost a RISE")
	check(_at(f, 8, 10) == 0.0 and _at(f, 8, 11) == 0.0, "the floor takes none (%.2f, %.2f)" % [_at(f, 8, 10), _at(f, 8, 11)])
	check(_at(f, 0, 8) == 0.0, "nor does the wall beside the open hall, below the ceiling")


func test_soffit_the_shade_holds_all_the_way_up_a_ceiling() -> void:
	var f := SoffitShade.shade_field(_hall(), SIZE)
	var last := 2.0
	for y in range(5, -1, -1):
		var v := _at(f, 8, y)
		check(v <= last, "row %d is no darker than the row under it (%.2f after %.2f)" % [y, v, last])
		check(v >= SoffitShade.HOLD, "row %d of the ceiling keeps at least HOLD (%.2f): no lit band inside it" % [y, v])
		last = v
	check_near(_at(f, 8, 0), SoffitShade.HOLD, 0.001, "the top of a thick ceiling rests at HOLD")


func test_soffit_a_walking_surface_keeps_its_light() -> void:
	var solids := _hall(2)
	# A ledge one cell thick and a block two thick, both standing in open air.
	for x in range(5, 8):
		solids[Vector2i(x, 6)] = true
	for x in range(10, 13):
		solids[Vector2i(x, 5)] = true
		solids[Vector2i(x, 6)] = true
	var f := SoffitShade.shade_field(solids, SIZE)
	check(_at(f, 6, 6) == 0.0, "a ledge one cell thick is all walking surface: no shade (%.2f)" % _at(f, 6, 6))
	check(_at(f, 11, 5) == 0.0, "the top of a thicker block is not shaded (%.2f)" % _at(f, 11, 5))
	check_near(_at(f, 11, 6), 1.0, 0.001, "its underside course is")
	var shade := SoffitShade.new()
	arena.add_child(shade)
	shade.setup(solids, SIZE)
	check(shade.level_at_pixel(Vector2(11.5, 5.1) * SoffitShade.TILE) == 0, "the top pixels of the block are drawn bare")
	check(shade.level_at_pixel(Vector2(11.5, 6.9) * SoffitShade.TILE) == SoffitShade.LEVELS, "its bottom pixels are drawn at the full step")
	check(shade.level_at_pixel(Vector2(11.5, 7.5) * SoffitShade.TILE) == 0, "open air under it is never drawn on")


func test_soffit_a_ceiling_feathers_into_the_wall_it_springs_from() -> void:
	# The ceiling covers only the east half; west of it the mass runs down to the floor.
	var solids := {}
	for y in SIZE.y:
		for x in SIZE.x:
			if x < 8 or y < 4 or y >= SIZE.y - 2:
				solids[Vector2i(x, y)] = true
	var f := SoffitShade.shade_field(solids, SIZE)
	check_near(_at(f, 8, 3), 1.0, 0.001, "the underside course beside the wall is full")
	var last := 1.0
	var reached := 0
	for x in range(7, 1, -1):
		var v := _at(f, x, 3)
		check(v <= last, "column %d is no darker than the one nearer the ceiling (%.2f after %.2f)" % [x, v, last])
		if v > 0.0:
			reached += 1
		last = v
	check(reached >= 2 and reached <= 4, "the shade runs two to four cells into the wall (%d)" % reached)
	check(_at(f, 2, 3) == 0.0, "and is gone well inside it")
	check(_at(f, 7, 8) == 0.0, "the wall's face below the ceiling takes none")


func test_soffit_a_haunch_is_shaded_in_its_solid_half_only() -> void:
	var solids := _hall()
	var west := Vector2i(2, 6)
	solids[west] = true
	var haunches := {west: true}
	var f := SoffitShade.shade_field(solids, SIZE, haunches)
	check(SoffitShade.is_source(solids, SIZE, haunches, {}, west), "a haunch's diagonal is an underside")
	check_near(_at(f, 2, 6), 1.0, 0.001, "so it is at full shade")
	check(not SoffitShade.is_source(solids, SIZE, haunches, {}, Vector2i(2, 5)), "the course above a haunch has ground under it")
	var shade := SoffitShade.new()
	arena.add_child(shade)
	shade.setup(solids, SIZE, haunches)
	var o := Vector2(west * SoffitShade.TILE)
	check(shade.level_at_pixel(o + Vector2(3, 3)) > 0, "the solid top-left half is shaded")
	check(shade.level_at_pixel(o + Vector2(13, 13)) == 0, "the open bottom-right half is not")


func test_soffit_a_walking_slope_takes_no_shade() -> void:
	var solids := _hall()
	var slope := Vector2i(6, 9)
	solids[slope] = true
	var slopes := {slope: true}
	var f := SoffitShade.shade_field(solids, SIZE, {}, slopes)
	check(not SoffitShade.is_source(solids, SIZE, {}, slopes, slope), "a walking slope is no underside")
	var shade := SoffitShade.new()
	arena.add_child(shade)
	shade.setup(solids, SIZE, {}, slopes)
	check(shade.level_at_pixel((Vector2(slope) + Vector2(0.5, 0.5)) * SoffitShade.TILE) == 0, "and is never drawn on")
	check_near(_at(f, 6, 5), 1.0, 0.001, "the ceiling over it is unchanged")


func test_soffit_the_room_shades_its_ceilings() -> void:
	var rows: Array = ["zone: boughs", "---"]
	for y in 14:
		var row := ""
		for x in 20:
			var solid := y < 5 or y >= 11 or x == 0 or x == 19
			row += "#" if solid else "."
		rows.append(row)
	rows[2 + 5] = "#`................'#"
	var room := make_room(rows)
	var shade := room.get_node_or_null("SoffitShade") as SoffitShade
	if not check(shade != null, "the room builds a SoffitShade"):
		return
	check(shade.block_count() > 0, "and it draws")
	var t := float(Room.TILE)
	check(shade.level_at_pixel(Vector2(10.5 * t, 4.9 * t)) == SoffitShade.LEVELS, "the ceiling's lowest pixels are at the full step")
	check(shade.level_at_pixel(Vector2(10.5 * t, 0.5 * t)) >= 1, "the top of the ceiling is still in shadow")
	check(shade.level_at_pixel(Vector2(10.5 * t, 11.5 * t)) == 0, "the floor is bare")
	check(shade.level_at_pixel(Vector2(1.2 * t, 5.2 * t)) > 0, "the west haunch is shaded in its solid half")
	check(shade.level_at_pixel(Vector2(1.8 * t, 5.8 * t)) == 0, "and bare in its open half")
	var edge := room.get_node("EdgeShade")
	var deep := room.get_node("DeepShade")
	check(edge.get_index() < shade.get_index() and shade.get_index() < deep.get_index(), "it draws over the rim and under the deep shade")
