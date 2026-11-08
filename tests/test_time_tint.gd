extends TestSuite
## TimeTint: the world's whole-scene colour grade (design bible 12.9) and the
## Stillstone's time-stop override. These drive the pure colour logic the modulate
## lerps toward, so the on-screen cast is backed by tested maths.

const SHIPPED := ["hearthroot", "heartwood", "tower", "haar", "boughs",
	"vorrhallow", "evercrown", "sunken", "spires"]


func _lum(a: Color) -> float:
	return a.r * 0.299 + a.g * 0.587 + a.b * 0.114


func test_every_shipped_zone_has_a_grade() -> void:
	# Every playable zone should carry its own cinematic cast, as ZONE_HAZE does for
	# the parallax fog (design bible 12.5, 12.9).
	for z: String in SHIPPED:
		check(TimeTint.GRADE.has(z), "%s has a colour grade" % z)


func test_an_unknown_zone_is_neutral() -> void:
	# The gym and any new zone get no grade, so the world draws exactly as painted.
	check(TimeTint.grade_for("gym").is_equal_approx(TimeTint.NEUTRAL),
		"a zone with no grade falls back to neutral white")
	check(TimeTint.NEUTRAL.is_equal_approx(Color.WHITE), "neutral is white (an identity multiply)")


func test_a_grade_actually_tints() -> void:
	# A grade must be a real cast, not white, or the pass does nothing.
	for z: String in SHIPPED:
		check(not TimeTint.grade_for(z).is_equal_approx(Color.WHITE),
			"%s grade is not pure white" % z)


func test_a_grade_keeps_the_scene_bright_and_readable() -> void:
	# The grade is a uniform multiply, so it must not crush any channel or darken the
	# scene — combat has to stay readable (Sean's 2026-11-07 request). Every channel
	# stays high and luminance stays near full.
	for z: String in SHIPPED:
		var g := TimeTint.grade_for(z)
		check(g.r >= 0.84 and g.g >= 0.84 and g.b >= 0.84,
			"%s grade keeps every channel high (no channel crushed)" % z)
		check(_lum(g) >= 0.9, "%s grade keeps the scene bright" % z)


func test_zones_differ_by_family() -> void:
	# The point of the pass: a warm hearth, a cold spring, a green wood and a crystal
	# hall must read as different light. Sample one zone per family.
	var warm := TimeTint.grade_for("hearthroot")
	var cold := TimeTint.grade_for("sunken")
	var green := TimeTint.grade_for("boughs")
	var violet := TimeTint.grade_for("evercrown")
	check(warm.r > cold.r and warm.b < cold.b, "the warm hearth cast is redder and less blue than the cold spring")
	check(green.g > warm.g and green.g > cold.g, "the canopy cast is the greenest")
	check(violet.r > green.r and violet.b > warm.b and violet.g < warm.g,
		"the crystal cast is magenta: high red and blue, low green")


func test_a_family_shares_one_grade() -> void:
	# Two zones of a family share a cast, as they share a fog colour, so the world
	# coheres (design bible 12.9).
	check(TimeTint.grade_for("hearthroot").is_equal_approx(TimeTint.grade_for("spires")),
		"the two warm hearths share one grade")
	check(TimeTint.grade_for("haar").is_equal_approx(TimeTint.grade_for("sunken")),
		"the two cold springs share one grade")


func test_the_stillstone_overrides_the_grade() -> void:
	# While time is held the world drains to the pale-blue stop tint whatever the zone,
	# so the Stillstone reads the same everywhere (8.A8).
	for z: String in SHIPPED:
		check(TimeTint.target_for(z, true).is_equal_approx(TimeTint.STOPPED),
			"%s drains to the stop tint while time is held" % z)
	check(not TimeTint.STOPPED.is_equal_approx(Color.WHITE), "the stop tint is a real cast")


func test_without_the_stillstone_the_target_is_the_zone_grade() -> void:
	for z: String in SHIPPED:
		check(TimeTint.target_for(z, false).is_equal_approx(TimeTint.grade_for(z)),
			"%s shows its own grade when time runs" % z)


func test_set_zone_tracks_the_room() -> void:
	var tint := TimeTint.new()
	tint.set_zone("haar")
	check(tint.zone == "haar", "set_zone records the current zone")
	check(TimeTint.target_for(tint.zone, false).is_equal_approx(TimeTint.grade_for("haar")),
		"the tint targets its zone's grade")
	tint.free()
