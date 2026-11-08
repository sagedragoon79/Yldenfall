class_name World
extends Node2D
## Owns the current room, the player and the camera, and moves the player
## between rooms through doors. Also handles saving at shrines, respawning at
## the last save, the dropped gold purse, and the room catalog the map reads.
##
## Doors are digits in a room's grid plus a `door: N, target/room, M` header
## line. Edge doors trigger when the player walks into them; inner doors
## (digits away from the edge) are used by pressing Up.

signal room_changed(room: Room)

## Legend characters that are something to find: items and chests (Treasure Sense).
const TREASURE_CHARS := "GXOdhnzLWF*&${(}"
const FADE_OUT := 0.12
const FADE_IN := 0.18
## Side and shaft doors between rooms of one zone scroll the view instead of
## fading (design bible 3.3).
const SCROLL_TIME := 0.34
## How far inside the room the player lands when arriving through a side door.
const ARRIVE_INSET := 14.0
## Upward speed when arriving through a floor door from below.
const RISE_SPEED := -430.0
const TOP_ARRIVE_FALL := 120.0
## Falling this far below the room without a door puts the player back on safe ground.
const FALL_RESCUE := 64.0

const ZONES := {
	"hearthroot": {"name": "Hearthroot", "color": Color("c9a25a")},
	"heartwood": {"name": "Heartwood", "color": Color("6fb0a0")},
	"tower": {"name": "Hollin Tower", "color": Color("c8784a")},
	"haar": {"name": "The Haar", "color": Color("8fa596")},
	"boughs": {"name": "High Boughs", "color": Color("8cc070")},
	"spires": {"name": "Storm Spires", "color": Color("a58cd0")},
	"vorrhallow": {"name": "Vorrhallow", "color": Color("4a9aa8")},
	"evercrown": {"name": "The Evercrown", "color": Color("8a3a5a")},
	"sunken": {"name": "Sunken Spring", "color": Color("3a8a9a")},
	"trials": {"name": "Inner Rings", "color": Color("b8b4ac")},
	"gym": {"name": "Movement Gym", "color": Color("8d84a3")},
	"test": {"name": "Test Rooms", "color": Color("8d84a3")},
}

var room: Room
var player: Player
var camera: GameCamera
## Optional full-screen ColorRect (in the UI layer) used for fades.
var fader: ColorRect
## Skips fades so transitions finish within one frame (tests).
var instant := false
## When false the player keeps its own stats (the gym gives every ability).
var use_game_state := true
## Room id -> {name, zone, map: Vector2i, screens: Vector2i, size: Vector2i,
## doors: {n: {rect: Rect2i, edge, target, target_door}}, shrines: [Vector2i]}.
## `shrines` is every place to rest and save: each Meditation Shrine and each
## Ringreader (pass 403), so the map shows a town's rest as it shows a shrine.
var catalog := {}
## Room id -> room text. Tests register rooms here instead of writing files.
var texts := {}
var start_room := ""
## Visible area in world pixels, passed to the camera for its bounds clamp.
var view_size := Vector2(640, 360)
var busy := false
var backdrop: Backdrop
## The whole-scene colour grade (per-zone, design bible 12.9) and the Stillstone's
## time-stop tint; created with the camera on the first placement.
var time_tint: TimeTint
var motes: Motes
## Blossom drifting through the Tree once the Everbloom is dead (Motes.BLOSSOM).
var blossom: Motes
## Trial (pass 498): the PixelLab rain sheet for Carillon. Off unless SheetRain.SHIPPED
## or the --sheet-rain capture flag is set.
var sheet_rain: SheetRain
## Set from game.gd's --sheet-rain flag, so a capture can compare the two rains.
static var sheet_rain_trial := false
var fog: Fog
## The NES look over a `retro: true` room (Old Hearthroot, design bible 11).
var retro: RetroFilter

var _ignored_door := 0


func _ready() -> void:
	add_to_group("world")
	backdrop = Backdrop.new()
	add_child(backdrop)
	fog = Fog.new()
	add_child(fog)
	motes = Motes.new()
	add_child(motes)
	blossom = Motes.new()
	blossom.table = Motes.blossom_table()
	add_child(blossom)
	sheet_rain = SheetRain.new()
	add_child(sheet_rain)
	retro = RetroFilter.new()
	add_child(retro)


# --- Rooms -----------------------------------------------------------------------

func has_room(room_id: String) -> bool:
	return texts.has(room_id) or FileAccess.file_exists(room_path(room_id))


static func room_path(room_id: String) -> String:
	return "res://levels/%s.room" % room_id


## Whether a room file exists for `room_id` (a save from another build may name
## one that doesn't).
static func room_exists(room_id: String) -> bool:
	return room_id.count("/") == 1 and not room_id.contains("..") and FileAccess.file_exists(room_path(room_id))


func room_text(room_id: String) -> String:
	if texts.has(room_id):
		return texts[room_id]
	return FileAccess.get_file_as_string(room_path(room_id))


## Reads every room file under res://levels (except the gym) plus any rooms in
## `texts`, so the map knows each room's place, size and doors.
## Zone folders that aren't part of the world map (or the completion count).
const OFF_MAP := ["gym", "trials"]


func build_catalog() -> void:
	catalog.clear()
	var dir := DirAccess.open("res://levels")
	if dir != null:
		for zone_dir in dir.get_directories():
			# The gym and the Inner Rings' inner rings are off the map.
			if zone_dir in OFF_MAP:
				continue
			var sub := DirAccess.open("res://levels/" + zone_dir)
			for file in sub.get_files():
				if file.ends_with(".room"):
					var room_id := zone_dir + "/" + file.trim_suffix(".room")
					_catalog_room(room_id, room_text(room_id))
	for room_id: String in texts:
		_catalog_room(room_id, texts[room_id])


## A parsed room's key doors, `{cell, kind, id}`: each `J` is a Copper door unless a
## `lock:` line names its card, and each `g` is the Sky Gate.
static func locks_in(room_id: String, parsed: Dictionary) -> Array[Dictionary]:
	var kinds := {}
	for spec: String in parsed.lists.get("lock", []):
		var l := spec.split(",")
		if l.size() == 3:
			kinds[Vector2i(int(l[0]), int(l[1]))] = l[2].strip_edges()
	var out: Array[Dictionary] = []
	var grid: Array[String] = parsed.grid
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] in ["J", "g"]:
				var cell := Vector2i(x, y)
				var kind: String = "sky" if grid[y][x] == "g" else kinds.get(cell, "copper")
				out.append({"cell": cell, "kind": kind, "id": "%s:%d,%d" % [room_id, x, y]})
	return out


static var _world_locks: Array[Dictionary] = []


## Every key door in the world's room files (read once). The shops ask how many of
## a card's doors still stand shut, so they never sell a key with no door left
## (design bible 10.2).
static func world_locks() -> Array[Dictionary]:
	if _world_locks.is_empty():
		var dir := DirAccess.open("res://levels")
		for zone_dir in dir.get_directories():
			if zone_dir in OFF_MAP:
				continue
			for file in DirAccess.open("res://levels/" + zone_dir).get_files():
				if file.ends_with(".room"):
					var room_id := zone_dir + "/" + file.trim_suffix(".room")
					_world_locks.append_array(locks_in(room_id, Room.parse(FileAccess.get_file_as_string(room_path(room_id)))))
	return _world_locks


func _catalog_room(room_id: String, text: String) -> void:
	var parsed := Room.parse(text)
	var header: Dictionary = parsed.header
	var grid: Array[String] = parsed.grid
	var width := 0
	for row in grid:
		width = maxi(width, row.length())
	var size := Vector2i(width, grid.size())
	var map := Vector2i.ZERO
	if header.has("map"):
		var xy: PackedStringArray = String(header.map).split(",")
		map = Vector2i(int(xy[0]), int(xy[1]))
	var found := Room.scan_doors(grid)
	var doors := {}
	for spec: String in parsed.lists.get("door", []):
		var parts := spec.split(",")
		var n := int(parts[0])
		if found.has(n) and parts.size() >= 3:
			doors[n] = {"rect": found[n].rect, "edge": found[n].edge, "target": parts[1].strip_edges(), "target_door": int(parts[2])}
	var shrines: Array[Vector2i] = []
	var treasures: Array[String] = []
	var fruits := 0
	var dews := 0
	var grains := 0
	var locks := locks_in(room_id, parsed)
	# Finds laid by a `prop:` line count too (pass 187): the Elven Helm and the
	# Glass Key, under the id Room gives them (the prop's own cell).
	for spec: String in parsed.lists.get("prop", []):
		var pr := spec.split(",")
		if pr.size() == 3 and pr[2].strip_edges() in Room.FOUND_PROPS:
			treasures.append("%s:%d,%d" % [room_id, int(pr[0]), int(pr[1])])
	# A Ringreader rests and saves as a shrine does (design bible 3.3), so the map
	# marks where he stands too (pass 403).
	for spec: String in parsed.lists.get("npc", []):
		var np := spec.split(",")
		if np.size() >= 3 and String(GameData.npc(np[2].strip_edges()).get("role", "")) == "ringreader":
			shrines.append(Vector2i(int(np[0]), int(np[1])))
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] == "S":
				shrines.append(Vector2i(x, y))
			elif TREASURE_CHARS.contains(grid[y][x]):
				treasures.append("%s:%d,%d" % [room_id, x, y])
				if grid[y][x] == "L":
					fruits += 1
				elif grid[y][x] == "W":
					dews += 1
				elif grid[y][x] == "*":
					grains += 1
	catalog[room_id] = {
		"name": header.get("name", room_id),
		"zone": header.get("zone", ""),
		"map": map,
		"size": size,
		"screens": Room.screens_for(size),
		"doors": doors,
		"shrines": shrines,
		## Pickup ids of the room's items and chests (Treasure Sense, design bible 9).
		"treasures": treasures,
		## How many of those are Life Fruits and Mana Dews (the Journey page counts them).
		"fruits": fruits,
		"dews": dews,
		## And Grain Shards (the Journey page counts the skill points they make).
		"grains": grains,
		## Has a hidden room (a `secret:` line); finding it sets the flag `secret:<room id>`.
		"secret": not parsed.lists.get("secret", []).is_empty(),
		## Its key doors, `{cell, kind, id}`; the map marks the ones still shut.
		"locks": locks,
		## The guardian whose arena this is (`boss:` header), or "".
		"boss": String(header.get("boss", "")),
	}


# --- Starting and changing rooms ---------------------------------------------------

## Creates the player (if needed) and puts it in `room_id`, at `at` if given,
## otherwise at the room's spawn marker.
func start(room_id: String, at := Vector2.INF) -> void:
	start_room = room_id
	# A trial or rush never carries over into a new or loaded game.
	Trials.abandon()
	BossRush.abandon()
	if player == null:
		player = Player.new()
		player.respawn_handler = _on_player_respawn
		player.died.connect(_on_player_died)
		_enter(room_id)
		if use_game_state:
			GameState.apply(player)
	else:
		_enter(room_id)
	var pos := room.spawn_position if at == Vector2.INF else at
	# A restored position inside solid — a save from a build whose room has
	# since changed shape, or one hand-edited — would wake the hero embedded in
	# a wall, a soft-lock no rescue frees him from (the fall-rescue only catches
	# a drop past the floor). Fall back to the room's own spawn, as if arriving
	# fresh (pass 495).
	if at != Vector2.INF and _embedded_at(pos):
		at = Vector2.INF
		pos = room.spawn_position
	if at == Vector2.INF and room.spawn_position == Vector2.ZERO and not room.doors.is_empty():
		# No spawn marker: arrive as if through the room's first door.
		var first: int = room.doors.keys().min()
		_place_at_door(room.doors[first], Vector2.ZERO)
		pos = player.global_position
	player.teleport(pos)
	player.spawn_point = pos
	player.safe_position = pos
	if camera == null:
		camera = GameCamera.new()
		camera.target = player
		camera.view_size = view_size
		add_child(camera)
		camera.make_current()
		time_tint = TimeTint.new()
		# _enter sets the backdrop zone before the tint exists on the first room, so
		# seed the grade from the room we are placing into now (design bible 12.9).
		time_tint.set_zone(room.zone)
		add_child(time_tint)
	camera.set_room_limits(room.pixel_rect(), room.wide_camera())
	camera.snap_to_target()


## True if the hero's body, placed at `pos`, would sit in solid tiles (pass 495).
## Mirrors the soak's embed test (test_soak `_embedded`): the body drawn in 3 px,
## its four corners and centre, so "embedded" means the same here as under test.
func _embedded_at(pos: Vector2) -> bool:
	var was := player.global_position
	player.global_position = pos
	var body := player.body_rect().grow(-3.0)
	player.global_position = was
	for corner in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end, body.get_center()]:
		if room.is_solid_at(corner):
			return true
	return false


func _enter(room_id: String) -> void:
	var next := Room.from_text(room_text(room_id), room_id)
	if room != null:
		if player.get_parent() == room:
			room.remove_child(player)
		# Out of the tree at once: its walls must not shove the player in the new
		# room on the next physics step (queue_free alone keeps them a frame).
		remove_child(room)
		room.queue_free()
	room = next
	add_child(room)
	backdrop.set_zone(room.zone)
	# The whole-scene colour grade follows the zone (design bible 12.9); on the very
	# first room the tint is not built yet (the camera block below seeds it instead).
	if time_tint != null:
		time_tint.set_zone(room.zone)
	# Carillon's rain is either the code streak field (Motes) or the PixelLab sheet
	# (SheetRain); never both. The sheet is off unless kept (SheetRain.SHIPPED) or a
	# capture asks for it (--sheet-rain).
	var sheet := room.zone == "spires" and (SheetRain.SHIPPED or sheet_rain_trial)
	sheet_rain.set_active(sheet)
	motes.set_zone("" if sheet else room.zone)
	blossom.set_zone(room.zone if GameState.flag("cleared") else "")
	Music.for_room(room)
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	room.add_child(player)
	fog.set_room(room)
	retro.set_room(room)
	for c in room.get_children():
		if c is GoldPurse:
			player.purse = c
	if use_game_state:
		GameState.visit(room_id)
	if camera != null:
		camera.set_room_limits(room.pixel_rect(), room.wide_camera())
	room_changed.emit(room)


func _physics_process(delta: float) -> void:
	BossRush.tick(delta)
	if busy or player == null or room == null or player.dead or player.frozen:
		return
	player.in_sap = room.is_sap_at(player.global_position + Vector2(0, -6))
	if player.global_position.y > room.pixel_rect().end.y + FALL_RESCUE:
		player.set_back()
		camera.snap_to_target()
		return
	var body := player.body_rect()
	var touching := 0
	for n: int in room.doors:
		var d: Dictionary = room.doors[n]
		if d.edge != "inner" and (d.rect as Rect2).intersects(body):
			touching = n
			break
	if touching == 0:
		_ignored_door = 0
	elif touching != _ignored_door or _falling_back_through(touching):
		use_door(touching)


## Coming up a shaft you arrive inside its floor door, rising. Fall back before
## you clear it and the door takes you back down, rather than letting you drop
## out of the bottom of the room (pass 146).
func _falling_back_through(n: int) -> bool:
	return room.doors[n].edge == "bottom" and player.velocity.y > 0.0


## Takes door `n` of the current room to its target room.
func use_door(n: int) -> void:
	if busy or not room.doors.has(n):
		return
	var d: Dictionary = room.doors[n]
	if not has_room(d.target):
		push_warning("Door %d in %s leads to missing room %s" % [n, room.id, d.target])
		return
	busy = true
	var vel := player.velocity
	player.frozen = true
	var scroll := transition_kind(d) == "scroll"
	var old_view: Texture2D = null
	if fader != null and not instant:
		# Right after boot there is no drawn frame to scroll away from yet.
		if scroll and Engine.get_frames_drawn() > 2:
			old_view = _snapshot()
		if old_view == null:
			Sfx.play("door", 0.05, -8.0)
			await _fade(1.0, FADE_OUT)
	if use_game_state:
		GameState.capture(player)
	_enter(d.target)
	var arrive: Dictionary = room.doors.get(d.target_door, {})
	if arrive.is_empty():
		push_warning("Room %s has no door %d" % [room.id, d.target_door])
		player.teleport(room.spawn_position)
	else:
		_place_at_door(arrive, vel)
	_ignored_door = d.target_door
	camera.snap_to_target()
	if old_view != null:
		await _scroll(old_view, d.edge)
	player.frozen = false
	if fader != null and not instant and old_view == null:
		await _fade(0.0, FADE_IN)
	busy = false


## Moves the player to `pos` in room `room_id` (the Kettleforge lift), with a fade.
func travel(room_id: String, pos: Vector2) -> void:
	if busy or not has_room(room_id):
		return
	busy = true
	player.frozen = true
	if fader != null and not instant:
		await _fade(1.0, FADE_OUT)
	if use_game_state:
		GameState.capture(player)
	if room_id != room.id:
		_enter(room_id)
	player.teleport(pos)
	player.velocity = Vector2.ZERO
	player.safe_position = pos
	camera.snap_to_target()
	player.frozen = false
	if fader != null and not instant:
		await _fade(0.0, FADE_IN)
	busy = false


## Moves the player into room `room_id` through its door `n`, with a fade, as
## if they had come through it (the boss rush).
func travel_to_door(room_id: String, n: int) -> void:
	if busy or not has_room(room_id):
		return
	busy = true
	player.frozen = true
	if fader != null and not instant:
		await _fade(1.0, FADE_OUT)
	if use_game_state:
		GameState.capture(player)
	_enter(room_id)
	var arrive: Dictionary = room.doors.get(n, {})
	if arrive.is_empty():
		player.teleport(room.spawn_position)
	else:
		_place_at_door(arrive, Vector2.ZERO)
	_ignored_door = n
	camera.snap_to_target()
	player.frozen = false
	if fader != null and not instant:
		await _fade(0.0, FADE_IN)
	busy = false


## "scroll" for an edge door into a room of the same zone, otherwise "fade".
func transition_kind(d: Dictionary) -> String:
	if d.edge == "inner":
		return "fade"
	var target_zone: String = catalog.get(d.target, {}).get("zone", "")
	return "scroll" if target_zone != "" and target_zone == room.zone else "fade"


func _snapshot() -> Texture2D:
	var img := get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img) if img != null else null


## Covers the view with the old room's last frame, waits for the new room to
## draw, then slides the old frame out and the new one in, the way the player
## walked.
func _scroll(old_view: Texture2D, edge: String) -> void:
	var dir := Vector2.ZERO
	match edge:
		"right": dir = Vector2.LEFT
		"left": dir = Vector2.RIGHT
		"top": dir = Vector2.DOWN
		"bottom": dir = Vector2.UP
	var curtain := Node2D.new()
	fader.get_parent().add_child(curtain)
	fader.get_parent().move_child(curtain, 0)
	var size := old_view.get_size()
	var offset := -(size - fader.size) * 0.5
	var old_sprite := Sprite2D.new()
	old_sprite.centered = false
	old_sprite.texture = old_view
	old_sprite.position = offset
	curtain.add_child(old_sprite)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var new_sprite := Sprite2D.new()
	new_sprite.centered = false
	new_sprite.texture = _snapshot()
	new_sprite.position = offset - dir * size
	curtain.add_child(new_sprite)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(old_sprite, "position", offset + dir * size, SCROLL_TIME)
	tw.tween_property(new_sprite, "position", offset, SCROLL_TIME)
	await tw.finished
	curtain.queue_free()


func _place_at_door(door: Dictionary, vel: Vector2) -> void:
	var r: Rect2 = door.rect
	var pos := Vector2(r.get_center().x, r.end.y)
	match door.edge:
		"left":
			pos.x = r.end.x + ARRIVE_INSET
			player.facing = 1
			vel.y = minf(vel.y, 0.0)
		"right":
			pos.x = r.position.x - ARRIVE_INSET
			player.facing = -1
			vel.y = minf(vel.y, 0.0)
		"top":
			pos.y = r.end.y + 40.0
			# Down through a floor door you come falling, even into water that
			# would otherwise float you straight back up through it.
			vel.y = maxf(vel.y, TOP_ARRIVE_FALL)
		"bottom":
			pos.y = r.position.y + 8.0
			vel.y = RISE_SPEED
		"inner":
			vel = Vector2.ZERO
	player.arrive_through_door(pos, vel, door.edge in ["left", "right"])
	# The arrival is the room's first safe spot, through any door: through a
	# floor or ceiling door it is the point under or over the opening (pass
	# 151). It had been left as the last room's footing until the first
	# landing, so spikes met on the way down set you back at the old room's
	# coordinates, inside this room's walls.
	player.safe_position = pos
	_clear_arrival(player.body_rect())


## Coming through a door means the way is open: cracked stone that would hold
## the player on arrival (a door reached from its far side first) gives way.
func _clear_arrival(body: Rect2) -> void:
	for c in room.get_children():
		if c is CrackedBlock and Rect2(c.global_position - Vector2(8, 8), Vector2(16, 16)).intersects(body.grow(-1.0)):
			c.break_block(true)


## A door's fade and scroll take real time (pass 477): the Game speed option, a
## boss's slow motion and hitstop never stretch or stall a way between rooms.
func _fade(to: float, time: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(fader, "color:a", to, time)
	await tw.finished


# --- Saving and death --------------------------------------------------------------

## Called by a save shrine at `pos` in the current room. False when the save
## file could not be written (a full or read-only disk), so the rest never
## claims a save it didn't make (pass 255).
func save_at(pos: Vector2) -> bool:
	player.spawn_point = pos
	if not use_game_state:
		return true
	GameState.capture(player)
	GameState.data.save_room = room.id
	GameState.data.save_pos = [pos.x, pos.y]
	return GameState.save_game()


func _on_player_died() -> void:
	if not use_game_state:
		return
	GameState.data.deaths = int(GameState.data.get("deaths", 0)) + 1
	if is_instance_valid(player.purse):
		var pos := player.purse.position
		GameState.data.purse = {"room": room.id, "x": pos.x, "y": pos.y, "value": player.purse.value}
	else:
		GameState.data.purse = {}
	GameState.capture(player)


func _on_player_respawn() -> void:
	player.frozen = true
	call_deferred("_respawn_player")


## Whether a guardian's fight is going on in the current room.
func _fight_under_way() -> bool:
	for c in room.get_children():
		if c is BossArena and (c as BossArena).fighting:
			return true
	return false


func _respawn_player() -> void:
	var target := start_room
	var pos := player.spawn_point
	if use_game_state:
		pos = Vector2.INF
		if String(GameState.data.save_room) != "":
			target = GameState.data.save_room
			pos = Vector2(float(GameState.data.save_pos[0]), float(GameState.data.save_pos[1]))
	# A fight lost in the room you rest in starts over (bible 8, pass 452):
	# the room is built afresh, so the guardian is whole and the doors open.
	# the Likeness's own gate has a shrine; until now you rose beside her
	# still sealed in, her wounds kept, mid-swing.
	if target != room.id or _fight_under_way():
		_enter(target)
	if pos == Vector2.INF:
		pos = room.spawn_position
	player.teleport(pos)
	player.safe_position = pos
	camera.snap_to_target()
	player.frozen = false
