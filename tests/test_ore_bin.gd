extends TestSuite
## OreBin (pass 574, bible 12.61): the Ore Bin's sign told of the chute, the
## winch and a bin "half full still", and the room showed none of them. The
## bin is the room's landmark, painted like the ore road (12.60).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell from the prop's origin.
func _pixels() -> Dictionary:
	var img := OreBin.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + OreBin.IMG.position] = c
	return out


func _bin(room: Node) -> OreBin:
	for n: Node in room.get_children():
		if n is OreBin:
			return n
	return null


## Every tone is a master palette value, and the baked image holds nothing else.
func test_ore_bin_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in OreBin.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	var img := OreBin.build_image()
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
	check(opaque > 12000, "the bin, its hopper and its chute are drawn (%d px)" % opaque)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)
	for tone: Color in OreBin.TONES:
		check(used.has(tone.to_html(false)), "the picture uses #%s" % tone.to_html(false))


## A plank box under a cap beam, on two posts that stand on stone footings.
func test_ore_bin_is_a_plank_box_on_posts() -> void:
	var px := _pixels()
	check(OreBin.BOX_FOOT - OreBin.BOX_TOP >= 64, "the box is tall (%d px)" % (OreBin.BOX_FOOT - OreBin.BOX_TOP))
	check((OreBin.BOX_FOOT - OreBin.BOX_TOP) % OreBin.PLANK == 0, "and whole planks high")
	check(OreBin.BOX_FOOT < -96, "it stands over every head on the floor (%d px up)" % -OreBin.BOX_FOOT)
	# Each plank: lit along its top, shaded along its bottom, a seam under it.
	var planks := (OreBin.BOX_FOOT - OreBin.BOX_TOP) / OreBin.PLANK
	var x := OreBin.BOX_HALF - 4  # east of the east strap, clear of the breach
	for k in planks:
		var y := OreBin.BOX_TOP + k * OreBin.PLANK
		# The cap beam's outline lies along the top plank's first row.
		check(px.get(Vector2i(x, y), Color.BLACK) == (OreBin.OUTLINE if k == 0 else OreBin.WOOD[2]), "plank %d is lit along its top" % k)
		check(px.get(Vector2i(x, y + OreBin.PLANK - 2), Color.BLACK) == OreBin.WOOD[0], "and shaded along its bottom")
		check(px.get(Vector2i(x, y + OreBin.PLANK - 1), Color.BLACK) == OreBin.OUTLINE, "with a seam under it")
	for side: int in [-1, 1]:
		var cx := side * OreBin.POST_X
		var name := "west" if side < 0 else "east"
		check(absi(cx) > OreBin.BOX_HALF, "the %s post stands outside the box" % name)
		var whole := true
		for y in range(OreBin.BOX_TOP + 1, -5):
			whole = whole and px.get(Vector2i(cx, y), Color.BLACK) in OreBin.WOOD
		check(whole, "and runs whole from the cap to its footing")
		check(px.get(Vector2i(cx - OreBin.POST_WIDE / 2, -60), Color.BLACK) == OreBin.WOOD[2], "lit down its left")
		check(px.get(Vector2i(cx + OreBin.POST_WIDE / 2 - 1, -60), Color.BLACK) == OreBin.WOOD[0], "shaded down its right")
		check(px.get(Vector2i(cx, -2), Color.BLACK) in OreBin.IRON, "on a stone footing")
		check(px.has(Vector2i(cx, -1)), "that sits on the floor")
	check(px.get(Vector2i(0, OreBin.BOX_TOP - OreBin.CAP_DEEP), Color.BLACK) == OreBin.WOOD[2], "a cap beam lies over the box")
	check(px.has(Vector2i(-OreBin.POST_X - 4, OreBin.BOX_TOP - 2)) and px.has(Vector2i(OreBin.POST_X + 4, OreBin.BOX_TOP - 2)), "and over both posts")
	var rivets := 0
	for c: Vector2i in px:
		if c.y >= OreBin.BOX_TOP and c.y < OreBin.BOX_FOOT and px[c] == OreBin.IRON[3]:
			rivets += 1
	check(rivets == planks * 2, "two iron straps, a rivet in each plank (%d)" % rivets)


## "The bin is half full still": through the sprung planks the ore lies to
## half the box's height, under a dark empty half.
func test_ore_bin_is_half_full() -> void:
	var px := _pixels()
	var mid := (OreBin.BOX_TOP + OreBin.BOX_FOOT) / 2
	check(OreBin.ORE_LINE == mid, "the ore stands at half the box's height")
	var sprung := OreBin.BREACH_PLANKS.y - OreBin.BREACH_PLANKS.x + 1
	check(sprung >= 3 and sprung <= 5, "%d planks have sprung" % sprung)
	check(OreBin.BOX_TOP + OreBin.BREACH_PLANKS.x * OreBin.PLANK < OreBin.ORE_LINE - 16, "the breach opens well over the ore")
	check(OreBin.BOX_TOP + (OreBin.BREACH_PLANKS.y + 1) * OreBin.PLANK >= OreBin.ORE_LINE + 4, "and reaches under its top")
	check(not OreBin.breached(0, OreBin.BOX_TOP) and not OreBin.breached(0, OreBin.BOX_FOOT - 1), "the top and bottom planks are whole")
	var ore := 0
	var dark := 0
	var wood := 0
	var ore_over := 0
	var dark_under := 0
	var ragged := {}
	for y in range(OreBin.BOX_TOP, OreBin.BOX_FOOT):
		var first := 1000
		for x in range(-OreBin.BOX_HALF, OreBin.BOX_HALF):
			if not OreBin.breached(x, y):
				continue
			first = mini(first, x)
			var c: Color = px.get(Vector2i(x, y), Color.WHITE)
			if c in OreBin.ORE:
				ore += 1
				if y < OreBin.ore_top(x):
					ore_over += 1
			elif c == OreBin.IRON[0] or c == OreBin.OUTLINE:
				dark += 1
				# The dark of the empty half is stone-1; an outline is a plank's edge or its shadow.
				if y > OreBin.ore_top(x) and c == OreBin.IRON[0]:
					dark_under += 1
			elif c in OreBin.WOOD:
				# The plank that hangs by one end crosses the breach's east side.
				wood += 1
		if first < 1000:
			ragged[first] = true
	check(ore > 120, "ore shows through the breach (%d px)" % ore)
	check(dark > 300, "under a dark, empty half (%d px)" % dark)
	check(ore_over == 0, "no ore above its top (%d)" % ore_over)
	check(dark_under == 0, "no hole in the ore (%d)" % dark_under)
	check(wood < 80, "what hangs across the breach hides little of it (%d px)" % wood)
	check(ragged.size() >= 3, "the sprung planks end raggedly (%d different ends)" % ragged.size())
	var lit := 0
	var lo := 1000
	var hi := -1000
	for x in range(OreBin.BREACH.x + 6, OreBin.BREACH.y - 8):
		lo = mini(lo, OreBin.ore_top(x))
		hi = maxi(hi, OreBin.ore_top(x))
		if px.get(Vector2i(x, OreBin.ore_top(x)), Color.BLACK) in [OreBin.ORE[2], OreBin.ORE[3]]:
			lit += 1
	check(lit >= OreBin.BREACH.y - OreBin.BREACH.x - 16, "the top of the ore is lit (%d px)" % lit)
	check(lo < hi and hi - lo <= 6, "and heaped a little under the chute (%d px)" % (hi - lo))
	check(OreBin.ore_top(OreBin.CHUTE_FOOT.x) == lo, "highest where the chute drops it")


## An iron hopper narrows under the box to a slide gate; the gate was left a
## crack open and a low spill lies on the floor under it.
func test_ore_bin_hopper_narrows_to_its_gate() -> void:
	var px := _pixels()
	check(OreBin.hopper_half(OreBin.BOX_FOOT) == OreBin.BOX_HALF, "the hopper hangs from the whole box")
	check(OreBin.hopper_half(OreBin.SPOUT_Y) == OreBin.SPOUT_HALF, "and narrows to the spout")
	var narrows := true
	var iron := 0
	for y in range(OreBin.BOX_FOOT + 1, OreBin.SPOUT_Y + 1):
		narrows = narrows and OreBin.hopper_half(y) <= OreBin.hopper_half(y - 1)
	check(narrows, "it only ever narrows")
	for y in range(OreBin.BOX_FOOT, OreBin.SPOUT_Y):
		for x in range(-OreBin.BOX_HALF, OreBin.BOX_HALF):
			var c: Color = px.get(Vector2i(x, y), Color.WHITE)
			if absi(x) < OreBin.hopper_half(y) and (c in OreBin.IRON or c == OreBin.RUST):
				iron += 1
	check(iron > 2400, "it is iron plate (%d px)" % iron)
	var y_mid := OreBin.BOX_FOOT + 12
	check(px.get(Vector2i(-OreBin.hopper_half(y_mid), y_mid), Color.BLACK) == OreBin.IRON[2], "lit down its left")
	check(px.get(Vector2i(OreBin.hopper_half(y_mid) - 1, y_mid), Color.BLACK) == OreBin.IRON[0], "shaded down its right")
	var rust_left := 0
	var rust_right := 0
	for c: Vector2i in px:
		if px[c] == OreBin.RUST:
			if c.x < -4:
				rust_left += 1
			else:
				rust_right += 1
	check(rust_right > 30 and rust_left == 0, "rusted in its shade only (%d, %d)" % [rust_right, rust_left])
	check(px.get(Vector2i(0, OreBin.SPOUT_Y), Color.BLACK) == OreBin.IRON[3], "a slide gate lies across the spout")
	check(px.get(Vector2i(OreBin.SPOUT_HALF + 10, OreBin.SPOUT_Y + 1), Color.BLACK) == OreBin.IRON[2], "with a lever out to the east")
	check(OreBin.SPOUT_Y + OreBin.GATE_DEEP < -40, "the gate is over every head (%d px up)" % -(OreBin.SPOUT_Y + OreBin.GATE_DEEP))
	# The thread of ore from the gate to the spill.
	var thread := 0
	for y in range(OreBin.SPOUT_Y + OreBin.GATE_DEEP + 1, -OreBin.SPILL_HIGH):
		for x in range(-4, 0):
			if px.get(Vector2i(x, y), Color.BLACK) in OreBin.ORE:
				thread += 1
	check(thread > 12 and thread < 40, "a thread of ore still falls from it (%d px)" % thread)
	# The spill.
	check(OreBin.spill_high(0) == OreBin.SPILL_HIGH, "the spill is highest under the spout")
	check(OreBin.spill_high(-OreBin.SPILL_HALF) == 0 and OreBin.spill_high(OreBin.SPILL_HALF) == 0, "and ends at its edges")
	check(OreBin.SPILL_HIGH <= 8, "it is low: nothing to stand on (%d px)" % OreBin.SPILL_HIGH)
	check(OreBin.SPILL_HALF < OreBin.POST_X - OreBin.POST_WIDE, "it lies between the posts")
	var spill := 0
	var floating := 0
	for x in range(-OreBin.SPILL_HALF, OreBin.SPILL_HALF + 1):
		for k in OreBin.spill_high(x):
			var c: Color = px.get(Vector2i(x, -1 - k), Color.BLACK)
			if c in OreBin.ORE:
				spill += 1
			else:
				floating += 1
	check(spill > 200 and floating == 0, "a heap of ore on the floor (%d px, %d not ore)" % [spill, floating])


## "Raw ore down the chute": a boxed chute comes down from the ceiling into
## the bin's mouth.
func test_ore_bin_chute_comes_down_from_the_ceiling() -> void:
	var px := _pixels()
	check(OreBin.CHUTE_TOP.y == OreBin.CEILING, "the chute starts at the ceiling")
	check(OreBin.CHUTE_FOOT.y == OreBin.BOX_TOP - OreBin.CAP_DEEP, "and ends on the bin's cap")
	check(absi(OreBin.CHUTE_FOOT.x) + OreBin.CHUTE_HALF < OreBin.BOX_HALF, "inside the box's width")
	check(OreBin.CHUTE_TOP.x < OreBin.CHUTE_FOOT.x, "it leans down from the west, where the ore chute is")
	check(OreBin.CHUTE_TOP.x - OreBin.CHUTE_HALF - 1 >= OreBin.IMG.position.x, "and stays in the picture")
	var whole := true
	var leans := true
	var bands := 0
	var was_band := false
	# The cap beam's outline lies over the chute's last row.
	for y in range(OreBin.CHUTE_TOP.y, OreBin.CHUTE_FOOT.y - 1):
		var cx := OreBin.chute_x(y)
		var c: Color = px.get(Vector2i(cx - OreBin.CHUTE_HALF, y), Color.BLACK)
		whole = whole and (c in OreBin.WOOD or c in OreBin.IRON)
		whole = whole and px.get(Vector2i(cx - OreBin.CHUTE_HALF - 1, y), Color.WHITE) == OreBin.OUTLINE
		leans = leans and OreBin.chute_x(y) >= OreBin.chute_x(maxi(y - 1, OreBin.CHUTE_TOP.y))
		var is_band: bool = c in OreBin.IRON
		if is_band and not was_band:
			bands += 1
		was_band = is_band
	check(whole, "it is whole and outlined all the way down")
	check(leans, "and only ever leans one way")
	check(bands >= 2 and bands <= 4, "bound with iron (%d bands)" % bands)
	var y := OreBin.CHUTE_TOP.y + 4
	check(px.get(Vector2i(OreBin.chute_x(y) - OreBin.CHUTE_HALF, y), Color.BLACK) == OreBin.WOOD[2], "lit down its left")
	check(px.get(Vector2i(OreBin.chute_x(y) + OreBin.CHUTE_HALF - 1, y), Color.BLACK) == OreBin.WOOD[0], "shaded down its right")


## "Sorted ore up the winch": the kibble hangs on its chain from the ceiling
## and sways at its end only.
func test_ore_bin_kibble_hangs_from_the_ceiling() -> void:
	var links := int(OreBin.CHAIN_LENGTH / 3.0)
	var top_moves := 0.0
	var lo := 1000.0
	var hi := -1000.0
	var length_kept := true
	for k in 80:
		var at := k * 0.2
		top_moves = maxf(top_moves, absf(OreBin.chain_point(0, at).x - OreBin.CHAIN_TOP.x))
		var tip := OreBin.chain_point(links, at)
		lo = minf(lo, tip.x)
		hi = maxf(hi, tip.x)
		length_kept = length_kept and tip.y == OreBin.CHAIN_TOP.y + links * 3.0
	check(length_kept, "the chain keeps its length")
	check(top_moves == 0.0, "the chain is still where it hangs")
	check(hi - lo >= 4.0 and hi - lo <= 10.0, "the kibble sways a little (%.0f px)" % (hi - lo))
	check(OreBin.CHAIN_TOP.y == OreBin.CEILING, "it hangs from the ceiling")
	check(lo - 10.0 > OreBin.POST_X + OreBin.POST_WIDE, "clear of the bin, to its east (%.0f px)" % (lo - 10.0 - OreBin.POST_X))
	check(OreBin.CHAIN_TOP.y + OreBin.CHAIN_LENGTH + 24.0 < -128.0, "over every head, even on the shelf beside it")


## In the room: the bin stands on solid floor in open air under the ceiling,
## clear of the ledges, and the sign tells of it.
func test_the_ore_bin_has_its_bin() -> void:
	var w := make_world({}, "tower/ore_bin")
	await frames(2)
	var bin := _bin(w.room)
	check(bin != null, "the Ore Bin has its bin")
	if bin == null:
		return
	var room: Room = w.room
	var at := bin.position
	for side: int in [-1, 1]:
		var name := "west" if side < 0 else "east"
		check(room.is_solid_at(at + Vector2(side * OreBin.POST_X, 4)), "the %s post stands on solid floor" % name)
		var buried := 0
		for y in range(OreBin.BOX_TOP - OreBin.CAP_DEEP, -2, 8):
			if room.is_solid_at(at + Vector2(side * (OreBin.POST_X + OreBin.POST_WIDE / 2 + 2), y)):
				buried += 1
		check(buried == 0, "and in open air (%d points in a wall)" % buried)
	check(room.is_solid_at(at + Vector2(OreBin.CHUTE_TOP.x, OreBin.CEILING - 4)), "the chute comes out of the ceiling")
	check(not room.is_solid_at(at + Vector2(OreBin.CHUTE_TOP.x, OreBin.CEILING + 4)), "into open air")
	check(room.is_solid_at(at + Vector2(0, 4)), "the spill lies on solid floor")
	check(room.is_solid_at(at + OreBin.CHAIN_TOP + Vector2(0, -4)), "the kibble's chain hangs from the ceiling")
	var kibble_in_wall := 0
	for y in range(4, int(OreBin.CHAIN_LENGTH) + 28, 8):
		for dx: int in [-14, 0, 14]:
			if room.is_solid_at(at + OreBin.CHAIN_TOP + Vector2(dx, y)):
				kibble_in_wall += 1
	check(kibble_in_wall == 0, "and the kibble swings in open air (%d points in a wall)" % kibble_in_wall)
	# No ledge and no chest stands in front of it: the landmark is seen whole.
	var covered := 0
	for y in range(OreBin.CEILING + 8, -8, 8):
		for x in range(-OreBin.POST_X - 6, OreBin.POST_X + 7, 8):
			var p := at + Vector2(x, y)
			if room.is_solid_at(p) or room.is_one_way_at(p):
				covered += 1
	check(covered == 0, "no wall or ledge stands across it (%d points)" % covered)
	var text := FileAccess.get_file_as_string("res://levels/tower/ore_bin.room")
	check(text.contains("Raw ore down the chute, sorted ore up the winch."), "the sign tells of the chute and the winch")
	check(text.contains("The bin is half full still."), "and of the bin, half full")
	check(bin.z_index < 0, "behind everyone who walks past")
	check(bin.get_child_count() == 0, "scenery only: nothing to stand on, to touch or to be hurt by")
	await frames(30)
	check(bin.t > 0.2, "its kibble moves")
