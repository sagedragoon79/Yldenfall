extends TestSuite
## BloomStalk (pass 572, bible 12.59): the Veins' sign told that "the light
## that fled the throne runs up these veins to the core", and the shaft showed
## six small crystals in the dark. The Everbloom's stalk stands up its back
## wall, and a channel of light on it goes dark with each vein that is cut.


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func _stalk(room: Node) -> BloomStalk:
	for n: Node in room.get_children():
		if n is BloomStalk:
			return n
	return null


func _image() -> Image:
	BloomStalk.bake()
	return BloomStalk._baked


## The opaque span of image row `row`: [first x, last x], or an empty array.
func _span(img: Image, row: int) -> Array:
	var first := -1
	var last := -1
	for x in img.get_width():
		if img.get_pixel(x, row).a > 0.0:
			if first < 0:
				first = x
			last = x
	return [] if first < 0 else [first, last]


## Every tone is a master palette value, and the baked image holds nothing else.
func test_bloom_stalk_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in BloomStalk.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	for tone: Color in [BloomStalk.LINE, BloomStalk.BEAD, BloomStalk.HEAD]:
		check(palette.has(tone.to_html(false)), "#%s (drawn live) is a master palette tone" % tone.to_html(false))
	var img := _image()
	var stray := 0
	var opaque := 0
	var used := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			opaque += 1
			used[c.to_html(false)] = true
			if c.a < 1.0 or not tones.has(c.to_html(false)):
				stray += 1
	check(stray == 0, "the baked stalk holds only its tones, each whole (%d stray)" % stray)
	check(opaque > 40000, "and it is a trunk, not a thread (%d pixels)" % opaque)
	check(used.size() == BloomStalk.TONES.size(), "it uses its flesh, its creases, its grooves and its outline (%d tones)" % used.size())
	# Nothing on it is as bright as a vein's crystal, or red like a thing that hurts.
	var brightest := 0.0
	for tone: Color in BloomStalk.TONES + [BloomStalk.LINE, BloomStalk.BEAD, BloomStalk.HEAD]:
		brightest = maxf(brightest, tone.v)
		check(not (tone.r > tone.b * 1.5 and tone.r > 0.4), "#%s is not a hazard's red" % tone.to_html(false))
	check(brightest < LightVein.SKY[5].v, "the veins stay the brightest things in the shaft (%.2f under %.2f)" % [brightest, LightVein.SKY[5].v])


## Three strands, braided, from roots that spread on the floor to a crown that
## spreads in the vault.
func test_bloom_stalk_is_a_braid_from_the_floor_to_the_vault() -> void:
	var img := _image()
	check(img.get_height() == BloomStalk.HEIGHT and BloomStalk.STRANDS == 3, "three strands, as tall as the shaft")
	# Every strand passes in front of the others and behind them, over and over.
	for k in BloomStalk.STRANDS:
		var turns := 0
		var was := BloomStalk.strand_depth(k, 0.0) > 0.0
		for h in range(1, BloomStalk.HEIGHT):
			var front := BloomStalk.strand_depth(k, float(h)) > 0.0
			if front != was:
				turns += 1
				was = front
		check(turns >= 6, "strand %d crosses in front and behind (%d times)" % [k, turns])
	# No row is empty, and the trunk is one mass: thick in the middle, wide at both ends.
	var gaps := 0
	var mid := 0.0
	var mid_rows := 0
	for row in img.get_height():
		var s := _span(img, row)
		if s.is_empty():
			gaps += 1
		elif row > 200 and row < BloomStalk.HEIGHT - 200:
			mid += s[1] - s[0] + 1
			mid_rows += 1
	check(gaps == 0, "it is unbroken from the floor to the vault (%d empty rows)" % gaps)
	mid /= maxf(1.0, mid_rows)
	check(mid >= 36.0 and mid <= 64.0, "its trunk is about as thick as the hero is tall (%.0f px)" % mid)
	var foot := _span(img, BloomStalk.HEIGHT - 2)
	var head := _span(img, 1)
	check(foot[1] - foot[0] > mid * 2.5, "its roots spread on the floor (%d px)" % (foot[1] - foot[0]))
	check(head[1] - head[0] > mid * 2.5, "and its crown spreads in the vault (%d px)" % (head[1] - head[0]))
	check(BloomStalk.root_flare(0.0) == 1.0 and BloomStalk.root_flare(BloomStalk.ROOT + 1.0) == 0.0, "the roots flare only at the foot")
	check(BloomStalk.crown_flare(float(BloomStalk.HEIGHT)) == 1.0 and BloomStalk.crown_flare(BloomStalk.HEIGHT - BloomStalk.CROWN - 1.0) == 0.0, "and the crown only at the head")
	# An outline wherever the flesh meets the air.
	var bare := 0
	for row in range(0, img.get_height(), 3):
		var s := _span(img, row)
		if img.get_pixel(s[0], row) != BloomStalk.OUTLINE or img.get_pixel(s[1], row) != BloomStalk.OUTLINE:
			bare += 1
	check(bare == 0, "its edge is outlined (%d rows bare)" % bare)


## Lit from the upper left: each strand's left side is lit and its right in
## shadow, and a strand throws its shadow on the one behind it.
func test_bloom_stalk_is_lit_from_the_upper_left() -> void:
	var img := _image()
	var lit_left := 0
	var dark_right := 0
	var rows := 0
	for row in range(200, BloomStalk.HEIGHT - 200):
		var s := _span(img, row)
		rows += 1
		var a := img.get_pixel(s[0] + 2, row)
		var b := img.get_pixel(s[1] - 2, row)
		if a == BloomStalk.FLESH[2] or a == BloomStalk.FLESH[3]:
			lit_left += 1
		if b == BloomStalk.FLESH[0]:
			dark_right += 1
	check(lit_left > rows * 0.8, "the trunk's left edge is lit (%d of %d rows)" % [lit_left, rows])
	check(dark_right > rows * 0.8, "and its right edge is in shadow (%d of %d rows)" % [dark_right, rows])
	check(BloomStalk.flesh_level(0, -0.7, 0, 1) >= 2 and BloomStalk.flesh_level(0, 0.0, 0, 1) == 1 and BloomStalk.flesh_level(0, 0.7, 0, 1) == 0, "across a strand: lit, body, shadow")
	var creases := 0
	var glints := 0
	for y in range(300, 500):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			creases += 1 if c == BloomStalk.CREASE else 0
			glints += 1 if c == BloomStalk.FLESH[3] else 0
	check(creases > 150, "creases ring the strands (%d pixels in 200 rows)" % creases)
	check(glints > 40 and glints < creases * 3, "and a broken glint runs up the lit side (%d pixels)" % glints)


## Six channels run the whole height, and beads of light climb them.
func test_bloom_stalk_has_a_channel_for_each_vein() -> void:
	var img := _image()
	check(BloomStalk.CHANNELS == BloomStalk.STRANDS * BloomStalk.CHANNEL_U.size(), "two channels a strand")
	for i in BloomStalk.CHANNELS:
		var pts := BloomStalk.channel(i)
		check(pts.size() > BloomStalk.HEIGHT * 0.5, "channel %d shows for most of the stalk's height (%d pixels)" % [i, pts.size()])
		if pts.size() < 2:
			continue
		var falls := 0
		var wrong := 0
		for p in pts.size():
			if p > 0 and pts[p].y > pts[p - 1].y:
				falls += 1
			if img.get_pixel(int(pts[p].x) - BloomStalk.IMG.position.x, int(pts[p].y) - BloomStalk.IMG.position.y) != BloomStalk.GROOVE:
				wrong += 1
		check(falls == 0, "its pixels run from the floor up")
		check(wrong == 0, "each is a groove in the baked stalk (%d are not)" % wrong)
		check(pts[0].y > -40.0 and pts[pts.size() - 1].y < -BloomStalk.HEIGHT + 40.0, "it runs from the roots to the crown (%.0f to %.0f)" % [pts[0].y, pts[pts.size() - 1].y])
		var seen := {}
		var climbed := 0
		for k in BloomStalk.BEADS:
			var a := BloomStalk.bead_at(i, k, 10)
			var b := BloomStalk.bead_at(i, k, 11)
			seen[a] = true
			check(a >= 0 and a < pts.size(), "bead %d stays on the channel" % k)
			if b > a:
				climbed += 1
		check(seen.size() == BloomStalk.BEADS, "no two beads together")
		check(climbed >= BloomStalk.BEADS - 1, "the beads climb toward the core (%d of %d rose in a step)" % [climbed, BloomStalk.BEADS])
	check(BloomStalk.STEP_FPS == LightVein.STEP_FPS, "the light steps at the veins' own rate")


## In the Veins a channel goes dark with each vein that is cut.
func test_the_veins_stalk_goes_dark_vein_by_vein() -> void:
	var w := make_world({}, "evercrown/veins")
	await frames(2)
	var room: Room = w.room
	var stalk := _stalk(room)
	check(stalk != null, "the Veins have the stalk")
	if stalk == null:
		return
	var veins := stalk.veins()
	check(veins.size() == BloomStalk.CHANNELS, "a channel for each of the room's veins (%d)" % veins.size())
	check(stalk.lit_mask() == (1 << BloomStalk.CHANNELS) - 1, "before a cut every channel carries light")
	for i in range(1, veins.size()):
		check(veins[i].position.y <= veins[i - 1].position.y, "channel %d is fed by a vein no lower than the one before" % i)
	(veins[0] as LightVein).take_hit(1, Vector2.RIGHT)
	check(not stalk.lit(0) and stalk.lit_mask() == ((1 << BloomStalk.CHANNELS) - 1) - 1, "cut the lowest vein and its channel alone goes dark")
	(veins[3] as LightVein).take_hit(1, Vector2.RIGHT)
	check(not stalk.lit(3) and stalk.lit(2) and stalk.lit(4), "cut another and its channel follows")
	check(not stalk.lit(-1) and not stalk.lit(BloomStalk.CHANNELS), "there is no seventh channel")
	# The light moves, and the Stillstone holds it.
	var t0 := stalk.t
	await frames(12)
	check(stalk.t > t0 + 0.1, "the light climbs")
	TimeStop.left = 5.0
	await frames(2)
	var held := stalk.t
	await frames(10)
	check(stalk.t == held, "and the Stillstone holds it, like the core's beams")
	TimeStop.left = 0.0
	w.queue_free()
	await frames(2)
	# Once the core is starved the veins stay cut, and the stalk dark.
	GameState.set_flag("boss:everbloom_veins")
	var after := Room.from_file("res://levels/evercrown/veins.room")
	arena.add_child(after)
	await frames(2)
	var dark := _stalk(after)
	check(dark != null and dark.lit_mask() == 0, "after the fight every channel is dark for good")
	GameState.new_game()


## In the Veins it stands up the middle of the shaft's back wall, from the
## floor to the vault, behind everything.
func test_the_veins_have_their_stalk() -> void:
	var w := make_world({}, "evercrown/veins")
	await frames(2)
	var room: Room = w.room
	var stalk := _stalk(room)
	check(stalk != null, "the Veins have the stalk")
	if stalk == null:
		return
	var width := float(room.size_tiles.x * Room.TILE)
	check(stalk.position.x + BloomStalk.AXIS == width * 0.5, "its axis is the middle of the shaft, under the core")
	check(room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, 4)) and not room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -4)), "its roots stand on the floor")
	check(room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -BloomStalk.HEIGHT - 4)) and not room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -BloomStalk.HEIGHT + 4)), "and its crown meets the vault")
	check(stalk.position.x + BloomStalk.IMG.position.x >= Room.TILE and stalk.position.x + BloomStalk.IMG.end.x <= width - Room.TILE, "it lies inside the shaft's walls")
	check(stalk.z_index < 0, "behind the hero, the veins and the shelves")
	for n: Node in room.get_children():
		if n is LightVein:
			check((n as LightVein).z_index > stalk.z_index, "a vein is drawn over it")
	check(stalk.get_child_count() == 0, "scenery only: nothing to touch or to be hurt by")
	check(FileAccess.get_file_as_string("res://levels/evercrown/veins.room").contains("runs up these veins to the core"), "the sign still tells of the light that runs up to the core")
	check(BloomStalk._baked != null, "the stalk is baked once for the whole run")
