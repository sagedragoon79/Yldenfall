class_name Chest
extends Interactable
## A treasure chest. Press Up to open it; gold sprays out. Stays open for good.
##
## Each zone houses its treasure in its own kind of chest (pass 595, bible
## 12.80), the way each zone carves its own stele (12.31): the pass 585 grade
## saw "the same chest ... in nearly every room". A root-wood coffer grown over
## with moss and roots in the Heartwood, a woven hamper in the High Boughs, a
## grey driftwood sea chest with a rope handle and barnacles in the Haar, a
## squared dwarf strongbox with a glowing rune plate under the Hearthroot, in
## the Sunken Spring and in Vorrhallow, an iron-strapped ore crate in the Tower,
## a sandstone reliquary with a pitched roof in the Spires, a crystal-studded
## geode casket in the Evercrown, and the plain domed trunk in the gym and the
## Trials. Every tone is a master palette value (art/palette/master.json).
##
## Drawn at 2x render density: every part is in half-pixels.

const KINDS := ["trunk", "coffer", "hamper", "sea_chest", "strongbox", "crate", "reliquary", "geode"]

## Per-zone chest. `kind` picks the build; `out` the outline; `dark`, `mid`,
## `lit` the body's ramp; `band`, `band_lit` the metal (or strap) and its
## light; `iron`, `iron_lit` corner fittings; `glow` the lock's light.
const LOOKS := {
	"gym": {"kind": "trunk", "out": "120f19", "dark": "432d23", "mid": "6e5135", "lit": "9c7f44", "band": "cb8d16", "band_lit": "f0c02e", "iron": "4a465d", "iron_lit": "645e82", "glow": "edce6e"},
	"trials": {"kind": "trunk", "out": "120f19", "dark": "432d23", "mid": "6e5135", "lit": "9c7f44", "band": "cb8d16", "band_lit": "f0c02e", "iron": "4a465d", "iron_lit": "645e82", "glow": "edce6e"},
	"heartwood": {"kind": "coffer", "out": "1c0d0f", "dark": "48201e", "mid": "783c2b", "lit": "aa6336", "band": "cb8d16", "band_lit": "f0c02e", "iron": "542512", "iron_lit": "8d4e16", "glow": "f0c02e"},
	"boughs": {"kind": "hamper", "out": "121613", "dark": "6e5135", "mid": "9c7f44", "lit": "ccbe8e", "band": "2b782c", "band_lit": "49aa36", "iron": "1e4825", "iron_lit": "2b782c", "glow": "f7f1de"},
	"haar": {"kind": "sea_chest", "out": "181111", "dark": "58544c", "mid": "797767", "lit": "989885", "band": "4f5c47", "band_lit": "728061", "iron": "aa9173", "iron_lit": "d6cec2", "glow": "d6cec2"},
	"hearthroot": {"kind": "strongbox", "out": "131217", "dark": "2f2c3a", "mid": "4a465d", "lit": "645e82", "band": "8d4e16", "band_lit": "cb8d16", "iron": "2f2c3a", "iron_lit": "867ba2", "glow": "f0c02e"},
	"sunken": {"kind": "strongbox", "out": "161413", "dark": "363330", "mid": "58544c", "lit": "797767", "band": "2b5278", "band_lit": "3677aa", "iron": "363330", "iron_lit": "989885", "glow": "84cbd6"},
	"vorrhallow": {"kind": "strongbox", "out": "161413", "dark": "363330", "mid": "58544c", "lit": "797767", "band": "712b78", "band_lit": "a736aa", "iron": "363330", "iron_lit": "989885", "glow": "cd51c5"},
	"tower": {"kind": "crate", "out": "131217", "dark": "542512", "mid": "8d4e16", "lit": "aa6336", "band": "2f2c3a", "band_lit": "645e82", "iron": "4a465d", "iron_lit": "867ba2", "glow": "edce6e"},
	"spires": {"kind": "reliquary", "out": "1a100f", "dark": "432d23", "mid": "6e5135", "lit": "9c7f44", "band": "bea860", "band_lit": "f0dfa8", "iron": "432d23", "iron_lit": "bea860", "glow": "f0dfa8"},
	"evercrown": {"kind": "geode", "out": "120f19", "dark": "2c2541", "mid": "44386b", "lit": "5d4997", "band": "2b5278", "band_lit": "51a5cd", "iron": "51a5cd", "iron_lit": "b5e3e1", "glow": "84cbd6"},
}

## Shared tones: the dark inside of an open chest, and moss.
const INSIDE := "200b09"
const MOSS_LIT := "49aa36"
const MOSS_DARK := "2b782c"

## Every part stays inside this box (half-pixels, feet at y = 0).
const BOUNDS := Rect2(-28, -52, 56, 52)

var pickup_id := ""
var value := 100
## The room's zone: picks the chest's look. Set before the chest is added.
var zone := ""

var _open := false
var _parts_open := -1
var _parts: Array = []
var _rim: Array = []
var _spots: Array = []


func _ready() -> void:
	super()
	prompt_height = 26.0
	z_index = -1
	if pickup_id != "" and GameState.is_collected(pickup_id):
		_open = true
		remove_from_group("interactable")


func interact(_p: Player) -> void:
	if _open:
		return
	_open = true
	remove_from_group("interactable")
	if pickup_id != "":
		GameState.collect(pickup_id)
	Coin.spray(get_parent(), global_position + Vector2(0, -12), value)
	Sfx.play("chest", 0.0)
	Feel.hitstop(0.05)
	var d := Dust.new()
	d.setup("parry")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -12)


func is_open() -> bool:
	return _open


## The look for `z`, or the plain trunk for an unknown zone.
static func look_for(z: String) -> Dictionary:
	return LOOKS.get(z, LOOKS["gym"])


## The chest as data: [[x, y, w, h, hex], ...] in half-pixels, drawn in order.
## The lock's pulsing light is drawn over it by `_draw`, at `KEYHOLE`.
static func parts(look: Dictionary, open: bool) -> Array:
	var p: Array = []
	var kind := String(look["kind"])
	var o: String = look["out"]
	var dk: String = look["dark"]
	var md: String = look["mid"]
	var lt: String = look["lit"]
	var bd: String = look["band"]
	var bl: String = look["band_lit"]
	var ir: String = look["iron"]
	var il: String = look["iron_lit"]

	# The body.
	match kind:
		"hamper":
			# Woven wicker, a touch wider at the rim than the foot.
			for y in range(-25, 0):
				var hw := 21 - floori((y + 25) / 9.0)
				p.append([-hw, y, hw * 2, 1, o])
			for y in range(-23, -1):
				var hw := 19 - floori((y + 25) / 9.0)
				p.append([-hw, y, hw * 2, 1, md])
			# Strands: a dark gap under each row, stitches staggered row to row.
			for r in 7:
				var y0 := -23 + r * 3
				var hw := 19 - floori((y0 + 27) / 9.0)
				p.append([-hw, y0 + 2, hw * 2, 1, dk])
				p.append([-hw, y0, hw * 2, 1, lt])
				var x := -hw + (2 if r % 2 == 1 else 0)
				while x < hw - 1:
					p.append([x, y0, 1, 2, dk])
					x += 4
			# A leaf strap down the front.
			p.append([-3, -23, 6, 21, bd])
			p.append([-3, -23, 1, 21, bl])
		"strongbox":
			# Squared dwarf stone, its blocks seamed and riveted.
			p.append([-21, -25, 42, 25, o])
			p.append([-19, -23, 38, 22, md])
			p.append([-19, -23, 38, 1, lt])
			p.append([-19, -12, 38, 1, dk])
			p.append([-8, -22, 1, 10, dk])
			p.append([7, -11, 1, 10, dk])
			p.append([-19, -3, 38, 2, dk])
			p.append([-19, -16, 38, 3, bd])
			p.append([-19, -16, 38, 1, bl])
			for x: int in [-17, 15]:
				for y: int in [-21, -8]:
					p.append([x, y, 2, 2, il])
		"crate":
			# An ore crate: boards across, iron straps standing up its face.
			p.append([-21, -25, 42, 25, o])
			p.append([-19, -23, 38, 22, md])
			for i in 4:
				p.append([-19, -23 + i * 6, 38, 1, lt])
				if i < 3:
					p.append([-19, -18 + i * 6, 38, 1, dk])
			for x: int in [-15, 11]:
				p.append([x, -23, 4, 22, bd])
				p.append([x, -23, 1, 22, bl])
				p.append([x + 1, -20, 2, 2, il])
				p.append([x + 1, -6, 2, 2, il])
			# A stencilled ore mark.
			p.append([-7, -9, 3, 3, dk])
			p.append([4, -9, 3, 3, dk])
		"reliquary":
			# Sandstone with a carved arcade along its face.
			p.append([-21, -25, 42, 25, o])
			p.append([-19, -23, 38, 22, md])
			p.append([-19, -23, 38, 1, lt])
			p.append([-19, -4, 38, 3, dk])
			p.append([-19, -4, 38, 1, bd])
			for x: int in [-16, -10, 6, 12]:
				p.append([x, -19, 4, 13, dk])
				p.append([x + 1, -20, 2, 1, dk])
				p.append([x, -19, 1, 13, o])
		"geode":
			# A rough stone casket, its seams lit with crystal.
			p.append([-21, -25, 42, 25, o])
			p.append([-19, -23, 38, 22, md])
			p.append([-19, -23, 38, 1, lt])
			p.append([-19, -10, 38, 2, dk])
			p.append([-15, -20, 6, 1, bd])
			p.append([-15, -19, 1, 4, bd])
			p.append([10, -18, 1, 5, bd])
			p.append([10, -18, 5, 1, bl])
			p.append([-19, -3, 38, 2, dk])
		_:
			# Planks with grain, iron corners, a metal band: the trunk, the
			# root coffer and the sea chest.
			p.append([-21, -25, 42, 25, o])
			p.append([-19, -23, 38, 22, md])
			for i in 3:
				p.append([-19, -21 + i * 7, 38, 1, dk])
			p.append([-19, -23, 38, 1, lt])
			p.append([-19, -14, 38, 4, bd])
			p.append([-19, -14, 38, 1, bl])
			for x: int in [-19, 15]:
				p.append([x, -23, 4, 22, ir])
				p.append([x + 1, -21, 2, 2, il])
				p.append([x + 1, -6, 2, 2, il])
			if kind == "sea_chest":
				# Salt-greyed boards split along the grain.
				p.append([-11, -20, 7, 1, dk])
				p.append([4, -6, 8, 1, dk])

	# The lid.
	if open:
		# Thrown back, the inside dark with a glint of what was left.
		p.append([-21, -40, 42, 11, o])
		p.append([-19, -38, 38, 8, dk])
		p.append([-19, -38, 38, 1, md])
		p.append([-17, -29, 34, 4, INSIDE])
		p.append([-9, -28, 2, 1, bl])
		p.append([5, -27, 2, 1, bd])
	else:
		match kind:
			"strongbox":
				# A heavy flat lid, its cornice overhanging the box.
				p.append([-23, -32, 46, 8, o])
				p.append([-21, -30, 42, 4, lt])
				p.append([-21, -27, 42, 2, bd])
				p.append([-21, -27, 42, 1, bl])
				p.append([-19, -34, 38, 2, o])
				p.append([-17, -33, 34, 1, md])
			"crate":
				p.append([-22, -30, 44, 6, o])
				p.append([-20, -28, 40, 3, md])
				p.append([-20, -28, 40, 1, lt])
				for x: int in [-15, 11]:
					p.append([x, -28, 4, 3, bd])
			"hamper":
				# A flat woven lid and a bent-cane loop handle.
				p.append([-23, -30, 46, 6, o])
				p.append([-21, -28, 42, 3, md])
				p.append([-21, -28, 42, 1, lt])
				var x := -20
				while x < 20:
					p.append([x, -27, 1, 1, dk])
					x += 3
				p.append([-6, -36, 12, 2, o])
				p.append([-6, -36, 2, 6, o])
				p.append([4, -36, 2, 6, o])
				p.append([-4, -35, 8, 1, lt])
			"reliquary":
				# A pitched roof, lit down its west slope, a gold finial at its peak.
				for r in 7:
					var y := -38 + r * 2
					var hw := 5 + r * 3
					p.append([-hw - 2, y, hw * 2 + 4, 2, o])
				for r in 6:
					var y := -36 + r * 2
					var hw := 5 + r * 3
					p.append([-hw, y, hw * 2, 2, md])
					p.append([-hw, y, 3, 1, lt])
				p.append([-23, -26, 46, 2, bd])
				p.append([-23, -26, 46, 1, bl])
				p.append([-1, -43, 2, 5, bd])
				p.append([-2, -44, 4, 2, bl])
			_:
				# The domed lid.
				p.append([-21, -33, 42, 9, o])
				p.append([-19, -31, 38, 7, md])
				p.append([-17, -33, 34, 2, o])
				p.append([-17, -31, 34, 1, lt])
				p.append([-19, -25, 38, 1, dk])
				for x: int in [-19, 15]:
					p.append([x, -31, 4, 7, ir])
				if kind == "geode":
					# Crystal shards grown up through the lid.
					for s: Array in [[-13, 5, 9], [-3, 6, 14], [8, 4, 8]]:
						var sx: int = s[0]
						var sw: int = s[1]
						var sh: int = s[2]
						for r in sh:
							var w := maxi(1, sw - floori(r * sw / float(sh)))
							var top := -33 - r
							p.append([sx - 1, top - 1, w + 2, 1, o])
							p.append([sx, top, w, 1, bd if r < sh / 2 else bl])
						p.append([sx, -34 - sh + 1, 1, 1, il])
		# The lock plate.
		p.append([-4, -26, 8, 9, o])
		p.append([-3, -25, 6, 7, bd])
		p.append([-3, -25, 6, 1, bl])

	# What the zone grows on it.
	match kind:
		"coffer":
			# Roots coil round its feet; moss sits along the lid.
			p.append([-25, -5, 5, 2, o])
			p.append([-26, -3, 3, 3, o])
			p.append([-24, -4, 3, 1, ir])
			p.append([20, -8, 5, 2, o])
			p.append([23, -6, 3, 6, o])
			p.append([21, -7, 3, 1, ir])
			p.append([24, -5, 1, 4, il])
			var top := -40 if open else -33
			p.append([-16, top - 1, 11, 2, MOSS_DARK])
			p.append([-15, top - 1, 8, 1, MOSS_LIT])
			p.append([4, top - 1, 9, 2, MOSS_DARK])
			p.append([5, top - 1, 5, 1, MOSS_LIT])
			p.append([-12, top + 1, 2, 2, MOSS_DARK])
			p.append([9, top + 1, 1, 3, MOSS_DARK])
		"sea_chest":
			# A rope handle on its side; barnacles crusted along its foot.
			p.append([-25, -19, 4, 1, ir])
			p.append([-26, -18, 1, 6, ir])
			p.append([-25, -12, 4, 1, ir])
			p.append([-25, -18, 1, 1, il])
			for b: Array in [[-16, -4], [-12, -3], [-9, -5], [9, -4], [13, -3]]:
				p.append([b[0], b[1], 2, 2, o])
				p.append([b[0], b[1], 1, 1, il])
	return p


## Where the lock's pulsing light sits, in half-pixels.
const KEYHOLE := Rect2(-1, -23, 2, 3)


## How far the halo behind a closed chest reaches, in pixels.
const HALO_RADIUS := 22.0
## How many spots along the lid glint in turn.
const GLINTS := 3


## The top half-pixel of every column of the closed chest: where its accent
## rims it (12.106).
static func rim(look: Dictionary) -> Array:
	return Standout.top_cells(parts(look, false))


## A chest stands out until it is opened: the halo, the rim and the glint all
## go with the gold.
func stands_out() -> bool:
	return not _open


func _draw() -> void:
	var look := look_for(zone)
	var glow := Color(String(look["glow"]))
	if stands_out():
		Standout.draw_halo(self, Vector2(0, -9), HALO_RADIUS, glow, t)
	var key := 1 if _open else 0
	if key != _parts_open:
		_parts_open = key
		_parts = parts(look, _open)
		_rim = rim(look)
		_spots = Standout.glint_spots(_rim, GLINTS)
	for q: Array in _parts:
		_px(q[0], q[1], q[2], q[3], Color(String(q[4])))
	if stands_out():
		for c: Vector2i in _rim:
			_px(c.x, c.y, 1, 1, glow)
		var k := 0.6 + 0.4 * sin(t * 4.0)
		_px(int(KEYHOLE.position.x), int(KEYHOLE.position.y), int(KEYHOLE.size.x), int(KEYHOLE.size.y), Color(glow, k))
		var g := Standout.glint_at(t, _spots.size())
		if int(g[0]) >= 0:
			Standout.draw_glint(self, Vector2(_spots[int(g[0])]) * 0.5, int(g[1]))
	draw_prompt()


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x * 0.5, y * 0.5, w * 0.5, h * 0.5), color)
