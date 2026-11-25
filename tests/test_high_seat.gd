extends TestSuite
## HighSeat (pass 575, bible 12.62): the Rot Dwarf Hall's sign told of the
## Amberlee dwarves and of the rot that "came up through the roots with the
## sap", and the hall showed a flat floor and four ledges. The high seat,
## split by a root, is the hall's landmark, painted like the ore bin (12.61).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell from the prop's origin.
func _pixels() -> Dictionary:
	var img := HighSeat.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + HighSeat.IMG.position] = c
	return out


func _seat(room: Node) -> HighSeat:
	for n: Node in room.get_children():
		if n is HighSeat:
			return n
	return null


## Whether `c` lies on the main root.
func _on_root(c: Vector2i) -> bool:
	return absi(c.x - HighSeat.root_x(c.y)) <= HighSeat.root_half(c.y)


## Whether `c` is timber, whole or rotted, or a seam in it.
func _timber(c: Color) -> bool:
	return c in HighSeat.WOOD or c in HighSeat.ROT or c == HighSeat.OUTLINE


## Every tone is a master palette value, and the baked image holds nothing else.
func test_high_seat_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in HighSeat.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	var img := HighSeat.build_image()
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
	check(opaque > 14000, "the seat, its frame and the root are drawn (%d px)" % opaque)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)
	for tone: Color in HighSeat.TONES:
		check(used.has(tone.to_html(false)), "the picture uses #%s" % tone.to_html(false))


## Two carved pillars on a low dais, and the hall's two shields: one hangs,
## one has fallen from its nail and lies against the east pillar.
func test_high_seat_stands_between_two_pillars_on_a_dais() -> void:
	var px := _pixels()
	check(HighSeat.DAIS_HIGH <= 6, "the dais is too low to read as a step (%d px)" % HighSeat.DAIS_HIGH)
	check(px.get(Vector2i(-HighSeat.DAIS_HALF + 2, -HighSeat.DAIS_HIGH), Color.BLACK) == HighSeat.STONE[2], "it is stone, lit along its top")
	check(px.has(Vector2i(-HighSeat.DAIS_HALF + 2, -1)) and px.has(Vector2i(HighSeat.DAIS_HALF - 2, -1)), "and lies on the floor from end to end")
	var top := HighSeat.LINTEL_TOP + HighSeat.LINTEL_DEEP
	for side: int in [-1, 1]:
		var cx := side * HighSeat.PILLAR_X
		var name := "west" if side < 0 else "east"
		check(absi(cx) > HighSeat.SEAT_HALF + 8, "the %s pillar stands clear of the seat" % name)
		check(absi(cx) + HighSeat.PILLAR_WIDE / 2 <= HighSeat.DAIS_HALF, "on the dais")
		var whole := true
		for y in range(top, -HighSeat.DAIS_HIGH):
			whole = whole and _timber(px.get(Vector2i(cx, y), Color.BLACK))
		check(whole, "and runs whole from the dais to the lintel")
		check(px.get(Vector2i(cx - HighSeat.PILLAR_WIDE / 2, -100), Color.BLACK) == HighSeat.WOOD[2], "lit down its left")
		check(px.get(Vector2i(cx + HighSeat.PILLAR_WIDE / 2 - 1, -100), Color.BLACK) == HighSeat.WOOD[0], "shaded down its right")
	var hung := HighSeat.SHIELD_HUNG
	check(px.get(hung, Color.BLACK) == HighSeat.STONE[3], "a shield hangs west of the seat, its boss lit")
	check(px.get(hung + Vector2i(0, -HighSeat.SHIELD_RADIUS - 6), Color.BLACK) == HighSeat.STONE[3], "from a nail")
	check(hung.x + HighSeat.SHIELD_RADIUS < -HighSeat.BACK_HALF, "between the seat")
	check(hung.x - HighSeat.SHIELD_RADIUS > -HighSeat.PILLAR_X + HighSeat.PILLAR_WIDE / 2, "and the west pillar")
	check(hung.y + HighSeat.SHIELD_RADIUS < -64, "over every head")
	var nail := HighSeat.SHIELD_NAIL
	check(absi(nail.x + hung.x) <= 4 and nail.y == hung.y - HighSeat.SHIELD_RADIUS - 1, "the other nail is its mirror")
	check(px.get(nail, Color.BLACK) == HighSeat.STONE[3], "and bare")
	var bare := true
	for dy in range(3, 20):
		bare = bare and not px.has(nail + Vector2i(0, dy))
	check(bare, "nothing hangs from it")
	var fallen := HighSeat.SHIELD_FALLEN
	check(px.get(fallen, Color.BLACK) == HighSeat.STONE[3], "its shield lies below")
	check(fallen.y + HighSeat.SHIELD_RADIUS == -HighSeat.DAIS_HIGH, "on the dais")
	check(fallen.x > HighSeat.SEAT_HALF + 8 and fallen.x < HighSeat.PILLAR_X, "against the east pillar")


## "The rot came up through the roots": one root, whole from the floor to the
## ceiling, through the dais, the seat and the lintel.
func test_a_root_has_come_up_through_the_high_seat() -> void:
	var px := _pixels()
	var whole := true
	var lit := true
	var shaded := true
	var lo := 1000
	var hi := -1000
	for y in range(HighSeat.CEILING, 0):
		var cx := HighSeat.root_x(y)
		var hw := HighSeat.root_half(y)
		var c: Color = px.get(Vector2i(cx, y), Color.BLACK)
		whole = whole and (c in HighSeat.ROOT or c in HighSeat.SAP)
		lo = mini(lo, cx)
		hi = maxi(hi, cx)
		# The heaved slabs of the dais stand in front of its foot.
		if y >= -HighSeat.DAIS_HIGH - 5:
			continue
		lit = lit and px.get(Vector2i(cx - hw, y), Color.BLACK) == HighSeat.ROOT[2]
		shaded = shaded and px.get(Vector2i(cx + hw - 1, y), Color.BLACK) == HighSeat.ROOT[0]
		whole = whole and px.get(Vector2i(cx - hw - 1, y), Color.BLACK) == HighSeat.OUTLINE
	check(whole, "the root is whole and outlined from the floor to the ceiling")
	check(lit, "lit down its left")
	check(shaded, "shaded down its right")
	check(HighSeat.root_half(-40) > HighSeat.root_half(-240), "it thins as it climbs (%d to %d px)" % [HighSeat.root_half(-40), HighSeat.root_half(-240)])
	check(HighSeat.root_half(-1) >= HighSeat.root_half(-40) + 4, "and flares where it leaves the floor")
	check(hi - lo >= 16, "it wanders (%d px)" % (hi - lo))
	check(lo - 14 > -HighSeat.PILLAR_X + HighSeat.PILLAR_WIDE / 2 and hi + 14 < HighSeat.PILLAR_X - HighSeat.PILLAR_WIDE / 2, "between the pillars all the way")
	for y: int in [HighSeat.SEAT_TOP - 4, HighSeat.BACK_TOP + 20]:
		check(absi(HighSeat.root_x(y)) + HighSeat.root_half(y) < HighSeat.BACK_HALF, "it goes up through the seat's back (row %d)" % y)
	# The root is darker than the timber it broke: the hall's frame stays the brighter thing.
	check(HighSeat.ROOT[2].get_luminance() < HighSeat.WOOD[2].get_luminance(), "the root is darker than the timber")
	# The dais is heaved up on each side of it.
	var at := HighSeat.root_x(-HighSeat.DAIS_HIGH)
	var hw0 := HighSeat.root_half(-HighSeat.DAIS_HIGH)
	for side: int in [-1, 1]:
		check(px.get(Vector2i(at + side * (hw0 + 2), -HighSeat.DAIS_HIGH - 3), Color.BLACK) in HighSeat.STONE, "a slab is heaved up on its %s side" % ("west" if side < 0 else "east"))
	# The east side root reaches the east pillar and sags between.
	var mid := (HighSeat.SIDE_EAST_FROM.x + HighSeat.SIDE_EAST_TO.x) / 2
	check(HighSeat.side_east_y(mid) > (HighSeat.SIDE_EAST_FROM.y + HighSeat.SIDE_EAST_TO.y) / 2 + 4, "a side root sags east from it")
	check(px.get(Vector2i(mid, HighSeat.side_east_y(mid) + 1), Color.BLACK) in HighSeat.ROOT, "drawn where it hangs")
	check(HighSeat.SIDE_EAST_TO.x == HighSeat.PILLAR_X - HighSeat.PILLAR_WIDE / 2, "to the east pillar")
	check(_on_root(HighSeat.SIDE_EAST_FROM), "from the root")


## The root is round (pass 655, bible 12.131): the pass 650 grade read it as
## "a flat unshaded band". Across every row it runs from a lit band west of
## its middle through the mid tone to a shaded east third; furrows of bark run
## up it and bunch toward its edges; its shadow falls east on the timber behind.
func test_the_root_is_round_and_barked() -> void:
	var px := _pixels()
	var rows := 0
	var round_rows := 0
	var furrowed := 0
	var plates := 0
	var lit_stray := 0
	for y in range(HighSeat.CEILING + 4, -HighSeat.DAIS_HIGH - 6):
		var cx := HighSeat.root_x(y)
		var hw := HighSeat.root_half(y)
		if hw < 7:
			continue
		rows += 1
		var west_lit := 0
		var east_lit := 0
		var west_dark := 0
		var east_dark := 0
		var dark_runs := 0
		for x in range(cx - hw + 1, cx + hw - 1):
			var c: Color = px.get(Vector2i(x, y), Color.BLACK)
			var west := x < cx
			if c == HighSeat.ROOT[2] or c == HighSeat.BARK_LIT:
				if west:
					west_lit += 1
				else:
					east_lit += 1
			var dark := c == HighSeat.ROOT[0] or c == HighSeat.OUTLINE
			if dark:
				if west:
					west_dark += 1
				else:
					east_dark += 1
			if c == HighSeat.BARK_LIT:
				plates += 1
				if HighSeat.root_light(x, y) <= 0.88:
					lit_stray += 1
			# A mark of bark: darker than the trunk's roundness alone gives there.
			var l := HighSeat.root_light(x, y)
			var want := 2 if l > 0.88 else (1 if l > 0.5 else 0)
			var got := 2 if c == HighSeat.ROOT[2] or c == HighSeat.BARK_LIT else (1 if c == HighSeat.ROOT[1] else 0)
			if got < want:
				dark_runs += 1
		if west_lit > east_lit and east_dark > west_dark and east_dark >= hw / 2:
			round_rows += 1
		if dark_runs >= 1:
			furrowed += 1
	check(rows > 200, "rows of the root measured (%d)" % rows)
	check(round_rows * 5 >= rows * 4, "lit west of its middle and shaded east of it in %d of %d rows" % [round_rows, rows])
	check(furrowed * 2 >= rows, "bark furrows and plates mark %d of %d rows" % [furrowed, rows])
	check(plates > 20, "the plates' lips catch the light (%d px)" % plates)
	check(lit_stray == 0, "only where the trunk faces the light (%d px elsewhere)" % lit_stray)
	# The furrows bunch toward the edges: round, not a striped board.
	var y0 := -150
	var hw0 := HighSeat.root_half(y0)
	var seen: Array[float] = []
	for k in range(-20, 21):
		var fa := HighSeat.furrow_angle(k, y0)
		if absf(fa) < PI * 0.5:
			seen.append(sin(fa))
	check(seen.size() >= 4, "%d furrows show on the trunk's face" % seen.size())
	seen.sort()
	var near_edge := minf(seen[1] - seen[0], seen[-1] - seen[-2])
	var near_mid := 0.0
	for i in seen.size() - 1:
		near_mid = maxf(near_mid, seen[i + 1] - seen[i])
	check(near_edge < near_mid, "furrows lie closer at the edge (%.2f) than the middle (%.2f) of a %d px trunk" % [near_edge, near_mid, hw0 * 2])
	# Its shadow on the seat's back, east of it.
	var y := HighSeat.BACK_TOP + 40
	var e := HighSeat.root_x(y) + HighSeat.root_half(y) + 1
	var shade := 0
	for x in range(e, e + HighSeat.CAST):
		if px.get(Vector2i(x, y), Color.BLACK) in [HighSeat.WOOD[0], HighSeat.ROT[0], HighSeat.OUTLINE]:
			shade += 1
	check(shade == HighSeat.CAST, "the root's shadow falls on the seat's back east of it (%d of %d px)" % [shade, HighSeat.CAST])


## What the root broke: the seat's back is split and its east half has
## dropped; the lintel is snapped and lifted at the break.
func test_the_root_split_the_high_seat_and_snapped_its_lintel() -> void:
	var px := _pixels()
	var split := HighSeat.root_x(HighSeat.BACK_TOP)
	check(absi(split) < HighSeat.BACK_HALF - 4, "the split is in the back, not beside it")
	# The crest is the same shape on both sides; the east side stands lower.
	var compared := 0
	for x: int in [4, 12, 16, 24, 28]:
		if -x >= split or x < split:
			continue
		compared += 1
		check(HighSeat.back_top(x) - HighSeat.back_top(-x) == HighSeat.BACK_DROP, "the back's east half has dropped %d px (column %d)" % [HighSeat.BACK_DROP, x])
	check(compared >= 2, "both halves of the back are there to compare (%d columns)" % compared)
	check(HighSeat.BACK_DROP >= 3 and HighSeat.BACK_DROP <= 8, "enough to see, not enough to fall")
	var y := HighSeat.BACK_TOP + 30
	var west_x := HighSeat.root_x(y) - HighSeat.root_half(y) - 4
	var east_x := HighSeat.root_x(y) + HighSeat.root_half(y) + 6
	check(west_x > -HighSeat.BACK_HALF and _timber(px.get(Vector2i(west_x, y), Color.BLACK)), "the back shows west of the root")
	check(east_x < HighSeat.BACK_HALF and _timber(px.get(Vector2i(east_x, y), Color.BLACK)), "and east of it")
	check(px.get(Vector2i(HighSeat.BACK_HALF - 4, HighSeat.back_top(HighSeat.BACK_HALF - 4)), Color.BLACK) == HighSeat.WOOD[2], "its top edge is lit")
	check(HighSeat.crest(0) > HighSeat.crest(12) and HighSeat.crest(12) > HighSeat.crest(26), "the crest steps up to its middle")
	check(px.get(Vector2i(HighSeat.SEAT_HALF - 3, HighSeat.SEAT_TOP - 2), Color.BLACK) == HighSeat.WOOD[2], "the seat board is whole, lit along its top")
	check(HighSeat.SEAT_TOP < -24 and HighSeat.SEAT_TOP > -48, "a seat a dwarf could climb onto (%d px)" % -HighSeat.SEAT_TOP)
	# The lintel.
	var at := HighSeat.lintel_break()
	check(not HighSeat.lintel_at(at), "the lintel is gone where the root goes through")
	check(HighSeat.lintel_at(at - 20) and HighSeat.lintel_at(at + 20), "and stands on both sides of it")
	check(HighSeat.lintel_lift(-HighSeat.PILLAR_X) == 0 and HighSeat.lintel_lift(HighSeat.PILLAR_X) == 0, "it still lies on both pillars")
	var rising := true
	for x in range(-HighSeat.PILLAR_X, at - 1):
		rising = rising and HighSeat.lintel_lift(x + 1) >= HighSeat.lintel_lift(x)
	for x in range(at + 1, HighSeat.PILLAR_X):
		rising = rising and HighSeat.lintel_lift(x + 1) <= HighSeat.lintel_lift(x)
	check(rising, "each half rises toward the break")
	check(HighSeat.WEST_LIFT >= 8 and HighSeat.lintel_lift(at - 1) >= HighSeat.WEST_LIFT - 1, "the west half is lifted %d px on the root's shoulder" % HighSeat.WEST_LIFT)
	check(HighSeat.EAST_LIFT > 0 and HighSeat.EAST_LIFT < HighSeat.WEST_LIFT - 3, "the east half less: the ends no longer meet")
	for x: int in [-60, -30, 40, 70]:
		var top := HighSeat.LINTEL_TOP - HighSeat.lintel_lift(x)
		check(px.get(Vector2i(x, top + 1), Color.BLACK) in [HighSeat.WOOD[2], HighSeat.ROT[0], HighSeat.ROT[1]], "the lintel is lit along its top at column %d" % x)
		check(px.get(Vector2i(x, top + HighSeat.LINTEL_DEEP - 1), Color.BLACK) == HighSeat.OUTLINE, "and outlined under it")
	# A zigzag is carved along it: every column of its face has a cut.
	var carved := 0
	for x in range(-60, -30):
		var top := HighSeat.LINTEL_TOP - HighSeat.lintel_lift(x)
		for row in range(4, 12):
			if px.get(Vector2i(x, top + row), Color.BLACK) == HighSeat.OUTLINE:
				carved += 1
				break
	check(carved == 30, "a zigzag is carved along its face (%d of 30 columns)" % carved)
	check(HighSeat.LINTEL_TOP - HighSeat.WEST_LIFT > HighSeat.CEILING + 48, "under the ceiling with room over it")


## "With the sap": sap runs down the root, has pooled on the seat and drips
## to the dais; nothing else is gold. The timber rots only beside the root.
func test_high_seat_sap_runs_down_the_root_and_the_timber_rots_beside_it() -> void:
	var px := _pixels()
	var sap := 0
	var astray := 0
	var rot := 0
	var far := 0
	for c: Vector2i in px:
		var col: Color = px[c]
		if col in HighSeat.SAP:
			sap += 1
			var pool := c.x >= HighSeat.POOL.x and c.x < HighSeat.POOL.y and c.y < HighSeat.SEAT_TOP - 2 and c.y >= HighSeat.SEAT_TOP - 3 - HighSeat.POOL_HIGH
			var puddle := absi(c.x - HighSeat.DRIP_X) <= HighSeat.PUDDLE_HALF and c.y >= -HighSeat.DAIS_HIGH - 2 and c.y < -HighSeat.DAIS_HIGH
			if not (_on_root(c) or pool or puddle):
				astray += 1
		elif col in HighSeat.ROT:
			rot += 1
			if absi(c.x - HighSeat.root_x(c.y)) > HighSeat.root_half(c.y) + HighSeat.ROT_REACH:
				far += 1
	check(sap > 80, "sap is drawn (%d px)" % sap)
	check(astray == 0, "only on the root, the seat's pool and the dais's puddle (%d px elsewhere)" % astray)
	check(rot > 150, "the timber rots (%d px)" % rot)
	check(far == 0, "only within %d px of the root (%d px farther)" % [HighSeat.ROT_REACH, far])
	var runs := HighSeat.sap_runs()
	check(runs.size() >= 5, "%d runs of sap" % runs.size())
	for run: Vector3i in runs:
		var x := HighSeat.root_x(run.x) - HighSeat.root_half(run.x) + run.z
		check(px.get(Vector2i(x, run.x), Color.BLACK) == HighSeat.SAP[2], "a run begins with a glint at row %d" % run.x)
		check(run.x > HighSeat.CEILING and run.x + run.y + 3 < 0, "between the ceiling and the floor")
	check(HighSeat.POOL.x > HighSeat.root_x(HighSeat.SEAT_TOP) and HighSeat.POOL.y < HighSeat.SEAT_HALF, "the pool lies on the seat board beside the root")
	check(px.get(Vector2i(HighSeat.POOL.x + 2, HighSeat.SEAT_TOP - 3), Color.BLACK) in HighSeat.SAP, "drawn there")
	# The drip.
	check(HighSeat.DRIP_X - HighSeat.PUDDLE_HALF > HighSeat.SEAT_HALF + 3, "the drip falls clear of the seat")
	check(HighSeat.DRIP_X + HighSeat.PUDDLE_HALF < HighSeat.SHIELD_FALLEN.x - 8, "and of the fallen shield")
	check(px.get(Vector2i(HighSeat.DRIP_X, HighSeat.drip_top() - 2), Color.BLACK) in HighSeat.ROOT, "from under the side root")
	check(px.get(Vector2i(HighSeat.DRIP_X, -HighSeat.DAIS_HIGH - 1), Color.BLACK) in HighSeat.SAP, "to a puddle on the dais")
	var lo := 1000.0
	var hi := -1000.0
	var falls := true
	var was := HighSeat.drip_y(0.0)
	for k in range(1, 64):
		var at := HighSeat.DRIP_PERIOD * k / 64.0
		var y := HighSeat.drip_y(at)
		falls = falls and y >= was
		was = y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(falls, "a drop only falls")
	check(lo == HighSeat.drip_top(), "it swells under the root")
	check(hi < -HighSeat.DAIS_HIGH and hi > -HighSeat.DAIS_HIGH - 12.0, "and lands on the puddle (%.0f)" % hi)
	check(HighSeat.drip_y(HighSeat.DRIP_PERIOD * 0.25) == HighSeat.drip_top(), "it hangs for half its time")
	check(HighSeat.DRIP_PERIOD >= 2.0, "slowly: sap, not water")


## In the room: the high seat stands on solid floor in open air, its root goes
## into the ceiling, no ledge crosses it, and the sign tells of it.
func test_the_rot_dwarf_hall_has_its_high_seat() -> void:
	var w := make_world({}, "heartwood/dwarf_hall")
	await frames(2)
	var seat := _seat(w.room)
	check(seat != null, "the Rot Dwarf Hall has its high seat")
	if seat == null:
		return
	var room: Room = w.room
	var at := seat.position
	for side: int in [-1, 1]:
		check(room.is_solid_at(at + Vector2(side * (HighSeat.DAIS_HALF - 2), 4)), "the dais's %s end lies on solid floor" % ("west" if side < 0 else "east"))
	check(not room.is_solid_at(at + Vector2(0, -4)), "on the floor, not in it")
	var top := Vector2(HighSeat.root_x(HighSeat.CEILING), HighSeat.CEILING)
	check(room.is_solid_at(at + top + Vector2(0, -4)), "the root goes into the ceiling")
	check(not room.is_solid_at(at + top + Vector2(0, 4)), "out of open air")
	# No wall or ledge stands in front of it: the landmark is seen whole.
	var covered := 0
	for y in range(HighSeat.CEILING + 8, -8, 8):
		for x in range(-HighSeat.LINTEL_HALF, HighSeat.LINTEL_HALF + 1, 8):
			var p := at + Vector2(x, y)
			if room.is_solid_at(p) or room.is_one_way_at(p):
				covered += 1
	check(covered == 0, "no wall or ledge stands across it (%d points)" % covered)
	var text := FileAccess.get_file_as_string("res://levels/heartwood/dwarf_hall.room")
	check(text.contains("These were Amberlee dwarves once."), "the sign tells of the dwarves")
	check(text.contains("The rot came up through the roots with the sap."), "and of the root, the rot and the sap")
	# The sign stands clear of it, to be read first on the way in from the west.
	var sign_x := 10 * 16 + 8
	check(at.x - HighSeat.LINTEL_HALF - sign_x > 48, "the sign stands clear of it (%d px)" % int(at.x - HighSeat.LINTEL_HALF - sign_x))
	check(seat.z_index < 0, "behind everyone who walks past")
	check(seat.get_child_count() == 0, "scenery only: nothing to stand on, to touch or to be hurt by")
	await frames(30)
	check(seat.t > 0.2, "its sap drips")


func _grid() -> Array[String]:
	var rows: Array[String] = []
	var text := FileAccess.get_file_as_string("res://levels/heartwood/dwarf_hall.room").replace("\r", "")
	for line: String in text.split("---\n")[1].split("\n"):
		if line != "":
			rows.append(line)
	return rows


## The independent grade after pass 575: "most rooms are a rectangular tile
## frame around a dead-level floor". The fourth room changed for it (12.63's
## rule, pass 579). The root that split the high seat has heaved the floor
## east of it into a bank, and past the bank the floor has fallen in: a ramp
## down a tile, a ramp down another, and a broken stair of two steps up to
## the east door's floor. The ceiling hangs in steps everywhere but over the
## seat, which keeps its 18 open rows.
func test_the_rot_dwarf_hall_is_not_a_level_box() -> void:
	var grid := _grid()
	check(grid.size() == 23 and grid[0].length() == 80, "the room keeps its size")
	var wide := grid[0].length()
	var floors := {}
	var ceilings := {}
	var floor_of: Array[int] = []
	var top_of: Array[int] = []
	var ramps: Array[Vector2i] = []
	for x in wide:
		var y := grid.size() - 1
		while y > 0 and grid[y][x] in "#/\\":
			y -= 1
		floor_of.append(y)
		var top := 0
		while top < grid.size() and grid[top][x] == "#":
			top += 1
		top_of.append(top)
		for row in grid.size():
			if grid[row][x] in "/\\":
				ramps.append(Vector2i(x, row))
		if x == 0 or x == wide - 1 or grid[y + 1][x] in "/\\":
			continue  # the walls, a ramp
		floors[y] = true
		ceilings[top] = true
	var level := floor_of[1]
	check(floors.size() == 4, "the floor stands at four heights (%s)" % [floors.keys()])
	check(ceilings.size() >= 4, "the ceiling's underside stands at four heights (%s)" % [ceilings.keys()])
	check(floor_of[wide - 2] == level, "both doors open on the same floor")
	# The high seat needs its floor and its 18 open rows (levels/README.md).
	var seat_x := 22
	for x in range(seat_x - 6, seat_x + 7):
		check(floor_of[x] == level and top_of[x] == 2, "the high seat's floor and ceiling are as they were at tile %d" % x)
	check(level - 2 + 1 == 18, "18 open rows over its floor")
	check(ramps.size() == 4, "four ramp tiles (%s)" % [ramps])
	if ramps.size() != 4:
		return
	for r: Vector2i in ramps:
		var high := -1 if grid[r.y][r.x] == "\\" else 1
		check(grid[r.y + 1][r.x] == "#" and grid[r.y][r.x + high] == "#", "the ramp at %s has ground under it and on its high side" % r)
		check(grid[r.y][r.x - high] == ".", "and open floor at its foot")
	# The bank: the root has heaved the floor up a tile, east of the seat.
	check(grid[ramps[0].y][ramps[0].x] == "/" and ramps[0].y == level, "a ramp climbs from the seat's floor")
	check(grid[ramps[1].y][ramps[1].x] == "\\" and ramps[1].y == level, "and a ramp comes down again")
	check(ramps[0].x > seat_x + 6 + 1, "clear of the high seat (tile %d)" % ramps[0].x)
	var bank := 0
	for x in range(ramps[0].x + 1, ramps[1].x):
		if floor_of[x] == level - 1:
			bank += 1
	check(bank == ramps[1].x - ramps[0].x - 1 and bank >= 5, "between them the floor stands a tile higher (%d tiles)" % bank)
	# Nothing to pick up moved, and no ledge: the low plank's west end is over
	# the bank (a shorter jump) and its east end over the old floor.
	var plank: Array[int] = []
	for x in wide:
		if grid[16][x] == "-":
			plank.append(x)
	check(plank.size() == 14 and plank[0] == 36 and plank[6] == 42 and plank[7] == 60 and plank[13] == 66, "the low planks are where they were (%s)" % [plank])
	check(floor_of[plank[0]] == level - 1 and floor_of[plank[6]] == level, "the west plank stands with one leg on the bank and one on the floor")
	check(floor_of[plank[7]] == level and floor_of[plank[13]] == level, "the east plank on the east door's floor")
	check(grid[11][47] == "$" and grid[12].substr(44, 7) == "-------", "the chest is on its plank")
	check(grid[10][70] == "F" and grid[12].substr(68, 5) == "-----", "the Potion Shard over its own")
	check(grid[19][25] == "D" and grid[19][58] == "D" and grid[19].count("M") == 1, "two Rot Dwarves and the Blinkhop")
	check(floor_of[grid[19].find("M")] == level, "the Blinkhop on the floor between the bank and the fall")
	# The fall: a tile down, then two, on the room's last row of ground.
	check(grid[ramps[2].y][ramps[2].x] == "\\" and ramps[2].y == level + 1, "a ramp goes down where the floor fell in")
	check(grid[ramps[3].y][ramps[3].x] == "\\" and ramps[3].y == level + 2, "and a second, down again")
	var shelf := 0
	for x in range(ramps[2].x + 1, ramps[3].x):
		if floor_of[x] == level + 1:
			shelf += 1
	check(shelf == ramps[3].x - ramps[2].x - 1 and shelf >= 3, "between them the floor lies a tile down (%d tiles)" % shelf)
	var sump := 0
	var x := ramps[3].x + 1
	while floor_of[x] == level + 2:
		check(grid[grid.size() - 1][x] == "#", "the low floor at %d is the room's last row of ground" % x)
		sump += 1
		x += 1
	check(sump >= 4, "the low floor lies two tiles down (%d tiles)" % sump)
	# Its east side is a broken stair, not a ramp: a Rot Dwarf turns at a
	# step and walks down a ramp, and the east dwarf keeps the gate's floor.
	check(floor_of[x] == level + 1 and floor_of[x + 1] == level, "a stair of two steps climbs out on the east (tiles %d and %d)" % [x, x + 1])
	var stair := x
	for e in range(stair + 1, wide - 1):
		if floor_of[e] != level:
			check(false, "the east door's floor is level (tile %d)" % e)
	check(grid[19].rfind("D") > stair + 1, "the east dwarf starts on it")
	var hazards := 0
	for row: String in grid:
		hazards += row.count("^") + row.count("o")
	check(hazards == 0, "nothing in the hall is spiked: the fall is only a low place")
	# The ceiling hangs low over both doors and is never ruled straight for
	# long outside the seat's span.
	check(top_of[1] >= 4 and top_of[wide - 2] >= 4, "the ceiling hangs low over both doors (%d and %d)" % [top_of[1], top_of[wide - 2]])
	var run := 0
	var longest := 0
	for c in range(1, wide - 1):
		run = run + 1 if c > 1 and top_of[c] == top_of[c - 1] else 1
		longest = maxi(longest, run)
	check(longest <= 21, "the longest straight run of ceiling is the seat's (%d tiles)" % longest)
	for c in range(1, wide - 1):
		check(top_of[c] <= 5, "the ceiling at %d leaves the planks their headroom" % c)
	# Walked for real. The dwarves first, with the player out of their sight
	# on the chest's plank: each keeps his own floor.
	var w := make_world({}, "heartwood/dwarf_hall")
	await frames(3)
	var p := w.player
	p.global_position = cell_feet(47, 11)
	p.velocity = Vector2.ZERO
	var dwarves: Array[RotDwarf] = []
	for e: Node in runner.get_tree().get_nodes_in_group("enemy"):
		if e is RotDwarf:
			dwarves.append(e)
	check(dwarves.size() == 2, "both Rot Dwarves are here")
	dwarves.sort_custom(func(a: RotDwarf, b: RotDwarf) -> bool: return a.global_position.x < b.global_position.x)
	if dwarves.size() == 2:
		await frames(20)
		var y0: Array[float] = [dwarves[0].global_position.y, dwarves[1].global_position.y]
		var lo: Array[float] = [dwarves[0].global_position.x, dwarves[1].global_position.x]
		var hi: Array[float] = lo.duplicate()
		var drift: Array[float] = [0.0, 0.0]
		for k in 1800:
			await frames(1)
			for i in 2:
				var d := dwarves[i]
				lo[i] = minf(lo[i], d.global_position.x)
				hi[i] = maxf(hi[i], d.global_position.x)
				drift[i] = maxf(drift[i], absf(d.global_position.y - y0[i]))
		check(drift[0] <= 2.0, "the west dwarf never leaves the seat's floor (%.0f px)" % drift[0])
		check(hi[0] <= (ramps[0].x + 1) * Room.TILE and hi[0] > (seat_x + 6) * Room.TILE, "he turns at the bank's ramp (x %.0f)" % hi[0])
		check(lo[0] < (seat_x - 6) * Room.TILE, "and paces past the high seat (x %.0f)" % lo[0])
		check(drift[1] <= 2.0, "the east dwarf never goes down into the fall (%.0f px)" % drift[1])
		check(lo[1] >= (stair + 1) * Room.TILE and lo[1] < (stair + 3) * Room.TILE, "he turns at the stair's head (x %.0f)" % lo[1])
		check(hi[1] > 70 * Room.TILE, "and paces to the east door (x %.0f)" % hi[1])
	for e: Node in runner.get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await frames(2)
	# A walk east from the seat climbs the bank, comes down, and ends in the
	# low floor two tiles under the doors: four heights, no jump.
	p.global_position = cell_feet(ramps[0].x - 3, level)
	p.velocity = Vector2.ZERO
	await frames(10)
	var from_y := p.global_position.y
	var hp := p.hp
	var highest := from_y
	p.input.move_x = 1
	var steps := 0
	while p.global_position.x < (ramps[3].x + 2) * Room.TILE and steps < 900:
		await frames(1)
		steps += 1
		highest = minf(highest, p.global_position.y)
	p.input.move_x = 0
	await frames(10)
	check_near(from_y - highest, float(Room.TILE), 2.0, "a walk east from the seat climbs the bank, a tile up")
	check_near(p.global_position.y - from_y, 2.0 * Room.TILE, 2.0, "and goes down both ramps to the low floor (after %d frames)" % steps)
	check(p.is_on_floor() and p.hp == hp, "unhurt")
	# The stair stops a walk, and two short jumps climb it.
	p.input.move_x = 1
	await frames(120)
	check(p.global_position.x < (stair + 1) * Room.TILE and absf(p.global_position.y - from_y - 2.0 * Room.TILE) <= 2.0, "the stair's first step stops a walk (x %.0f)" % p.global_position.x)
	steps = 0
	while p.global_position.x < (stair + 3) * Room.TILE and steps < 300:
		p.input.jump_pressed = p.is_on_floor() and steps % 20 == 0
		p.input.jump_held = p.input.jump_pressed
		await frames(1)
		steps += 1
	p.input.move_x = 0
	p.input.jump_pressed = false
	p.input.jump_held = false
	await frames(30)
	check(p.global_position.x >= (stair + 3) * Room.TILE and p.is_on_floor(), "jumps climb the stair (x %.0f after %d frames)" % [p.global_position.x, steps])
	check_near(p.global_position.y, from_y, 2.0, "back on the doors' floor")
	w.queue_free()
	await frames(2)
