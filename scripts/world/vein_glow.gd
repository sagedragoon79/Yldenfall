class_name VeinGlow
extends Node2D
## The light the Veins give off (bible 12.140, pass 664). The pass 660 grade
## saw the Veins "in one purple": a wine backdrop (hue 289), violet shelves and
## a violet stalk (hue 259), and the light the room's sign tells of only in six
## thin channels. The stalk's veins now light the air of the shaft round it in
## their own cool cyan, a column that stands off the wine haze on both sides,
## so the room has a second hue and a middle to look at.
##
## It is the light in the channels: each lit vein feeds `1 / CHANNELS` of it,
## so the column dims a step with every cut, and once the core is starved
## (every vein cut, for good) the shaft is wine again. The Stillstone changes
## nothing here, since the light only holds still.
##
## Behind everything that is played: drawn under the stalk, the air's shade,
## the tiles and every actor (`Z`), so it tints only the air seen past them,
## like the light shafts (12.17). The falloff is baked once as clean steps in
## 2-pixel blocks (12.129), and a cut changes only the modulate.

## Under the air's shade (-3), the stalk (-2) and the light shafts (-1).
const Z := -4
## The glow's colour: sky-2, a channel's own line (`BloomStalk.LINE`).
const COLOR := Color("2b5278")
## Its strength at its heart, with every vein lit; a normal (mixing) blend, so
## it turns the wine toward the light's hue, not just brighter.
const PEAK := 0.62
## Half its width, from the stalk's axis (the stalk itself swings out to 50 px
## at its crown, 34 at its roots).
const REACH := 230
## The share of `REACH` at full strength round the axis.
const CORE := 0.18
## The floor's share of the strength: the light runs up, brightest at the core.
const FOOT := 0.7
## The falloff's steps, and the pixel block it is laid in.
const LEVELS := 8
const BLOCK := 2

static var _tex: ImageTexture

var stalk: BloomStalk


func _ready() -> void:
	z_as_relative = false
	z_index = Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The glow's strength at `dx` px across from the axis and `h` px up from the
## floor, before the lit share: 0 to 1, in `LEVELS` clean steps.
static func strength(dx: float, h: float) -> float:
	var across := absf(dx) / float(REACH)
	if across >= 1.0:
		return 0.0
	var a := 1.0 if across <= CORE else pow(1.0 - (across - CORE) / (1.0 - CORE), 1.6)
	var up := FOOT + (1.0 - FOOT) * clampf(h / float(BloomStalk.HEIGHT), 0.0, 1.0)
	return floorf(a * up * LEVELS + 0.5) / LEVELS


## The baked falloff: white, its alpha `strength`, from `-REACH` to `REACH`
## across the axis and the stalk's height up from the floor.
static func texture() -> ImageTexture:
	if _tex == null:
		var w := REACH * 2
		var hgt := BloomStalk.HEIGHT
		var img := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
		for by in range(0, hgt, BLOCK):
			for bx in range(0, w, BLOCK):
				var s := strength(bx + BLOCK * 0.5 - REACH, hgt - by - BLOCK * 0.5)
				if s <= 0.0:
					continue
				img.fill_rect(Rect2i(bx, by, BLOCK, BLOCK), Color(1, 1, 1, s))
		_tex = ImageTexture.create_from_image(img)
	return _tex


## The share of the light still running: the lit channels over all six.
func lit_share() -> float:
	if stalk == null:
		return 0.0
	var n := 0
	for i in BloomStalk.CHANNELS:
		if stalk.lit(i):
			n += 1
	return float(n) / BloomStalk.CHANNELS


## The glow's alpha at its heart now.
func peak() -> float:
	return PEAK * lit_share()


func _draw() -> void:
	var p := peak()
	if p <= 0.0:
		return
	draw_texture(texture(), Vector2(BloomStalk.AXIS - REACH, -BloomStalk.HEIGHT), Color(COLOR.r, COLOR.g, COLOR.b, p))
