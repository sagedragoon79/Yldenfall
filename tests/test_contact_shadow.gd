extends TestSuite
## Standing things are grounded (pass 634, bible 12.110). The pass 630 grade: "props are
## not grounded: no contact shadows under chests, steles, the hero or foes, and the
## plaza's doorway is an orange frame floating on the skyline".

const ROWS := [
	"######################",
	"#....................#",
	"#....................#",
	"#....................#",
	"#..........H.........#",
	"#....................#",
	"#..$..S......D.......#",
	"######################",
	"######################",
]


func _shadow_of(n: Node) -> ContactShadow:
	for c in n.get_children():
		if c is ContactShadow:
			return c
	return null


## The chest, the shrine, a walker, a flier, a stele, a person, a doorway and the hero
## each carry a pool; a guardian does not (it draws its own ground).
func test_standing_things_cast_a_pool() -> void:
	var room := make_room(ROWS)
	var p := make_player(room, Vector2i(16, 6))
	var tablet := LoreTablet.new()
	tablet.zone = "hearthroot"
	room.add_child(tablet)
	var door := DoorMarker.new()
	room.add_child(door)
	await frames(2)
	var seen := {}
	for c in room.get_children():
		if c is Chest or c is SaveShrine or c is RotDwarf or c is Hornet:
			seen[c.get_class() if c.get_script() == null else c.get_script().get_global_name()] = _shadow_of(c) != null
	for k: String in ["Chest", "SaveShrine", "RotDwarf", "Hornet"]:
		check(seen.get(k, false), "%s casts a contact shadow" % k)
	check(_shadow_of(tablet) != null, "a stele casts one")
	check(_shadow_of(door) != null, "a doorway casts one")
	check(_shadow_of(p) != null and _shadow_of(p).follow, "the hero casts one that follows him")
	var dwarf_shadow: ContactShadow = null
	for c in room.get_children():
		if c is RotDwarf:
			dwarf_shadow = _shadow_of(c)
	check(dwarf_shadow != null and dwarf_shadow.follow, "a foe's follows it")
	if dwarf_shadow != null:
		check(dwarf_shadow.half_width > (dwarf_shadow.get_parent() as Enemy).body_size.x * 0.5, "a foe's is wider than its body")
	var npc := Npc.new()
	room.add_child(npc)
	check(_shadow_of(npc) != null, "a person casts one")
	var boss := Enemy.new()
	boss.add_to_group("boss")
	room.add_child(boss)
	check(_shadow_of(boss) == null, "a guardian casts none")


## The pool sits on the ground: in front of the tiles, behind its body, and mostly on the
## ground's top, so it darkens the lip under the feet.
func test_the_pool_lies_on_the_ground_lip() -> void:
	var room := make_room(ROWS)
	var p := make_player(room, Vector2i(16, 6))
	await frames(3)
	var s := _shadow_of(p)
	check(not s.z_as_relative and s.z_index == 0, "drawn at absolute z 0, over the tiles")
	check(s.show_behind_parent, "behind its body")
	check(s.drop >= 0.0 and s.drop < 0.5, "on the floor it falls at the feet (%.2f)" % s.drop)
	var on_ground := 0
	for r in ContactShadow.ROWS:
		if ContactShadow.TOP + r >= 0:
			on_ground += 1
	check(on_ground >= 3, "three rows on the ground (%d)" % on_ground)
	check(ContactShadow.TOP >= -1, "at most one row above the ground line, under the feet")


## A pool, not a slab: whole-pixel rows, the ground line widest, tapering away from it,
## with a darker core.
func test_the_pool_tapers() -> void:
	var hw := 12.0
	var widths: Array[float] = []
	for r in ContactShadow.ROWS:
		var w := ContactShadow.row_half_width(r, hw)
		check(is_equal_approx(w, roundf(w)), "row %d is whole pixels" % r)
		widths.append(w)
	var line := -ContactShadow.TOP
	check(is_equal_approx(widths[line], hw), "the ground line is the full width")
	for r in range(line + 1, ContactShadow.ROWS):
		check(widths[r] < widths[r - 1], "row %d is narrower than the one above it" % r)
	check(widths[0] < widths[line], "the row above the line is narrower")
	check(widths[ContactShadow.ROWS - 1] <= hw * 0.5, "the last row is half the width or less")
	check(ContactShadow.EDGE >= 0.3 and ContactShadow.EDGE + ContactShadow.CORE >= 0.6, "dark enough to read on a dark floor")
	check(ContactShadow.EDGE + ContactShadow.CORE < 0.8, "and soft, not a black bar")


## Off the ground the pool stays on the ground below, smaller and fainter; past its
## reach there is none.
func test_a_jump_leaves_a_fainter_pool_below() -> void:
	check_near(ContactShadow.strength_at(0.0), 1.0, 0.001, "full on the ground")
	check(ContactShadow.strength_at(ContactShadow.REACH * 0.5) < 0.6, "fainter halfway up")
	check(ContactShadow.strength_at(ContactShadow.REACH + 1.0) <= 0.0, "none past the reach")
	check(ContactShadow.strength_at(-1.0) <= 0.0, "none with no ground below")
	var room := make_room(ROWS)
	var p := make_player(room, Vector2i(16, 6))
	await frames(3)
	var s := _shadow_of(p)
	p.global_position.y -= 30.0
	p.velocity = Vector2.ZERO
	await frames(1)
	check(s.drop >= 26.0 and s.drop <= 34.0, "30 px up, the pool is on the floor below (%.1f)" % s.drop)
	var flier: Enemy = null
	for c in room.get_children():
		if c is Hornet:
			flier = c
	var fs := _shadow_of(flier)
	check(fs != null and fs.drop > 0.0, "a flier's pool is on the floor under it (%.1f)" % (fs.drop if fs != null else -2.0))


## A foe that has died casts nothing.
func test_a_dead_foe_casts_nothing() -> void:
	var room := make_room(ROWS)
	await frames(2)
	for c in room.get_children():
		if c is RotDwarf:
			var s := _shadow_of(c)
			check(not s.body_gone(), "alive, it casts a pool")
			(c as Enemy).dead = true
			check(s.body_gone(), "dead, it casts none")


## A doorway inside a room is set in a wall of the zone's stone, wider and taller than its
## frame, with a broken top.
func test_a_doorway_stands_in_a_wall() -> void:
	check(DoorMarker.WALL_HALF >= 20, "the wall is wider than the 28 px frame and its jambs")
	check(DoorMarker.WALL_HEIGHT >= 50, "and taller than the frame's arch")
	check(not DoorMarker.TOP_STEPS.is_empty(), "with a broken top")
	for step: Array in DoorMarker.TOP_STEPS:
		check(int(step[1]) - int(step[0]) < DoorMarker.WALL_HALF * 2, "a top course stops short of the full width")
	# The room hands its zone to the door, so the stone is that zone's.
	var text := "\n".join(PackedStringArray([
		"zone: hearthroot",
		"door: 1, test/b, 1",
		"---",
		"##########",
		"#........#",
		"#........#",
		"#...1....#",
		"#...1....#",
		"#...1....#",
		"##########",
	]))
	var room := Room.from_text(text)
	arena.add_child(room)
	var door: DoorMarker = null
	for c in room.get_children():
		if c is DoorMarker:
			door = c
	check(door != null, "an inner door is built")
	if door != null:
		check(door.zone == "hearthroot", "it is given its room's zone (%s)" % door.zone)
