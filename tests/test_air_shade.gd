extends TestSuite
## AirShade: the play plane stands off the backdrop (design bible 12.129). The
## air next to every solid edge, plank board and hung deck darkens toward it,
## with the key light from the top left.

const T := AirShade.TILE


func _shade(solids: Dictionary, size: Vector2i, boards := {}, decks := {}, haunches := {}) -> AirShade:
	var shade := AirShade.new()
	arena.add_child(shade)
	shade.setup(solids, boards, decks, size, haunches)
	return shade


func _row(y: int, from: int, to: int) -> Dictionary:
	var out := {}
	for x in range(from, to + 1):
		out[Vector2i(x, y)] = true
	return out


func test_air_darkens_at_an_edge_and_most_below() -> void:
	# A ledge of solid across row 2, open air under and over it.
	var ledge := _row(2, 2, 7)
	var shade := _shade(ledge, Vector2i(10, 10))
	var foot := 3.0 * T
	var mid := 5.0 * T
	check(is_equal_approx(shade.alpha_at(Vector2(mid, foot + 1)), AirShade.MAX_ALPHA),
			"the air just under an underside is at its darkest: %f" % shade.alpha_at(Vector2(mid, foot + 1)))
	check(shade.alpha_at(Vector2(mid, foot + 12)) > 0.0, "the darkness reaches 12 px under it")
	check(shade.alpha_at(Vector2(mid, foot + AirShade.DOWN_REACH + 2)) == 0.0, "and ends past DOWN_REACH")
	var top := 2.0 * T
	check(shade.alpha_at(Vector2(mid, top - 1)) > 0.0, "a thin line darkens over the walking surface")
	check(shade.alpha_at(Vector2(mid, top - 6)) == 0.0, "but no more than UP_REACH over it")
	var end := 8.0 * T
	check(shade.alpha_at(Vector2(end + 6, top + 8)) > 0.0, "the air beside the ledge's end darkens")
	check(shade.alpha_at(Vector2(end + AirShade.SIDE_REACH + 2, top + 8)) == 0.0, "for SIDE_REACH beside it")
	check(AirShade.DOWN_REACH > AirShade.SIDE_REACH and AirShade.SIDE_REACH > AirShade.UP_REACH,
			"it falls furthest below, then beside, least above (the key light is top left)")
	check(shade.alpha_at(Vector2(mid, 2.5 * T)) == 0.0, "nothing is painted over the solid itself")


func test_air_shade_falls_off_in_clean_steps() -> void:
	var shade := _shade(_row(2, 0, 9), Vector2i(10, 10))
	var seen := {}
	var last := 2.0
	for y in range(int(3.0 * T) + 1, int(3.0 * T + AirShade.DOWN_REACH) + 4):
		var a := shade.alpha_at(Vector2(80, y))
		seen[snappedf(a, 0.001)] = true
		check(a <= last + 0.0001, "the darkness never rises away from the edge (%d px: %f)" % [y, a])
		last = a
	check(seen.size() == AirShade.LEVELS + 1, "it steps through %d levels to none: %s" % [AirShade.LEVELS, seen.keys()])
	# No dither: every block along one row at one depth is the same step.
	var row := {}
	for x in range(20, 140, 2):
		row[snappedf(shade.alpha_at(Vector2(x, 3.0 * T + 9)), 0.001)] = true
	check(row.size() == 1, "one depth is one step across the run, no checker: %s" % [row.keys()])


func test_air_a_board_casts_from_its_top_only() -> void:
	var boards := _row(4, 3, 6)
	var shade := _shade({}, Vector2i(10, 10), boards)
	var x := 4.5 * T
	check(shade.alpha_at(Vector2(x, 4.0 * T + 1)) == 0.0, "the board itself is not painted")
	var under := 4.0 * T + AirShade.BOARD_DEPTH
	check(shade.alpha_at(Vector2(x, under + 1)) > 0.0, "the air under the board darkens")
	check(shade.alpha_at(Vector2(x, under + AirShade.DOWN_REACH + 2)) == 0.0, "for DOWN_REACH under it")
	var decked := _shade({}, Vector2i(10, 10), boards, boards)
	check(decked.alpha_at(Vector2(x, 4.0 * T + 8)) == 0.0, "a hung deck's cell is its own, not air")
	check(decked.alpha_at(Vector2(x, 5.0 * T + 1)) > 0.0, "the air under a hung deck darkens from its foot")


func test_air_open_rooms_and_the_outside_cast_nothing() -> void:
	var empty := _shade({}, Vector2i(6, 6))
	check(empty.painted() == 0, "a room of open air paints nothing")
	check(empty.alpha_at(Vector2(2, 2)) == 0.0, "not even by the frame: the room's outside casts nothing")


func test_air_a_room_builds_its_shade_behind_the_tiles() -> void:
	var room := Room.from_text("zone: tower
---
##########
#........#
#........#
#..----..#
#........#
#........#
#...##...#
#........#
#........#
##########")
	arena.add_child(room)
	var shade := room.get_node_or_null("AirShade") as AirShade
	check(shade != null, "the room builds an AirShade")
	if shade == null:
		return
	check(shade.z_index < room.tiles.z_index, "it draws behind the tiles")
	var holds := room.get_node_or_null("PlankSupports") as PlankSupports
	check(holds != null and holds.decks.size() == 1, "the plank run hangs as a deck")
	check(shade.alpha_at(Vector2(4.5 * T, 4.0 * T + 1)) > 0.0, "the air under the hung deck darkens")
	check(shade.alpha_at(Vector2(4.5 * T, 3.0 * T + 8)) == 0.0, "the deck's own cell is not painted")
	check(shade.alpha_at(Vector2(4.5 * T, 7.0 * T + 1)) > 0.0, "the air under the block darkens")
	check(shade.alpha_at(Vector2(1.0 * T + 1, 5.0 * T)) > 0.0, "the air beside the wall darkens")


## A haunch casts from its diagonal (bible 12.136, pass 660): the falloff runs
## along the slope the tile draws, not in square steps from the cells behind it.
func test_air_a_haunch_casts_from_its_diagonal() -> void:
	# A west haunch at (4, 4): solid above it and to its left, open below and right.
	var solids := {Vector2i(4, 3): true, Vector2i(3, 4): true, Vector2i(3, 3): true}
	var shade := _shade(solids, Vector2i(10, 10), {}, {}, {Vector2i(4, 4): true})
	var o := Vector2(4, 4) * T
	var n := Vector2(1, 1).normalized()
	# Two points the same way off the diagonal, near its two ends, are one step.
	var off := 5.0
	var near_top := shade.alpha_at(o + Vector2(12, 4) + n * off)
	var near_wall := shade.alpha_at(o + Vector2(4, 12) + n * off)
	check(near_top > 0.0, "the air off the slope darkens: %f" % near_top)
	check(is_equal_approx(near_top, near_wall),
			"one step all along the slope, not squares from the cells behind it: %f, %f" % [near_top, near_wall])
	check(is_equal_approx(shade.alpha_at(o + Vector2(9, 9)), AirShade.MAX_ALPHA),
			"the air just past the diagonal is at its darkest: %f" % shade.alpha_at(o + Vector2(9, 9)))
	check(shade.alpha_at(o + Vector2(8, 8) + n * 20.0) == 0.0, "and it is gone well off the slope")
	# An east haunch mirrors it.
	var east := _shade({Vector2i(5, 3): true, Vector2i(6, 4): true, Vector2i(6, 3): true}, Vector2i(10, 10), {}, {},
			{Vector2i(5, 4): false})
	var e := Vector2(5, 4) * T
	var m := Vector2(-1, 1).normalized()
	check(is_equal_approx(east.alpha_at(e + Vector2(4, 4) + m * off), east.alpha_at(e + Vector2(12, 12) + m * off)),
			"an east haunch casts along its own diagonal")
	check(east.alpha_at(e + Vector2(4, 4) + m * off) > 0.0, "and darkens the air off it")


func test_air_a_room_passes_its_haunches() -> void:
	var rows := ["zone: boughs", "---"]
	for y in 12:
		var row := ""
		for x in 12:
			row += "#" if y <= 3 or y >= 10 or x <= 1 or x >= 10 else "."
		rows.append(row)
	rows[2 + 4] = rows[2 + 4].substr(0, 2) + "`" + rows[2 + 4].substr(3)
	var room := make_room(rows)
	var shade := room.get_node_or_null("AirShade") as AirShade
	if not check(shade != null, "the room builds an AirShade"):
		return
	var o := Vector2(2, 4) * T
	check(room.is_solid_at(o + Vector2(3, 3)) and not room.is_solid_at(o + Vector2(9, 9)), "the haunch is laid")
	check(is_equal_approx(shade.alpha_at(o + Vector2(9, 9)), AirShade.MAX_ALPHA),
			"the air just past its diagonal is at its darkest: %f" % shade.alpha_at(o + Vector2(9, 9)))
