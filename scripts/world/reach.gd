class_name Reach
extends RefCounted
## Reachability checker (design bible 14): proves, on the room grids alone,
## which places the player can get to with a given set of abilities, and
## whether they can always get back to a save point.
##
## It is a conservative approximation of the real controller. A node is a
## standing spot: room, tile column x and the tile row y holding the feet, with
## BODY_ROWS clear tiles for the body and support below. Moves are walking, walking
## off ledges (with some drift), jumps within the safe envelope, doors, with
## the Climbing Glove climbing any wall face, and with the Delver's Pick pogo bounces
## off spikes and thorn bulbs (see drop()), and with the Featherstep Boots a higher,
## longer jump (BOOT_JUMP), and from a bounce-pod a much higher one (POD_JUMP), and with the Elven
## Stride an air dash at the top of each (STRIDE_REACH). Numbers are a little under
## the movement spec so a route that passes here is comfortable in play.

## Safe jump envelope in tiles: rise -> max horizontal distance.
const JUMP := {0: 5, 1: 5, 2: 5, 3: 4, 4: 2}
## Rows the body fills, feet row included: four since the 2x hero (pass 508), who stands
## about 60 px tall where the old one stood 46 (every passage was raised to match).
const BODY_ROWS := 4
## Rows from the feet up to the head's row.
const HEAD := BODY_ROWS - 1
## With the Featherstep Boots: a second jump at the top adds three tiles of rise
## (double_jump_height 48) and keeps the player in the air longer. In play the
## feet rise 124 px; seven rows (112 px) keeps the plain jump's 12 px margin
## (pass 235: the Feather Hollow's perch, proven in test_abilities.gd).
const BOOT_JUMP := {0: 7, 1: 7, 2: 7, 3: 6, 4: 6, 5: 5, 6: 3, 7: 2}
## How many rows over the cell you stand in a pickup can be and still be
## touched with a jump. In play the head (40 px tall, a pickup's touch reaching
## 4 px past it) rises 116 px over the feet with a plain jump and 164 px with the
## second: the centre of a pickup six rows up is 104 px over the feet, eight
## rows up 136 px, each with a margin.
const TOUCH_RISE := 6
const BOOT_TOUCH_RISE := 8
## Off a bounce-pod (legend `@`): pod_bounce 600 rises about nine tiles in play.
const POD_JUMP := {0: 5, 1: 5, 2: 5, 3: 5, 4: 5, 5: 5, 6: 4, 7: 3}
## Inside wrong gravity (legend `v`, GravityDrift.PULL 0.4) a jump rises about 11
## tiles and hangs long; past the plain envelope the column must stay drift up to
## the landing height, or the true pull takes hold.
const DRIFT_JUMP := {0: 6, 1: 6, 2: 6, 3: 6, 4: 6, 5: 6, 6: 5, 7: 5, 8: 4, 9: 3}
## Deep water (legend `a`, and `l`, an eel in it): a spot with the feet in water
## is a swimming spot whether or not anything is under it. From one you can swim
## to the water cells beside, above and below; with the head out (no water two
## rows up) you can jump out, a little short of a jump from the floor.
const WATER := "al"
const WATER_JUMP := {0: 4, 1: 4, 2: 4, 3: 3}
## Wind currents (legend `>` east, `<` west; the High Boughs, bible 6.9), reversed
## with the "sky_spring" ability (the Sky Spring restored). A jump whose top
## puts the middle of the body (the row above the feet) in a current is caught:
## it rides the current downwind along that row, and can touch down on any spot
## it passes, drop out (Down) anywhere, or fly out of the band's far end and
## fall. A jump that rises through a current to a top above it, or that runs
## into one sideways, is caught where it meets it and goes no further. Walking
## on a floor in a current is unaffected (you brace).
const WIND := "<>"
## A bounce-pod throws you higher than its landing envelope: a pod launch is
## caught by a current up to this many rows above it.
const POD_CATCH := 9
## With the Elven Stride: dash_speed 380 for 0.15 s is about 3.5 tiles, held level.
const STRIDE_REACH := 3
const DROP_DRIFT := 4
const RISE_FROM_FLOOR_DOOR := 4
## Slopes (`/`, `\`) count as whole blocks: a ramp reads as a stair of
## one-tile steps, which the model climbs with hops, so it never claims more.
const SOLID := "#CJu/\\"
## Ladders (legend `"`, bible 6.11): a spot with the feet on a ladder is a
## standing spot (you hang there), the ladder's top is a plank, and you climb
## to the ladder cells above and below. A jump from a ladder is a full jump.
const LADDER := "\""
## Tiles the body can't stand in (hazards).
const HAZARD := "^o"

var rooms := {}        # room id -> {grid: Array[String], size: Vector2i, doors: {n: {...}}}
var abilities := {}    # ability -> bool
var keys := false      # may Copper doors be opened?

var _edges := {}       # node key -> Array of node keys
# Per-room caches, for speed only (a full flood visits each cell many times):
# solidity for these abilities, and memos of standable() and drop(). A room's
# caches are dropped when its root-gates open.
var _solid := {}       # room id -> Array of bool, row-major
var _stand := {}       # room id -> Array: 0 unknown, 1 no, 2 yes
var _drops := {}       # room id -> Array: -2 unknown, else drop()'s answer
var _climbs := {}      # node key -> where a climb from there leads
var _jumps := {}       # node key and side -> where a jump from there leads
# The room the last query was about, so runs of queries skip the lookups.
var _lr := ""
var _lw := 0
var _lh := 0
var _lsolid: Array = []
var _roots_open := {}  # room id -> true once its Root Heart is in reach


## `catalog_texts`: room id -> room text.
func _init(room_texts: Dictionary, ability_set: Dictionary, can_use_keys := false) -> void:
	abilities = ability_set
	keys = can_use_keys
	for id: String in room_texts:
		var parsed := Room.parse(room_texts[id])
		var grid: Array[String] = parsed.grid
		var width := 0
		for row in grid:
			width = maxi(width, row.length())
		var found := Room.scan_doors(grid)
		var doors := {}
		for spec: String in parsed.lists.get("door", []):
			var parts := spec.split(",")
			var n := int(parts[0])
			if found.has(n):
				doors[n] = {"rect": found[n].rect, "edge": found[n].edge, "target": parts[1].strip_edges(), "target_door": int(parts[2])}
		# Finds laid by `prop:` lines (Room.FOUND_PROPS: the Glass Key, the
		# Elven Helm, the Acorn Charm, the Briar Wand), as [kind, x, y] (pass 203).
		var finds := []
		for spec: String in parsed.lists.get("prop", []):
			var pr := spec.split(",")
			if pr.size() == 3 and pr[2].strip_edges() in Room.FOUND_PROPS:
				finds.append([pr[2].strip_edges(), int(pr[0]), int(pr[1])])
		rooms[id] = {"grid": grid, "size": Vector2i(width, grid.size()), "doors": doors, "finds": finds}


static func key(room_id: String, x: int, y: int) -> String:
	return "%s|%d|%d" % [room_id, x, y]


static func unkey(k: String) -> Array:
	var parts := k.split("|")
	return [parts[0], int(parts[1]), int(parts[2])]


# --- Tile queries ----------------------------------------------------------------

func ch(room_id: String, x: int, y: int) -> String:
	var g: Array[String] = rooms[room_id].grid
	if y < 0 or y >= g.size() or x < 0 or x >= g[y].length():
		return "#" if y >= 0 else "."
	return g[y][x]


func solid(room_id: String, x: int, y: int) -> bool:
	if y < 0:
		return false  # open sky above the room (ch gives ".")
	if room_id != _lr:
		_use(room_id)
	if y >= _lh or x < 0 or x >= _lw:
		return true
	return _lsolid[y * _lw + x]


## Points the fast path at a room, building its solidity map on first use.
func _use(room_id: String) -> void:
	_lr = room_id
	var size: Vector2i = rooms[room_id].size
	_lw = size.x
	_lh = size.y
	if not _solid.has(room_id):
		var map := []
		map.resize(_lw * _lh)
		for y in _lh:
			for x in _lw:
				map[y * _lw + x] = _solid_char(room_id, ch(room_id, x, y))
		_solid[room_id] = map
		var stand := []
		stand.resize(_lw * _lh)
		stand.fill(0)
		_stand[room_id] = stand
		var drops := []
		drops.resize(_lw * _lh)
		drops.fill(-2)
		_drops[room_id] = drops
	_lsolid = _solid[room_id]


## Forgets a room's caches (its root-gates just opened).
func _forget(room_id: String) -> void:
	_solid.erase(room_id)
	_stand.erase(room_id)
	_drops.erase(room_id)
	_lr = ""


## Whether a tile of character `c` in the room blocks the body, for these abilities.
func _solid_char(room_id: String, c: String) -> bool:
	if c == "J":
		return not keys
	if c == "f":
		# Falling water beats you back down; only the Stillstone stills it.
		return not abilities.get("stillstone", false)
	if c == "g":
		# Vorrhallow's upper gate opens with the Sky Key (Skyrend's reward).
		return not abilities.get("sky_key", false)
	if c == "C":
		return not abilities.get("delvers_pick", false)
	if c == "R":
		# A root-gate opens once the room's Root Heart can be struck.
		return not _roots_open.has(room_id)
	if c == "Q":
		# The flue damper stands open once Durgan falls and the winch turns.
		return not abilities.get("winch", false)
	if c == "|":
		# An elven veil lets only a dash through (the Elven Stride).
		return not abilities.get("stride", false)
	if c == "Y":
		# Bound fog parts for the Lantern Key (Gloamweaver's reward).
		return not abilities.get("lantern", false)
	if c == "Z":
		# A fire seal goes out for good once a Deluge bolt strikes it.
		return not abilities.get("torrent", false)
	if c == "k":
		# A conduit gate slides open once Tempest Lance powers the room's conduits.
		return not abilities.get("thunder", false)
	if c == "+":
		# The heart's flesh parts only for the Severance.
		return not abilities.get("severance", false)
	if c == "w":
		# A bramble wall burns away for good under a Emberfall spell.
		return not abilities.get("fire", false)
	if c == "[":
		# A cracked stone seal shatters for good under a Lithic Fracture cast.
		return not abilities.get("fracture", false)
	if c == "~":
		# Sap hardens into solid amber once the Heartwood Spring is restored.
		return abilities.get("amber", false)
	return SOLID.contains(c)


func clear(room_id: String, x: int, y: int) -> bool:
	return not solid(room_id, x, y)


## Room for the body with the feet in row y.
func body_clear(room_id: String, x: int, y: int) -> bool:
	for k in BODY_ROWS:
		if not clear(room_id, x, y - k):
			return false
	return true


func supported(room_id: String, x: int, y: int) -> bool:
	var below := ch(room_id, x, y + 1)
	return solid(room_id, x, y + 1) or below == "-" or below == "i" or below == LADDER or _foothold(room_id, x, y + 1) or (below == "=" and abilities.get("torrent", false)) \
		or (below == "b" and abilities.get("spring_haar", false))


## Time-locked water (`f`): with the Stillstone it freezes into footholds every
## Waterfall.STEP rows up from the bottom of its run.
func _foothold(room_id: String, x: int, y: int) -> bool:
	if ch(room_id, x, y) != "f" or not abilities.get("stillstone", false):
		return false
	var bottom := y
	while ch(room_id, x, bottom + 1) == "f":
		bottom += 1
	return bottom > y and (bottom - y) % Waterfall.STEP == 0


func standable(room_id: String, x: int, y: int) -> bool:
	if room_id != _lr:
		_use(room_id)
	if x < 0 or x >= _lw or y < 0 or y >= _lh:
		return false
	var memo: Array = _stand[room_id]
	var i := y * _lw + x
	if memo[i] == 0:
		var ok := body_clear(room_id, x, y) and (supported(room_id, x, y) or WATER.contains(ch(room_id, x, y)) or ch(room_id, x, y) == LADDER) \
			and not HAZARD.contains(ch(room_id, x, y))
		memo[i] = 2 if ok else 1
	return memo[i] == 2


## Where something falling down column x from row y lands, or -1 if it leaves
## the room (through a floor door) or never lands. With the Delver's Pick, a fall onto
## spikes or a thorn bulb is a pogo: it "lands" just above the hazard, and the
## bounce works like a jump from there.
func drop(room_id: String, x: int, y: int) -> int:
	if room_id != _lr:
		_use(room_id)
	if x < 0 or x >= _lw or y < 0 or y >= _lh:
		return _drop(room_id, x, y)
	var memo: Array = _drops[room_id]
	var i := y * _lw + x
	if memo[i] == -2:
		memo[i] = _drop(room_id, x, y)
	return memo[i]


func _drop(room_id: String, x: int, y: int) -> int:
	var h: int = rooms[room_id].size.y
	var yy := y
	while yy < h:
		if not clear(room_id, x, yy):
			return -1
		if HAZARD.contains(ch(room_id, x, yy)):
			if abilities.get("delvers_pick", false) and yy > y:
				return yy - 1
			return -1
		if supported(room_id, x, yy) or WATER.contains(ch(room_id, x, yy)):
			return yy
		yy += 1
	return -1


# --- The graph ---------------------------------------------------------------------

func neighbors(k: String) -> Array:
	if _edges.has(k):
		return _edges[k]
	var out := []
	var n := Reach.unkey(k)
	var r: String = n[0]
	var x: int = n[1]
	var y: int = n[2]
	for s: int in [-1, 1]:
		# Walk.
		if standable(r, x + s, y):
			out.append(key(r, x + s, y))
		# Walk off a ledge, drifting up to DROP_DRIFT columns while falling.
		elif body_clear(r, x + s, y):
			for dx in range(1, DROP_DRIFT + 1):
				var cx := x + s * dx
				if not body_clear(r, cx, y):
					break
				var land := drop(r, cx, y)
				if land > y:
					out.append(key(r, cx, land))
		# Jumps up, across and down.
		_add_jumps(out, r, x, y, s)
	# Swim up (float) and down (Down held).
	if WATER.contains(ch(r, x, y)):
		for dy: int in [-1, 1]:
			if WATER.contains(ch(r, x, y + dy)) and standable(r, x, y + dy):
				out.append(key(r, x, y + dy))
	# Climb a ladder up and down.
	if ch(r, x, y) == LADDER or ch(r, x, y + 1) == LADDER:
		if ch(r, x, y) == LADDER and standable(r, x, y - 1):
			out.append(key(r, x, y - 1))
		if ch(r, x, y + 1) == LADDER and standable(r, x, y + 1):
			out.append(key(r, x, y + 1))
	# Drop through a one-way platform (Down + Jump).
	# (Frozen water's footholds melt away when time runs again: the same way down.)
	if ch(r, x, y + 1) in ["-", "i"] or _foothold(r, x, y + 1):
		var below := drop(r, x, y + 1)
		if below > y:
			out.append(key(r, x, below))
	if abilities.get("glove", false):
		_add_climbs(out, r, x, y)
	_add_doors(out, r, x, y)
	_edges[k] = out
	return out


## With the Elven Stride, an air dash at the top of any jump carries the body
## STRIDE_REACH tiles further across.
static func _strided(envelope: Dictionary) -> Dictionary:
	var out := {}
	for rise: int in envelope:
		out[rise] = int(envelope[rise]) + STRIDE_REACH
	return out


## A jump from (x, y): rise straight up to the target's height (head room in
## column x), then travel across with the body clear, then land.
func _add_jumps(out: Array, r: String, x: int, y: int, s: int) -> void:
	var k := "%s|%d|%d|%d" % [r, x, y, s]
	if not _jumps.has(k):
		var found := []
		_jump_from(found, r, x, y, s)
		_jumps[k] = found
	out.append_array(_jumps[k])


## Which way the current at (x, y) blows: 1 east, -1 west, 0 none.
func wind_dir(room_id: String, x: int, y: int) -> int:
	var c := ch(room_id, x, y)
	if not WIND.contains(c):
		return 0
	var d := 1 if c == ">" else -1
	# The inner rings's winds never turn (the trials, pass 160).
	if room_id.begins_with("trials/"):
		return d
	return -d if abilities.get("sky_spring", false) else d


## Rides the current that holds a body with its feet at (x, y) downwind: every
## spot it can touch down on or drop out to, and where it falls off the far end.
func _ride(out: Array, r: String, x: int, y: int) -> void:
	var d := wind_dir(r, x, y - 1)
	var cx := x
	while true:
		if standable(r, cx, y):
			out.append(key(r, cx, y))
		var below := drop(r, cx, y + 1) if body_clear(r, cx, y + 1) else -1
		if below > y:
			out.append(key(r, cx, below))
		var nx := cx + d
		if not body_clear(r, nx, y):
			return
		cx = nx
		if wind_dir(r, cx, y - 1) == 0:
			# Out of the far end: on ground there, or falling with the drift it carried.
			if standable(r, cx, y):
				out.append(key(r, cx, y))
				return
			for dx in range(0, DROP_DRIFT + 1):
				var fx := cx + d * dx
				if not body_clear(r, fx, y):
					break
				var land := drop(r, fx, y)
				if land >= 0:
					out.append(key(r, fx, land))
			return


## A body rising up column x from feet row y to `top` meets a current on the way
## (below the top): the row whose feet it is caught at, or -1.
func _caught_rising(r: String, x: int, y: int, top: int) -> int:
	for yy in range(y - 1, top, -1):
		if wind_dir(r, x, yy - 1) != 0:
			return yy
	return -1


func _jump_from(out: Array, r: String, x: int, y: int, s: int) -> void:
	var envelope: Dictionary = BOOT_JUMP if abilities.get("boots", false) else JUMP
	var pod := ch(r, x, y) == "@"
	if pod:
		envelope = POD_JUMP
	var drifting := ch(r, x, y) == "v"
	if drifting:
		envelope = DRIFT_JUMP
	if WATER.contains(ch(r, x, y)):
		if WATER.contains(ch(r, x, y - HEAD)):
			return
		envelope = WATER_JUMP
	if abilities.get("stride", false):
		envelope = _strided(envelope)
	if pod:
		# Caught by a current above the landing envelope's reach.
		for rise in range(envelope.size(), POD_CATCH + 1):
			var top := y - rise
			if not _column_clear(r, x, top - HEAD, y - BODY_ROWS):
				break
			if _caught_rising(r, x, y, top) >= 0:
				break
			if wind_dir(r, x, top - 1) != 0:
				_ride(out, r, x, top)
				break
	for rise: int in envelope:
		var top := y - rise
		if drifting and not JUMP.has(rise) and ch(r, x, top) != "v":
			break
		var ok := true
		for yy in range(top - HEAD, y - HEAD):
			if not clear(r, x, yy):
				ok = false
				break
		if not ok:
			break
		if _caught_rising(r, x, y, top) >= 0:
			break  # a current caught it lower down (that rise rides it)
		if wind_dir(r, x, top - 1) != 0:
			_ride(out, r, x, top)
			continue
		for dx in range(1, int(envelope[rise]) + 1):
			var cx := x + s * dx
			if not body_clear(r, cx, top):
				break
			if wind_dir(r, cx, top - 1) != 0:
				_ride(out, r, cx, top)
				break
			if standable(r, cx, top):
				out.append(key(r, cx, top))
			else:
				var land := drop(r, cx, top)
				if land >= 0:
					out.append(key(r, cx, land))


## With the glove: jump at a wall (straight up, or one column over), then climb
## that column while a wall is beside it, and jump off from any height reached.
func _add_climbs(out: Array, r: String, x: int, y: int) -> void:
	for cx: int in [x, x - 1, x + 1]:
		for lift in range(0, 5):
			var y0 := y - lift
			if not body_clear(r, cx, y0) or not body_clear(r, x, y0):
				break
			out.append_array(_climb(r, cx, y0))


## Everywhere a climb up column cx from row y0 leads (memoized: many nearby
## spots start the same climb).
func _climb(r: String, cx: int, y0: int) -> Array:
	var k := key(r, cx, y0)
	if _climbs.has(k):
		return _climbs[k]
	var out := []
	var yy := y0
	while body_clear(r, cx, yy - 1) and not _body_hurts(r, cx, yy - 1) \
			and (solid(r, cx - 1, yy - 2) or solid(r, cx + 1, yy - 2)):
		yy -= 1
		if standable(r, cx, yy):
			out.append(key(r, cx, yy))
		for s: int in [-1, 1]:
			_add_jumps(out, r, cx, yy, s)
	# Reaching a ceiling door by climbing.
	if yy <= 3:
		_door_at(out, r, cx, 0)
	_climbs[k] = out
	return out


## Whether a body with its feet in row y of column x would touch a hazard
## (no one climbs a wall through thorns).
func _body_hurts(r: String, x: int, y: int) -> bool:
	for yy in range(y - HEAD, y + 1):
		if HAZARD.contains(ch(r, x, yy)):
			return true
	return false


func _add_doors(out: Array, r: String, x: int, y: int) -> void:
	var size: Vector2i = rooms[r].size
	# Side doors: walk into the edge column.
	for s: int in [-1, 1]:
		if x + s == 0 or x + s == size.x - 1:
			for yy in range(y - HEAD, y + 1):
				_door_at(out, r, x + s, yy)
	# Floor doors: fall through a gap.
	for s: int in [-1, 0, 1]:
		var cx := x + s
		var yy := y + (1 if s == 0 else 0)
		while yy < size.y and clear(r, cx, yy):
			if Room.DOOR_CHARS.contains(ch(r, cx, yy)) and yy == size.y - 1:
				_door_at(out, r, cx, yy)
				break
			if s != 0 and supported(r, cx, yy):
				break
			yy += 1
	# Ceiling doors: jump into them.
	if y - HEAD - 4 <= 0:
		var yy := y - BODY_ROWS
		while yy >= 0 and clear(r, x, yy):
			yy -= 1
		if yy < 0:
			_door_at(out, r, x, 0)
	# Inner doors: stand in them.
	if Room.DOOR_CHARS.contains(ch(r, x, y)):
		_door_at(out, r, x, y)


func _door_at(out: Array, r: String, x: int, y: int) -> void:
	var c := ch(r, x, y)
	if not Room.DOOR_CHARS.contains(c):
		return
	var d: Dictionary = rooms[r].doors.get(int(c), {})
	if d.is_empty() or not rooms.has(d.target):
		return
	var arrive: Dictionary = rooms[d.target].doors.get(d.target_door, {})
	if arrive.is_empty():
		return
	var t: String = d.target
	var rect: Rect2i = arrive.rect
	var cx := rect.position.x + rect.size.x / 2
	match arrive.edge:
		"left":
			var land := drop(t, rect.end.x, rect.end.y - 1)
			if land >= 0:
				out.append(key(t, rect.end.x, land))
		"right":
			var land := drop(t, rect.position.x - 1, rect.end.y - 1)
			if land >= 0:
				out.append(key(t, rect.position.x - 1, land))
		"top":
			var land := drop(t, cx, rect.end.y + 2)
			if land >= 0:
				out.append(key(t, cx, land))
		"bottom":
			# Popping up out of a floor door: land on a ledge near the top of the rise.
			var top := rect.position.y - RISE_FROM_FLOOR_DOOR
			for dx in range(-3, 4):
				for yy in range(top, rect.position.y):
					if standable(t, cx + dx, yy):
						out.append(key(t, cx + dx, yy))
		_:
			var land := drop(t, cx, rect.end.y - 1)
			if land >= 0:
				out.append(key(t, cx, land))


# --- Searches ----------------------------------------------------------------------

## Every node reachable from `start`, opening root-gates whose heart comes in
## reach along the way.
func reachable(start: String) -> Dictionary:
	while true:
		var seen := _flood(start)
		var opened := false
		for id: String in rooms:
			if _roots_open.has(id):
				continue
			var g: Array[String] = rooms[id].grid
			for y in g.size():
				var x := g[y].find("N")
				if x >= 0 and touchable(seen, id, x, y):
					_roots_open[id] = true
					_forget(id)
					opened = true
		if not opened:
			return seen
		_edges.clear()
		_climbs.clear()
		_jumps.clear()
	return {}


func _flood(start: String) -> Dictionary:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var k: String = queue.pop_back()
		for nb: String in neighbors(k):
			if not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	return seen


## Nodes in `nodes` that can't get back to any node in `goals`.
func stuck(nodes: Dictionary, goals: Array) -> Array:
	# Reverse edges over the known nodes, then search back from the goals.
	var rev := {}
	for k: String in nodes:
		for nb: String in neighbors(k):
			if not rev.has(nb):
				rev[nb] = []
			rev[nb].append(k)
	var back := {}
	var queue := []
	for g: String in goals:
		if nodes.has(g):
			back[g] = true
			queue.append(g)
	while not queue.is_empty():
		var k: String = queue.pop_back()
		for prev: String in rev.get(k, []):
			if not back.has(prev):
				back[prev] = true
				queue.append(prev)
	var out := []
	for k: String in nodes:
		if not back.has(k):
			out.append(k)
	return out


## Standing spot for the first `ch` found in a room (feet in that tile, or the
## first landing below it for things that float).
func spot_of(room_id: String, marker: String) -> String:
	var g: Array[String] = rooms[room_id].grid
	for y in g.size():
		var x := g[y].find(marker)
		if x >= 0:
			var land := y if standable(room_id, x, y) else drop(room_id, x, y)
			return key(room_id, x, land) if land >= 0 else ""
	return ""


## True if a pickup at tile (x, y) can be touched from some reachable node:
## standing in it, or jumping into it from below: within TOUCH_RISE rows, or
## BOOT_TOUCH_RISE with the Featherstep Boots' second jump (pass 232).
func touchable(nodes: Dictionary, room_id: String, x: int, y: int) -> bool:
	var rise := BOOT_TOUCH_RISE if abilities.get("boots", false) else TOUCH_RISE
	for dy in range(0, rise + 1):
		for dx in range(-1, 2):
			if nodes.has(key(room_id, x + dx, y + dy)):
				if dy <= 2 or _column_clear(room_id, x + dx, y, y + dy):
					return true
	return false


func _column_clear(room_id: String, x: int, from_y: int, to_y: int) -> bool:
	for yy in range(from_y, to_y + 1):
		if not clear(room_id, x, yy):
			return false
	return true
