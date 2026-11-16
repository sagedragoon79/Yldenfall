extends TestSuite
## HornetNest (pass 576, bible 12.63): the Hornet Gallery's sign said "The
## hornets nest where the sap runs thickest", and the gallery showed three
## hornets, no nest and no sap, over a floor as level as every other room's.
## The great nest hangs between the two hanging trunks with sap running down
## it, and the floor climbs out of the thorns by two ramps.

const GALLERY := "res://levels/heartwood/hornet_gallery.room"


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


## The opaque pixels of the baked image, by world cell from the prop's origin.
func _pixels() -> Dictionary:
	var img := HornetNest.build_image()
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				out[Vector2i(x, y) + HornetNest.IMG.position] = c
	return out


func _nest(room: Node) -> HornetNest:
	for n: Node in room.get_children():
		if n is HornetNest:
			return n
	return null


func _grid() -> PackedStringArray:
	return FileAccess.get_file_as_string(GALLERY).replace("\r", "").split("---\n")[1].strip_edges().split("\n")


func _is_sap(c: Color) -> bool:
	return c in HornetNest.SAP


func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


## Whether (x, y) is on or beside a rope of sap.
func _on_rope(p: Vector2i) -> bool:
	for rope: Vector2i in HornetNest.sap_ropes():
		if p.y <= rope.y + 1 and p.x >= HornetNest.rope_x(rope, mini(p.y, rope.y)) - 1 and p.x <= HornetNest.rope_x(rope, mini(p.y, rope.y)) + 2:
			return true
	return false


func test_hornet_nest_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	for tone: Color in HornetNest.TONES:
		check(palette.has(tone.to_html(false)), "tone %s is a master palette value" % tone.to_html(false))
	var px := _pixels()
	var used := {}
	var stray := 0
	for p: Vector2i in px:
		var c: Color = px[p]
		if c.a < 1.0 or not c in HornetNest.TONES:
			stray += 1
		used[c] = true
	check(stray == 0, "every pixel is a whole, opaque tone of the piece (%d astray)" % stray)
	for tone: Color in HornetNest.TONES:
		check(used.has(tone), "tone %s is used" % tone.to_html(false))
	check(px.size() > 9000, "a landmark, not a speck (%d px)" % px.size())


func test_the_great_nest_hangs_from_the_ceiling_as_a_banded_teardrop() -> void:
	var px := _pixels()
	check(px.has(Vector2i(0, 0)) and px.has(Vector2i(0, HornetNest.TOP)), "its stalk comes out of the ceiling")
	var widest := 0
	var widest_y := 0
	var teardrop := true
	for y in range(HornetNest.TOP, HornetNest.BOTTOM):
		var hw := HornetNest.half_at(y)
		if hw > widest:
			widest = hw
			widest_y = y
	for y in range(HornetNest.TOP + 1, HornetNest.BOTTOM):
		var grows := HornetNest.half_at(y) >= HornetNest.half_at(y - 1)
		if (y <= widest_y) != grows and HornetNest.half_at(y) != HornetNest.half_at(y - 1):
			teardrop = false
	check(teardrop, "it swells to its widest and narrows from there")
	var f := float(widest_y - HornetNest.TOP) / float(HornetNest.BOTTOM - HornetNest.TOP)
	check(f > 0.3 and f < 0.55, "widest above its middle (%.2f of the way down)" % f)
	check(widest * 2 >= 96, "six tiles across at its widest (%d px)" % (widest * 2))
	check(HornetNest.BOTTOM - HornetNest.TOP >= 136, "eight and a half tiles long")
	var foot := HornetNest.half_at(HornetNest.BOTTOM - 1)
	check(foot * 3 < widest * 2 and foot >= 10, "blunt at its foot, not a point (%d px)" % (foot * 2))
	# Outlined down both sides, lit on the west and in shade on the east.
	var open := 0
	var west := 0.0
	var east := 0.0
	var n := 0
	for y in range(HornetNest.TOP + 8, HornetNest.BOTTOM - 1):
		var hw := HornetNest.half_at(y)
		for edge: int in [-hw - 1, hw]:
			# A rope of sap may cross the outline on its way over the shoulder.
			var c: Color = px.get(Vector2i(edge, y), Color.WHITE)
			if c != HornetNest.OUTLINE and not _is_sap(c):
				open += 1
		for k in range(2, 8):
			west += _lum(px[Vector2i(-hw + k, y)])
			east += _lum(px[Vector2i(hw - 1 - k, y)])
			n += 1
	check(open == 0, "outlined down both sides (%d gaps)" % open)
	check(west / n > east / n * 1.25, "lit from the upper left (%.3f west, %.3f east)" % [west / n, east / n])
	# Banded: layers of grey paper and chewed bark, each sagging in the middle.
	var seams := 0
	var paper := 0
	var bark := 0
	var x := -24
	for y in range(HornetNest.TOP + 20, HornetNest.BOTTOM - 20):
		if HornetNest.band_of(x, y) != HornetNest.band_of(x, y - 1):
			seams += 1
			check(px[Vector2i(x, y)] == HornetNest.OUTLINE or _is_sap(px[Vector2i(x, y)]), "a seam is drawn at row %d" % y)
		elif px[Vector2i(x, y)] in HornetNest.PAPER:
			paper += 1
		elif px[Vector2i(x, y)] in HornetNest.BAND:
			bark += 1
	check(seams >= 8, "at least eight layers down its face (%d seams)" % seams)
	check(paper > 25 and bark > 25, "grey paper and chewed bark by turns (%d, %d)" % [paper, bark])
	var sags := 0
	for y in range(40, 120, 10):
		var hw := HornetNest.half_at(y)
		if HornetNest.band_of(0, y) < HornetNest.band_of(-hw + 2, y) and HornetNest.band_of(0, y) < HornetNest.band_of(hw - 2, y):
			sags += 1
	check(sags == 8, "every layer sags in the middle (%d of 8 rows)" % sags)


func test_the_nest_has_a_mouth_and_a_tear_where_the_comb_shows() -> void:
	var px := _pixels()
	var bad := 0
	var cells := 0
	for y in range(HornetNest.MOUTH.y - 8, HornetNest.MOUTH.y + 9):
		for x in range(HornetNest.MOUTH.x - 10, HornetNest.MOUTH.x + 11):
			if HornetNest.in_mouth(x, y):
				cells += 1
				var c: Color = px[Vector2i(x, y)]
				if c != HornetNest.OUTLINE and c != HornetNest.MOUTH_DARK:
					bad += 1
	check(cells > 100 and bad == 0, "the mouth is dark all through (%d cells, %d not)" % [cells, bad])
	var low := float(HornetNest.MOUTH.y - HornetNest.TOP) / float(HornetNest.BOTTOM - HornetNest.TOP)
	check(low > 0.7, "low on the nest's face (%.2f of the way down)" % low)
	check(absi(HornetNest.MOUTH.x) + HornetNest.MOUTH_R.x + 4 < HornetNest.half_at(HornetNest.MOUTH.y), "inside its outline")
	check(HornetNest.MOUTH.x < 0 and HornetNest.TEAR.x > 0, "the mouth west of the middle, the tear east")
	var hollow := 0
	var wax := 0
	var capped := 0
	var outside := 0
	var dark_outside := 0
	for p: Vector2i in px:
		var c: Color = px[p]
		if c in HornetNest.COMB:
			if not HornetNest.in_tear(p.x, p.y):
				outside += 1
			if c == HornetNest.COMB[0]:
				hollow += 1
			elif c == HornetNest.COMB[1]:
				wax += 1
			else:
				capped += 1
		if c == HornetNest.MOUTH_DARK and not HornetNest.in_mouth(p.x, p.y):
			dark_outside += 1
	check(outside == 0, "comb shows only in the tear (%d px outside)" % outside)
	check(dark_outside == 0, "the mouth's dark is only in the mouth (%d px outside)" % dark_outside)
	check(hollow > 120 and wax > hollow and capped > 15, "open cells in wax, some capped (%d hollow, %d wax, %d capped)" % [hollow, wax, capped])
	check(HornetNest.TEAR.x + HornetNest.TEAR_R.x < HornetNest.half_at(HornetNest.TEAR.y), "the tear is in its face, not off its edge")
	# The hornets at the mouth stay on the nest, and they are specks.
	var off := 0
	for k in HornetNest.CRAWLERS:
		for i in 200:
			var c := HornetNest.crawler_at(k, i * 0.37)
			if absi(c.x) + 3 >= HornetNest.half_at(c.y) or HornetNest.in_mouth(c.x, c.y):
				off += 1
	check(off == 0, "the crawlers circle the mouth's rim, on the paper (%d off it)" % off)
	check(HornetNest.crawler_at(0, 0.0) != HornetNest.crawler_at(0, 1.0), "and they move")


func test_two_young_nests_hang_beside_the_great_one() -> void:
	var px := _pixels()
	check(HornetNest.YOUNG.size() == 2 and HornetNest.YOUNG[0].x < 0 and HornetNest.YOUNG[1].x > 0, "one each side")
	for which in HornetNest.YOUNG.size():
		var n := HornetNest.YOUNG[which]
		var side := "west" if n.x < 0 else "east"
		check(px.has(Vector2i(n.x, 0)), "the %s one hangs from the ceiling" % side)
		check(n.y * 3 < HornetNest.HALF and n.z * 3 < HornetNest.BOTTOM, "the %s one is under a third of the great nest's size" % side)
		var widest := 0
		for y in range(4, n.z):
			widest = maxi(widest, HornetNest.young_half(which, y))
		check(widest == n.y, "the %s one swells to its width (%d of %d)" % [side, widest, n.y])
		# Open air between it and the great nest, all the way down.
		var gap := signi(n.x) * (absi(n.x) - n.y - 3)
		var filled := 0
		for y in range(4, n.z + 2):
			if px.has(Vector2i(gap, y)) and not _on_rope(Vector2i(gap, y)):
				filled += 1
		check(filled == 0, "the %s one hangs clear of the great nest (%d px between)" % [side, filled])
		check(px.get(Vector2i(n.x, n.z - 3), Color.WHITE) == HornetNest.OUTLINE, "the %s one has its own mouth" % side)
		check(absi(n.x) + n.y < HornetNest.IMG.size.x / 2, "the %s one is whole in the picture" % side)


func test_sap_runs_thickest_over_the_nests() -> void:
	var px := _pixels()
	var stray := 0
	var seep := 0
	for p: Vector2i in px:
		if not _is_sap(px[p]):
			continue
		if p.y < 4 and not _on_rope(p):
			seep += 1
		elif not _on_rope(p):
			stray += 1
	check(stray == 0, "gold is only sap: the seep under the ceiling and the ropes (%d px astray)" % stray)
	check(seep > 60, "sap seeps out of the ceiling along the nests' roots (%d px)" % seep)
	var ropes := HornetNest.sap_ropes()
	check(ropes.size() >= 4, "at least four ropes of sap")
	var ends := {}
	for rope: Vector2i in ropes:
		var broken := 0
		var glints := 0
		for y in range(0, rope.y):
			var c: Color = px.get(Vector2i(HornetNest.rope_x(rope, y), y), Color.WHITE)
			if not _is_sap(c):
				broken += 1
			if c == HornetNest.SAP[2]:
				glints += 1
		check(broken == 0, "the rope at %d runs unbroken from the ceiling (%d gaps)" % [rope.x, broken])
		check(glints >= 6, "and glints on its lit side (%d)" % glints)
		check(absi(HornetNest.rope_x(rope, 0)) < absi(HornetNest.rope_x(rope, 60)) or absi(rope.x) < 6, "it spreads over the nest's shoulder (%d)" % rope.x)
		ends[rope.y] = true
	check(ends.size() == ropes.size(), "each rope ends at its own height")
	# The last rope hangs under the nest as a strand, and drips.
	var last: Vector2i = ropes.back()
	check(last.y == HornetNest.BOTTOM + HornetNest.STRAND, "one rope hangs under the nest")
	var air := 0
	for y in range(HornetNest.BOTTOM + 2, last.y - 3):
		for dx: int in [-3, 4]:
			if px.has(Vector2i(HornetNest.drip_x() + dx, y)):
				air += 1
	check(air == 0, "in open air (%d px beside it)" % air)
	check(HornetNest.drip_top() > last.y, "the drop forms under the strand's foot")
	check_near(HornetNest.drip_y(0.0), HornetNest.drip_top(), 0.01, "it hangs there first")
	var rises := 0
	var prev := HornetNest.drip_y(0.0)
	for i in range(1, 100):
		var y := HornetNest.drip_y(HornetNest.DRIP_PERIOD * i / 100.0)
		if y < prev:
			rises += 1
		prev = y
	check(rises == 0, "and only falls (%d rises)" % rises)
	check_near(prev, HornetNest.DRIP_LAND, 8.0, "down to the thorns")
	check(HornetNest.DRIP_LAND - HornetNest.drip_top() > 100, "a long fall (%d px)" % (HornetNest.DRIP_LAND - HornetNest.drip_top()))


## In the room: the nests hang from solid ceiling in open air between the two
## hanging trunks, no ledge crosses them, the drop falls into the thorns clear
## of the planks, and a hornet hovers in front of the great nest.
func test_the_hornet_gallery_has_its_nests() -> void:
	var w := make_world({}, "heartwood/hornet_gallery")
	await frames(2)
	var nest := _nest(w.room)
	check(nest != null, "the Hornet Gallery has its nests")
	if nest == null:
		return
	var room: Room = w.room
	var at := nest.position
	for x: int in [0, HornetNest.YOUNG[0].x, HornetNest.YOUNG[1].x]:
		check(room.is_solid_at(at + Vector2(x, -4)), "the nest at %d hangs from solid ceiling" % x)
		check(not room.is_solid_at(at + Vector2(x, 4)), "in open air")
	var covered := 0
	for y in range(4, HornetNest.IMG.size.y, 8):
		for x in range(HornetNest.IMG.position.x + 2, HornetNest.IMG.end.x, 8):
			var p := at + Vector2(x, y)
			if room.is_solid_at(p) or room.is_one_way_at(p):
				covered += 1
	check(covered == 0, "no wall or ledge stands across them (%d points)" % covered)
	# The drop: through open air, clear of the planks, into the thorns.
	var grid := _grid()
	var blocked := 0
	for y in range(HornetNest.drip_top(), HornetNest.DRIP_LAND, 4):
		for dx: int in [-3, 0, 4]:
			var p := at + Vector2(HornetNest.drip_x() + dx, y)
			if room.is_solid_at(p) or room.is_one_way_at(p):
				blocked += 1
	check(blocked == 0, "the drop falls through open air, clear of the planks (%d points)" % blocked)
	var land := room.cell_at(at + Vector2(HornetNest.drip_x(), HornetNest.DRIP_LAND + 4))
	check(grid[land.y][land.x] == "^", "and lands in the thorns (%s is '%s')" % [land, grid[land.y][land.x]])
	var tips := (land.y * Room.TILE) - at.y
	check(HornetNest.DRIP_LAND >= tips and HornetNest.DRIP_LAND < tips + Room.TILE, "among their tips, not under the floor (%d of %d)" % [HornetNest.DRIP_LAND, int(tips)])
	# A hornet hovers in front of the great nest.
	var hovering := 0
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] == "H":
				var c := cell_center(x, y) - at
				if absf(c.x) < HornetNest.HALF and c.y > HornetNest.TOP and c.y < HornetNest.BOTTOM:
					hovering += 1
	check(hovering >= 1, "a hornet hovers in front of the great nest")
	var text := FileAccess.get_file_as_string(GALLERY)
	check(text.contains("The hornets nest where the sap runs thickest."), "the sign tells of the nests and the sap")
	check(text.contains("Mind the thorns below."), "and of the thorns the sap drips into")
	check(nest.z_index < 0, "behind the hornets and the hero")
	check(nest.get_child_count() == 0, "scenery only: nothing to stand on, to touch or to be hurt by")
	await frames(30)
	check(nest.t > 0.2, "its sap drips and its hornets crawl")


## The independent grade after pass 575: "most rooms are a rectangular tile
## frame around a dead-level floor". The gallery's floor now stands at three
## heights joined by two ramps, and its ceiling steps down to the hanging
## trunks instead of meeting them square.
func test_the_hornet_gallery_is_not_a_level_box() -> void:
	var grid := _grid()
	var floors := {}
	var ceilings := {}
	var ramps: Array[Vector2i] = []
	for x in range(1, grid[0].length() - 1):
		var y := grid.size() - 1
		while y > 0 and grid[y][x] in "#/":
			y -= 1
		floors[y] = true
		var top := 0
		while top < grid.size() and grid[top][x] == "#":
			top += 1
		ceilings[top] = true
		for row in grid.size():
			if grid[row][x] == "/":
				ramps.append(Vector2i(x, row))
	check(floors.size() >= 3, "the floor stands at three heights (%s)" % [floors.keys()])
	check(ceilings.size() >= 6, "the ceiling's underside steps at six heights or more (%s)" % [ceilings.keys()])
	check(ramps.size() == 2, "two ramps (%s)" % [ramps])
	for r: Vector2i in ramps:
		check(grid[r.y + 1][r.x] == "#" and grid[r.y][r.x + 1] == "#", "the ramp at %s has ground under it and on its high side" % r)
		check(grid[r.y][r.x - 1] in ".T" and grid[r.y + 1][r.x - 1] == "#", "and starts on open floor")
	# Walked for real: from the thorns' east side up both ramps to the east door's
	# shelf, with no jump.
	var w := make_world({}, "heartwood/hornet_gallery")
	await frames(3)
	for e: Node in runner.get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await frames(2)
	var p := w.player
	p.global_position = cell_feet(21, 21)
	p.velocity = Vector2.ZERO
	await frames(10)
	var from_y := p.global_position.y
	p.input.move_x = 1
	var steps := 0
	while p.global_position.x < 35 * Room.TILE and steps < 400:
		await frames(1)
		steps += 1
	p.input.move_x = 0
	await frames(10)
	check(p.global_position.x >= 35 * Room.TILE, "a walk east from the thorns reaches the door's shelf (x %.0f after %d frames)" % [p.global_position.x, steps])
	check_near(from_y - p.global_position.y, 2.0 * Room.TILE, 2.0, "two tiles higher than it began, by the ramps alone")
	check(p.is_on_floor(), "standing")
	w.queue_free()
	await frames(2)
