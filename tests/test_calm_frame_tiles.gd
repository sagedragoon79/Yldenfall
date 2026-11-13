extends TestSuite
## Calm frame tiles (design bible 12.45, pass 555). The solid fields that frame a
## room must not shout over the play field: the Tower's plates and Vorrhallow's
## blocks share one body value with the odd worn block, the High Boughs' wood is
## long strands rather than striped noise, and the factory's variant scatter has
## no beat along a row.

const PX := 32  # one tile in the atlas (TILE * DENSITY)
const HALF := 16  # a Tower plate, and half a Vorrhallow block
## A worn block sits a whole ramp step under the body: about 20 in luminance
## (0 to 255) at every depth tier. Same-value blocks differ by under 6.
const WORN_GAP := 10.0


func _atlas(zone: String) -> Image:
	var tex := load(TilesetFactory.TILES_DIR + zone + ".png") as Texture2D
	return tex.get_image()


func _tiers() -> Array:
	var full: Array[Vector2i] = [TilesetFactory.ground(TilesetFactory.FULL)]
	# ground() with the default cell may return a variant; the base is the one
	# coord of a field that is not in FULL_VARIANTS.
	for y in 8:
		for x in 8:
			var c := TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), 1)
			if not TilesetFactory.FULL_VARIANTS.has(c):
				full = [c]
	full.append_array(TilesetFactory.FULL_VARIANTS)
	return [full, TilesetFactory.MID, TilesetFactory.DEEP]


## The mean luminance (0 to 255) of one 16 px quarter of a tile.
func _quarter(img: Image, tile: Vector2i, q: Vector2i) -> float:
	var total := 0.0
	for y in HALF:
		for x in HALF:
			total += img.get_pixel(tile.x * PX + q.x * HALF + x, tile.y * PX + q.y * HALF + y).get_luminance()
	return total / float(HALF * HALF) * 255.0


## How many of a zone's interior blocks are worn (darker than their tier's body
## by a ramp step), and how many blocks there are.
func _worn(zone: String) -> Vector2i:
	var img := _atlas(zone)
	var worn := 0
	var blocks := 0
	for tier: Array in _tiers():
		var lums: Array[float] = []
		for tile: Vector2i in tier:
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				lums.append(_quarter(img, tile, q))
		var sorted := lums.duplicate()
		sorted.sort()
		var body: float = sorted[sorted.size() / 2]
		for l in lums:
			blocks += 1
			if l < body - WORN_GAP:
				worn += 1
			check(l < body + WORN_GAP, "%s: no block stands a step brighter than its tier's body (%.1f against %.1f)" % [zone, l, body])
	return Vector2i(worn, blocks)


func test_plates_and_blocks_share_one_body_value() -> void:
	# The coin toss between two values made a checkerboard a whole shade deep
	# (about half the blocks worn). Now a few are: more than none, so the field
	# is not one flat value, and under a quarter, so it is not a checker.
	for zone in ["tower", "vorrhallow"]:
		var w := _worn(zone)
		check(w.y == 48, "%s: 12 interior tiles of 4 blocks were measured, got %d" % [zone, w.y])
		check(w.x >= 2, "%s: a few blocks are worn, got %d" % [zone, w.x])
		check(w.x * 4 < w.y, "%s: under a quarter of the blocks are worn, got %d of %d" % [zone, w.x, w.y])


func test_the_tide_stain_is_not_on_every_tile() -> void:
	# Vorrhallow's teal tide line used to cross every tile at the same height,
	# ruling a stripe through a field every tile. It now marks some interior
	# tiles and no edge tile (an edge has no variants, so its stain would repeat
	# down every wall face).
	var img := _atlas("vorrhallow")
	var stained := 0
	var interior := 0
	for tier: Array in _tiers():
		for tile: Vector2i in tier:
			interior += 1
			if _teal(img, tile) > 0:
				stained += 1
	check(stained >= 1, "some interior tiles carry the tide stain, got %d" % stained)
	check(stained * 2 <= interior, "at most half the interior tiles carry it, got %d of %d" % [stained, interior])
	# The wall faces: full height, open to one side.
	var west_open := TilesetFactory.FULL & ~(TilesetFactory.W | TilesetFactory.NW | TilesetFactory.SW)
	var east_open := TilesetFactory.FULL & ~(TilesetFactory.E | TilesetFactory.NE | TilesetFactory.SE)
	for mask: int in [west_open, east_open]:
		check(_teal(img, TilesetFactory.ground(mask)) == 0, "a wall face (mask %d) has no tide stain" % mask)


## Teal pixels in a tile's tide rows: blue well above red, as no stone is.
func _teal(img: Image, tile: Vector2i) -> int:
	var n := 0
	for y in range(20, 28):
		for x in PX:
			var c := img.get_pixel(tile.x * PX + x, tile.y * PX + y)
			if c.b > c.r * 1.6 and c.g > c.r * 1.2:
				n += 1
	return n


func test_the_boughs_wood_is_long_strands() -> void:
	# The old bough face changed colour between a third of its neighbouring
	# pixels (a sine grain down every column). Long strands change far less, and
	# hardly at all going down a column.
	var img := _atlas("boughs")
	var tiles: Array = _tiers()[0]
	var across := 0
	var down := 0
	var pairs := 0
	for tile: Vector2i in tiles:
		for y in PX - 1:
			for x in PX - 1:
				var p := img.get_pixel(tile.x * PX + x, tile.y * PX + y)
				pairs += 1
				if not p.is_equal_approx(img.get_pixel(tile.x * PX + x + 1, tile.y * PX + y)):
					across += 1
				if not p.is_equal_approx(img.get_pixel(tile.x * PX + x, tile.y * PX + y + 1)):
					down += 1
	check(pairs > 0 and float(across + down) / float(2 * pairs) < 0.23,
		"under 23%% of neighbouring pixels differ in the bough fill, got %.3f" % (float(across + down) / float(2 * pairs)))
	check(float(down) / float(pairs) < 0.06,
		"a strand runs down the tile: under 6%% of pixels differ from the one below, got %.3f" % (float(down) / float(pairs)))


func test_the_variant_scatter_has_no_beat_along_a_row() -> void:
	# The old hash's low bits followed the cell's, so every fourth cell of a row
	# drew the same tile and a worn block marched across a field at a fixed step.
	# For every short step, a cell and the one that many along must often differ.
	for depth in [1, 2, 3]:
		for step in range(1, 9):
			var same := 0
			var total := 0
			for y in 24:
				for x in 64:
					total += 1
					if TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), depth) \
							== TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x + step, y), depth):
						same += 1
			# Four tiles to choose from: a quarter match by chance.
			check(same * 100 < total * 40, "depth %d: cells %d apart along a row match %d of %d times (a beat)" % [depth, step, same, total])
			check(same * 100 > total * 12, "depth %d: cells %d apart sometimes match (%d of %d): a scatter, not a rule" % [depth, step, same, total])
	# And down a column.
	for step in range(1, 9):
		var same := 0
		for y in 64:
			for x in 24:
				if TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), 2) \
						== TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y + step), 2):
					same += 1
		check(same * 100 < 64 * 24 * 40, "cells %d apart down a column match %d of 1536 times (a beat)" % [step, same])


func test_the_scatter_still_uses_every_variant_evenly() -> void:
	for depth in [1, 2, 3]:
		var count := {}
		for y in 32:
			for x in 32:
				var c := TilesetFactory.ground(TilesetFactory.FULL, Vector2i(x, y), depth)
				count[c] = int(count.get(c, 0)) + 1
		check(count.size() == 4, "depth %d draws four tiles, got %d" % [depth, count.size()])
		for c: Vector2i in count:
			check(count[c] > 180 and count[c] < 340, "depth %d: tile %s takes about a quarter of 1024 cells, got %d" % [depth, c, count[c]])
