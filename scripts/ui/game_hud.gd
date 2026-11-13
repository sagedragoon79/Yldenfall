class_name GameHud
extends Control
## In-game HUD drawn in code at the 640x360 base resolution: health masks,
## magic bar, Sapflask charges and gold. Rendered at native resolution
## (outside the pixel-art viewport) so it stays sharp.

const MASK_HP := 20
const OUTLINE := Color("1d1a2b")
const MASK_FULL := Color("f1ead2")
const MASK_EMPTY := Color("3a344c")
const MASK_SHINE := Color("ffffff")
const MP := Color("4aa3df")
const MP_DARK := Color("23385e")
const POTION := Color("e0404a")
const POTION_EMPTY := Color("4a2a34")
const GOLD := Color("ffd24a")
const HURT_RED := Color("d0202c")
## Peak alpha of the hurt edge, how fast it fades (per second), the low-health
## pulse at its height, and how many bands the edge fades over.
const HURT_EDGE := 0.5
const HURT_FADE := 2.5
const LOW_EDGE := 0.24
const EDGE_STEPS := 6
const OINTMENT := Color("f0c02e")
const POISONED := Color("6fb83a")
const POISONED_SHINE := Color("c8f08a")

var player: Player

const BANNER_TIME := 3.2
const TOAST_TIME := 2.2

## The gold the counter shows; below 0 until it first sees the purse.
var _shown_gold := -1.0
var _banner_title := ""
var _banner_sub := ""
var _banner_t := 0.0
var _toast := ""
var _toast_t := 0.0
var _flash := 0.0
## The red edge flash when you're hurt (design bible 5.3), and the health it last saw.
var hurt := 0.0
var _last_hp := -1
var _pulse_t := 0.0
## The boss bar's shown health trails the real value, like the gold counter.
var _boss_shown := 1.0
var _mask_cache := {}
## Frames drawn (the soak test checks the HUD really draws).
var draws := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.banner.connect(show_banner)
	GameState.toast.connect(show_toast)
	GameState.flash.connect(func(strength: float) -> void: _flash = maxf(_flash, strength * Feel.flash_scale))


func show_banner(title: String, subtitle: String) -> void:
	_banner_title = title
	_banner_sub = subtitle
	_banner_t = BANNER_TIME


func show_toast(text: String) -> void:
	_toast = text
	_toast_t = TOAST_TIME


func _process(delta: float) -> void:
	# Words on screen are read in real time (pass 482): a guardian's reward
	# banner or a toast lasts as long at a slower Game speed, in a boss's slow
	# motion or through hitstop as at full speed.
	var real := Feel.unscaled(delta)
	_banner_t = maxf(_banner_t - real, 0.0)
	_toast_t = maxf(_toast_t - real, 0.0)
	_flash = maxf(_flash - delta * 1.6, 0.0)
	hurt = maxf(hurt - delta * HURT_FADE, 0.0)
	_pulse_t += delta
	if player:
		if _last_hp >= 0 and player.hp < _last_hp:
			hurt = maxf(hurt, Feel.flash_scale)
		_last_hp = player.hp
	if player:
		_shown_gold = shown_gold_after(_shown_gold, player.gold, delta, get_tree().paused)
	queue_redraw()


## The counter rolls toward the real total, like an arcade score (design bible
## 12, the gold counter, pass 532). It starts on the purse itself (`shown` below
## 0: a loaded save does not roll up from nothing), and while the tree is paused
## it shows the exact sum, since a shop or the pause menu then prints that sum
## beside it.
static func shown_gold_after(shown: float, gold: int, delta: float, paused: bool) -> float:
	if shown < 0.0 or paused:
		return float(gold)
	return move_toward(shown, gold, maxf(40.0, absf(gold - shown) * 6.0) * delta)


func _draw() -> void:
	if player == null:
		return
	draws += 1
	var origin := Vector2(10, 10)
	var masks := ceili(float(player.max_hp) / MASK_HP)
	var mask_x := 0.0
	var widths: Array[float] = []
	for i in masks:
		var cap := clampf(float(player.max_hp - i * MASK_HP) / MASK_HP, 0.0, 1.0)
		widths.append(12.0 if cap >= 1.0 else 7.0)
		mask_x += widths[i] + 2.0
	var bar_w := maxf(mask_x - 2.0, player.max_mp)
	var row_w := maxf(bar_w, player.flask_max * 9 + 48 + (14 if _glass_shown() else 0))
	_draw_plate(Rect2(origin - Vector2(5, 5), Vector2(row_w + 10, 43 + (14 if _ointment_shown() or player.glove_left > 0.0 else 0))))
	mask_x = 0.0
	for i in masks:
		# The last container is narrower when a Life Fruit has added half a mask.
		var cap := clampf(float(player.max_hp - i * MASK_HP) / MASK_HP, 0.0, 1.0)
		var fill := clampf(float(player.hp - i * MASK_HP) / (MASK_HP * cap), 0.0, 1.0)
		_draw_mask(origin + Vector2(mask_x, 0), widths[i] < 12.0, fill)
		mask_x += widths[i] + 2.0
	_draw_mp(Rect2(origin + Vector2(0, 18), Vector2(bar_w, 5)))
	# Sapflask charges.
	for i in player.flask_max:
		_draw_flask(origin + Vector2(i * 9, 28), i < player.flask_charges)
	# Gold.
	var gp := origin + Vector2(player.flask_max * 9 + 6, 28)
	_draw_coin(gp + Vector2(3, 5))
	PixelFont.draw(self, gp + Vector2(10, 9), str(int(maxf(_shown_gold, 0.0))), 10, GOLD, OUTLINE)
	if _glass_shown():
		_draw_glass(origin + Vector2(row_w - 8, 27))
	_draw_ointment(origin + Vector2(0, 42))
	_draw_glove(origin + Vector2(48, 42))
	_draw_minimap()
	_draw_boss()
	_draw_trial()
	_draw_messages()
	_draw_hurt_edge()
	if _flash > 0.0:
		draw_rect(get_viewport_rect(), Color(1, 1, 1, minf(_flash, 1.0)))


## A Ringreader Trial's name and clock, top center, while one is under way; or the
## boss rush's count and clock.
## The minimap in the top right corner (pass 373), while nothing covers it.
func _draw_minimap() -> void:
	var world := get_tree().get_first_node_in_group("world") as World
	if world == null or not Minimap.showing(self):
		return
	Minimap.draw(self, Minimap.window(get_viewport_rect().size), world, _pulse_t)


func _draw_trial() -> void:
	if BossRush.active():
		_draw_rush()
		return
	if not Trials.active():
		return
	var t := Trials.find(Trials.run.id)
	var title := String(t.get("name", "")).to_upper()
	var clock := Trials.format_time(float(Trials.run.time))
	var best := Trials.best(Trials.run.id)
	var sub := "BEST " + Trials.format_time(best) if best != INF else "FIRST WALK"
	var w := maxf(PixelFont.width(title, 10), PixelFont.width(clock, 20)) + 20.0
	var x := get_viewport_rect().size.x * 0.5
	_draw_plate(Rect2(Vector2(x - w * 0.5, 6), Vector2(w, 46)))
	PixelFont.draw(self, Vector2(x - PixelFont.width(title, 10) * 0.5, 17), title, 10, MASK_FULL, OUTLINE)
	PixelFont.draw(self, Vector2(x - PixelFont.width(clock, 20) * 0.5, 37), clock, 20, MASK_FULL, OUTLINE)
	PixelFont.draw(self, Vector2(x - PixelFont.width(sub, 10) * 0.5, 49), sub, 10, GOLD, OUTLINE)


## How strongly the screen's edge glows red now: a hit's flash, or at low health
## a slow pulse in time with the heartbeat.
func edge_strength() -> float:
	var s := hurt * HURT_EDGE
	if player and player.is_low_health():
		# Locked to the heartbeat itself (pass 484): brightest as it sounds.
		var beat := 0.5 + 0.5 * cos(player.heartbeat_phase() * TAU)
		s = maxf(s, LOW_EDGE * (0.4 + 0.6 * beat) * maxf(Feel.flash_scale, 0.5))
	return s


func _draw_hurt_edge() -> void:
	var s := edge_strength()
	if s <= 0.01:
		return
	var r := get_viewport_rect()
	var band := r.size.y * 0.035
	for i in EDGE_STEPS:
		var a := s * pow(1.0 - float(i) / EDGE_STEPS, 2.0)
		var c := Color(HURT_RED, a)
		var o := band * i
		draw_rect(Rect2(r.position + Vector2(o, o), Vector2(r.size.x - o * 2.0, band)), c)
		draw_rect(Rect2(r.position + Vector2(o, r.size.y - o - band), Vector2(r.size.x - o * 2.0, band)), c)
		draw_rect(Rect2(r.position + Vector2(o, o + band), Vector2(band, r.size.y - o * 2.0 - band * 2.0)), c)
		draw_rect(Rect2(r.position + Vector2(r.size.x - o - band, o + band), Vector2(band, r.size.y - o * 2.0 - band * 2.0)), c)


# --- 2x icons --------------------------------------------------------------------
# The HUD renders at the window's full resolution, so icons are drawn in
# half-pixels (2x density, like the world art) through _hp() and _hpoly().

const MASK_SHADE := Color("c9b98f")
const MASK_EYE := Color("8a7a5a")
const MASK_EMPTY_LIGHT := Color("4e4766")
const POISONED_DARK := Color("3f7a2a")
const MP_LIGHT := Color("9fdcff")
const MP_DEEP := Color("2a6fb0")
const GLASS := Color("c9c4d6")
const CORK := Color("8d4e16")
const POTION_LIGHT := Color("ff9a8a")
const GOLD_DARK := Color("b8860b")
const GLASS_SAND := Color("e8c870")
const PLATE := Color(0.07, 0.06, 0.11, 0.5)
## The plate fades in over this many steps of one unit (two screen pixels)
## outside its rect (pass 546), so it is a soft shade, not a black bar.
const PLATE_FEATHER := 6
## A full mask, 24x28 half-pixels: a carved ivory face, brow to chin.
const MASK_SHAPE := [Vector2(4, 0), Vector2(20, 0), Vector2(24, 4), Vector2(24, 14), Vector2(20, 22), Vector2(12, 28), Vector2(4, 22), Vector2(0, 14), Vector2(0, 4)]
## Half a mask (a Life Fruit's worth), 14 half-pixels wide.
const HALF_MASK_SHAPE := [Vector2(4, 0), Vector2(14, 0), Vector2(14, 27), Vector2(12, 28), Vector2(4, 22), Vector2(0, 14), Vector2(0, 4)]


func _hp(at: Vector2, x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(at + Vector2(x, y) * 0.5, Vector2(w, h) * 0.5), c)


func _hpoly(at: Vector2, pts: Array, grow: float = 0.0) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p: Vector2 in pts:
		center += p
	center /= pts.size()
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var q := p
		if grow != 0.0:
			q += (p - center).normalized() * grow
		out.append(at + q * 0.5)
	return out


## A faint backing plate so the HUD reads over bright rooms. Until pass 546 it
## was one hard-edged rectangle with a gold rule, which read as a stray black bar
## across the room (the pass 540 grade). It is now a soft shade: nested layers
## from `plate_layers`, each a little darker, so it fades in from nothing at its
## edge to the full PLATE behind the HUD itself.
func _draw_plate(r: Rect2) -> void:
	for layer: Array in plate_layers(r):
		draw_rect(layer[0], Color(PLATE, layer[1]))


## The plate's layers, outermost first: [rect, alpha]. Each step's alpha is
## chosen so that, stacked, they reach PLATE's alpha over the whole of `r`.
static func plate_layers(r: Rect2) -> Array:
	var step := 1.0 - pow(1.0 - PLATE.a, 1.0 / PLATE_FEATHER)
	var out := []
	for k in PLATE_FEATHER:
		var grow := float(PLATE_FEATHER - 1 - k)
		out.append([r.grow(grow), step])
	return out


## One health mask: ivory fills from the chin up as health returns; green when poisoned.
## A mask's polygons relative to its corner, built once per shape: outline,
## body, inner ring, inner fill and the lit face.
func _mask_polys(half: bool) -> Array:
	var key := "half" if half else "full"
	if not _mask_cache.has(key):
		var shape: Array = HALF_MASK_SHAPE if half else MASK_SHAPE
		_mask_cache[key] = [_hpoly(Vector2.ZERO, shape, 2.0), _hpoly(Vector2.ZERO, shape),
			_hpoly(Vector2(0.5, 0.5), shape, -2.0), _hpoly(Vector2(0.5, 0.5), shape, -3.0),
			_hpoly(Vector2(-0.5, -0.5), shape, -2.0)]
	return _mask_cache[key]


## One health mask: ivory fills from the chin up as health returns; green when poisoned.
func _draw_mask(at: Vector2, half: bool, fill: float) -> void:
	var polys := _mask_polys(half)
	draw_set_transform(at)
	draw_colored_polygon(polys[0], OUTLINE)
	draw_colored_polygon(polys[1], MASK_EMPTY)
	draw_colored_polygon(polys[2], MASK_EMPTY_LIGHT)
	draw_colored_polygon(polys[3], MASK_EMPTY)
	var sick := player.poison_left > 0.0
	var main := POISONED if sick else MASK_FULL
	var shade := POISONED_DARK if sick else MASK_SHADE
	if fill >= 1.0:
		draw_colored_polygon(polys[1], shade)
		draw_colored_polygon(polys[4], main)
	elif fill > 0.0:
		# Only a part-filled mask needs clipping at its fill line.
		var line := 14.0 * (1.0 - fill)
		var clip := PackedVector2Array([Vector2(-1, line), Vector2(13, line), Vector2(13, 15), Vector2(-1, 15)])
		for part in Geometry2D.intersect_polygons(polys[1], clip):
			draw_colored_polygon(part, shade)
		for part in Geometry2D.intersect_polygons(polys[4], clip):
			draw_colored_polygon(part, main)
	draw_set_transform(Vector2.ZERO)
	if fill >= 1.0:
		_hp(at, 4, 2, 3, 2, POISONED_SHINE if sick else MASK_SHINE)
		_hp(at, 3, 4, 2, 4, POISONED_SHINE if sick else MASK_SHINE)
	# The eyes and a brow line, carved in.
	var eye := (POISONED_DARK if sick else MASK_EYE) if fill > 0.45 else OUTLINE
	_hp(at, 5, 10, 5, 3, eye)
	if not half:
		_hp(at, 14, 10, 5, 3, eye)
	_hp(at, 11, 15, 2, 4, Color(eye, 0.6))


## The magic bar: a framed glass tube, ticked every 10 MP, with a gem cap.
func _draw_mp(bar: Rect2) -> void:
	draw_rect(bar.grow(1), OUTLINE)
	draw_rect(bar, MP_DARK)
	var w := roundf(bar.size.x * player.mp / maxf(1.0, player.max_mp) * 2.0) * 0.5
	if w > 0.0:
		draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), MP)
		draw_rect(Rect2(bar.position, Vector2(w, 1)), MP_LIGHT)
		draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 1), Vector2(w, 1)), MP_DEEP)
	var tick := bar.size.x * 10.0 / maxf(1.0, player.max_mp)
	var x := tick
	while x < bar.size.x - 1.0:
		draw_rect(Rect2(bar.position + Vector2(roundf(x * 2.0) * 0.5, 1), Vector2(0.5, bar.size.y - 2)), Color(OUTLINE, 0.55))
		x += tick
	# The gem cap, overlapping the left end, glows the equipped spell's color.
	var gem := Spells.color(player.equipped_spell)
	var g := bar.position + Vector2(-1.5, bar.size.y * 0.5)
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -4), g + Vector2(3.5, 0), g + Vector2(0, 4), g + Vector2(-3.5, 0)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -3), g + Vector2(2.5, 0), g + Vector2(0, 3), g + Vector2(-2.5, 0)]), gem)
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -3), g + Vector2(0, 0), g + Vector2(-2.5, 0)]), gem.lightened(0.45))


## One Sapflask charge: a round flask with a cork, full or empty glass.
func _draw_flask(at: Vector2, full: bool) -> void:
	var c := at + Vector2(3.5, 6)
	draw_circle(c, 4.0, OUTLINE)
	_hp(at, 3, 0, 8, 7, OUTLINE)
	_hp(at, 5, 0, 4, 2, CORK)
	_hp(at, 5, 2, 4, 4, GLASS)
	draw_circle(c, 3.0, POTION if full else POTION_EMPTY)
	if full:
		draw_rect(Rect2(c + Vector2(-3, -2.5), Vector2(6, 1)), Color(GLASS, 0.5))
		_hp(c, -4, -2, 2, 3, POTION_LIGHT)
	else:
		_hp(c, -4, -3, 2, 2, Color(GLASS, 0.5))


## A gold coin with a rim and a struck center.
func _draw_coin(c: Vector2) -> void:
	draw_circle(c, 4.0, OUTLINE)
	draw_circle(c, 3.0, GOLD_DARK)
	draw_circle(c + Vector2(-0.5, -0.5), 2.5, GOLD)
	_hp(c, -1, -2, 2, 4, GOLD_DARK)
	_hp(c, -4, -4, 2, 2, Color("fff4c0"))


func _glass_shown() -> bool:
	return player.abilities.get("stillstone", false)


## The Stillstone once owned: full and bright when it can be turned, sand
## pouring while time is stopped, the top bulb refilling as it runs back.
func _draw_glass(at: Vector2) -> void:
	var can_turn := TimeStop.ready_to_turn()
	var top := 1.0 if can_turn else 1.0 - TimeStop.cooldown / TimeStop.COOLDOWN
	if TimeStop.active():
		top = TimeStop.left / TimeStop.total
	var sand := GLASS_SAND if can_turn or TimeStop.active() else GLASS_SAND.darkened(0.45)
	draw_rect(Rect2(at + Vector2(0, 0), Vector2(8, 12)), OUTLINE)
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(6, 10)), Color(GLASS, 0.25))
	draw_rect(Rect2(at + Vector2(0, 0), Vector2(8, 1.5)), GOLD_DARK)
	draw_rect(Rect2(at + Vector2(0, 10.5), Vector2(8, 1.5)), GOLD_DARK)
	# The top bulb (4 rows) and the bottom (4 rows), the neck between.
	var th := roundf(top * 8.0) * 0.5
	draw_rect(Rect2(at + Vector2(1.5, 5.5 - th), Vector2(5, th)), sand)
	var bh := roundf((1.0 - top) * 8.0) * 0.5
	draw_rect(Rect2(at + Vector2(1.5, 10.5 - bh), Vector2(5, bh)), sand)
	draw_rect(Rect2(at + Vector2(3.5, 5.5), Vector2(1, 1)), Color(GLASS, 0.6))
	if TimeStop.active():
		draw_rect(Rect2(at + Vector2(3.75, 5.5), Vector2(0.5, 5)), sand)
	if can_turn:
		draw_rect(Rect2(at + Vector2(2, 2), Vector2(1, 2)), Color(1, 1, 1, 0.7))


func _ointment_shown() -> bool:
	return player.ointments > 0 or player.ointment_left > 0.0


## Barkbalms carried (a small jar and a count), and the time left on one in use.
func _draw_ointment(at: Vector2) -> void:
	var left := player.ointment_left
	if player.ointments <= 0 and left <= 0.0:
		return
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(5, 2)), Color("8d4e16"))
	draw_rect(Rect2(at + Vector2(0, 2), Vector2(7, 7)), OUTLINE)
	draw_rect(Rect2(at + Vector2(1, 3), Vector2(5, 5)), OINTMENT)
	draw_rect(Rect2(at + Vector2(2, 3), Vector2(1, 2)), Color("f7f1de"))
	var label := "x%d" % player.ointments
	PixelFont.draw(self, at + Vector2(10, 9), label, 10, OINTMENT, OUTLINE)
	if left > 0.0:
		var bar := Rect2(at + Vector2(0, 11), Vector2(30, 2))
		draw_rect(bar.grow(1), OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * left / Player.OINTMENT_TIME), bar.size.y)), OINTMENT)


## A War Glove in use (pass 147): a small red fist and the time it has left.
func _draw_glove(at: Vector2) -> void:
	var left := player.glove_left
	if left <= 0.0:
		return
	var red := Color("d0503a")
	draw_rect(Rect2(at + Vector2(0, 1), Vector2(7, 8)), OUTLINE)
	draw_rect(Rect2(at + Vector2(1, 2), Vector2(5, 4)), red)
	draw_rect(Rect2(at + Vector2(1, 6), Vector2(5, 2)), Color("f0c02e"))
	# The last three seconds blink, so the end isn't a surprise.
	if left > 3.0 or int(left * 6.0) % 2 == 0:
		var bar := Rect2(at + Vector2(10, 4), Vector2(30, 2))
		draw_rect(bar.grow(1), OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * left / player.combat.war_glove_time), bar.size.y)), red)


func _boss() -> Node:
	var b := get_tree().get_first_node_in_group("boss")
	return b if b != null and not b.is_queued_for_deletion() and b.state != "dead" else null


## How fast the pale trail behind the boss bar's red catches up a blow, as a
## share of the bar each second (design bible 8, pass 364).
const BOSS_TRAIL_SPEED := 0.5
## The boss bar's width (world px).
const BOSS_BAR_WIDTH := 320.0


## The boss bar as drawn (design bible 8): the guardian's name, its bar, the
## red fill (its health), the pale trail of a blow catching up behind it, and a
## gold tick at each mark where a phase begins. Empty with no guardian up.
func boss_bar() -> Dictionary:
	var b := _boss()
	if b == null:
		return {}
	var bar := Rect2((get_viewport_rect().size.x - BOSS_BAR_WIDTH) * 0.5, 340, BOSS_BAR_WIDTH, 6)
	var ticks: Array[float] = []
	for mark: float in b.PHASES:
		ticks.append(bar.position.x + roundf(bar.size.x * mark))
	return {"boss": b, "name": String(b.DISPLAY_NAME), "rect": bar, "fill": float(b.health_fraction()), "trail": _boss_shown, "ticks": ticks}


## Boss health bar along the bottom, with a tick at each phase threshold.
func _draw_boss() -> void:
	var bar_info := boss_bar()
	if bar_info.is_empty():
		_boss_shown = 1.0
		return
	var frac: float = bar_info.fill
	_boss_shown = move_toward(_boss_shown, frac, get_process_delta_time() * BOSS_TRAIL_SPEED)
	if _boss_shown < frac:
		_boss_shown = frac
	var bar: Rect2 = bar_info.rect
	PixelFont.draw(self, bar.position + Vector2(0, -4), bar_info.name, 10, MASK_FULL, OUTLINE)
	draw_rect(bar.grow(1), OUTLINE)
	draw_rect(bar, Color("3a1a22"))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _boss_shown), bar.size.y)), Color("f1ead2"))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * frac), bar.size.y)), Color("d8443a"))
	for x: float in bar_info.ticks:
		draw_rect(Rect2(x, bar.position.y - 2, 1, bar.size.y + 4), GOLD)


## Fades in fast, holds, fades out over the last half second.
static func _envelope(t_left: float, total: float) -> float:
	return clampf(minf((total - t_left) / 0.2, t_left / 0.5), 0.0, 1.0)


func _draw_messages() -> void:
	var w := get_viewport_rect().size.x
	if _banner_t > 0.0:
		var a := _envelope(_banner_t, BANNER_TIME)
		var band := Rect2(0, 96, w, 50 if _banner_sub != "" else 34)
		draw_rect(band, Color(0.07, 0.06, 0.11, 0.75 * a))
		draw_rect(Rect2(band.position, Vector2(w, 1)), Color(GOLD, 0.6 * a))
		draw_rect(Rect2(band.position + Vector2(0, band.size.y - 1), Vector2(w, 1)), Color(GOLD, 0.6 * a))
		_centered(_banner_title, 124, 18, Color(MASK_FULL, a))
		if _banner_sub != "":
			_centered(_banner_sub, 140, 10, Color(Color("c9b98f"), a))
	if _toast_t > 0.0:
		var a := _envelope(_toast_t, TOAST_TIME)
		_centered(_toast, 318 if _boss() != null else 330, 10, Color(MASK_FULL, a))


func _centered(text: String, y: float, size: int, color: Color) -> void:
	var w := get_viewport_rect().size.x
	var tw := PixelFont.width(text, size)
	var pos := Vector2(roundf((w - tw) * 0.5), y)
	PixelFont.draw(self, pos, text, size, color, Color(OUTLINE, color.a))


func _draw_rush() -> void:
	var title := "BOSS RUSH  %d/%d" % [mini(int(BossRush.run.index) + 1, BossRush.ORDER.size()), BossRush.ORDER.size()]
	var clock := Trials.format_time(float(BossRush.run.time))
	var best := BossRush.best()
	var sub := "BEST " + Trials.format_time(best) if best != INF else "FIRST RUSH"
	var w := maxf(PixelFont.width(title, 10), PixelFont.width(clock, 20)) + 20.0
	var x := get_viewport_rect().size.x * 0.5
	_draw_plate(Rect2(Vector2(x - w * 0.5, 6), Vector2(w, 46)))
	PixelFont.draw(self, Vector2(x - PixelFont.width(title, 10) * 0.5, 17), title, 10, MASK_FULL, OUTLINE)
	PixelFont.draw(self, Vector2(x - PixelFont.width(clock, 20) * 0.5, 37), clock, 20, MASK_FULL, OUTLINE)
	PixelFont.draw(self, Vector2(x - PixelFont.width(sub, 10) * 0.5, 49), sub, 10, GOLD, OUTLINE)
