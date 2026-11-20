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
## large solid field stops reading as a 32 px grid (design bible 12.8). Row 8
## holds the edge variants and row 9 the two haunches (the ceiling's slopes).
## Rows 10 to 12, where a zone has them, hold its patches of other stone.

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
## Edge variants (row 8, design bible 12.53): a floor's top tile, a ceiling's
## bottom tile and a wall's two faces, scattered by cell like the fields, so a
## long floor or ceiling is not one tile from end to end. Their trim lines run
## straight in every variant, so a run still joins. An atlas without row 8
## (Hearthroot's PixelLab set) has none: see `has_edges`.
const TOP_VARIANTS: Array[Vector2i] = [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8)]
const BOTTOM_VARIANTS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8)]
const WEST_VARIANTS: Array[Vector2i] = [Vector2i(6, 8)]
const EAST_VARIANTS: Array[Vector2i] = [Vector2i(7, 8)]
const EDGE_ROWS := 9
## Legend `/`: solid below a diagonal rising to the east.
const SLOPE_EAST := Vector2i(6, 6)
## Legend `\`: solid below a diagonal rising to the west.
const SLOPE_WEST := Vector2i(7, 6)
## Haunches (row 9, design bible 12.78): the ceiling's slopes, where a vault
## curves down into its wall instead of stepping. Legend `` ` ``: solid above a
## diagonal, in the cell's top-left half (a west wall meets the ceiling). Legend
## `'`: the mirror, solid in the top-right half. An atlas without row 9
## (Hearthroot's PixelLab set) has none: see `has_haunches`.
const HAUNCH_WEST := Vector2i(0, 9)
const HAUNCH_EAST := Vector2i(1, 9)
const HAUNCH_ROWS := 10
## Patches of other stone (rows 10 to 12, design bible 12.91): inside a wall, a
## stretch laid in courses of another height. Row 10 is the surface tier, 11 MID
## and 12 DEEP. Each row holds two variants of four tiles: no end joint, a joint
## at the west edge, one at the east edge, and both, for the cells where the
## patch ends. An atlas without these rows has no patches: see `has_patches`.
const PATCH_ROW := 10
const PATCH_ROWS := 13
const PATCH_VARIANTS := 2
## A patch is a few tiles tall and several wide: the noise's lattice, in cells.
const PATCH_SPAN := Vector2i(7, 3)
## The noise's level above which a cell is in a patch (about a quarter of them).
const PATCH_LEVEL := 0.6

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
const EDGE_TOP := FULL & ~(N | NE | NW)
const EDGE_BOTTOM := FULL & ~(S | SE | SW)
const EDGE_WEST := FULL & ~(W | NW | SW)
const EDGE_EAST := FULL & ~(E | NE | SE)

static var _masks: Array[int] = []
static var _index := {}
static var _cache := {}
static var _edges := {}


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
## With `edges` (a zone whose atlas has row 8), a straight edge scatters too.
static func ground(mask: int, cell := Vector2i.ZERO, depth := 1, edges := false) -> Vector2i:
	blob_masks()
	var m := reduce_mask(mask)
	if edges and m != FULL:
		var set := edge_variants(m)
		if not set.is_empty():
			var k := scatter(cell) % (set.size() + 1)
			if k > 0:
				return set[k - 1]
	if m == FULL:
		# A large field is mostly full-solid cells, so if they all drew one atlas
		# tile the field would band on the 32 px grid. Scatter several masonry
		# variants by cell position (design bible 12.8). Deeper cells keep their
		# darker MID/DEEP look; both now carry variants too.
		var h := scatter(cell)
		if depth >= 3:
			return DEEP[h % DEEP.size()]
		if depth >= 2:
			return MID[h % MID.size()]
		var k := h % (FULL_VARIANTS.size() + 1)
		if k > 0:
			return FULL_VARIANTS[k - 1]
	var i: int = _index[m]
	return Vector2i(i % COLUMNS, i / COLUMNS)


## A well-mixed hash of a cell, for choosing its variant. The two products alone
## are not enough: their low bits follow the cell's own low bits, so `% 4` drew
## the same tile every fourth cell along a row and a worn block marched across a
## field on a fixed beat (design bible 12.45).
static func scatter(cell: Vector2i) -> int:
	var h := ((cell.x * 73856093) ^ (cell.y * 19349663)) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	return h ^ (h >> 15)


## The row-8 variants of a straight edge, or none for any other mask.
static func edge_variants(reduced_mask: int) -> Array[Vector2i]:
	match reduced_mask:
		EDGE_TOP:
			return TOP_VARIANTS
		EDGE_BOTTOM:
			return BOTTOM_VARIANTS
		EDGE_WEST:
			return WEST_VARIANTS
		EDGE_EAST:
			return EAST_VARIANTS
	return []


## True if the zone's atlas carries the edge variants (row 8).
static func has_edges(zone: String) -> bool:
	var path := TILES_DIR + zone + ".png"
	if zone == "" or not ResourceLoader.exists(path):
		path = TILES_DIR + FALLBACK_ZONE + ".png"
	if not _edges.has(path):
		var tex: Texture2D = load(path)
		_edges[path] = tex.get_height() >= EDGE_ROWS * TILE * DENSITY
	return _edges[path]


## The patch tile of a cell `depth` tiles from open air. `west_end` and
## `east_end`: the patch stops at that side, so the tile closes its blocks with
## a head joint there.
static func patch(cell: Vector2i, depth := 1, west_end := false, east_end := false) -> Vector2i:
	var variant := (scatter(cell) >> 4) % PATCH_VARIANTS
	return Vector2i(variant * 4 + int(west_end) + 2 * int(east_end), PATCH_ROW + clampi(depth, 1, 3) - 1)


static func is_patch(coords: Vector2i) -> bool:
	return coords.y >= PATCH_ROW and coords.y < PATCH_ROWS


## A slow value noise over the cells, 0 to 1: `PATCH_SPAN` cells to a lattice
## step, so its highs are wide and low, as a stretch of relaid wall is.
static func patch_noise(cell: Vector2i) -> float:
	var fx := float(cell.x) / PATCH_SPAN.x
	var fy := float(cell.y) / PATCH_SPAN.y
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := smoothstep(0.0, 1.0, fx - ix)
	var ty := smoothstep(0.0, 1.0, fy - iy)
	var top := lerpf(_lattice(ix, iy), _lattice(ix + 1, iy), tx)
	var bottom := lerpf(_lattice(ix, iy + 1), _lattice(ix + 1, iy + 1), tx)
	return lerpf(top, bottom, ty)


static func _lattice(x: int, y: int) -> float:
	return float(scatter(Vector2i(x + 7919, y - 104729)) & 0xFFFF) / 65535.0


## True where the noise puts a patch. Whether the cell is drawn as one is the
## room's call (it must be inside a wall, in a zone with patches).
static func in_patch(cell: Vector2i) -> bool:
	return patch_noise(cell) > PATCH_LEVEL


## True if the zone's atlas carries the patches (rows 10 to 12).
static func has_patches(zone: String) -> bool:
	var path := TILES_DIR + zone + ".png"
	if zone == "" or not ResourceLoader.exists(path):
		path = TILES_DIR + FALLBACK_ZONE + ".png"
	var tex: Texture2D = load(path)
	return tex.get_height() >= PATCH_ROWS * TILE * DENSITY


## True if the zone's atlas carries the haunches (row 9).
static func has_haunches(zone: String) -> bool:
	var path := TILES_DIR + zone + ".png"
	if zone == "" or not ResourceLoader.exists(path):
		path = TILES_DIR + FALLBACK_ZONE + ".png"
	var tex: Texture2D = load(path)
	return tex.get_height() >= HAUNCH_ROWS * TILE * DENSITY


static func is_ground(coords: Vector2i) -> bool:
	return coords != ONE_WAY and coords != AMBER and not is_slope(coords)


## True for a floor slope or a haunch: a cell solid on one side of a diagonal.
static func is_slope(coords: Vector2i) -> bool:
	return coords == SLOPE_EAST or coords == SLOPE_WEST or is_haunch(coords)


static func is_haunch(coords: Vector2i) -> bool:
	return coords == HAUNCH_WEST or coords == HAUNCH_EAST


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
	var haunch_west := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half)])
	var haunch_east := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half)])
	var all: Array[Vector2i] = [ONE_WAY, AMBER, SLOPE_EAST, SLOPE_WEST]
	all.append_array(MID)
	all.append_array(DEEP)
	all.append_array(FULL_VARIANTS)
	if has_edges(zone):
		all.append_array(TOP_VARIANTS)
		all.append_array(BOTTOM_VARIANTS)
		all.append_array(WEST_VARIANTS)
		all.append_array(EAST_VARIANTS)
	if has_haunches(zone):
		all.append_array([HAUNCH_WEST, HAUNCH_EAST])
	if has_patches(zone):
		for row in range(PATCH_ROW, PATCH_ROWS):
			for col in COLUMNS:
				all.append(Vector2i(col, row))
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
		elif coords == HAUNCH_WEST:
			data.set_collision_polygon_points(0, 0, haunch_west)
		elif coords == HAUNCH_EAST:
			data.set_collision_polygon_points(0, 0, haunch_east)
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
