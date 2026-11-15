extends TestSuite
## SpringWall (pass 571, bible 12.58): the Fountain Plaza's sign told that the
## fountain is "fed by the three springs of the Ylden", and the first room of
## the game showed a small fountain in an empty dark hall. The Three Mouths
## stand behind it: a carved headwall whose mouths run as the springs return.


func _palette() -> Dictionary:
	var palette := {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/master.json"))
	for c: String in data.colors:
		palette[c.trim_prefix("#").to_lower()] = true
	return palette


func _wall(room: Node) -> SpringWall:
	for n: Node in room.get_children():
		if n is SpringWall:
			return n
	return null


func _fountain(room: Node) -> Fountain:
	for n: Node in room.get_children():
		if n is Fountain:
			return n
	return null


func _value(c: Vector2i) -> float:
	return SpringWall.tone_at(c).v


## Every tone is a master palette value, and the baked image holds nothing else.
func test_spring_wall_is_pixel_art_on_the_master_palette() -> void:
	var palette := _palette()
	var tones := {}
	for tone: Color in SpringWall.TONES:
		check(palette.has(tone.to_html(false)), "#%s is a master palette tone" % tone.to_html(false))
		tones[tone.to_html(false)] = true
	for tone: Color in SpringWall.WATER + [SpringWall.LEAF_LIT]:
		check(palette.has(tone.to_html(false)), "#%s (drawn live) is a master palette tone" % tone.to_html(false))
	var img := SpringWall.build_image()
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
	check(stray == 0, "the baked wall holds only its tones, each whole (%d stray)" % stray)
	check(opaque > 20000, "and it is a wall, not a sketch (%d pixels)" % opaque)
	check(used.size() >= 18, "it uses its stone, its warm stone, its bronze and its lanterns (%d tones)" % used.size())


## Three niches of one size in a wall that is the same on both sides, each
## with its mouth, its bronze lip and its own sign.
func test_spring_wall_has_three_mouths() -> void:
	var odd := 0
	var cells := [0, 0, 0]
	for y in range(SpringWall.IMG.position.y, 0):
		for x in range(SpringWall.IMG.position.x, SpringWall.IMG.end.x):
			var c := Vector2i(x, y)
			if SpringWall.in_wall(c) != SpringWall.in_wall(Vector2i(-1 - x, y)):
				odd += 1
			var i := SpringWall.niche_at(c)
			if i >= 0:
				cells[i] += 1
				if not SpringWall.in_wall(c):
					odd += 1
	check(odd == 0, "the wall is the same on both sides, and its niches lie inside it (%d cells off)" % odd)
	check(cells[0] > 2500 and cells[0] == cells[1] and cells[1] == cells[2], "three niches of one size (%s)" % [cells])
	check(SpringWall.NICHE_X.size() == Fountain.SPRINGS.size(), "one mouth for each spring that feeds the fountain")
	var signs := {}
	for i in SpringWall.NICHE_X.size():
		var cx: int = SpringWall.NICHE_X[i]
		check([SpringWall.HOLLOW, SpringWall.HOLLOW_LIT, SpringWall.HOLLOW_WARM].has(SpringWall.tone_at(Vector2i(cx + 10, -60))), "niche %d is a dark hollow" % i)
		var pier := SpringWall.tone_at(Vector2i(cx - 31, -60))
		check(SpringWall.STONE.has(pier) or SpringWall.WARM.has(pier), "with a pier of stone to its left")
		check(SpringWall.BRONZE.has(SpringWall.tone_at(Vector2i(cx, SpringWall.LIP_Y - 2))), "mouth %d has its bronze lip" % i)
		check(SpringWall.tone_at(Vector2i(cx, -90)) == SpringWall.OUTLINE, "over it the mouth is an open slot")
		check(SpringWall.SCALE_DARK == SpringWall.tone_at(Vector2i(cx, -70)) or SpringWall.SCALE == SpringWall.tone_at(Vector2i(cx, -70)), "and under it the stone is limed where the water ran")
		var cut := ""
		var cuts := 0
		for gy in 5:
			for gx in 5:
				var on := SpringWall.glyph_at(i, Vector2i(cx, 0) + SpringWall.GLYPH_AT + Vector2i(gx, gy))
				cut += "#" if on else "."
				cuts += 1 if on else 0
		check(cuts >= 6, "mouth %d has a sign cut in its keystone (%d pixels)" % [i, cuts])
		signs[cut] = true
	check(signs.size() == 3, "each spring has its own sign")
	check(-SpringWall.IMG.position.y >= 2 * 65, "the wall stands taller than two fountains (%d px)" % -SpringWall.IMG.position.y)
	check(SpringWall.TROUGH_HALF > 38, "and its trough runs wider than the fountain's basin")


## Lit from the upper left, and warm round its two lanterns.
func test_spring_wall_is_lit() -> void:
	var cornice_top := 0.0
	var under := 0.0
	for x in range(-90, 90):
		cornice_top += _value(Vector2i(x, -139))
		under += _value(Vector2i(x, -131))
	check(cornice_top > under * 1.8, "the cornice's top is lit and the wall under it is in its shadow (%.1f over %.1f)" % [cornice_top, under])
	for i in SpringWall.NICHE_X.size():
		var cx: int = SpringWall.NICHE_X[i]
		var half := int(SpringWall.NICHE_HALF)
		check(_value(Vector2i(cx + half - 1, -50)) > _value(Vector2i(cx - half, -50)) + 0.1, "niche %d: the jamb that faces the light is lit, the other in shadow" % i)
		check(SpringWall.tone_at(Vector2i(cx - half + 3, -50)) == SpringWall.HOLLOW, "and the left pier throws its shadow on the niche's back")
	var warm := 0
	var cool_near := 0
	var warm_far := 0
	for y in range(-125, -26):
		for x in range(-100, 100):
			var c := Vector2i(x, y)
			var tone := SpringWall.tone_at(c)
			var is_warm := SpringWall.WARM.has(tone)
			var is_cool := SpringWall.STONE.has(tone)
			if SpringWall.lamp_light(c) > SpringWall.WARM_OVER + 0.1:
				warm += 1 if is_warm else 0
				cool_near += 1 if is_cool and SpringWall.niche_at(c) < 0 else 0
			elif SpringWall.lamp_light(c) < SpringWall.WARM_OVER - 0.1 and is_warm:
				warm_far += 1
	check(warm > 300, "the stone round the lanterns is warm (%d pixels)" % warm)
	check(cool_near == 0, "none of it is left cool (%d)" % cool_near)
	check(warm_far == 0, "and the light does not reach the middle of the wall (%d)" % warm_far)
	check(SpringWall.LAMPS.size() == 2 and SpringWall.LAMPS[0].x == -SpringWall.LAMPS[1].x, "two lanterns, one on each outer pier")
	for lamp: Vector2 in SpringWall.LAMPS:
		check(SpringWall.tone_at(Vector2i(floori(lamp.x), floori(lamp.y))) == SpringWall.FLAME, "a lantern burns at %s" % lamp)
		check(SpringWall.niche_at(Vector2i(floori(lamp.x), floori(lamp.y))) < 0, "on a pier, not in a niche")


## A mouth runs when its spring is restored, and only then.
func test_spring_wall_runs_as_the_springs_return() -> void:
	var w := make_world({}, "hearthroot/plaza")
	await frames(2)
	var running := 0
	for i in 3:
		running += 1 if SpringWall.flows(i) else 0
	check(running == 0 and Fountain.level() == 0, "a new game: every mouth is dry, like the fountain")
	GameState.set_flag("spring:haar")
	check(not SpringWall.flows(0) and SpringWall.flows(1) and not SpringWall.flows(2), "the Haar Spring runs from the middle mouth alone")
	GameState.set_flag("spring:heartwood")
	check(SpringWall.flows(0) and SpringWall.flows(1) and not SpringWall.flows(2), "the Heartwood Spring from the left")
	GameState.set_flag("spring:sky")
	running = 0
	for i in 3:
		running += 1 if SpringWall.flows(i) else 0
	check(running == 3 and Fountain.level() == 3, "and all three with the fountain full")
	check(SpringWall.fall() > 50.0, "the water falls from the lip to the trough, taller than the hero (%.0f px)" % SpringWall.fall())
	check(SpringWall.LIP_Y + SpringWall.fall() == SpringWall.TROUGH_TOP, "and lands in the trough")
	var moved := 0
	for k in SpringWall.GLINTS:
		var a := SpringWall.glint_drop(k, 1.0)
		var b := SpringWall.glint_drop(k, 1.1)
		check(a >= 0.0 and a < SpringWall.fall() and b >= 0.0 and b < SpringWall.fall(), "glint %d stays in the thread" % k)
		if b > a:
			moved += 1
	check(moved >= SpringWall.GLINTS - 1, "the glints slide down it (%d of %d fell in a tenth of a second)" % [moved, SpringWall.GLINTS])
	check(SpringWall.glint_drop(0, 1.0) != SpringWall.glint_drop(1, 1.0), "no two together")
	var wall := _wall(w.room)
	check(wall != null, "the plaza has the wall")
	if wall != null:
		await frames(20)
		check(wall.t > 0.2, "and its water and flames move")


## In the plaza it stands behind the fountain, on the floor, clear of the
## room's stone and of everything the hero can stand on.
func test_the_fountain_plaza_has_its_spring_wall() -> void:
	var w := make_world({}, "hearthroot/plaza")
	await frames(2)
	var room: Room = w.room
	var wall := _wall(room)
	var fountain := _fountain(room)
	check(wall != null and fountain != null, "the plaza has its wall and its fountain")
	if wall == null or fountain == null:
		return
	check(wall.position == fountain.position, "the wall stands behind the fountain, on one center line")
	check(wall.z_index < fountain.z_index and fountain.z_index < 0, "behind the fountain, and both behind everyone who walks past")
	check(wall.get_child_count() == 0, "scenery only: nothing to touch or to be hurt by")
	check(room.is_solid_at(wall.position + Vector2(-100, 4)) and room.is_solid_at(wall.position + Vector2(100, 4)), "it stands on solid floor from end to end")
	var in_stone := 0
	for y in range(SpringWall.IMG.position.y, -Room.TILE, 8):
		for x in range(SpringWall.IMG.position.x, SpringWall.IMG.end.x, 8):
			if room.is_solid_at(wall.position + Vector2(x, y)):
				in_stone += 1
	check(in_stone == 0, "above the low posts at its feet, no tile of the room stands in it (%d points)" % in_stone)
	check(not room.is_solid_at(wall.position + Vector2(0, SpringWall.IMG.position.y - 24)), "and there is air over its crown")
	check(FileAccess.get_file_as_string("res://levels/hearthroot/plaza.room").contains("Fed by the three springs of the Ylden."), "the sign still tells of the three springs")
	check(SpringWall._baked != null, "the wall is baked once for the whole run")
