class_name DeepShade
extends Node2D
## Solid mass falls off into darkness away from the walkable edge (design bible
## 12.38, pass 547). The tilesets have three depths of ground tile (the lit edge,
## one step in, and the interior), so every cell three or more tiles from open
## air drew the same interior tile: a big off-room mass read as one flat cobble
## field with its studs repeating to the frame. Now the interior sinks into
## shadow the deeper it lies, so the lit rock hugs the rooms and the rest of the
## mass reads as depth:
##
## - each solid cell's distance to the nearest open cell (8-way, in tiles) gives
##   a darkness, nothing within `START` tiles, near-black by `START + SPAN`;
## - the field is blended between cell centres, then quantised to `LEVELS`
##   steps with a 4 x 4 ordered dither in `GRAIN`-pixel blocks, so the falloff is
##   pixelled steps, never a smooth gradient or a hard ring;
## - the room's outer boundary counts as solid, so the mass past the frame sinks
##   too.
##
## It draws over the tiles and `EdgeShade`, under the actors, once per room load
## (and again when a guardian tears the floor), with no per-frame cost. Secret
## cells are left out of the main shade and drawn by a second shade parented to
## the secret layer, so it fades with the fake wall and a hidden room is never
## left dark once found.
##
## What the deep holds (design bible 12.123, pass 647): the deepest mass is not
## left a flat near-black. The pass 645 grade read the grub burrows' upper mass
## as "dead voids". Over the full shade each zone's buried matter shows faintly:
## roots in the woods and the marsh, crystal veins in the two crystal halls,
## broken bedding seams in the stone zones. Each stroke is a few tiles long and
## drawn in 2-pixel blocks, a dark body with a dim lit edge, only where the shade
## is at or near full, so the lit rock round a room is never touched.

const TILE := 16
## Near-black with the same faint cool bias as `EdgeShade`.
const COLOR := Color(0.0, 0.0, 0.02)
## Distance in tiles where the falloff begins: the tilesets' own interior tile
## starts at 3, so the lit edge and the step in are never touched.
const START := 2.5
## Tiles from START to full darkness.
const SPAN := 4.0
## Opacity at full darkness: a trace of the rock still shows at the very back.
const MAX_ALPHA := 0.86
## Quantised steps of darkness.
const LEVELS := 5
## Dither block size, world px.
const GRAIN := 2

const _BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

var _solids: Dictionary
var _size: Vector2i
var _only: Dictionary
var _skip: Dictionary
var _field: PackedFloat32Array
## The rects to fill, built once per setup: [Rect2, alpha] pairs.
var _rects: Array = []
var _zone := ""
var _seed := 0
## The deep's forms, built once per setup: [Rect2, Color] pairs, drawn over the shade.
var _motif: Array = []
## Whether the ground under a floor stops at the floor shade's full darkness (pass 681).
var _floors := false
## Each form's bounds, for tests.
var _strokes: Array[Rect2] = []

## The forms each zone's deep mass holds.
const MOTIF := {
	"heartwood": "roots", "boughs": "roots", "haar": "roots",
	"evercrown": "veins", "vorrhallow": "veins",
	"tower": "strata", "trials": "strata", "hearthroot": "strata", "spires": "strata", "sunken": "strata",
}
## A form's dark body and its dim lit edge, by zone (master palette, tools/art/palette.py).
const MOTIF_COLORS := {
	"heartwood": [Color8(0x48, 0x20, 0x1e), Color8(0x78, 0x3c, 0x2b)],
	"boughs": [Color8(0x48, 0x20, 0x1e), Color8(0x78, 0x3c, 0x2b)],
	"haar": [Color8(0x2f, 0x39, 0x2d), Color8(0x4f, 0x5c, 0x47)],
	"evercrown": [Color8(0x42, 0x1e, 0x48), Color8(0xa7, 0x36, 0xaa)],
	"vorrhallow": [Color8(0x1e, 0x31, 0x48), Color8(0x36, 0x77, 0xaa)],
	"tower": [Color8(0x2f, 0x2c, 0x3a), Color8(0x4a, 0x46, 0x5d)],
	"trials": [Color8(0x2f, 0x2c, 0x3a), Color8(0x4a, 0x46, 0x5d)],
	"hearthroot": [Color8(0x48, 0x20, 0x1e), Color8(0x78, 0x3c, 0x2b)],
	"spires": [Color8(0x50, 0x16, 0x23), Color8(0x86, 0x1d, 0x25)],
	"sunken": [Color8(0x1e, 0x31, 0x48), Color8(0x2b, 0x52, 0x78)],
}
## A form is drawn only where the shade's field is at least this (full is 1).
const MOTIF_FROM := 0.8
## The body's and the lit edge's opacity where the field is full.
const MOTIF_BODY_A := 0.62
const MOTIF_LIT_A := 0.55
## Deep cells per form.
const MOTIF_CELLS := 6
## The most forms one room builds: the rooms with the most deep mass (the
## Trials, the Proving Scar) load closest to the 500 ms budget (bible 14).
const MOTIF_MAX := 60
## Roots hang one to so many columns of deep mass.
const ROOT_SPACING := 3
## A form's length, world px.
const MOTIF_LEN := Vector2(56.0, 150.0)


## Reads the room's solid cells (`solids`) over the `size` tile grid. When
## `only` is not empty, only those cells are shaded; cells in `skip` never are.
## `zone` picks the forms the deepest mass holds (none for a zone not in MOTIF);
## `motif_seed` makes them the room's own. With `floors`, the ground under a
## floor (`FloorShade.floor_tops`) sinks no darker than the floor shade's full.
func setup(solids: Dictionary, size: Vector2i, only := {}, skip := {}, zone := "", motif_seed := 0, floors := false) -> void:
	_floors = floors
	_solids = solids
	_size = size
	_only = only
	_skip = skip
	_zone = zone
	_seed = motif_seed
	rebuild()


## Recomputes the field and the rects (after the solid cells change).
func rebuild() -> void:
	_field = darkness_field(_solids, _size)
	if _floors:
		cap_under_floors(_field, _size, FloorShade.floor_tops(_solids, _size, _skip))
	_rects = build_rects(_field, _size, _only, _skip)
	_build_motif()
	queue_redraw()


## The darkness field (0..1 per cell, row major), unquantised: `FloorShade`
## eases off it so the two never stack (pass 681).
func field() -> PackedFloat32Array:
	return _field


## The distance in tiles from each cell to the nearest open cell, 8-way, row
## major. Open cells are 0; the room's outside counts as solid and is never a
## source, so a room with no open cell is all `INF`.
static func distance_field(solids: Dictionary, size: Vector2i) -> PackedInt32Array:
	var n := size.x * size.y
	var dist := PackedInt32Array()
	dist.resize(n)
	var queue: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if solids.has(c):
				dist[y * size.x + x] = 1 << 30
			else:
				dist[y * size.x + x] = 0
				queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := dist[c.y * size.x + c.x] + 1
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var m := c + Vector2i(dx, dy)
				if m.x < 0 or m.y < 0 or m.x >= size.x or m.y >= size.y:
					continue
				var i := m.y * size.x + m.x
				if dist[i] > d:
					dist[i] = d
					queue.append(m)
	return dist


## Darkness 0..1 per cell from its distance to open air.
static func darkness_for(distance: int) -> float:
	return clampf((float(distance) - START) / SPAN, 0.0, 1.0)


static func darkness_field(solids: Dictionary, size: Vector2i) -> PackedFloat32Array:
	var dist := distance_field(solids, size)
	var f := PackedFloat32Array()
	f.resize(dist.size())
	for i in dist.size():
		f[i] = darkness_for(dist[i])
	return f


## Under a floor the ground is the frame's foreground, cut by the screen's
## edge, not mass deep in the world (pass 681). The pass 680 grade read a heavy
## dark ellipse under the Source Hall's floor: eight tiles of ground under the
## walking line sank radially from the pool and the floor into a near-black
## blob, with the floor shade's band laid over it. Now each cell at or under a
## floor's top (`tops`, -1 for none) is held at the floor shade's full darkness,
## so `FloorShade` grades that ground by its depth under the walking line and
## the two read as one fall into shadow. Walls and hanging mass are untouched.
static func cap_under_floors(field: PackedFloat32Array, size: Vector2i, tops: PackedInt32Array) -> void:
	var cap := FloorShade.MAX_ALPHA / MAX_ALPHA
	for x in mini(size.x, tops.size()):
		if tops[x] < 0:
			continue
		for y in range(tops[x], size.y):
			var i := y * size.x + x
			field[i] = minf(field[i], cap)


## The field blended between cell centres at `p`, in tiles (a cell's centre is
## at its index + 0.5). Off the grid it holds the edge value.
static func field_at(field: PackedFloat32Array, size: Vector2i, p: Vector2) -> float:
	var q := p - Vector2(0.5, 0.5)
	var x0 := floori(q.x)
	var y0 := floori(q.y)
	var tx := q.x - x0
	var ty := q.y - y0
	var a := _cell(field, size, x0, y0)
	var b := _cell(field, size, x0 + 1, y0)
	var c := _cell(field, size, x0, y0 + 1)
	var d := _cell(field, size, x0 + 1, y0 + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _cell(field: PackedFloat32Array, size: Vector2i, x: int, y: int) -> float:
	return field[clampi(y, 0, size.y - 1) * size.x + clampi(x, 0, size.x - 1)]


## The dither threshold at block `b`, -0.5..0.5.
static func dither(b: Vector2i) -> float:
	return (float(_BAYER[posmod(b.y, 4)][posmod(b.x, 4)]) + 0.5) / 16.0 - 0.5


## The quantised step 0..LEVELS of darkness `v` at block `b`.
static func level_at(v: float, b: Vector2i) -> int:
	if v <= 0.0:
		return 0
	return clampi(roundi(v * LEVELS + dither(b)), 0, LEVELS)


## The opacity of step `level`.
static func alpha_for(level: int) -> float:
	return MAX_ALPHA * float(level) / LEVELS


## The rects that paint the shade: whole cells where the step is the same over
## the cell, otherwise runs of `GRAIN`-pixel blocks along each row.
static func build_rects(field: PackedFloat32Array, size: Vector2i, only := {}, skip := {}) -> Array:
	var out: Array = []
	var per := TILE / GRAIN
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if skip.has(cell) or (not only.is_empty() and not only.has(cell)):
				continue
			var lo := INF
			var hi := -INF
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var v := field_at(field, size, Vector2(cell) + corner)
				lo = minf(lo, v)
				hi = maxf(hi, v)
			if hi <= 0.0:
				continue
			var origin := Vector2(cell * TILE)
			if lo >= 1.0:
				out.append([Rect2(origin, Vector2(TILE, TILE)), alpha_for(LEVELS)])
				continue
			# Ground held under a floor (pass 681) is one flat value over the cell:
			# one rect at the floor shade's full, not 64 dithered blocks.
			if lo == hi and lo >= FloorShade.MAX_ALPHA / MAX_ALPHA - 0.0001:
				out.append([Rect2(origin, Vector2(TILE, TILE)), MAX_ALPHA * lo])
				continue
			for by in per:
				var run_start := 0
				var run_level := -1
				for bx in per + 1:
					var lvl := -1
					if bx < per:
						var blk := cell * per + Vector2i(bx, by)
						var p := (Vector2(blk) + Vector2(0.5, 0.5)) * GRAIN / TILE
						lvl = level_at(field_at(field, size, p), blk)
					if lvl != run_level:
						if run_level > 0:
							out.append([Rect2(origin + Vector2(run_start * GRAIN, by * GRAIN),
									Vector2((bx - run_start) * GRAIN, GRAIN)), alpha_for(run_level)])
						run_start = bx
						run_level = lvl
	return out


## The step drawn at world pixel `px` (for tests): 0 where nothing is drawn.
func level_at_pixel(px: Vector2) -> int:
	for r: Array in _rects:
		if (r[0] as Rect2).has_point(px):
			return roundi(float(r[1]) / MAX_ALPHA * LEVELS)
	return 0


func rect_count() -> int:
	return _rects.size()


## The bounds of each form the deep holds.
func motif_strokes() -> Array[Rect2]:
	return _strokes


## The form's colour drawn at world pixel `px` (for tests): transparent where none is.
func motif_at_pixel(px: Vector2) -> Color:
	var out := Color(0, 0, 0, 0)
	for r: Array in _motif:
		if (r[0] as Rect2).has_point(px):
			out = r[1]
	return out


## Every block the forms fill: [Rect2, Color] pairs.
func motif_blocks() -> Array:
	return _motif


## The deep's forms: strokes walked from deep cells in GRAIN-pixel blocks.
func _build_motif() -> void:
	_motif.clear()
	_strokes.clear()
	var kind: String = MOTIF.get(_zone, "")
	if kind == "":
		return
	var deep: Array[Vector2i] = []
	for y in _size.y:
		for x in _size.x:
			var cell := Vector2i(x, y)
			if _skip.has(cell) or (not _only.is_empty() and not _only.has(cell)):
				continue
			if _field[y * _size.x + x] >= 1.0:
				deep.append(cell)
	if deep.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, _size, deep.size()])
	var cols: Array = MOTIF_COLORS[_zone]
	var seen := {}
	if kind == "roots":
		# Roots hang from the top of the deep mass, one every ROOT_SPACING tiles
		# across it, each set a little off its slot, so they never cross in a tangle.
		var tops := {}
		for c: Vector2i in deep:
			if not tops.has(c.x) or c.y < int(tops[c.x]):
				tops[c.x] = c.y
		var xs: Array = tops.keys()
		xs.sort()
		var slots := clampi(xs.size() / ROOT_SPACING, 1, MOTIF_MAX)
		for i in slots:
			var x: int = xs[mini(xs.size() - 1, int((i + rng.randf_range(0.1, 0.9)) * xs.size() / slots))]
			var start := Vector2((x + rng.randf()) * TILE, int(tops[x]) * TILE)
			_walk(kind, start, PI / 2.0 + rng.randf_range(-0.35, 0.35), rng.randf_range(MOTIF_LEN.x, MOTIF_LEN.y) * 1.4, rng, cols, seen, true)
		return
	# Veins a third as many as the roots; seams half as many (they run long, and
	# the stone halls hold the most deep mass, so this keeps the load lean).
	var count := clampi(deep.size() / (MOTIF_CELLS * (3 if kind == "veins" else 2)), 1, MOTIF_MAX)
	for i in count:
		var start := (Vector2(deep[rng.randi_range(0, deep.size() - 1)]) + Vector2(rng.randf(), rng.randf())) * TILE
		_walk(kind, start, -1.0, rng.randf_range(MOTIF_LEN.x, MOTIF_LEN.y), rng, cols, seen, true)


## One stroke from `start`. Roots fall and wander and may fork; veins zigzag and
## bead; strata run near level and break.
func _walk(kind: String, start: Vector2, heading: float, length: float, rng: RandomNumberGenerator,
		cols: Array, seen: Dictionary, may_fork: bool) -> void:
	var a := heading
	if a < 0.0:
		match kind:
			"roots":
				a = PI / 2.0 + rng.randf_range(-1.1, 1.1)
			"veins":
				a = rng.randf_range(0.0, TAU)
			_:
				a = (0.0 if rng.randf() < 0.5 else PI) + rng.randf_range(-0.18, 0.18)
	var p := start
	var bounds := Rect2(p, Vector2.ZERO)
	var steps := int(length / GRAIN)
	var fork_at := -1
	if may_fork and kind == "roots" and rng.randf() < 0.45:
		fork_at = rng.randi_range(steps / 3, steps * 2 / 3)
	var gap := 0
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	for n in steps:
		match kind:
			"roots":
				a += rng.randf_range(-0.1, 0.1)
				a = lerpf(a, PI / 2.0, 0.05)
			"veins":
				# A vein runs straight and turns sharp, like a crack along a facet.
				# Turns alternate, so it zigzags instead of curling.
				if n % 18 == 17:
					turn = -turn
					a += turn * rng.randf_range(0.4, 0.8)
			_:
				a += rng.randf_range(-0.08, 0.08)
				if gap <= 0 and rng.randf() < 0.03:
					gap = rng.randi_range(3, 8)
		p += Vector2.from_angle(a) * GRAIN
		if gap > 0:
			gap -= 1
			continue
		# A root tapers from a 6-pixel trunk to a 2-pixel tip.
		var w := 2
		if kind == "roots":
			w = 6 if n < steps * 0.3 else (4 if n < steps * 0.65 else 2)
		var beaded := kind == "veins" and n % 15 == 7
		_block(p, w, cols[1] if beaded else cols[0], MOTIF_LIT_A if beaded else MOTIF_BODY_A, seen)
		if not beaded:
			# The lit edge: above a root or a seam, beside a vein.
			var lit := Vector2(-GRAIN, 0) if kind == "veins" else Vector2(0, -GRAIN)
			_block(p + lit, GRAIN, cols[1], MOTIF_LIT_A * 0.6, seen)
			if w > GRAIN * 2:
				_block(p + lit + Vector2(GRAIN, 0), GRAIN, cols[1], MOTIF_LIT_A * 0.6, seen)
		bounds = bounds.expand(p)
		if n == fork_at:
			_walk(kind, p, a + (0.7 if rng.randf() < 0.5 else -0.7), length * 0.45, rng, cols, seen, false)
	_strokes.append(bounds)


## A `w`-pixel block at `p` (snapped to the grain), faded by the shade's field, and
## only once per block.
func _block(p: Vector2, w: int, col: Color, alpha: float, seen: Dictionary) -> void:
	var at := Vector2(floorf(p.x / GRAIN) * GRAIN, floorf(p.y / GRAIN) * GRAIN)
	if at.x < 0 or at.y < 0 or at.x + w > _size.x * TILE or at.y + w > _size.y * TILE:
		return
	var key := Vector2i(at)
	if seen.has(key):
		return
	var cell := Vector2i(floori(at.x / TILE), floori(at.y / TILE))
	if not _solids.has(cell) or _skip.has(cell) or (not _only.is_empty() and not _only.has(cell)):
		return
	var v := field_at(_field, _size, (at + Vector2(w, w) * 0.5) / TILE)
	if v < MOTIF_FROM:
		return
	seen[key] = true
	var fade := clampf((v - MOTIF_FROM) / (1.0 - MOTIF_FROM), 0.0, 1.0)
	_motif.append([Rect2(at, Vector2(w, w)), Color(col, alpha * fade)])


func _draw() -> void:
	for r: Array in _rects:
		draw_rect(r[0], Color(COLOR, r[1]))
	for r: Array in _motif:
		draw_rect(r[0], r[1])
