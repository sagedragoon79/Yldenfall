class_name LoreTablet
extends Interactable
## A carved stone sign. Press Up to read it. The face carries engraved runes:
## short grooved strokes — upright stems, cross-ticks, bars and dots — laid in
## two or three lines, seeded from the sign's own text so each sign carves its
## own marks instead of the same filler scribble (pass 512).

const STONE := Color("5d5670")
const STONE_DARK := Color("37324a")
const GLYPH := Color("c9b98f")
const GLYPH_SHADE := Color("8a7a56")

## The inner writing area in local space, inset inside the slab's bevel. Every
## rune stroke stays within it.
const FACE := Rect2(-7, -17, 14, 15)

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
	prompt_height = 26.0
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


func _draw() -> void:
	_ensure_runes()
	# A carved stone slab with a bevelled frame: lit along the top and left,
	# shadowed down the right and bottom, so it reads as cut stone, not a card.
	draw_rect(Rect2(-9, -20, 18, 20), STONE_DARK)
	draw_rect(Rect2(-8, -19, 16, 18), STONE)
	draw_rect(Rect2(-8, -19, 16, 1), STONE.lightened(0.18))
	draw_rect(Rect2(-8, -19, 1, 18), STONE.lightened(0.08))
	draw_rect(Rect2(-8, -2, 16, 1), STONE_DARK)
	draw_rect(Rect2(7, -19, 1, 18), STONE_DARK)
	# The engraved runes: a dark groove under each mark, the inlay over it.
	for s: Array in _runes:
		draw_rect(Rect2(s[0], s[1] + 1.0, s[2], s[3]), STONE_DARK)
		draw_rect(Rect2(s[0], s[1], s[2], s[3]), GLYPH if (s[3] >= s[2]) else GLYPH_SHADE)
	draw_prompt()
