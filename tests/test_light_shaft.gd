extends TestSuite
## Light shafts (design bible 12.17): the pure geometry of the god-ray overlay —
## how many beams a room carries, where they fall, and the across/along falloff
## that feathers each one — so the drawn effect is backed by tested maths. The
## overlay itself is additive and drawn behind the tiles (LightShaft), so these
## cover the numbers, not the GPU draw.


func test_wider_rooms_carry_more_beams_within_bounds() -> void:
	check(LightShaft.beam_count(80.0) == LightShaft.MIN_BEAMS, "a tiny room floors at MIN_BEAMS")
	check(LightShaft.beam_count(100000.0) == LightShaft.MAX_BEAMS, "a huge room caps at MAX_BEAMS")
	var narrow := LightShaft.beam_count(400.0)
	var wide := LightShaft.beam_count(1000.0)
	check(wide >= narrow, "a wider room carries at least as many beams")
	check(narrow >= LightShaft.MIN_BEAMS and wide <= LightShaft.MAX_BEAMS, "always in range")


func test_beam_centres_count_and_stay_off_the_edges() -> void:
	var width := 900.0
	var centers := LightShaft.beam_centers(width, "heartwood/spring".hash())
	check(centers.size() == LightShaft.beam_count(width), "one centre per beam")
	for cx: float in centers:
		check(cx >= LightShaft.MARGIN and cx <= width - LightShaft.MARGIN,
			"every beam centre stays inside the margins")


func test_beam_centres_are_deterministic_but_not_a_mechanical_comb() -> void:
	var width := 900.0
	var a := LightShaft.beam_centers(width, 12345)
	var b := LightShaft.beam_centers(width, 12345)
	check(a == b, "the same width and seed give the same layout (stable across frames and saves)")
	var other := LightShaft.beam_centers(width, 999)
	check(a != other, "a different seed gives a different layout")
	# The jitter pushes the beams off a perfectly even comb.
	var lo := LightShaft.MARGIN
	var hi := width - LightShaft.MARGIN
	var span := hi - lo
	var n := a.size()
	var any_jittered := false
	for i in n:
		var even := lo + span * (float(i) + 0.5) / float(n)
		if absf(a[i] - even) > 1.0:
			any_jittered = true
	check(any_jittered, "at least one beam is nudged off the mechanical even spacing")


func test_a_room_narrower_than_two_margins_gets_one_centred_beam() -> void:
	var width := LightShaft.MARGIN  # narrower than 2 * MARGIN
	var centers := LightShaft.beam_centers(width, 7)
	check(centers.size() == 1, "a very narrow room gets a single beam")
	check_near(centers[0], width * 0.5, 0.01, "down the middle")


func test_across_profile_is_bright_at_the_core_and_gone_by_the_edge() -> void:
	check_near(LightShaft.across_alpha(0.0, LightShaft.HALF), 1.0, 0.001, "full at the centre")
	check_near(LightShaft.across_alpha(LightShaft.HALF, LightShaft.HALF), 0.0, 0.001, "nothing at the edge")
	check_near(LightShaft.across_alpha(2.0 * LightShaft.HALF, LightShaft.HALF), 0.0, 0.001,
		"nothing beyond the edge")
	var near := LightShaft.across_alpha(5.0, LightShaft.HALF)
	var far := LightShaft.across_alpha(25.0, LightShaft.HALF)
	check(near > far, "the profile falls off from the core outward")


func test_along_profile_fades_in_at_the_ceiling_and_dims_to_the_floor() -> void:
	check_near(LightShaft.along_alpha(0.0), 0.0, 0.001, "a soft onset at the very top, not a hard line")
	check_near(LightShaft.along_alpha(LightShaft.HEAD), 1.0, 0.001, "full once the head has faded in")
	check_near(LightShaft.along_alpha(1.0), LightShaft.TAIL, 0.001, "dimmed to the tail at the floor")
	check(LightShaft.along_alpha(0.5) > LightShaft.along_alpha(0.95),
		"a beam is brighter higher up than lower down")
	check(LightShaft.TAIL > 0.0, "the beam still carries some light to the floor")


func test_every_shipped_zone_has_bright_shaft_light_and_the_gym_has_none() -> void:
	for z: String in LightShaft.SHAFTS:
		var spec: Dictionary = LightShaft.SHAFTS[z]
		var col: Color = spec["color"]
		var lum := col.r * 0.299 + col.g * 0.587 + col.b * 0.114
		check(lum > 0.75, "%s shaft light is bright, so the additive draw adds light not dark" % z)
		check(absf(spec["slope"]) > 0.0 and absf(spec["slope"]) < 0.5, "%s lean is gentle" % z)
	check(not LightShaft.SHAFTS.has("gym"), "the gym gets no shafts")


func test_paired_zones_lean_opposite_ways() -> void:
	# Each family's two zones alternate lean so they never cast one identical rake.
	for pair: Array in [["hearthroot", "spires"], ["heartwood", "boughs"], ["haar", "sunken"],
			["evercrown", "vorrhallow"], ["tower", "trials"]]:
		var a: float = LightShaft.SHAFTS[pair[0]]["slope"]
		var b: float = LightShaft.SHAFTS[pair[1]]["slope"]
		check(signf(a) != signf(b), "%s and %s lean opposite ways" % [pair[0], pair[1]])


func test_the_canopys_air_is_shaded_and_the_sun_falls_through_it() -> void:
	# Design bible 12.152: a sunlit zone's air lies in shade under its roof of
	# leaves and its shafts are the sun through it, so the air is not one flat wash.
	check(not LightShaft.CANOPY.is_empty(), "a zone has a canopy")
	for z: String in LightShaft.CANOPY:
		check(Backdrop.ZONE_AIR.has(z), "%s is a sunlit zone (day air, 12.112)" % z)
		check(LightShaft.SHAFTS.has(z), "%s has shafts to fall through its shade" % z)
		var top := LightShaft.shade_at(z, 0.0)
		var top_lum := top.r * 0.299 + top.g * 0.587 + top.b * 0.114
		check(top_lum < 0.85, "%s air is in shade under its roof (%.2f)" % [z, top_lum])
		check(top_lum > 0.6, "%s shade is a shade, not a night (%.2f)" % [z, top_lum])
		var depth: float = LightShaft.CANOPY[z]["depth"]
		check(LightShaft.shade_at(z, depth).is_equal_approx(Color.WHITE),
			"%s shade clears by its depth" % z)
		check(LightShaft.shade_at(z, 1.0).is_equal_approx(Color.WHITE), "%s floor is untouched" % z)
		var last := -1.0
		var steady := true
		for i in 21:
			var c := LightShaft.shade_at(z, float(i) / 20.0)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum < last - 0.0001:
				steady = false
			last = lum
		check(steady, "%s shade only lightens going down" % z)
		# The sun has to read against the pale day air: twice the default strength.
		check(LightShaft.peak_for(z) >= LightShaft.PEAK * 2.0, "%s shafts are strong enough to see" % z)
		check(LightShaft.half_for(z) >= LightShaft.HALF, "%s shafts are no narrower" % z)
	check(LightShaft.shade_at("tower", 0.0).is_equal_approx(Color.WHITE), "a roofed zone has no canopy shade")
	check(is_equal_approx(LightShaft.peak_for("tower"), LightShaft.PEAK), "other zones keep the default peak")
	check(is_equal_approx(LightShaft.half_for("tower"), LightShaft.HALF), "other zones keep the default width")


func test_a_canopy_zones_shafts_carry_a_multiplied_shade_behind_them() -> void:
	for z: String in ["boughs", "tower"]:
		var shaft := LightShaft.new()
		shaft.zone = z
		shaft.room_size = Vector2(640, 360)
		shaft.seed = 7
		arena.add_child(shaft)
		var shade := shaft.get_node_or_null("CanopyShade") as Node2D
		if z == "boughs":
			check(shade != null, "the Boughs' shafts carry a canopy shade")
			if shade != null:
				var mat := shade.material as CanvasItemMaterial
				check(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_MUL,
					"the shade multiplies the air, so it only darkens")
				check(shade.show_behind_parent, "the shade draws under the beams")
		else:
			check(shade == null, "the Tower's shafts carry no canopy shade")
