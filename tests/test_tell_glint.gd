extends TestSuite
## A tell gathers on the weapon (pass 611, bible 12.88). The pass 610 grade read the
## Rot Dwarf's wind-up in the Heartwood as "a flat yellow full-body tint, a debug
## overlay": the gold rim ran round the whole foe and a tint lay over it. A sheet foe
## with a point in `Enemy.TELL_POINTS` now keeps its own colors through a wind-up and
## wears a four-point glint on its weapon, which grows as the blow nears, with the rim
## only near the weapon on the pulse's lit beats.

const ROWS := [
	"####################",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..........D.......#",
	"####################",
	"####################",
]


func _dwarf() -> RotDwarf:
	var room := Room.from_text("\n".join(PackedStringArray(ROWS)))
	arena.add_child(room)
	for c in room.get_children():
		if c is RotDwarf:
			return c
	return null


## Every point names a wind-up of a real sheet and sits on the foe, on every frame.
func test_every_point_sits_on_its_foes_wind_up() -> void:
	check(Enemy.TELL_POINTS.size() >= 20, "most sheet foes have a point (%d)" % Enemy.TELL_POINTS.size())
	for sheet: String in Enemy.TELL_POINTS:
		check(Sheet.exists(sheet), "%s is a sheet" % sheet)
		if not Sheet.exists(sheet):
			continue
		var s := Sheet.get_sheet(sheet)
		var mask: Image = (s.mask as Texture2D).get_image()
		if mask.is_compressed():
			mask.decompress()
		for anim: String in Enemy.TELL_POINTS[sheet]:
			check(Sheet.has_anim(sheet, anim), "%s has the wind-up '%s'" % [sheet, anim])
			if not Sheet.has_anim(sheet, anim):
				continue
			check(Enemy.has_tell_point(sheet, anim), "%s/%s is found" % [sheet, anim])
			var frames_seen := {}
			for f: Variant in s.animations[anim].seq:
				frames_seen[int(f)] = true
			for f: int in frames_seen:
				var p := Enemy.tell_point(sheet, anim, f)
				var cell: Vector2 = s.cell
				check(Rect2(Vector2.ZERO, cell).has_point(p), "%s/%s/%d: the point is in the cell (%s)" % [sheet, anim, f, p])
				var at := Sheet.region(sheet, anim, f).position + p
				var near := false
				for dy in range(-6, 7):
					for dx in range(-6, 7):
						var q := Vector2i(at) + Vector2i(dx, dy)
						if q.x >= 0 and q.y >= 0 and q.x < mask.get_width() and q.y < mask.get_height() and mask.get_pixelv(q).a > 0.5:
							near = true
				check(near, "%s/%s/%d: the point is on the foe, within 6 sheet pixels (%s)" % [sheet, anim, f, p])
	check(not Enemy.has_tell_point("rot_dwarf", "walk"), "a walk has no point")
	check(not Enemy.has_tell_point("no_such_sheet", "windup"), "nor a sheet that is not there")


## The glint grows through the wind-up and is whole before any blow can fall.
func test_the_glint_gathers_before_the_blow() -> void:
	check(is_equal_approx(Enemy.glint_arm(0.0, false), Enemy.GLINT_MIN), "it starts at GLINT_MIN")
	check(is_equal_approx(Enemy.glint_arm(Enemy.GLINT_GATHER, false), Enemy.GLINT_MAX), "and is whole after GLINT_GATHER")
	check(Enemy.GLINT_GATHER <= Enemy.MIN_TELEGRAPH, "whole within the shortest wind-up in the game")
	var last := 0.0
	for i in 12:
		var arm := Enemy.glint_arm(Enemy.GLINT_GATHER * i / 11.0, false)
		check(arm > last, "it grows at every step (%.2f after %.2f)" % [arm, last])
		last = arm
	check(Enemy.glint_arm(0.1, true) > Enemy.glint_arm(0.1, false), "it is longer on a lit beat")
	check(Enemy.GLINT_MIN >= 2.0, "seen from its first frame (%.1f px)" % Enemy.GLINT_MIN)
	check(Enemy.GLINT_MAX + Enemy.GLINT_PULSE >= 7.0 and Enemy.GLINT_MAX + Enemy.GLINT_PULSE <= 12.0,
		"whole, it is a spark on a weapon, not a second flash over the foe")
	var core := Enemy.GLINT_CORE
	check(core.v >= 0.95 and core.s < 0.25, "its core is hot, nearly white (%s)" % core)


## The rim stays near the weapon: its widest square is under half of any foe's cell.
func test_the_rim_never_closes_round_a_whole_foe() -> void:
	check(Enemy.TELL_REACH.size() >= 2, "the rim fades over more than one step")
	var top := 0.0
	for reach: float in Enemy.TELL_REACH:
		check(reach > top, "each square is wider than the last")
		top = reach
	var whole := 1.0 - pow(1.0 - Enemy.TELL_REACH_RIM, Enemy.TELL_REACH.size())
	check(whole >= 0.75, "at the weapon the layers make a nearly solid rim (%.2f)" % whole)
	check(Enemy.TELL_REACH_RIM <= 0.5, "and one layer alone, at its edge, is faint")
	for sheet: String in Enemy.TELL_POINTS:
		if not Sheet.exists(sheet):
			continue
		var s := Sheet.get_sheet(sheet)
		var cell: Vector2 = s.cell
		var side := minf(cell.x, cell.y) / float(s.density)
		var k := Enemy.tell_reach_scale(sheet)
		check(k > 0.0 and k <= 1.0, "%s: the scale is a fraction (%.2f)" % [sheet, k])
		check(top * k * 2.0 < side * 0.5, "%s: the widest square (%.1f px) is under half its cell (%.1f px)" % [sheet, top * k * 2.0, side])


## In a room: the Rot Dwarf's body keeps its colors through the wind-up, and the
## glint sits on his raised axe, above his head, growing.
func test_a_rot_dwarfs_tell_is_a_glint_on_his_axe() -> void:
	var d := _dwarf()
	await frames(2)
	check(d.glint_drawn() == 0.0 and not d.tell_drawn(), "a dwarf on patrol wears no glint and no tell")
	d.set_state("windup")
	var lit := 0
	var dark := 0
	var first := 0.0
	var last := 0.0
	for i in 20:
		await frames(1)
		if d.state != "windup":
			break
		check(d.white_strength() == 0.0, "no tint lies over his body (%.2f)" % d.white_strength())
		check(not d.hit_rim_drawn(), "and no blow's dark rim")
		check(d.glint_drawn() >= Enemy.GLINT_MIN, "the glint is there on every frame (%.2f)" % d.glint_drawn())
		if d.tell_drawn():
			lit += 1
		else:
			dark += 1
			if first == 0.0:
				first = d.glint_drawn()
			last = d.glint_drawn()
		var at := d.glint_at()
		check(at.y < -d.body_size.y, "it sits above his head, on the raised axe (%s)" % at)
		check(absf(at.x) <= d.body_size.x, "over him, not off to one side (%s)" % at)
	check(lit >= 2 and dark >= 2, "the tell still pulses (%d lit, %d between)" % [lit, dark])
	check(last > first, "and the glint has grown between beats (%.2f to %.2f)" % [first, last])

	# It follows his facing.
	d.set_state("windup")
	d.facing = 1
	await frames(1)
	var right := d.glint_at()
	d.facing = -1
	await frames(1)
	var left := d.glint_at()
	check(is_equal_approx(right.x, -left.x) and is_equal_approx(right.y, left.y), "the glint mirrors with him (%s, %s)" % [right, left])

	# A blow in the wind-up is white, with no glint over it.
	d.set_state("windup")
	d.take_hit(1, Vector2(float(d.facing), 0))
	await frames(1)
	check(d.glint_drawn() == 0.0 and not d.tell_drawn(), "struck, the glint gives way to the blow's flash")
	await frames(14)


## A wind-up is a pose (pass 633, bible 12.109): the rear is quick, whole well inside
## the shortest wind-up, and large enough to change the silhouette.
func test_a_wind_up_rears_the_foe() -> void:
	check(Enemy.rear_at(0.0) == 0.0, "upright as the wind-up starts")
	check(is_equal_approx(Enemy.rear_at(Enemy.REAR_TIME), 1.0) and is_equal_approx(Enemy.rear_at(9.0), 1.0), "whole after REAR_TIME, and it stays")
	check(Enemy.REAR_TIME <= Enemy.MIN_TELEGRAPH * 0.5, "whole in the first half of the shortest wind-up")
	check(Enemy.rear_at(Enemy.REAR_TIME * 0.3) >= 0.5, "half of it in the first frames (%.2f)" % Enemy.rear_at(Enemy.REAR_TIME * 0.3))
	var last := -1.0
	for i in 9:
		var k := Enemy.rear_at(Enemy.REAR_TIME * i / 8.0)
		check(k > last, "it only grows (%.2f after %.2f)" % [k, last])
		last = k
	check(Enemy.REAR_LEAN >= 0.1 and Enemy.REAR_LEAN <= 0.25, "a lean that moves a head 3 px or more, short of a fall (%.2f)" % Enemy.REAR_LEAN)
	check(Enemy.REAR_STRETCH >= 0.06 and Enemy.REAR_STRETCH <= 0.15, "a stretch of two pixels or more on a 30 px foe (%.2f)" % Enemy.REAR_STRETCH)

	var d := _dwarf()
	await frames(2)
	check(d.rear_drawn() == 0.0, "a dwarf on patrol stands as he is drawn")
	var rest: Transform2D = d._sheet_transform(Vector2.ZERO)
	for side: int in [1, -1]:
		d.facing = side
		d.set_state("windup")
		await frames(int(Enemy.REAR_TIME * 60.0) + 3)
		check(d.state == "windup" and d.rear_drawn() > 0.95, "reared, facing %d (%.2f)" % [side, d.rear_drawn()])
		var x: Transform2D = d._sheet_transform(Vector2.ZERO)
		var head := x * Vector2(0, -30)
		check(head.x * side <= -3.0, "his head is back from the way he faces (%.1f px)" % head.x)
		check(head.y <= -32.0, "and higher (%.1f)" % head.y)
		check(absf(x.x.x) < absf(rest.x.x), "he is narrower (%.2f)" % x.x.x)
		check(x * Vector2.ZERO == Vector2.ZERO, "his feet have not moved")
		check(d.lean_drawn() == 0.0, "it is not a blow's recoil")
	d.set_state("swing")
	await frames(1)
	check(d.rear_drawn() == 0.0, "he snaps upright as the blow goes")
	d.set_state("windup")
	await frames(6)
	d.take_hit(1, Vector2(float(d.facing), 0))
	await frames(1)
	check(d.rear_drawn() == 0.0 and d.light_drawn() == 0.0, "struck, the rear and the light give way to the blow")
	await frames(14)


## And a light (pass 633, bible 12.109): warm at the weapon, graded, gone by the far
## side of the body, gathering with the glint and never blinking.
func test_the_weapons_light_falls_on_the_body() -> void:
	var whole := Enemy.GLINT_GATHER
	check(Enemy.body_light(0.0, 0.0) == 0.0, "no light as the wind-up starts")
	var top := Enemy.body_light(0.0, whole)
	check(top >= 0.2 and top <= 0.35, "at the weapon it is plain, and under the soft flash (%.2f)" % top)
	check(Enemy.body_light(0.0, whole * 0.5) < top and Enemy.body_light(0.0, whole * 2.0) == top, "it gathers with the glint and holds")
	check(Enemy.LIGHT_REACH.size() >= 6, "it falls off over six steps or more")
	check(Enemy.LIGHT_STEP <= FoeGlow.MAX_STEP, "no step is one the eye picks out (12.108)")
	var last := top
	var wide := 0.0
	for reach: float in Enemy.LIGHT_REACH:
		check(reach > wide, "each square is wider than the last")
		wide = reach
		var here := Enemy.body_light(reach + 0.5, whole)
		check(here < last and last - here <= Enemy.LIGHT_STEP + 0.001, "one step down past %.0f px (%.3f after %.3f)" % [reach, here, last])
		last = here
	check(last == 0.0, "and none past the widest")
	# It is not a tint over a whole figure: a foe as tall as a dwarf keeps its far end.
	for sheet: String in ["rot_dwarf", "iron_dwarf", "shade_knight", "spire_sentinel", "bark_knight"]:
		var s := Sheet.get_sheet(sheet)
		for anim: String in Enemy.TELL_POINTS[sheet]:
			var p := Enemy.tell_point(sheet, anim, 0)
			var far := 0.0
			var mask: Image = (s.mask as Texture2D).get_image()
			if mask.is_compressed():
				mask.decompress()
			var at := Sheet.region(sheet, anim, 0)
			for y in range(0, int(at.size.y), 2):
				for x in range(0, int(at.size.x), 2):
					if mask.get_pixel(int(at.position.x) + x, int(at.position.y) + y).a > 0.5:
						far = maxf(far, maxf(absf(x - p.x), absf(y - p.y)) / float(s.density))
			check(Enemy.body_light(far, whole, Enemy.tell_reach_scale(sheet)) == 0.0,
				"%s/%s: the far end of the body (%.0f px off) keeps its own colors" % [sheet, anim, far])

	var d := _dwarf()
	await frames(2)
	check(d.light_drawn() == 0.0, "a dwarf on patrol wears no light")
	d.set_state("windup")
	var before := 0.0
	var seen := 0
	for i in 24:
		await frames(1)
		if d.state != "windup":
			break
		check(d.light_drawn() >= before, "the light never drops between beats (%.3f after %.3f)" % [d.light_drawn(), before])
		check(d.white_strength() == 0.0, "and it is not a flat tint over him")
		before = d.light_drawn()
		seen += 1
	check(seen >= 20 and is_equal_approx(before, top), "gathered, it is whole (%.2f)" % before)
