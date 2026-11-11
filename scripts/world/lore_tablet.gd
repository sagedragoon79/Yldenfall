class_name LoreTablet
extends Interactable
## A carved stone sign. Press Up to read it. The face carries engraved runes:
## short grooved strokes — upright stems, cross-ticks, bars and dots — laid in
## two or three lines, seeded from the sign's own text so each sign carves its
## own marks instead of the same filler scribble (pass 512).
##
## Each zone carves its own stele (pass 539, bible 12.31): a round-topped root-
## wood marker in the Heartwood, a sloping, chipped waystone in the Haar, a
## gabled ochre stele in the Spires, a dwarf runestone with a metal cornice band
## under the Hearthroot, a tapering crystal shard in the Evercrown. Every tone
## is a master palette value (art/palette/master.json).

## The inner writing area in local space, inside the stele's recessed panel.
## Every rune stroke stays within it. The plinth fills the 3 rows below it.
const FACE := Rect2(-6, -19, 12, 15)
## The plinth the stele stands on: wider than the stone, on the ground line.
const PLINTH := Rect2(-10, -3, 20, 3)

## Silhouettes. Each is a column profile (see `profile`).
const SHAPES := ["arch", "gable", "waystone", "runestone", "shard"]

## Per-zone stele. `shape` picks the silhouette; `out`, `dark`, `mid`, `lit`
## the stone ramp (outline to top light); `face` the recessed panel; `glyph`
## and `glyph_shade` the inlay; `moss` a moss cap; `band` a metal cornice band
## (runestone); `tip` a lit crystal tip (shard).
const LOOKS := {
	"gym": {"shape": "arch", "out": "131217", "dark": "2f2c3a", "mid": "645e82", "lit": "867ba2", "face": "4a465d", "glyph": "edce6e", "glyph_shade": "cb8d16"},
	"heartwood": {"shape": "arch", "out": "1c0d0f", "dark": "48201e", "mid": "783c2b", "lit": "aa6336", "face": "48201e", "glyph": "f0c02e", "glyph_shade": "cb8d16", "moss": true},
	"boughs": {"shape": "arch", "out": "121613", "dark": "2f392d", "mid": "4f5c47", "lit": "728061", "face": "2f392d", "glyph": "ddd6bb", "glyph_shade": "b2b8a2", "moss": true},
	"hearthroot": {"shape": "runestone", "out": "131217", "dark": "2f2c3a", "mid": "4a465d", "lit": "645e82", "face": "2f2c3a", "glyph": "f0c02e", "glyph_shade": "cb8d16", "band": "8d4e16"},
	"haar": {"shape": "waystone", "out": "181111", "dark": "3c2c2a", "mid": "634a41", "lit": "8a6e56", "face": "3c2c2a", "glyph": "d6cec2", "glyph_shade": "aa9173", "moss": true},
	"sunken": {"shape": "runestone", "out": "161413", "dark": "363330", "mid": "58544c", "lit": "797767", "face": "363330", "glyph": "84cbd6", "glyph_shade": "3677aa", "band": "2b5278"},
	"spires": {"shape": "gable", "out": "1a100f", "dark": "432d23", "mid": "6e5135", "lit": "9c7f44", "face": "432d23", "glyph": "f0dfa8", "glyph_shade": "bea860"},
	"vorrhallow": {"shape": "runestone", "out": "161413", "dark": "363330", "mid": "58544c", "lit": "797767", "face": "363330", "glyph": "cd51c5", "glyph_shade": "a736aa", "band": "712b78"},
	"trials": {"shape": "gable", "out": "131217", "dark": "2f2c3a", "mid": "645e82", "lit": "867ba2", "face": "4a465d", "glyph": "edce6e", "glyph_shade": "cb8d16"},
	"tower": {"shape": "gable", "out": "131217", "dark": "2f2c3a", "mid": "645e82", "lit": "867ba2", "face": "4a465d", "glyph": "f0c02e", "glyph_shade": "cb8d16"},
	"evercrown": {"shape": "shard", "out": "120f19", "dark": "2c2541", "mid": "44386b", "lit": "5d4997", "face": "2c2541", "glyph": "51a5cd", "glyph_shade": "2b5278", "tip": "84cbd6"},
}

## Moss tones for a moss cap.
const MOSS_LIT := "49aa36"
const MOSS_DARK := "2b782c"

## The room's zone: picks the stele's look. Set before the tablet is added.
var zone := ""
var text := ""
## [conditions, text] pairs from the room's sign lines, in the order written.
## A line may open with world flags in brackets ("[spring:heartwood !boss:x]",
## the same as a person's fourth field): the first line whose flags all hold
## is the one read, and a line with none always holds (pass 251).
var variants: Array = []

## The carved rune strokes, computed from the sign's text and cached. Each is
## [x, y, w, h] in local space.
var _runes: Array = []
## The text the cached runes were carved for; a sentinel until the first carve.
var _runes_key := "￿"


## Adds one sign line. Text without brackets is read when no line before it holds.
func add_variant(line: String) -> void:
	line = line.strip_edges()
	var conds := ""
	if line.begins_with("["):
		var close := line.find("]")
		if close > 0:
			conds = line.substr(1, close - 1)
			line = line.substr(close + 1).strip_edges()
	variants.append([conds, line])
	text = current_text()


## What the tablet says now: the first line whose flags hold, else the last.
func current_text() -> String:
	for v: Array in variants:
		if Room.flags_hold(v[0]):
			return v[1]
	return "" if variants.is_empty() else String(variants[-1][1])


func _ready() -> void:
	super()
	prompt_height = 32.0
	z_index = -1


func interact(_p: Player) -> void:
	Sfx.play("tablet_read", 0.04)
	if not variants.is_empty():
		text = current_text()
	GameState.say("", text.split("|"))


## Carved runes for the face: short grooved strokes laid in two or three lines,
## rune-like and deterministic from `seed`, so each sign carries its own
## engraving. Each line opens with an upright stem; the rest mixes stems (with
## the odd cross-tick), short bars and dots, read left to right with word gaps.
## Returns [[x, y, w, h], ...] stroke rects, every one within FACE.
static func rune_strokes(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var strokes: Array = []
	var rows := rng.randi_range(2, 3)
	var row_h := FACE.size.y / float(rows)
	var right := FACE.position.x + FACE.size.x
	for r in rows:
		var baseline := FACE.position.y + r * row_h + row_h - 1.0
		var max_h := row_h - 2.0
		var x := FACE.position.x + rng.randf_range(0.0, 1.0)
		var first := true
		while x < right - 1.0:
			# The first mark of each line is always an upright stem.
			var kind := 0 if first else rng.randi_range(0, 4)
			first = false
			if kind <= 1:  # an upright stem, sometimes with a cross-tick
				var h := roundf(rng.randf_range(2.0, max_h))
				strokes.append([x, baseline - h, 1.0, h])
				if h >= 3.0 and rng.randf() < 0.45:
					var tw: float = min(2.0, right - x)
					strokes.append([x, baseline - h + roundf(h * 0.4), tw, 1.0])
				x += 2.0
			elif kind == 2:  # a short cross-bar
				var w: float = min(rng.randf_range(2.0, 4.0), right - x)
				strokes.append([x, baseline - 2.0, w, 1.0])
				x += w + 1.0
			elif kind == 3:  # a single dot
				strokes.append([x, baseline - 2.0, 1.0, 1.0])
				x += 2.0
			else:  # a gap between words
				x += rng.randf_range(2.0, 3.0)
	return strokes


## The text the runes are seeded from: every variant line joined, so the carving
## is stable as world flags swap the read line, and two different signs differ.
func _seed_text() -> String:
	if variants.is_empty():
		return name
	var parts: Array = []
	for v: Array in variants:
		parts.append(String(v[1]))
	return "|".join(parts)


func _ensure_runes() -> void:
	var key := _seed_text()
	if key != _runes_key:
		_runes_key = key
		_runes = rune_strokes(key.hash())


## The look for `z`, or the plain slate arch for an unknown zone.
static func look_for(z: String) -> Dictionary:
	return LOOKS.get(z, LOOKS["gym"])


## The stele's silhouette as columns: {x: [top, bottom]}, the one-pixel column
## at x filled from y = top down to y = bottom (exclusive), above the plinth.
## Every shape covers the recessed panel (FACE grown by one) and stands on the
## plinth.
static func profile(shape: String) -> Dictionary:
	var cols := {}
	var foot := PLINTH.position.y
	match shape:
		"gable":
			# A pointed gable: straight slopes up to a peak two pixels wide.
			for x in range(-9, 9):
				var d := absf(x + 0.5)
				cols[x] = [-22.0 - floorf(9.0 - d), foot]
		"waystone":
			# A rough standing stone: its top slopes down to the right, with a
			# chip broken out of it.
			for x in range(-9, 9):
				var top := -28.0 + roundf((x + 9) * 4.0 / 17.0)
				if x == 3 or x == 4:
					top += 2.0
				elif x == 2 or x == 5:
					top += 1.0
				cols[x] = [top, foot]
		"runestone":
			# A squared dwarf runestone: a raised crown, and a cornice that
			# overhangs the shaft by a pixel each side.
			for x in range(-9, 9):
				cols[x] = [-27.0 if absf(x + 0.5) < 4.0 else -25.0, foot]
			cols[-10] = [-25.0, -22.0]
			cols[9] = [-25.0, -22.0]
		"shard":
			# A tall crystal shard: steep facets tapering to a point.
			for x in range(-9, 9):
				var d := absf(x + 0.5)
				cols[x] = [-23.0 - floorf((9.0 - d) * 1.2), foot]
		_:
			# A round-topped arch.
			for x in range(-9, 9):
				var d := absf(x + 0.5)
				cols[x] = [-22.0 - roundf(sqrt(maxf(0.0, 81.0 - d * d)) * 0.7), foot]
	return cols


func _px(x: float, y: float, w: float, h: float, hex: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(hex))


func _draw() -> void:
	_ensure_runes()
	var look := look_for(zone)
	var shape := String(look["shape"])
	var cols := profile(shape)
	var xs: Array = cols.keys()
	xs.sort()
	var left: int = xs[0]
	var right: int = xs[-1]
	var rng := RandomNumberGenerator.new()
	rng.seed = _runes_key.hash()
	var panel := FACE.grow(1.0)
	# The plinth: a low, wider block on the ground line, lit along its top.
	_px(PLINTH.position.x - 1, PLINTH.position.y - 1, PLINTH.size.x + 2, PLINTH.size.y + 1, look["out"])
	_px(PLINTH.position.x, PLINTH.position.y, PLINTH.size.x, PLINTH.size.y, look["dark"])
	_px(PLINTH.position.x, PLINTH.position.y, PLINTH.size.x, 1, look["mid"])
	# The outline: every column grown by a pixel each way.
	for x: int in xs:
		var c: Array = cols[x]
		_px(x - 1, c[0] - 1, 3, c[1] - c[0] + 1, look["out"])
	# The stone: mid, lit down the left edge and along each column's top,
	# shadowed down the right edge.
	for x: int in xs:
		var c: Array = cols[x]
		var tone: String = look["mid"]
		if x <= left + 1:
			tone = look["lit"]
		elif x >= right - 1:
			tone = look["dark"]
		_px(x, c[0], 1, c[1] - c[0], tone)
		_px(x, c[0], 1, 1, look["mid"] if x >= right - 1 else look["lit"])
	# A few weathering pits in the stone around the panel.
	for i in 8:
		var x: int = xs[rng.randi_range(2, xs.size() - 3)]
		var c: Array = cols[x]
		var y := float(rng.randi_range(int(c[0]) + 2, int(c[1]) - 1))
		if not panel.grow(1.0).has_point(Vector2(x + 0.5, y + 0.5)):
			_px(x, y, 1, 1, look["dark"])
	match shape:
		"runestone":
			# The cornice band, in metal, across the stone under its crown.
			_px(-10, -23, 20, 1, look["band"])
			_px(-10, -22, 20, 1, look["out"])
		"waystone":
			# A crack running down from the chip.
			var cx := 4.0
			var top: float = cols[4][0]
			for k in 4:
				_px(cx, top + 1.0 + k, 1, 1, look["out"])
				if k % 2 == 0:
					cx -= 1.0
		"shard":
			# A lit facet down the shard's left face, and its tip catching light.
			for x: int in xs:
				if x >= -1:
					break
				_px(x, cols[x][0] + 1.0, 1, 2, look["lit"])
			_px(-1, cols[-1][0], 2, 2, look["tip"])
	# The recessed panel: shadowed along the top and left, lit along the foot.
	_px(panel.position.x, panel.position.y, panel.size.x, panel.size.y, look["face"])
	_px(panel.position.x, panel.position.y, panel.size.x, 1, look["out"])
	_px(panel.position.x, panel.position.y, 1, panel.size.y, look["out"])
	_px(panel.position.x + 1, panel.end.y - 1, panel.size.x - 1, 1, look["lit"])
	# A moss cap: tufts along the top, the odd strand hanging down the face.
	if look.get("moss", false):
		for x: int in xs:
			if rng.randf() < 0.55:
				var top: float = cols[x][0]
				_px(x, top - 1.0, 1, 1, MOSS_LIT)
				_px(x, top, 1, 1, MOSS_DARK)
				if rng.randf() < 0.2:
					_px(x, top + 1.0, 1, rng.randi_range(1, 3), MOSS_DARK)
	# The engraved runes: a dark groove under each mark, the inlay over it.
	for s: Array in _runes:
		_px(s[0], s[1] + 1.0, s[2], s[3], look["out"])
		_px(s[0], s[1], s[2], s[3], look["glyph"] if (s[3] >= s[2]) else look["glyph_shade"])
	draw_prompt()
