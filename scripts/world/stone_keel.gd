class_name StoneKeel
extends Node2D
## What a floating stone hangs from (design bible 12.82, pass 597). The Spires'
## bridge stones float ("Its stones still float, a stride apart"), and the play
## layer drew each one as a bare brick block on nothing: the pass 595 grade read
## them as "floating brick blocks". The Spires' sky islands in the backdrop read
## well, because each hangs on a ragged keel of rock. This layer gives every
## floating mass of solid cells the same keel: the rock it tore free with when
## the storm took the bridge, a cluster of chunky stones in the islands' own
## ramp, lit from the upper left, outlined on its shadow side and underside, with
## a spur or three hanging below and a few loose pebbles drifting under the
## tips, bobbing a pixel, to say the whole thing floats.
##
## A mass floats when none of its cells touches the room's edge. The keel stays
## in open air: no keel pixel lies in a solid or plank cell, and it ends two
## pixels above whatever is below. Drawn once per room load behind the tiles
## (z -1, like the plank supports), so the block's own edge sits over the keel's
## top and actors pass in front. Collision is untouched; it is dressing only.

const TILE := 16
## The zones whose stones float.
const ZONES := ["spires"]
## The keel's tones: rim, lit, mid, shadow (the Spires islands' rock, tilegen
## ISLAND_ROCK: crystal-3, crystal-2, crystal-1, night-1) and the outline (night-0).
const ROCK := ["a736aa", "712b78", "421e48", "2c2541"]
const LINE := "120f19"
## The deepest a keel hangs below its block, world px, and the shallowest its
## deepest spur may be.
const DEPTH_MAX := 40.0
const DEPTH_MIN := 12.0
## The keel ends this far above whatever is below it, world px.
const CLEAR := 2
## A chunky stone's size in the keel, world px.
const STONE := 6

## One Dictionary per floating mass: {cells, left, right, bottoms (column ->
## lowest row), origin (world px of the keel image), pixels ({Vector2i: hex},
## relative to origin), pebbles ([Rect2, hex] in world px)}.
var keels: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _pebbles: Node2D
var _t := 0.0


func _ready() -> void:
	z_index = -1


func setup(solid: Dictionary, blocked: Dictionary, size: Vector2i, seed_value: int) -> void:
	keels = StoneKeel.plan(solid, blocked, size, seed_value)
	_textures.clear()
	for k: Dictionary in keels:
		_textures.append(StoneKeel.texture_for(k))
	if _pebbles == null:
		_pebbles = Node2D.new()
		_pebbles.name = "Pebbles"
		_pebbles.draw.connect(_draw_pebbles)
		add_child(_pebbles)
	_pebbles.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	if _pebbles == null:
		return
	_t += delta
	# A slow bob of one pixel: the pebbles hang on nothing.
	_pebbles.position.y = roundf(sin(_t * 1.3) * 2.0) * 0.5


## The floating masses of `solid` (cells), each with its keel planned. A mass
## floats when no cell of it lies on the room's edge.
static func plan(solid: Dictionary, blocked: Dictionary, size: Vector2i, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var cells: Array = solid.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var mass: Array[Vector2i] = []
		var anchored := false
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			mass.append(c)
			if c.x <= 0 or c.y <= 0 or c.x >= size.x - 1 or c.y >= size.y - 1:
				anchored = true
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := c + d
				if solid.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		if anchored:
			continue
		var keel := StoneKeel.keel_for(mass, blocked, size, seed_value)
		if not keel.pixels.is_empty():
			out.append(keel)
	return out


## The keel under one floating mass: which world pixels it covers and their tones.
static func keel_for(mass: Array[Vector2i], blocked: Dictionary, size: Vector2i, seed_value: int) -> Dictionary:
	var left := mass[0].x
	var right := mass[0].x
	var bottoms := {}
	for c in mass:
		left = mini(left, c.x)
		right = maxi(right, c.x)
		bottoms[c.x] = maxi(bottoms.get(c.x, c.y), c.y)
	var x0 := left * TILE
	var w := (right - left + 1) * TILE
	var top := 1 << 30
	for col: int in bottoms:
		top = mini(top, (bottoms[col] + 1) * TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, left, mass[0].y])
	var depth := clampf(w * 0.45, DEPTH_MIN, DEPTH_MAX)
	# A main spur off centre and two or three lesser ones: no two keels are the same wedge.
	var spurs: Array = [[rng.randf_range(-0.3, 0.3), rng.randf_range(0.2, 0.32), 1.0]]
	for i in rng.randi_range(2, 3):
		spurs.append([rng.randf_range(-0.75, 0.75), rng.randf_range(0.08, 0.18), rng.randf_range(0.35, 0.7)])
	# Per world-pixel column: where the keel starts (the mass's underside) and how far it hangs.
	var spans := {}
	for px in w:
		var u := (px + 0.5 - w * 0.5) / (w * 0.5)
		var belly := 0.3 * pow(maxf(0.0, 1.0 - u * u), 0.7)
		var drop := belly
		for s: Array in spurs:
			var a: float = 1.0 - absf(u - float(s[0])) / float(s[1])
			if a > 0.0:
				drop = maxf(drop, belly + (float(s[2]) - belly) * pow(a, 1.6))
		var hang := int(depth * drop)
		if absf(u) > 0.9:
			hang = mini(hang, 2)  # rounded shoulders under the block's ends
		var col := left + int(px / TILE)
		var y_top := (int(bottoms[col]) + 1) * TILE
		# Never into a solid or plank cell, and stop CLEAR px above it.
		var room_px := 0
		var row := int(bottoms[col]) + 1
		while row < size.y and not blocked.has(Vector2i(col, row)):
			room_px += TILE
			row += 1
		hang = mini(hang, room_px - CLEAR)
		if hang > 0:
			spans[px] = Vector2i(y_top, hang)
	var pixels := {}
	var bottom := top
	for px: int in spans:
		var s: Vector2i = spans[px]
		bottom = maxi(bottom, s.x + s.y)
	for px: int in spans:
		var s: Vector2i = spans[px]
		for j in s.y:
			var p := Vector2i(px, s.x + j - top)
			var out_r: bool = not spans.has(px + 1) or j >= spans[px + 1].y or spans[px + 1].x != s.x
			var out_l: bool = not spans.has(px - 1) or j >= spans[px - 1].y or spans[px - 1].x != s.x
			var out_d := j == s.y - 1
			if out_r or out_d:
				pixels[p] = LINE  # the selective outline: shadow side and underside
				continue
			var k := float(j) / depth
			# Chunky stones: the nearest jittered centre on a STONE grid, and a seam where two meet.
			var near := StoneKeel._stone_at(px, s.x + j, seed_value)
			var level := 1
			var v := (float(px) / w) * 0.6 + k * 0.9
			level = 1 if v < 0.5 else (2 if v < 0.95 else 3)
			if near.y < 0.9:
				level = mini(3, level + 1)  # a seam, one step darker
			elif near.x < -2.0 and level > 1:
				level -= 1  # the stone's lit upper-left face (the rim tone stays on the flank)
			if out_l:
				level = 0 if k < 0.3 else mini(level, 1)  # a rim of light down the lit flank
			pixels[p] = ROCK[maxi(0, level)]
	# Loose pebbles drifting under the two deepest spur tips.
	var pebbles: Array = []
	var tips: Array = spans.keys()
	tips.sort_custom(func(a: int, b: int) -> bool: return spans[a].x + spans[a].y > spans[b].x + spans[b].y)
	var used := []
	for px: int in tips:
		if pebbles.size() >= 2:
			break
		var near_used := false
		for u: int in used:
			if absi(u - px) < 10:
				near_used = true
		if near_used:
			continue
		used.append(px)
		var s: Vector2i = spans[px]
		var gap := rng.randi_range(4, 8)
		var pw := rng.randi_range(2, 3)
		var py := s.x + s.y + gap
		var col := left + int(px / TILE)
		var cell := Vector2i(col, int(py / TILE))
		var cell2 := Vector2i(col, int((py + 3) / TILE))
		if blocked.has(cell) or blocked.has(cell2) or cell2.y >= size.y:
			continue
		var r := Rect2(x0 + px - pw * 0.5, py, pw, 2)
		pebbles.append([r, ROCK[1]])
		pebbles.append([Rect2(r.position.x, r.end.y, pw, 1), LINE])
	return {"cells": mass, "left": left, "right": right, "bottoms": bottoms,
		"origin": Vector2(x0, top), "pixels": pixels, "pebbles": pebbles, "depth": bottom - top}


## Where world pixel (x, y) sits in its chunky stone: x is how far up-left of the
## stone's centre it lies (negative is the lit face), y how far it is from the
## seam with the next stone.
static func _stone_at(x: int, y: int, seed_value: int) -> Vector2:
	var best := INF
	var second := INF
	var lean := 0.0
	var gx := int(floor(float(x) / STONE))
	var gy := int(floor(float(y) / STONE))
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx := (gx + ox) * STONE + StoneKeel._hash01(gx + ox, gy + oy, seed_value) * STONE
			var cy := (gy + oy) * STONE + StoneKeel._hash01(gy + oy, gx + ox, seed_value + 9) * STONE
			var d := sqrt((x - cx) * (x - cx) + ((y - cy) * 1.6) * ((y - cy) * 1.6))
			if d < best:
				second = best
				best = d
				lean = (x - cx) + (y - cy) * 1.3
			elif d < second:
				second = d
	return Vector2(lean, second - best)


static func _hash01(a: int, b: int, s: int) -> float:
	return float(hash([a, b, s]) & 0xffff) / 65536.0


static func texture_for(keel: Dictionary) -> Texture2D:
	var w := (int(keel.right) - int(keel.left) + 1) * TILE
	var h := maxi(1, int(keel.depth))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for p: Vector2i in keel.pixels:
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
			img.set_pixelv(p, Color(keel.pixels[p]))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	for i in keels.size():
		draw_texture(_textures[i], keels[i].origin)


func _draw_pebbles() -> void:
	for k: Dictionary in keels:
		for p: Array in k.pebbles:
			_pebbles.draw_rect(p[0], Color(p[1]))
