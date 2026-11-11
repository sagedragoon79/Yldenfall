extends TestSuite
## LoreTablet: the engraved runes carved on a sign's face (pass 512). These
## cover the pure rule that lays the engraving out, so the drawing in _draw() is
## driven by tested logic. They replace the old row of identical flat "scribble"
## bars that the independent grade flagged as an un-authored UI stub in five
## rooms; a carved sign now reads as writing — several lines, each opening with
## an upright stem.


## Every stroke a sign carves stays within the slab's writing face.
func test_runes_stay_within_the_face() -> void:
	var face := LoreTablet.FACE.grow(0.02)
	for seed in range(40):
		for s: Array in LoreTablet.rune_strokes(seed):
			var r := Rect2(s[0], s[1], s[2], s[3])
			check(face.encloses(r), "seed %d: stroke %s stays within the face %s" % [seed, r, LoreTablet.FACE])


## A sign carves real writing: at least two lines, each opening with an upright
## stem — never the old row of identical flat bars (which had no verticals).
func test_runes_read_as_engraved_lines() -> void:
	for seed in range(40):
		var strokes := LoreTablet.rune_strokes(seed)
		var baselines := {}
		var uprights := 0
		for s: Array in strokes:
			if s[3] > s[2]:  # taller than wide: an upright stem
				uprights += 1
				baselines[roundi(s[1] + s[3])] = true  # the line it sits on
		check(baselines.size() >= 2, "seed %d: the runes fall on at least two lines (%d)" % [seed, baselines.size()])
		check(uprights >= 2, "seed %d: each line opens with an upright stem (%d stems)" % [seed, uprights])


## The carving is deterministic, and two different signs carve different runes
## (so the same stamp no longer repeats across rooms).
func test_runes_are_stable_and_per_sign() -> void:
	check(LoreTablet.rune_strokes(12345) == LoreTablet.rune_strokes(12345), "the same sign carves the same runes")
	check(LoreTablet.rune_strokes(1) != LoreTablet.rune_strokes(2), "two different signs carve different runes")


## Pass 539: every zone carves its own stele. Each zone with rooms has a look,
## and every look's tones are master palette values.
func test_stele_every_zone_has_a_look_in_the_palette() -> void:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data["colors"]:
		palette[c.trim_prefix("#").to_lower()] = true
	for zone: String in DirAccess.get_directories_at("res://levels"):
		check(LoreTablet.LOOKS.has(zone), "zone %s has a stele look" % zone)
	for zone: String in LoreTablet.LOOKS:
		var look: Dictionary = LoreTablet.LOOKS[zone]
		check(String(look["shape"]) in LoreTablet.SHAPES, "%s: a known shape (%s)" % [zone, look["shape"]])
		for key: String in look:
			if key in ["shape", "moss"]:
				continue
			check(palette.has(String(look[key]).to_lower()), "%s: %s #%s is a master palette tone" % [zone, key, look[key]])
	for hex: String in [LoreTablet.MOSS_LIT, LoreTablet.MOSS_DARK]:
		check(palette.has(hex), "moss #%s is a master palette tone" % hex)


## Every silhouette covers the recessed panel round the runes, stands on the
## plinth, and has a top that is not one flat line (the old slab was a box).
func test_stele_shapes_hold_the_panel_and_are_not_boxes() -> void:
	var panel := LoreTablet.FACE.grow(1.0)
	var outlines := {}
	for shape: String in LoreTablet.SHAPES:
		var cols := LoreTablet.profile(shape)
		var tops := {}
		for x in range(int(panel.position.x), int(panel.end.x)):
			check(cols.has(x), "%s: a column at x=%d behind the panel" % [shape, x])
			if cols.has(x):
				check(cols[x][0] < panel.position.y - 1.0, "%s: stone above the panel at x=%d (top %d)" % [shape, x, cols[x][0]])
				check(is_equal_approx(cols[x][1], LoreTablet.PLINTH.position.y), "%s: the column at x=%d stands on the plinth" % [shape, x])
		for x: int in cols:
			tops[cols[x][0]] = true
			check(x >= LoreTablet.PLINTH.position.x and x < LoreTablet.PLINTH.end.x, "%s: x=%d stays over the plinth" % [shape, x])
		check(tops.size() >= 2, "%s: the top is shaped, not one flat line (%d heights)" % [shape, tops.size()])
		outlines[str(cols)] = shape
	check(outlines.size() == LoreTablet.SHAPES.size(), "every shape has its own silhouette")
	var used := {}
	for zone: String in LoreTablet.LOOKS:
		used[LoreTablet.LOOKS[zone]["shape"]] = true
	check(used.size() == LoreTablet.SHAPES.size(), "every shape stands in some zone (%d of %d)" % [used.size(), LoreTablet.SHAPES.size()])


## A room's tablets take the room's zone, so the stele matches where it stands.
func test_stele_a_room_carves_its_zone_stele() -> void:
	var room := Room.from_text("zone: haar\nsign: 3, 3, Hello\n---\n########\n#......#\n#......#\n#......#\n########")
	arena.add_child(room)
	var tablet: LoreTablet = null
	for n in room.get_children():
		if n is LoreTablet:
			tablet = n
	check(tablet != null, "the room has its tablet")
	if tablet:
		check(tablet.zone == "haar", "it is carved for the Haar (%s)" % tablet.zone)
		check(LoreTablet.look_for(tablet.zone)["shape"] == "waystone", "a Haar tablet is a waystone")
	check(LoreTablet.look_for("nowhere") == LoreTablet.LOOKS["gym"], "an unknown zone falls back to the slate arch")
