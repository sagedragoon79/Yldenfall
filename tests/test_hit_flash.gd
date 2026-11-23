extends TestSuite
## A struck foe keeps its inner lines (pass 567, bible 6.7). The pass 565 grade
## saw the struck foe in both hit frames as "a solid white cutout". The frame a
## blow lands the foe is still drawn white, the pop; for the rest of the flash,
## the hit-stop included, it wears a pale tint its own lines show through. A
## tell's pulse stays the full white.

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


## How white the hornet was drawn on each of the next `n` frames.
func _watch(h: Hornet, n: int) -> Array[float]:
	var seen: Array[float] = []
	for i in n:
		await frames(1)
		seen.append(h.white_strength())
	return seen


func test_a_hit_flash_pops_white_once_then_keeps_the_foes_lines() -> void:
	var h := _hornet()
	await frames(2)
	check(h.white_strength() == 0.0, "a hornet at rest is drawn in its own colors")
	h.take_hit(1, Vector2(1, 0))
	var seen := await _watch(h, 12)
	var white := seen.filter(func(s: float) -> bool: return s > 0.0)
	check(white.size() >= 3, "the flash is drawn for three frames or more (%s)" % [seen])
	check(white.size() > 0 and white[0] == Enemy.SHEET_WHITE, "the frame the blow lands is the white pop")
	check(white.count(Enemy.SHEET_WHITE) == 1, "the pop is one frame (%s)" % [seen])
	check(white.count(Enemy.SHEET_SOFT_WHITE) == white.size() - 1, "and the rest of the flash is the pale tint")
	check(seen[-1] == 0.0, "the tint goes with the flash")
	check(h.drawn_white() == false, "and the hornet is in its own colors again")

	# A second blow inside the flash pops again.
	h.take_hit(1, Vector2(1, 0))
	await frames(2)
	check(h.white_strength() == Enemy.SHEET_SOFT_WHITE, "two frames into a flash the hornet wears the tint")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.white_strength() == Enemy.SHEET_WHITE, "a second blow inside the flash pops white again")


## Pass 585 (bible 6.7): a tell is a warm tint and a rim, never a white cutout.
## Since pass 611 (12.88) a sheet foe with a point for its weapon wears no tint at
## all: the pulse is the rim near the weapon and a longer glint.
func test_a_tells_pulse_is_its_own_tint_and_never_a_blows_white() -> void:
	var h := _hornet()
	await frames(2)
	check(not h.tell_drawn(), "a hornet at rest wears no tell")
	h.set_state("windup")
	var pulses := 0
	var other := 0
	var rest := 0
	for i in 16:
		await frames(1)
		if h.state != "windup":
			break
		if h.white_strength() == 0.0 and h.tell_drawn():
			pulses += 1
			check(h.glint_drawn() >= Enemy.GLINT_MIN + Enemy.GLINT_PULSE, "a lit beat's glint is the longer one")
		elif h.white_strength() > 0.0:
			other += 1
		else:
			rest += 1
			check(not h.tell_drawn(), "between pulses the hornet is in its own colors")
	check(pulses >= 2, "the tell pulses on the hornet, its body in its own colors (%d frames)" % pulses)
	check(other == 0, "and never in a blow's white or its pale tint")
	check(rest >= 2, "the pulse goes off between beats (%d frames)" % rest)

	# A blow that lands in the wind-up is white: white means a blow landed.
	h.set_state("windup")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.white_strength() == Enemy.SHEET_WHITE and not h.tell_drawn(),
		"a blow in the wind-up pops white over the tell")


## The overlay a foe drawn from a sheet wears: the tell's tint for a tell, white
## for a blow, and a half-seen foe's is scaled with it.
func test_the_overlay_is_the_tint_for_a_tell_and_white_for_a_blow() -> void:
	var h := _hornet()
	await frames(2)
	var tell := h.flash_overlay(true)
	check(tell.is_equal_approx(Color(Enemy.TELL_TINT, Enemy.SHEET_TELL)), "a tell's overlay is the tint (%s)" % tell)
	check(h.tell_drawn(), "and the drawing is marked as a tell, so the rim is drawn")
	check(is_equal_approx(h.flash_overlay(true, 0.5).a, Enemy.SHEET_TELL * 0.5), "a half-seen foe's is half as strong")
	h.flash_overlay(false)
	check(not h.tell_drawn() and not h.drawn_white(), "no overlay, no tell")
	h.take_hit(1, Vector2(1, 0))
	var pop := h.flash_overlay(true)
	check(pop.is_equal_approx(Color(1, 1, 1, Enemy.SHEET_WHITE)), "a blow's overlay is white (%s)" % pop)
	check(not h.tell_drawn(), "and is no tell")
	await frames(12)


func test_a_code_drawn_foes_wash_softens_the_same_way() -> void:
	var h := _hornet()
	await frames(2)
	h.take_hit(1, Vector2(1, 0))
	h.wash(true)
	check(h.washed() and h.white_strength() == Enemy.FLASH_WASH, "the wash is full on the frame the blow lands")
	check(is_equal_approx((h.material as ShaderMaterial).get_shader_parameter("amount"), Enemy.FLASH_WASH),
		"its shader washes by FLASH_WASH")
	await frames(1)
	h.wash(true)
	check(h.washed() and h.white_strength() == Enemy.FLASH_SOFT_WASH, "and soft from the next frame")
	check(is_equal_approx((h.material as ShaderMaterial).get_shader_parameter("amount"), Enemy.FLASH_SOFT_WASH),
		"its shader washes by FLASH_SOFT_WASH")
	h.wash(false)
	check(not h.washed(), "the soft wash comes off like the full one")
	await frames(10)
	h.wash(true)
	check(h.white_strength() == Enemy.FLASH_WASH and not h.tell_drawn(),
		"a wash with no blow and no tell behind it (a guardian's death blink) is white")
	h.wash(false)
	# A code-drawn foe's tell washes toward the tint, and less.
	h.set_physics_process(false)
	for tell: String in ["windup", "sweep_tell"]:
		h.state = tell
		h.wash(true)
		check(h.tell_drawn() and h.white_strength() == Enemy.TELL_WASH, "a wash in '%s' is the tell's" % tell)
		var m := h.material as ShaderMaterial
		check(is_equal_approx(m.get_shader_parameter("amount"), Enemy.TELL_WASH), "its shader washes by TELL_WASH")
		var tint: Variant = m.get_shader_parameter("tint")
		check(tint is Color and (tint as Color).is_equal_approx(Enemy.TELL_TINT), "toward TELL_TINT (%s)" % [tint])
		h.wash(false)
		check(not h.washed() and not h.tell_drawn(), "and comes off")
	h.state = "idle"


## The numbers (bible 6.7): the tint leaves more than half of a foe's own
## contrast and is still a flash; the pop is nearly white.
func test_the_tint_keeps_more_than_half_of_the_foes_contrast() -> void:
	check(Enemy.FLASH_WASH >= 0.7 and Enemy.SHEET_WHITE >= 0.8, "the pop is nearly white")
	check(Enemy.FLASH_SOFT_WASH <= 0.45 and Enemy.SHEET_SOFT_WHITE <= 0.45,
		"the tint keeps more than half of the foe's own contrast")
	check(Enemy.FLASH_SOFT_WASH >= 0.3, "a code-drawn foe has no edge, so its tint is still seen as a flash")
	check(Enemy.SHEET_SOFT_WHITE >= 0.1 and Enemy.SHEET_SOFT_WHITE <= 0.2,
		"a sheet foe's struck edge carries the flash, so its body keeps most of its colors (pass 646)")


## The tell's numbers (bible 6.7, pass 585): it keeps more than half of the foe's
## contrast, is still seen, is a warm hue that no blow's white can be taken for,
## and its rim is nearly solid.
func test_the_tell_keeps_the_foes_pose_and_is_not_white() -> void:
	check(Enemy.TELL_WASH < 0.5 and Enemy.SHEET_TELL < 0.5, "the tell keeps more than half of the foe's own contrast")
	check(Enemy.TELL_WASH >= 0.35, "a code-drawn foe has no rim, so its wash is still seen as a pulse")
	check(Enemy.SHEET_TELL >= 0.12 and Enemy.SHEET_TELL <= 0.3,
		"a sheet foe's rim carries the warning, so its body keeps most of its own colors (pass 586)")
	var t := Enemy.TELL_TINT
	check(t.r >= 0.95 and t.b <= 0.5 and t.g > t.b and t.g < t.r, "the tint is a warm gold, not white (%s)" % t)
	check(t.s >= 0.5, "saturated enough to tell from a blow's white (s %.2f)" % t.s)
	check(Enemy.TELL_RIM >= 0.8, "the rim is nearly solid")
	check(Enemy.RIM_STEPS.size() == 4, "and stands on all four sides")
	for step: Vector2 in Enemy.RIM_STEPS:
		check(is_equal_approx(step.length(), 1.0), "one pixel wide (%s)" % step)


## Pass 602 (bible 6.7): a hit flash's white overlay also washed out a sheet foe's
## dark outline, so the pass 600 grade read the struck foe as going see-through.
## Through the flash a sheet foe wears a dark rim, as a tell wears its warm one.
func test_a_struck_foe_keeps_a_dark_edge() -> void:
	var h := _hornet()
	await frames(2)
	check(not h.hit_rim_drawn(), "a hornet at rest wears no rim")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.hit_rim_drawn() and h.white_strength() == Enemy.SHEET_WHITE, "struck, it wears the dark rim with the white pop")
	await frames(2)
	check(h.hit_rim_drawn() and h.white_strength() == Enemy.SHEET_SOFT_WHITE, "and through the pale tint")
	var c := Enemy.HIT_RIM_COLOR
	check(c.v <= 0.12 and Enemy.HIT_RIM >= 0.9, "the rim is near-black and nearly solid (%s, %.2f)" % [c, Enemy.HIT_RIM])
	check(c.v < Enemy.TELL_TINT.v * 0.2, "never to be taken for a tell's warm rim")
	await frames(14)
	check(not h.hit_rim_drawn() and not h.drawn_white(), "and it goes with the flash")


## Pass 607 (bible 6.7): the pass 605 grade still read the struck foe as "a
## see-through ghost": 40 to 45 percent of white over a dark foe made a flat
## lavender-grey near the backdrop's hue. The soft phase is now 0.3 of a warm
## cream, so the foe keeps most of its own colors; the pop stays white.
func test_a_struck_foe_keeps_its_own_colors_through_the_flash() -> void:
	var h := _hornet()
	await frames(2)
	h.take_hit(1, Vector2(1, 0))
	var pop := h.flash_overlay(true)
	check(pop.is_equal_approx(Color(1, 1, 1, Enemy.SHEET_WHITE)), "the frame the blow lands is still the white pop")
	await frames(2)
	var soft := h.flash_overlay(true)
	check(soft.a <= 0.3 + 0.001, "after it, the overlay covers at most 30 percent (%.2f)" % soft.a)
	check(soft.r >= soft.g and soft.g > soft.b, "in a warm cream, not white (%s)" % soft)
	var t := Enemy.SOFT_TINT
	check(t.r > t.b + 0.15 and t.v > 0.9, "a pale warm tint")
	# A dark violet foe under the soft phase stays well below the pale grey a ghost reads as.
	var violet := Color("3a2f4a")
	var seen := violet.lerp(Color(t, 1.0), soft.a)
	# Since pass 646 a sheet foe's tint is lighter still: it keeps its own hue, and the struck edge carries the blow.
	check(seen.v < 0.5 and absf(seen.h - violet.h) < 0.08, "a dark violet foe stays dark and keeps its hue, not lavender (%s)" % seen)
	var cream := violet.lerp(Color(t, 1.0), Enemy.FLASH_SOFT_WASH)
	check(cream.v < 0.5 and cream.r > cream.b, "under a code-drawn foe's wash it stays dark and turns warm (%s)" % cream)
	h.wash(true)
	var mat := h.material as ShaderMaterial
	check(mat != null and (mat.get_shader_parameter("tint") as Color).is_equal_approx(t), "a code-drawn foe's soft wash takes the same tint")
	await frames(12)


## Pass 646 (bible 6.7): the pass 645 grade called the fight's contact points "mush";
## under the cream tint the struck foe was a muddy shape. Through a hit flash a sheet
## foe wears a crescent of warm white inside its outline on the side the blow came
## from, and keeps its own colors elsewhere.
func test_a_struck_foe_is_lit_on_the_side_the_blow_came_from() -> void:
	var h := _hornet()
	await frames(2)
	check(h.struck_edge_drawn() == 0, "a hornet at rest wears no struck edge")
	h.take_hit(1, Vector2(1, 0))
	await frames(1)
	check(h.struck_edge_drawn() == -1, "a blow pushing it right lights its left side (%d)" % h.struck_edge_drawn())
	await frames(2)
	check(h.struck_edge_drawn() == -1 and h.white_strength() == Enemy.SHEET_SOFT_WHITE,
		"and still through the soft phase")
	await frames(14)
	check(h.struck_edge_drawn() == 0, "it goes with the flash")
	h.take_hit(1, Vector2(-1, 0))
	await frames(1)
	check(h.struck_edge_drawn() == 1, "a blow pushing it left lights its right side (%d)" % h.struck_edge_drawn())
	await frames(16)
	var e := Enemy.STRUCK_EDGE
	check(e.v >= 0.95 and e.r >= e.b, "the edge is a warm white (%s)" % e)
	check(e.s < Enemy.TELL_TINT.s * 0.5, "never to be taken for a tell's gold")
	check(Enemy.STRUCK_EDGE_WIDTH >= 1.0 and Enemy.STRUCK_EDGE_WIDTH <= 2.0, "one to two world pixels wide")
	h.set_state("windup")
	var tells := 0
	for i in 8:
		await frames(1)
		if h.tell_drawn():
			tells += 1
			check(h.struck_edge_drawn() == 0, "a tell never wears it")
	check(tells >= 1, "the wind-up pulsed (%d frames)" % tells)
	h.state = "idle"
