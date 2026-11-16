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
	check(OreRoad.FOOT_Y.size() == OreRoad.BENTS.size(), "every bent has its footing's level")
	var last := OreRoad.WEST
	for i in OreRoad.BENTS.size():
		var bx := OreRoad.BENTS[i]
		var foot_y := OreRoad.FOOT_Y[i]
		check(bx - last >= 120 and bx - last <= 180, "the bent at %d stands a span from the one before (%d px)" % [bx, bx - last])
		last = bx
		check(OreRoad.deck_at(bx - 30) and OreRoad.deck_at(bx + 30), "the bent at %d and its knees carry whole deck" % bx)
		for side: int in [-1, 1]:
			var foot := bx + side * OreRoad.LEG_FOOT
			check(px.has(Vector2i(foot, foot_y - 1)), "its %s leg stands on its floor, %d px under the road's origin" % ["west" if side < 0 else "east", foot_y])
			check(not px.has(Vector2i(foot, foot_y)), "and goes no deeper")
			check(px.get(Vector2i(foot + 3, foot_y - 3), Color.BLACK) == OreRoad.IRON[2], "on a stone footing")
			var mid := -70
			var cx := bx + side * OreRoad.leg_off(mid, foot_y)
			check(px.get(Vector2i(cx - 2, mid), Color.BLACK) == OreRoad.WOOD[2], "and is lit down its left")
			check(px.get(Vector2i(cx + 2, mid), Color.BLACK) == OreRoad.WOOD[0], "and shaded down its right")
		for g: int in OreRoad.girts_for(foot_y):
			check(px.get(Vector2i(bx, g), Color.BLACK) == OreRoad.WOOD[2], "a girt crosses it at %d" % g)
		check(OreRoad.leg_off(foot_y - 1, foot_y) == OreRoad.LEG_FOOT, "its legs reach their full splay at its own floor")
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


## Pass 577 (bible 12.64): the gallery's floor is not level, and the trestle
## crosses it on legs of the length each footing needs.
func test_ore_road_bents_follow_the_floor() -> void:
	var px := _pixels()
	var levels := {}
	var deepest := 0
	for y: int in OreRoad.FOOT_Y:
		levels[y] = true
		deepest = maxi(deepest, y)
		check(y % 16 == 0, "a footing stands on a whole tile's floor (%d)" % y)
	check(levels.size() >= 3, "the bents stand at three levels (%s)" % [levels.keys()])
	check(deepest == OreRoad.DEEPEST and OreRoad.IMG.end.y == deepest, "the picture reaches the deepest footing and no further")
	var lowest := -1000
	for c: Vector2i in px:
		lowest = maxi(lowest, c.y)
	check(lowest == deepest - 1, "nothing is drawn under the deepest floor (%d)" % lowest)
	var sills := 0
	for i in OreRoad.BENTS.size():
		var bx := OreRoad.BENTS[i]
		var foot_y := OreRoad.FOOT_Y[i]
		var girts := OreRoad.girts_for(foot_y)
		check(foot_y - girts[-1] < OreRoad.SILL_FROM, "the bent at %d has a girt within %d px of its feet (%d)" % [bx, OreRoad.SILL_FROM, foot_y - girts[-1]])
		check(girts[-1] + 5 < foot_y - 8, "and its last girt stands clear over its footings")
		if girts.size() > 3:
			sills += 1
			check(foot_y == deepest, "only a bent in the pit has a sill girt")
			# A cross in the tier the sill makes, behind the legs.
			var braced := 0
			for y in range(OreRoad.GIRTS[2] + 8, girts[-1] - 2):
				for x in range(bx - 8, bx + 9):
					if px.get(Vector2i(x, y), Color.BLACK) in OreRoad.WOOD:
						braced += 1
			check(braced >= 60, "with a cross in the tier under the third girt (%d px)" % braced)
		# Under the level floor a sunk bent's legs are still drawn, lit and shaded.
		if foot_y > 0:
			var y := foot_y - 8
			for side: int in [-1, 1]:
				var cx := bx + side * OreRoad.leg_off(y, foot_y)
				check(px.get(Vector2i(cx - 2, y), Color.BLACK) == OreRoad.WOOD[2] and px.get(Vector2i(cx + 2, y), Color.BLACK) == OreRoad.WOOD[0], "the bent at %d runs on under the level floor (%d px down)" % [bx, y])
		else:
			check(not px.has(Vector2i(bx - OreRoad.LEG_FOOT, 4)) and not px.has(Vector2i(bx + OreRoad.LEG_FOOT, 4)), "the bent at %d ends at the level floor" % bx)
	check(sills == 1, "one bent stands in the pit (%d)" % sills)
	# What fell from the span lies on the floor west of the pit's brink, the
	# timber's east end out over it by less than a third of its length.
	var over := 0
	var on_floor := 0
	for x in range(OreRoad.BREAK.x - 12, OreRoad.BREAK.y):
		if px.get(Vector2i(x, -3), Color.BLACK) in OreRoad.WOOD:
			if x + OreRoad.PROP_X >= OreRoad.PIT.x:
				over += 1
			else:
				on_floor += 1
	check(on_floor >= 24 and over > 0 and over <= 10, "the fallen timber lies on the floor with its end over the brink (%d px on, %d over)" % [on_floor, over])


func _grid() -> Array[String]:
	var rows: Array[String] = []
	var text := FileAccess.get_file_as_string("res://levels/tower/rail_gallery.room").replace("\r", "")
	for line: String in text.split("---\n")[1].split("\n"):
		if line != "":
			rows.append(line)
	return rows


## The independent grade after pass 575: "most rooms are a rectangular tile
## frame around a dead-level floor". The second room changed for it (12.63's
## rule): the floor stands at three heights, with a ramped dip under the first
## spikes and a pit two tiles deep under the second, and the ceiling is
## vaulted in three places.
func test_the_rail_gallery_is_not_a_level_box() -> void:
	var grid := _grid()
	check(grid.size() == 23 and grid[0].length() == 80, "the gallery keeps its size")
	var floors := {}
	var ceilings := {}
	var ramps: Array[Vector2i] = []
	var floor_of: Array[int] = []
	for x in grid[0].length():
		var y := grid.size() - 1
		while y > 0 and grid[y][x] in "#/\\":
			y -= 1
		floor_of.append(y)
		if x == 0 or x == grid[0].length() - 1 or grid[grid.size() - 1][x] != "#" or grid[y + 1][x] in "/\\" or grid[y][x] == "#":
			continue  # the walls, the vault's shaft, a ramp
		if y < 16:
			continue  # the pillar
		floors[y] = true
		var top := 0
		while top < grid.size() and grid[top][x] == "#":
			top += 1
		ceilings[top] = true
	for x in grid[0].length():
		for row in grid.size():
			if grid[row][x] in "/\\":
				ramps.append(Vector2i(x, row))
	check(floors.size() >= 3, "the floor stands at three heights (%s)" % [floors.keys()])
	check(ceilings.size() >= 3, "the ceiling's underside stands at three heights (%s)" % [ceilings.keys()])
	for x in range(1, grid[0].length() - 1):
		if grid[4][x] == "B":
			check(grid[3][x] == "#", "the Gear Bat at %d still roosts under the ceiling" % x)
	check(ramps.size() == 2 and grid[ramps[0].y][ramps[0].x] == "\\" and grid[ramps[1].y][ramps[1].x] == "/", "two ramps, into the dip and out of it (%s)" % [ramps])
	if ramps.size() != 2:
		return
	for r: Vector2i in ramps:
		var high := -1 if grid[r.y][r.x] == "\\" else 1
		check(grid[r.y + 1][r.x] == "#" and grid[r.y][r.x + high] == "#", "the ramp at %s has ground under it and on its high side" % r)
		check(grid[r.y][r.x - high] == "." and grid[r.y + 1][r.x - high] == "#", "and starts on open floor")
	# The dip: a tile down, spikes on its floor, footing either side of them.
	var level := floor_of[1]
	var dip := 0
	var dip_spikes := 0
	for x in range(ramps[0].x + 1, ramps[1].x):
		if grid[level + 1][x] in ".^" and grid[level + 2][x] == "#":
			dip += 1
		if grid[level + 1][x] == "^":
			dip_spikes += 1
	check(dip == ramps[1].x - ramps[0].x - 1 and dip >= 12, "between them the floor lies a tile down (%d tiles)" % dip)
	check(dip_spikes == 8, "with the first spikes on it, as wide as they were (%d)" % dip_spikes)
	check(grid[level + 1][ramps[0].x + 1] == "." and grid[level + 1][ramps[1].x - 1] == ".", "and footing at the foot of each ramp")
	# The pit: two tiles down, spiked from wall to wall, under the hung plank.
	var pit: Array[int] = []
	for x in range(1, grid[0].length() - 1):
		if grid[level + 1][x] == "." and grid[level + 2][x] in ".^" and grid[grid.size() - 1][x] == "#":
			pit.append(x)
	check(pit.size() == 10 and pit[-1] - pit[0] == 9, "the pit is ten tiles of floor two tiles down (%s)" % [pit])
	if pit.is_empty():
		return
	check(pit[0] * Room.TILE == OreRoad.PIT.x and (pit[-1] + 1) * Room.TILE == OreRoad.PIT.y, "where the road's painter takes it to be")
	var bare := 0
	var planked := 0
	for x: int in pit:
		if grid[level + 2][x] != "^":
			bare += 1
		for row in range(0, level):
			if grid[row][x] == "-":
				planked += 1
	check(bare == 0, "spiked from wall to wall: nowhere in it to stand (%d bare)" % bare)
	check(planked == pit.size(), "and the hung plank still crosses all of it")
	# Walked for real: out of the dip by its east ramp, with no jump.
	var w := make_world({}, "tower/rail_gallery")
	await frames(3)
	for e: Node in runner.get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await frames(2)
	var p := w.player
	p.global_position = cell_feet(ramps[1].x - 2, ramps[1].y)
	p.velocity = Vector2.ZERO
	await frames(10)
	var from_y := p.global_position.y
	var hp := p.hp
	check(p.is_on_floor(), "east of the spikes the dip has footing")
	p.input.move_x = 1
	var steps := 0
	while p.global_position.x < (ramps[1].x + 3) * Room.TILE and steps < 300:
		await frames(1)
		steps += 1
	p.input.move_x = 0
	await frames(10)
	check(p.global_position.x >= (ramps[1].x + 3) * Room.TILE, "a walk east climbs out of the dip (x %.0f after %d frames)" % [p.global_position.x, steps])
	check_near(from_y - p.global_position.y, float(Room.TILE), 2.0, "a tile higher than it began, by the ramp alone")
	check(p.is_on_floor(), "standing")
	# And into it from the west door's floor.
	p.global_position = cell_feet(ramps[0].x - 3, ramps[0].y - 1)
	p.velocity = Vector2.ZERO
	await frames(10)
	from_y = p.global_position.y
	p.input.move_x = 1
	steps = 0
	while p.global_position.x < (ramps[0].x + 2) * Room.TILE and steps < 300:
		await frames(1)
		steps += 1
	p.input.move_x = 0
	await frames(10)
	check_near(p.global_position.y - from_y, float(Room.TILE), 2.0, "a walk east from the door goes down into the dip")
	check(p.is_on_floor() and p.hp == hp, "and stops short of the spikes unhurt")
	w.queue_free()
	await frames(2)


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
	check(at.x == OreRoad.PROP_X, "the road's origin is where its painter takes it to be (%.0f)" % at.x)
	for i in OreRoad.BENTS.size():
		var bx := OreRoad.BENTS[i]
		var foot_y := OreRoad.FOOT_Y[i]
		var buried := 0
		for y in range(OreRoad.DECK_BOTTOM, foot_y - 1, 6):
			for side: int in [-1, 1]:
				if room.is_solid_at(at + Vector2(bx + side * OreRoad.leg_off(y, foot_y), y)):
					buried += 1
		check(buried == 0, "the bent at %d stands in open air down to its feet (%d points in a wall)" % [bx, buried])
		for side: int in [-1, 1]:
			var foot := at + Vector2(bx + side * OreRoad.LEG_FOOT, foot_y)
			check(room.is_solid_at(foot + Vector2(0, 4)), "its %s foot is on solid floor, %d px under the origin" % ["west" if side < 0 else "east", foot_y])
			check(not room.is_solid_at(foot + Vector2(-7, -3)) and not room.is_solid_at(foot + Vector2(7, -3)), "and its footing is not let into a wall")
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
