extends TestSuite
## GearTrain (pass 570, bible 12.57): the Gear Pit's sign told that "the great
## gears turned the winch from here. Their teeth still bite", and the room
## showed none. The train is the room's landmark, painted like the crucible
## (12.35) and the fallen bell (12.56).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of a baked image, by world cell.
func _pixels(strain: float) -> Dictionary:
	var img := GearTrain.build_image(strain)
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + GearTrain.IMG.position] = c
	return out


func _train(room: Node) -> GearTrain:
	for n: Node in room.get_children():
		if n is GearTrain:
			return n
	return null


## The teeth of wheel `i` when it stands at angle 0: the times its edge rises
## from the root to the tip in one turn.
func _teeth(i: int) -> int:
	var g: Dictionary = GearTrain.GEARS[i]
	var mid: float = g.r
	var count := 0
	var was := GearTrain.edge(i, -0.001) > mid
	for k in 2000:
		var now := GearTrain.edge(i, k * TAU / 2000.0) > mid
		if now and not was:
			count += 1
		was = now
	return count


## Every tone is a master palette value, and both baked images hold nothing else.
func test_gear_train_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in GearTrain.TONES + [GearTrain.FRAME, GearTrain.FRAME_LIT]:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	for strain: float in [0.0, 1.0]:
		var img := GearTrain.build_image(strain)
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
		check(opaque > 9000, "the wheels, their hangers and the post are drawn (%d px)" % opaque)
		check(stray == 0, "no blended or off-palette pixels (%d)" % stray)


## Three wheels of one pitch, each a sum of radii from the one before, their
## teeth between each other's and never through them.
func test_gear_train_is_three_wheels_in_mesh() -> void:
	check(GearTrain.GEARS.size() == 3, "three wheels")
	var pitch: float = TAU * GearTrain.GEARS[0].r / GearTrain.GEARS[0].teeth
	for i in GearTrain.GEARS.size():
		var g: Dictionary = GearTrain.GEARS[i]
		check(absf(TAU * g.r / g.teeth - pitch) < 0.01, "wheel %d has the train's pitch" % i)
		# The great gear has lost one (see the next test).
		var whole: int = g.teeth - (1 if i == 0 else 0)
		check(_teeth(i) == whole, "wheel %d has its %d whole teeth (%d)" % [i, whole, _teeth(i)])
		if i > 0:
			var before: Dictionary = GearTrain.GEARS[i - 1]
			check(g.r < before.r, "wheel %d is smaller than its driver" % i)
			check(absf(before.at.distance_to(g.at) - (before.r + g.r)) < 0.05, "and stands in mesh with it (%.2f)" % before.at.distance_to(g.at))
	check(GearTrain.GEARS[0].r * 2.0 > 96.0, "the great gear is taller than two dwarves")
	for strain: float in [0.0, 0.5, 1.0]:
		var turned := GearTrain.angles(strain)
		for i in range(1, GearTrain.GEARS.size()):
			var a: Dictionary = GearTrain.GEARS[i - 1]
			var b: Dictionary = GearTrain.GEARS[i]
			var clash := 0
			var both := [0, 0]
			var mid: Vector2 = a.at + (b.at - a.at).normalized() * a.r
			for y in range(floori(mid.y) - 12, floori(mid.y) + 13):
				for x in range(floori(mid.x) - 12, floori(mid.x) + 13):
					var c := Vector2i(x, y)
					var in_a := GearTrain.covers(i - 1, c, turned[i - 1])
					var in_b := GearTrain.covers(i, c, turned[i])
					# Inside both wheels' tip circles: where teeth pass each other.
					var shared: bool = (Vector2(c) + Vector2(0.5, 0.5)).distance_to(a.at) < a.r + GearTrain.TOOTH and (Vector2(c) + Vector2(0.5, 0.5)).distance_to(b.at) < b.r + GearTrain.TOOTH
					if in_a and in_b:
						clash += 1
					if shared and in_a:
						both[0] += 1
					if shared and in_b:
						both[1] += 1
			check(clash == 0, "wheels %d and %d never share a pixel at strain %.1f (%d)" % [i - 1, i, strain, clash])
			check(both[0] >= 8 and both[1] >= 8, "and each has a tooth between the other's (%d, %d px)" % both)


## Lit from the upper left on the iron ramp; rust only in the shade, in
## streaks; each wheel is a slab with a dark side down and to the right.
func test_gear_train_is_lit_from_the_upper_left() -> void:
	var px := _pixels(0.0)
	var used := {}
	var upper := [0.0, 0]
	var lower := [0.0, 0]
	var rust := 0
	var rust_lit := 0
	var iron := 0
	var side := 0
	var great: Dictionary = GearTrain.GEARS[0]
	for c: Vector2i in px:
		var col: Color = px[c]
		var i := GearTrain.wheel_at(c, 0.0)
		if i < 0:
			if col == GearTrain.IRON[0] and (GearTrain.wheel_at(c - Vector2i(1, 1), 0.0) >= 0 or GearTrain.wheel_at(c - Vector2i(2, 2), 0.0) >= 0):
				side += 1
			continue
		used[col.to_html(false)] = true
		var level := GearTrain.IRON.find(col)
		if col == GearTrain.RUST or col == GearTrain.RUST_DARK:
			rust += 1
			if GearTrain.face_level(i, c) >= 2:
				rust_lit += 1
		if level < 0 or i != 0:
			continue
		iron += 1
		var d: Vector2 = Vector2(c) - great.at
		# The upper left by the test's own measure, not the painter's.
		var half: Array = upper if d.dot(Vector2(-1, -1)) > 0.0 else lower
		half[0] += level
		half[1] += 1
	for tone: Color in GearTrain.IRON:
		check(used.has(tone.to_html(false)), "the iron uses #%s" % tone.to_html(false))
	for tone: Color in GearTrain.BRASS.slice(1):
		check(used.has(tone.to_html(false)), "the bearing caps use #%s" % tone.to_html(false))
	check(iron > 3000, "the great gear is a large mass of iron (%d px)" % iron)
	check(upper[0] / upper[1] > lower[0] / lower[1] + 0.6, "its upper left is brighter (%.2f over %.2f)" % [upper[0] / upper[1], lower[0] / lower[1]])
	check(rust > 150 and rust < 1500, "rust grows in streaks, not all over (%d px)" % rust)
	check(rust_lit == 0, "and only in the shade")
	check(side > 300, "each wheel shows a dark side down and to the right (%d px)" % side)


## One tooth of the great gear has snapped off, and it lies on the floor.
func test_gear_train_has_lost_a_tooth() -> void:
	var g: Dictionary = GearTrain.GEARS[0]
	var step: float = TAU / g.teeth
	var tip: float = g.r + GearTrain.TOOTH
	var stubs := 0
	for k in g.teeth:
		var reach := 0.0
		for j in range(-10, 11):
			reach = maxf(reach, GearTrain.edge(0, k * step + j * step / 40.0))
		if k == GearTrain.BROKEN:
			check(reach < g.r - 1.0 and reach > g.r - GearTrain.TOOTH, "the broken tooth is a stub under the pitch circle (%.1f)" % reach)
			stubs += 1
		elif reach < tip - 0.01:
			stubs += 1
	check(stubs == 1, "one tooth is broken, the other %d are whole (%d)" % [g.teeth - 1, stubs])
	# The stub stands in the light, where it shows: the upper half of the wheel.
	var at := Vector2.from_angle(GearTrain.REST + GearTrain.BROKEN * step)
	check(at.y < -0.5, "the gap is on the wheel's upper side (%.2f)" % at.y)
	var px := _pixels(0.0)
	var fallen := 0
	for y in range(-8, 0):
		for x in range(38, 49):
			if px.has(Vector2i(x, y)) and GearTrain.wheel_at(Vector2i(x, y), 0.0) < 0:
				fallen += 1
	check(fallen >= 40, "the tooth lies on the floor beside the wheel (%d px)" % fallen)


## "Their teeth still bite": the train strains a sixth of a tooth and falls
## back, each wheel against its driver and faster by the ratio of their teeth.
func test_gear_train_strains_and_falls_back() -> void:
	var rest := GearTrain.angles(0.0)
	var bite := GearTrain.angles(1.0)
	var pitch: float = TAU / GearTrain.GEARS[0].teeth
	check(absf((bite[0] - rest[0]) - pitch / 6.0) < 0.0001, "the great gear strains a sixth of a tooth")
	for i in range(1, 3):
		var ratio: float = float(GearTrain.GEARS[i - 1].teeth) / GearTrain.GEARS[i].teeth
		var turn_a := bite[i - 1] - rest[i - 1]
		var turn_b := bite[i] - rest[i]
		check(signf(turn_a) != signf(turn_b), "wheel %d turns against its driver" % i)
		check(absf(absf(turn_b) - absf(turn_a) * ratio) < 0.0001, "and faster by the ratio of their teeth (%.3f)" % (absf(turn_b) / absf(turn_a)))
	var a := _pixels(0.0)
	var b := _pixels(1.0)
	var moved := 0
	for c: Vector2i in a:
		if not b.has(c) or b[c] != a[c]:
			moved += 1
	check(moved > 400 and moved < a.size() / 2, "the strained image differs at the teeth and spokes, not everywhere (%d px)" % moved)
	var biting := 0
	var bites := 0
	var was := false
	for k in 700:
		var now := GearTrain.biting(k * 0.01)
		if now:
			biting += 1
		if now and not was:
			bites += 1
		was = now
	check(bites == 2, "two bites in a cycle (%d)" % bites)
	check(biting >= 10 and biting <= 30, "short ones: the train is seized (%d hundredths of %d)" % [biting, 700])


## The parted drive chain hangs from the pinion and sways at its end only.
func test_gear_train_chain_hangs_from_the_pinion() -> void:
	var links := int(GearTrain.CHAIN_LENGTH / 3.0)
	var top_moves := 0.0
	var lo := 1000.0
	var hi := -1000.0
	var length_kept := true
	for k in 60:
		var at := k * 0.2
		top_moves = maxf(top_moves, absf(GearTrain.chain_point(0, at).x - GearTrain.CHAIN_TOP.x))
		var tip := GearTrain.chain_point(links, at)
		lo = minf(lo, tip.x)
		hi = maxf(hi, tip.x)
		length_kept = length_kept and tip.y == GearTrain.CHAIN_TOP.y + links * 3.0
	check(length_kept, "the chain keeps its length")
	check(top_moves == 0.0, "the chain is still where it hangs")
	check(hi - lo >= 3.0 and hi - lo <= 8.0, "its end sways a little (%.0f px)" % (hi - lo))
	var pin: Dictionary = GearTrain.GEARS[2]
	var off: float = GearTrain.CHAIN_TOP.distance_to(pin.at)
	check(off > pin.r - GearTrain.TOOTH - 1.0 and off < pin.r + GearTrain.TOOTH, "it leaves the pinion's rim (%.1f px from its axle)" % off)
	var great: Dictionary = GearTrain.GEARS[0]
	check(GearTrain.chain_point(links, 0.0).distance_to(great.at) > great.r + GearTrain.TOOTH + 4.0, "and ends clear of the great gear")


## In the room: the great gear sinks into solid floor, the hangers are bolted
## into solid ceiling, nothing stands in a wall, and the sign tells of it.
func test_the_gear_pit_has_its_great_gears() -> void:
	var w := make_world({}, "tower/gear_pit")
	await frames(2)
	var train := _train(w.room)
	check(train != null, "the Gear Pit has its gears")
	if train == null:
		return
	var room: Room = w.room
	var great: Dictionary = GearTrain.GEARS[0]
	check(room.is_solid_at(train.position + Vector2(-30, 4)) and room.is_solid_at(train.position + Vector2(30, 4)), "the great gear stands over solid floor")
	check(great.at.y + great.r + GearTrain.TOOTH > 2.0, "and sinks into it, toward the winch below")
	for i in GearTrain.GEARS.size():
		var g: Dictionary = GearTrain.GEARS[i]
		var reach: float = g.r + GearTrain.TOOTH
		var in_wall := 0
		for k in 16:
			var p: Vector2 = train.position + g.at + Vector2.from_angle(k * TAU / 16.0) * reach
			if p.y < train.position.y - 1.0 and room.is_solid_at(p):
				in_wall += 1
		check(in_wall == 0, "wheel %d stands in open air (%d of 16 points in a wall)" % [i, in_wall])
		if i > 0:
			check(room.is_solid_at(train.position + Vector2(g.at.x, GearTrain.CEILING - 4)), "wheel %d's hanger is bolted into the ceiling" % i)
			check(not room.is_solid_at(train.position + Vector2(g.at.x, GearTrain.CEILING + 4)), "and hangs below it")
	var left := train.position.x + GearTrain.IMG.position.x
	var tablets := 0
	for n: Node in room.get_children():
		if n is LoreTablet:
			tablets += 1
			check(n.position.x + 12.0 < left, "the sign stands clear of the gears")
	check(tablets == 1, "the room has its sign")
	check(FileAccess.get_file_as_string("res://levels/tower/gear_pit.room").contains("The great gears turned the winch from here. Their teeth still bite."), "and the sign tells of the gears")
	check(train.z_index < 0, "behind everyone who walks past")
	check(train.get_child_count() == 0, "scenery only: nothing to touch or to be hurt by")
	await frames(30)
	check(train.t > 0.2, "its chain moves")
	# The strained image is baked off the room's load, on a worker thread.
	for i in 600:
		if train._tex_bite != null:
			break
		await frames(1)
	check(train._tex_bite != null and train._tex_bite.get_size() == train._tex_rest.get_size(), "the strained image arrives after the room has loaded")
