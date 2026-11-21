extends TestSuite
## A blow knocks chips off the foe (pass 621, bible 6.7). The pass 615 grade read a
## landed hit as "one small spark with no foe flash, streak or debris in the frame".
## A blow that wounds breaks a few splinters off the body, in the foe's own colors,
## thrown on along the blow; a blow its guard turns breaks none.

const ROWS := [
	"####################",
	"#..................#",
	"#..................#",
	"#..................#",
	"#..........H.......#",
	"#..................#",
	"#..................#",
	"#..................#",
	"####################",
	"####################",
]


func _hornet() -> Hornet:
	var room := Room.from_text("\n".join(PackedStringArray(ROWS)))
	arena.add_child(room)
	for c in room.get_children():
		if c is Hornet:
			return c
	return null


func test_a_blow_knocks_chips_off_the_foe() -> void:
	var h := _hornet()
	await frames(2)
	check(h.chips == null, "a hornet no blow has touched has shed nothing")
	h.max_hp = 99
	h.hp = 99
	h.take_hit(1, Vector2(1, 0))
	var c := h.chips
	check(c != null and c.get_parent() == h.get_parent(), "a blow that wounds breaks chips off it, into the room")
	check(c.flying() == HitChips.COUNT, "%d of them (%d)" % [HitChips.COUNT, c.flying()])
	check(c.global_position.distance_to(h.center()) < 1.0, "from the middle of its body")
	check(c.z_index >= Enemy.STRUCK_Z and c.z_index < 4, "drawn over the struck foe and under the spark (z %d)" % c.z_index)
	var on := true
	var ahead := true
	for chip: Array in c.chips:
		on = on and (chip[1] as Vector2).x > 0.0
		ahead = ahead and (chip[0] as Vector2).x >= HitChips.AHEAD_MIN
	check(on, "every chip is thrown on, the way the blow went")
	check(ahead, "and starts on the side the blow leaves by")
	var from: Array[Vector2] = []
	for chip: Array in c.chips:
		from.append(chip[0])
	await frames(4)
	var clear := true
	for i in c.chips.size():
		clear = clear and ((c.chips[i][0] as Vector2).x - from[i].x) >= 5.0
	# The slowest chip at the steepest throw (260 px/s, 1.12 rad off the level) covers
	# 6.5 px in four braked steps; 8 px, the first bound, failed on such a throw in CI.
	check(clear, "four frames on, every chip has leapt 5 px or more from where it broke off")
	await frames(int(ceil(HitChips.LIFE_MAX * 60.0)) + 2)
	check(not is_instance_valid(c), "and they are gone within %s s" % HitChips.LIFE_MAX)

	h.take_hit(1, Vector2(-1, 0))
	var back := true
	for chip: Array in h.chips.chips:
		back = back and (chip[1] as Vector2).x < 0.0 and (chip[0] as Vector2).x <= -HitChips.AHEAD_MIN
	check(back, "a blow from the right throws them left")

	h.take_hit(1, Vector2(1.8, 0))
	check(h.chips.flying() == HitChips.HEAVY_COUNT, "a heavy blow breaks off %d (%d)" % [HitChips.HEAVY_COUNT, h.chips.flying()])


func test_the_chips_are_the_foes_own_colors() -> void:
	var h := _hornet()
	await frames(2)
	h.max_hp = 99
	h.hp = 99
	h.take_hit(1, Vector2(1, 0))
	var tones := Enemy.sheet_chip_colors("hornet")
	check(h.chips.colors == tones and tones.size() == 2, "a hornet's chips are read off its own sheet (%s)" % [tones])
	check(tones != HitChips.BONE, "not the pale bone of a foe with no sheet")
	var main := tones[0].lerp(HitChips.CREAM, HitChips.LIT)
	check((h.chips.chips[0][4] as Color).is_equal_approx(main), "a chip wears the body's main tone, lit a little by the blow")

	# Every sheet foe: two tones lighter than an outline, both in its own picture.
	var seen := 0
	for id: String in FoeLight.ACCENTS:
		if not Sheet.exists(id):
			continue
		seen += 1
		var t := Enemy.sheet_chip_colors(id)
		check(t.size() == 2 and t[0].get_luminance() >= Enemy.CHIP_DARK and t[1].get_luminance() >= t[0].get_luminance(),
				"%s: a main tone lighter than its outline, and one as light or lighter (%s)" % [id, t])
	check(seen >= 15, "the sheet foes were looked at (%d)" % seen)

	# A foe with no sheet is chipped in pale bone.
	var bare := Enemy.new()
	arena.add_child(bare)
	check(bare.chip_colors() == HitChips.BONE, "a foe with no sheet sheds pale bone")
	var none: Array[Color] = []
	var c := HitChips.spawn(arena, Vector2(50, 50), Vector2.RIGHT, none)
	check(c.colors == HitChips.BONE, "and chips given no tones take it too")


func test_the_hit_stop_holds_the_chips_and_a_turned_blow_sheds_none() -> void:
	var c := HitChips.spawn(arena, Vector2(100, 100), Vector2.RIGHT, HitChips.BONE)
	var at: Vector2 = c.chips[0][0]
	var vel: Vector2 = c.chips[0][1]
	c._physics_process(0.0)
	check((c.chips[0][0] as Vector2) == at and c.flying() == HitChips.COUNT, "a stopped clock holds every chip where it is")
	check((c.chips[0][1] as Vector2) == vel, "and brakes none of them: they leap on when it runs again")
	check(HitChips.size_at(1.0, 1.0) == 1.0 and HitChips.size_at(0.1, 1.0) == HitChips.SMALL, "a chip is whole, then small at the end of its fall: it never fades")
	var kite := HitChips.splinter(Vector2.ZERO, Vector2.RIGHT, 1.0)
	check(kite[0].x > -kite[2].x and is_equal_approx(kite[0].x - kite[2].x, HitChips.LONG), "a chip is a splinter that points the way it flies (%s)" % [kite])

	# A Rot Dwarf's shield turns a blow from the front: no wound, no chips.
	var d := RotDwarf.new()
	arena.add_child(d)
	await frames(2)
	d.take_hit(1, Vector2(-d.facing, 0))
	if d.hits_taken > 0 and d.hp == d.max_hp:
		check(d.chips == null, "a blow his shield turns breaks nothing off him")
	else:
		check(false, "the dwarf's shield should have turned a blow from his front (hp %d of %d)" % [d.hp, d.max_hp])
	d.take_hit(1, Vector2(d.facing, 0))
	check(d.hp < d.max_hp and d.chips != null, "a blow in his back does")
