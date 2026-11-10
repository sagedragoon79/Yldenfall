class_name Npc
extends Interactable
## A townsperson (data/npcs.json). Press Up to talk. Roles: "talk" (dialog),
## "king" (dialog, gives the starting gold once), "shop" (opens the shop) and
## "guru" (rest and save, skills) and "physician" (Kettleforge's hospital: mends
## you for free, without a save; pass 175).

const KING_GOLD := 1500
## Set once the first Ringreader has read the glass leaf (design bible 2).
const LEAF_READ := "leaf_read"
const OUTLINE := Color("1d1a2b")

var npc_id := ""
var info := {}

var _look := {}


func _ready() -> void:
	super()
	add_to_group("npc")
	info = GameData.npc(npc_id)
	_look = info.get("look", {})
	prompt_height = 50.0
	z_index = -1


func interact(p: Player) -> void:
	_face(p)
	match String(info.get("role", "talk")):
		"king":
			if not GameState.flag("king_gold"):
				GameState.set_flag("king_gold")
				p.add_gold(KING_GOLD)
				GameState.capture(p)
				Sfx.play("coin", 0.0, 4.0)
				GameState.say(info.name, info.lines)
			else:
				GameState.say(info.name, lines(info, "lines_after" if info.has("lines_after") else "lines"))
		"shop":
			Menus.open_shop(get_tree(), info.shop, p)
		"physician":
			if treat(p):
				_mend_fx()
				GameState.say(info.name, lines(info, "lines_treated"))
			else:
				GameState.say(info.name, lines(info, "lines"))
		"ringreader":
			var world := get_tree().get_first_node_in_group("world") as World
			if world != null and world.room != null:
				GameState.meet_ringreader(world.room.id, global_position)
			if GameState.unnamed_title() != "":
				await _name_title()
			Menus.open_ringreader(get_tree(), ringreader_greeting(info), p, self)
		_:
			GameState.say(info.get("name", ""), lines(info, "lines"))


## What a Ringreader says over the menu. The first one you meet reads the
## glass leaf the stranger carries (design bible 2, Act I) and sees the
## Heartwood Spring dammed with stillglass; after that, the usual greeting.
static func ringreader_greeting(npc: Dictionary) -> String:
	if not GameState.flag(LEAF_READ) and npc.has("greeting_leaf"):
		GameState.set_flag(LEAF_READ)
		return String(npc.greeting_leaf)
	return String(npc.get("greeting", ""))


## The original's town hospital (Kettleforge's, in Yldenfall): health and magic
## made whole and poison drawn out. Unlike a Ringreader's rest it neither saves nor
## refills the flask. Returns false when there was nothing to mend.
static func treat(p: Player) -> bool:
	if p.hp >= p.max_hp and p.mp >= p.max_mp and p.poison_left <= 0.0:
		return false
	p.cure_poison()
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.health_changed.emit(p.hp, p.max_hp)
	return true


func _mend_fx() -> void:
	var d := Dust.new()
	d.setup("heal")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -20)
	Sfx.play("heal", 0.0)


## What a person says from `key` of their data. Once the Everbloom is dead and
## the Tree blooms (`cleared`), "lines_cleared" takes over where it is written
## (design bible 4.4).
static func lines(npc: Dictionary, key: String) -> Array:
	if GameState.flag("cleared") and npc.has("lines_cleared"):
		return npc.lines_cleared
	return npc.get(key, [])


## Yldenfall's title ceremony: a rank you earned in the field becomes your
## name when a Ringreader speaks it, to a fanfare.
func _name_title() -> void:
	var title := GameState.name_title()
	var r := int(GameState.data.rank)
	Sfx.play("title", 0.0)
	Music.duck(2.2)
	GameState.flash.emit(0.25)
	var d := Dust.new()
	d.setup("heal")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -24)
	GameState.say(info.get("name", "Ringreader"), title_lines(r, title))
	var box := _dialog_box()
	if box != null and box.is_open:
		await box.closed


## What the Ringreader says when naming you `title` (rank index `r`), in the
## original's manner.
static func title_lines(r: int, title: String) -> Array:
	var first := "You have done well, wanderer. The Tree has felt your blade."
	if r >= 12:
		first = "Few who climb the Ylden come back as you have. Even the Everbloom must fear you now."
	elif r >= 8:
		first = "The dwarves' halls echo with your name. You walk like one the Tree has chosen."
	elif r >= 4:
		first = "Your steps no longer stumble on the roots. You have grown, wanderer."
	return [first, "From this day you shall be called %s." % title.to_upper(), "Go now, %s, and may the light of the springs guide you." % title]


func _dialog_box() -> DialogBox:
	for c in get_tree().root.find_children("*", "DialogBox", true, false):
		return c as DialogBox
	return null


## The Ringreader's "Rest and save": same as a shrine.
func rest(p: Player) -> void:
	p.restore()
	var world := get_tree().get_first_node_in_group("world") as World
	var saved := world == null or world.save_at(global_position)
	var d := Dust.new()
	d.setup("heal")
	get_parent().add_child(d)
	d.global_position = global_position + Vector2(0, -20)
	Sfx.play("save", 0.0)
	GameState.toast.emit("Rested. Your mark in the wood: " + GameState.carved_mark() if saved else SaveShrine.NOT_SAVED)


func _face(p: Player) -> void:
	scale.x = -1.0 if p.global_position.x < global_position.x else 1.0


func _c(key: String, fallback: String) -> Color:
	return Color(_look.get(key, fallback))


func _draw() -> void:
	if Sheet.exists("npc_" + npc_id):
		# Generated by tools/art/castgen.py from the look in data/npcs.json.
		Sheet.draw(self, "npc_" + npc_id, "idle", Sheet.frame_at("npc_" + npc_id, "idle", t))
		draw_prompt()
		return
	var robe := _c("robe", "#6b6380")
	var trim := _c("trim", "#c9b98f")
	var skin := _c("skin", "#e8c9a0")
	var hair := _c("hair", "#3a2a1e")
	var breathe := roundf(sin(t * 2.0) * 0.6)
	# Robe (wider at the hem), outlined.
	var body := PackedVector2Array([Vector2(-6, -30 + breathe), Vector2(6, -30 + breathe), Vector2(9, 0), Vector2(-9, 0)])
	var outline := PackedVector2Array([Vector2(-7, -31 + breathe), Vector2(7, -31 + breathe), Vector2(10, 1), Vector2(-10, 1)])
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(body, robe)
	draw_rect(Rect2(-9, -3, 18, 3), trim)
	draw_rect(Rect2(-1, -29 + breathe, 2, 26), trim.darkened(0.2))
	# Head.
	var head := Vector2(0, -36 + breathe)
	draw_rect(Rect2(head + Vector2(-5, -6), Vector2(10, 11)), OUTLINE)
	draw_rect(Rect2(head + Vector2(-4, -5), Vector2(8, 9)), skin)
	draw_rect(Rect2(head + Vector2(1, -2), Vector2(2, 2)), OUTLINE)
	draw_rect(Rect2(head + Vector2(-4, -5), Vector2(8, 3)), hair)
	draw_rect(Rect2(head + Vector2(-5, -4), Vector2(2, 6)), hair)
	match String(_look.get("hat", "none")):
		"crown":
			draw_rect(Rect2(head + Vector2(-5, -9), Vector2(10, 4)), trim)
			for i in 3:
				draw_rect(Rect2(head + Vector2(-5 + i * 4, -11), Vector2(2, 2)), trim)
		"hood":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-7, 3), head + Vector2(-6, -7), head + Vector2(0, -10), head + Vector2(6, -7), head + Vector2(7, 3), head + Vector2(5, 3), head + Vector2(4, -5), head + Vector2(-4, -5), head + Vector2(-5, 3)]), robe.lightened(0.1))
		"cap":
			draw_rect(Rect2(head + Vector2(-5, -8), Vector2(11, 4)), trim)
			draw_rect(Rect2(head + Vector2(4, -6), Vector2(3, 2)), trim)
		"helm":
			draw_rect(Rect2(head + Vector2(-6, -8), Vector2(12, 5)), Color("8d84a3"))
			draw_rect(Rect2(head + Vector2(-6, -4), Vector2(2, 5)), Color("8d84a3"))
	# Hands.
	draw_rect(Rect2(Vector2(5, -18 + breathe), Vector2(3, 3)), skin)
	draw_prompt()


func draw_prompt() -> void:
	# The node may be mirrored to face the player; draw the prompt unmirrored.
	if scale.x < 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	super()
	draw_set_transform(Vector2.ZERO)
