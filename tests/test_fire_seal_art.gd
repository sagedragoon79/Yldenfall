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
