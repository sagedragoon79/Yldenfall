class_name DoorMarker
extends Interactable
## A doorway inside a room (as opposed to an exit at the room's edge). Press Up
## to go through; the World does the transition.

const FRAME := Color("8a5a34")
const FRAME_DARK := Color("5e3b22")
const INSIDE := Color("1d1a2b")
## The wall the door is set in (bible 12.110, pass 634): the pass 630 grade saw the plaza's
## door as "an orange frame floating on the skyline". Half its width and its height.
const WALL_HALF := 24
const WALL_HEIGHT := 56
## A course of the wall's blocks, and a block's length.
const COURSE := 8
const BLOCK := 12
## The ruined top: how many pixels of each course stand, from the left edge, for the two
## top courses (the rest of the wall is whole). A broken edge, not a straight cut.
const TOP_STEPS := [[0, 30], [10, 48]]

var door := 0
## The zone, for the wall's stone (the lore tablets' tones for that zone).
var zone := ""


func _ready() -> void:
	super()
	prompt_height = 48.0
	z_index = -2
	add_child(ContactShadow.make(WALL_HALF + 2))


func interact(_p: Player) -> void:
	var world := get_tree().get_first_node_in_group("world") as World
	if world != null:
		# Deferred: the player is mid-physics-step and is about to be moved to another room.
		world.call_deferred("use_door", door)


func _draw() -> void:
	draw_wall()
	draw_rect(Rect2(-14, -42, 28, 42), FRAME_DARK)
	draw_rect(Rect2(-12, -40, 24, 40), FRAME)
	draw_rect(Rect2(-9, -37, 18, 37), INSIDE)
	draw_circle(Vector2(0, -37), 9.0, INSIDE)
	draw_prompt()


## The stone round the door: block courses with a broken top, a jamb of lit stones each
## side of the frame, a lintel over it and a threshold step. The stone is the zone's.
func draw_wall() -> void:
	var look := LoreTablet.look_for(zone)
	var out := Color(String(look["out"]))
	var dark := Color(String(look["dark"]))
	var mid := Color(String(look["mid"]))
	var lit := Color(String(look["lit"]))
	var courses := WALL_HEIGHT / COURSE
	for i in courses:
		var y0 := -COURSE * (i + 1)
		var from_top := courses - 1 - i
		var x0 := -WALL_HALF
		var x1 := WALL_HALF
		if from_top < TOP_STEPS.size():
			x0 = -WALL_HALF + int(TOP_STEPS[from_top][0])
			x1 = -WALL_HALF + int(TOP_STEPS[from_top][1])
		# The outline round the course's run, then its blocks.
		draw_rect(Rect2(x0 - 1, y0 - 1, x1 - x0 + 2, COURSE + 1), out)
		var shift := (BLOCK / 2) * (i % 2)
		var bx := -WALL_HALF - shift
		while bx < x1:
			var a := maxi(bx, x0)
			var b := mini(bx + BLOCK, x1)
			if b - a >= 2:
				draw_rect(Rect2(a, y0, b - a - 1, COURSE - 1), mid)
				draw_rect(Rect2(a, y0, b - a - 1, 1), lit)
				draw_rect(Rect2(a, y0 + COURSE - 2, b - a - 1, 1), dark)
			bx += BLOCK
	# The jambs: tall stones each side of the frame, lit on the face the light finds.
	for side: int in [-1, 1]:
		var jx := -18 if side < 0 else 14
		for j in 5:
			var jy := -8 * (j + 1)
			draw_rect(Rect2(jx - 1, jy - 1, 6, 9), out)
			draw_rect(Rect2(jx, jy, 4, 7), lit if side < 0 else mid)
			draw_rect(Rect2(jx, jy, 4, 1), lit.lightened(0.15))
	# The lintel: one long stone over the frame, its keystone raised.
	draw_rect(Rect2(-19, -51, 38, 7), out)
	draw_rect(Rect2(-18, -50, 36, 5), mid)
	draw_rect(Rect2(-18, -50, 36, 1), lit)
	draw_rect(Rect2(-4, -54, 8, 9), out)
	draw_rect(Rect2(-3, -53, 6, 7), lit)
	# The threshold: a worn step the width of the jambs.
	draw_rect(Rect2(-20, -3, 40, 3), out)
	draw_rect(Rect2(-19, -2, 38, 2), mid)
	draw_rect(Rect2(-19, -2, 38, 1), lit)
