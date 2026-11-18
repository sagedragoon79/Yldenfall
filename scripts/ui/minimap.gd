class_name Minimap
extends RefCounted
## The minimap (bible 12's UI list, pass 373): a small window in the HUD's top
## right corner showing the map around you at half the full map's scale. It
## shows what the full map shows (rooms you have walked, dimmed rooms a chart
## gives you, your room pulsing, shrines, still-shut key doors, and a blinking
## dot where you stand) so you can keep your bearings without opening the map.
## It hides while the full map, a menu or a dialog is up, and in the Inner Rings
## and the Boss Rush, whose clocks hold the top of the screen.

## The window's size in HUD pixels, and its gap from the screen's corner.
const SIZE := Vector2(96, 54)
const MARGIN := 10.0
## Half the full map's scale: one screen of a room is 20 x 11 here.
const SCALE := 0.5
## The pass 600 grade saw "an empty dark panel holding one flat coloured rectangle".
## Since pass 603 the window reads as the map it is: the map's own grid, one faint
## cell per screen of a room (`GRID`), each walked room's door openings, as the full
## map draws them, and a short stub of path (`EXIT` px) out of each door of your room
## that leads somewhere you have neither walked nor charted, so the ways on show.
## Its frame has gold corner brackets (`BRACKET` px), as the HUD's plate does.
const GRID := Color(1, 1, 1, 0.06)
const EXIT := 4.0
const EXIT_COLOR := Color(0.945, 0.918, 0.824, 0.6)
const BRACKET := 4.0
const BRACKET_COLOR := Color(0.847, 0.69, 0.376, 0.85)


## Where the window sits on a screen of `screen` size.
static func window(screen: Vector2) -> Rect2:
	return Rect2(Vector2(screen.x - MARGIN - SIZE.x, MARGIN), SIZE)


## What the window shows: each room in view as {id, rect, how}, `how` as the full
## map has it ("here", "visited" or "charted"), and the dot where you stand, all
## in window space (the window's top left is 0, 0). Your room's middle is the
## window's middle, so the map scrolls as you move from room to room.
##
## The rooms in view change only when you change rooms, walk a new one or buy
## a chart, so they are worked out then and kept on the world (pass 375):
## sweeping the whole catalog every frame cost about 0.2 ms on a full map.
## Only the dot is worked out each frame. `cached` says which it was.
static func layout(world: World) -> Dictionary:
	var out := {"rooms": [], "player": Vector2.INF, "cached": false, "origin": Vector2.ZERO, "exits": []}
	if world == null or world.room == null:
		return out
	var here: Dictionary = world.catalog.get(world.room.id, {})
	if here.is_empty():
		return out
	var here_rect := _rect(here)
	var origin := SIZE * 0.5 - here_rect.get_center()
	out.origin = origin
	var key := "%s|%d|%d|%d" % [world.room.id, GameState.data.visited.size(), GameState.data.charts.size(), world.catalog.size()]
	var kept: Dictionary = world.get_meta(CACHE, {})
	if kept.get("key", "") == key:
		out.rooms = kept.rooms
		out.exits = kept.exits
		out.cached = true
	else:
		var view := Rect2(Vector2.ZERO, SIZE)
		for room_id: String in world.catalog:
			var info: Dictionary = world.catalog[room_id]
			var how := MapScreen.shown(room_id, info, world.room.id)
			if how == "":
				continue
			var r := _rect(info)
			r.position += origin
			if not r.intersects(view):
				continue
			out.rooms.append({"id": room_id, "rect": r, "how": how, "info": info})
		var here_in := here_rect
		here_in.position += origin
		out.exits = _exits(world, here, here_in)
		world.set_meta(CACHE, {"key": key, "rooms": out.rooms, "exits": out.exits})
	if world.player != null:
		var frac := world.player.global_position / (Vector2(here.size) * Room.TILE)
		out.player = origin + here_rect.position + frac.clamp(Vector2.ZERO, Vector2.ONE) * here_rect.size
	return out


## The doors of your room (`info`, drawn at `r` in window space) that lead to a room
## the map does not show yet: each as {at, edge}, the door's point on the room's edge.
static func _exits(world: World, info: Dictionary, r: Rect2) -> Array:
	var out := []
	for n: int in info.doors:
		var d: Dictionary = info.doors[n]
		if d.edge == "inner":
			continue
		var target: Dictionary = world.catalog.get(String(d.target), {})
		if not target.is_empty() and MapScreen.shown(String(d.target), target, world.room.id) != "":
			continue
		out.append({"at": door_point(info, r, d), "edge": String(d.edge)})
	return out


## Where door `d` of room `info`, drawn at `r`, meets the room's edge.
static func door_point(info: Dictionary, r: Rect2, d: Dictionary) -> Vector2:
	var cell_rect: Rect2i = d.rect
	var c := (Vector2(cell_rect.position) + Vector2(cell_rect.size) * 0.5) / Vector2(info.size)
	var p := r.position + c * r.size
	match String(d.edge):
		"left":
			p.x = r.position.x
		"right":
			p.x = r.end.x
		"top":
			p.y = r.position.y
		"bottom":
			p.y = r.end.y
	return p


## The four gold corner brackets of a frame at `r`: two bars each, `size` px long.
static func bracket_rects(r: Rect2, size := BRACKET) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for corner: Vector2 in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		var right := corner.x > r.position.x
		var low := corner.y > r.position.y
		out.append(Rect2(Vector2(corner.x - size + 1 if right else corner.x, corner.y), Vector2(size, 1)))
		out.append(Rect2(Vector2(corner.x, corner.y - size + 1 if low else corner.y), Vector2(1, size)))
	return out


## The world's meta key the rooms in view are kept under.
const CACHE := &"minimap_rooms"


static func _rect(info: Dictionary) -> Rect2:
	var r := MapScreen.room_rect(info)
	return Rect2(r.position * SCALE, r.size * SCALE)


## Whether the HUD should draw it now: not while the full map, a menu or a
## dialog beside it on the UI layer is open, nor in a Trial or the Rush.
static func showing(hud: Node) -> bool:
	if Trials.active() or BossRush.active():
		return false
	var layer := hud.get_parent()
	if layer == null:
		return true
	for c in layer.get_children():
		if (c is MapScreen and (c as MapScreen).is_open) or (c is ListMenu and (c as ListMenu).is_open) \
				or (c is DialogBox and (c as DialogBox).is_open):
			return false
	return true


## Draws the window on `canvas` (the HUD) at `at`, pulsing with `t`.
static func draw(canvas: CanvasItem, at: Rect2, world: World, t: float) -> void:
	var lay := layout(world)
	canvas.draw_rect(at.grow(1), MapScreen.OUTLINE)
	canvas.draw_rect(at, Color(0.05, 0.04, 0.09, 0.62))
	# The map's grid, one cell per screen of a room, scrolling with the map.
	var grid_cell := MapScreen.CELL * SCALE
	var gx := fposmod((lay.origin as Vector2).x, grid_cell.x)
	while gx < SIZE.x:
		canvas.draw_rect(Rect2(at.position + Vector2(gx, 0), Vector2(1, SIZE.y)), GRID)
		gx += grid_cell.x
	var gy := fposmod((lay.origin as Vector2).y, grid_cell.y)
	while gy < SIZE.y:
		canvas.draw_rect(Rect2(at.position + Vector2(0, gy), Vector2(SIZE.x, 1)), GRID)
		gy += grid_cell.y
	for room: Dictionary in lay.rooms:
		var r: Rect2 = (room.rect as Rect2).intersection(Rect2(Vector2.ZERO, SIZE))
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		r.position += at.position
		var info: Dictionary = room.info
		var zone: Dictionary = World.ZONES.get(info.zone, {"color": MapScreen.DIM})
		var color: Color = zone.color
		var fill := color.darkened(0.55)
		match String(room.how):
			"charted":
				canvas.draw_rect(r, color.darkened(0.82))
				canvas.draw_rect(r, color.darkened(0.5), false, 1.0)
				continue
			"here":
				fill = color.darkened(0.25 - 0.1 * sin(t * 4.0))
		canvas.draw_rect(r, fill)
		canvas.draw_rect(r, MapScreen.EDGE.darkened(0.35), false, 1.0)
		var full := (room.rect as Rect2)
		full.position += at.position
		# Its door openings, gaps in the outline as the full map draws them.
		for n: int in info.doors:
			var d: Dictionary = info.doors[n]
			if d.edge == "inner":
				continue
			var dp := door_point(info, full, d)
			var side: bool = d.edge in ["left", "right"]
			var gap := Rect2(dp - Vector2(1, 1.5), Vector2(2, 3)) if side else Rect2(dp - Vector2(1.5, 1), Vector2(3, 2))
			if at.encloses(gap):
				canvas.draw_rect(gap, fill)
		for cell: Vector2i in info.get("shrines", []):
			var sp := full.position + Vector2(cell) / Vector2(info.size) * full.size
			if at.has_point(sp):
				canvas.draw_rect(Rect2(sp - Vector2(1, 2), Vector2(2, 3)), MapScreen.SHRINE)
		for lock: Dictionary in MapScreen.locked_doors(info):
			var lp := full.position + (Vector2(lock.cell) + Vector2(0.5, 1)) / Vector2(info.size) * full.size
			if at.has_point(lp):
				canvas.draw_rect(Rect2(lp - Vector2(1, 3), Vector2(2, 3)), MapScreen.LOCK)
	# The ways on: a stub of path out of each door that leads somewhere unknown.
	for e: Dictionary in lay.exits:
		var p: Vector2 = at.position + (e.at as Vector2)
		var stub: Rect2
		match String(e.edge):
			"left":
				stub = Rect2(p + Vector2(-EXIT - 1, -0.5), Vector2(EXIT, 1))
			"right":
				stub = Rect2(p + Vector2(1, -0.5), Vector2(EXIT, 1))
			"top":
				stub = Rect2(p + Vector2(-0.5, -EXIT - 1), Vector2(1, EXIT))
			_:
				stub = Rect2(p + Vector2(-0.5, 1), Vector2(1, EXIT))
		stub = stub.intersection(at)
		if stub.size.x > 0.0 and stub.size.y > 0.0:
			canvas.draw_rect(stub, EXIT_COLOR)
	var dot: Vector2 = lay.player
	if dot != Vector2.INF and fmod(t, 0.6) < 0.4:
		var p := at.position + dot
		canvas.draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 4)), MapScreen.OUTLINE)
		canvas.draw_rect(Rect2(p - Vector2(1, 2), Vector2(2, 2)), MapScreen.PLAYER)
	canvas.draw_rect(at, Color(MapScreen.EDGE, 0.35), false, 1.0)
	for b: Rect2 in bracket_rects(at.grow(1)):
		canvas.draw_rect(b, BRACKET_COLOR)
