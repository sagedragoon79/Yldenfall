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
	for c: Node in stalk.get_children():
		check(c is VeinGlow, "scenery only: nothing to touch or to be hurt by, only its light (%s)" % c.name)
	check(FileAccess.get_file_as_string("res://levels/evercrown/veins.room").contains("runs up these veins to the core"), "the sign still tells of the light that runs up to the core")
	check(BloomStalk._baked != null, "the stalk is baked once for the whole run")


func _veins_grid() -> Array[String]:
	var rows: Array[String] = []
	var text := FileAccess.get_file_as_string("res://levels/evercrown/veins.room").replace("\r", "")
	for line: String in text.split("---\n")[1].split("\n"):
		if line != "":
			rows.append(line)
	return rows


## The independent grade after pass 575: "most rooms are a rectangular tile
## frame around a dead-level floor". The sixth room changed for it (12.63's
## rule, pass 581), and the first shaft. The stalk's roots have heaved the
## floor: a hump west of them, and east of them a bank a tile up and a second
## two up. The vault is a vault: it steps down from the crown to both walls,
## lowest in the west corner. The stalk's own floor and the stone over its
## crown are as they were, and so is every shelf and vein of the climb.
func test_the_veins_are_not_a_level_box() -> void:
	var grid := _veins_grid()
	check(grid.size() == 68 and grid[0].length() == 40, "the shaft keeps its size")
	var wide := grid[0].length()
	var back := char(92)
	var slopes := "/" + back
	var floors := {}
	var ceilings := {}
	var floor_of: Array[int] = []
	var top_of: Array[int] = []
	var ramps: Array[Vector2i] = []
	for x in wide:
		var y := grid.size() - 1
		while y > 0 and ("#" + slopes).contains(grid[y][x]):
			y -= 1
		floor_of.append(y)
		var top := 0
		while top < grid.size() and grid[top][x] == "#":
			top += 1
		top_of.append(top)
		for row in grid.size():
			if slopes.contains(grid[row][x]):
				ramps.append(Vector2i(x, row))
		if x == 0 or x == wide - 1:
			continue  # the walls
		ceilings[top] = true
		if not slopes.contains(grid[y + 1][x]):
			floors[y] = true
	var level := 65
	check(floor_of[1] == level and grid[level][0] == "1" and grid[level - 3][0] == "1", "the west door opens on the old floor")
	check(floors.size() == 3, "the floor stands at three heights (%s)" % [floors.keys()])
	check(ceilings.size() >= 5, "the vault's underside stands at five heights (%s)" % [ceilings.keys()])
	# The stalk (12.59) is 256 px wide on the shaft's middle: tiles 12 to 27.
	for x in range(12, 28):
		check(floor_of[x] == level and top_of[x] == 4, "the stalk's floor and the stone over its crown are as they were at tile %d" % x)
	# The ramps.
	check(ramps.size() == 4, "four ramp tiles (%s)" % [ramps])
	if ramps.size() != 4:
		return
	for r: Vector2i in ramps:
		var high := -1 if grid[r.y][r.x] == back else 1
		check(grid[r.y + 1][r.x] == "#" and grid[r.y][r.x + high] == "#", "the ramp at %s has ground under it and on its high side" % r)
		check(grid[r.y][r.x - high] == ".", "and open floor at its foot")
	check(grid[ramps[0].y][ramps[0].x] == "/" and grid[ramps[1].y][ramps[1].x] == back and ramps[0].y == level and ramps[1].y == level, "a hump west of the roots, a ramp up and a ramp down")
	check(ramps[0].x > 8 and ramps[1].x < 12 and ramps[1].x - ramps[0].x <= 3, "between the door's landing and the stalk (tiles %d to %d)" % [ramps[0].x, ramps[1].x])
	check(grid[ramps[2].y][ramps[2].x] == "/" and ramps[2].y == level and ramps[2].x > 27, "east of the roots a ramp climbs to a bank (tile %d)" % ramps[2].x)
	check(grid[ramps[3].y][ramps[3].x] == "/" and ramps[3].y == level - 1 and ramps[3].x >= ramps[2].x + 4, "and a second climbs from the bank to the east wall's (tile %d)" % ramps[3].x)
	for x in range(ramps[2].x + 1, ramps[3].x):
		check(floor_of[x] == level - 1, "the bank stands a tile up at tile %d" % x)
	for x in range(ramps[3].x + 1, wide - 1):
		check(floor_of[x] == level - 2, "the east wall's bank stands two up at tile %d" % x)
	# The vault: highest over the crown, stepping down to both walls, lowest in the west.
	var steps_west := 0
	var steps_east := 0
	for x in range(1, wide - 2):
		if x < 12:
			check(top_of[x] >= top_of[x + 1], "the vault never rises toward the west wall (tile %d)" % x)
			steps_west += 1 if top_of[x] > top_of[x + 1] else 0
		elif x >= 27:
			check(top_of[x + 1] >= top_of[x], "nor toward the east wall (tile %d)" % x)
			steps_east += 1 if top_of[x + 1] > top_of[x] else 0
	check(steps_west >= 3 and steps_east >= 2, "it steps down three times to the west and twice to the east (%d and %d)" % [steps_west, steps_east])
	check(top_of[1] > top_of[wide - 2], "and hangs lowest in the west corner (%d rows against %d)" % [top_of[1], top_of[wide - 2]])
	# The east door, its shelf, and the air a jump to it needs.
	check(grid[8][wide - 1] == "2" and grid[11][wide - 1] == "2" and grid[12].substr(25, 14) == "--------------", "the east door and its shelf are where they were")
	for x in range(25, wide - 1):
		check(12 - top_of[x] >= 6, "six open rows over the shelf at tile %d" % x)
	# Nothing of the climb moved: the shelves, the veins, the sign.
	var planks := 0
	var veins: Array[Vector2i] = []
	var hazards := 0
	for row in grid.size():
		planks += grid[row].count("-")
		hazards += grid[row].count("^") + grid[row].count("o")
		for x in wide:
			if grid[row][x] == "x":
				veins.append(Vector2i(x, row))
	check(planks == 150, "every shelf of the climb is as it was (%d plank tiles)" % planks)
	check(veins == [Vector2i(21, 12), Vector2i(32, 21), Vector2i(21, 30), Vector2i(4, 39), Vector2i(14, 48), Vector2i(32, 57)], "the six veins are where they were (%s)" % [veins])
	check(hazards == 0, "no hazard in the floor: the fight is the veins")
	for x in range(18, 22):
		check(top_of[x] == 4 and grid[7][x] == ".", "the core hangs in open air at tile %d" % x)
	# Done for real: with the core starved, a walk east from the door crosses
	# the hump, passes the roots and climbs both banks with no jump.
	GameState.new_game()
	GameState.set_flag("boss:everbloom_veins")
	var w := make_world({}, "evercrown/veins", cell_feet(3, level))
	await frames(12)
	var p := w.player
	var from_y := p.global_position.y
	var hp := p.hp
	check(p.is_on_floor(), "in from the west door, the hero stands on the old floor")
	var on_hump := from_y
	var past_roots := -1.0
	p.input.move_x = 1
	var steps := 0
	while p.global_position.x < 37 * Room.TILE and steps < 900:
		await frames(1)
		steps += 1
		if p.global_position.x < 12 * Room.TILE:
			on_hump = minf(on_hump, p.global_position.y)
		elif p.global_position.x > 19 * Room.TILE and past_roots < 0.0:
			past_roots = p.global_position.y
	p.input.move_x = 0
	await frames(10)
	check(p.global_position.x >= 37 * Room.TILE, "a walk east from the west door reaches the east wall with no jump (x %.0f after %d frames)" % [p.global_position.x, steps])
	check_near(from_y - on_hump, float(Room.TILE), 2.0, "it goes over the hump, a tile up")
	check_near(past_roots, from_y, 2.0, "passes the roots on the old floor")
	check_near(from_y - p.global_position.y, 2.0 * Room.TILE, 2.0, "and ends two tiles up, on the east wall's bank")
	check(p.is_on_floor() and p.hp == hp, "unhurt")
	var stalk := _stalk(w.room)
	check(stalk != null and w.room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, 4)) and not w.room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -4)), "the stalk's roots still stand on the floor")
	check(stalk != null and w.room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -BloomStalk.HEIGHT - 4)) and not w.room.is_solid_at(stalk.position + Vector2(BloomStalk.AXIS, -BloomStalk.HEIGHT + 4)), "and its crown still meets the vault")
	w.queue_free()
	await frames(2)
	GameState.new_game()


## The pass 660 grade saw the Veins "in one purple": a wine backdrop, violet
## shelves and a violet stalk. The veins light the air of the shaft round the
## stalk in their own cool cyan (12.140): a column that turns the wine to the
## light's hue beside the stalk and leaves the walls' side of the shaft wine.
## It is the light in the channels, so it dims a step with each cut and is gone
## once the core is starved.
func test_the_veins_light_the_shaft_round_the_stalk() -> void:
	var palette := _palette()
	check(palette.has(VeinGlow.COLOR.to_html(false)), "the glow is a master palette tone (#%s)" % VeinGlow.COLOR.to_html(false))
	check(VeinGlow.COLOR == BloomStalk.LINE, "the light of a channel")
	var wine: Color = Backdrop.ZONE_HAZE["evercrown"]
	var lit := wine.lerp(VeinGlow.COLOR, VeinGlow.PEAK)
	var hue_gap := absf(lit.h - wine.h) * 360.0
	check(hue_gap >= 40.0 and hue_gap <= 320.0, "beside the stalk the wine turns to the light's hue (%.0f degrees off it)" % hue_gap)
	check(lit.get_luminance() > wine.get_luminance() * 1.4, "and is lighter: it is light, not fog (%.2f over %.2f)" % [lit.get_luminance(), wine.get_luminance()])
	check(lit.v < LightVein.SKY[5].v, "the veins stay the brightest things in the shaft")
	# The falloff: full round the axis, none at its reach, brighter toward the core, in clean steps.
	check(VeinGlow.strength(0, 900) == 1.0 or VeinGlow.strength(0, 900) >= 0.875, "full at the axis, high up")
	check(VeinGlow.strength(VeinGlow.REACH, 400) == 0.0 and VeinGlow.strength(-VeinGlow.REACH - 1, 400) == 0.0, "nothing at its reach")
	check(VeinGlow.strength(0, 0) < VeinGlow.strength(0, BloomStalk.HEIGHT), "brighter toward the core than at the floor")
	var last := 2.0
	var steps := {}
	for dx in range(0, VeinGlow.REACH + 1, 2):
		var s := VeinGlow.strength(dx, 500)
		check(s <= last, "it only fades going out (%d px)" % dx)
		last = s
		steps[s] = true
		check(is_equal_approx(s * VeinGlow.LEVELS, roundf(s * VeinGlow.LEVELS)), "in clean steps, no dither (%.3f)" % s)
	check(steps.size() >= 5, "a falloff, not a box (%d steps)" % steps.size())
	var tex := VeinGlow.texture()
	check(tex.get_width() == VeinGlow.REACH * 2 and tex.get_height() == BloomStalk.HEIGHT, "baked once, the stalk's height")
	# The shaft keeps its wine at the walls: the column is a band, not the room.
	var w := make_world({}, "evercrown/veins")
	await frames(2)
	var room: Room = w.room
	var stalk := _stalk(room)
	check(stalk != null and stalk.glow != null, "the stalk gives off its glow")
	if stalk == null or stalk.glow == null:
		w.queue_free()
		return
	var width := float(room.size_tiles.x * Room.TILE)
	var half_at := 0
	while VeinGlow.strength(half_at, 500) >= 0.5:
		half_at += 1
	check(half_at * 2 <= width / 3.0, "the glow is a column: at half strength or more over a third of the shaft at most (%d px of %d)" % [half_at * 2, int(width)])
	var wall := width * 0.5 - BloomStalk.AXIS - 4 * Room.TILE
	check(VeinGlow.strength(wall, 500) == 0.0 and VeinGlow.strength(-wall, 500) == 0.0, "and the four tiles off each wall stay wine")
	check(stalk.glow.z_index < -3 and not stalk.glow.z_as_relative, "behind the air's shade, the stalk, the tiles and every actor")
	check(is_equal_approx(stalk.glow.peak(), VeinGlow.PEAK), "every vein lit: the glow at full")
	var veins := stalk.veins()
	(veins[0] as LightVein).take_hit(1, Vector2.RIGHT)
	(veins[4] as LightVein).take_hit(1, Vector2.RIGHT)
	check(is_equal_approx(stalk.glow.peak(), VeinGlow.PEAK * 4.0 / 6.0), "two cut: two sixths of it gone (%.3f)" % stalk.glow.peak())
	w.queue_free()
	await frames(2)
	GameState.set_flag("boss:everbloom_veins")
	var after := Room.from_file("res://levels/evercrown/veins.room")
	arena.add_child(after)
	await frames(2)
	var dark := _stalk(after)
	check(dark != null and dark.glow != null and dark.glow.peak() == 0.0, "the core starved: the shaft is wine again")
	after.queue_free()
	GameState.new_game()
