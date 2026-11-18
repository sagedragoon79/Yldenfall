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
		if h.white_strength() == Enemy.SHEET_TELL and h.tell_drawn():
			pulses += 1
		elif h.white_strength() > 0.0:
			other += 1
		else:
			rest += 1
			check(not h.tell_drawn(), "between pulses the hornet is in its own colors")
	check(pulses >= 2, "the tell pulses the hornet in the tell's tint (%d frames)" % pulses)
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
	check(Enemy.FLASH_SOFT_WASH >= 0.3 and Enemy.SHEET_SOFT_WHITE >= 0.3, "and is still seen as a flash")


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
