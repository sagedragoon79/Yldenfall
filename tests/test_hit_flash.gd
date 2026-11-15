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


func test_a_tells_pulse_stays_full_white() -> void:
	var h := _hornet()
	await frames(2)
	h.set_state("windup")
	var pulses := 0
	var soft := 0
	for i in 16:
		await frames(1)
		if h.state != "windup":
			break
		if h.white_strength() == Enemy.SHEET_WHITE:
			pulses += 1
		elif h.white_strength() > 0.0:
			soft += 1
	check(pulses >= 2, "the tell pulses the hornet white (%d frames)" % pulses)
	check(soft == 0, "and never in the hit flash's pale tint")


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
	check(h.white_strength() == Enemy.FLASH_WASH, "a wash with no hit flash behind it (a tell) is full")
	h.wash(false)


## The numbers (bible 6.7): the tint leaves more than half of a foe's own
## contrast and is still a flash; the pop is nearly white.
func test_the_tint_keeps_more_than_half_of_the_foes_contrast() -> void:
	check(Enemy.FLASH_WASH >= 0.7 and Enemy.SHEET_WHITE >= 0.8, "the pop is nearly white")
	check(Enemy.FLASH_SOFT_WASH <= 0.45 and Enemy.SHEET_SOFT_WHITE <= 0.45,
		"the tint keeps more than half of the foe's own contrast")
	check(Enemy.FLASH_SOFT_WASH >= 0.3 and Enemy.SHEET_SOFT_WHITE >= 0.3, "and is still seen as a flash")
