class_name LightShaft
extends Node2D
## Volumetric light shafts — god rays (design bible 12.17). A few broad, soft,
## angled beams rake down from the top of a room in the zone's own light colour,
## the "light shafts" Sean's reference shots call for in a deep layered background
## (bible 12.0 / the room-density note) and the "windows / light sources" piece of
## his 2026-11-07 lighting-and-depth request that the radial room-light pools
## (12.10) did not cover. Where the pools bleed a source's colour onto the stones
## around it, the shafts add the directional, atmospheric light that reads as
## distance and gives the open air of a room depth.
##
## Combat-safe by construction, like the room-light pools:
## - **Behind the tiles** (`z_index` below the tile layer), so solid geometry
##   occludes a beam — it shows only in the open air of a room, raking over the
##   backdrop, and is cut off by any wall or platform in front of it. Every actor
##   (player, foes, projectiles, drawn at z >= 0) also draws in front of the
##   beams, so a shaft never falls over a foe or a telegraph.
## - **Additive and faint** (`PEAK`), so a beam only ever adds a little light to
##   the backdrop it falls on; it tints the air, it never washes anything out.
## One overlay per room, its geometry built once (12.3's static-overlay rule); a
## slow unison breathe is a cheap `self_modulate` tween with no per-frame redraw.

## Peak additive brightness at a beam's bright core (near the top). Additive and
## low, so the shaft adds atmosphere without touching the contrast combat reads by.
const PEAK := 0.085
## Across-beam strip width in px: each beam is drawn as feathered vertical strips
## so its sides fade to nothing with no hard edge.
const STRIP := 6.0
## Vertical bands a beam is split into, so it brightens toward its top (the light's
## source) and fades down its length — the god-ray gradient, in cheap steps.
const BANDS := 10
## Half-width of a beam's core, in px. A beam feathers to nothing by `HALF` either
## side of its centre line.
const HALF := 34.0
## One beam per this many px of room width, clamped to [MIN_BEAMS, MAX_BEAMS].
const SPACING := 190.0
const MIN_BEAMS := 2
const MAX_BEAMS := 6
## Keep beam centres this far off the room's left and right edges.
const MARGIN := 44.0
## The share of a beam's head over which it fades in from the ceiling, so its top
## is a soft onset, not a hard bright line.
const HEAD := 0.08
## The brightness a beam fades to at the floor (relative to its bright head).
const TAIL := 0.28

## Per-zone light colour and lean (design bible 12.17): each zone's shafts carry
## its own light — warm gold windows in the hearths, green-gold canopy sun in the
## woods, pale cool light through the spring mist and water, violet crystal light
## in the Evercrown and Vorrhallow, bare pale light through the grey stone. Every
## colour is bright (high luminance), so the additive draw adds light, never
## darkens. The lean (horizontal px per vertical px) alternates direction between
## paired zones so the two never cast one identical rake. A zone with no entry
## (the gym, any new zone) gets no shafts.
const SHAFTS := {
	"hearthroot": {"color": Color("f0dca0"), "slope": 0.22},
	"spires": {"color": Color("f0dca0"), "slope": -0.26},
	"heartwood": {"color": Color("d6e89a"), "slope": 0.26},
	"boughs": {"color": Color("f2e6a4"), "slope": -0.30, "peak": 0.2, "half": 44.0},
	"haar": {"color": Color("c2e2ea"), "slope": 0.20},
	"sunken": {"color": Color("bfe6de"), "slope": -0.18},
	"evercrown": {"color": Color("d8bff0"), "slope": 0.24},
	"vorrhallow": {"color": Color("d2bcea"), "slope": -0.22},
	"tower": {"color": Color("dcd8e0"), "slope": 0.28},
	"trials": {"color": Color("dcd8e0"), "slope": -0.24},
}

## The canopy's shade (design bible 12.152, pass 675): a sunlit zone's open air is
## lit from above through a roof of leaves, so it is not one flat wash. Under the
## roof the air lies in shade, multiplied by `tint` at the room's top and clearing
## to nothing `depth` of the way down; the zone's shafts (stronger there, `peak` and
## `half` in SHAFTS) are the sun falling through it. Drawn behind the tiles with the
## beams, so walls, platforms and every actor stay as they were.
const CANOPY := {
	"boughs": {"tint": Color(0.7, 0.8, 0.76), "depth": 0.55},
}
## Bands the canopy's shade is drawn in, top to bottom.
const SHADE_BANDS := 24

## Set by Room before the node enters the tree.
var zone := ""
var room_size := Vector2.ZERO
var seed := 0

var _centers: Array[float] = []
var _t := 0.0


func _ready() -> void:
	# Additive: a beam only ever adds light to the backdrop it falls on.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# Behind the tile layer (z 0), so walls and platforms occlude a beam and it
	# shows only in the open air; still in front of the backdrop (z -50).
	z_index = -1
	if SHAFTS.has(zone):
		_centers = beam_centers(room_size.x, seed)
	if CANOPY.has(zone):
		var shade := CanopyShade.new()
		shade.name = "CanopyShade"
		shade.zone = zone
		shade.room_size = room_size
		# Under the beams: the sun falls through the shade, not under it.
		shade.show_behind_parent = true
		add_child(shade)
	queue_redraw()


## A zone's peak additive brightness: its own `peak` in SHAFTS, or PEAK.
static func peak_for(a_zone: String) -> float:
	return float(SHAFTS.get(a_zone, {}).get("peak", PEAK))


## A zone's beam half-width: its own `half` in SHAFTS, or HALF.
static func half_for(a_zone: String) -> float:
	return float(SHAFTS.get(a_zone, {}).get("half", HALF))


## What the canopy's shade multiplies the air by at `t` (0 the room's top, 1 its
## floor): `tint` at the top, easing to white (no change) by `depth`. White for a
## zone with no canopy. Pure, so the gradient is tested without a scene.
static func shade_at(a_zone: String, t: float) -> Color:
	if not CANOPY.has(a_zone):
		return Color.WHITE
	var spec: Dictionary = CANOPY[a_zone]
	var k := clampf(t / float(spec["depth"]), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return (spec["tint"] as Color).lerp(Color.WHITE, k)


## How many beams a room of this width carries: one per `SPACING` px, clamped.
static func beam_count(width: float) -> int:
	return clampi(roundi(width / SPACING), MIN_BEAMS, MAX_BEAMS)


## The x centre of each beam across a room `width` px wide, spread evenly between
## the margins with a per-beam jitter seeded by `a_seed`, so a room's beams are
## stable across frames and saves but never a mechanical even comb. Pure, so the
## layout is tested without a running scene.
static func beam_centers(width: float, a_seed: int) -> Array[float]:
	var out: Array[float] = []
	var lo := MARGIN
	var hi := width - MARGIN
	if hi <= lo:
		# A room narrower than two margins: one beam down its middle.
		out.append(width * 0.5)
		return out
	var n := beam_count(width)
	var span := hi - lo
	var rng := RandomNumberGenerator.new()
	rng.seed = a_seed
	for i in n:
		var base := lo + span * (float(i) + 0.5) / float(n)
		var jit := rng.randf_range(-1.0, 1.0) * (span / float(n)) * 0.3
		out.append(clampf(base + jit, lo, hi))
	return out


## A beam's across-profile at `dx` px from its centre: 1 at the core, 0 by `half`
## either side, eased (smoothstep) so the sides feather with no hard edge. Pure.
static func across_alpha(dx: float, half: float) -> float:
	var t := clampf(1.0 - absf(dx) / half, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## A beam's brightness down its length at `t` (0 at the ceiling, 1 at the floor):
## a soft fade-in over the first `HEAD`, then a fall from 1 to `TAIL` — the god-ray
## gradient, bright at the source and dimming as it descends. Pure.
static func along_alpha(t: float) -> float:
	var y := clampf(t, 0.0, 1.0)
	if y < HEAD:
		return y / HEAD
	return lerpf(1.0, TAIL, (y - HEAD) / (1.0 - HEAD))


func _draw() -> void:
	if _centers.is_empty():
		return
	var spec: Dictionary = SHAFTS[zone]
	var color: Color = spec["color"]
	var slope: float = spec["slope"]
	var peak := peak_for(zone)
	var half := half_for(zone)
	var h := room_size.y
	for cx: float in _centers:
		# Each strip is drawn with its colour given at its corners, so the beam
		# grades smoothly across and down instead of in visible steps (pass 675:
		# at the Boughs' stronger peak the steps read as seams).
		var ox := -half
		while ox < half:
			var ox1 := minf(ox + STRIP, half)
			var a0 := across_alpha(ox, half)
			var a1 := across_alpha(ox1, half)
			if a0 > 0.0 or a1 > 0.0:
				for b in BANDS:
					var t0 := float(b) / BANDS
					var t1 := float(b + 1) / BANDS
					var y0 := t0 * h
					var y1 := t1 * h
					var d0 := peak * along_alpha(t0)
					var d1 := peak * along_alpha(t1)
					draw_polygon(
						PackedVector2Array([
							Vector2(cx + ox + slope * y0, y0),
							Vector2(cx + ox1 + slope * y0, y0),
							Vector2(cx + ox1 + slope * y1, y1),
							Vector2(cx + ox + slope * y1, y1),
						]),
						PackedColorArray([
							Color(color, d0 * a0),
							Color(color, d0 * a1),
							Color(color, d1 * a1),
							Color(color, d1 * a0),
						])
					)
			ox = ox1


## A slow unison breathe, so the shafts feel like living light rather than a decal.
## Driven on self_modulate (no redraw): the built geometry is untouched.
func _process(delta: float) -> void:
	if _centers.is_empty():
		return
	_t += delta
	self_modulate.a = 0.86 + 0.14 * (0.5 + 0.5 * sin(_t * 0.8))


## The canopy's shade (CANOPY): a multiplied gradient over the open air, darkest
## under the room's top. Built once; no per-frame redraw.
class CanopyShade extends Node2D:
	var zone := ""
	var room_size := Vector2.ZERO

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		material = mat
		queue_redraw()

	func _draw() -> void:
		var h := room_size.y
		var bands := LightShaft.SHADE_BANDS
		var w := room_size.x
		for b in bands:
			var t0 := float(b) / bands
			var t1 := float(b + 1) / bands
			var c0 := LightShaft.shade_at(zone, t0)
			var c1 := LightShaft.shade_at(zone, t1)
			if c0.is_equal_approx(Color.WHITE):
				break
			# Graded down each band, so the shade has no steps.
			draw_polygon(
				PackedVector2Array([Vector2(0, t0 * h), Vector2(w, t0 * h), Vector2(w, t1 * h), Vector2(0, t1 * h)]),
				PackedColorArray([c0, c0, c1, c1])
			)
