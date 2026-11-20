extends TestSuite
## Pass 564 (bible 12.52): a foe made of stillglass carries its own light. The
## Crystal Dwarf's crystal throws a stepped, dithered glow onto the dark behind
## him, so his dark body stands against it; it swells with his tell and goes
## out when he dies.


func _dwarf() -> CrystalDwarf:
	var w := make_world({}, "vorrhallow/flooded_hall", cell_feet(4, 15))
	await frames(4)
	for c in w.room.get_children():
		if c is CrystalDwarf:
			return c
	return null


func test_the_glow_falls_off_in_dithered_steps() -> void:
	var half := Vector2(40, 34)
	check(FoeGlow.level_at(0, 0, half) == FoeGlow.LEVELS, "brightest at its centre")
	check(FoeGlow.level_at(40, 0, half) == 0 and FoeGlow.level_at(0, -35, half) == 0, "nothing past its reach")
	check(FoeGlow.level_at(-30, -30, half) == 0, "nor in its corners: it is round, not a box")
	# Along a row the mean level only falls with distance (block by block of the dither).
	var falling := true
	var prev := 1e9
	for bx in range(0, 40, 8):
		var sum := 0.0
		for x in range(bx, bx + 8):
			for y in range(0, 8):
				sum += FoeGlow.level_at(x, y, half)
		falling = falling and sum <= prev
		prev = sum
	check(falling, "it only dims outward")
	# Steps, not a gradient: the texture holds LEVELS tones and nothing between.
	var tones := {}
	var img := FoeGlow.texture_for(half).get_image()
	for y in img.get_height():
		for x in img.get_width():
			tones[roundi(img.get_pixel(x, y).a * 255.0)] = true
	check(tones.size() == FoeGlow.LEVELS + 1, "%d tones and clear (%d)" % [FoeGlow.LEVELS, tones.size()])
	# The dither is in GRAIN blocks: a pixel and its block neighbour share a tone.
	var blocky := true
	for y in range(-34, 34, FoeGlow.GRAIN):
		for x in range(-40, 40, FoeGlow.GRAIN):
			blocky = blocky and FoeGlow.level_at(x, y, half) == FoeGlow.level_at(x + 1, y, half)
	check(blocky, "stepped in %d px blocks across" % FoeGlow.GRAIN)
	# Between two steps the tones mix (a dither), they do not ring.
	var mixed := false
	for x in range(0, 38, FoeGlow.GRAIN):
		var a := FoeGlow.level_at(x, 0, half)
		var b := FoeGlow.level_at(x, FoeGlow.GRAIN, half)
		var c := FoeGlow.level_at(x + 2 * FoeGlow.GRAIN, 0, half)
		mixed = mixed or (a != b and a == c)
	check(mixed, "neighbouring steps mix through the dither")


func test_the_glow_breathes_swells_and_goes_out() -> void:
	var lo := 1.0
	var hi := 0.0
	for i in 80:
		var a := FoeGlow.peak_at(1.0, i * 0.1)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	check(hi <= FoeGlow.PEAK + 0.001 and lo >= FoeGlow.PEAK * (1.0 - FoeGlow.BREATH) - 0.001, "at rest it breathes just under its peak (%.2f to %.2f)" % [lo, hi])
	check(hi - lo > 0.02, "and the breath shows")
	check(FoeGlow.peak_at(2.0, 0.0) == FoeGlow.PEAK_TELL and FoeGlow.PEAK_TELL > FoeGlow.PEAK, "a tell is brighter than rest")
	check(FoeGlow.peak_at(1.5, 0.0) > hi and FoeGlow.peak_at(1.5, 0.0) < FoeGlow.PEAK_TELL, "and swells toward it")
	check(FoeGlow.peak_at(0.0, 0.0) == 0.0, "dark, it adds nothing")
	# The light it adds behind the foe outweighs the foe's line and deep shadows in
	# the hall's light. Since pass 612 (bible 12.89) his steel is lit by the fill,
	# so the glow no longer has to outweigh the steel: his line is what stands
	# against it, and the steel stands above the hall's dark on its own.
	var line := FoeLight.lit(Color("12161c"), "vorrhallow")
	var steel := FoeLight.lit(Color("3a4450"), "vorrhallow")
	var added := FoeLight.luma(CrystalDwarf.CRYSTAL_LIGHT) * lo
	check(added >= FoeLight.luma(line) + 0.08, "the dark behind him is lit past his line (%.2f over %.2f)" % [added, FoeLight.luma(line)])
	check(FoeLight.luma(steel) > FoeLight.luma(Backdrop.ZONE_HAZE["vorrhallow"]) + 0.08, "and his steel stands above the hall's dark (%.2f)" % FoeLight.luma(steel))


func test_the_crystal_dwarf_carries_his_crystals_light() -> void:
	var foe := await _dwarf()
	check(foe != null, "a Crystal Dwarf stands in the Flooded Hall")
	if foe == null:
		return
	var glow := foe.glow
	check(glow != null and glow.get_parent() == foe, "he carries a glow")
	check(glow.show_behind_parent, "drawn behind him: nothing is painted over the figure")
	var mat := glow.material as CanvasItemMaterial
	check(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "it only adds light")
	check(glow.color == CrystalDwarf.CRYSTAL_LIGHT, "in the stillglass's own colour")
	check(glow.reach.x >= foe.body_size.x * 1.5 and glow.reach.y >= foe.body_size.y, "wider than his body, so it shows around him")
	check(glow.shown_peak() > 0.3, "lit at rest (%.2f)" % glow.shown_peak())
	# It sits on the crystal: on his back, whichever way he faces.
	foe.facing = 1
	await frames(2)
	var right := glow.position
	foe.facing = -1
	await frames(2)
	check(right.x < 0.0 and glow.position.x > 0.0 and right.y == glow.position.y, "it follows the crystal on his back")
	check(glow.position.y < 0.0 and glow.position.y > -foe.body_size.y, "at the height of his back")
	# The tell swells it.
	var rest := glow.shown_peak()
	foe.set_state("windup")
	check(foe.glow_strength() >= 1.0, "the windup starts from rest")
	foe.state_time = CrystalDwarf.WINDUP * 0.9
	check(foe.glow_strength() > 1.8, "and swells to the strike")
	foe.set_state("walk")
	check(foe.glow_strength() == 1.0, "walking, it rests")
	# Dead, it goes out.
	foe.take_hit(9999, Vector2(0, 1))
	check(foe.dead and foe.glow_strength() == 0.0, "dead, the crystal is dark")
	await frames(30)
	check(not is_instance_valid(foe) or foe.glow.shown_peak() == 0.0, "and the glow is gone (was %.2f)" % rest)
