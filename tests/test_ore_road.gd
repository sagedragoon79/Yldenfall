extends TestSuite
## OreRoad (pass 573, bible 12.60): the Rail Gallery's sign told of the "ORE
## ROAD. Carts run east to the Haar cut", and the room showed no rail and no
## cart of its own. The road is the room's landmark, painted like the crucible
## (12.35) and the great gears (12.57).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell from the prop's origin.
func _pixels() -> Dictionary:
	var img := OreRoad.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + OreRoad.IMG.position] = c
	return out


func _road(room: Node) -> OreRoad:
	for n: Node in room.get_children():
		if n is OreRoad:
			return n
	return null


## Every tone is a master palette value, and the baked image holds nothing else.
func test_ore_road_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in OreRoad.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	var img := OreRoad.build_image()
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
	check(opaque > 30000, "the road, its bents and its cart are drawn (%d px)" % opaque)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)
	for tone: Color in OreRoad.TONES:
		check(used.has(tone.to_html(false)), "the picture uses #%s" % tone.to_html(false))


## The rail runs from wall to wall on its sleepers and stringer, but for the
## fallen span.
func test_ore_road_runs_the_length_of_the_gallery() -> void:
	var px := _pixels()
	var rail := 0
	var rail_in_gap := 0
	var stringer_in_gap := 0
	var missing := 0
	var stringer_y := OreRoad.RAIL_Y + OreRoad.RAIL_DEEP + OreRoad.SLEEPER_DEEP + 3
	for x in range(OreRoad.WEST, OreRoad.EAST):
		var head: Color = px.get(Vector2i(x, OreRoad.RAIL_Y), Color(0, 0, 0, 0))
		var is_rail := head == OreRoad.IRON[3] or head == OreRoad.RUST
		if OreRoad.deck_at(x):
			# The cart's wheels stand on the rail and hide none of it.
			if is_rail:
				rail += 1
			else:
				missing += 1
		else:
			# The bent rail leaves the line within a few pixels; the stub is the east end.
			if is_rail and x > OreRoad.BREAK.x + 8 and x < OreRoad.BREAK.y - 7:
				rail_in_gap += 1
			if px.get(Vector2i(x, stringer_y), Color.BLACK) in OreRoad.WOOD:
				stringer_in_gap += 1
	check(not OreRoad.deck_at(OreRoad.WEST - 1) and not OreRoad.deck_at(OreRoad.EAST), "the road ends at the walls")
	check(OreRoad.EAST - OreRoad.WEST > 1200, "it runs the length of the gallery (%d px)" % (OreRoad.EAST - OreRoad.WEST))
	check(rail > 1150 and missing == 0, "the rail's head is whole wherever the deck stands (%d px, %d missing)" % [rail, missing])
	check(rail_in_gap == 0 and stringer_in_gap == 0, "and the fallen span is open (%d, %d)" % [rail_in_gap, stringer_in_gap])
	var gap := OreRoad.BREAK.y - OreRoad.BREAK.x
	check(gap >= 40 and gap <= 80, "one span has fallen, wider than a cart (%d px)" % gap)
	# Sleepers: one a step, under the rail, on the stringer.
	var sleepers := 0
	var y := OreRoad.RAIL_Y + OreRoad.RAIL_DEEP + 1
	var was := false
	for x in range(OreRoad.WEST, OreRoad.EAST):
		var now: bool = px.get(Vector2i(x, y), OreRoad.OUTLINE) != OreRoad.OUTLINE
		if now and not was:
			sleepers += 1
		was = now
	check(sleepers > 90 and sleepers < 110, "the rail lies on its sleepers (%d)" % sleepers)
	check(px.get(Vector2i(100, stringer_y - 3), Color.BLACK) == OreRoad.WOOD[2], "the stringer is lit along its top")
	check(px.get(Vector2i(100, OreRoad.DECK_BOTTOM - 1), Color.BLACK) == OreRoad.WOOD[0], "and shaded along its bottom")


## Eight splayed timber bents carry it, none under the fallen span, each with
## three girts and two feet on the floor, lit down the left of each leg.
func test_ore_road_stands_on_its_bents() -> void:
	var px := _pixels()
	check(OreRoad.BENTS.size() == 8, "eight bents")
	check(OreRoad.GIRTS.size() == 3, "three girts a bent")
	var last := OreRoad.WEST
	for bx: int in OreRoad.BENTS:
		check(bx - last >= 120 and bx - last <= 180, "the bent at %d stands a span from the one before (%d px)" % [bx, bx - last])
		last = bx
		check(OreRoad.deck_at(bx - 30) and OreRoad.deck_at(bx + 30), "the bent at %d and its knees carry whole deck" % bx)
		for side: int in [-1, 1]:
			var foot := bx + side * OreRoad.LEG_FOOT
			check(px.has(Vector2i(foot, -1)), "its %s leg stands on the floor" % ("west" if side < 0 else "east"))
			var mid := -70
			var cx := bx + side * OreRoad.leg_off(mid)
			check(px.get(Vector2i(cx - 2, mid), Color.BLACK) == OreRoad.WOOD[2], "and is lit down its left")
			check(px.get(Vector2i(cx + 2, mid), Color.BLACK) == OreRoad.WOOD[0], "and shaded down its right")
		for g: int in OreRoad.GIRTS:
			check(px.get(Vector2i(bx, g), Color.BLACK) == OreRoad.WOOD[2], "a girt crosses it at %d" % g)
	check(OreRoad.EAST - last <= 180, "the last bent stands a span from the east wall")
	check(OreRoad.leg_off(-1) > OreRoad.leg_off(OreRoad.DECK_BOTTOM + 5) + 8, "the legs splay toward the floor")
	check(OreRoad.DECK_BOTTOM < -180, "the road is carried over every head and ledge (%d px up)" % -OreRoad.DECK_BOTTOM)


## One loaded cart stands on the rail between two bents, under the ceiling.
func test_ore_road_carries_a_loaded_cart() -> void:
	var px := _pixels()
	check(OreRoad.deck_at(OreRoad.CART_X - 20) and OreRoad.deck_at(OreRoad.CART_X + 20), "the cart stands on whole rail")
	check(OreRoad.CART_X < OreRoad.BREAK.x, "west of the fallen span: it never got across")
	var iron := 0
	var ore := 0
	var top := 0
	var lowest := -1000
	for c: Vector2i in px:
		if c.y >= OreRoad.RAIL_Y or absi(c.x - OreRoad.CART_X) > 24:
			continue
		top = mini(top, c.y)
		lowest = maxi(lowest, c.y)
		if px[c] in OreRoad.IRON:
			iron += 1
		if px[c] in OreRoad.ORE:
			ore += 1
	check(lowest == OreRoad.RAIL_Y - 1, "its wheels stand on the rail's head")
	check(iron > 350, "an iron tub on two wheels (%d px)" % iron)
	check(ore > 60, "heaped with ore (%d px)" % ore)
	check(top > OreRoad.CEILING + 2, "under the ceiling (%d over %d)" % [top, OreRoad.CEILING])
	check(top < OreRoad.RAIL_Y - 24, "taller than its wheels and tub alone: the heap stands over the rim")
	# Nothing else stands on the rail.
	var others := 0
	for c: Vector2i in px:
		if c.y < OreRoad.RAIL_Y - 1 and absi(c.x - OreRoad.CART_X) > 24:
			others += 1
	check(others == 0, "the only cart on the road (%d px elsewhere over the rail)" % others)


## The rail hangs bent into the gap, and what fell lies on the floor under it.
func test_ore_road_has_a_fallen_span() -> void:
	var px := _pixels()
	check(OreRoad.droop(0) == 0, "the bent rail leaves the line where the deck ends")
	var falls := true
	for i in range(1, OreRoad.DROOP_REACH + 1):
		falls = falls and OreRoad.droop(i) >= OreRoad.droop(i - 1)
	check(falls, "and only ever falls")
	check(OreRoad.droop(OreRoad.DROOP_REACH) == OreRoad.DROOP, "its end hangs %d px under the line" % OreRoad.DROOP)
	check(OreRoad.DROOP_REACH < (OreRoad.BREAK.y - OreRoad.BREAK.x) / 2, "short of the gap's middle")
	var hanging := 0
	for i in range(8, OreRoad.DROOP_REACH):
		var c := Vector2i(OreRoad.BREAK.x + i, OreRoad.RAIL_Y + OreRoad.droop(i))
		if px.get(c, Color.BLACK) in OreRoad.IRON:
			hanging += 1
	check(hanging >= OreRoad.DROOP_REACH - 9, "the hanging rail is drawn (%d px)" % hanging)
	var fallen := 0
	for y in range(-6, 0):
		for x in range(OreRoad.BREAK.x, OreRoad.BREAK.y):
			if px.get(Vector2i(x, y), Color.BLACK) in OreRoad.WOOD:
				fallen += 1
	check(fallen >= 120, "a timber and a sleeper lie on the floor under the gap (%d px)" % fallen)


## The hoist chain hangs from the stringer and sways at its hook only.
func test_ore_road_chain_hangs_from_the_stringer() -> void:
	var links := int(OreRoad.CHAIN_LENGTH / 3.0)
	var top_moves := 0.0
	var lo := 1000.0
	var hi := -1000.0
	var length_kept := true
	for k in 60:
		var at := k * 0.2
		top_moves = maxf(top_moves, absf(OreRoad.chain_point(0, at).x - OreRoad.CHAIN_TOP.x))
		var tip := OreRoad.chain_point(links, at)
		lo = minf(lo, tip.x)
		hi = maxf(hi, tip.x)
		length_kept = length_kept and tip.y == OreRoad.CHAIN_TOP.y + links * 3.0
	check(length_kept, "the chain keeps its length")
	check(top_moves == 0.0, "the chain is still where it hangs")
	check(hi - lo >= 4.0 and hi - lo <= 10.0, "its hook sways a little (%.0f px)" % (hi - lo))
	check(OreRoad.CHAIN_TOP.y == OreRoad.DECK_BOTTOM, "it hangs from the stringer's underside")
	check(OreRoad.deck_at(int(OreRoad.CHAIN_TOP.x)), "where the deck is whole")
	var clear := true
	for bx: int in OreRoad.BENTS:
		clear = clear and absf(OreRoad.CHAIN_TOP.x - bx) > 40.0
	check(clear, "and clear of the bents")
	check(OreRoad.CHAIN_TOP.y + OreRoad.CHAIN_LENGTH + 16.0 < -96.0, "its hook hangs over every head")


## In the room: the road runs from wall to wall under the ceiling, every bent
## stands on solid floor in open air, and the sign tells of it.
func test_the_rail_gallery_has_its_ore_road() -> void:
	var w := make_world({}, "tower/rail_gallery")
	await frames(2)
	var road := _road(w.room)
	check(road != null, "the Rail Gallery has its ore road")
	if road == null:
		return
	var room: Room = w.room
	var at := road.position
	check(room.is_solid_at(at + Vector2(OreRoad.WEST - 4, OreRoad.RAIL_Y + 4)), "the road's west end is let into the wall")
	check(room.is_solid_at(at + Vector2(OreRoad.EAST + 4, OreRoad.RAIL_Y + 4)), "and its east end, toward the Haar cut")
	var in_wall := 0
	for x in range(OreRoad.WEST + 2, OreRoad.EAST - 2, 8):
		for y: int in [OreRoad.RAIL_Y - 28, OreRoad.RAIL_Y, OreRoad.DECK_BOTTOM + 4]:
			if room.is_solid_at(at + Vector2(x, y)):
				in_wall += 1
	check(in_wall == 0, "between the walls it and its cart stand in open air (%d points in a wall)" % in_wall)
	check(room.is_solid_at(at + Vector2(OreRoad.CART_X, OreRoad.CEILING - 4)), "the ceiling is over the cart")
	check(not room.is_solid_at(at + Vector2(OreRoad.CART_X, OreRoad.CEILING + 4)), "and the cart is under it")
	for bx: int in OreRoad.BENTS:
		var buried := 0
		for y in range(OreRoad.DECK_BOTTOM, -2, 12):
			for side: int in [-1, 1]:
				if room.is_solid_at(at + Vector2(bx + side * OreRoad.leg_off(y), y)):
					buried += 1
		check(buried == 0, "the bent at %d stands in open air (%d points in a wall)" % [bx, buried])
		for side: int in [-1, 1]:
			check(room.is_solid_at(at + Vector2(bx + side * OreRoad.LEG_FOOT, 4)), "its %s foot is on solid floor" % ("west" if side < 0 else "east"))
	var tablets := 0
	for n: Node in room.get_children():
		if n is LoreTablet:
			tablets += 1
	check(tablets == 2, "the room has its two signs")
	check(FileAccess.get_file_as_string("res://levels/tower/rail_gallery.room").contains("ORE ROAD. Carts run east to the Haar cut."), "and the sign tells of the ore road")
	check(road.z_index < 0, "behind everyone who walks past")
	check(road.get_child_count() == 0, "scenery only: nothing to stand on, to touch or to be hurt by")
	await frames(30)
	check(road.t > 0.2, "its chain moves")
