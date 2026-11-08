class_name TownLamp
extends Node2D
## A lamp post in a town of the Haar (Lampwick, design bible 3.2): a weathered
## post with a lantern hung from an arm. Its flame burns a pocket out of the fog
## (group "light"), so the town is a string of warm pockets in the murk. Scenery
## only. The origin is the lantern's flame; the post runs down to the floor.

const HEIGHT := 50.0
const POST := Color("3a2e26")
const POST_LIGHT := Color("5e4a3a")
const IRON := Color("1d1a2b")
const GLASS := Color("f0c02e")
const CORE := Color("f7f1de")

## How far the flame clears the fog (Fog reads it).
var light_radius := 84.0
## The warm pool it casts onto the floor and walls around it (RoomLight reads
## these): its flame's gold, reaching a little past the fog pocket.
var glow_color := GLASS
var glow_radius := 112.0
var _t := 0.0


func _ready() -> void:
	add_to_group("light")
	# Its flame also lights the stones around the post (design bible 12.10).
	add_to_group(RoomLight.GROUP)
	z_index = -2
	_t = fmod(global_position.x * 0.37, TAU)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# The post stands six pixels to the left of the lantern, under its arm.
	var post_x := -8.0
	draw_rect(Rect2(post_x - 2, -4, 4, HEIGHT + 4), IRON)
	draw_rect(Rect2(post_x - 1, -3, 2, HEIGHT + 2), POST)
	draw_rect(Rect2(post_x - 1, -3, 1, HEIGHT + 2), POST_LIGHT)
	draw_rect(Rect2(post_x - 4, HEIGHT - 3, 8, 3), IRON)
	# The arm and the hook.
	draw_rect(Rect2(post_x, -10, 9, 2), IRON)
	draw_rect(Rect2(0, -9, 1, 3), IRON)
	# The lantern: an iron cage around a flickering flame.
	var flicker := 0.85 + 0.15 * sin(_t * 7.0) * sin(_t * 3.1)
	draw_circle(Vector2.ZERO, 26.0, Color(GLASS, 0.07 * flicker))
	draw_circle(Vector2.ZERO, 12.0, Color(GLASS, 0.1 * flicker))
	draw_rect(Rect2(-4, -6, 9, 11), IRON)
	draw_rect(Rect2(-3, -5, 7, 9), GLASS * Color(1, 1, 1, flicker))
	draw_rect(Rect2(-1, -3, 3, 5), CORE * Color(1, 1, 1, flicker))
	draw_rect(Rect2(-4, -7, 9, 2), IRON)
	draw_rect(Rect2(-4, 4, 9, 2), IRON)
