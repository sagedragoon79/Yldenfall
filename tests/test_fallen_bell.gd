extends TestSuite
## FallenBell (pass 569, bible 12.56): the Bell Loft's sign told of a shift bell
## that "lies where it fell, split from lip to crown", and the room showed none.
## The bell is the room's landmark, painted like the crucible (12.35).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell.
func _pixels() -> Dictionary:
	var img := FallenBell.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + FallenBell.IMG.position] = c
	return out


func _bell(room: Node) -> FallenBell:
	for n: Node in room.get_children():
		if n is FallenBell:
			return n
	return null


## Every tone is a master palette value, and the baked image holds nothing else.
func test_fallen_bell_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in FallenBell.TONES + [FallenBell.HOLLOW_LIT, FallenBell.ROPE, FallenBell.ROPE_DARK]:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	var img := FallenBell.build_image()
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
	check(opaque > 4000, "the bell, its clapper and its headstock are drawn (%d px)" % opaque)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)


## A bell's shape: a flared lip, a waist, a shoulder that closes to the crown.
## It is taller than the hero and lies on the floor.
func test_fallen_bell_is_a_bell_on_its_side() -> void:
	check(FallenBell.radius(0.0) == FallenBell.LIP_R, "the lip is its widest ring")
	check(FallenBell.radius(40.0) < FallenBell.LIP_R * 0.7, "it narrows to a waist")
	check(FallenBell.radius(FallenBell.LENGTH - 1.0) < FallenBell.radius(FallenBell.SHOULDER) * 0.5, "the shoulder closes to the crown")
	check(FallenBell.radius(FallenBell.LENGTH) < 0.01, "and ends")
	check(FallenBell.LIE > 0.05 and FallenBell.LIE < 0.4, "it lies nearly flat, its crown lower than its mouth")
	var px := _pixels()
	var top := 0
	var bottom := -1000
	var bronze := 0
	var lowest := -1000
	for c: Vector2i in px:
		lowest = maxi(lowest, c.y)
		if FallenBell.in_body(FallenBell.local(c)):
			bronze += 1
			top = mini(top, c.y)
			bottom = maxi(bottom, c.y)
	check(bronze > 2500, "the bronze is a large mass (%d px)" % bronze)
	check(top < -56, "taller than the hero (%d)" % top)
	check(bottom >= -5 and bottom <= -1, "resting on the floor (%d)" % bottom)
	check(lowest == -1, "nothing is drawn under the floor (%d)" % lowest)


## Lit from the upper left on the whole bronze ramp: the upper side is brighter
## than the lower, and verdigris grows only in the shade.
func test_fallen_bell_is_lit_from_the_upper_left() -> void:
	var px := _pixels()
	var used := {}
	var upper := [0.0, 0]
	var lower := [0.0, 0]
	var patina := 0
	var patina_lit := 0
	for c: Vector2i in px:
		var q := FallenBell.local(c)
		if not FallenBell.in_body(q):
			continue
		var col: Color = px[c]
		used[col.to_html(false)] = true
		var level := FallenBell.level_at(c, q)
		var half: Array = upper if q.y < 0.0 else lower
		half[0] += level
		half[1] += 1
		if col == FallenBell.PATINA or col == FallenBell.PATINA_DARK:
			patina += 1
			if level >= 2:
				patina_lit += 1
	for tone: Color in FallenBell.BRONZE:
		check(used.has(tone.to_html(false)), "the bronze uses #%s" % tone.to_html(false))
	check(used.has(FallenBell.GLINT.to_html(false)), "and a glint")
	check(upper[0] / upper[1] > lower[0] / lower[1] + 0.8, "the upper side is brighter (%.2f over %.2f)" % [upper[0] / upper[1], lower[0] / lower[1]])
	check(patina > 60 and patina < 700, "verdigris grows in patches, not all over (%d px)" % patina)
	check(patina_lit == 0, "and only in the shade")


## The split the sign names: unbroken from the lip to the crown, a gap at the
## lip and a hairline at the crown, and it zigzags.
func test_fallen_bell_is_split_from_lip_to_crown() -> void:
	var px := _pixels()
	var columns := {}
	var lip := 0
	for c: Vector2i in px:
		if px[c] != FallenBell.OUTLINE:
			continue
		var q := FallenBell.local(c)
		if FallenBell.in_body(q) and FallenBell.on_crack(q):
			columns[floori(q.x)] = true
		elif FallenBell.in_mouth(q, 0.0) and not FallenBell.in_mouth(q, FallenBell.WALL) and q.y < 0.0 and q.x > 0.0:
			lip += 1
	var missing := 0
	for s in range(10, int(FallenBell.LENGTH) - 4):
		if not columns.has(s):
			missing += 1
	check(missing == 0, "the split is unbroken from lip to crown (%d gaps)" % missing)
	check(lip >= 2, "and cuts the lip's edge (%d px)" % lip)
	check(FallenBell.crack_at(2.0).y > FallenBell.crack_at(FallenBell.LENGTH - 6.0).y * 2.0, "widest at the lip")
	var mids := {}
	for s in range(0, 60, 3):
		mids[snappedf(FallenBell.crack_at(float(s)).x + FallenBell.radius(float(s)) * 0.42, 0.1)] = true
	check(mids.size() >= 4, "it zigzags (%d offsets)" % mids.size())


## The rope hangs from the headstock's stub and sways at its frayed end only.
func test_fallen_bell_rope_sways_from_the_stub() -> void:
	var steps := int(FallenBell.ROPE_LENGTH / 2.0)
	var top_moves := 0.0
	var tip_lo := 1000.0
	var tip_hi := -1000.0
	var length_kept := true
	for i in 40:
		var at := i * 0.2
		top_moves = maxf(top_moves, absf(FallenBell.rope_point(0, at).x - FallenBell.ROPE_TOP.x))
		var tip := FallenBell.rope_point(steps, at)
		tip_lo = minf(tip_lo, tip.x)
		tip_hi = maxf(tip_hi, tip.x)
		length_kept = length_kept and tip.y == FallenBell.ROPE_TOP.y + steps * 2.0
	check(length_kept, "the rope keeps its length")
	check(top_moves == 0.0, "the rope is still where it is tied")
	check(tip_hi - tip_lo >= 6.0 and tip_hi - tip_lo <= 12.0, "its end sways a little (%.0f px)" % (tip_hi - tip_lo))
	check(Rect2(FallenBell.STUB).grow(1).has_point(FallenBell.ROPE_TOP), "it leaves the headstock's stub")
	check(FallenBell.ROPE_TOP.y + FallenBell.ROPE_LENGTH < -80.0, "and ends well above the bell")


## In the room: the bell lies on the floor under a solid ceiling, clear of the
## sign and the door, and the sign still tells of it.
func test_the_bell_loft_has_its_fallen_bell() -> void:
	var w := make_world({}, "tower/bell_loft")
	await frames(2)
	var bell := _bell(w.room)
	check(bell != null, "the Bell Loft has its bell")
	if bell == null:
		return
	var room: Room = w.room
	var left := bell.position.x + FallenBell.IMG.position.x
	var right := bell.position.x + FallenBell.IMG.end.x
	check(room.is_solid_at(bell.position + Vector2(-40, 4)) and room.is_solid_at(bell.position + Vector2(40, 4)), "it lies on the floor")
	check(not room.is_solid_at(bell.position + Vector2(0, -8)), "in open air")
	for x: int in [FallenBell.STUB.position.x + 6, FallenBell.STUB.end.x - 10]:
		check(room.is_solid_at(bell.position + Vector2(x, FallenBell.CEILING - 4)), "a strap is bolted into the ceiling")
		check(not room.is_solid_at(bell.position + Vector2(x, FallenBell.CEILING + 4)), "and hangs below it")
	var tablets := 0
	for n: Node in room.get_children():
		if n is LoreTablet:
			tablets += 1
			check(n.position.x + 12.0 < left or n.position.x - 12.0 > right, "the sign stands clear of the bell")
	check(tablets == 1, "the room has its sign")
	check(FileAccess.get_file_as_string("res://levels/tower/bell_loft.room").contains("lies where it fell, split from lip to crown"), "and the sign tells of the bell")
	check(right <= room.size_tiles.x * Room.TILE - Room.TILE, "the bell stands clear of the door")
	check(bell.z_index < 0, "behind everyone who walks past")
	await frames(30)
	check(bell.t > 0.2, "its rope moves")
