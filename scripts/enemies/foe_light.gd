class_name FoeLight
extends RefCounted
## A foe stands in its room's light (design bible 12.43). The pass 550 grade saw
## foes "more saturated and detailed than the muted rooms, so they look pasted
## in". Every foe in a zone's room draws through one shared material that mutes
## its colour a little and sinks its darks toward the zone's haze
## (`Backdrop.ZONE_HAZE`, the colour the room's own shadows recede into). Lights
## keep their value, and the hit flash, the tell and the death replace the
## material, so nothing a player reads in a fight is dimmed.
##
## One colour of a foe's own is left out of that (design bible 12.69). The pass
## 580 grade: foes are "dark on dark", and each wants "one saturated color". A
## foe's accent is a band of hue on its own sheet (the Rot Dwarf's orange cloth,
## the Grub Lump's cyan spots, the Iron Dwarf's bronze edges): pixels in the
## band, saturated and light enough to count, are not muted or sunk, and their
## saturation and value are lifted instead. Nothing is drawn that the sheet does
## not hold, so a foe with no such colour on its sheet has no accent.
##
## The body is lit by a fill (design bible 12.89). The pass 610 grade: foes
## "sink into dark rooms", one "a dark smudge". Measured on every sheet, half of
## a foe's pixels sat at or under the value of its room's shadows once sunk. A
## foe's mid tones (not its outline, not its lights) are raised by a gain and a
## touch of the zone's own light, so the body stands a step above the room's
## dark and the outline still closes it. This is a tone curve on the foe's own
## paint: nothing is drawn round the figure, so it is not a rim light.

const SHADER := preload("res://shaders/foe_light.gdshader")
## How far a foe's colour is pulled toward its own grey.
const MUTE := 0.2
## How far pure black sinks toward the haze; the pull falls off with the square
## of the darkness, so a mid tone moves a little and a light hardly at all.
const SINK := 0.55
## The darks sink toward the haze at this share of its value: the hue of the
## room's shadows, but never lighter than them, so an outline stays an outline
## (a foe must not melt into its backdrop: the Bark Knight on the Boughs' green).
const DEEP := 0.6
## Rec. 601 luma, as the shader weighs it.
const LUMA := Vector3(0.299, 0.587, 0.114)

## The fill: the gain on a mid tone, and how much of the zone's light is added.
const FILL_GAIN := 0.4
const FILL_ADD := 0.05
## The lumas (as painted) the fill rises over and falls over: nothing under
## FILL_LO (an outline), the whole fill from FILL_FULL to FILL_HOLD, nothing
## past FILL_END (a light keeps its value).
const FILL_LO := 0.06
const FILL_FULL := 0.2
const FILL_HOLD := 0.3
const FILL_END := 0.7

## The falloff past the edge of an accent's band (degrees of hue) and above its
## two floors, as the shader has them.
const BAND_SOFT := 12.0
const FLOOR_SOFT := 0.12
## Each foe's accent, by its script's name: the hue (degrees) and the band's
## half width, the least saturation and value a pixel needs to count, and how
## far its saturation and value rise toward 1. Tuned by eye on each idle frame
## at 3x over its zone's dark. A foe not here has none: the Lantern Ghost is
## meant to be faint (bible 7), the Crystal Dwarf carries a `FoeGlow`, and the
## Bog Puffcap, the Bark Knight and the Spring Eel have no such colour drawn.
const ACCENTS := {
	"blinkhop": [35.0, 20.0, 0.55, 0.5, 0.8, 0.5],  # its horn
	"hornet": [40.0, 20.0, 0.6, 0.5, 0.7, 0.4],  # its bands
	"rot_dwarf": [5.0, 20.0, 0.4, 0.2, 0.8, 0.55],  # his cloth
	"grub_lump": [165.0, 25.0, 0.3, 0.4, 0.8, 0.5],  # its fungus spots
	"sap_spitter": [165.0, 30.0, 0.3, 0.5, 0.8, 0.5],  # its fungus eyes
	"iron_dwarf": [28.0, 18.0, 0.45, 0.42, 0.8, 0.45],  # the bronze of his plate's edges
	"minecart_rider": [5.0, 20.0, 0.6, 0.35, 0.8, 0.5],  # his gloves and the cart's bands
	"gear_bat": [40.0, 20.0, 0.6, 0.6, 0.8, 0.5],  # its gear
	"silt_adder": [5.0, 20.0, 0.55, 0.35, 0.8, 0.5],  # its bands
	"drowned_dwarf": [5.0, 20.0, 0.6, 0.22, 0.8, 0.65],  # his rusted straps
	"marsh_hag": [110.0, 35.0, 0.3, 0.5, 0.8, 0.5],  # her lure's light
	"leaf_mantis": [35.0, 20.0, 0.6, 0.5, 0.8, 0.5],  # its eye
	"seed_bomber": [5.0, 20.0, 0.6, 0.35, 0.7, 0.45],  # its husk
	"mothling": [345.0, 25.0, 0.5, 0.4, 0.7, 0.45],  # its wings
	"storm_harpy": [35.0, 20.0, 0.6, 0.5, 0.8, 0.5],  # her talons
	"thunder_beetle": [35.0, 20.0, 0.6, 0.55, 0.7, 0.45],  # its shell's seams
	"spire_sentinel": [20.0, 30.0, 0.6, 0.35, 0.8, 0.5],  # his gilding
	"shade_knight": [160.0, 30.0, 0.38, 0.5, 0.8, 0.5],  # the lights of his plate
	"clockwork_hound": [35.0, 20.0, 0.62, 0.5, 0.7, 0.45],  # its brass
	"meteor_slug": [8.0, 22.0, 0.6, 0.45, 0.7, 0.45],  # the fire in its shell
}

static var _materials := {}


## The material a foe in `zone` rests in, or null where there is no zone (the
## gym, a bare test scene): then it draws as painted. A foe named by `foe` (its
## script's name) that has an accent gets the zone's material with its accent;
## every other foe of the zone shares one.
static func material_for(zone: String, foe := "") -> ShaderMaterial:
	if not Backdrop.ZONE_HAZE.has(zone):
		return null
	var who := foe if ACCENTS.has(foe) else ""
	var key := zone + "/" + who
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var deep := deep_for(zone)
		mat.set_shader_parameter("haze", Vector3(deep.r, deep.g, deep.b))
		mat.set_shader_parameter("mute", MUTE)
		mat.set_shader_parameter("sink", SINK)
		mat.set_shader_parameter("band_soft", BAND_SOFT)
		mat.set_shader_parameter("floor_soft", FLOOR_SOFT)
		var tint := fill_tint(zone)
		mat.set_shader_parameter("fill", Vector2(FILL_GAIN, FILL_ADD))
		mat.set_shader_parameter("fill_tint", Vector3(tint.r, tint.g, tint.b))
		mat.set_shader_parameter("fill_band", Vector4(FILL_LO, FILL_FULL, FILL_HOLD, FILL_END))
		if who != "":
			var a: Array = ACCENTS[who]
			mat.set_shader_parameter("accent", Vector4(a[0], a[1], a[2], a[3]))
			mat.set_shader_parameter("lift", Vector2(a[4], a[5]))
		_materials[key] = mat
	return _materials[key]


## The name a foe's accent is listed under: its script's file name.
static func id_of(foe: Node) -> String:
	var script: Script = foe.get_script()
	return script.resource_path.get_file().get_basename() if script != null else ""


## How much of an accent pixel `c` is for `foe`: 0 none, 1 the whole lift.
static func accent_at(c: Color, foe: String) -> float:
	if not ACCENTS.has(foe):
		return 0.0
	var a: Array = ACCENTS[foe]
	var d := absf(fposmod(c.h * 360.0 - a[0] + 180.0, 360.0) - 180.0)
	return ((1.0 - smoothstep(a[1], a[1] + BAND_SOFT, d))
		* smoothstep(a[2], a[2] + FLOOR_SOFT, c.s)
		* smoothstep(a[3], a[3] + FLOOR_SOFT, c.v))


## An accent pixel at its whole lift.
static func lifted(c: Color, foe: String) -> Color:
	if not ACCENTS.has(foe):
		return c
	var a: Array = ACCENTS[foe]
	return Color.from_hsv(c.h, c.s + (1.0 - c.s) * a[4], c.v + (1.0 - c.v) * a[5], c.a)


## The colour a foe's darks sink toward in `zone`: its haze at DEEP of its value.
static func deep_for(zone: String) -> Color:
	var haze: Color = Backdrop.ZONE_HAZE[zone]
	return Color(haze.r * DEEP, haze.g * DEEP, haze.b * DEEP)


static func luma(c: Color) -> float:
	return c.r * LUMA.x + c.g * LUMA.y + c.b * LUMA.z


## How far a tone of luma `g` sinks toward the haze.
static func sink_at(g: float) -> float:
	return SINK * (1.0 - g) * (1.0 - g)


## How much of the fill a tone painted at luma `g` takes: 0 none, 1 the whole.
static func fill_at(g: float) -> float:
	return smoothstep(FILL_LO, FILL_FULL, g) * (1.0 - smoothstep(FILL_HOLD, FILL_END, g))


## The colour of a zone's fill: its haze at full value, halfway to white, so a
## foe is lit in the hue of its room and keeps its own.
static func fill_tint(zone: String) -> Color:
	var haze: Color = Backdrop.ZONE_HAZE[zone]
	var top := maxf(haze.r, maxf(haze.g, haze.b))
	return Color(haze.r / top, haze.g / top, haze.b / top).lerp(Color.WHITE, 0.5)


## What the shader makes of `c` in `zone`: the same sum, for the tests.
static func lit(c: Color, zone: String, foe := "") -> Color:
	if not Backdrop.ZONE_HAZE.has(zone):
		return c
	var g := luma(c)
	var grey := Color(g, g, g, c.a)
	var muted := c.lerp(grey, MUTE)
	var out := muted.lerp(deep_for(zone), sink_at(g))
	var f := fill_at(g)
	var tint := fill_tint(zone)
	out = Color(minf(out.r * (1.0 + FILL_GAIN * f) + FILL_ADD * f * tint.r, 1.0),
		minf(out.g * (1.0 + FILL_GAIN * f) + FILL_ADD * f * tint.g, 1.0),
		minf(out.b * (1.0 + FILL_GAIN * f) + FILL_ADD * f * tint.b, 1.0))
	var w := accent_at(c, foe)
	if w > 0.0:
		out = out.lerp(lifted(c, foe), w)
	out.a = c.a
	return out


## The zone of the room `node` stands in, or "" outside any room.
static func zone_of(node: Node) -> String:
	var n := node.get_parent()
	while n != null:
		if n is Room:
			return (n as Room).zone
		n = n.get_parent()
	return ""
