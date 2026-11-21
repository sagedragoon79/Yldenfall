class_name SoffitShade
extends Node2D
## Mass that hangs over open air is in shadow (design bible 12.102, pass 626).
## The tiers (12.8) and `DeepShade` (12.38) darken ground by its distance from
## open air and do not ask which way the air lies, so the lowest course of a
## ceiling was as bright as the top of a lit floor, with only `EdgeShade`'s 7 px
## rim under it. The key light is above (12.3): a soffit faces away from it.
##
## - A cell with open air under it (or a haunch, whose diagonal is an underside)
##   is a **source**, at full shade.
## - The shade climbs the mass above a source, a `RISE` a cell, and never falls
##   below `HOLD`: everything that overhangs air stays in shadow up to where
##   `DeepShade` takes over, so no lit band is left inside a ceiling.
## - It spreads sideways a `SPREAD` a cell, so a ceiling feathers into the wall
##   it springs from over two or three cells and never ends at a seam.
## - A cell with open air above it is a walking surface and takes none, so a
##   ledge's lit top is kept; a floor has no air under it and takes none either.
##
## The field is blended between cell centres and quantised with `DeepShade`'s
## ordered dither, so it is pixelled steps. Baked into one texture per room
## load and drawn over the tiles and under the actors. Secret cells are drawn by a second shade on the
## secret layer, as `DeepShade`'s are.

const TILE := 16
const COLOR := Color(0.0, 0.0, 0.02)
## What the shade loses per cell climbed above a source.
const RISE := 0.25
## The least shade anywhere straight above a source.
const HOLD := 0.5
## What it loses per cell sideways.
const SPREAD := 0.3
## Opacity at a source.
const MAX_ALPHA := 0.58
const LEVELS := 4
const GRAIN := DeepShade.GRAIN

## The shade, one pixel per `GRAIN` block, baked once per setup and drawn as
## one texture: no cost per frame.
var _image: Image
var _texture: ImageTexture
var _blocks := 0


## `solids` is the room's ground look over the `size` grid. `haunches` are the
## cells solid on one side of a diagonal (cell -> true for a west haunch);
## `slopes` are the other half-open cells, which take no shade. When `only` is
## not empty, only those cells are drawn; cells in `skip` never are.
func setup(solids: Dictionary, size: Vector2i, haunches := {}, slopes := {}, only := {}, skip := {}) -> void:
	var field := shade_field(solids, size, haunches, slopes)
	_image = build_image(field, size, solids, haunches, slopes, only, skip)
	_blocks = 0
	_texture = null
	if _image != null:
		_blocks = _image.get_meta("blocks", 0)
		if _blocks > 0:
			_texture = ImageTexture.create_from_image(_image)
	queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _open(solids: Dictionary, size: Vector2i, slopes: Dictionary, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	return not solids.has(cell) or slopes.has(cell)


## True if `cell` is ground with open air under it, or a haunch.
static func is_source(solids: Dictionary, size: Vector2i, haunches: Dictionary, slopes: Dictionary, cell: Vector2i) -> bool:
	if haunches.has(cell):
		return true
	if not solids.has(cell) or slopes.has(cell):
		return false
	var below := cell + Vector2i.DOWN
	return _open(solids, size, slopes, below) and not haunches.has(below)


## The shade 0..1 of every cell, row major. Open cells carry the most of their
## neighbours' shade, so the blend holds its value up to an edge.
static func shade_field(solids: Dictionary, size: Vector2i, haunches := {}, slopes := {}) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(size.x * size.y)
	var ground := PackedByteArray()
	ground.resize(size.x * size.y)
	for y in range(size.y - 1, -1, -1):
		var row := y * size.x
		for x in size.x:
			var cell := Vector2i(x, y)
			var is_ground := haunches.has(cell) or (solids.has(cell) and not slopes.has(cell))
			if not is_ground:
				continue
			# A walking surface keeps its light.
			if not haunches.has(cell) and _open(solids, size, slopes, cell + Vector2i.UP):
				continue
			ground[row + x] = 1
			var v := 0.0
			if is_source(solids, size, haunches, slopes, cell):
				v = 1.0
			elif y + 1 < size.y and ground[row + size.x + x] == 1:
				var under := f[row + size.x + x]
				v = maxf(HOLD, under - RISE) if under >= HOLD else maxf(0.0, under - RISE)
			f[row + x] = v
		for x in range(1, size.x):
			if ground[row + x] == 1 and ground[row + x - 1] == 1:
				f[row + x] = maxf(f[row + x], f[row + x - 1] - SPREAD)
		for x in range(size.x - 2, -1, -1):
			if ground[row + x] == 1 and ground[row + x + 1] == 1:
				f[row + x] = maxf(f[row + x], f[row + x + 1] - SPREAD)
	# Open cells and walking surfaces hold their neighbours' most, for the blend
	# only: they are never drawn darker than their own rule allows.
	var held := f.duplicate()
	for y in size.y:
		for x in size.x:
			if ground[y * size.x + x] == 1:
				continue
			var cell := Vector2i(x, y)
			if solids.has(cell) and not slopes.has(cell):
				continue # a walking surface stays at 0 and pulls the blend down
			var most := 0.0
			for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(1, -1)]:
				var n := cell + d
				if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and ground[n.y * size.x + n.x] == 1:
					most = maxf(most, f[n.y * size.x + n.x])
			held[y * size.x + x] = most
	return held


static func level_at(v: float, b: Vector2i) -> int:
	if v <= 0.0:
		return 0
	return clampi(roundi(v * LEVELS + DeepShade.dither(b)), 0, LEVELS)


static func alpha_for(level: int) -> float:
	return MAX_ALPHA * float(level) / LEVELS


## True if the block centred at `local` (px inside its cell) is in the solid
## half of a haunch; `west` is the haunch solid in its top-left half.
static func in_haunch(local: Vector2, west: bool) -> bool:
	return local.x + local.y < TILE if west else local.y < local.x


## The shade as an image, one pixel per `GRAIN` block (null for an empty room).
## Its "blocks" meta counts the blocks drawn.
static func build_image(field: PackedFloat32Array, size: Vector2i, solids: Dictionary, haunches := {}, slopes := {}, only := {}, skip := {}) -> Image:
	if size.x <= 0 or size.y <= 0:
		return null
	var per := TILE / GRAIN
	var img := Image.create_empty(size.x * per, size.y * per, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = []
	for level in LEVELS + 1:
		colors.append(Color(COLOR, alpha_for(level)))
	var blocks := 0
	var n := PackedFloat32Array()
	n.resize(9)
	var step := 1.0 / per
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if skip.has(cell) or (not only.is_empty() and not only.has(cell)):
				continue
			var haunch := haunches.has(cell)
			if not haunch and (not solids.has(cell) or slopes.has(cell)):
				continue
			# The cell and the eight round it decide every blend inside it.
			var lo := INF
			var hi := 0.0
			var k := 0
			for ny in range(y - 1, y + 2):
				var row := clampi(ny, 0, size.y - 1) * size.x
				for nx in range(x - 1, x + 2):
					var v := field[row + clampi(nx, 0, size.x - 1)]
					n[k] = v
					k += 1
					lo = minf(lo, v)
					hi = maxf(hi, v)
			if hi <= 0.0:
				continue
			# Even shade on a whole step (the HOLD of a thick ceiling) fills the
			# cell: the dither never moves a whole step.
			if lo == hi and not haunch and absf(lo * LEVELS - roundf(lo * LEVELS)) < 0.01:
				img.fill_rect(Rect2i(x * per, y * per, per, per), colors[roundi(lo * LEVELS)])
				blocks += per * per
				continue
			var west: bool = haunch and haunches[cell]
			for by in per:
				# Blend between cell centres: above the centre row or below it.
				var qy := (by + 0.5) * step - 0.5
				var r0 := 0 if qy < 0.0 else 3
				var ty := qy + 1.0 if qy < 0.0 else qy
				for bx in per:
					if haunch and not in_haunch(Vector2(bx + 0.5, by + 0.5) * GRAIN, west):
						continue
					var qx := (bx + 0.5) * step - 0.5
					var c0 := 0 if qx < 0.0 else 1
					var tx := qx + 1.0 if qx < 0.0 else qx
					var i := r0 + c0
					var v := lerpf(lerpf(n[i], n[i + 1], tx), lerpf(n[i + 3], n[i + 4], tx), ty)
					var lvl := level_at(v, Vector2i(x * per + bx, y * per + by))
					if lvl > 0:
						img.set_pixel(x * per + bx, y * per + by, colors[lvl])
						blocks += 1
	img.set_meta("blocks", blocks)
	return img


## The step drawn at world pixel `px` (for tests): 0 where nothing is drawn.
func level_at_pixel(px: Vector2) -> int:
	if _image == null:
		return 0
	var b := Vector2i((px / GRAIN).floor())
	if b.x < 0 or b.y < 0 or b.x >= _image.get_width() or b.y >= _image.get_height():
		return 0
	return roundi(_image.get_pixel(b.x, b.y).a / MAX_ALPHA * LEVELS)


## How many `GRAIN` blocks carry shade.
func block_count() -> int:
	return _blocks


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_image.get_size()) * GRAIN), false)
