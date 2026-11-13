extends TestSuite
## Fire seal art (pass 544, bible 12.36): a seal is one sheet of pixel fire on
## the master palette's heat ramp, where the pass 540 grade saw "the Haar's
## stacked orange blocks" (each tile drew the same four rectangle tongues).

const O := Vector2(520, 296)


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func _heat_index(c: Color) -> int:
	return FireSeal.HEAT.find(c)


## Every tone the seal uses is a master palette value.
func test_fire_seal_tones_are_master_palette() -> void:
	var palette := _palette()
	for tone: Color in FireSeal.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))


## Every frame is pixel art in the seal's own tones: opaque, on the palette,
## inside the tile's width.
func test_fire_seal_paints_only_its_own_tones() -> void:
	var tones := {}
	for tone: Color in FireSeal.TONES:
		tones[tone.to_html(false)] = true
	var stray := 0
	var outside := 0
	var lit := 0
	for step in 12:
		for joined in [0, FireSeal.UP, FireSeal.DOWN, FireSeal.UP | FireSeal.DOWN | FireSeal.LEFT]:
			for out in [0.0, 0.4, 1.0]:
				var px := FireSeal.cells(O, step, joined, out)
				for c: Vector2i in px:
					var col: Color = px[c]
					lit += 1
					if col.a < 1.0 or not tones.has(col.to_html(false)):
						stray += 1
					if c.x < -8 or c.x > 7 or c.y > 7:
						outside += 1
	check(lit > 5000, "the seals are drawn (%d px)" % lit)
	check(stray == 0, "no blended or off-palette pixels (%d)" % stray)
	check(outside == 0, "nothing strays past the tile's sides or floor (%d)" % outside)


## Stacked tiles join into one sheet: no empty row where they meet, only the
## column's top licks above its tile, and only its foot stands on coals.
func test_a_column_of_fire_seals_is_one_sheet() -> void:
	var gaps := 0
	var licks_top := 0
	var licks_inside := 0
	var coal_inside := 0
	var coal_foot := 0
	for step in 20:
		var top := FireSeal.cells(O, step, FireSeal.DOWN)
		var mid := FireSeal.cells(O + Vector2(0, 16), step, FireSeal.UP | FireSeal.DOWN)
		var foot := FireSeal.cells(O + Vector2(0, 32), step, FireSeal.UP)
		for pair: Array in [[top, 7], [mid, -8], [mid, 7], [foot, -8]]:
			var row := 0
			for x in range(-4, 4):
				if (pair[0] as Dictionary).has(Vector2i(x, pair[1])):
					row += 1
			if row < 6:
				gaps += 1
		for c: Vector2i in top:
			if c.y < -8:
				licks_top += 1
		for d: Dictionary in [mid, foot]:
			for c: Vector2i in d:
				if c.y < -8:
					licks_inside += 1
		for d: Dictionary in [top, mid]:
			for c: Vector2i in d:
				if d[c] == FireSeal.COAL:
					coal_inside += 1
		for c: Vector2i in foot:
			if foot[c] == FireSeal.COAL:
				coal_foot += 1
	var a := FireSeal.cells(O + Vector2(0, 16), 5, FireSeal.UP | FireSeal.DOWN)
	var b := FireSeal.cells(O + Vector2(0, 32), 5, FireSeal.UP | FireSeal.DOWN)
	var same := 0
	for c: Vector2i in a:
		if b.get(c, Color(0, 0, 0, 0)) == a[c]:
			same += 1
	check(same < a.size() * 0.7, "neighbouring tiles are not one stamp (%d of %d px alike)" % [same, a.size()])
	check(gaps == 0, "the flames run unbroken across the seams (%d thin rows)" % gaps)
	check(licks_top > 60, "the column's top licks above its tile (%d px over 20 frames)" % licks_top)
	check(licks_inside == 0, "a tile with a seal above it does not lick into it (%d)" % licks_inside)
	check(coal_foot > 100 and coal_inside == 0, "coals at the foot only (%d at the foot, %d above)" % [coal_foot, coal_inside])


## The fire is hotter inside than at an open side, an open side is ragged, and
## a side with a seal beside it is not (two-wide seals read as one wall).
func test_fire_seal_is_hot_inside_and_ragged_only_where_open() -> void:
	var core := 0.0
	var edge := 0.0
	var core_n := 0
	var edge_n := 0
	var open_edge_lit := 0
	var joined_edge_lit := 0
	var widths := {}
	for step in 20:
		var lone := FireSeal.cells(O, step, FireSeal.UP | FireSeal.DOWN)
		var left := FireSeal.cells(O, step, FireSeal.UP | FireSeal.DOWN | FireSeal.RIGHT)
		var right := FireSeal.cells(O + Vector2(16, 0), step, FireSeal.UP | FireSeal.DOWN | FireSeal.LEFT)
		for y in range(-8, 6):
			var w := 0
			for x in range(-8, 8):
				var c := Vector2i(x, y)
				if not lone.has(c):
					continue
				w += 1
				var h := _heat_index(lone[c])
				if h < 0:
					continue
				if absi(x * 2 + 1) <= 3:
					core += h
					core_n += 1
				elif x == -7 or x == 6:
					edge += h
					edge_n += 1
			widths[w] = true
			if lone.has(Vector2i(7, y)):
				open_edge_lit += 1
			if left.has(Vector2i(7, y)):
				joined_edge_lit += 1
			if right.has(Vector2i(-8, y)):
				joined_edge_lit += 1
	core /= maxf(1.0, core_n)
	edge /= maxf(1.0, edge_n)
	check(core > edge + 1.5, "the core runs hotter than the edges (%.2f vs %.2f)" % [core, edge])
	check(widths.size() >= 4, "an open side is ragged: the flame's width varies (%d widths)" % widths.size())
	check(joined_edge_lit > open_edge_lit * 4 and joined_edge_lit > 400, "the side joined to a seal is filled (%d lit, %d where open)" % [joined_edge_lit, open_edge_lit])


## The flames move: frames differ, and the heat steps between ramp tones.
func test_fire_seal_flickers_in_palette_steps() -> void:
	var a := FireSeal.cells(O, 3, FireSeal.UP | FireSeal.DOWN)
	var b := FireSeal.cells(O, 4, FireSeal.UP | FireSeal.DOWN)
	var changed := 0
	var used := {}
	for c: Vector2i in a:
		if b.get(c, Color(0, 0, 0, 0)) != a[c]:
			changed += 1
		used[_heat_index(a[c])] = true
	# Inside a wall of seals (joined on every side) nothing is ragged, so what
	# moves there is the fire itself.
	var all := FireSeal.UP | FireSeal.DOWN | FireSeal.LEFT | FireSeal.RIGHT
	var ia := FireSeal.cells(O + Vector2(0, 16), 3, all)
	var ib := FireSeal.cells(O + Vector2(0, 16), 7, all)
	var leaps := 0
	var core := {}
	for c: Vector2i in ia:
		if FireSeal.HEAT.has(ia[c]) and FireSeal.HEAT.has(ib.get(c, Color.BLACK)) and absi(_heat_index(ib[c]) - _heat_index(ia[c])) >= 2:
			leaps += 1
		if FireSeal.HEAT.has(ia[c]):
			core[_heat_index(ia[c])] = true
	check(changed > 30, "the next frame moves (%d px change)" % changed)
	check(leaps > 10, "the fire rises, not just shimmers: %d px jump two tones or more in four frames" % leaps)
	check(core.size() >= 3, "licks of cooler fire run through the core (%d tones there)" % core.size())
	check(used.size() >= 6, "the fire uses most of its ramp (%d tones)" % used.size())


## A few runes, not a grid: one on every other tile down the seal's left edge,
## each burnt dark and ringed with gold.
func test_fire_seal_carries_a_few_runes() -> void:
	check(FireSeal.has_rune(Vector2(8, 8), 0) != FireSeal.has_rune(Vector2(8, 24), 0), "runes skip every other row")
	check(not FireSeal.has_rune(Vector2(8, 8), FireSeal.LEFT) and not FireSeal.has_rune(Vector2(8, 24), FireSeal.LEFT), "a tile with a seal to its left has none")
	var with_rune := O if FireSeal.has_rune(O, 0) else O + Vector2(0, 16)
	var px := FireSeal.cells(with_rune, 0, 0)
	var dark := 0
	var ringed := 0
	for c: Vector2i in px:
		if px[c] != FireSeal.RUNE:
			continue
		dark += 1
		for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var n: Color = px.get(c + o, Color(0, 0, 0, 0))
			if n != FireSeal.HEAT[5] and n != FireSeal.HEAT[4] and n != FireSeal.RUNE:
				ringed -= 1
				break
		ringed += 1
	check(dark >= 9, "the rune is drawn (%d px)" % dark)
	check(ringed == dark, "the rune is closed in its gold ring (%d of %d pixels border only gold or rune)" % [ringed, dark])
	var bare := FireSeal.cells(with_rune + Vector2(0, 16), 0, 0)
	check(not bare.values().has(FireSeal.RUNE), "the tile below it carries none")


## Doused: steam only while the fire dies, and once out only a scorched socket
## at the column's foot.
func test_fire_seal_goes_out_to_ash_at_its_foot() -> void:
	var burning := 0
	for step in 12:
		for joined in [0, FireSeal.UP, FireSeal.DOWN]:
			var px := FireSeal.cells(O + Vector2(0, 16), step, joined)
			burning += px.values().count(FireSeal.STEAM[0]) + px.values().count(FireSeal.STEAM[1])
	check(burning == 0, "no steam while the seal burns (%d px)" % burning)
	var dying := FireSeal.cells(O, 2, 0, 0.3)
	check(dying.values().count(FireSeal.STEAM[1]) > 8, "steam rises as it goes out")
	var foot := FireSeal.cells(O, 2, FireSeal.UP, 1.0)
	var mid := FireSeal.cells(O, 2, FireSeal.UP | FireSeal.DOWN, 1.0)
	var only_ash := true
	for c: Vector2i in foot:
		only_ash = only_ash and FireSeal.ASH.has(foot[c]) and c.y >= 4
	check(foot.size() >= 16 and only_ash, "the foot is a low socket of ash (%d px)" % foot.size())
	check(mid.is_empty(), "a tile with a seal below it leaves nothing")


# --- Pass 549 (bible 12.40): the seals light the stone around them ---------------

## One pool per short column, from its middle tile; a tall seal every third tile.
func test_fire_seal_pools_are_spaced_down_the_column() -> void:
	for tiles in [1, 2, 3]:
		var anchors := 0
		for above in tiles:
			if FireSeal.anchor_at(above, tiles):
				anchors += 1
		check(anchors == 1, "a column of %d casts one pool (%d)" % [tiles, anchors])
	check(FireSeal.anchor_at(1, 3), "a column of three casts from its middle tile")
	check(FireSeal.anchor_at(0, 2), "a column of two casts from its upper tile")
	var tall := 0
	for above in 14:
		if FireSeal.anchor_at(above, 14):
			tall += 1
	check(tall == 5, "a seal 14 tall casts a pool every third tile (%d)" % tall)
	check(FireSeal.glow_reach(false, 3) == 0.0, "a tile off the anchor casts no pool")
	check(FireSeal.glow_reach(true, 3) > FireSeal.glow_reach(true, 1), "a taller short column casts a wider pool")
	check(FireSeal.glow_reach(true, 14) == FireSeal.glow_reach(true, 3), "a tall seal's pools are all one size")


## The heat halo: only off open sides, falling off in dithered steps, shallow
## onto the floor, never on the flames, and seamless between tiles.
func test_fire_seal_halo_glows_off_open_sides() -> void:
	var lone := FireSeal.halo_cells(O, 0)
	var on_flames := 0
	var past := 0
	var floor_deep := 0
	var levels := {}
	for c: Vector2i in lone:
		var a: float = lone[c]
		levels[snappedf(a, 0.001)] = true
		if c.x >= -8 and c.x <= 7 and c.y >= -8 and c.y <= 7:
			on_flames += 1
		if a > FireSeal.HALO_PEAK + 0.0001:
			past += 1
		if c.y > 7 + FireSeal.HALO_FLOOR:
			floor_deep += 1
	check(lone.size() > 600, "a lone tile throws a halo (%d px)" % lone.size())
	check(on_flames == 0, "the halo never sits on the flames (%d)" % on_flames)
	check(past == 0, "no halo pixel passes the peak (%d)" % past)
	check(floor_deep == 0, "the halo onto the floor stays shallow (%d)" % floor_deep)
	check(levels.size() >= 3 and levels.size() <= 4, "it steps through a few levels, not a gradient (%d)" % levels.size())
	# Near the flames is brighter than far out, on average.
	var near := 0.0
	var far := 0.0
	for y in range(-8, 8):
		near += float(lone.get(Vector2i(-10, y), 0.0)) + float(lone.get(Vector2i(-11, y), 0.0))
		far += float(lone.get(Vector2i(-24, y), 0.0)) + float(lone.get(Vector2i(-25, y), 0.0))
	check(near > far * 2.0, "the halo falls off away from the flames (%.2f vs %.2f)" % [near, far])
	# A joined side throws nothing; a column's inner tile has no top or floor halo.
	var inner := FireSeal.halo_cells(O, FireSeal.UP | FireSeal.DOWN | FireSeal.RIGHT)
	var wrong := 0
	for c: Vector2i in inner:
		if c.x > 7 or c.y < -8 or c.y > 7:
			wrong += 1
	check(inner.size() > 100, "an inner tile still glows off its open side")
	check(wrong == 0, "nothing glows off a joined side (%d)" % wrong)
	# The dither is in world pixels: two tiles stacked give the same pattern.
	var below := FireSeal.halo_cells(O + Vector2(0, 16), FireSeal.UP | FireSeal.DOWN | FireSeal.RIGHT)
	var seam := 0
	for x in range(-8 - FireSeal.HALO, -8):
		# The rows either side of the seam differ by no more than one dither step.
		var a_top: float = inner.get(Vector2i(x, 7), 0.0)
		var a_low: float = below.get(Vector2i(x, -8), 0.0)
		if absf(a_top - a_low) > FireSeal.HALO_PEAK * 0.26:
			seam += 1
	check(seam == 0, "the halo runs across the seam between tiles (%d jumps)" % seam)


## The halo breathes in alpha, gently, and never goes out while the seal burns.
func test_fire_seal_halo_breathes() -> void:
	var seen := {}
	for step in 40:
		var f := FireSeal.halo_flicker(O, step)
		check(f >= 0.8 and f <= 1.0, "the breath stays gentle (%.2f)" % f)
		seen[snappedf(f, 0.01)] = true
	check(seen.size() > 4, "it moves (%d values)" % seen.size())


## In a room: a column of three casts one warm pool onto the stone, and dousing
## it puts the pool and the halo out.
func test_fire_seal_pool_lights_the_room_and_goes_out() -> void:
	var rows := grid_rows(14, 9)
	put_tiles(rows, 7, 3, "Z", 1, 3)
	var room := Room.from_text("\n".join(PackedStringArray(_rows_text(rows))))
	arena.add_child(room)
	await frames(2)
	var rl := room.get_node_or_null("RoomLight") as RoomLight
	check(rl != null, "the room built a RoomLight overlay")
	if rl == null:
		return
	var seals: Array[FireSeal] = []
	for c in room.get_children():
		if c is FireSeal:
			seals.append(c)
	check(seals.size() == 3, "three seal tiles (%d)" % seals.size())
	var warm := 0
	for pool: Array in rl._pools:
		if (pool[1] as Color).is_equal_approx(FireSeal.HEAT[3]):
			warm += 1
			check(pool[3] <= RoomLight.READABLE_CAP, "the seal's pool stays under the readability cap")
	check(warm == 1, "a column of three casts one pool (%d)" % warm)
	if seals.is_empty():
		return
	for s in seals:
		s.flag_id = ""
	seals[0].douse()
	warm = 0
	for pool: Array in rl._pools:
		if (pool[1] as Color).is_equal_approx(FireSeal.HEAT[3]):
			warm += 1
	check(warm == 0, "a doused seal's pool goes out (%d)" % warm)
	check(not seals[1]._halo.visible, "and so does its halo")


func _rows_text(rows: Array) -> Array:
	var out := []
	for row: Array in rows:
		out.append("".join(PackedStringArray(row)))
	return out


## The Haar's fog pockets are no longer perfect circles in hard rings: the rim
## wavers and the steps are dithered (the shader is checked by its source; the
## CPU mirror keeps the undisturbed centre).
func test_fog_pockets_waver_and_dither() -> void:
	var src := FileAccess.get_file_as_string("res://shaders/fog.gdshader")
	check(src.find("floor(clear * 4.0 + 0.5)") < 0, "the hard rounding to rings is gone")
	check(src.find("POCKET_WAVER") >= 0 and src.find("BAYER") >= 0, "the rim wavers and the steps are dithered")
	check(src.find("floor(p / 2.0)") >= 0, "the dither is in 2-pixel blocks of world pixels")
