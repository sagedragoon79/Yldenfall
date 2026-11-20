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
			# Saturation, not chroma: the fill (12.89) makes a mid tone lighter,
			# and a lighter pixel of one saturation has more chroma.
			check(out.s < c.s * 0.9, "%s: a strong colour is muted" % zone)
			check(out.s > c.s * 0.5, "%s: but it keeps its hue" % zone)
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
	var own := FoeLight.material_for("tower", "hornet")
	var room := _room("tower")
	var h := _hornet(room)
	await frames(2)
	check(h.material == own, "a hornet in the Tower rests in the Tower's light")
	h.wash(true)
	check(h.washed() and h.material != own, "the white wash replaces it")
	h.wash(false)
	check(h.material == own, "and it comes back when the wash ends")
	h.respawn_time = 0.3
	h.take_hit(999, Vector2(1, 0))
	await frames(2)
	check(h.material != null and h.material != own, "the death's dissolve replaces it")
	await frames(60)
	check(not h.dead and h.material == own, "a foe that respawns is back in the room's light")

	# No zone, no light: the gym and bare test rooms draw as painted.
	var bare := _room("")
	var g := _hornet(bare)
	await frames(2)
	check(g.material == null, "a foe outside a zone has no material")


## Pass 582 (bible 12.69). The pass 580 grade: foes are "dark on dark", and each
## wants "one saturated color". A foe's accent is a band of hue on its own sheet
## that the room's light leaves out and lifts.
func test_each_foe_keeps_one_colour_of_its_own() -> void:
	check(FoeLight.ACCENTS.size() >= 18, "most foes have an accent (%d)" % FoeLight.ACCENTS.size())
	for id: String in FoeLight.ACCENTS:
		var a: Array = FoeLight.ACCENTS[id]
		check(ResourceLoader.exists("res://scripts/enemies/%s.gd" % id), "%s is a foe" % id)
		check(a.size() == 6 and a[1] > 0.0 and a[1] <= 35.0, "%s: one band of hue, not half the wheel" % id)
		check(a[4] >= 0.5 and a[5] >= 0.3, "%s: the lift shows" % id)
		# The sheet holds the colour, and it is a part of the foe, never its body.
		var img: Image = (load("res://assets/sprites/%s.png" % id) as Texture2D).get_image()
		var solid := 0
		var lit_up := 0
		var gain_s := 0.0
		var gain_v := 0.0
		var hue_drift := 0.0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var c := img.get_pixel(x, y)
				if c.a < 0.8:
					continue
				solid += 1
				if FoeLight.accent_at(c, id) < 0.5:
					continue
				lit_up += 1
				var plain := FoeLight.lit(c, "tower")
				var own := FoeLight.lit(c, "tower", id)
				gain_s += own.s - plain.s
				gain_v += own.v - plain.v
				hue_drift = maxf(hue_drift, absf(fposmod(own.h - c.h + 0.5, 1.0) - 0.5))
		var share := float(lit_up) / float(maxi(solid, 1))
		check(share >= 0.003, "%s: its sheet holds the accent (%.1f%% of it)" % [id, share * 100.0])
		check(share <= 0.2, "%s: the accent is a part of it, not the whole (%.1f%%)" % [id, share * 100.0])
		if lit_up > 0:
			check(gain_s / lit_up > 0.08, "%s: the accent is more saturated than the room's light leaves it (%.2f)" % [id, gain_s / lit_up])
			check(gain_v / lit_up > 0.08, "%s: and lighter (%.2f)" % [id, gain_v / lit_up])
			check(hue_drift < 0.03, "%s: in the hue it was painted" % id)
		# What is not the accent is as it was: the outline, the white, a grey.
		for c: Color in [Color.BLACK, Color.WHITE, Color(0.4, 0.4, 0.4), Color("3a4450")]:
			check(FoeLight.lit(c, "tower", id).is_equal_approx(FoeLight.lit(c, "tower")), "%s: %s is lit as before" % [id, c.to_html(false)])
		var mat := FoeLight.material_for("tower", id)
		check(mat != FoeLight.material_for("tower"), "%s has a material of its own" % id)
		check(mat == FoeLight.material_for("tower", id), "%s: one per foe and zone" % id)
		var acc: Vector4 = mat.get_shader_parameter("accent")
		var lift: Vector2 = mat.get_shader_parameter("lift")
		check(acc.is_equal_approx(Vector4(a[0], a[1], a[2], a[3])) and lift.is_equal_approx(Vector2(a[4], a[5])), "%s: the shader has its numbers" % id)
		check(is_equal_approx(mat.get_shader_parameter("band_soft"), FoeLight.BAND_SOFT)
			and is_equal_approx(mat.get_shader_parameter("floor_soft"), FoeLight.FLOOR_SOFT), "%s: and the falloffs" % id)

	# A foe with no accent shares the zone's material, and is lit as before.
	for id: String in ["lantern_ghost", "crystal_dwarf", "bog_puffcap", "bark_knight", "spring_eel", ""]:
		check(not FoeLight.ACCENTS.has(id), "%s has no accent" % id)
		check(FoeLight.material_for("haar", id) == FoeLight.material_for("haar"), "%s shares the zone's material" % id)
		check(FoeLight.lit(Color(0.9, 0.5, 0.1), "haar", id).is_equal_approx(FoeLight.lit(Color(0.9, 0.5, 0.1), "haar")), "%s is lit as before" % id)
	var plain_mat := FoeLight.material_for("haar")
	check(is_zero_approx((plain_mat.get_shader_parameter("accent") as Vector4).y if plain_mat.get_shader_parameter("accent") != null else 0.0), "the zone's material has no band")
	check(FoeLight.material_for("gym", "hornet") == null, "and outside a zone a foe still draws as painted")
	check(FoeLight.lit(Color(0.9, 0.6, 0.1), "gym", "hornet") == Color(0.9, 0.6, 0.1), "accent and all")

	# The band: inside it the whole lift, past its soft edge nothing; a dull or a
	# dark pixel of the same hue does not count.
	var horn := Color.from_hsv(35.0 / 360.0, 0.8, 0.8)
	check(is_equal_approx(FoeLight.accent_at(horn, "blinkhop"), 1.0), "the Blinkhop's horn is its accent")
	check(is_zero_approx(FoeLight.accent_at(Color.from_hsv(250.0 / 360.0, 0.8, 0.8), "blinkhop")), "its violet body is not")
	check(is_zero_approx(FoeLight.accent_at(Color.from_hsv(35.0 / 360.0, 0.3, 0.8), "blinkhop")), "nor a dull pixel in the band")
	check(is_zero_approx(FoeLight.accent_at(Color.from_hsv(35.0 / 360.0, 0.8, 0.3), "blinkhop")), "nor a dark one")
	var out := FoeLight.lit(horn, "tower", "blinkhop")
	check(out.s > horn.s and out.v > horn.v, "the horn comes out brighter than it was painted")
	check(FoeLight.lit(horn, "tower").s < horn.s, "where the room's light alone mutes it")

	# In a room: the foe rests in its own material, by its script's name.
	var room := _room("heartwood")
	var h := _hornet(room)
	await frames(2)
	check(FoeLight.id_of(h) == "hornet", "a foe is named by its script")
	check(h.material == FoeLight.material_for("heartwood", "hornet"), "a hornet in the Heartwood rests in its own light")
	check(h.material != FoeLight.material_for("heartwood"), "not the zone's plain one")


## Pass 612 (bible 12.89). The pass 610 grade: foes "sink into dark rooms", one
## "a dark smudge". A foe's mid tones take a fill, so its body stands a step
## above the room's shadows; its outline and its lights are as they were.
func test_a_foes_body_stands_above_the_rooms_dark() -> void:
	# The band: nothing for an outline or a light, the whole for a mid tone.
	check(is_zero_approx(FoeLight.fill_at(0.0)) and is_zero_approx(FoeLight.fill_at(FoeLight.FILL_LO)),
		"an outline takes no fill")
	check(is_equal_approx(FoeLight.fill_at(0.25), 1.0), "a mid tone takes the whole fill")
	check(is_zero_approx(FoeLight.fill_at(FoeLight.FILL_END)) and is_zero_approx(FoeLight.fill_at(1.0)),
		"a light takes none")
	check(FoeLight.FILL_GAIN >= 0.25 and FoeLight.FILL_GAIN <= 0.6, "the fill shows, and is not a wash")

	for zone: String in Backdrop.ZONE_HAZE:
		var deep := FoeLight.deep_for(zone)
		var haze: Color = Backdrop.ZONE_HAZE[zone]
		# A mid grey: what the mute and the sink leave of it, and what the fill adds.
		var mid := Color(0.25, 0.25, 0.25)
		var sunk := mid.lerp(deep, FoeLight.sink_at(0.25))
		var out := FoeLight.lit(mid, zone)
		check(FoeLight.luma(out) > FoeLight.luma(sunk) + 0.08, "%s: a mid tone is lit (%.2f from %.2f)" % [zone, FoeLight.luma(out), FoeLight.luma(sunk)])
		check(FoeLight.luma(out) > FoeLight.luma(haze), "%s: and stands above the room's shadows" % zone)
		check(FoeLight.luma(out) < 0.45, "%s: but is still a mid tone" % zone)
		# The fill is the room's light: a grey leans to the zone's hue, never away.
		var tint := FoeLight.fill_tint(zone)
		check(maxf(tint.r, maxf(tint.g, tint.b)) == 1.0 and minf(tint.r, minf(tint.g, tint.b)) >= 0.5,
			"%s: the fill is a pale light in the zone's hue" % zone)
		# No tone passes another: a lighter paint never comes out darker.
		var last := -1.0
		var ordered := true
		for i in 101:
			var g := i / 100.0
			var l := FoeLight.luma(FoeLight.lit(Color(g, g, g), zone))
			if l < last - 0.0005:
				ordered = false
			last = l
		check(ordered, "%s: the tones keep their order" % zone)

	# The material carries the fill.
	var mat := FoeLight.material_for("vorrhallow")
	var tint_v := FoeLight.fill_tint("vorrhallow")
	check((mat.get_shader_parameter("fill") as Vector2).is_equal_approx(Vector2(FoeLight.FILL_GAIN, FoeLight.FILL_ADD)),
		"the shader has the fill's gain and add")
	check((mat.get_shader_parameter("fill_tint") as Vector3).is_equal_approx(Vector3(tint_v.r, tint_v.g, tint_v.b)),
		"and the zone's tint")
	check((mat.get_shader_parameter("fill_band") as Vector4).is_equal_approx(
		Vector4(FoeLight.FILL_LO, FoeLight.FILL_FULL, FoeLight.FILL_HOLD, FoeLight.FILL_END)), "and its band")
	check((FoeLight.material_for("vorrhallow", "shade_knight").get_shader_parameter("fill") as Vector2).is_equal_approx(
		Vector2(FoeLight.FILL_GAIN, FoeLight.FILL_ADD)), "a foe with an accent is filled too")

	# Every sheet foe: the middle of its body stands above the dark of the
	# darkest and the lightest halls, and its outline has not moved.
	var dir := DirAccess.open("res://scripts/enemies")
	var seen := 0
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var id := file.get_basename()
		var path := "res://assets/sprites/%s.png" % id
		if not ResourceLoader.exists(path) or not FileAccess.file_exists("res://assets/sprites/%s.json" % id):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % id))
		var cell: Array = meta["cell"]
		var img: Image = (load(path) as Texture2D).get_image()
		var lumas: Array[float] = []
		var plain: Array[float] = []
		for y in range(0, int(cell[1]), 2):
			for x in range(0, int(cell[0]), 2):
				var c := img.get_pixel(x, y)
				if c.a < 0.8:
					continue
				lumas.append(FoeLight.luma(FoeLight.lit(c, "vorrhallow", id)))
				plain.append(FoeLight.luma(c))
		if lumas.size() < 40:
			continue
		seen += 1
		lumas.sort()
		plain.sort()
		var mid_lit := lumas[lumas.size() / 2]
		check(mid_lit > FoeLight.luma(Backdrop.ZONE_HAZE["vorrhallow"]) + 0.06,
			"%s: half its body stands a step above Vorrhallow's dark (%.2f)" % [id, mid_lit])
		check(mid_lit < plain[plain.size() / 2] + 0.12, "%s: and is not washed out (%.2f from %.2f)" % [id, mid_lit, plain[plain.size() / 2]])
		check(lumas[0] < 0.12, "%s: its outline is still an outline (%.2f)" % [id, lumas[0]])
	check(seen >= 20, "the sheet foes were all looked at (%d)" % seen)
