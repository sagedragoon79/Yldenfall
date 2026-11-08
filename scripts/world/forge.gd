class_name Forge
extends Node2D
## The Kettleforge forge (room prop `forge`): a brick hearth under an iron hood,
## coals that breathe with the bellows, and an anvil the smith rings every
## couple of seconds, throwing sparks. Scenery only, drawn at 2x density
## (half-pixel detail). The origin is the bottom center of the hearth.

const OUTLINE := Color("120f19")
const BRICK := Color("6e3a1a")
const BRICK_LIGHT := Color("a0522d")
const MORTAR := Color("3a2420")
const IRON := Color("4a4560")
const IRON_LIGHT := Color("7a7296")
const IRON_DARK := Color("2a2638")
const COAL := Color("2a1a1a")
const EMBER := Color("e8641c")
const HOT := Color("f0c02e")
const WHITE_HOT := Color("f7f1de")
const LEATHER := Color("783c2b")
const WOOD := Color("48201e")

## Seconds between hammer strikes on the anvil.
const STRIKE_EVERY := 1.6
## Where the anvil stands, from the origin.
const ANVIL := Vector2(-44, 0)
## The ring is heard within this distance of the player.
const HEAR := 260.0

var t := 0.0
var strikes := 0
var _next_strike := 0.8
## Live sparks: [position, velocity, life].
var sparks: Array = []
## Embers drifting up the flue: [position, life].
var _embers: Array = []
var _rng := RandomNumberGenerator.new()
var _glow: Node2D

## The ember pool the hearth throws onto the brick and floor around it (RoomLight
## reads these): the forge is the brightest fixed light in the Kettleforge.
var glow_color := EMBER
var glow_radius := 118.0


func _ready() -> void:
	z_index = -2
	# Its coals light the smithy around it (design bible 12.10).
	add_to_group(RoomLight.GROUP)
	_rng.seed = 7
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.z_index = 1
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func breath() -> float:
	# The bellows push air in a slow rhythm; the coals brighten with each push.
	return 0.5 + 0.5 * sin(t * 2.4)


func _process(delta: float) -> void:
	t += delta
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike += STRIKE_EVERY
		strike()
	for s: Array in sparks:
		s[1].y += 420.0 * delta
		s[0] += s[1] * delta
		s[2] -= delta
	sparks = sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	if _rng.randf() < delta * 6.0:
		_embers.append([Vector2(_rng.randf_range(-6, 6), -62), 1.6])
	for e: Array in _embers:
		e[0] += Vector2(sin(t * 3.0 + e[1] * 5.0) * 6.0, -38.0) * delta
		e[1] -= delta
	_embers = _embers.filter(func(e: Array) -> bool: return e[1] > 0.0)
	queue_redraw()
	_glow.queue_redraw()


## One ring of the hammer: a shower of sparks off the anvil, heard nearby.
func strike() -> void:
	strikes += 1
	for i in 9:
		var v := Vector2(_rng.randf_range(-110, 110), _rng.randf_range(-190, -80))
		sparks.append([ANVIL + Vector2(_rng.randf_range(-4, 4), -15), v, _rng.randf_range(0.25, 0.55)])
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		var d := p.global_position.distance_to(global_position + ANVIL)
		if d < HEAR:
			Sfx.play("anvil", 0.05, -10.0 - 14.0 * d / HEAR)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _draw() -> void:
	var b := breath()
	# The flue climbs out of sight.
	_px(-9, -260, 18, 200, OUTLINE)
	_px(-8, -260, 16, 200, IRON_DARK)
	_px(-8, -260, 2, 200, IRON)
	var y := -250.0
	while y < -64.0:
		_px(-9, y, 18, 1.5, IRON)
		y += 24.0
	# The hood: a trapezoid of riveted iron.
	var hood := PackedVector2Array([Vector2(-34, -40), Vector2(34, -40), Vector2(12, -64), Vector2(-12, -64)])
	draw_colored_polygon(PackedVector2Array([Vector2(-36, -39), Vector2(36, -39), Vector2(13, -65), Vector2(-13, -65)]), OUTLINE)
	draw_colored_polygon(hood, IRON)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -40), Vector2(-28, -40), Vector2(-10, -64), Vector2(-12, -64)]), IRON_LIGHT)
	_px(-34, -42, 68, 2, IRON_DARK)
	for i in 6:
		draw_circle(Vector2(-26 + i * 10.5, -44.5), 0.9, IRON_LIGHT)
	# The brick hearth.
	_px(-31, -40, 62, 40, OUTLINE)
	_px(-30, -39, 60, 39, BRICK)
	for row in 7:
		var ry := -39.0 + row * 5.5
		_px(-30, ry, 60, 0.5, MORTAR)
		var off := 0.0 if row % 2 == 0 else 5.0
		var bx := -30.0 + off
		while bx < 30.0:
			_px(bx, ry, 0.5, 5.5, MORTAR)
			_px(bx + 0.5, ry + 0.5, 9, 0.5, BRICK_LIGHT)
			bx += 10.0
	# The mouth, and the coals inside it.
	_px(-20, -30, 40, 20, OUTLINE)
	_px(-19, -29, 38, 18, COAL)
	for i in 13:
		var cx := -17.0 + i * 2.8
		var heat := 0.5 + 0.5 * sin(t * 5.0 + i * 1.7)
		var c := EMBER.lerp(HOT, heat * b)
		var h := 3.0 + 2.5 * heat + 2.0 * b
		_px(cx, -11 - h, 2.5, h, c)
		if heat * b > 0.6:
			_px(cx + 0.5, -11 - h, 1.5, 1.0, WHITE_HOT)
	# Flames licking up at the back of the mouth.
	for i in 4:
		var fx := -12.0 + i * 8.0
		var fh := 6.0 + 6.0 * b * (0.6 + 0.4 * sin(t * 9.0 + i * 2.0))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 3, -12), Vector2(fx + 3, -12), Vector2(fx + sin(t * 7.0 + i) * 1.5, -12 - fh)]), EMBER.lerp(HOT, 0.4))
	_px(-30, -10, 60, 2, BRICK_LIGHT)
	# The bellows on the right: two boards and a leather fold, pumping.
	var open := 4.0 + 5.0 * (1.0 - b)
	var bx2 := 36.0
	draw_colored_polygon(PackedVector2Array([Vector2(bx2, -17), Vector2(bx2 + 22, -20 - open), Vector2(bx2 + 22, -14 + open), Vector2(bx2, -13)]), LEATHER)
	_px(bx2 - 1, -21 - open * 0.5, 24, 2, WOOD)
	_px(bx2 - 1, -11 + open * 0.5, 24, 2, WOOD)
	_px(bx2 + 22, -24 - open * 0.5, 1.5, 6, WOOD)
	_px(31, -16, 6, 2, IRON)
	# The anvil on its stump.
	var a := ANVIL
	_px(a.x - 6, a.y - 9, 12, 9, OUTLINE)
	_px(a.x - 5, a.y - 9, 10, 9, WOOD)
	_px(a.x - 3, a.y - 9, 1, 9, LEATHER)
	draw_colored_polygon(PackedVector2Array([a + Vector2(-13, -15), a + Vector2(9, -15), a + Vector2(5, -10), a + Vector2(-7, -10)]), OUTLINE)
	_px(a.x - 12, a.y - 17, 22, 4, IRON)
	_px(a.x - 12, a.y - 17, 22, 1, IRON_LIGHT)
	draw_colored_polygon(PackedVector2Array([a + Vector2(-12, -17), a + Vector2(-18, -16), a + Vector2(-12, -14)]), IRON)
	_px(a.x - 4, a.y - 13, 8, 3, IRON_DARK)
	# A glowing billet on the anvil cools between strikes.
	var since := STRIKE_EVERY - _next_strike
	var billet := HOT.lerp(EMBER, clampf(since / STRIKE_EVERY, 0.0, 1.0))
	_px(a.x - 4, a.y - 18.5, 9, 1.5, billet)
	# Sparks and embers.
	for s: Array in sparks:
		var life: float = s[2]
		_px(s[0].x, s[0].y, 1.0, 1.0, HOT.lerp(WHITE_HOT, clampf(life * 2.0, 0.0, 1.0)))
	for e: Array in _embers:
		_px(e[0].x, e[0].y, 1.0, 1.0, EMBER.lerp(HOT, clampf(e[1] - 0.8, 0.0, 1.0)))


func _draw_glow() -> void:
	var b := breath()
	var warm := Color(EMBER.r, EMBER.g * 0.8, EMBER.b * 0.4, 0.016 + 0.016 * b)
	for i in 8:
		_glow.draw_circle(Vector2(0, -20), 72.0 - i * 7.5, warm)
	var flash := clampf(1.0 - (STRIKE_EVERY - _next_strike) * 5.0, 0.0, 1.0)
	if flash > 0.0:
		_glow.draw_circle(ANVIL + Vector2(0, -17), 18.0, Color(HOT.r, HOT.g, HOT.b, 0.18 * flash))
