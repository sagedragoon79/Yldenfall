class_name FoeLight
extends RefCounted
## A foe stands in its room's light (design bible 12.43). The pass 550 grade saw
## foes "more saturated and detailed than the muted rooms, so they look pasted
## in". Every foe in a zone's room draws through one shared material that mutes
## its colour a little and sinks its darks toward the zone's haze
## (`Backdrop.ZONE_HAZE`, the colour the room's own shadows recede into). Lights
## keep their value, and the hit flash, the tell and the death replace the
## material, so nothing a player reads in a fight is dimmed.

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

static var _materials := {}


## The material a foe in `zone` rests in, or null where there is no zone (the
## gym, a bare test scene): then it draws as painted.
static func material_for(zone: String) -> ShaderMaterial:
	if not Backdrop.ZONE_HAZE.has(zone):
		return null
	if not _materials.has(zone):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var deep := deep_for(zone)
		mat.set_shader_parameter("haze", Vector3(deep.r, deep.g, deep.b))
		mat.set_shader_parameter("mute", MUTE)
		mat.set_shader_parameter("sink", SINK)
		_materials[zone] = mat
	return _materials[zone]


## The colour a foe's darks sink toward in `zone`: its haze at DEEP of its value.
static func deep_for(zone: String) -> Color:
	var haze: Color = Backdrop.ZONE_HAZE[zone]
	return Color(haze.r * DEEP, haze.g * DEEP, haze.b * DEEP)


static func luma(c: Color) -> float:
	return c.r * LUMA.x + c.g * LUMA.y + c.b * LUMA.z


## How far a tone of luma `g` sinks toward the haze.
static func sink_at(g: float) -> float:
	return SINK * (1.0 - g) * (1.0 - g)


## What the shader makes of `c` in `zone`: the same sum, for the tests.
static func lit(c: Color, zone: String) -> Color:
	if not Backdrop.ZONE_HAZE.has(zone):
		return c
	var g := luma(c)
	var grey := Color(g, g, g, c.a)
	var muted := c.lerp(grey, MUTE)
	var out := muted.lerp(deep_for(zone), sink_at(g))
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
