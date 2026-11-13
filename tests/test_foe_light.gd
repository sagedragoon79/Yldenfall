extends TestSuite
## A foe stands in its room's light (pass 553, bible 12.43). The pass 550 grade
## saw foes "more saturated and detailed than the muted rooms, so they look
## pasted in": a foe in a zone's room is muted a little and its darks sink toward
## the deep of the zone's haze, while its lights, its flash and its tell are
## left alone.

const ROWS := [
	"####################",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..........H.......#",
	"#..................#",
	"#..................#",
	"#..................#",
	"####################",
	"####################",
]


func _room(zone: String) -> Room:
	var lines := PackedStringArray(ROWS)
	if zone != "":
		lines = PackedStringArray(["zone: " + zone, "---"]) + lines
	var room := Room.from_text("\n".join(lines))
	arena.add_child(room)
	return room


func _hornet(room: Room) -> Hornet:
	for c in room.get_children():
		if c is Hornet:
			return c
	return null


func _saturation(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func test_foes_stand_in_their_rooms_light() -> void:
	# Every zone with rooms has a light to stand in.
	var dir := DirAccess.open("res://levels")
	for zone in dir.get_directories():
		if zone == "gym":
			continue
		check(FoeLight.material_for(zone) != null, "foes in %s stand in its light" % zone)
	check(FoeLight.material_for("gym") == null and FoeLight.material_for("") == null,
		"outside a zone a foe is drawn as painted")
	check(FoeLight.lit(Color(0.9, 0.6, 0.1), "gym") == Color(0.9, 0.6, 0.1), "and its colours are untouched")

	# The sum: colour is muted, darks sink toward the zone, lights hold.
	var bee := Color8(232, 168, 36)   # the hornet's yellow
	var teal := Color8(38, 120, 104)  # the adder's scales
	for zone: String in Backdrop.ZONE_HAZE:
		var deep := FoeLight.deep_for(zone)
		var haze: Color = Backdrop.ZONE_HAZE[zone]
		check(FoeLight.luma(deep) < FoeLight.luma(haze), "%s: the darks sink below the haze, never up to it" % zone)
		for c: Color in [bee, teal]:
			var out := FoeLight.lit(c, zone)
			check(_saturation(out) < _saturation(c) * 0.9, "%s: a strong colour is muted" % zone)
			check(_saturation(out) > _saturation(c) * 0.5, "%s: but it keeps its hue" % zone)
		var black := FoeLight.lit(Color.BLACK, zone)
		check(black.is_equal_approx(Color.BLACK.lerp(deep, FoeLight.SINK)), "%s: an outline takes the room's shadow colour" % zone)
		check(FoeLight.luma(black) < 0.12, "%s: and stays an outline" % zone)
		check(FoeLight.lit(Color.WHITE, zone).is_equal_approx(Color.WHITE), "%s: white (the flash, the tell) is untouched" % zone)
		check(absf(FoeLight.luma(FoeLight.lit(bee, zone)) - FoeLight.luma(bee)) < 0.04, "%s: a light keeps its value" % zone)
	check(FoeLight.sink_at(0.0) > FoeLight.sink_at(0.5) * 3.0 and is_zero_approx(FoeLight.sink_at(1.0)),
		"the sink falls off fast toward the lights")
	check(not FoeLight.lit(Color.BLACK, "boughs").is_equal_approx(FoeLight.lit(Color.BLACK, "tower")),
		"each zone has its own shadow colour")

	# The material carries the same numbers as the sum.
	var mat := FoeLight.material_for("tower")
	var deep_t := FoeLight.deep_for("tower")
	check((mat.get_shader_parameter("haze") as Vector3).is_equal_approx(Vector3(deep_t.r, deep_t.g, deep_t.b)),
		"the shader sinks toward the zone's deep")
	check(is_equal_approx(mat.get_shader_parameter("mute"), FoeLight.MUTE)
		and is_equal_approx(mat.get_shader_parameter("sink"), FoeLight.SINK), "with the tuned mute and sink")
	check(FoeLight.material_for("tower") == mat, "one material serves every foe of a zone")

	# A foe in a zone's room rests in it; the flash and the death replace it.
	var room := _room("tower")
	var h := _hornet(room)
	await frames(2)
	check(h.material == mat, "a hornet in the Tower rests in the Tower's light")
	h.wash(true)
	check(h.washed() and h.material != mat, "the white wash replaces it")
	h.wash(false)
	check(h.material == mat, "and it comes back when the wash ends")
	h.respawn_time = 0.3
	h.take_hit(999, Vector2(1, 0))
	await frames(2)
	check(h.material != null and h.material != mat, "the death's dissolve replaces it")
	await frames(60)
	check(not h.dead and h.material == mat, "a foe that respawns is back in the room's light")

	# No zone, no light: the gym and bare test rooms draw as painted.
	var bare := _room("")
	var g := _hornet(bare)
	await frames(2)
	check(g.material == null, "a foe outside a zone has no material")
