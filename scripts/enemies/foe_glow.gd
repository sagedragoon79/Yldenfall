class_name FoeGlow
extends Node2D
## The light a foe made of stillglass carries (design bible 12.52). The pass 560
## grade: "the foe at the waterline is nearly invisible against the dark pillars".
## The Crystal Dwarf is dark steel in a dark hall, and `FoeLight` (12.43) sinks
## his darks toward the hall's haze, so only his crystal told him from a pillar.
##
## The crystal is a light, as the stillglass on the floor is: it throws a glow
## onto the dark behind him, and his body stands against it as a silhouette. The
## glow is drawn behind the foe, additive. Nothing is drawn over the figure:
## this is not a rim light.
##
## It is a soft light (12.108). Until pass 632 it fell off in four tones through
## an ordered dither, and the grade read that as "a square of magenta dither
## round the foe": a checkerboard a quarter of the peak deep. It now falls off
## in LEVELS fine tones, still mixed through the dither in GRAIN blocks, so no
## two neighbouring blocks differ by more than MAX_STEP of the brightest glow
## and the pattern is under what the eye picks out.
##
## It breathes slowly at rest, swells while the foe winds up (the tell reads
## sooner), and goes out when the foe dies.

## The glow's alpha at its centre, at rest and in a windup.
const PEAK := 0.44
const PEAK_TELL := 0.6
## Dither block size (world px) and the tone steps from the centre to nothing.
const GRAIN := 2
const LEVELS := 14
## The most two neighbouring blocks may differ by, as alpha at PEAK_TELL.
const MAX_STEP := 0.1
## The falloff's curve: above 1 the glow is bright at the crystal and thins out
## fast, so it lights a pocket behind the foe and not the hall.
const CURVE := 1.5
## How deep the resting glow breathes (a share of PEAK) and how fast (rad/s).
const BREATH := 0.12
const BREATH_RATE := 1.7
## How fast the glow follows its target strength (per second).
const FOLLOW := 6.0

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _textures := {}

## The glow's colour and half extents (world px).
var color := Color("f0a0f0")
var reach := Vector2(30, 26)
## Where the light is on the foe, facing right (world px from its origin).
var at := Vector2.ZERO
## 0 dark, 1 at rest; the foe sets it above 1 for its tell.
var strength := 1.0

var _t := 0.0
var _shown := 1.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The foe it lights is keyed off it (12.154): a dark edge between body and glow.
	var foe := get_parent() as Enemy
	if foe != null:
		foe.light_keyed = true


## The glow's step (0 nothing, LEVELS the centre) at `x`, `y` px from its
## centre: the falloff, read once per GRAIN block and dithered between steps.
## The very centre is the top step whole.
static func level_at(x: int, y: int, half: Vector2) -> int:
	var bx := floori(float(x) / GRAIN)
	var by := floori(float(y) / GRAIN)
	var nx := (float(bx) + 0.5) * GRAIN / half.x
	var ny := (float(by) + 0.5) * GRAIN / half.y
	var t := 1.0 - sqrt(nx * nx + ny * ny)
	if t <= 0.0:
		return 0
	t = pow(t, CURVE)
	var b: int = BAYER[posmod(by, 4) * 4 + posmod(bx, 4)]
	return mini(floori(t * (LEVELS + 1) + (b + 0.5) / 16.0), LEVELS)


## The share of the peak a step shows.
static func level_alpha(level: int) -> float:
	return float(level) / float(LEVELS)


## The glow as a white texture of half extents `half`, built once per size.
static func texture_for(half: Vector2) -> ImageTexture:
	var key := Vector2i(half)
	if not _textures.has(key):
		var img := Image.create(key.x * 2, key.y * 2, false, Image.FORMAT_RGBA8)
		for y in key.y * 2:
			for x in key.x * 2:
				img.set_pixel(x, y, Color(1, 1, 1, level_alpha(level_at(x - key.x, y - key.y, half))))
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


## The alpha at the glow's centre for `strength`, `t` seconds into its breath.
static func peak_at(strength: float, t: float) -> float:
	var rest := PEAK * (1.0 - BREATH * (0.5 + 0.5 * sin(t * BREATH_RATE)))
	if strength <= 1.0:
		return rest * maxf(strength, 0.0)
	return lerpf(rest, PEAK_TELL, minf(strength - 1.0, 1.0))


## The alpha the glow is drawn at now.
func shown_peak() -> float:
	return peak_at(_shown, _t)


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, strength, FOLLOW * delta)
	var foe := get_parent() as Enemy
	if foe != null:
		position = Vector2(at.x * foe.facing, at.y).round()
	queue_redraw()


func _draw() -> void:
	var a := shown_peak()
	if a <= 0.0:
		return
	var half := Vector2(Vector2i(reach))
	draw_texture_rect(texture_for(half), Rect2(-half, half * 2.0), false, Color(color, a))
