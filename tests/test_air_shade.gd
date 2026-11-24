extends TestSuite
## AirShade: the play plane stands off the backdrop (design bible 12.129). The
## air next to every solid edge, plank board and hung deck darkens toward it,
## with the key light from the top left.

const T := AirShade.TILE


func _shade(solids: Dictionary, size: Vector2i, boards := {}, decks := {}) -> AirShade:
	var shade := AirShade.new()
	arena.add_child(shade)
	shade.setup(solids, boards, decks, size)
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
