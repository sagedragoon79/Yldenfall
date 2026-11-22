extends TestSuite
## Chest: each zone houses its treasure in its own kind of chest (pass 595,
## design bible 12.80). The pass 585 grade saw "the same chest ... in nearly
## every room"; one brown trunk stood in all 68 chest cells.


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data["colors"]:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## Every zone with rooms has a chest look, every look a known kind, and every
## tone it draws (its look's and the shared ones) is a master palette value.
func test_chest_every_zone_has_a_look_in_the_palette() -> void:
	var palette := _palette()
	for zone: String in DirAccess.get_directories_at("res://levels"):
		check(Chest.LOOKS.has(zone), "zone %s has a chest look" % zone)
	for zone: String in Chest.LOOKS:
		var look: Dictionary = Chest.LOOKS[zone]
		check(String(look["kind"]) in Chest.KINDS, "%s: a known kind (%s)" % [zone, look["kind"]])
		for key: String in look:
			if key != "kind":
				check(palette.has(String(look[key]).to_lower()), "%s: %s #%s is a master palette tone" % [zone, key, look[key]])
		for open: bool in [false, true]:
			for q: Array in Chest.parts(look, open):
				check(palette.has(String(q[4]).to_lower()), "%s: a drawn tone #%s is in the palette" % [zone, q[4]])
	check(Chest.look_for("nowhere") == Chest.LOOKS["gym"], "an unknown zone falls back to the trunk")


## The zones do not share one chest: every kind is used, the game's zones use
## at least seven of them, and no two kinds draw the same closed silhouette.
func test_chest_the_zones_do_not_share_one_chest() -> void:
	var used := {}
	for zone: String in DirAccess.get_directories_at("res://levels"):
		if zone != "gym":
			used[String(Chest.look_for(zone)["kind"])] = true
	check(used.size() >= 7, "the game's zones use at least seven kinds of chest (%d)" % used.size())
	var shapes := {}
	for zone: String in Chest.LOOKS:
		var look: Dictionary = Chest.LOOKS[zone]
		var kind := String(look["kind"])
		var mask := _mask(Chest.parts(look, false))
		if shapes.has(kind):
			continue
		for other: String in shapes:
			check(shapes[other] != mask, "%s and %s draw different silhouettes" % [kind, other])
		shapes[kind] = mask
	for kind: String in Chest.KINDS:
		check(shapes.has(kind), "kind %s is used by some zone" % kind)


## Every part stays in the chest's box and on its ground line, the closed lid
## covers the lock's light, and opening it throws the lid back.
func test_chest_parts_fit_and_open() -> void:
	for zone: String in Chest.LOOKS:
		var look: Dictionary = Chest.LOOKS[zone]
		for open: bool in [false, true]:
			var lowest := -999
			for q: Array in Chest.parts(look, open):
				var r := Rect2(q[0], q[1], q[2], q[3])
				check(Chest.BOUNDS.encloses(r), "%s: part %s stays inside %s" % [zone, r, Chest.BOUNDS])
				lowest = maxi(lowest, int(r.end.y))
			check(lowest == 0, "%s: the chest stands on the ground line (%d)" % [zone, lowest])
		var closed := Chest.parts(look, false)
		var plate := false
		for q: Array in closed:
			if Rect2(q[0], q[1], q[2], q[3]).encloses(Chest.KEYHOLE) and String(q[4]) == String(look["band"]):
				plate = true
		check(plate, "%s: the lock's light sits on its plate" % zone)
		check(_mask(closed) != _mask(Chest.parts(look, true)), "%s: opening it changes its shape" % zone)


## A room's chest takes the room's zone.
func test_chest_a_room_houses_its_zone_chest() -> void:
	var room := Room.from_text("zone: boughs\n---\n########\n#......#\n#..$...#\n########")
	arena.add_child(room)
	var chest: Chest = null
	for n in room.get_children():
		if n is Chest:
			chest = n
	check(chest != null, "the room has its chest")
	if chest:
		check(chest.zone == "boughs", "it is housed for the High Boughs (%s)" % chest.zone)
		check(Chest.look_for(chest.zone)["kind"] == "hamper", "a High Boughs chest is a woven hamper")


## The set of half-pixels the parts cover.
func _mask(parts: Array) -> Dictionary:
	var m := {}
	for q: Array in parts:
		for y in range(int(q[1]), int(q[1]) + int(q[3])):
			for x in range(int(q[0]), int(q[0]) + int(q[2])):
				m[Vector2i(x, y)] = true
	return m


## A chest is set down with a few things beside it (pass 638, bible 12.114):
## every kind has a setting in palette tones, standing on the ground line and
## outside the chest's body, never past the floor it is given, and none at all
## on a floor no wider than the chest.
func test_chest_is_set_down_with_things_beside_it() -> void:
	var palette := _palette()
	var dump := {}
	var seen := {}
	for zone: String in Chest.LOOKS:
		var look: Dictionary = Chest.LOOKS[zone]
		var wide := Chest.setting(look, 80, 112)
		dump[zone] = {"parts": Chest.parts(look, false), "setting": wide, "narrow": Chest.setting(look, 16, 48)}
		check(wide.size() > 0, "%s: a chest on a broad floor has a setting" % zone)
		var east := 0
		var west := 0
		var lowest := -999
		var mask := _mask(wide)
		for q: Array in wide:
			var r := Rect2(q[0], q[1], q[2], q[3])
			check(palette.has(String(q[4]).to_lower()), "%s: a setting tone #%s is in the palette" % [zone, q[4]])
			check(r.position.x >= 80 * -1 and r.end.x <= 112, "%s: part %s stays on the floor (-80 to 112)" % [zone, r])
			check(r.end.y <= 0, "%s: part %s is not below the ground" % [zone, r])
			check(r.position.x >= Chest.BODY_HALF or r.end.x <= -Chest.BODY_HALF, "%s: part %s is beside the chest, not on it" % [zone, r])
			lowest = maxi(lowest, int(r.end.y))
			if r.position.x > 0:
				east += 1
			else:
				west += 1
		check(lowest == 0, "%s: the setting stands on the ground line (%d)" % [zone, lowest])
		check(east > 0 and west > 0, "%s: things lie on both sides of a chest with floor both ways" % zone)
		check(mask.size() >= 150, "%s: the setting is big enough to read (%d half-pixels)" % [zone, mask.size()])
		seen[mask] = true
		check(Chest.setting(look, Chest.HALF_CELL, Chest.HALF_CELL).is_empty(), "%s: no setting on a floor no wider than the chest" % zone)
		for q: Array in Chest.setting(look, 16, 48):
			check(int(q[0]) > 0 and int(q[0]) + int(q[2]) <= 48, "%s: with floor only east, the setting lies east inside it" % zone)
	check(seen.size() >= 7, "the zones' settings are not one stamp (%d different)" % seen.size())
	if OS.has_environment("CHEST_DUMP"):
		var f := FileAccess.open(OS.get_environment("CHEST_DUMP"), FileAccess.WRITE)
		f.store_string(JSON.stringify(dump))


## The room measures the floor beside a chest: open cells over a flat top, up
## to three a side; a slope, a wall or a gap ends it.
func test_chest_the_room_measures_its_floor() -> void:
	var room := Room.from_text("zone: hearthroot\n---\n############\n#..........#\n#...#$.....#\n##########.#\n############")
	arena.add_child(room)
	var chest: Chest = null
	for n in room.get_children():
		if n is Chest:
			chest = n
	check(chest != null, "the room has its chest")
	if chest:
		check(chest.reach_left == Chest.HALF_CELL, "a wall beside it: no floor west (%d)" % chest.reach_left)
		check(chest.reach_right == Chest.HALF_CELL + 3 * 2 * Chest.HALF_CELL, "three cells of floor east, the most it measures (%d)" % chest.reach_right)
	var gap := Room.from_text("zone: hearthroot\n---\n#########\n#.......#\n#...$...#\n##.-#.###\n#########")
	arena.add_child(gap)
	for n in gap.get_children():
		if n is Chest:
			check(n.reach_left == Chest.HALF_CELL + 2 * Chest.HALF_CELL, "a plank counts as floor (%d)" % n.reach_left)
			check(n.reach_right == Chest.HALF_CELL, "a gap beside it ends the floor (%d)" % n.reach_right)
