class_name Room
extends Node2D
## A room built from a text file: a header of `key: value` lines, a `---`
## separator, then an ASCII tile grid. See levels/README.md for the legend.

const TILE := TilesetFactory.TILE
## Props that lay a find, once: the World catalog counts them as treasures (pass 187).
const FOUND_PROPS := ["glass_key", "elven_helm", "pendant", "briar_wand"]
## One screen in tiles (640x360 px). Map cells and room sizes count in screens.
const SCREEN_TILES := Vector2(40, 22.5)
const DOOR_CHARS := "123456789"
## What each zone's ground is made of, for footsteps (design bible 11). A room's
## `surface:` header overrides it; platforms are planks and sap pools are sap.
const ZONE_SURFACES := {"gym": "stone", "hearthroot": "stone", "heartwood": "moss", "tower": "iron", "haar": "mud", "boughs": "plank", "spires": "stone", "vorrhallow": "stone", "evercrown": "moss", "sunken": "stone", "trials": "stone"}

## Room id: its path under res://levels without the extension, e.g. "hearthroot/gate".
## Cells a thorn bulb can grow from (pass 540): ground, mud, cracked stone and
## fake walls, which all look solid.
const THORN_HOLDS := ["#", "u", "C", "%"]

var id := ""
var title := ""
var zone := ""
var header := {}
var size_tiles := Vector2i.ZERO
var spawn_position := Vector2.ZERO
var tiles: TileMapLayer
var secrets: TileMapLayer
## Hidden planks (legend `i`), seen only through the Seer's Lens.
var phantoms: TileMapLayer
var sheen: OnyxSheen
## Door number -> {rect: Rect2 (pixels), edge: "left"/"right"/"top"/"bottom"/"inner",
## target: room id, target_door: int}.
var doors := {}

var _one_way := {}
## Cells of the room's `-` planks (not ladder tops, boardwalks or hidden planks), for `PlankSupports`.
var _planks := {}
var _secret_cells := {}
## Time-locked water cells (legend `f`), gathered into Waterfalls after the grid.
var _falls := {}
## Wrong-gravity cells (legend `v`), gathered into GravityDrifts after the grid.
var _drifts := {}
## Wind cells (legend `>` east, `<` west), by the way they blow as drawn.
var _winds_east := {}
var _winds_west := {}
## Deep water cells (legend `a`), one SwimWater for the room after the grid.
var _water := {}
## Vorrhallow's standing water (the `tide:` header), until Thane Vorrund is at rest.
var tide: Tide
## The stillglass's flesh across the way into its heart (legend `+`), gathered into HeartSeals.
var _seals := {}
## Ladder cells (legend `"`, bible 6.11). The top cell of each is also a plank.
var _ladders := {}
var _sap_cells := {}
var _sap_node: SapPool
## Cells drawn as ground (real walls and fake ones), for picking autotiles.
var _solid_look := {}
## Slope cells (`/`, `\`): ground to their neighbours, but half open air, so
## the ground under a slope stays as light as any surface tile.
var _slope_cells := {}
## Key doors (`J`) that take another card than the Copper: cell -> kind (header `lock: x, y, kind`).
var _locks := {}
## Chests worth more than the room's `chest_gold`: cell -> gold (header `chest: x, y, gold`).
var _chest_gold := {}
var _secret_revealed := false
## People standing here and foes spawned here, for is_town().
var _people := 0
var _foes := 0
var _roots_open := false


func _ready() -> void:
	add_to_group("room")


func _physics_process(delta: float) -> void:
	if secrets == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	var inside := p != null and is_secret_at(p.global_position + Vector2(0, -12))
	var target := 0.25 if inside else 1.0
	secrets.modulate.a = move_toward(secrets.modulate.a, target, delta * 4.0)
	if inside and not _secret_revealed:
		_secret_revealed = true
		# The find chimes once in a journey (pass 465): coming back to a hidden
		# room you already know fades its cover as before, in silence.
		if not GameState.flag("secret:" + id):
			Sfx.play("secret", 0.0)
			GameState.set_flag("secret:" + id)


static func from_file(path: String, room_id := "") -> Room:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Room file missing or empty: " + path)
	var room := Room.new()
	room.id = room_id if room_id != "" else path.trim_prefix("res://levels/").trim_suffix(".room")
	room.build(text)
	return room


static func from_text(text: String, room_id := "") -> Room:
	var room := Room.new()
	room.id = room_id
	room.build(text)
	return room


## Splits room text into {header: Dictionary, lists: {key: [values]}, grid: Array[String]}.
## Keys that may repeat (label, door, sign, npc, secret, prop) are collected in `lists`.
static func parse(text: String) -> Dictionary:
	var lines := text.replace("\r", "").split("\n")
	var header := {}
	var lists := {}
	var grid: Array[String] = []
	var in_grid := not text.contains("\n---")
	for line in lines:
		if not in_grid:
			if line.strip_edges() == "---":
				in_grid = true
				continue
			var colon := line.find(":")
			if colon > 0:
				var key := line.substr(0, colon).strip_edges()
				var value := line.substr(colon + 1).strip_edges()
				if key in ["label", "door", "sign", "npc", "secret", "prop", "lock", "chest"]:
					if not lists.has(key):
						lists[key] = []
					lists[key].append(value)
				else:
					header[key] = value
			continue
		if line.strip_edges() != "":
			grid.append(line)
	return {"header": header, "lists": lists, "grid": grid}


## True when every space-separated condition in `conds` holds: "flag" is set,
## "!flag" is not.
static func flags_hold(conds: String) -> bool:
	for cond: String in conds.strip_edges().split(" ", false):
		if GameState.flag(cond.trim_prefix("!")) == cond.begins_with("!"):
			return false
	return true


## Finds door cells in a grid: door number -> {rect: Rect2i (tiles), edge}.
static func scan_doors(grid: Array[String]) -> Dictionary:
	var found := {}
	var width := 0
	for row in grid:
		width = maxi(width, row.length())
	for y in grid.size():
		for x in grid[y].length():
			var ch := grid[y][x]
			if DOOR_CHARS.contains(ch):
				var n := int(ch)
				var r := Rect2i(x, y, 1, 1)
				if found.has(n):
					r = r.merge(found[n])
				found[n] = r
	var out := {}
	for n: int in found:
		var r: Rect2i = found[n]
		var edge := "inner"
		if r.position.x == 0:
			edge = "left"
		elif r.end.x == width:
			edge = "right"
		elif r.position.y == 0:
			edge = "top"
		elif r.end.y == grid.size():
			edge = "bottom"
		out[n] = {"rect": r, "edge": edge}
	return out


## Room size in screens (for the map), at least 1x1.
static func screens_for(size: Vector2i) -> Vector2i:
	return Vector2i(maxi(1, roundi(size.x / SCREEN_TILES.x)), maxi(1, roundi(size.y / SCREEN_TILES.y)))


func build(text: String) -> void:
	var parsed := Room.parse(text)
	header = parsed.header
	var grid: Array[String] = parsed.grid
	var lists: Dictionary = parsed.lists

	title = header.get("name", "Untitled room")
	zone = header.get("zone", "")
	var width := 0
	for row in grid:
		width = maxi(width, row.length())
	size_tiles = Vector2i(width, grid.size())

	tiles = TilesetFactory.layer(zone)
	tiles.name = "Tiles"
	add_child(tiles)

	# Emissive light pools from the room's fixed sources, drawn just over the raw
	# tiles and under every actor (design bible 12.10). Added here, before the
	# sources and the decor, so it sits beneath them; it gathers them once the
	# room is in the tree (its decor is handed to it after the Decor is built).
	var room_light := RoomLight.new()
	room_light.name = "RoomLight"
	room_light.room = self
	add_child(room_light)

	# Volumetric light shafts raking down the open air (design bible 12.17), drawn
	# behind the tiles so solid geometry occludes them and in front of the backdrop.
	var shaft := LightShaft.new()
	shaft.name = "LightShaft"
	shaft.zone = zone
	shaft.room_size = Vector2(size_tiles * TILE)
	shaft.seed = id.hash()
	add_child(shaft)

	# Which cells look like ground, so each wall tile can match its neighbours.
	var amber := _amber_on()
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] in ["#", "%", "u", "/", "\\"]:
				_solid_look[Vector2i(x, y)] = true
			if grid[y][x] in ["/", "\\"]:
				_slope_cells[Vector2i(x, y)] = true
	for spec: String in lists.get("lock", []):
		var l := spec.split(",")
		if l.size() == 3:
			_locks[Vector2i(int(l[0]), int(l[1]))] = l[2].strip_edges()
	for spec: String in lists.get("chest", []):
		var c := spec.split(",")
		if c.size() == 3:
			_chest_gold[Vector2i(int(c[0]), int(c[1]))] = int(c[2])
	# Hidden rooms: a rectangle of fake wall hides the contents until the player walks in.
	var covers := {}
	for spec: String in lists.get("secret", []):
		var r := spec.split(",")
		if r.size() == 4:
			for y in range(int(r[1]), int(r[3]) + 1):
				for x in range(int(r[0]), int(r[2]) + 1):
					var ch := _char_at(grid, Vector2i(x, y))
					if ch not in ["#", "-"] and not (ch == "~" and amber):
						covers[Vector2i(x, y)] = true
						_solid_look[Vector2i(x, y)] = true

	for y in grid.size():
		var row := grid[y]
		for x in row.length():
			_place(row[x], Vector2i(x, y), grid)
	_place_basins(grid)
	_place_falls()
	for cell: Vector2i in covers:
		if not _secret_cells.has(cell):
			_place_secret(cell)
	if secrets != null or phantoms != null:
		sheen = OnyxSheen.new()
		sheen.room = self
		sheen.cells = _secret_cells
		add_child(sheen)
	var decor := Decor.new()
	decor.name = "Decor"
	add_child(decor)
	decor.build(id, zone, grid, covers)
	# The decor's candle and fungus glows pool their light onto the floor too.
	room_light.decor = decor

	# Ambient-occlusion rim shading where solid edges meet open air.
	var shade := EdgeShade.new()
	shade.name = "EdgeShade"
	add_child(shade)
	shade.setup(_solid_look, size_tiles)

	# What holds each plank run up: a brace, a post or hangers (design bible 12.30).
	if not _planks.is_empty():
		var holds := PlankSupports.new()
		holds.name = "PlankSupports"
		add_child(holds)
		holds.setup(zone, _planks, _solid_look, size_tiles)

	var found := Room.scan_doors(grid)
	for spec: String in lists.get("door", []):
		var parts := spec.split(",")
		if parts.size() < 3:
			push_warning("Bad door line in %s: %s" % [id, spec])
			continue
		var n := int(parts[0])
		if not found.has(n):
			push_warning("Door %d in %s has no cells in the grid" % [n, id])
			continue
		var r: Rect2i = found[n].rect
		doors[n] = {
			"rect": Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE)),
			"edge": found[n].edge,
			"target": parts[1].strip_edges(),
			"target_door": int(parts[2]),
		}
		if found[n].edge == "inner":
			var marker := DoorMarker.new()
			marker.door = n
			_spawn(marker, Vector2((r.position.x + r.size.x * 0.5) * TILE, r.end.y * TILE))

	for spec: String in lists.get("label", []):
		_add_label(spec)
	# Several sign lines on one cell are one tablet that reads whichever holds
	# when it is read (pass 251): "[spring:heartwood] The falls have set." first.
	var tablets := {}
	for spec: String in lists.get("sign", []):
		var parts := spec.split(",", true, 2)
		if parts.size() == 3:
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			if not tablets.has(cell):
				tablets[cell] = LoreTablet.new()
				(tablets[cell] as LoreTablet).zone = zone
				_spawn(tablets[cell], Vector2(cell.x * TILE + TILE * 0.5, (cell.y + 1) * TILE))
			(tablets[cell] as LoreTablet).add_variant(parts[2])

	if not _sap_cells.is_empty():
		_sap_pool()
		_sap_node.falls = SapPool.find_falls(_sap_cells, func(c: Vector2i) -> bool: return _solid_look.has(c))

	# A boss rush's arenas hold only their boss: no one stands in the fight.
	for spec: String in ([] if BossRush.active() else lists.get("npc", [])):
		var parts := spec.split(",")
		# An optional fourth field shows the person only once a world flag is set,
		# or ("!flag") only until it is. Several, space-separated, must all hold
		# (pass 178: "boss:thane_vorrund !boss:clockwork_alpha").
		if parts.size() == 4:
			if not flags_hold(parts[3]):
				continue
			parts.resize(3)
		if parts.size() == 3:
			var npc := Npc.new()
			npc.npc_id = parts[2].strip_edges()
			_people += 1
			_spawn(npc, Vector2(int(parts[0]) * TILE + TILE * 0.5, (int(parts[1]) + 1) * TILE))

	for spec: String in lists.get("prop", []):
		var parts := spec.split(",")
		if parts.size() == 3:
			_add_prop(parts[2].strip_edges(), Vector2(int(parts[0]) * TILE + TILE * 0.5, (int(parts[1]) + 1) * TILE))

	if header.has("boss"):
		var arena := BossArena.new()
		arena.boss_id = header.boss
		arena.room = self
		add_child(arena)

	_restore_purse()


## True once this room's Root Heart has been struck (on this visit or an earlier one).
func root_gates_open() -> bool:
	return _roots_open or (id != "" and GameState.flag("roots:" + id))


## The Root Heart was struck: every root-gate in the room withers open, for good.
func open_root_gates() -> void:
	_roots_open = true
	if id != "":
		GameState.set_flag("roots:" + id)
	for c in get_children():
		if c is RootGate:
			(c as RootGate).retract()
	Sfx.play("crumble", 0.0)


func _add_prop(kind: String, pos: Vector2) -> void:
	match kind:
		"fountain":
			_spawn(Fountain.new(), pos)
		"spring_heartwood":
			var spring := Spring.new()
			spring.spring_id = "heartwood"
			spring.spring_name = "Heartwood Spring"
			_spawn(spring, pos)
		"spring_haar":
			# the Haar Wyrm lies coiled around it: it can be cleared once he is beaten.
			var spring := Spring.new()
			spring.spring_id = "haar"
			spring.spring_name = "Haar Spring"
			spring.text = "The fog thins. Water returns to Hearthroot."
			spring.needs_flag = "boss:haar_wyrm"
			_spawn(spring, pos)
		"spring_sky":
			# The roc nested on it: it can be cleared once Skyrend falls.
			var spring := Spring.new()
			spring.spring_id = "sky"
			spring.spring_name = "Sky Spring"
			spring.text = "The storm breaks. Hearthroot's fountain runs full."
			spring.needs_flag = "boss:skyrend"
			_spawn(spring, pos)
		"house":
			var house := HouseFront.new()
			if zone == "haar":
				# Lampwick's boardwalk houses: its people never left, so they are lit.
				house.style = "haar"
				house.lit_flag = ""
			_spawn(house, pos)
		"lamp":
			# The lantern hangs off the post's arm, over the tile's center.
			_spawn(TownLamp.new(), pos + Vector2(8, -TownLamp.HEIGHT))
		"taproot":
			_spawn(Taproot.new(), pos)
		"crucible":
			_spawn(Crucible.new(), pos)
		"winch":
			_spawn(Winch.new(), pos)
		"forge":
			_spawn(Forge.new(), pos)
		"water_clock":
			_spawn(WaterClock.new(), pos)
		"drowned_statue":
			_spawn(DrownedStatue.new(), pos)
		"aqueduct_spill":
			_spawn(AqueductSpill.new(), pos)
		"evercrown_gate":
			_spawn(CrownGate.new(), pos)
		"trial_goal":
			_spawn(TrialGoal.new(), pos)
		"glass_key", "elven_helm", "pendant", "briar_wand":
			# Found once, never sold: the one Glass Key, the Elven Helm and the
			# original's two relics, the Acorn Charm and the Briar Wand (pass 201;
			# FOUND_PROPS: the World catalog counts them as treasures).
			var item_id := _pickup_id(Vector2i(int(pos.x / TILE), int(pos.y / TILE) - 1))
			if not GameState.is_collected(item_id):
				var item := ItemPickup.new()
				item.kind = kind
				item.pickup_id = item_id
				_spawn(item, pos - Vector2(0, TILE * 0.5))
		"lift":
			var cage := LiftCage.new()
			cage.room_id = id
			_spawn(cage, pos)
		_:
			if kind in SetPiece.NAMES:
				var piece := SetPiece.new()
				piece.sheet = kind
				_spawn(piece, pos)
			else:
				push_warning("Unknown prop in %s: %s" % [id, kind])


## A guardian tears the floor (Gnarlmaw's phase 3, the Bloom's bites): removes
## floor rows `row_from`..`row_to` between the columns, and lines the new pit's
## floor with spikes.
func tear_floor(col_from: int, col_to: int, row_from: int, row_to: int) -> void:
	_keep_set_back_off(col_from, col_to, row_from)
	for x in range(col_from, col_to + 1):
		for y in range(row_from, row_to + 1):
			tiles.erase_cell(Vector2i(x, y))
			_solid_look.erase(Vector2i(x, y))
		var below := Vector2i(x, row_to + 1)
		if tiles.get_cell_source_id(below) != -1:
			_spawn(Spikes.new(), Vector2((x + 0.5) * TILE, below.y * TILE))
	# The ground around the pit gets new edges.
	for x in range(col_from - 3, col_to + 4):
		for y in range(row_from - 3, row_to + 4):
			var cell := Vector2i(x, y)
			if _solid_look.has(cell) and tiles.get_cell_source_id(cell) != -1:
				tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ground(_ground_mask(cell), cell, _depth(cell)))


## The spot a spike sets the player back to (bible 6.13, pass 292) is never over
## floor just torn away: it was the tile they stood on, so a bite that tore the
## leaf from under them had them set back over its thorns until they died. It
## moves to the nearer tile beside the pit. So does a purse lying there (bible
## 5.4, pass 300): left from a death earlier in the fight, it would hang over
## the thorns, and taking it back would cost a mask.
func _keep_set_back_off(col_from: int, col_to: int, row: int) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		var x := _beside_pit(p.safe_position, col_from, col_to, row)
		if not is_nan(x):
			p.safe_position = Vector2(x, row * TILE)
	for c in get_children():
		if not c is GoldPurse or c.is_queued_for_deletion():
			continue
		var bag := c as GoldPurse
		var x := _beside_pit(bag.position, col_from, col_to, row)
		if is_nan(x):
			continue
		bag.position = Vector2(x, row * TILE)
		var kept: Dictionary = GameState.data.get("purse", {})
		if kept.get("room", "") == id:
			kept.x = bag.position.x
			kept.y = bag.position.y


## Where a spot standing on floor about to be torn from `col_from` to `col_to`
## on `row` moves to: the x of the nearer solid tile beside the pit, or NAN if
## the spot is not over the tear (or no tile is left beside it).
func _beside_pit(at: Vector2, col_from: int, col_to: int, row: int) -> float:
	if at.x < col_from * TILE or at.x >= (col_to + 1) * TILE or absf(at.y - row * TILE) > TILE * 0.5:
		return NAN
	var left := (col_from - 0.5) * TILE
	var right := (col_to + 1.5) * TILE
	var sides := [left, right] if at.x - left <= right - at.x else [right, left]
	for x: float in sides:
		if is_solid_at(Vector2(x, row * TILE + TILE * 0.5)):
			return x
	return NAN


func _amber_on() -> bool:
	return zone == "heartwood" and GameState.flag("spring:heartwood")


const _NEIGHBOURS := [
	[Vector2i(0, -1), TilesetFactory.N], [Vector2i(1, -1), TilesetFactory.NE],
	[Vector2i(1, 0), TilesetFactory.E], [Vector2i(1, 1), TilesetFactory.SE],
	[Vector2i(0, 1), TilesetFactory.S], [Vector2i(-1, 1), TilesetFactory.SW],
	[Vector2i(-1, 0), TilesetFactory.W], [Vector2i(-1, -1), TilesetFactory.NW],
]


## How far a ground cell is from open air, in tiles (1 to 3).
func _depth(cell: Vector2i) -> int:
	for r in [1, 2]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := cell + Vector2i(dx, dy)
				var inside := n.x >= 0 and n.y >= 0 and n.x < size_tiles.x and n.y < size_tiles.y
				if inside and (not _solid_look.has(n) or _slope_cells.has(n)):
					return r
	return 3


## Which of a cell's 8 neighbours look like ground. Outside the room counts as ground.
func _ground_mask(cell: Vector2i) -> int:
	var m := 0
	for d: Array in _NEIGHBOURS:
		var n: Vector2i = cell + d[0]
		var outside := n.x < 0 or n.y < 0 or n.x >= size_tiles.x or n.y >= size_tiles.y
		if outside or _solid_look.has(n):
			m |= int(d[1])
	return m


func _place(ch: String, cell: Vector2i, grid: Array[String]) -> void:
	var cell_origin := Vector2(cell * TILE)
	var bottom_center := cell_origin + Vector2(TILE * 0.5, TILE)
	var center := cell_origin + Vector2(TILE, TILE) * 0.5
	match ch:
		"#", "u":
			tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ground(_ground_mask(cell), cell, _depth(cell)))
		"-":
			tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ONE_WAY)
			_one_way[cell] = true
			_planks[cell] = true
		"\"":
			_ladders[cell] = true
			if cell.y == 0 or grid[cell.y - 1].substr(cell.x, 1) != "\"":
				# The ladder's top is a plank: stand on it, Down to climb back on.
				tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ONE_WAY)
				_one_way[cell] = true
		"/":
			tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.SLOPE_EAST)
		"\\":
			tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.SLOPE_WEST)
		"b":
			# A drowned boardwalk: it rises once the Haar Spring flows.
			if GameState.flag(Fog.SPRING_FLAG):
				tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ONE_WAY)
				_one_way[cell] = true
		"%":
			_place_secret(cell)
		"i":
			_place_phantom(cell)
		"f":
			_falls[cell] = true
		"v":
			_drifts[cell] = true
		">":
			_winds_east[cell] = true
		"<":
			_winds_west[cell] = true
		"a":
			_water[cell] = true
		"+":
			_seals[cell] = true
		"~":
			if _amber_on():
				# The restored spring hardens the Heartwood's sap into walkable amber.
				tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.AMBER)
			else:
				_sap_cells[cell] = true
		"^":
			_spawn(Spikes.new(), bottom_center)
		"@":
			_spawn(BouncePod.new(), bottom_center)
		"r":
			_spawn(StrideSeed.new(), center)
		"o":
			var bulb := ThornBulb.new()
			var wall := func(c: Vector2i) -> bool: return _char_at(grid, c) in THORN_HOLDS
			bulb.anchor = ThornBulb.anchor_for(cell, wall)
			if bulb.anchor != Vector2i.ZERO:
				for d: Vector2i in ThornBulb.along(bulb.anchor):
					if _char_at(grid, cell + d) == "o" and ThornBulb.anchor_for(cell + d, wall) == bulb.anchor:
						bulb.links.append(d)
			_spawn(bulb, center)
		"C":
			var block := CrackedBlock.new()
			if zone != "gym" and zone != "":
				# In the real world a broken wall stays broken.
				block.respawns = false
				block.persist_id = _pickup_id(cell)
				if GameState.is_collected(block.persist_id):
					block.free()
					return
			_spawn(block, center)
		"E":
			_spawn(TrainingDummy.new(), bottom_center)
		"M":
			_spawn_enemy(Blinkhop.new(), bottom_center)
		"H":
			_spawn_enemy(Hornet.new(), center)
		"D":
			_spawn_enemy(RotDwarf.new(), bottom_center)
		"T":
			_spawn_enemy(SapSpitter.new(), bottom_center)
		"U":
			_spawn_enemy(GrubLump.new(), center)
		"I":
			_spawn_enemy(IronDwarf.new(), bottom_center)
		"B":
			_spawn_enemy(GearBat.new(), center)
		"K":
			_spawn_enemy(MinecartRider.new(), bottom_center)
		"A":
			_spawn_enemy(LanternGhost.new(), center)
		"V":
			_spawn_enemy(BogPuffcap.new(), bottom_center)
		"p":
			_spawn_enemy(DrownedDwarf.new(), bottom_center)
		"m":
			_spawn_enemy(LeafMantis.new(), bottom_center)
		"!":
			_spawn_enemy(BarkKnight.new(), bottom_center)
		";":
			_spawn_enemy(SeedBomber.new(), center)
		"?":
			_spawn_enemy(MarshHag.new(), bottom_center)
		"t":
			_spawn_enemy(ThunderBeetle.new(), bottom_center)
		"y":
			_spawn_enemy(StormHarpy.new(), center)
		"]":
			_spawn_enemy(SpireSentinel.new(), bottom_center)
		"q":
			_spawn_enemy(CrystalDwarf.new(), bottom_center)
		"e":
			_spawn_enemy(ShadeKnight.new(), bottom_center)
		"j":
			_spawn_enemy(ClockworkHound.new(), bottom_center)
		"s":
			_spawn_enemy(GlassSlug.new(), bottom_center)
		"l":
			# A Spring Eel, in a cell of the water it never leaves.
			_water[cell] = true
			_spawn_enemy(SpringEel.new(), center)
		")":
			_spawn_enemy(SiltAdder.new(), center)
		"R":
			var gate := RootGate.new()
			_spawn(gate, center)
			if root_gates_open():
				gate.retract(true)
		"Q":
			_spawn(FlueDamper.new(), center)
		"|":
			_spawn(StrideVeil.new(), center)
		"Y":
			var curtain := MistCurtain.new()
			curtain.flag_id = "curtain:" + id
			_spawn(curtain, center)
		"c":
			var conduit := Conduit.new()
			if not header.has("boss"):
				# A boss room's conduits are part of the fight and wake afresh each time.
				conduit.flag_id = "conduit:%s:%d,%d" % [id, cell.x, cell.y]
				conduit.room_flag = "conduits:" + id
			_spawn(conduit, bottom_center)
		"k":
			var cgate := ConduitGate.new()
			cgate.flag_id = "conduits:" + id
			_spawn(cgate, center)
		"w":
			var bramble := BrambleWall.new()
			bramble.persist_id = _pickup_id(cell)
			_spawn(bramble, center)
			if GameState.is_collected(bramble.persist_id):
				bramble.set_burnt()
		"Z":
			var seal := FireSeal.new()
			seal.flag_id = "seal:" + id
			_spawn(seal, center)
		"[":
			# A cracked stone seal: only a Lithic Fracture cast breaks it, and it
			# only ever hides an optional cache. It stays broken once shattered.
			var stone := StoneSeal.new()
			stone.persist_id = _pickup_id(cell)
			_spawn(stone, center)
		"N":
			var heart := RootHeart.new()
			heart.room = self
			heart.struck = root_gates_open()
			_spawn(heart, bottom_center)
		"S":
			_spawn(SaveShrine.new(), bottom_center)
		"J", "g":
			var door_id := _pickup_id(cell)
			if not GameState.is_collected(door_id):
				var key_door := KeyDoor.new()
				key_door.persist_id = door_id
				if ch == "g":
					# Vorrhallow's upper gate: Skyrend's Sky Key opens it.
					key_door.kind = "sky"
				elif _locks.has(cell):
					key_door.kind = _locks[cell]
				_spawn(key_door, bottom_center)
		"$":
			var chest := Chest.new()
			chest.pickup_id = _pickup_id(cell)
			chest.value = _chest_gold.get(cell, int(header.get("chest_gold", "100")))
			_spawn(chest, bottom_center)
		"G", "X", "O", "d", "h", "n", "z", "L", "W", "F", "*", "&", "{", "(", "}", ":":
			var item_id := _pickup_id(cell)
			if not GameState.is_collected(item_id):
				var item := ItemPickup.new()
				item.kind = ItemPickup.KIND_BY_CHAR[ch]
				item.pickup_id = item_id
				_spawn(item, center)
		"x":
			var vein := LightVein.new()
			# Once the core is starved its veins stay dark.
			vein.is_cut = GameState.flag("boss:everbloom_veins")
			_spawn(vein, center)
		"P":
			spawn_position = bottom_center


## Each connected block of `f` cells becomes one Waterfall over its bounding box.
func _place_falls() -> void:
	for box in _blocks(_falls):
		var fall := Waterfall.new()
		fall.cells = box
		add_child(fall)
	if not _ladders.is_empty():
		var ladders := Ladders.new()
		ladders.cells = _ladders
		add_child(ladders)
	for box in _blocks(_drifts):
		var drift := GravityDrift.new()
		drift.cells = box
		add_child(drift)
	for pair: Array in [[_winds_east, 1], [_winds_west, -1]]:
		for box in _blocks(pair[0]):
			var wind := WindCurrent.new()
			wind.cells = box
			wind.drawn_dir = pair[1]
			add_child(wind)
	if not _water.is_empty():
		var water := SwimWater.new()
		water.cells = _water
		for c: Vector2i in _water:
			if _solid_look.has(c + Vector2i.UP):
				water.roofed[c] = true
		add_child(water)
	if header.has("tide"):
		_place_tide(int(header.tide))
	for box in _blocks(_seals):
		var seal := HeartSeal.new()
		seal.cells = box
		seal.persist_id = _pickup_id(box.position)
		add_child(seal)


## Standing water (design bible 4.4): from row `row` down to the first tile
## in every column open at that row.
func _place_tide(row: int) -> void:
	tide = Tide.new()
	tide.row = row
	for x in size_tiles.x:
		var y := row
		while y < size_tiles.y and tiles.get_cell_source_id(Vector2i(x, y)) == -1:
			tide.cells[Vector2i(x, y)] = true
			y += 1
	add_child(tide)


## The bounding boxes of each connected block of `cells`.
func _blocks(cells: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var seen := {}
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var box := Rect2i(start, Vector2i.ONE)
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			box = box.merge(Rect2i(c, Vector2i.ONE))
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if cells.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					todo.append(c + d)
		out.append(box)
	return out


## A hidden plank: a one-way platform that is always there but drawn only
## faintly, and only for a player carrying the Seer's Lens (design bible A7).
func _place_phantom(cell: Vector2i) -> void:
	if phantoms == null:
		phantoms = TilesetFactory.layer(zone)
		phantoms.name = "Phantoms"
		phantoms.modulate.a = 0.0
		add_child(phantoms)
	phantoms.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ONE_WAY)
	_one_way[cell] = true


func _place_secret(cell: Vector2i) -> void:
	if secrets == null:
		secrets = TilesetFactory.layer(zone, false)
		secrets.name = "Secrets"
		secrets.z_index = 3
		add_child(secrets)
	secrets.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ground(_ground_mask(cell), cell, _depth(cell)))
	_secret_cells[cell] = true


func _pickup_id(cell: Vector2i) -> String:
	return "%s:%d,%d" % [id, cell.x, cell.y]


func _spawn(node: Node2D, pos: Vector2) -> void:
	node.position = pos
	add_child(node)


func _spawn_enemy(enemy: Enemy, pos: Vector2) -> void:
	# `calm: flag`: once the flag is set the room is a town again, and its foes
	# are gone (the Drowned Market after Thane Vorrund falls, pass 159).
	if header.has("calm") and GameState.flag(String(header.calm)):
		enemy.free()
		return
	_foes += 1
	enemy.respawn_time = float(header.get("enemy_respawn", "0"))
	# Everything that lives in the Everbloom is grown through with its crystal.
	enemy.corrupted = str(header.get("corrupted", "true" if zone == "evercrown" else "false")) == "true"
	_spawn(enemy, pos)


## A town: people live here and no foe or boss does (a calm room counts once
## its flag is set). The hero's hood is down in one.
func is_town() -> bool:
	return _people > 0 and _foes == 0 and not header.has("boss")


## Puts back the gold purse dropped in this room on the last death.
func _restore_purse() -> void:
	var purse: Dictionary = GameState.data.get("purse", {})
	if id == "" or purse.get("room", "") != id:
		return
	var bag := GoldPurse.new()
	bag.value = int(purse.value)
	_spawn(bag, Vector2(float(purse.x), float(purse.y)))


func _char_at(grid: Array[String], cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].length():
		return "."
	return grid[cell.y][cell.x]


func _add_label(spec: String) -> void:
	var parts := spec.split(",", true, 2)
	if parts.size() < 3:
		return
	var label := Label.new()
	label.text = parts[2].strip_edges()
	label.position = Vector2(int(parts[0]) * TILE, int(parts[1]) * TILE)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("d8cfb4"))
	label.add_theme_color_override("font_outline_color", Color("1d1a2b"))
	label.add_theme_constant_override("outline_size", 2)
	label.z_index = -2
	add_child(label)


func pixel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_tiles * TILE))


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


## Each run of `=` tiles is a dry basin's water line; its mud bed (`u`) lies
## below it. See DryBasin.
func _place_basins(grid: Array[String]) -> void:
	for y in grid.size():
		var x := 0
		while x < grid[y].length():
			if grid[y][x] != "=":
				x += 1
				continue
			var start := x
			while x < grid[y].length() and grid[y][x] == "=":
				x += 1
			var bed := y + 1
			while bed < grid.size() and _char_at(grid, Vector2i(start, bed)) != "u":
				bed += 1
			var basin := DryBasin.new()
			basin.room = self
			basin.x0 = start
			basin.x1 = x - 1
			basin.water_row = y
			basin.bed_row = bed
			if header.has("boss"):
				# A boss arena's basins are part of the fight: dry again on every
				# try, and full for good once the boss is beaten.
				basin.start_full = GameState.flag("boss:" + str(header.boss))
			else:
				basin.flag_id = "basin:%s:%d" % [id, start]
			add_child(basin)


## A filled basin's raft: the `=` row from x0 to x1 becomes a one-way platform.
func float_raft(x0: int, x1: int, row: int) -> void:
	for x in range(x0, x1 + 1):
		var cell := Vector2i(x, row)
		tiles.set_cell(cell, TilesetFactory.SOURCE_ID, TilesetFactory.ONE_WAY)
		_one_way[cell] = true


## How hard this room's foes and guardians hit (CombatTuning.ZONE_THREAT,
## design bible 5.5; a boss's arena too since pass 196).
func threat() -> float:
	return float(CombatTuning.ZONE_THREAT.get(zone, 1.0))


## True if the tile under `world_pos` is solid ground (not a one-way platform).
func is_solid_at(world_pos: Vector2) -> bool:
	var cell := cell_at(world_pos)
	if tiles.get_cell_source_id(cell) == -1:
		return false
	var coords := tiles.get_cell_atlas_coords(cell)
	if TilesetFactory.is_slope(coords):
		# Solid below the diagonal only.
		var local := world_pos - Vector2(cell * TILE)
		var floor_y := TILE - local.x if coords == TilesetFactory.SLOPE_EAST else local.x
		return local.y >= floor_y
	return coords != TilesetFactory.ONE_WAY


## True if `world_pos` is on a ladder (bible 6.11).
func is_ladder_at(world_pos: Vector2) -> bool:
	return _ladders.has(cell_at(world_pos))


## The x of the middle of the ladder at `world_pos`.
func ladder_x(world_pos: Vector2) -> float:
	return (cell_at(world_pos).x + 0.5) * TILE


## The y of the top of the ladder at `world_pos` (the top of its highest rung's
## cell, where its plank is), or -INF if there is no ladder there.
func ladder_top(world_pos: Vector2) -> float:
	var cell := cell_at(world_pos)
	if not _ladders.has(cell):
		return -INF
	while _ladders.has(cell + Vector2i.UP):
		cell += Vector2i.UP
	return float(cell.y * TILE)


func is_one_way_at(world_pos: Vector2) -> bool:
	return _one_way.has(cell_at(world_pos))


## The ground under `world_pos` (a point just below the feet) for footsteps:
## "stone", "moss", "mud", "plank", "iron", "sap" or "wade" (standing water),
## or "" in mid-air.
func surface_at(world_pos: Vector2) -> String:
	if is_sap_at(world_pos + Vector2(0, -TILE * 0.5)):
		return "sap"
	if is_one_way_at(world_pos):
		return "plank"
	if tide != null and tide.has_point(world_pos + Vector2(0, -TILE * 0.5)):
		# Wading Vorrhallow's standing water (its own slosh since pass 262).
		return "wade"
	var cell := cell_at(world_pos)
	if tiles.get_cell_source_id(cell) == -1:
		return ""
	return str(header.get("surface", ZONE_SURFACES.get(zone, "stone")))


## True if `world_pos` is inside a fake wall (a secret passage).
func is_secret_at(world_pos: Vector2) -> bool:
	return _secret_cells.has(cell_at(world_pos))


## True if `world_pos` is inside a sap pool (slows the player).
func is_sap_at(world_pos: Vector2) -> bool:
	return _sap_cells.has(cell_at(world_pos))


## A Sap Spitter's glob lands: a puddle of sap, up to three tiles wide, on the
## floor around `world_pos`, that slows like a pool and dries after `seconds`.
## Returns the cells it covered (none in mid-air or where sap already is).
func splash_sap(world_pos: Vector2, seconds: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at := cell_at(world_pos)
	for dx in [0, -1, 1]:
		var c: Vector2i = at + Vector2i(dx, 0)
		if _sap_cells.has(c) or tiles.get_cell_source_id(c) != -1 or not is_solid_at(Vector2(c + Vector2i.DOWN) * TILE + Vector2(8, 8)):
			continue
		_sap_cells[c] = true
		out.append(c)
	if out.is_empty():
		return out
	_sap_pool()
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		for c in out:
			_sap_cells.erase(c))
	return out


func _sap_pool() -> SapPool:
	if _sap_node == null:
		_sap_node = SapPool.new()
		_sap_node.cells = _sap_cells
		add_child(_sap_node)
	return _sap_node


## True when the header asks for the wide camera (`camera: wide`, design bible 6.7).
func wide_camera() -> bool:
	return str(header.get("camera", "")) == "wide"
