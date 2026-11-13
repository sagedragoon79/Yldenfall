extends TestSuite
## Light vein art (pass 545, bible 12.37): each vein in the Everbloom's shaft is
## a knot of faceted crystal shards on a fleshy node, painted in whole world
## pixels on master palette ramps, where the pass 535 grade saw "flat cyan
## diamonds" (one smooth pentagon of a single cyan).


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func _tones() -> Dictionary:
	var tones := {}
	for tone: Color in LightVein.TONES:
		tones[tone.to_html(false)] = true
	return tones


func _sky_index(c: Color) -> int:
	for i in LightVein.SKY.size():
		if LightVein.SKY[i].to_html(false) == c.to_html(false):
			return i
	return -1


## Every tone the vein uses is a master palette value.
func test_light_vein_tones_are_master_palette() -> void:
	var palette := _palette()
	for tone: Color in LightVein.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))


## The baked knot is pixel art: every pixel clear or one of its own opaque
## tones, and the outline closes every shape.
func test_light_vein_image_is_closed_pixel_art() -> void:
	var tones := _tones()
	for cut_off in [false, true]:
		var img := LightVein.build_image(cut_off)
		var stray := 0
		var open := 0
		var filled := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a == 0.0:
					continue
				filled += 1
				if c.a < 1.0 or not tones.has(c.to_html(false)):
					stray += 1
				if c.to_html(false) == LightVein.OUTLINE.to_html(false):
					continue
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var e := Vector2i(x, y) + d
					if e.x < 0 or e.y < 0 or e.x >= img.get_width() or e.y >= img.get_height() or img.get_pixelv(e).a == 0.0:
						open += 1
		check(filled > 200, "the knot is drawn (%d px, cut %s)" % [filled, cut_off])
		check(stray == 0, "no blended or off-palette pixels (%d, cut %s)" % [stray, cut_off])
		check(open == 0, "the outline closes every shape (%d gaps, cut %s)" % [open, cut_off])


## The crystal is faceted and lit from the upper left: several tones, the main
## shard's left face lighter than its right, and a fleshy node below it.
func test_light_vein_crystal_is_faceted() -> void:
	var img := LightVein.build_image(false)
	var sky := {}
	var night := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var i := _sky_index(c)
			if i >= 0:
				sky[i] = true
			elif c.a > 0.0 and LightVein.NIGHT.any(func(n: Color) -> bool: return n.to_html(false) == c.to_html(false)):
				night += 1
	check(sky.size() >= 5, "the crystal uses at least five tones of its ramp (%d)" % sky.size())
	check(night > 40, "it grows from a node of flesh (%d px)" % night)
	var main: Array = LightVein.SHARDS[2]
	var left := LightVein.crystal_tone(main, Vector2(-3.5, -2.5))
	var right := LightVein.crystal_tone(main, Vector2(3.5, -2.5))
	check(left > right, "the left face is lit, the right shaded (%d, %d)" % [left, right])
	check(LightVein.crystal_tone(main, Vector2(-0.5, -11.5)) > LightVein.crystal_tone(main, Vector2(-0.5, 4.5)), "the cap is lighter than the root")
	for shard: Array in LightVein.SHARDS.slice(0, 2):
		check(LightVein.crystal_tone(shard, shard[2] + Vector2(0, -2)) <= LightVein.crystal_tone(main, Vector2(-0.5, 4.5)), "a side shard sits no lighter than the main one")


## The light climbs: a bright head runs up the main shard and beads run up the
## vein, step by step, always in the crystal's own tones.
func test_light_vein_light_climbs() -> void:
	var tones := _tones()
	var heads: Array[int] = []
	var stray := 0
	var frames := {}
	for step in 10:
		var top := 999
		var pulse := LightVein.pulse_cells(step)
		for p: Array in pulse:
			var c: Vector2i = p[0]
			if p[1] == LightVein.SKY[6] or p[1] == LightVein.SKY[5]:
				top = mini(top, c.y)
			if not tones.has((p[1] as Color).to_html(false)):
				stray += 1
		heads.append(top)
		var thread := LightVein.thread_cells(step)
		var lit := []
		for p: Array in thread:
			if not tones.has((p[1] as Color).to_html(false)):
				stray += 1
			if p[1] != LightVein.SKY[0]:
				lit.append(p[0])
			check((p[0] as Vector2i).y < LightVein.TIP, "the vein runs above the knot")
		check(lit.size() >= 4, "beads of light run up the vein (step %d, %d)" % [step, lit.size()])
		frames[str(lit)] = true
	check(stray == 0, "the light stays in its own tones (%d)" % stray)
	var climbing := 0
	for i in range(1, heads.size()):
		if heads[i] < heads[i - 1]:
			climbing += 1
	check(climbing >= 6, "the pulse's head climbs the shard (%s)" % str(heads))
	check(frames.size() >= 8, "the beads move every step (%d of 10 frames differ)" % frames.size())
	check(LightVein.thread_cells(0).size() >= LightVein.THREAD - 2, "the vein climbs its full height")


## Cut, the main shard snaps off, the crystal goes dead and the vein hangs slack.
func test_light_vein_cut_goes_dead() -> void:
	var lit := LightVein.build_image(false)
	var dead := LightVein.build_image(true)
	var sky := 0
	var lit_top := 999
	var dead_top := 999
	for y in dead.get_height():
		for x in dead.get_width():
			if _sky_index(dead.get_pixel(x, y)) >= 0:
				sky += 1
			if dead.get_pixel(x, y).a > 0.0:
				dead_top = mini(dead_top, y)
			if lit.get_pixel(x, y).a > 0.0:
				lit_top = mini(lit_top, y)
	check(sky == 0, "no light is left in the cut crystal (%d px)" % sky)
	check(dead_top - lit_top >= 6, "the main shard is snapped off (tops %d and %d)" % [lit_top, dead_top])
	var stump := 0
	for c: Vector2i in LightVein.body_cells(true):
		if c.y < LightVein.SNAP - 1:
			stump += 1
	check(stump == 0, "nothing of the shard stands above the break (%d)" % stump)
	check(LightVein.slack_cells().size() < LightVein.thread_cells(0).size() / 2, "the vein hangs short and slack")


## The light is stepped like hand-drawn frames: a vein redraws only when its
## step changes, not every frame.
func test_light_vein_redraws_on_its_steps() -> void:
	var v := LightVein.new()
	arena.add_child(v)
	await frames(2)
	var steps := {}
	for i in 30:
		steps[v._step] = true
		await frames(1)
	check(steps.size() >= 3 and steps.size() <= 12, "the step advances at about %d fps (%d steps in 30 frames)" % [int(LightVein.STEP_FPS), steps.size()])
	v.queue_free()
