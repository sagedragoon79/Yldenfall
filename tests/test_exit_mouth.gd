extends TestSuite
## ExitMouth: a side exit is the mouth of a passage under the wall above it
## (design bible 12.125, pass 649). The pass 645 grade: "walls that end mid-air at
## the screen's edge".

## A room 20 wide: a west exit under a wall one tile thick that runs 2 tiles in,
## an east exit with open sky over it.
const ROWS := [
	"#...................",
	"#...................",
	"##..................",
	"1...................",
	"1..................2",
	"1..................2",
	"####################",
]


func _room() -> Room:
	var room := Room.from_text("\n".join(PackedStringArray(["zone: heartwood", "door: 1, x, 1", "door: 2, x, 1", "---"] + ROWS)))
	arena.add_child(room)
	return room


func _mouth(room: Room) -> ExitMouth:
	for c in room.get_children():
		if c is ExitMouth:
			return c
	return null


## The mean opacity over the 8 x 4 px area at `p`, so the dither does not decide a check.
func _mean(mouth: ExitMouth, p: Vector2) -> float:
	var sum := 0.0
	for dy in 4:
		for dx in 8:
			sum += mouth.alpha_at(p + Vector2(dx, dy))
	return sum / 32.0


func test_a_side_exit_under_a_wall_is_a_mouth_dark_toward_the_edge() -> void:
	var room := _room()
	var mouth := _mouth(room)
	check(mouth != null, "the room has an exit mouth")
	if mouth == null:
		return
	check(mouth.mouths.size() == 1, "only the exit with a wall over it has a mouth" + " (%s)" % str(mouth.mouths.size()))
	var m: Dictionary = mouth.mouths[0]
	check(m.left, "it is the west exit")
	check(m.rect == Rect2(0, 48, 64, 48), "it runs from the wall's underside to the floor, 4 tiles in" + " (%s)" % str(m.rect))
	check(m.roof == 32, "the wall above reaches 2 tiles in" + " (%s)" % str(m.roof))
	# Darkest at the edge, fading inward, gone by DEPTH.
	var y := 80.0
	var edge := _mean(mouth, Vector2(0, y))
	var mid := _mean(mouth, Vector2(24, y))
	var deep := mouth.alpha_at(Vector2(ExitMouth.DEPTH + 2, y))
	check(edge >= ExitMouth.MAX_ALPHA * 0.8, "the edge is nearly black (%.2f)" % edge)
	check(mid > 0.0 and mid < edge, "halfway in is lighter (%.2f < %.2f)" % [mid, edge])
	check(deep == 0.0, "nothing past DEPTH" + " (%s)" % str(deep))
	# Under the wall it is darker at the lintel than lower down.
	check(_mean(mouth, Vector2(16, 48)) > _mean(mouth, Vector2(16, 88)) + 0.08,
		"darker under the lintel (%.2f, %.2f)" % [_mean(mouth, Vector2(16, 48)), _mean(mouth, Vector2(16, 88))])
	# Past the wall's end its top fades in: no hard edge across open air.
	check(_mean(mouth, Vector2(34, 48)) + 0.08 < _mean(mouth, Vector2(34, 48 + ExitMouth.OPEN_FADE)),
		"past the wall the top fades in (%.2f, %.2f)" % [_mean(mouth, Vector2(34, 48)), _mean(mouth, Vector2(34, 48 + ExitMouth.OPEN_FADE))])
	check(mouth.alpha_at(Vector2(4, 40)) == 0.0, "the wall above is not shaded")
	check(mouth.alpha_at(Vector2(4, 100)) == 0.0, "nor the floor")


func test_the_mouth_lies_behind_the_tiles_and_the_actors() -> void:
	var mouth := _mouth(_room())
	check(mouth.z_index < 0 and mouth.z_as_relative, "behind the tiles (z %d)" % mouth.z_index)
	check(mouth.z_index >= -1, "over the light shafts and the backdrop")


func test_the_graded_rooms_side_exits_have_mouths() -> void:
	# The rooms the pass 645 grade saw walls end in mid-air over an exit.
	for spec: Array in [["spires/sky_steps", true], ["boughs/canopy_bridge", true], ["boughs/canopy_bridge", false], ["haar/marsh_road", true]]:
		var room := Room.from_text(FileAccess.get_file_as_string("res://levels/%s.room" % spec[0]))
		var found := false
		for m: Dictionary in _mouth(room).mouths:
			found = found or m.left == spec[1]
		check(found, "%s's %s exit is a passage mouth" % [spec[0], "west" if spec[1] else "east"])
		room.free()
