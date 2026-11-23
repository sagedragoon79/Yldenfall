class_name ItemPickup
extends Node2D
## A permanent item lying in the world: an ability, Life Fruit, Mana Dew, a
## Potion Shard, a Grain Shard or a Stillglass Shard. Touch it to take it; it never comes back.

const KIND_BY_CHAR := {
	"G": "glove",
	"X": "boots",
	"O": "torrent",
	"d": "stride",
	"h": "thunder",
	":": "fracture",
	"n": "seers_lens",
	"z": "stillstone",
	"L": "life_fruit",
	"W": "mana_dew",
	"F": "potion_shard",
	"*": "grain_shard",
	"&": "severance",
	"{": "death",
	"(": "meteor_shard",
	"}": "rune_dagger",
}

const INFO := {
	"glove": {"title": "Climbing Glove", "text": "Slide down walls. Jump to leap off them.", "color": Color("c08a5a")},
	"torrent": {"title": "Deluge", "text": "A surging flood of water: douses fire seals and fills dry basins. Costs MP.", "color": Color("4aa3df")},
	"death": {"title": "Witherbloom", "text": "Blight blooms out in a ring and strikes every foe around you, through stone. Costs most of your MP.", "color": Color("8a4ad8")},
	"thunder": {"title": "Tempest Lance", "text": "A lance of lightning: it leaps to dead conduits and wakes them. Costs MP.", "color": Color("b8a8ff")},
	"fracture": {"title": "Lithic Fracture", "text": "A cascade of stone columns erupts along the floor, staggering and slowing what it strikes and shattering cracked stone seals. Costs MP.", "color": Color("9a8c7a")},
	"stride": {"title": "Elven Stride", "text": "Press Dash to stride: on the ground, or once in the air. Harm passes through you as you go.", "color": Color("6fd08a")},
	"stillstone": {"title": "Stillstone", "text": "Press Stillstone (T) to stop time for a moment: falling water freezes, and so do arrows and shards in flight.", "color": Color("e8c870")},
	"seers_lens": {"title": "Seer's Lens", "text": "Illusory walls shimmer at their seams, and hidden planks show faintly.", "color": Color("8a6ad8")},
	"boots": {"title": "Featherstep Boots", "text": "Jump again in mid-air. A pogo or a wall gives it back.", "color": Color("7fb0d8")},
	"life_fruit": {"title": "Life Fruit", "text": "", "color": Color("e0404a")},
	"mana_dew": {"title": "Mana Dew", "text": "", "color": Color("4aa3df")},
	"potion_shard": {"title": "Potion Shard", "text": "", "color": Color("ff6a6a")},
	"grain_shard": {"title": "Grain Shard", "text": "", "color": Color("b58cff")},
	"meteor_shard": {"title": "Stillglass Shard", "text": "", "color": Color("e04aa8")},
	"elven_helm": {"title": "Elven Helm", "text": "One more leaf, and 10% less damage on top of your armor. Your shield stays in hand.", "color": Color("a8d4cc")},
	"glass_key": {"title": "Glass Key", "text": "Opens the Glass door. There is only one.", "color": Color("9a6ad8")},
	"rune_dagger": {"title": "Rune Dagger", "text": "Throw (B) flicks it; Up throws it high. It comes back, so it never runs out. It is in your Projectile slot (Equipment).", "color": Color("7ff0e0")},
	"pendant": {"title": "Acorn Charm", "text": "An old charm of the Tree's folk. Your blade strikes a tenth harder.", "color": Color("e8c06a")},
	"briar_wand": {"title": "Briar Wand", "text": "Deluge's bolts strike half again as hard.", "color": Color("6ac8f0")},
	"severance": {"title": "Severance", "text": "The only blade that can wound the Everbloom. Stillglass flesh parts before it.", "color": Color("8af0e8")},
}

## Kinds that grant an ability rather than a stat.
const ABILITIES := ["glove", "boots", "torrent", "stride", "thunder", "fracture", "seers_lens", "stillstone", "death", "rune_dagger", "pendant", "briar_wand"]

var kind := "life_fruit"
var pickup_id := ""
## Abilities glow through the Haar's fog (group "light") so they are never missed.
var light_radius := 44.0

var _t := 0.0


func _ready() -> void:
	z_index = 1
	# The near layers thin in front of a pickup (Backdrop.REVEAL_GROUPS, design bible 12.121).
	add_to_group("pickup")
	if kind in ABILITIES or kind in ["severance", "elven_helm"]:
		add_to_group("light")


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead and not p.frozen and p.body_rect().grow(4.0).has_point(global_position):
		grant(p)
		return
	queue_redraw()


func grant(p: Player) -> void:
	var info: Dictionary = INFO[kind]
	var subtitle: String = info.text
	if kind in ABILITIES:
		p.abilities[kind] = true
		if Spells.DATA.has(kind) and not p.abilities.get(p.equipped_spell, false):
			p.equipped_spell = kind
		if kind == "rune_dagger" and String(GameState.data.equipment.get(GameState.PROJECTILE_PLACE, "")) == "":
			# It goes into the projectile slot (design bible 5.6); the shield stays on.
			GameState.data.equipment[GameState.PROJECTILE_PLACE] = kind
	elif kind == "severance":
		# Found, not bought: it goes straight into your hand (design bible 5.2, A10).
		p.abilities[kind] = true
		GameState.obtain_gear(kind, p)
	elif kind == "elven_helm":
		# Found, not bought: it goes straight on, in its own slot (bible 5.2).
		GameState.obtain_gear(kind, p)
		p.hp = p.max_hp
		p.health_changed.emit(p.hp, p.max_hp)
	elif kind == "glass_key":
		GameState.add_key("glass")
	else:
		subtitle = GameState.grant_stat_item(kind, p)
	if pickup_id != "":
		GameState.collect(pickup_id)
	GameState.capture(p)
	GameState.banner.emit(info.title, subtitle)
	Sfx.play("item", 0.0)
	Feel.hitstop(0.12)
	var d := Dust.new()
	d.setup("parry")
	get_parent().add_child(d)
	d.global_position = global_position
	queue_free()


## Drawn at 2x render density: _hp() and the polygons take half-pixels.
func _draw() -> void:
	var bob := roundf(sin(_t * 2.5) * 4.0) * 0.5
	var c: Color = INFO[kind].color
	var o := Vector2(0, bob)
	var dark := c.darkened(0.45)
	var light := c.lightened(0.45)
	# A soft halo and two twinkles orbiting it.
	draw_circle(o, 11.0 + sin(_t * 4.0), Color(c, 0.12))
	draw_circle(o, 7.5 + sin(_t * 4.0) * 0.5, Color(c, 0.1))
	for i in 2:
		var a := _t * 1.6 + i * PI
		var tw := o + Vector2(cos(a) * 10.0, sin(a) * 5.0 - 1.0)
		var k := 0.5 + 0.5 * sin(_t * 6.0 + i * 2.0)
		_hp(tw, -1, -3, 2, 6, Color(light, k))
		_hp(tw, -3, -1, 6, 2, Color(light, k))
	match kind:
		"glove":
			# A leather climbing gauntlet: four fingers, a thumb, a gold cuff, stitching.
			_poly(o, [Vector2(-10, -2), Vector2(10, -2), Vector2(10, 12), Vector2(-10, 12)], dark, 2.0)
			for i in 4:
				_hp(o, -10 + i * 5, -14 + (2 if i == 0 or i == 3 else 0), 5, 14, Color("120f19"))
				_hp(o, -9 + i * 5, -13 + (2 if i == 0 or i == 3 else 0), 3, 13, c)
				_hp(o, -9 + i * 5, -13 + (2 if i == 0 or i == 3 else 0), 1, 9, light)
			_hp(o, -9, -2, 18, 13, c)
			_hp(o, -9, 2, 18, 1, dark)
			_hp(o, -15, 0, 6, 9, Color("120f19"))
			_hp(o, -14, 1, 5, 7, c)
			_hp(o, -14, 1, 2, 5, light)
			_hp(o, -11, 10, 22, 6, Color("120f19"))
			_hp(o, -10, 11, 20, 4, Color("ffd24a"))
			_hp(o, -10, 11, 20, 1, Color("fff4c0"))
			_hp(o, -10, 14, 20, 1, Color("b8860b"))
			for i in 4:
				_hp(o, -7 + i * 4, 6, 2, 1, dark)
		"thunder":
			# A spell scroll bound in violet ribbon, a lightning glyph flickering on it.
			_poly(o, [Vector2(-12, -10), Vector2(12, -10), Vector2(12, 10), Vector2(-12, 10)], Color("120f19"), 2.0)
			_hp(o, -12, -10, 24, 20, Color("efe4c8"))
			_hp(o, -12, -10, 24, 2, Color("c9b98e"))
			_hp(o, -14, -12, 4, 24, dark)
			_hp(o, 10, -12, 4, 24, dark)
			var k := 0.5 + 0.5 * absf(sin(_t * 9.0))
			for seg: Array in [[2, -8, 3, 5], [-1, -3, 4, 2], [-1, -1, 3, 4], [-4, 3, 3, 5]]:
				_hp(o, seg[0], seg[1], seg[2], seg[3], Color(Color("e8c04a"), k))
		"death":
			# A spell scroll bound in black ribbon, a skull glyph breathing on it.
			_poly(o, [Vector2(-12, -10), Vector2(12, -10), Vector2(12, 10), Vector2(-12, 10)], Color("120f19"), 2.0)
			_hp(o, -12, -10, 24, 20, Color("e4dccc"))
			_hp(o, -12, -10, 24, 2, Color("b8ac90"))
			_hp(o, -14, -12, 4, 24, Color("2a1838"))
			_hp(o, 10, -12, 4, 24, Color("2a1838"))
			var k := 0.55 + 0.45 * sin(_t * 3.0)
			var g := Color(c.darkened(0.3), k)
			_hp(o, -5, -7, 10, 8, g)
			_hp(o, -3, 1, 6, 4, g)
			_hp(o, -3, -4, 2, 2, Color("e4dccc"))
			_hp(o, 1, -4, 2, 2, Color("e4dccc"))
			_hp(o, -1, 2, 2, 2, Color("e4dccc"))
		"torrent":
			# A spell scroll bound in blue ribbon, a wave glyph glowing on it.
			_poly(o, [Vector2(-12, -10), Vector2(12, -10), Vector2(12, 10), Vector2(-12, 10)], Color("120f19"), 2.0)
			_hp(o, -12, -10, 24, 20, Color("efe4c8"))
			_hp(o, -12, -10, 24, 2, Color("c9b98e"))
			_hp(o, -14, -12, 4, 24, Color("c9b98e"))
			_hp(o, 10, -12, 4, 24, Color("c9b98e"))
			_hp(o, -1, -10, 3, 20, dark)
			var k := 0.6 + 0.4 * sin(_t * 4.0)
			for i in 4:
				_hp(o, -9 + i * 5, -2 + (2 if i % 2 else 0), 4, 2, Color(c, k))
				_hp(o, -9 + i * 5, 3 + (2 if i % 2 else 0), 4, 2, Color(light, k))
		"fracture":
			# A spell scroll bound in stone-grey cord, a jagged fracture glyph lit
			# amber on it.
			_poly(o, [Vector2(-12, -10), Vector2(12, -10), Vector2(12, 10), Vector2(-12, 10)], Color("120f19"), 2.0)
			_hp(o, -12, -10, 24, 20, Color("e4ddd0"))
			_hp(o, -12, -10, 24, 2, Color("b4ac9c"))
			_hp(o, -14, -12, 4, 24, Color("3a3444"))
			_hp(o, 10, -12, 4, 24, Color("3a3444"))
			var k := 0.55 + 0.45 * sin(_t * 4.0)
			var amber := Color("e8c488")
			for seg: Array in [[-5, -7, 3, 4], [-3, -4, 3, 3], [-1, -2, 3, 4], [1, 1, 3, 3], [3, 3, 3, 4]]:
				_hp(o, seg[0], seg[1], seg[2], seg[3], Color(amber, k))
		"boots":
			# A messenger's boot, sky-blue leather with a gold cuff and a white
			# wing at the heel that flutters.
			var flap := roundf(sin(_t * 7.0) * 2.0)
			var wing := [Vector2(-6, -8), Vector2(-16, -14 - flap), Vector2(-20, -8 - flap), Vector2(-16, -4), Vector2(-8, -2)]
			_poly(o, wing, Color("120f19"), 2.0)
			_poly(o, wing, Color("e8f0f8"))
			for i in 3:
				_hp(o, -17 + i * 3, -9 - flap + i, 2, 1, Color("9fb6cc"))
			var boot := [Vector2(-7, -14), Vector2(3, -14), Vector2(3, 2), Vector2(13, 6), Vector2(13, 12), Vector2(-7, 12)]
			_poly(o, boot, Color("120f19"), 2.0)
			_poly(o, boot, dark)
			_poly(o + Vector2(-0.5, -0.5), [Vector2(-6, -13), Vector2(2, -13), Vector2(2, 3), Vector2(12, 7), Vector2(12, 9), Vector2(-6, 9)], c)
			_hp(o, -5, -12, 2, 18, light)
			_hp(o, -8, -16, 12, 4, Color("120f19"))
			_hp(o, -7, -15, 10, 2, Color("ffd24a"))
			_hp(o, -7, 10, 20, 3, Color("3a2a1a"))
		"stride":
			# An elven warden's feather, leaf-green, streaming wind lines behind it
			# as if it were already moving.
			var drift := roundf(sin(_t * 5.0) * 2.0)
			for i in 3:
				var k := 0.4 + 0.3 * sin(_t * 6.0 + i)
				_hp(o, -20 - i * 2 + drift, -6 + i * 6, 8 + i * 2, 2, Color(light, k))
			var vane := [Vector2(-10, 10), Vector2(-6, -2), Vector2(2, -12), Vector2(12, -16), Vector2(8, -6), Vector2(0, 4), Vector2(-8, 12)]
			_poly(o, vane, Color("120f19"), 2.0)
			_poly(o, vane, dark)
			_poly(o + Vector2(-0.5, -0.5), [Vector2(-8, 8), Vector2(-5, -2), Vector2(2, -11), Vector2(10, -15), Vector2(6, -6), Vector2(-1, 3)], c)
			# The quill down the middle, and a gold band at its root.
			for i in 7:
				_hp(o, -10 + i * 3, 10 - i * 4, 2, 2, light)
			_hp(o, -14, 12, 6, 4, Color("120f19"))
			_hp(o, -13, 13, 4, 2, Color("ffd24a"))
		"stillstone":
			# A dwarf-made hour glass in a brass frame, the sand caught mid-fall.
			var sand := fmod(_t * 0.4, 1.0)
			_poly(o, [Vector2(-10, -16), Vector2(10, -16), Vector2(10, 16), Vector2(-10, 16)], Color("120f19"), 2.0)
			_hp(o, -11, -17, 22, 4, Color("b8860b"))
			_hp(o, -11, 13, 22, 4, Color("b8860b"))
			_hp(o, -11, -17, 22, 1, Color("ffd24a"))
			_hp(o, -10, -13, 2, 26, Color("8a6a20"))
			_hp(o, 8, -13, 2, 26, Color("8a6a20"))
			var glass := Color("d8ecf0")
			_poly(o, [Vector2(-7, -13), Vector2(7, -13), Vector2(1, 0), Vector2(-1, 0)], Color(glass, 0.5))
			_poly(o, [Vector2(-1, 0), Vector2(1, 0), Vector2(7, 13), Vector2(-7, 13)], Color(glass, 0.5))
			var top_h := roundi(8.0 * (1.0 - sand))
			_hp(o, -4 + (8 - top_h) / 2, -12 + (8 - top_h), top_h, top_h, c)
			_hp(o, -1, -1, 2, 10, Color(c, 0.8))
			var bot_h := roundi(8.0 * sand)
			_hp(o, -5, 12 - bot_h, 10, bot_h, c)
			_hp(o, -5, -11, 2, 4, Color("ffffff"))
		"severance":
			# A long blade of pale stillglass steel, point down, a cyan light running
			# up its fuller; a dragon's-wing guard in gold and a dark grip.
			var run := fmod(_t * 0.8, 1.0)
			_poly(o, [Vector2(-3, -6), Vector2(3, -6), Vector2(3, 18), Vector2(0, 24), Vector2(-3, 18)], Color("120f19"), 2.0)
			_poly(o, [Vector2(-2, -6), Vector2(2, -6), Vector2(2, 18), Vector2(0, 23), Vector2(-2, 18)], Color("d8e8f0"))
			_hp(o, -2, -6, 1, 24, Color("ffffff"))
			_hp(o, 0, -4, 1, 22, Color("7a98a8"))
			_hp(o, 0, -4 + roundi(20.0 * (1.0 - run)), 1, 4, c)
			# A plain trapezoid: a grown outline of anything more jagged fails to triangulate.
			var guard := [Vector2(-12, -10), Vector2(12, -10), Vector2(8, -5), Vector2(-8, -5)]
			_poly(o, guard, Color("120f19"), 2.0)
			_poly(o, guard, Color("ffd24a"))
			_hp(o, -8, -9, 16, 1, Color("fff4c0"))
			_hp(o, -2, -18, 4, 9, Color("120f19"))
			_hp(o, -1, -17, 2, 7, Color("4a2a3a"))
			_hp(o, -3, -21, 6, 4, Color("120f19"))
			_hp(o, -2, -20, 4, 2, c)
		"seers_lens":
			# A black stone cut in facets, a violet light sliding over it as it turns.
			var spin := sin(_t * 2.0)
			var wx := 9.0 + absf(spin) * 2.0
			var gem := [Vector2(-wx * 0.6, -12), Vector2(wx * 0.6, -12), Vector2(wx, -4), Vector2(0, 14), Vector2(-wx, -4)]
			_poly(o, gem, Color("e8dcff") if fmod(_t, 2.4) < 0.08 else Color("120f19"), 2.0)
			_poly(o, gem, Color("1c1828"))
			var mid := spin * wx * 0.5
			_poly(o, [Vector2(-wx * 0.6, -12), Vector2(wx * 0.6, -12), Vector2(wx, -4), Vector2(-wx, -4)], Color("2e2840"))
			_poly(o, [Vector2(mid - 3, -12), Vector2(mid + 3, -12), Vector2(mid + 4, -4), Vector2(0, 14), Vector2(mid - 4, -4)], Color(c, 0.55))
			_hp(o, -int(wx * 0.6) + 2, -11, 4, 2, Color("e8dcff"))
			_hp(o, int(mid) - 1, -3, 2, 6, Color(light, 0.8))
		"life_fruit":
			# A red fruit of the Tree: shaded crescent, highlight, stem and leaf.
			var f := o + Vector2(0, 1)
			draw_circle(f, 6.5, Color("120f19"))
			draw_circle(f, 5.5, dark)
			draw_circle(f + Vector2(-0.5, -0.5), 4.8, c)
			draw_circle(f + Vector2(-1.5, -1.5), 2.6, c.lightened(0.15))
			_hp(f, -5, -6, 3, 2, Color("ffd0d0"))
			_hp(f, -6, -4, 2, 3, Color("ffd0d0"))
			_hp(f, 5, 5, 3, 2, Color(dark.darkened(0.3), 0.8))
			_hp(f, -1, -16, 2, 6, Color("5e3b22"))
			_poly(f, [Vector2(1, -15), Vector2(6, -18), Vector2(11, -16), Vector2(6, -12)], Color("3f6a32"), 1.5)
			_poly(f, [Vector2(1, -15), Vector2(6, -18), Vector2(11, -16), Vector2(6, -12)], Color("5f8a4a"))
			_hp(f, 3, -15, 6, 1, Color("8fbf6a"))
		"mana_dew":
			# A drop of the Tree's dew: three tones and a bright glint.
			var drop := [Vector2(0, -16), Vector2(5, -6), Vector2(9, 2), Vector2(8, 8), Vector2(4, 12), Vector2(-4, 12), Vector2(-8, 8), Vector2(-9, 2), Vector2(-5, -6)]
			_poly(o, drop, Color("120f19"), 2.0)
			_poly(o, drop, dark)
			_poly(o + Vector2(-0.5, -0.5), drop, c, -2.0)
			_poly(o + Vector2(-1.5, -0.5), [Vector2(0, -10), Vector2(3, -3), Vector2(4, 4), Vector2(-4, 4), Vector2(-3, -3)], light)
			_hp(o, -5, 0, 2, 5, Color("e8f8ff"))
			_hp(o, -3, -6, 2, 3, Color("e8f8ff"))
		"potion_shard":
			# A curved shard of a Sapflask flask, a bead of potion still in it.
			var shard := [Vector2(-4, -15), Vector2(7, -7), Vector2(5, 11), Vector2(-2, 13), Vector2(-8, 5)]
			_poly(o, shard, Color("120f19"), 2.0)
			_poly(o, shard, Color("c9c4d6"))
			_poly(o + Vector2(0.5, 1), [Vector2(-5, 0), Vector2(5, -2), Vector2(4, 9), Vector2(-2, 11), Vector2(-6, 5)], c)
			_poly(o + Vector2(0.5, 1), [Vector2(-5, 0), Vector2(5, -2), Vector2(4, 1), Vector2(-5, 3)], light)
			_hp(o, -4, -12, 2, 8, Color("f7f1de"))
			_hp(o, 3, 6, 2, 3, dark)
		"grain_shard":
			# A violet crystal turning slowly: the lit facet sweeps across it.
			var spin := sin(_t * 3.0)
			var wx := 6.0 + absf(spin) * 3.0
			var gem := [Vector2(0, -17), Vector2(wx, -2), Vector2(0, 17), Vector2(-wx, -2)]
			_poly(o, gem, Color("120f19"), 2.0)
			_poly(o, gem, dark)
			var mid := spin * wx * 0.6
			_poly(o, [Vector2(0, -17), Vector2(mid, -2), Vector2(0, 17), Vector2(-wx, -2)], c)
			_poly(o, [Vector2(0, -17), Vector2(mid, -2), Vector2(-wx, -2)], light)
			_hp(o, -2, -9, 2, 5, Color("efe4ff"))
		"meteor_shard":
			# A splinter of the Everbloom: three jagged magenta spurs from a black rock
			# heel, a cyan light beating in the crack between them like the Evercrown's heart.
			var beat := 0.5 + 0.5 * sin(_t * 5.0)
			var rock := [Vector2(-9, 8), Vector2(-5, 13), Vector2(6, 13), Vector2(10, 7), Vector2(2, 4)]
			_poly(o, rock, Color("120f19"), 2.0)
			_poly(o, rock, Color("2a1f33"))
			var spurs := [
				[Vector2(-8, 7), Vector2(-11, -6), Vector2(-4, 4)],
				[Vector2(-4, 6), Vector2(1, -18), Vector2(5, 5)],
				[Vector2(3, 6), Vector2(10, -8), Vector2(9, 6)],
			]
			for s: Array in spurs:
				_poly(o, s, Color("120f19"), 2.0)
			for s: Array in spurs:
				_poly(o, s, c)
				_poly(o, [s[0], s[1], (s[0] + s[2]) * 0.5], dark)
			_hp(o, 0, -13, 2, 12, light)
			_hp(o, -1, 2, 3, 7, Color(Color("8af0e8"), 0.55 + 0.45 * beat))
			_hp(o, 0, 3, 1, 5, Color("e8fffc"))
		"elven_helm":
			# The elf kings' war-helm (Sean's reference): sea-green steel, a domed crown,
			# cheek guards, an eye slit under a gold brow band, swept wings and cyan runes.
			var helm := [Vector2(-11, 12), Vector2(-12, -2), Vector2(-8, -11), Vector2(0, -14), Vector2(8, -11), Vector2(12, -2), Vector2(11, 12), Vector2(5, 12), Vector2(4, 4), Vector2(-4, 4), Vector2(-5, 12)]
			for side in [-1, 1]:
				var wing := [Vector2(10 * side, -8), Vector2(20 * side, -18), Vector2(17 * side, -9), Vector2(21 * side, -11), Vector2(12 * side, -1)]
				_poly(o, wing, Color("120f19"), 1.5)
				_poly(o, wing, Color("d8f0ea"))
			_poly(o, helm, Color("120f19"), 2.0)
			_poly(o, helm, dark)
			_poly(o + Vector2(-1, -1), [Vector2(-10, 2), Vector2(-10, -3), Vector2(-7, -10), Vector2(0, -12), Vector2(7, -10), Vector2(10, -3), Vector2(10, 2)], c)
			_hp(o, -8, -9, 3, 8, light)
			_hp(o, -9, -1, 18, 3, Color("120f19"))
			_hp(o, -10, -4, 20, 2, Color("c8a850"))
			_hp(o, -5, 4, 1, 8, Color("c8a850"))
			_hp(o, 4, 4, 1, 8, Color("c8a850"))
			_hp(o, -1, -13, 2, 9, light)
			var glint := Color(Color("7ff0e0"), 0.6 + 0.4 * sin(_t * 4.0))
			_hp(o, -7, -8, 2, 1, glint)
			_hp(o, 5, -8, 2, 1, glint)
		"rune_dagger":
			# A slim elven throwing dagger, point down, a cyan rune pulsing on the
			# blade; a short crossguard and a wrapped grip with a ring pommel.
			var k := 0.55 + 0.45 * sin(_t * 5.0)
			_poly(o, [Vector2(-3, -2), Vector2(3, -2), Vector2(3, 12), Vector2(0, 18), Vector2(-3, 12)], Color("120f19"), 2.0)
			_poly(o, [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 12), Vector2(0, 17), Vector2(-2, 12)], Color("dfe6ee"))
			_hp(o, -2, -2, 1, 15, Color("ffffff"))
			_hp(o, 1, -1, 1, 14, Color("8a94a8"))
			_hp(o, -1, 2, 2, 2, Color(c, k))
			_hp(o, -1, 7, 2, 2, Color(c, k))
			_hp(o, -8, -6, 16, 4, Color("120f19"))
			_hp(o, -7, -5, 14, 2, Color("b8c4d0"))
			_hp(o, -2, -15, 4, 10, Color("120f19"))
			_hp(o, -1, -14, 2, 8, Color("5a4028"))
			_hp(o, -1, -12, 2, 1, Color("8a6a40"))
			_hp(o, -1, -9, 2, 1, Color("8a6a40"))
			draw_circle(o + Vector2(0, -9), 2.5, Color("120f19"))
			draw_circle(o + Vector2(0, -9), 1.5, Color(c, k))
		"glass_key":
			# A violet key: a star in its bow, two teeth on its bit.
			_hp(o, -2, -4, 4, 18, Color("120f19"))
			_hp(o, -1, -3, 2, 16, c)
			_hp(o, 1, 6, 6, 3, Color("120f19"))
			_hp(o, 1, 11, 5, 3, Color("120f19"))
			_hp(o, 1, 7, 5, 1, c)
			_hp(o, 1, 12, 4, 1, c)
			draw_circle(o + Vector2(0, -9), 8.0, Color("120f19"))
			draw_circle(o + Vector2(0, -9), 6.5, c)
			draw_circle(o + Vector2(0, -9), 4.5, dark)
			var star := []
			for i in 10:
				var r := 4.0 if i % 2 == 0 else 1.8
				star.append(Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
			_poly(o + Vector2(0, -9), star, Color("ffe08a"))
			_hp(o, -4, -14, 2, 2, light)
		"pendant":
			# A gold locket on a fine chain, a green leaf-stone set in it that
			# catches the light now and then.
			for i in 7:
				var a := PI * (0.15 + 0.7 * i / 6.0)
				_hp(o, cos(a) * 9.0 - 1, -sin(a) * 9.0 - 9, 2, 2, Color("8a6a3a"))
			var drop := [Vector2(0, -8), Vector2(7, -2), Vector2(6, 6), Vector2(0, 11), Vector2(-6, 6), Vector2(-7, -2)]
			_poly(o, drop, Color("120f19"), 2.0)
			_poly(o, drop, c)
			_poly(o, [Vector2(0, -8), Vector2(7, -2), Vector2(0, 1), Vector2(-7, -2)], light)
			var glint := Color("e8ffd8") if fmod(_t, 2.2) < 0.1 else Color("4fae6a")
			draw_circle(o + Vector2(0, 0.75), 1.6, Color("1e4a2a"))
			draw_circle(o + Vector2(0, 0.5), 1.1, glint)
			_hp(o, -4, -3, 2, 2, Color("fff4c0"))
		"briar_wand":
			# A slim wand of pale Tree-wood with a water-blue orb at its head and a
			# drop of light rising off it.
			var rod := [Vector2(-1, -6), Vector2(2, -6), Vector2(3, 18), Vector2(0, 20)]
			_poly(o, rod, Color("120f19"), 2.0)
			_poly(o, rod, Color("c8a878"))
			_hp(o, 2, -4, 1, 22, Color("8a6a4a"))
			_hp(o, -2, 2, 6, 2, Color("e8c06a"))
			draw_circle(o + Vector2(0.25, -5.5), 4.0, Color("120f19"))
			draw_circle(o + Vector2(0.25, -5.5), 3.2, dark)
			draw_circle(o + Vector2(0, -5.75), 2.5, c)
			_hp(o, -3, -14, 2, 2, Color("e8f8ff"))
			var rise := fmod(_t * 0.8, 1.0)
			draw_circle(o + Vector2(0.25, -10 - rise * 5.0), 0.8, Color(light, 1.0 - rise))


func _hp(at: Vector2, x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(at + Vector2(x, y) * 0.5, Vector2(w, h) * 0.5), col)


## A polygon in half-pixels around `at`, grown outward by `grow` half-pixels.
func _poly(at: Vector2, pts: Array, col: Color, grow := 0.0) -> void:
	var center := Vector2.ZERO
	for p: Vector2 in pts:
		center += p
	center /= pts.size()
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(at + (p + (p - center).normalized() * grow) * 0.5)
	draw_colored_polygon(out, col)
