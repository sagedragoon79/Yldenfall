extends TestSuite
## Crucible (pass 543, bible 12.35): the Smelter's great crucible is painted in
## whole world pixels on master palette ramps, lit from the upper left, where the
## pass 540 grade saw "the smelter's clean vector lava cauldron".


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell.
func _pixels() -> Dictionary:
	var img := Crucible.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + Crucible.IMG.position] = c
	return out


## Every tone the crucible uses is a master palette value.
func test_crucible_tones_are_master_palette() -> void:
	var palette := _palette()
	for tone: Color in Crucible.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))


## The baked image is pixel art: every pixel fully opaque or clear, and every
## colour one of the crucible's own tones (no blended polygon edges).
func test_crucible_bakes_only_its_own_tones() -> void:
	var img := Crucible.build_image()
	var tones := {}
	for tone: Color in Crucible.TONES:
		tones[tone.to_html(false)] = true
	var stray := 0
	var opaque := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			opaque += 1
			if c.a < 1.0 or not tones.has(c.to_html(false)):
				stray += 1
	check(opaque > 3000, "the pot, chains and trough are drawn (%d px)" % opaque)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)


## The pot is shaded on a ramp lit from the upper left: it uses all four iron
## tones, its upper-left half is brighter than its lower right, and the metal's
## glow is caught on the side facing the trough.
func test_crucible_pot_is_lit_from_the_upper_left() -> void:
	var px := _pixels()
	var used := {}
	var lit := [0.0, 0]
	var shade := [0.0, 0]
	var bounce := 0
	for c: Vector2i in px:
		var q := Crucible.local(c)
		if not Crucible.in_bowl(q) or Crucible.in_mouth(q, Crucible.RIM):
			continue
		var col: Color = px[c]
		used[col.to_html(false)] = true
		if col == Crucible.BOUNCE or col == Crucible.BOUNCE_HOT:
			bounce += 1
			check(q.x > 0.0 or q.y > Crucible.BOWL_RY * 0.6, "the glow is caught low and on the trough's side (%s)" % q)
		var w := Vector2(c) - Crucible.POT
		var into := lit if w.x + w.y < 0.0 else shade
		into[0] += col.get_luminance()
		into[1] += 1
	for tone: Color in Crucible.IRON:
		check(used.has(tone.to_html(false)), "the bowl uses iron #%s" % tone.to_html(false))
	check(lit[1] > 200 and shade[1] > 200, "both halves of the bowl are drawn")
	check(lit[0] / lit[1] > shade[0] / shade[1] + 0.05, "the upper left is brighter (%.2f) than the lower right (%.2f)" % [lit[0] / lit[1], shade[0] / shade[1]])
	check(bounce > 10, "the molten glow is caught on the pot's lower edge (%d px)" % bounce)


## The outline is selective: it closes the shadow side and the underside, and
## leaves the lit upper-left edge of the bowl bare against the dark.
func test_crucible_outline_is_selective() -> void:
	var px := _pixels()
	var lit_side := 0
	var dark_side := 0
	for c: Vector2i in px:
		if px[c] != Crucible.OUTLINE:
			continue
		var q := Crucible.local(c)
		var near_bowl := q.y >= 0.0 and pow(q.x / (Crucible.POT_RX + 2.0), 2) + pow(q.y / (Crucible.BOWL_RY + 2.0), 2) <= 1.0
		if not near_bowl:
			continue
		var w := Vector2(c) - Crucible.POT
		if w.x + w.y < -20.0:
			lit_side += 1
		elif w.x + w.y > 20.0:
			dark_side += 1
	check(dark_side > 40, "the shadow side is outlined (%d px)" % dark_side)
	check(lit_side * 3 < dark_side, "the lit side mostly isn't (%d against %d)" % [lit_side, dark_side])


## The metal moves in palette steps: the surface, the stream and the channel
## use only the heat ramp, the surface rolls between frames, and the stream
## pours unbroken from the lip to the trough.
func test_crucible_metal_rolls_in_palette_steps() -> void:
	var heat := {}
	for tone: Color in Crucible.HEAT:
		heat[tone.to_html(false)] = true
	var cells := Crucible.mouth_cells()
	check(cells.size() > 500, "the mouth is full of metal (%d px)" % cells.size())
	var changed := 0
	var crust := 0
	for m: Array in cells:
		var a := Crucible.molten_tone(m[1], m[2], 0.0)
		var b := Crucible.molten_tone(m[1], m[2], 0.5)
		check(heat.has(a.to_html(false)), "a surface tone is on the heat ramp")
		if a != b:
			changed += 1
		if a == Crucible.HEAT[1]:
			crust += 1
	check(changed > cells.size() / 10, "the surface rolls (%d px change)" % changed)
	check(crust > 10 and crust < cells.size() / 3, "a skin of crust floats on it (%d px)" % crust)
	var rows := {}
	for s: Array in Crucible.stream_cells(0.3):
		check(heat.has(s[1].to_html(false)), "a stream tone is on the heat ramp")
		rows[s[0].y] = true
	var top := floori(Crucible.lip_at().y)
	var gaps := 0
	for y in range(top, -10):
		if not rows.has(y):
			gaps += 1
	check(gaps == 0, "the stream runs unbroken from the lip to the trough (%d gaps)" % gaps)
	check(Crucible.channel_tone(int(Crucible.lip_at().x) + 4, 0, 0.0).get_luminance() > Crucible.channel_tone(-Crucible.TROUGH_W / 2 + 5, 0, 0.0).get_luminance(), "the channel is hottest where the stream lands")
