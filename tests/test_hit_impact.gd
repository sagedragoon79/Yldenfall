extends TestSuite
## The hit frame reads (pass 592, bible 6.7). The pass 590 grade scored combat
## readability 4.5: "the spark is small, and the struck foe shows no flash or
## knockback pose". Every spark now lays a long tapered streak across the foe, the
## cut itself, and a foe drawn from a sheet leans away from the blow through its
## hitstun, easing upright as it ends.

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


func test_a_spark_lays_a_streak_across_the_foe() -> void:
	var s := HitSpark.spawn(arena, Vector2(100, 100), Vector2.RIGHT)
	await frames(1)
	check(s.streak() == 1.0 and s.streak_drawn == 1.0, "the streak is drawn at full the moment the blade bites")
	var a := s.streak_axis()
	check(a.x > 0.3 and a.y < -0.3, "a level cut to the right lays it on a rising diagonal (%s)" % a)
	check(HitSpark.STREAK_LEN >= 36.0, "it is longer than a foe is wide (%s px)" % HitSpark.STREAK_LEN)
	check(s.streak_center().x > 0.0, "its middle lies on past the spark, over the foe")
	await frames(int(ceil(HitSpark.STREAK_LIFE * HitSpark.STREAK_HOLD * 60.0)) - 2)
	check(s.streak() == 1.0, "it holds at full for the first part of its life")
	await frames(int(ceil(HitSpark.STREAK_LIFE * 60.0)) + 1)
	check(s.streak() == 0.0 and s.streak_drawn == 0.0, "and is gone by %s s" % HitSpark.STREAK_LIFE)

	var l := HitSpark.spawn(arena, Vector2(100, 100), Vector2.LEFT)
	await frames(1)
	check(l.streak_axis().x < -0.3 and l.streak_axis().y < -0.3, "a cut to the left mirrors it")
	check(l.streak_center().x < 0.0, "with its middle on the left")

	var heavy := HitSpark.spawn(arena, Vector2(100, 100), Vector2.RIGHT, 1.6)
	await frames(1)
	check(heavy.streak_center().length() > s.streak_center().length(), "the heavy finisher's streak is bigger")

	# Both looks lay it: the code rays as well as the sheet.
	HitSpark.trial = "code"
	var c := HitSpark.spawn(arena, Vector2(100, 100), Vector2.RIGHT)
	await frames(1)
	check(c.streak_drawn == 1.0, "the code look draws it too")
	HitSpark.trial = ""


func test_a_struck_foe_leans_away_from_the_blow() -> void:
	var h := _hornet()
	await frames(2)
	check(h.lean_drawn() == 0.0, "a hornet at rest is drawn upright")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.recoil() > 0.8, "the frame after a blow it is deep in its recoil (%s)" % h.recoil())
	check(h.lean_drawn() > 0.2, "and drawn leaning right, the way the blow pushed it (%s)" % h.lean_drawn())
	var first := h.lean_drawn()
	await frames(5)
	check(h.lean_drawn() > 0.0 and h.lean_drawn() < first, "it eases back as the hitstun runs (%s)" % h.lean_drawn())
	await frames(int(ceil(Enemy.HITSTUN * 60.0)) + 2)
	check(h.lean_drawn() == 0.0, "and stands upright again when the hitstun is over")

	h.take_hit(1, Vector2(-1, 0))
	await frames(1)
	check(h.lean_drawn() < -0.2, "a blow from the right throws it leaning left (%s)" % h.lean_drawn())
	await frames(int(ceil(Enemy.HITSTUN * 60.0)) + 2)

	# A blow its guard turns, or no blow at all, leaves it upright.
	h.stagger()
	await frames(2)
	check(h.lean_drawn() == 0.0, "a stagger with no blow behind it does not lean")


## Pass 599 (bible 6.7): the pass 595 grade read the slash and spark as covering
## the struck foe. The streak now runs behind the actors and comes out past the
## body, and a foe in its hit flash draws above the swing's smear.
func test_the_cut_runs_behind_the_struck_foe() -> void:
	var s := HitSpark.spawn(arena, Vector2(100, 100), Vector2.RIGHT)
	await frames(1)
	check(not s.streak_layer.z_as_relative and s.streak_layer.z_index < 0, "the streak draws on its own layer, under the actors (z %d)" % s.streak_layer.z_index)
	check(s.streak_drawn == 1.0, "and is drawn there at full")
	check(s.z_index > Enemy.STRUCK_Z, "the spark itself stays on top of a struck foe")
	var tip := s.streak_center() + s.streak_axis() * HitSpark.STREAK_LEN * 0.5
	check(tip.x >= 30.0 and tip.y <= -18.0, "its far tip comes out past a foe's body, up and on (%s)" % tip)
	check(SlashFx.Z < Enemy.STRUCK_Z, "the swing's smear draws under a struck foe")

	var h := _hornet()
	await frames(2)
	var rest := h.z_index
	check(not h.drawn_struck() and rest < SlashFx.Z, "a hornet at rest draws under the smear (z %d)" % rest)
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.drawn_struck() and h.z_index == Enemy.STRUCK_Z, "struck, it draws above the smear (z %d)" % h.z_index)
	await frames(int(ceil(Enemy.STRUCK_TIME * 60.0)) + 2)
	check(not h.drawn_struck() and h.z_index == rest, "and goes back to its own z when the blow has played (z %d)" % h.z_index)

	# A foe with a z of its own gets it back.
	h.z_index = 1
	h.take_hit(1, Vector2(-1, 0))
	await frames(1)
	check(h.z_index == Enemy.STRUCK_Z, "a raised foe is raised again when struck")
	await frames(int(ceil(Enemy.STRUCK_TIME * 60.0)) + 2)
	check(h.z_index == 1, "and comes back to its own z of 1 (%d)" % h.z_index)

	# A tell is not a blow: winding up never raises a foe.
	h.set_state("windup")
	await frames(3)
	check(not h.drawn_struck() and h.z_index == 1, "a tell leaves it where it was")
