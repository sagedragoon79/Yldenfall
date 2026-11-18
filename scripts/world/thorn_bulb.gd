class_name ThornBulb
extends Area2D
## A glowing thorn pod: dangerous to touch, the main pogo target for Delver's Pick routes.
##
## Pass 540 (bible 12.32): the pod grows from the surface beside it. It was a
## flat red disc with six dark lines, and stacked down a shaft wall a run of
## them read as a column of red orbs (the pass 535 grade's "placeholder set
## pieces"). Now each pod is a pixel-drawn bramble bud: outlined, lit from the
## upper left, with a glowing seam and hooked pale thorns, on a woody stem that
## roots into the wall, floor or ceiling it hangs from. Pods that grow side by
## side from the same surface share one thorny bramble vine along it, so a
## column of them reads as a bramble climbing the wall. A pod with no surface
## beside it floats free, thorned all round. The hitbox is unchanged: a circle
## of radius 6 at the cell's center, where the pod sits.
##
## Pass 593 (bible 12.32): a row of the red pods read as strawberries. The
## husk is now dark bark split by an ember seam, with five long bone thorns,
## on a bark-brown vine.

## The husk's ramp, dark to lit, plus its outline. Pass 593: the husk was a
## four-step bright red, and with pale thorn-tip dots and a green stem a row
## of pods read as strawberries (the pass 590 grade). It is now a dark woody
## husk, so the red lives only in the ember seam that splits it.
const OUTLINE := Color("1c0d0f")
const POD_DARK := Color("200b09")
const POD := Color("48201e")
const POD_MID := Color("783c2b")
const POD_LIT := Color("aa6336")
const SHINE := Color("cd8c51")
## The seam's ember glow pulses between these; its core is hotter.
const GLOW := Color("c02a20")
const GLOW_HOT := Color("e55439")
const EMBER := Color("f0c02e")
## Thorns: long bone spikes, a shadowed flank, a lit flank and a pale point.
const THORN_DARK := Color("797767")
const THORN := Color("ccbe8e")
const THORN_TIP := Color("f1eee4")
## The woody stem and the bramble vine: bark, not leaf.
const VINE_OUT := Color("161413")
const VINE := Color("432d23")
const VINE_LIT := Color("6e5135")
const VINE_THORN := Color("ccbe8e")
## Every tone above, for the palette test.
const TONES := [OUTLINE, POD_DARK, POD, POD_MID, POD_LIT, SHINE, GLOW, GLOW_HOT, EMBER, THORN_DARK, THORN, THORN_TIP, VINE_OUT, VINE, VINE_LIT, VINE_THORN]
## How far a thorn reaches past the husk, in pixels.
const THORN_LEN := 4

## Half a tile: the surface the pod grows from is this far from its center.
const HALF := 8
## The hitbox radius.
const RADIUS := 6.0
## How far, in radians, alternate pods along a surface droop from straight out.
const TILT := 0.45

## Points from the pod toward the surface it grows from (a unit grid step),
## or zero for a pod that floats free. Set before the pod is added.
var anchor := Vector2i.ZERO
## The grid steps (along the surface) toward neighbouring pods that grow from
## the same surface; the vine runs that way to meet theirs.
var links: Array[Vector2i] = []

var _t := randf() * TAU
var _squish := 0.0
## [pixel, color] pairs, built once for this anchor and these links.
var _vine_px: Array = []
var _pod_px: Array = []
var _seam_px: Array[Vector2i] = []
var _core_px: Array[Vector2i] = []


func _ready() -> void:
	collision_layer = Player.LAYER_HAZARD
	collision_mask = 0
	monitoring = false
	add_to_group("hazard")
	add_to_group("pogo")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_build()


func take_hit(_damage: int, _dir: Vector2) -> void:
	_squish = 1.0
	Sfx.play("thorn", 0.1)


func _physics_process(delta: float) -> void:
	_t += delta * 3.0
	_squish = maxf(_squish - delta * 6.0, 0.0)
	queue_redraw()


## The surface a pod in `cell` grows from, given which cells are solid: a wall
## to the west or east first (the pods line shaft walls), then the floor, then
## the ceiling. Zero when nothing solid touches it.
static func anchor_for(cell: Vector2i, solid: Callable) -> Vector2i:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
		if solid.call(cell + step):
			return step
	return Vector2i.ZERO


## The two directions along a surface: up and down a wall, east and west along
## a floor or ceiling.
static func along(a: Vector2i) -> Array[Vector2i]:
	if a.x != 0:
		return [Vector2i.UP, Vector2i.DOWN]
	return [Vector2i.LEFT, Vector2i.RIGHT]


## The way the bud points: straight out from its surface, tipped by `tilt`
## radians (so a column of pods droops alternately up and down the wall instead
## of standing in a uniform row). A free pod points up.
static func pod_dir(a: Vector2i, tilt: float) -> Vector2:
	var out := Vector2(-a) if a != Vector2i.ZERO else Vector2.UP
	return out.rotated(tilt)


## The tilt of a pod at `cell` growing from `a`: pods alternate along their
## surface, a free pod stands straight.
static func tilt_for(cell: Vector2i, a: Vector2i) -> float:
	if a == Vector2i.ZERO:
		return 0.0
	var k := cell.y if a.x != 0 else cell.x
	return TILT if posmod(k, 2) == 0 else -TILT


## Pixel offsets (from the pod's center) the pod body covers, for a bud
## pointing along `dir`: round at the stem, tapering to its tip.
static func pod_cells(dir: Vector2) -> Array[Vector2i]:
	var side := Vector2(-dir.y, dir.x)
	var cells: Array[Vector2i] = []
	for y in range(-HALF, HALF):
		for x in range(-HALF, HALF):
			var p := Vector2(x + 0.5, y + 0.5)
			var u := p.dot(dir) - 0.3  # along the pod, toward its tip
			var v := p.dot(side)
			var t := clampf((u + 1.0) / 6.0, 0.0, 1.0)
			var rv := 4.8 * (1.0 - 0.6 * t * t)
			var ru := 5.0 if u < 0.0 else 6.8
			if (u / ru) * (u / ru) + (v / rv) * (v / rv) <= 1.0:
				cells.append(Vector2i(x, y))
	return cells


func _build() -> void:
	var dir := pod_dir(anchor, tilt_for(Vector2i((position / (HALF * 2)).floor()), anchor))
	var body := {}
	for c: Vector2i in pod_cells(dir):
		body[c] = true
	var side := Vector2(-dir.y, dir.x)
	var light := Vector2(-0.6, -0.8)
	_pod_px.clear()
	_seam_px.clear()
	_core_px.clear()
	for c: Vector2i in body:
		var p := Vector2(c) + Vector2(0.5, 0.5)
		var u := p.dot(dir) - 0.3
		var v := p.dot(side)
		# A rough normal: away from the bud's spine.
		var n := (p - dir * clampf(u, -1.0, 2.0) * 0.6).normalized()
		var lit := n.dot(light)
		var col := POD
		if lit < -0.35:
			col = POD_DARK
		elif lit > 0.65:
			col = POD_LIT
		elif lit > 0.2:
			col = POD_MID
		_pod_px.append([c, col])
		# The seam: an ember crack down the husk's spine from the stem to the
		# tip, kinked once so it reads as a split, not a stripe.
		var kink := 0.35 if u < 0.8 else -0.45
		if u > -3.2 and absf(v - kink) < 0.75:
			_seam_px.append(c)
			if u > -1.0 and u < 3.0:
				_core_px.append(c)
	# Outline every empty pixel beside the body.
	var rim := {}
	for c: Vector2i in body:
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not body.has(c + s):
				rim[c + s] = true
	for c: Vector2i in rim:
		_pod_px.insert(0, [c, OUTLINE])
	# A glint up and left of the center, off the seam.
	var g := Vector2i((light * 2.6).floor())
	if body.has(g) and not _seam_px.has(g):
		_pod_px.append([g, SHINE])
	# Thorns: five long spikes, two pixels thick at the husk and tapering to a
	# pale point, lit on their upper-left flank and outlined, so a row of pods
	# bristles instead of being dotted like a berry. Round all but the stem.
	var angles := [0.0, 1.05, -1.05, 2.15, -2.15]
	if anchor == Vector2i.ZERO:
		angles.append(PI)
	var spikes: Array = []
	for ang: float in angles:
		var d := dir.rotated(ang)
		var r := 1.0
		while body.has(Vector2i((d * r).floor())) and r < HALF:
			r += 0.5
		var base := d * (r - 0.5)
		var flank := d.orthogonal()
		if flank.dot(light) < 0.0:
			flank = -flank
		for i in range(THORN_LEN + 1):
			var q := base + d * i
			var core := Vector2i(q.floor())
			if not body.has(core):
				spikes.append([core, THORN_TIP if i == THORN_LEN else THORN])
			if i < 2:
				var w := Vector2i((q - flank).floor())
				if not body.has(w) and w != core:
					spikes.append([w, THORN_DARK])
	var spiked := {}
	for px: Array in spikes:
		spiked[px[0]] = true
	for px: Array in spikes:
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var o: Vector2i = px[0] + s
			if not body.has(o) and not spiked.has(o) and not rim.has(o):
				_pod_px.insert(0, [o, OUTLINE])
				rim[o] = true
	_pod_px.append_array(spikes)
	_build_vine()


func _build_vine() -> void:
	_vine_px.clear()
	if anchor == Vector2i.ZERO:
		return
	var out := -anchor
	var dirs := along(anchor)
	# The stem: from the surface to the bud's back, two pixels wide, lit on
	# its upper or left column.
	var wide := dirs[1]
	for i in range(HALF - 6, HALF + 1):
		var c := anchor * i
		_vine_px.append([c, VINE_LIT])
		_vine_px.append([c + wide, VINE])
	# The vine along the surface, a pixel or two off it, out to the cell's
	# edge toward each linked pod (a short root clutch when there is none).
	# Its wobble and thorns follow the room's pixels, so neighbouring pods'
	# vines meet without a jog.
	for d: Vector2i in dirs:
		var reach := HALF if links.has(d) else 3
		var axis := Vector2(absi(d.x), absi(d.y))
		var at := roundi(position.dot(axis))
		var sgn := d.x + d.y
		for i in range(0, reach + 1):
			var k := at + i * sgn
			var wob := 1 if posmod(k, 12) < 6 else 0
			var c := anchor * (HALF - 1 - wob) + d * i
			_vine_px.append([c - out, VINE_OUT])
			_vine_px.append([c, VINE])
			_vine_px.append([c + out, VINE_OUT if i == reach and reach < HALF else VINE_LIT])
			# A thorn off the vine every few pixels, pointing out from the surface.
			if posmod(k, 7) == 3:
				_vine_px.append([c + out * 2, VINE_LIT])
				_vine_px.append([c + out * 3 + d, VINE_THORN])


## The husk's, outline's and thorns' [pixel, color] pairs. For tests.
func pod_pixels() -> Array:
	return _pod_px


## The ember seam's pixels. For tests.
func seam_pixels() -> Array[Vector2i]:
	return _seam_px


## The stem's and vine's [pixel, color] pairs. For tests.
func vine_pixels() -> Array:
	return _vine_px


func _draw() -> void:
	for px: Array in _vine_px:
		draw_rect(Rect2(Vector2(px[0]), Vector2.ONE), px[1])
	var sq := Vector2(1.0 + _squish * 0.4, 1.0 - _squish * 0.35)
	draw_set_transform(Vector2.ZERO, 0.0, sq)
	for px: Array in _pod_px:
		draw_rect(Rect2(Vector2(px[0]), Vector2.ONE), px[1])
	var pulse := 0.5 + 0.5 * sin(_t)
	var glow := GLOW.lerp(GLOW_HOT, pulse)
	for c: Vector2i in _seam_px:
		draw_rect(Rect2(Vector2(c), Vector2.ONE), glow)
	var core := GLOW_HOT.lerp(EMBER, pulse)
	for c: Vector2i in _core_px:
		draw_rect(Rect2(Vector2(c), Vector2.ONE), core)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
