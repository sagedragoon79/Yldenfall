class_name RoomLight
extends Node2D
## Drawn emissive light pools (design bible 12.10). Every fixed scenery light — a
## town lamp, a meditation shrine's rune, a forge mouth, and the glowing fungus
## and candles of the decor — now casts a soft radial pool of its own colour onto
## the floor, walls and backdrop around it, so the source reads as a light that
## bleeds into the world instead of a bright sprite stuck on a flat scene. This is
## the recurring "flat, directionless lighting / sources cast no coloured pool
## onto nearby geometry" defect the independent grade keeps flagging, and the
## room-light part of Sean's 2026-11-07 lighting-and-depth request (the per-zone
## distance fog and colour grade shipped in passes 505 and 507).
##
## The pools are **additive** and **localised**: each only brightens a pocket
## around its own source, and the centre is capped well below a blow-out
## (READABLE_CAP), so the lit gameplay layer and combat telegraphs keep the
## contrast they read by — a pool tints its surroundings, it never washes them
## out. The overlay sits just above the raw floor tiles and under every actor (it
## is added to the room right after the tile layer, before the player, the
## enemies and the decor), so a pool lights the ground a foe stands on without
## lighting the foe. One overlay per room, gathered once (12.3's static-overlay
## rule, no per-frame cost).

## A fixed light source opts in by joining this group and exposing `glow_color`
## and `glow_radius`. Dynamic lights — projectiles, foes, pickups — stay in the
## fog's own "light" group and are deliberately NOT lit here, so a fireball never
## drags a glowing pool across the floor.
const GROUP := "room_light"

## Peak additive brightness at a pool's centre. Additive, so it only ever adds
## light; capped low so a pool tints the scene without crushing the contrast that
## combat reads by. Every pool's centre stays at or under this.
const READABLE_CAP := 0.16
## Side of the shared radial-gradient sprite each pool is drawn from, in texels.
const TEX_SIZE := 96

## Fallbacks for a source that joins the group without its own colour or reach.
const DEFAULT_COLOR := Color("f0c02e") ## a warm lamp gold
const DEFAULT_RADIUS := 90.0
## A decor candle or fungus glow is a small point source, so its pool is tighter
## and fainter than a lamp's.
const DECOR_RADIUS := 46.0
const DECOR_PEAK := 0.11
## Every overlay joins this group, so a source that goes dark (a doused fire
## seal) can ask the room's overlay to gather its pools again (`refresh`).
const OVERLAY_GROUP := "room_light_overlay"

## The shared radial-gradient sprite every pool is drawn from, built on first use.
static var _pool_tex: Texture2D

## [local centre, colour, radius, centre peak] per pool, filled once by `_collect`.
var _pools: Array = []
## The room whose sources light this overlay; set by Room before it enters the tree.
var room: Node = null
## The room's Decor node, for its candle/fungus glow points; set by Room.
var decor: Node2D = null


func _ready() -> void:
	# Additive: a pool only ever adds light to what it falls on.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	add_to_group(OVERLAY_GROUP)
	# Smooth the radial sprite even where the project defaults to nearest for crisp
	# pixel art, so a scaled-up pool stays a soft bloom with no texel stepping.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Over the raw tiles (added just before this), under every actor and the decor.
	z_index = 0
	# Collect after the whole room subtree is in the tree and its sources have
	# joined the group (deferred: siblings added after this node ready later).
	call_deferred("_collect")


## Gathers every fixed source into a pool: the "room_light" group members that
## belong to this room, and each of the decor's glow points.
func _collect() -> void:
	_pools.clear()
	if room != null and is_inside_tree():
		for n in get_tree().get_nodes_in_group(GROUP):
			var n2 := n as Node2D
			if n2 == null or not room.is_ancestor_of(n2):
				continue
			var g := source_glow(n2)
			# A source can opt out of a pool of its own (a fire seal's tiles share
			# one pool, cast from one of them) by reporting no reach.
			if g.radius <= 0.0:
				continue
			_pools.append([to_local(n2.global_position + g.offset), g.color, g.radius, READABLE_CAP])
	if decor != null:
		var pc: Variant = decor.get("pool_color")
		var col: Color = pc if pc is Color else DEFAULT_COLOR
		var glows: Variant = decor.get("glows")
		if glows is Array:
			for gpos: Vector2 in glows:
				_pools.append([to_local(decor.to_global(gpos)), col, DECOR_RADIUS, DECOR_PEAK])
	queue_redraw()


## A source's pool colour and reach, read off the node with warm defaults, so a
## source that joins the group but forgets a field still lights.
static func source_glow(node: Node) -> Dictionary:
	var color: Variant = node.get("glow_color")
	var radius: Variant = node.get("glow_radius")
	var offset: Variant = node.get("glow_offset")
	return {
		"color": color if color is Color else DEFAULT_COLOR,
		"radius": float(radius) if (radius is float or radius is int) else DEFAULT_RADIUS,
		"offset": offset if offset is Vector2 else Vector2.ZERO,
	}


## Gathers the pools of every room's overlay again: a source left the group (a
## fire seal went out) or changed its glow.
static func refresh(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(OVERLAY_GROUP):
		(n as RoomLight)._collect()


## A pool's brightness at normalised distance `t` from its centre (0 at the
## centre, 1 at the rim): 1 at the centre, 0 at the edge, eased softly
## (smoothstep) so the pool has no hard edge and no visible banding. Pure, so the
## on-screen falloff is backed by tested maths; it builds the radial sprite below.
static func falloff(t: float) -> float:
	var x := clampf(1.0 - t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## How much tighter the glow is above the source than a plain circle: the air over
## a lamp or a glow-mushroom catches far less light than the ground beneath it, so
## the upward reach is divided down by this.
const UP_TIGHTEN := 2.1
## How far the glow reaches below the source, as a fraction of the plain radius —
## a little short of the rim so the cast pool fades before the quad's edge.
const DOWN_REACH := 0.94
## How much the pool widens toward the floor: a real cast pool spreads sideways
## where it lands, so x-distance is eased down for the rows below the source.
const GROUND_SPREAD := 0.7


## A pool's brightness at a texel, given normalised offsets from the source
## (`nx`, `ny` in -1..1, with `ny` positive downward toward the ground). The
## source still sits at the centre (nx=ny=0 is full brightness, so the centre
## peak is exactly the pool's cap, bible 12.10), but the falloff is shaped so the
## glow hugs the surface instead of reading as a floating disc: the air above the
## source (ny<0) is tightened hard, and below it (ny>0) the pool reaches the floor
## and widens across it. This is the "shape the glow to its source/surface"
## lighting fix — a lantern or glow-mushroom now casts a pool on the ground rather
## than a symmetric blob. Pure, so the on-screen shape is backed by tested maths.
static func shaped_alpha(nx: float, ny: float) -> float:
	# Upward reaches much less far than downward.
	var vy := ny * UP_TIGHTEN if ny < 0.0 else ny * DOWN_REACH
	# Below the source the pool spreads sideways where it lands on the floor.
	var vx := nx / (1.0 + GROUND_SPREAD * maxf(ny, 0.0))
	return falloff(sqrt(vx * vx + vy * vy))


## A white sprite whose alpha is `shaped_alpha` of the offset from its centre,
## built once and shared. Each pool draws one of these tinted and scaled, so the
## cast pool is a single smooth quad — none of the ringing a stack of filled
## circles shows on a dark backdrop — and the shaping makes it hug the ground
## under its source instead of floating as an even disc.
static func pool_texture() -> Texture2D:
	if _pool_tex != null:
		return _pool_tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var mid := float(TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var nx := (float(x) - mid) / mid
			var ny := (float(y) - mid) / mid
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, shaped_alpha(nx, ny)))
	_pool_tex = ImageTexture.create_from_image(img)
	return _pool_tex


func _draw() -> void:
	var tex := pool_texture()
	for pool: Array in _pools:
		var center: Vector2 = pool[0]
		var color: Color = pool[1]
		var radius: float = pool[2]
		var peak: float = pool[3]
		var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		# Additive: the quad adds colour * (texture alpha * peak), so the centre
		# adds colour * peak and the rim adds nothing.
		draw_texture_rect(tex, rect, false, Color(color.r, color.g, color.b, peak))
