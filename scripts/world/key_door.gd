class_name KeyDoor
extends StaticBody2D
## A locked door (four tiles tall since pass 508, for the 2x hero). Walk into it holding the right key and it
## unlocks for good; without one it tells you what it needs. The key doors
## (design bible 3, "Key doors"), each with a mark of Yldenfall's own (pass 471:
## they had worn the card suits of the game this one began as): Copper (oak, an
## acorn; legend `J`), and, set by a `lock: x, y, kind` header line on a `J`,
## Silver (red lacquer, an Ylden leaf), Gold (blackened iron, the Reeve's crown),
## Thorn (elf-silver, a barbed thorn) and Glass (violet, a stillglass shard that
## glints). Key doors guard treasure, never the way on. "sky" is Vorrhallow's
## upper gate (pale shrine stone with a gold lightning glyph, legend `g`:
## Skyrend's Sky Key).

const IRON := Color("6b6380")
const GLYPH := Color("ffd24a")
const SIZE := Vector2(16, 64)
const SHRINE := Color("c9c4d6")
const SHRINE_DARK := Color("8d84a3")
const SKY := Color("b8a8ff")
## What each key is called in the game (pass 461): ids stay, names are the metal's.
const NAMES := {"copper": "Copper", "silver": "Silver", "gold": "Gold", "thorn": "Thorn", "glass": "Glass"}

## A key's name for the player: "copper" is "Copper".
static func label(kind: String) -> String:
	return String(NAMES.get(kind, kind.capitalize()))


## The key doors: their panel, its shade, the bands and the mark's glyph.
const DOORS := {
	"copper": {"panel": Color("8a5a34"), "dark": Color("5e3b22"), "band": Color("6b6380"), "glyph": Color("ffd24a"), "mark": "acorn"},
	"silver": {"panel": Color("a8323e"), "dark": Color("6a1e28"), "band": Color("d8b060"), "glyph": Color("ffe6ea"), "mark": "leaf"},
	"gold": {"panel": Color("3a3848"), "dark": Color("1e1c28"), "band": Color("d8b060"), "glyph": Color("ffd24a"), "mark": "crown"},
	"thorn": {"panel": Color("b8c4d8"), "dark": Color("7a86a0"), "band": Color("eef4ff"), "glyph": Color("4aa3df"), "mark": "thorn"},
	"glass": {"panel": Color("5a3a8a"), "dark": Color("34205a"), "band": Color("8af0b0"), "glyph": Color("ffd24a"), "mark": "shard"},
}

var kind := "copper"
var persist_id := ""

var _told := false


func _ready() -> void:
	collision_layer = Player.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * 0.5)
	add_child(shape)
	z_index = -1


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead:
		return
	if kind == "sky" or kind == "glass":
		queue_redraw()
	var touching := absf(p.global_position.x - global_position.x) < SIZE.x * 0.5 + 8.0 and absf(p.global_position.y - global_position.y) < 8.0
	if not touching:
		_told = false
		return
	if GameState.key_count(kind) > 0:
		open()
	elif not _told:
		_told = true
		GameState.toast.emit("A %s door. You need a %s Key." % [label(kind), label(kind)])
		Sfx.play("door_locked", 0.03)


func open() -> void:
	GameState.add_key(kind, -1)
	if persist_id != "":
		GameState.collect(persist_id)
	GameState.toast.emit("The %s Key turns." % label(kind))
	# The wards click, the bolt draws back, and a small chime (not the plain door creak).
	Sfx.play("key_turn", 0.03)
	var d := Dust.new()
	d.setup("debris")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -SIZE.y * 0.5)
	queue_free()


func _draw() -> void:
	if kind == "sky":
		_draw_sky_gate()
		return
	var door: Dictionary = DOORS.get(kind, DOORS.copper)
	draw_rect(Rect2(-8, -SIZE.y, 16, SIZE.y), door.dark)
	draw_rect(Rect2(-7, -SIZE.y + 1, 14, SIZE.y - 1), door.panel)
	for y in [-56, -32, -8]:
		draw_rect(Rect2(-8, y, 16, 3), door.band)
	draw_mark(self, String(door.mark), Vector2(0, -43), door.glyph)


## A door's mark, about 8 px across, centered on `c`, drawn on `ci`. Each has a
## shape of its own, so the doors are told apart without their colors (14).
static func draw_mark(ci: CanvasItem, mark: String, c: Vector2, col: Color) -> void:
	match mark:
		"acorn":
			# A nut under a cap, with its stalk.
			ci.draw_circle(c + Vector2(0, 1.5), 3.0, col)
			ci.draw_rect(Rect2(c + Vector2(-4, -3), Vector2(8, 3)), col)
			ci.draw_rect(Rect2(c + Vector2(-0.5, -5), Vector2(1, 2)), col)
		"leaf":
			# An Ylden leaf: broad and pointed, on its stalk, with its midrib dark.
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				var r := Vector2(3.6, 4.2) * (1.0 - 0.35 * maxf(0.0, -sin(a)))
				pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y - 1.0))
			pts[9] = c + Vector2(0, -5.5)
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, -4), c + Vector2(0, 5), col.darkened(0.5), 1.0)
			ci.draw_line(c + Vector2(0, 3), c + Vector2(0, 5.5), col, 1.0)
		"crown":
			# The Reeve's crown: a band and three points.
			ci.draw_rect(Rect2(c + Vector2(-4, 1), Vector2(8, 3)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(-4, -4), c + Vector2(-2, -1),
				c + Vector2(0, -5), c + Vector2(2, -1), c + Vector2(4, -4), c + Vector2(4, 1)]), col)
		"thorn":
			# A thorn off a bramble: a broad base curving up to a hooked point.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 5), c + Vector2(3.5, 5), c + Vector2(1, 1),
				c + Vector2(-0.5, -2), c + Vector2(-3, -5.5), c + Vector2(-2, -1), c + Vector2(-2.5, 2)]), col)
		_:
			# Stillglass: a tall crystal with a short one at its side, and a glint that winks.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, 5), c + Vector2(-2.5, -2.5), c + Vector2(-0.5, -6),
				c + Vector2(1.5, -2.5), c + Vector2(1.5, 5)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, 5), c + Vector2(2, 0), c + Vector2(3.5, -2),
				c + Vector2(5, 0), c + Vector2(5, 5)]), col)
			var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			ci.draw_circle(c + Vector2(-1, -2), 1.0, Color(1, 1, 1, a))


func _draw_sky_gate() -> void:
	draw_rect(Rect2(-8, -SIZE.y, 16, SIZE.y), SHRINE_DARK)
	draw_rect(Rect2(-7, -SIZE.y + 1, 14, SIZE.y - 1), SHRINE)
	for y in [-60, -6]:
		draw_rect(Rect2(-8, y, 16, 3), GLYPH)
	# A lightning glyph, pulsing faintly.
	var a := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
	var bolt := PackedVector2Array([Vector2(1, -51), Vector2(-3, -36), Vector2(1, -36), Vector2(-2, -21)])
	draw_polyline(bolt, SKY * Color(1, 1, 1, a), 3.0)
	draw_polyline(bolt, GLYPH, 1.0)
