extends Node
## Workbench capture: runs the real game (scenes/main.tscn) with whatever game
## options follow `--` (--room, --shot-at, --wear, --dye, --say, --open, ...), then
## saves the world's own render target, which holds no HUD, menus or dialog.
## Nothing here changes the game; it only reads what the game drew.
##
## Usage: godot --path . res://workbench/capture/shot.tscn -- --out=PATH [options] [game options]
##   --out=PATH          PNG to write (required)
##   --frames=N          frames to wait before saving (default 50)
##   --ui                save the full window, HUD and menus included, instead
##   --hero=W,H          crop a W x H box (world pixels) around the hero, feet near the bottom
##   --focus=npc:ID|boss with --hero's box: crop around that NPC or the room's boss instead
##   --scale=N           scale the saved image by N (nearest), after any crop
##   --invulnerable      keep the hero at full health so nothing interrupts the shot
##   --spark=X,Y[,...]   throw a hit spark at world X,Y (along +x) --spark-age=N frames
##                       before the shot (default 3); words after it: "heavy", "left",
##                       "up", "down", and "hero" (X,Y are from the hero's feet)
##   --slash=KIND[,...]  play the hero's swing smear (KIND side, up or down)
##                       --slash-age=N frames before the shot (default 2); words after
##                       it: "heavy", "left" (face left), "back" (the second combo cut)
##   --face-left         turn the hero to face left before anything else happens
##   --when=hit|tell     a fight frame: save once the hero's blade lands on something
##                       (hit: a HitSpark and the swing's smear, from a real swing, see --shot-attack) or a foe
##                       winds up an attack (tell), --after=N frames later (default 2).
##                       --frames is then the longest it waits (give it 600 or so); if
##                       the moment never comes nothing is saved and the exit code is 3.

## The states foes wind up an attack in (Enemy.MIN_TELEGRAPH), for --when=tell.
const TELLS: Array[String] = ["windup", "tell", "wind", "rev", "swell", "coil", "raise"]

var _args := {}
var _frames := 0
var _game: Node
var _moment := -1  # the frame --when's moment came, or -1


func _ready() -> void:
	# Menus pause the game; the capture keeps counting frames through them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_game = load("res://scenes/main.tscn").instantiate()
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	var p = _game.get("player")
	if _args.has("invulnerable") and p != null:
		p.hp = p.max_hp
	if _args.has("face-left") and p != null and _frames <= 20:
		p.facing = -1
	var at_frame := int(_args.get("frames", "50"))
	if _args.has("spark") and _frames == at_frame - int(_args.get("spark-age", "3")):
		_throw_spark(String(_args["spark"]).split(","))
	if _args.has("slash") and _frames == at_frame - int(_args.get("slash-age", "2")):
		_play_slash(String(_args["slash"]).split(","))
	if _args.has("when"):
		if _moment < 0 and moment(get_tree(), String(_args["when"])):
			_moment = _frames
		if _moment < 0 and _frames >= at_frame:
			printerr("workbench: no %s within %d frames" % [_args["when"], at_frame])
			set_process(false)
			get_tree().quit(3)
			return
		if _moment < 0 or _frames < _moment + int(_args.get("after", "2")):
			return
	elif _frames < at_frame:
		return
	set_process(false)
	var img: Image
	if _args.has("ui"):
		img = get_viewport().get_texture().get_image()
	else:
		var view: SubViewport = _game.get("view")
		img = view.get_texture().get_image()
		if _args.has("hero") and p != null:
			var wh: PackedStringArray = String(_args["hero"]).split(",")
			var detail := 2
			var size := Vector2i(int(wh[0]), int(wh[1])) * detail
			var target: Node2D = p
			if _args.has("focus"):
				target = _focus(String(_args["focus"]))
				if target == null:
					printerr("workbench: nothing to focus on for ", _args["focus"])
					get_tree().quit(2)
					return
			# The target's feet, in the world viewport's pixels.
			var feet: Vector2 = target.get_global_transform_with_canvas().origin
			var at := Vector2i(int(feet.x) - size.x / 2, int(feet.y) - size.y + 8 * detail)
			at.x = clampi(at.x, 0, img.get_width() - size.x)
			at.y = clampi(at.y, 0, img.get_height() - size.y)
			img = img.get_region(Rect2i(at, size))
	var s := int(_args.get("scale", "1"))
	if s > 1:
		img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	var out := String(_args.get("out", "user://shot.png"))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	get_tree().quit()


## True on a frame worth a fight picture (--when). "hit": a spark from the hero's
## blade is in the air and the swing's smear is showing. "tell": a living foe is in
## a wind-up state.
static func moment(tree: SceneTree, what: String) -> bool:
	match what:
		"hit":
			# The blow lands on the swing's first step, the game holds for the hitstop
			# (real time, so no frame count is safe) and only then does the blade
			# travel: wait until the spark and the swing's smear are both drawn.
			var room := tree.get_first_node_in_group("room")
			var hero := tree.get_first_node_in_group("player")
			if room == null or hero == null:
				return false
			var smear := false
			for c in hero.get_children():
				if c is SlashFx and not c.waiting():
					smear = true
			if smear:
				for c in room.get_children():
					if c is HitSpark:
						return true
		"tell":
			for e in tree.get_nodes_in_group("enemy"):
				if e is Enemy and not e.dead and TELLS.has(e.state):
					return true
	return false


func _focus(what: String) -> Node2D:
	if what == "boss":
		return get_tree().get_first_node_in_group("boss") as Node2D
	if what.begins_with("npc:"):
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is Npc and n.npc_id == what.trim_prefix("npc:"):
				return n
	return null


func _throw_spark(v: PackedStringArray) -> void:
	var dir := Vector2.RIGHT
	var size := 1.0
	var at := Vector2(float(v[0]), float(v[1]))
	for w in v.slice(2):
		match w:
			"hero":
				var p = _game.get("player")
				if p != null:
					at += (p as Node2D).global_position
			"heavy": size = Player.HEAVY_SPARK
			"left": dir = Vector2.LEFT
			"up": dir = Vector2.UP
			"down": dir = Vector2.DOWN
	var room := get_tree().get_first_node_in_group("room")
	if room != null:
		HitSpark.spawn(room, at, dir, size)


func _play_slash(v: PackedStringArray) -> void:
	var p = _game.get("player")
	if p == null:
		return
	var facing := -1 if v.has("left") else 1
	(p as Player).facing = facing
	var fx := SlashFx.new()
	fx.setup(v[0], facing, 2 if v.has("back") else 1, v.has("heavy"))
	(p as Node2D).add_child(fx)
