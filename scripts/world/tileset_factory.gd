class_name TilesetFactory
extends RefCounted
## Builds a zone's TileSet from its generated atlas (tools/art/tilegen.py,
## assets/tiles/<zone>.png) and adds collision.
##
## Ground uses 47 "blob" autotiles: each solid cell picks the tile for which of
## its 8 neighbours are solid too (corners count only when both sides next to
## them are solid). The atlas has them in rows 0-5 in the order of
## `blob_masks()`; row 6 holds the one-way platform, amber, and darker interior
## tiles for wall cells two (MID) or three or more (DEEP) tiles from open air,
## then the two 45-degree slopes (design bible 6.1). Row 7 holds masonry variants
## (full-solid surface plus more MID/DEEP) that `ground()` scatters by cell so a
## large solid field stops reading as a 32 px grid (design bible 12.8).

const TILE := 16
## Render density of the atlases (design bible 12.1): each 16 px world tile is
## drawn from a 32 px atlas tile. Tile layers run at TILE * DENSITY and are
## scaled by 1 / DENSITY (see `layer()`), so cell coordinates stay the same.
const DENSITY := 2
const SOURCE_ID := 0
const COLUMNS := 8
const TILES_DIR := "res://assets/tiles/"
const FALLBACK_ZONE := "gym"

const ONE_WAY := Vector2i(0, 6)
const AMBER := Vector2i(1, 6)
## Darker interior tiles for cells two (MID) or three-plus (DEEP) tiles from open
## air. The last two of each are row-7 variants (tilegen.py) so a darkened field
## does not read as one repeated tile either (design bible 12.8).
const MID: Array[Vector2i] = [Vector2i(2, 6), Vector2i(3, 6), Vector2i(3, 7), Vector2i(4, 7)]
const DEEP: Array[Vector2i] = [Vector2i(4, 6), Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 7)]
## Surface-bright full-solid variants (row 7, cols 0-2): the visible interior of
## a large solid field, scattered by cell so the 32 px repeat unit stops reading.
const FULL_VARIANTS: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)]
## Legend `/`: solid below a diagonal rising to the east.
const SLOPE_EAST := Vector2i(6, 6)
## Legend `\`: solid below a diagonal rising to the west.
const SLOPE_WEST := Vector2i(7, 6)

## Neighbour bits for blob masks.
const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128
const FULL := 255

static var _masks: Array[int] = []
static var _index := {}
static var _cache := {}


## The 47 distinct reduced masks, ascending (tilegen.py builds the same list).
static func blob_masks() -> Array[int]:
	if _masks.is_empty():
		var seen := {}
		for m in 256:
			seen[reduce_mask(m)] = true
		for m: int in seen:
			_masks.append(m)
		_masks.sort()
		for i in _masks.size():
			_index[_masks[i]] = i
	return _masks


## Drops corner bits whose two neighbouring sides are not both solid.
static func reduce_mask(m: int) -> int:
	if not (m & N and m & E):
		m &= ~NE
	if not (m & S and m & E):
		m &= ~SE
	if not (m & S and m & W):
		m &= ~SW
	if not (m & N and m & W):
		m &= ~NW
	return m


## Atlas coordinates of the ground tile for a neighbour mask. `depth` is how
## many tiles the cell is from open air (1 = touching it); deeper cells darken.
static func ground(mask: int, cell := Vector2i.ZERO, depth := 1) -> Vector2i:
	blob_masks()
	var m := reduce_mask(mask)
	if m == FULL:
		# A large field is mostly full-solid cells, so if they all drew one atlas
		# tile the field would band on the 32 px grid. Scatter several masonry
		# variants by cell position (design bible 12.8). Deeper cells keep their
		# darker MID/DEEP look; both now carry variants too.
		var h := absi((cell.x * 73856093) ^ (cell.y * 19349663))
		if depth >= 3:
			return DEEP[h % DEEP.size()]
		if depth >= 2:
			return MID[h % MID.size()]
		var k := h % (FULL_VARIANTS.size() + 1)
		if k > 0:
			return FULL_VARIANTS[k - 1]
	var i: int = _index[m]
	return Vector2i(i % COLUMNS, i / COLUMNS)


static func is_ground(coords: Vector2i) -> bool:
	return coords != ONE_WAY and coords != AMBER and not is_slope(coords)


static func is_slope(coords: Vector2i) -> bool:
	return coords == SLOPE_EAST or coords == SLOPE_WEST


## Builds (and caches) the tileset for a zone. Without collision it is used for
## fake walls (secrets).
static func build(zone := "", with_collision := true) -> TileSet:
	var path := TILES_DIR + zone + ".png"
	if zone == "" or not ResourceLoader.exists(path):
		zone = FALLBACK_ZONE
		path = TILES_DIR + zone + ".png"
	var key := "%s:%s" % [zone, with_collision]
	if _cache.has(key):
		return _cache[key]
	var ts := TileSet.new()
	var size := TILE * DENSITY
	ts.tile_size = Vector2i(size, size)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Player.LAYER_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(size, size)
	ts.add_source(src, SOURCE_ID)

	var half := size * 0.5
	var full := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var lip := 4.0 * DENSITY
	var strip := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + lip), Vector2(-half, -half + lip)])
	var rise_east := PackedVector2Array([Vector2(-half, half), Vector2(half, -half), Vector2(half, half)])
	var rise_west := PackedVector2Array([Vector2(-half, -half), Vector2(half, half), Vector2(-half, half)])
	var all: Array[Vector2i] = [ONE_WAY, AMBER, SLOPE_EAST, SLOPE_WEST]
	all.append_array(MID)
	all.append_array(DEEP)
	all.append_array(FULL_VARIANTS)
	for i in blob_masks().size():
		all.append(Vector2i(i % COLUMNS, i / COLUMNS))
	for coords in all:
		src.create_tile(coords)
		if not with_collision:
			continue
		var data := src.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		if coords == ONE_WAY:
			data.set_collision_polygon_points(0, 0, strip)
			data.set_collision_polygon_one_way(0, 0, true)
		elif coords == SLOPE_EAST:
			data.set_collision_polygon_points(0, 0, rise_east)
		elif coords == SLOPE_WEST:
			data.set_collision_polygon_points(0, 0, rise_west)
		else:
			data.set_collision_polygon_points(0, 0, full)
	_cache[key] = ts
	return ts


## A tile layer for a zone's tileset, scaled so its cells are TILE world pixels.
static func layer(zone := "", with_collision := true) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = build(zone, with_collision)
	l.scale = Vector2.ONE / DENSITY
	GroundFill.attach(l, zone)
	return l
