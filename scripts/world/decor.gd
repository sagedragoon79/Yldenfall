class_name Decor
extends Node2D
## Small pieces that dress a room's surfaces: tufts and fungus on floors, roots
## and ivy hanging from ceilings, shelves on walls (sprites from
## tools/art/decorgen.py in assets/decor/). Scattered deterministically from the
## room id, so a room always looks the same. Pure decoration: no collision.
## Light-giving pieces (the Heartwood's cyan fungus) get a soft pulsing glow.

const DIR := "res://assets/decor/"
## Chance out of 100 for each kind of open cell.
const FLOOR_CHANCE := 30
const CEILING_CHANCE := 24
const WALL_CHANCE := 8
const GLOW_COLORS := {"heartwood": Color("84cbd6"), "hearthroot": Color("f0c02e"), "tower": Color("f09040"), "haar": Color("f0d070"), "boughs": Color("f0e090"), "spires": Color("f0d070"), "vorrhallow": Color("e070e0"), "evercrown": Color("60e8f0"), "sunken": Color("8af0e8"), "trials": Color("e8e4dc")}

## [kind row, variant, cell] for every placed piece.
var pieces: Array = []
var glows: Array[Vector2] = []
## The zone's glow colour, so RoomLight can pool the candle/fungus light onto the
## floor around each glow (design bible 12.10). Resolved in `build`.
var pool_color: Color = Color.WHITE

var _tex: Texture2D
var _meta: Dictionary
var _glow: Node2D
var _t := 0.0


## Scatters decor over `grid`. `skip` holds cells to leave bare (secret covers).
func build(room_id: String, zone: String, grid: Array[String], skip: Dictionary) -> void:
	var path := DIR + zone
	if not ResourceLoader.exists(path + ".png"):
		return
	_tex = load(path + ".png")
	_meta = (load(path + ".json") as JSON).data
	pool_color = GLOW_COLORS.get(zone, Color.WHITE)
	z_index = -1
	var seed_value := room_id.hash()
	for y in grid.size():
		for x in grid[y].length():
			var cell := Vector2i(x, y)
			if _at(grid, cell) != "." or skip.has(cell):
				continue
			var roll := _roll(cell, seed_value)
			var variant := (roll >> 8) % 997
			if _at(grid, cell + Vector2i.DOWN) == "#" and _calm(grid, cell) and roll % 100 < FLOOR_CHANCE:
				_add(0, "floor", variant, cell)
			elif _at(grid, cell + Vector2i.UP) == "#" and _at(grid, cell + Vector2i.DOWN) == "." \
					and _at(grid, cell + Vector2i(0, 2)) == "." and roll % 100 < CEILING_CHANCE:
				_add(1, "ceiling", variant, cell)
			elif _at(grid, cell + Vector2i.UP) == "." and _at(grid, cell + Vector2i.DOWN) == "." and roll % 100 < WALL_CHANCE:
				if _at(grid, cell + Vector2i.LEFT) == "#":
					_add(2, "wall", variant, cell)
				elif _at(grid, cell + Vector2i.RIGHT) == "#":
					_add(3, "wall", variant, cell)
	if not glows.is_empty():
		_glow = Node2D.new()
		_glow.z_index = 2
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_glow.draw.connect(_draw_glow.bind(GLOW_COLORS.get(zone, Color.WHITE)))
		add_child(_glow)
	queue_redraw()


func _process(delta: float) -> void:
	if _glow:
		_t += delta
		_glow.modulate.a = 0.75 + 0.25 * sin(_t * 1.7)


func _add(row: int, kind: String, variant: int, cell: Vector2i) -> void:
	var variants: Array = _meta.get(kind, [])
	if variants.is_empty():
		return
	var v := variant % variants.size()
	pieces.append([row, v, cell])
	var origin := _origin(row, cell)
	for g: Array in variants[v].glow:
		var gx: float = g[0]
		if row == 3:
			gx = _meta.cell[0] - gx
		glows.append(origin + Vector2(gx, g[1]))


## Top-left of a piece's 16x32 (world pixel) sprite: floor pieces stand on the cell's bottom,
## ceiling pieces hang from its top, wall pieces span the cell and the one below.
func _origin(row: int, cell: Vector2i) -> Vector2:
	var p := Vector2(cell * Room.TILE)
	if row == 0:
		return p + Vector2(0, Room.TILE - 32)
	return p


func _draw() -> void:
	if _tex == null:
		return
	# The atlas is drawn at the render density (design bible 12.1): `density`
	# atlas pixels per world pixel.
	var size := Vector2(_meta.cell[0], _meta.cell[1])
	var src_size := size * float(_meta.get("density", 1))
	for piece: Array in pieces:
		var src := Rect2(Vector2(piece[1], piece[0]) * src_size, src_size)
		draw_texture_rect_region(_tex, Rect2(_origin(piece[0], piece[2]), size), src)


func _draw_glow(color: Color) -> void:
	for g in glows:
		_glow.draw_circle(g, 12.0, Color(color, 0.05))
		_glow.draw_circle(g, 7.0, Color(color, 0.08))
		_glow.draw_circle(g, 3.5, Color(color, 0.14))


## No piece next to doors, hazards or things standing on the floor.
func _calm(grid: Array[String], cell: Vector2i) -> bool:
	for dx in [-1, 1]:
		var ch := _at(grid, cell + Vector2i(dx, 0))
		if ch != "." and ch != "#":
			return false
	return true


static func _at(grid: Array[String], cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].length():
		return "#"
	return grid[cell.y][cell.x]


static func _roll(cell: Vector2i, seed_value: int) -> int:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ seed_value
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff
