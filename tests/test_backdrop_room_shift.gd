extends TestSuite
## A room shows its own stretch of the zone's backdrop (design bible 12.101, pass
## 625). The pass 620 grade saw the same floating islands in the same places in
## the Spires' storm ledge and Fallen Bridge: every room started each parallax
## layer at the same spot of the one painting its zone has.


## The distance between two shifts along the repeating art, world px.
func _apart(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, Backdrop.SIZE.x - d)


func _room_ids(zone: String) -> Array:
	var out := []
	for file: String in DirAccess.get_files_at("res://levels/" + zone):
		if file.ends_with(".room"):
			out.append("%s/%s" % [zone, file.get_basename()])
	return out


func _shifts(id: String) -> Array:
	var out := []
	for suffix: String in Backdrop.LAYERS:
		out.append(Backdrop.room_shift(id, suffix))
	return out


func test_backdrop_shift_a_room_slides_each_layer_its_own_way() -> void:
	for suffix: String in Backdrop.LAYERS:
		var s := Backdrop.room_shift("spires/storm_ledge", suffix)
		check(s >= 0.0 and s < Backdrop.SIZE.x, "%s: the shift is inside one repeat (%.0f)" % [suffix, s])
		check(is_equal_approx(fmod(s, Backdrop.SHIFT_STEP), 0.0), "%s: and on a whole step" % suffix)
		check(s == Backdrop.room_shift("spires/storm_ledge", suffix), "%s: and the same every time" % suffix)
	var shifts := _shifts("spires/storm_ledge")
	check(shifts[0] != shifts[1] or shifts[1] != shifts[2], "the layers are not slid as one sheet (%s)" % [shifts])
	check(Backdrop.room_shift("", "mid") == 0.0, "a room with no id slides nothing")


func test_backdrop_shift_the_graded_spires_rooms_show_different_islands() -> void:
	# The mid layer holds the sky islands: a sixth of the art (one island's share) apart at least.
	var a := Backdrop.room_shift("spires/storm_ledge", "mid")
	var b := Backdrop.room_shift("spires/fallen_bridge", "mid")
	check(_apart(a, b) >= Backdrop.SIZE.x / 6.0, "the storm ledge and the Fallen Bridge start the islands %.0f px apart" % _apart(a, b))


func test_backdrop_shift_no_two_rooms_of_a_zone_show_the_same_backdrop() -> void:
	var rooms := 0
	for zone: String in DirAccess.get_directories_at("res://levels"):
		var seen := {}
		var mids := {}
		var ids := _room_ids(zone)
		for id: String in ids:
			rooms += 1
			var key := str(_shifts(id))
			check(not seen.has(key), "%s: %s and %s set the layers the same way" % [zone, id, seen.get(key, "")])
			seen[key] = id
			mids[Backdrop.room_shift(id, "mid")] = true
		# The rooms of a zone are spread along the art, not bunched at one place.
		if ids.size() >= 6:
			check(mids.size() * 2 >= mini(ids.size(), 20), "%s: %d rooms start the mid layer at %d places" % [zone, ids.size(), mids.size()])
	check(rooms > 80, "the game's rooms were looked at (%d)" % rooms)


func test_backdrop_shift_the_world_slides_the_backdrop_for_the_room_it_enters() -> void:
	var b := Backdrop.new()
	arena.add_child(b)
	b.set_zone("spires")
	b.set_room("spires/storm_ledge")
	var found := 0
	for layer in b.get_children():
		var p := layer as Parallax2D
		if p == null:
			continue
		if p.scroll_scale == Backdrop.FORE_SCROLL:
			check(p.scroll_offset == Vector2.ZERO, "the foreground is not slid")
			continue
		for suffix: String in Backdrop.LAYERS:
			if p.scroll_scale == Backdrop.LAYERS[suffix]:
				found += 1
				check(p.scroll_offset == Vector2(Backdrop.room_shift("spires/storm_ledge", suffix), 0.0), "%s is slid for the room (%s)" % [suffix, p.scroll_offset])
	check(found == 3, "the Spires' three layers were found (%d)" % found)
	# The next room of the same zone slides them again, though the zone has not changed.
	b.set_zone("spires")
	b.set_room("spires/fallen_bridge")
	for layer in b.get_children():
		var p := layer as Parallax2D
		if p != null and p.scroll_scale == Backdrop.LAYERS["mid"]:
			check(p.scroll_offset.x == Backdrop.room_shift("spires/fallen_bridge", "mid"), "the next room's shift takes over")
	b.queue_free()
	check("backdrop.set_room(room.id)" in FileAccess.get_file_as_string("res://scripts/world/world.gd"), "World tells the backdrop which room it entered")
