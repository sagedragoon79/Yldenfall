class_name PlankSupports
extends Node2D
## What holds each one-way plank up (design bible 12.30). The pass 535
## independent grade read rooms as "empty boxes of unsupported floating planks":
## the plank tile's own trestle (12.20) stays inside its cell, so a run of
## planks in open air still hung on nothing. This layer gives every run of `-`
## planks a support that reaches real structure, planned from the room grid:
##
## - a **knee brace** into a wall the run's end touches;
## - a **post** down to a floor (or a plank) at most `POST_MAX` tiles below;
## - otherwise a pair of **hangers** up to the first solid cell or plank above:
##   rope in the timber and water zones, chain in the stone and iron ones. A
##   hanger with nothing above it within `HANG_MAX` tiles fades out into the
##   dark, as if hung from beyond the view.
##
## Posts are built timber, not sticks (design bible 12.81, pass 596): a squared
## post with a cap block and knee brackets under the board, a footing stone where
## it meets the floor, and bolts in the zone's accent. Two posts under one run
## are tied by a rail and cross-braced, bay by bay, so the run reads as a built
## trestle rather than a table on legs.
##
## A hung run is a deck, not a board (design bible 12.128, pass 652): the pass
## 650 grade read hanging and chain platforms as "debug geometry, thin and the
## backdrop's value". A run that hangs gets a girder under its board, as deep
## as the plank's cell: a dark web behind the plank's trestle, a bottom chord
## bolted under each trestle foot, an end plate at each end and a cast shadow
## beneath, so it reads as one heavy dark mass with a lit top edge. Its hangers
## are heavier (`CHAIN_W`, `ROPE_W`) and take the chord in a stirrup. The
## Evercrown's grown shelves swell into a grown underside instead (`DECK_SWELL`).
##
## Drawn once per room load behind the tiles (z -1, like the ladders), so the
## plank sits over the hanger's foot and actors pass in front. Collision is
## untouched; it is dressing only.

const TILE := 16
## A post reaches down to footing at most this many tiles below the plank.
const POST_MAX := 4
## A hanger reaches up at most this many tiles; past it, it fades into the dark.
const HANG_MAX := 22
## How far a hanger with no anchor above runs before it has faded out, tiles.
const FADE_TILES := 5
## Hangers sit this far in from a run's outer ends, world px.
const INSET := 4.0
## The plank's board is the top 3 world px of its cell (tilegen PLANK, 6 px at density 2).
const BOARD := 3.0
## The board's full depth with its dark underside, world px: a hanger taken from
## a plank above is fixed here, not below that plank's trestle.
const BOARD_UNDER := 5.0
## A post's width, world px (pass 596: it was 2.5, and read as a stick).
const POST_W := 4.0
## A hung deck's girder, world px below the top of its cell: the dark web runs
## from under the board to the chord, and the chord fills the cell's foot.
const DECK_WEB := 5.0
const DECK_CHORD := 12.0
const DECK_FOOT := 16.0
## The shadow a hung deck casts on the air under it, world px deep.
const DECK_SHADOW := 4.0
## How far a grown shelf's underside swells below its cell at its middle, world px.
const DECK_SWELL := 5.0
## A chain link's width and a rope's, world px (pass 652: 3 and 1.5 read as hairs).
const CHAIN_W := 4.0
const ROPE_W := 2.5
## A hung deck's bridle (design bible 12.147, pass 670): its two hangers rise
## as legs to a ring over its middle, at most this far above the board, world px
## (the legs rise as far as they reach in, so they stand at 45 degrees).
const BRIDLE_MAX := 44.0
## A bridle shorter than this reads as a kink, not a bridle: the run keeps two straight hangers.
const BRIDLE_MIN := 16.0
## The ring sits at least this far under the anchor above, world px.
const BRIDLE_CLEAR := 12.0
## The ring's outer width, world px.
const RING := 5.0
## How each zone family meets a hung deck's hangers over its middle (pass 671, design
## bible 12.148). The pass 670 grade read the bridle as "one hung-deck rig pasted
## across four zones". The town and the stone cities keep the bridle on a ring in the
## zone's accent metal ("ring"); the Tower and the Trials lift on a riveted iron
## spreader beam whose chains drop straight to the deck's ends ("spreader", a T, not
## a triangle); the timber and water zones run their ropes up to a wooden pulley block
## on a hook ("block"); the Evercrown's sinews droop and grow together in a swollen
## knot ("knot").
const RIGS := ["ring", "spreader", "block", "knot"]
## A spreader beam stands at most this far over the deck, world px, and is this deep.
const SPREADER_RISE := 20.0
const SPREADER_H := 4.0
## How far a beam runs past each drop, world px.
const SPREADER_OVER := 3.0
## How far a drooping sinew leg sags below its straight line, as a share of its rise.
const KNOT_SAG := 0.3
## How each zone family builds a hung deck (pass 676, design bible 12.153). The pass
## 675 grade still read "the hung-platform setup as one template across the marsh
## road, Tower foot, sky steps and veins": the rig over each deck differed (12.148),
## but every deck under it was the same timber girder. The town keeps the girder
## ("girder"); the Tower and the Trials rivet an iron plate girder stiffened by a
## lit zigzag ("truss"); the timber and water zones hang a raft of logs laid across
## the deck, their round ends in a row under the board ("raft"); the Spires and the
## dwarf halls hang a dressed stone slab corbelled in toward its foot ("slab"); the
## Evercrown's shelves swell into a grown underside ("grown").
const DECKS := ["girder", "truss", "raft", "slab", "grown"]
## A raft log's diameter, world px (two to a cell), and a slab's depth below the cell's foot.
const LOG := 8.0
const SLAB_DROP := 3.0
## How far a slab's corbelled foot steps in at each end, world px.
const SLAB_STEP := 3.0
## A frame's widest bay, world px; a longer span is split into bays.
const BAY_MAX := 48.0
## A frame needs this much height between board and footing, world px (a post
## over one empty row, 29 px, is too squat to cross-brace).
const FRAME_MIN_H := 40.0

## Per-zone support look. `hang` is rope, chain or sinew (a strand drawn like rope); `lit`, `mid`, `dark` are the
## hanger's three tones; `wood` the post and brace timber (lit, mid, dark), in
## the plank's own strut ramp (tilegen PLANK) so the support reads as the same
## build as the board it carries; `bolt` the fastener accent (tilegen PLANK
## `nail`), and `foot` the footing stone (lit, mid, dark). `moss`, where a zone has it
## (lit, mid, dark), grows on the rail and climbs each leg from its footing (pass 637).
const LOOKS := {
	"gym": {"deck": "girder", "frame": "x", "post": "squared", "hang": "rope", "rig": "block", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "aca1ba", "foot": ["797767", "58544c", "363330"]},
	# The Heartwood's timber is old and grey, grown over with moss, and lashed with flax (pass 637).
	"heartwood": {"deck": "raft", "frame": "lashed", "post": "raked", "hang": "rope", "rig": "block", "lit": "aa9173", "mid": "8a6e56", "dark": "3c2c2a", "wood": ["728061", "4f5c47", "2f392d"], "moss": ["49aa36", "2b782c", "1e4825"], "bolt": "f0c02e", "foot": ["797767", "58544c", "363330"]},
	"boughs": {"deck": "raft", "frame": "forked", "post": "trunk", "hang": "rope", "rig": "block", "lit": "cd8c51", "mid": "aa6336", "dark": "48201e", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "a1d684", "foot": ["797767", "58544c", "363330"]},
	"hearthroot": {"deck": "girder", "frame": "x", "post": "squared", "hang": "chain", "rig": "ring", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["aa6336", "783c2b", "48201e"], "bolt": "f0c02e", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"haar": {"deck": "raft", "frame": "piling", "post": "pile", "hang": "rope", "rig": "block", "lit": "aa9173", "mid": "8a6e56", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "989885", "foot": ["797767", "58544c", "363330"]},
	"sunken": {"deck": "raft", "frame": "piling", "post": "pile", "hang": "chain", "rig": "block", "lit": "aa9173", "mid": "634a41", "dark": "3c2c2a", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "84cbd6", "foot": ["797767", "58544c", "363330"]},
	# The Spires are a ruined stone city: their footings and piers are its own lilac stone (pass 625).
	"spires": {"deck": "slab", "frame": "pier", "post": "stone", "hang": "rope", "rig": "ring", "lit": "bea860", "mid": "9c7f44", "dark": "432d23", "wood": ["8a6e56", "634a41", "3c2c2a"], "bolt": "edce6e", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"vorrhallow": {"deck": "slab", "frame": "arch", "post": "stone", "hang": "chain", "rig": "ring", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "d684c6", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"trials": {"deck": "truss", "frame": "truss", "post": "column", "set_in": 8.0, "hang": "chain", "rig": "spreader", "lit": "867ba2", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "b4b4a7", "foot": ["867ba2", "645e82", "2f2c3a"]},
	"tower": {"deck": "truss", "frame": "truss", "post": "column", "set_in": 8.0, "hang": "chain", "rig": "spreader", "lit": "aca1ba", "mid": "645e82", "dark": "2f2c3a", "wood": ["797767", "58544c", "363330"], "bolt": "84cbd6", "foot": ["867ba2", "645e82", "2f2c3a"]},
	# The Evercrown's shelves are grown, not built (bible 12.34, pass 542): they hang on
	# sinew strands (night-5, night-3, crystal-1: wine, not red, bible 12.48), not hot crystal chains.
	"evercrown": {"deck": "grown", "frame": "web", "post": "squared", "hang": "sinew", "rig": "knot", "lit": "af92c9", "mid": "5d4997", "dark": "421e48", "wood": ["8265b8", "5d4997", "2c2541"], "bolt": "b5e3e1", "foot": ["8265b8", "5d4997", "2c2541"]},
}

## How each zone frames two posts under one run (pass 604): the pass 600 grade saw
## "the same X-braced trestle" in nearly every area. The town keeps the carpenter's
## trestle ("x", a rail and a cross-brace per bay); the woods and the Spires lash
## timber with rope ("lashed", one diagonal per bay, rope wrapped at its joints); the
## marsh and the spring stand on pilings ("piling", two stringers, no bracing); the
## Tower and the Trials rivet an iron truss ("truss", two chords and a zigzag web);
## the dwarf halls spring a stone arch ("arch", voussoirs and a keystone); and the
## Evercrown's shelves are grown ("web", two sagging strands of sinew).
##
## Pass 625: the pass 620 grade still saw one scaffold in the Heartwood and the
## High Boughs, which both lashed timber, as the Spires did. The Heartwood keeps
## the lashing; the Boughs prop a board on forked limbs cut from the canopy
## ("forked", a trunk per bay that splits in two under the board, bound with vine
## and still in leaf); the Spires stand theirs on what is left of the city's
## stone ("pier", corbels stepping out under the board's ends and a coursed pier
## between bays, no timber).
const FRAMES := ["x", "lashed", "piling", "truss", "arch", "web", "forked", "pier"]

## How each zone builds the post itself (pass 629, design bible 12.105). The pass
## 625 grade still saw "the same cross-braced plank platform in nearly every
## frame, recoloured": the frames differ by zone, so what repeated was the plank on
## two upright squared posts, a table's outline in every zone. The town keeps the
## squared post ("squared"); the Heartwood rakes its legs in under the board as a
## sawhorse does ("raked"); the Boughs stand a board in the crotch of a cut limb
## ("trunk"); the marsh and the spring drive round piles whose heads stand above the
## deck ("pile"); the Tower and the Trials set riveted iron columns in from the
## board's ends on gusset plates, so the deck overhangs them ("column", `set_in`);
## the Spires and the dwarf halls build coursed stone piers ("stone").
const POSTS := ["squared", "raked", "trunk", "pile", "column", "stone"]
## How far a raked leg leans in under the board, world px (a quarter of its height at most).
const RAKE := 7.0
## How far a pile's head stands above the deck, world px.
const PILE_HEAD := 5.0
## A run must be at least this many cells long for its posts to be set in from its ends.
const SET_IN_CELLS := 3

## The plan, one Dictionary per support: {kind: "brace", "post" or "hang", ...}.
var supports: Array[Dictionary] = []
## The hung decks, one {left, right, y} per run that hangs (pass 652).
var decks: Array[Dictionary] = []
## The bridles, one {left, right, x, apex, top, foot} per deck whose hangers meet over it (pass 670).
var bridles: Array[Dictionary] = []
var _look: Dictionary = LOOKS["gym"]


func _ready() -> void:
	z_index = -1


## Plans the supports for `planks` (cells of `-`) given which cells look solid.
func setup(zone: String, planks: Dictionary, solid: Dictionary, size: Vector2i) -> void:
	_look = LOOKS.get(zone, LOOKS["gym"])
	supports = PlankSupports.place(PlankSupports.plan(planks, solid, size), _look)
	decks = PlankSupports.hung_decks(planks, supports)
	for s: Dictionary in supports:
		if s.kind != "hang":
			continue
		for d: Dictionary in decks:
			if s.x >= d.left and s.x <= d.right and is_equal_approx(s.bottom, d.y + BOARD):
				s["stirrup"] = d.y + PlankSupports.deck_depth(_look)
	bridles = PlankSupports.bridle(planks, solid, size, supports)
	queue_redraw()


## The bridles (design bible 12.147, pass 670). The pass 665 grade read hung
## runs as "platforms hung on chains and ropes from nothing": two parallel lines
## rising out of the frame, one from each end, like two strings of debug lines.
## A run whose two hangers are both its own meets them over its middle instead:
## each rises from its end of the board as a leg, at 45 degrees, to a ring, and
## one hanger runs on from the ring to the first solid cell or plank above the
## middle, fixed there on a cleat. A run keeps its two straight hangers when
## nothing is above its middle within `HANG_MAX`, or when the anchor is too close
## for a bridle of `BRIDLE_MIN`. Marks each bridled hanger `bridled`.
static func bridle(planks: Dictionary, solid: Dictionary, size: Vector2i, held: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Vector3i in runs(planks):
		var board := run.x * TILE + BOARD
		var left := float(run.y * TILE)
		var right := float((run.z + 1) * TILE)
		var legs: Array[Dictionary] = []
		for s: Dictionary in held:
			if s.kind == "hang" and s.x >= left and s.x <= right and is_equal_approx(s.bottom, board):
				legs.append(s)
		if legs.size() != 2:
			continue
		var a: Dictionary = legs[0] if legs[0].x < legs[1].x else legs[1]
		var b: Dictionary = legs[1] if a == legs[0] else legs[0]
		var mid: float = (a.x + b.x) * 0.5
		# The anchor over the middle: of the one or two columns the middle touches, the nearest.
		var top := -INF
		for col: int in [int(floorf((mid - 0.5) / TILE)), int(floorf((mid + 0.5) / TILE))]:
			var above := PlankSupports._gap(col, run.x, -1, planks, solid, size)
			if above < 0 or above > HANG_MAX:
				continue
			var t := float((run.x - above) * TILE)
			if planks.has(Vector2i(col, run.x - above - 1)):
				t = (run.x - above - 1) * TILE + BOARD_UNDER
			top = maxf(top, t)
		if is_inf(top):
			continue
		var rise: float = minf(minf((b.x - a.x) * 0.5, BRIDLE_MAX), board - BRIDLE_CLEAR - top)
		rise = floorf(rise)
		if rise < BRIDLE_MIN:
			continue
		a["bridled"] = true
		b["bridled"] = true
		out.append({"left": a.x, "right": b.x, "x": mid, "apex": board - rise, "top": top, "foot": board})
	return out


## The runs that hang (pass 652): a run with a hanger under its board is a deck,
## spanning the run's cells, at its cell's top (`y`).
static func hung_decks(planks: Dictionary, held: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Vector3i in runs(planks):
		var left := float(run.y * TILE)
		var right := float((run.z + 1) * TILE)
		var y := float(run.x * TILE)
		for s: Dictionary in held:
			if s.kind == "hang" and s.x >= left and s.x <= right and is_equal_approx(s.bottom, y + BOARD):
				out.append({"left": left, "right": right, "y": y})
				break
	return out


## The rects of a hung deck's girder, each [Rect2, hex tone] or [Rect2, hex, alpha],
## back to front (pass 652): the dark web, the chord with its bolts, the end
## plates, and the shadow cast under it. A grown look (`web` frame) swells into
## a rounded underside instead of a chord.
static func deck_parts(left: float, right: float, y: float, look: Dictionary) -> Array:
	match String(look.get("deck", "girder")):
		"truss":
			return PlankSupports._truss_deck(left, right, y, look)
		"raft":
			return PlankSupports._raft_deck(left, right, y, look)
		"slab":
			return PlankSupports._slab_deck(left, right, y, look)
	var out: Array = []
	var w: Array = look.wood
	var width := right - left
	if look.get("deck", "girder") == "grown":
		# A grown underside, deepest at the middle, its rim a shade darker, a pore here and there.
		var n := int(width)
		for i in n:
			var t := (i + 0.5) / maxf(width, 1.0)
			var depth := DECK_FOOT - DECK_WEB + DECK_SWELL * sin(PI * t)
			var x := left + i
			# It faces down, away from the light: a band of the mid tone under the
			# board, then the dark tone, so it is a shaded mass and not a flat slab.
			var lit_h := floorf(depth * 0.3)
			out.append([Rect2(x, y + DECK_WEB, 1.0, depth), w[2]])
			out.append([Rect2(x, y + DECK_WEB, 1.0, lit_h + (1.0 if i % 3 == 0 else 0.0)), w[1]])
			out.append([Rect2(x, y + DECK_WEB + depth, 1.0, DECK_SHADOW), w[2], 0.35])
		for i in range(5, n - 4, 11):
			out.append([Rect2(left + i, y + DECK_CHORD, 1.0, 1.0), look.bolt])
		return out
	# The web behind the plank's trestle, so the girder reads as one mass.
	out.append([Rect2(left, y + DECK_WEB, width, DECK_CHORD - DECK_WEB), w[2]])
	# The chord: lit top, body, dark underside.
	out.append([Rect2(left, y + DECK_CHORD, width, DECK_FOOT - DECK_CHORD), w[1]])
	out.append([Rect2(left, y + DECK_CHORD, width, 1.0), w[0]])
	out.append([Rect2(left, y + DECK_FOOT - 1.0, width, 1.0), w[2]])
	# A bolt under each trestle foot (one every 8 px, as the plank's grooves fall).
	var x := left + 4.0
	while x < right - 2.0:
		out.append([Rect2(x, y + DECK_CHORD + 1.5, 1.0, 1.0), look.bolt])
		x += 8.0
	# End plates.
	for e: float in [left, right - 2.0]:
		out.append([Rect2(e, y + DECK_WEB, 2.0, DECK_FOOT - DECK_WEB), w[1]])
		out.append([Rect2(e, y + DECK_WEB, 0.5, DECK_FOOT - DECK_WEB), w[0]])
	# The shadow it casts on the air under it, falling off.
	out.append([Rect2(left + 1.0, y + DECK_FOOT, width - 2.0, DECK_SHADOW * 0.5), w[2], 0.45])
	out.append([Rect2(left + 2.0, y + DECK_FOOT + DECK_SHADOW * 0.5, width - 4.0, DECK_SHADOW * 0.5), w[2], 0.2])
	return out


## How far under its cell's top a deck's underside reaches, where a hanger's stirrup takes it, world px.
static func deck_depth(look: Dictionary) -> float:
	match String(look.get("deck", "girder")):
		"raft":
			return DECK_WEB + LOG + 1.0
		"slab":
			return DECK_FOOT + SLAB_DROP
	return DECK_FOOT


## An iron plate girder (pass 676): a dark web as deep as the cell, a lit zigzag of
## stiffeners riveted at each node, a heavy bottom flange in the hanger's iron, end
## posts, and the shadow under it.
static func _truss_deck(left: float, right: float, y: float, look: Dictionary) -> Array:
	var out: Array = []
	var width := right - left
	var top := y + DECK_WEB
	out.append([Rect2(left, top, width, DECK_FOOT - DECK_WEB), look.dark])
	# The flange: lit top, the iron's mid tone, a dark foot.
	out.append([Rect2(left, y + DECK_CHORD, width, DECK_FOOT - DECK_CHORD), look.mid])
	out.append([Rect2(left, y + DECK_CHORD, width, 1.0), look.lit])
	out.append([Rect2(left, y + DECK_FOOT - 1.0, width, 1.0), look.dark])
	# The stiffeners: one diagonal per 8 px bay, alternating, from under the board to the flange.
	var h := y + DECK_CHORD - top
	var bay := 0
	var x := left + 2.0
	while x + 8.0 <= right - 1.0:
		for i in 8:
			var t := (i + 0.5) / 8.0
			var dy := floorf((t if bay % 2 == 0 else 1.0 - t) * (h - 1.0))
			out.append([Rect2(x + i, top + dy, 1.0, 1.0), look.mid])
			if dy >= 1.0:
				out.append([Rect2(x + i, top + dy - 1.0, 1.0, 1.0), look.lit])
		out.append([Rect2(x - 0.5, top + (0.0 if bay % 2 == 0 else h - 2.0), 1.0, 1.0), look.bolt])
		bay += 1
		x += 8.0
	# Rivets along the flange, one under each trestle foot.
	x = left + 4.0
	while x < right - 2.0:
		out.append([Rect2(x, y + DECK_CHORD + 1.5, 1.0, 1.0), look.bolt])
		x += 8.0
	for e: float in [left, right - 2.0]:
		out.append([Rect2(e, top, 2.0, DECK_FOOT - DECK_WEB), look.mid])
		out.append([Rect2(e, top, 0.5, DECK_FOOT - DECK_WEB), look.lit])
	out.append([Rect2(left + 1.0, y + DECK_FOOT, width - 2.0, DECK_SHADOW * 0.5), look.dark, 0.45])
	out.append([Rect2(left + 2.0, y + DECK_FOOT + DECK_SHADOW * 0.5, width - 4.0, DECK_SHADOW * 0.5), look.dark, 0.2])
	return out


## A raft of logs laid across the deck (pass 676): under the board, a row of round
## log ends, `LOG` across, each a dark rim, the timber's face and a lit growth ring
## toward the key light, so its underside is scalloped; a rope lashing runs along
## their tops, and each log casts its own shadow.
static func _raft_deck(left: float, right: float, y: float, look: Dictionary) -> Array:
	var out: Array = []
	var w: Array = look.wood
	var top := y + DECK_WEB
	var rows := [4.0, 6.0, 8.0, 8.0, 8.0, 8.0, 6.0, 4.0]
	var n := maxi(1, int(floorf((right - left) / LOG)))
	var pad := ((right - left) - n * LOG) * 0.5
	for k in n:
		var cx := left + pad + (k + 0.5) * LOG
		for i in rows.size():
			var rw: float = rows[i]
			out.append([Rect2(cx - rw * 0.5, top + i, rw, 1.0), w[2]])
			if i > 0 and i < rows.size() - 1:
				out.append([Rect2(cx - rw * 0.5 + 1.0, top + i, rw - 2.0, 1.0), w[1]])
		# The end grain: a lit ring on its upper left, a dark heart.
		out.append([Rect2(cx - 2.0, top + 2.0, 2.0, 1.0), w[0]])
		out.append([Rect2(cx - 3.0, top + 3.0, 1.0, 2.0), w[0]])
		out.append([Rect2(cx - 0.5, top + 3.5, 1.0, 1.0), w[2]])
		out.append([Rect2(cx - 2.0, top + LOG, 4.0, DECK_SHADOW * 0.5), w[2], 0.4])
	# The lashing: a rope over the logs' tops, under the board, in the hanger's lay.
	out.append([Rect2(left, top, right - left, 1.0), look.mid])
	var x := left + 1.0
	while x < right - 1.0:
		out.append([Rect2(x, top, 1.0, 1.0), look.lit])
		x += 3.0
	return out


## A dressed stone slab (pass 676): two courses as deep as the cell and `SLAB_DROP`
## past it, the lower course stepped in `SLAB_STEP` at each end like a corbel, lit
## along its top and its left face, mortar joints staggered course by course, and
## the shadow under its narrower foot.
static func _slab_deck(left: float, right: float, y: float, look: Dictionary) -> Array:
	var out: Array = []
	var f: Array = look.foot
	var top := y + DECK_WEB
	var mid := y + DECK_CHORD - 1.0
	var foot := y + DECK_FOOT + SLAB_DROP
	var courses := [[left, right, top, mid], [left + SLAB_STEP, right - SLAB_STEP, mid, foot]]
	for ci in courses.size():
		var c: Array = courses[ci]
		var x0: float = c[0]
		var x1: float = c[1]
		var y0: float = c[2]
		var y1: float = c[3]
		out.append([Rect2(x0, y0, x1 - x0, y1 - y0), f[2]])
		out.append([Rect2(x0 + 0.5, y0 + 0.5, x1 - x0 - 1.0, y1 - y0 - 1.5), f[1]])
		out.append([Rect2(x0 + 0.5, y0 + 0.5, x1 - x0 - 1.0, 1.0), f[0]])
		out.append([Rect2(x0 + 0.5, y0 + 0.5, 1.0, y1 - y0 - 1.5), f[0]])
		# Mortar joints, staggered: every 16 px, the lower course offset by 8.
		var jx := x0 + (12.0 if ci == 0 else 8.0)
		while jx < x1 - 4.0:
			out.append([Rect2(jx, y0 + 1.0, 1.0, y1 - y0 - 1.5), f[2]])
			out.append([Rect2(jx + 1.0, y0 + 1.0, 0.5, y1 - y0 - 1.5), f[0]])
			jx += 16.0
	# A cramp in the accent metal across the courses' meeting, every 16 px.
	var bx := left + 8.0
	while bx < right - 6.0:
		out.append([Rect2(bx, mid - 0.5, 2.0, 1.0), look.bolt])
		bx += 16.0
	out.append([Rect2(left + SLAB_STEP + 1.0, foot, right - left - SLAB_STEP * 2.0 - 2.0, DECK_SHADOW * 0.5), f[2], 0.45])
	out.append([Rect2(left + SLAB_STEP + 2.0, foot + DECK_SHADOW * 0.5, right - left - SLAB_STEP * 2.0 - 4.0, DECK_SHADOW * 0.5), f[2], 0.2])
	return out


## Horizontal runs of plank cells, each [row, first column, last column], in reading order.
static func runs(planks: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cells: Array = planks.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in cells:
		if planks.has(c + Vector2i.LEFT):
			continue
		var end := c.x
		while planks.has(Vector2i(end + 1, c.y)):
			end += 1
		out.append(Vector3i(c.y, c.x, end))
	return out


static func plan(planks: Dictionary, solid: Dictionary, size: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Vector3i in runs(planks):
		var row := run.x
		var ends := [run.y, run.z]
		var held := [false, false]
		# A knee brace where an end butts against a wall that runs on below it.
		for i in 2:
			var side := -1 if i == 0 else 1
			var wall := Vector2i(ends[i] + side, row)
			if solid.has(wall) and solid.has(wall + Vector2i.DOWN):
				out.append({"kind": "brace", "cell": Vector2i(ends[i], row), "side": side})
				held[i] = true
		if held[0] and held[1]:
			continue
		# Short runs carried at one end need nothing more.
		if (held[0] or held[1]) and run.z - run.y < 3:
			continue
		var posts: Array[Dictionary] = []
		for i in 2:
			if held[i] or (i == 1 and run.y == run.z):
				continue
			var col: int = ends[i]
			var x := col * TILE + (INSET if i == 0 else TILE - INSET)
			if run.y == run.z:
				x = col * TILE + TILE * 0.5
			var below := PlankSupports._gap(col, row, 1, planks, solid, size)
			if below >= 1 and below <= POST_MAX:
				# Knee brackets toward the run's middle only, so none juts past its end.
				var knees: Array = [-1, 1] if run.y == run.z else [1 if i == 0 else -1]
				var post := {"kind": "post", "x": x, "top": row * TILE + BOARD, "bottom": float((row + 1 + below) * TILE), "knees": knees, "cells": run.z - run.y + 1}
				out.append(post)
				posts.append(post)
				continue
			var above := PlankSupports._gap(col, row, -1, planks, solid, size)
			var anchored := above >= 0 and above <= HANG_MAX
			var top := float((row - above) * TILE) if anchored else float((row - FADE_TILES) * TILE)
			if anchored and planks.has(Vector2i(col, row - above - 1)):
				top = (row - above - 1) * TILE + BOARD_UNDER
			if not anchored:
				top = maxf(top, 0.0)
			out.append({"kind": "hang", "x": x, "top": top, "bottom": row * TILE + BOARD, "anchored": anchored})
		# Two posts under one run are tied by a rail and cross-braced (pass 596).
		if posts.size() == 2:
			var low := minf(posts[0].bottom, posts[1].bottom)
			if low - posts[0].top >= FRAME_MIN_H:
				out.append({"kind": "frame", "left": posts[0].x, "right": posts[1].x, "top": posts[0].top, "bottom": low, "cells": run.z - run.y + 1})
	return out


## The plan as a zone builds it (pass 629): a look with `set_in` stands the end
## posts of a run of `SET_IN_CELLS` cells or more that far in from where the plan
## put them (still over the same floor cell), braced to the board on both sides,
## and its frame spans the moved posts. Other looks take the plan as it is.
static func place(planned: Array[Dictionary], look: Dictionary) -> Array[Dictionary]:
	var shift: float = look.get("set_in", 0.0)
	if shift <= 0.0:
		return planned
	var out: Array[Dictionary] = []
	for s: Dictionary in planned:
		var d := s.duplicate()
		if int(s.get("cells", 1)) >= SET_IN_CELLS:
			if s.kind == "post" and s.knees.size() == 1:
				d.x = s.x + s.knees[0] * shift
				d.knees = [-1, 1]
			elif s.kind == "frame":
				d.left = s.left + shift
				d.right = s.right - shift
		out.append(d)
	return out


## Empty cells between (col, row) and the first solid cell or plank in direction
## `dir` (1 down, -1 up). -1 if there is none inside the room.
static func _gap(col: int, row: int, dir: int, planks: Dictionary, solid: Dictionary, size: Vector2i) -> int:
	var y := row + dir
	var n := 0
	while y >= 0 and y < size.y:
		var c := Vector2i(col, y)
		if solid.has(c) or planks.has(c):
			return n
		n += 1
		y += dir
	return -1


func _draw() -> void:
	for s: Dictionary in supports:
		match s.kind:
			"brace":
				_draw_brace(s.cell, s.side)
			"post":
				_draw_parts(PlankSupports.post_parts(s.x, s.top, s.bottom, _look, s.get("knees", [-1, 1])))
			"frame":
				_draw_parts(PlankSupports.frame_parts(s.left, s.right, s.top, s.bottom, _look))
			"hang":
				var bottom: float = s.get("stirrup", s.bottom)
				# A bridled hanger keeps only its foot, from the board to the stirrup; its leg is the bridle's.
				var top: float = s.bottom if s.get("bridled", false) else s.top
				if _look.hang == "chain":
					_draw_chain(s.x, top, bottom, s.anchored and not s.get("bridled", false))
				else:
					_draw_rope(s.x, top, bottom, s.anchored and not s.get("bridled", false))
	# Each bridle: the hanger above its head, its two legs, then the head over them (pass 671: per zone family).
	for br: Dictionary in bridles:
		var head_top := PlankSupports.rig_top(br, _look)
		if _look.hang == "chain":
			_draw_chain(br.x, br.top, head_top, true)
		else:
			_draw_rope(br.x, br.top, head_top, true)
		for end: float in [br.left, br.right]:
			_draw_leg(PlankSupports.leg_path(br, end, _look))
		_draw_parts(PlankSupports.rig_parts(br, _look))
	# Decks over their hangers' feet, then the stirrups that take each chord.
	for d: Dictionary in decks:
		_draw_parts(PlankSupports.deck_parts(d.left, d.right, d.y, _look))
	for s: Dictionary in supports:
		if s.kind == "hang" and s.has("stirrup"):
			_draw_stirrup(s.x, s.stirrup)


func _c(hex: String, a := 1.0) -> Color:
	var col := Color(hex)
	col.a = a
	return col


## Alpha for a hanger at height y: full near the plank, fading toward `top` when unanchored.
func _fade(y: float, top: float, bottom: float, anchored: bool) -> float:
	if anchored:
		return 1.0
	return clampf((y - top) / maxf(bottom - top, 1.0), 0.0, 1.0)


func _draw_rope(x: float, top: float, bottom: float, anchored: bool) -> void:
	# A `ROPE_W` strand with a twist: a lit lay crossing it every 2 px, and a dark
	# core line down its right side (pass 652: it was 1.5 px, a hair).
	var y := top
	var k := 0
	var hw := ROPE_W * 0.5
	while y < bottom:
		var a := _fade(y, top, bottom, anchored)
		var h := minf(2.0, bottom - y)
		draw_rect(Rect2(x - hw, y, ROPE_W, h), _c(_look.mid, a))
		draw_rect(Rect2(x - hw + (0.0 if k % 2 == 0 else 1.0), y, 1.0, minf(1.0, h)), _c(_look.lit, a))
		draw_rect(Rect2(x + hw - 0.5, y, 0.5, h), _c(_look.dark, a))
		y += 2.0
		k += 1
	if anchored:
		_draw_cleat(x, top)


func _draw_chain(x: float, top: float, bottom: float, anchored: bool) -> void:
	# Links `CHAIN_W` wide and 4 px long, alternating face-on (an open oval with a
	# dark eye) and edge-on (a bar), each lit on its left (pass 652: 3 px read as a hair).
	var y := top
	var k := 0
	var hw := CHAIN_W * 0.5
	while y < bottom:
		var a := _fade(y, top, bottom, anchored)
		var h := minf(4.0, bottom - y)
		if k % 2 == 0:
			draw_rect(Rect2(x - hw, y, CHAIN_W, h), _c(_look.mid, a))
			draw_rect(Rect2(x - hw, y, 1.0, h), _c(_look.lit, a))
			draw_rect(Rect2(x + hw - 1.0, y, 1.0, h), _c(_look.dark, a))
			if h > 2.0:
				draw_rect(Rect2(x - 0.5, y + 1.0, 1.0, h - 2.0), _c(_look.dark, a))
		else:
			draw_rect(Rect2(x - 0.5, y - 0.5, 1.0, h + 1.0), _c(_look.lit, a))
			draw_rect(Rect2(x + 0.5, y - 0.5, 0.5, h + 1.0), _c(_look.dark, a))
		y += 3.5
		k += 1
	if anchored:
		_draw_cleat(x, top)


## A bridle's leg along `path` (from its end of the board up to the head), in
## the zone's hanger: a chain as links that swell face-on and narrow edge-on,
## every `CHAIN_W` along it; a rope or sinew as a `ROPE_W` strand with a lit lay.
## Each is lit on its upper left and dark on its lower right, on the 2-pixel grid.
func _draw_leg(path: PackedVector2Array) -> void:
	var chain: bool = _look.hang == "chain"
	var along := 0.0
	for i in path.size():
		if i > 0:
			along += path[i].distance_to(path[i - 1])
		var p := path[i].snapped(Vector2(0.5, 0.5))
		if chain:
			var face := int(along / 4.0) % 2 == 0
			var w := 2.0 if face else 1.0
			draw_rect(Rect2(p.x - w * 0.5, p.y - w * 0.5, w, w), _c(_look.mid))
			draw_rect(Rect2(p.x - w * 0.5, p.y - w * 0.5, 0.5, 0.5), _c(_look.lit))
			draw_rect(Rect2(p.x + w * 0.5 - 0.5, p.y + w * 0.5 - 0.5, 0.5, 0.5), _c(_look.dark))
		else:
			var hw := 1.0
			draw_rect(Rect2(p.x - hw, p.y - hw, hw * 2.0, hw * 2.0), _c(_look.mid))
			if int(along / 2.0) % 2 == 0:
				draw_rect(Rect2(p.x - hw, p.y - hw, 0.5, 0.5), _c(_look.lit))
			draw_rect(Rect2(p.x + hw - 0.5, p.y + hw - 0.5, 0.5, 0.5), _c(_look.dark))


## Where a bridle's head meets its legs, world y (pass 671): a spreader beam stands
## no higher than `SPREADER_RISE` over the deck; every other head at the bridle's apex.
static func rig_apex(br: Dictionary, look: Dictionary) -> float:
	if String(look.get("rig", "ring")) == "spreader":
		return maxf(br.apex, br.foot - SPREADER_RISE)
	return br.apex


## The top of a bridle's head, where the one hanger above it ends, world y.
static func rig_top(br: Dictionary, look: Dictionary) -> float:
	var ay := PlankSupports.rig_apex(br, look)
	match String(look.get("rig", "ring")):
		"spreader":
			return ay - SPREADER_H * 0.5 - 3.0
		"block":
			return ay - 11.0
		"knot":
			return ay - 3.0
	return ay - RING * 0.5


## A bridle leg's points from its end of the board (`end`) up to the head, every
## half pixel (pass 671): straight at 45 degrees to a ring or a block's hook; straight
## down from a spreader beam; a sinew drooping below its straight line to the knot.
static func leg_path(br: Dictionary, end: float, look: Dictionary) -> PackedVector2Array:
	var rig := String(look.get("rig", "ring"))
	var ay := PlankSupports.rig_apex(br, look)
	var foot := Vector2(end, br.foot)
	var head := Vector2(br.x, ay)
	if rig == "spreader":
		head = Vector2(end, ay + SPREADER_H * 0.5)
	elif rig == "knot":
		head = Vector2(br.x, ay + 2.0)
	var d := head - foot
	var n := maxi(1, int(ceilf(maxf(absf(d.x), absf(d.y)) / 0.5)))
	var ctrl := (foot + head) * 0.5 + Vector2(0.0, (foot.y - head.y) * KNOT_SAG)
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		if rig == "knot":
			out.append(foot.lerp(ctrl, t).lerp(ctrl.lerp(head, t), t))
		else:
			out.append(foot.lerp(head, t))
	return out


## The rects of a bridle's head, each [Rect2, hex tone], back to front (pass 671).
static func rig_parts(br: Dictionary, look: Dictionary) -> Array:
	var out: Array = []
	var x: float = br.x
	var ay := PlankSupports.rig_apex(br, look)
	var w: Array = look.wood
	match String(look.get("rig", "ring")):
		"spreader":
			# A riveted iron beam over the deck, its ends past the drops, a shackle on its middle.
			var x0: float = br.left - SPREADER_OVER
			var x1: float = br.right + SPREADER_OVER
			var y0 := ay - SPREADER_H * 0.5
			out.append([Rect2(x0, y0, x1 - x0, SPREADER_H), look.dark])
			out.append([Rect2(x0 + 0.5, y0 + 0.5, x1 - x0 - 1.0, SPREADER_H - 1.5), look.mid])
			out.append([Rect2(x0 + 0.5, y0 + 0.5, x1 - x0 - 1.0, 1.0), look.lit])
			for rx: float in [br.left, x, br.right]:
				out.append([Rect2(rx - 0.5, y0 + 1.0, 1.0, 1.0), look.bolt])
			out.append([Rect2(x - 2.0, y0 - 3.0, 4.0, 3.0), look.dark])
			out.append([Rect2(x - 1.5, y0 - 3.0, 3.0, 0.5), look.lit])
			out.append([Rect2(x - 0.5, y0 - 2.0, 1.0, 1.5), look.mid])
		"block":
			# A wooden pulley block on an iron strap, its sheave pinned, a hook under it the legs meet on.
			out.append([Rect2(x - 1.0, ay - 11.0, 2.0, 2.5), look.dark])
			out.append([Rect2(x - 3.0, ay - 9.0, 6.0, 7.0), w[2]])
			out.append([Rect2(x - 2.5, ay - 8.5, 5.0, 6.0), w[1]])
			out.append([Rect2(x - 2.5, ay - 8.5, 1.0, 6.0), w[0]])
			out.append([Rect2(x - 1.0, ay - 7.0, 2.0, 3.0), w[2]])
			out.append([Rect2(x - 0.5, ay - 6.0, 1.0, 1.0), look.bolt])
			out.append([Rect2(x - 0.5, ay - 2.0, 1.0, 2.0), look.dark])
			out.append([Rect2(x - 1.5, ay - 0.5, 1.5, 1.0), look.dark])
		"knot":
			# The sinews grow together in a swollen knot, lit on its upper left, a pore glowing in it.
			var rows := [3.0, 5.0, 7.0, 7.0, 5.0, 3.0]
			for i in rows.size():
				var rw: float = rows[i]
				out.append([Rect2(x - rw * 0.5, ay - 3.0 + i, rw, 1.0), w[2] if i >= 3 else w[1]])
			out.append([Rect2(x - 1.5, ay - 3.0, 1.5, 1.0), w[0]])
			out.append([Rect2(x - 2.5, ay - 2.0, 1.0, 1.0), w[0]])
			out.append([Rect2(x + 0.5, ay - 1.0, 1.0, 1.0), look.bolt])
		_:
			# A ring in the zone's accent metal: a dark eye, lit along its top and left.
			var h := RING * 0.5
			out.append([Rect2(x - h, ay - h, RING, RING), look.dark])
			out.append([Rect2(x - h + 0.5, ay - h + 0.5, RING - 1.0, RING - 1.0), look.mid])
			out.append([Rect2(x - h + 0.5, ay - h + 0.5, RING - 1.5, 0.5), look.bolt])
			out.append([Rect2(x - h + 0.5, ay - h + 0.5, 0.5, RING - 1.5), look.bolt])
			out.append([Rect2(x - 1.0, ay - 1.0, 2.0, 2.0), look.dark])
	return out


## The strap a hanger takes a deck's chord in: up both faces and under the chord.
func _draw_stirrup(x: float, foot: float) -> void:
	var hw := maxf(CHAIN_W, ROPE_W) * 0.5 + 1.0
	var h := DECK_FOOT - DECK_CHORD + 2.0
	draw_rect(Rect2(x - hw, foot - h + 1.0, 1.0, h), _c(_look.dark))
	draw_rect(Rect2(x + hw - 1.0, foot - h + 1.0, 1.0, h), _c(_look.dark))
	draw_rect(Rect2(x - hw, foot, hw * 2.0, 1.0), _c(_look.dark))
	draw_rect(Rect2(x - hw, foot - h + 1.0, 1.0, 1.0), _c(_look.lit))


## The iron plate a hanger is fixed to where it meets a ceiling or plank above.
func _draw_cleat(x: float, top: float) -> void:
	draw_rect(Rect2(x - 3.0, top, 6.0, 2.0), _c(_look.dark))
	draw_rect(Rect2(x - 2.5, top, 5.0, 0.5), _c(_look.lit))


func _draw_parts(parts: Array) -> void:
	for p: Array in parts:
		draw_rect(p[0], _c(p[1], p[2] if p.size() > 2 else 1.0))


## The rects of a post, each [Rect2, hex tone], back to front (pass 596): a
## squared post with a lit and a shaded edge and grain ticks, a cap block under
## the board with a bolt, knee brackets on the `knees` sides (-1 left, 1 right),
## and a footing stone.
static func post_parts(x: float, top: float, bottom: float, look: Dictionary, knees: Array = [-1, 1]) -> Array:
	match String(look.get("post", "squared")):
		"raked":
			# A lone post under a one-cell plank has no side to lean to: it stands square.
			if knees.size() == 1:
				return PlankSupports._raked_post(x, top, bottom, look, knees[0])
		"trunk":
			return PlankSupports._trunk_post(x, top, bottom, look, knees)
		"pile":
			return PlankSupports._pile_post(x, top, bottom, look, knees)
		"column":
			return PlankSupports._column_post(x, top, bottom, look, knees)
		"stone":
			return PlankSupports._stone_post(x, top, bottom, look, knees)
	var w: Array = look.wood
	var f: Array = look.foot
	var h := bottom - top
	var half := POST_W * 0.5
	var out: Array = []
	out.append([Rect2(x - half, top, POST_W, h), w[1]])
	out.append([Rect2(x - half, top, 1.0, h), w[0]])
	out.append([Rect2(x + half - 1.0, top, 1.0, h), w[2]])
	# Grain: short dark ticks down the face, alternating sides.
	var y := top + 6.0
	var k := 0
	while y < bottom - 6.0:
		out.append([Rect2(x - 0.5 + (0.5 if k % 2 else -0.5), y, 1.0, 1.5), w[2]])
		y += 5.0
		k += 1
	# Knee brackets: a short strut from the post up to the board, on the `knees` sides.
	if h >= 12.0:
		for side: int in knees:
			for i in 6:
				var px := x + side * (half + i * 0.75) - (1.0 if side < 0 else 0.0)
				var py := top + 6.5 - i * 0.75
				out.append([Rect2(px, py, 1.5, 1.5), w[1]])
				out.append([Rect2(px, py, 1.5, 0.5), w[0]])
	# The cap block the board rests on, with a bolt through it.
	out.append([Rect2(x - half - 2.0, top, POST_W + 4.0, 2.0), w[2]])
	out.append([Rect2(x - half - 2.0, top + 1.5, POST_W + 4.0, 0.5), w[1]])
	out.append([Rect2(x - 0.5, top + 0.5, 1.0, 1.0), look.bolt])
	# The footing stone: wider than the post, lit along its top.
	out.append([Rect2(x - half - 2.0, bottom - 3.0, POST_W + 4.0, 3.0), f[1]])
	out.append([Rect2(x - half - 2.0, bottom - 3.0, POST_W + 4.0, 0.5), f[0]])
	out.append([Rect2(x - half - 2.0, bottom - 0.5, POST_W + 4.0, 0.5), f[2]])
	out.append([Rect2(x + half + 1.0, bottom - 2.5, 1.0, 2.5), f[2]])
	PlankSupports._moss_climb(out, x, bottom - 3.0, h, look)
	return out


## How far a raked leg of height `h` leans in at its top.
static func rake(h: float) -> float:
	return minf(RAKE, h * 0.25)


## The wide stone a timber post stands on, lit along its top.
static func _footing(out: Array, x: float, bottom: float, f: Array) -> void:
	out.append([Rect2(x - 4.0, bottom - 3.0, 8.0, 3.0), f[1]])
	out.append([Rect2(x - 4.0, bottom - 3.0, 8.0, 0.5), f[0]])
	out.append([Rect2(x - 4.0, bottom - 0.5, 8.0, 0.5), f[2]])
	out.append([Rect2(x + 3.0, bottom - 2.5, 1.0, 2.5), f[2]])


## A raked leg (the Heartwood, pass 629): squared timber that stands where the
## plan put its foot and leans in under the board toward `dir`, so the board
## overhangs it as a sawhorse's does. A cap under the board, rope wrapped below
## the cap in place of a bolt, and a footing stone.
static func _raked_post(x: float, top: float, bottom: float, look: Dictionary, dir: int) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var h := bottom - top
	var lean := PlankSupports.rake(h)
	var y := top
	while y < bottom - 2.0:
		var cx := snappedf(x + dir * lean * (1.0 - (y - top) / h), 0.5)
		out.append([Rect2(cx - 2.0, y, 4.0, 1.0), w[1]])
		out.append([Rect2(cx - 2.0, y, 1.0, 1.0), w[0]])
		out.append([Rect2(cx + 1.0, y, 1.0, 1.0), w[2]])
		if int(y - top) % 5 == 3:
			out.append([Rect2(cx - 0.5, y, 1.0, 1.0), w[2]])
		y += 1.0
	var tx := snappedf(x + dir * lean, 0.5)
	out.append([Rect2(tx - 4.0, top, 8.0, 2.0), w[2]])
	out.append([Rect2(tx - 4.0, top + 1.5, 8.0, 0.5), w[1]])
	PlankSupports._lashing(out, Vector2(tx - dir * 0.5, top + 4.5), look)
	PlankSupports._footing(out, x, bottom, look.foot)
	PlankSupports._moss_climb(out, x, bottom - 3.0, h, look)
	return out


## Moss on the top of a timber from `x0` to `x1` at `y` (pass 637): cushions a few
## px wide every so often, placed by position so a run is the same each load, and
## now and then a strand hanging under it. Nothing where the zone has no moss.
static func _moss_beam(out: Array, x0: float, x1: float, y: float, look: Dictionary) -> void:
	if not look.has("moss"):
		return
	var m: Array = look.moss
	var x := x0 + 2.0
	while x < x1 - 3.0:
		var k := int(absf(x * 7.0 + y * 3.0)) % 5
		var wide := 3.0 + k % 3
		if k != 4:
			out.append([Rect2(x, y - 1.5, wide, 1.0), m[1]])
			out.append([Rect2(x + 1.0, y - 2.0, wide - 2.0, 0.5), m[0]])
			out.append([Rect2(x, y - 0.5, wide, 0.5), m[2]])
		if k == 1:
			out.append([Rect2(x + 1.0, y + 1.5, 1.0, 2.0 + k), m[2]])
		x += wide + 4.0 + k


## Moss climbing a leg from its footing at `foot`, a third of the way up at most (pass 637).
static func _moss_climb(out: Array, x: float, foot: float, h: float, look: Dictionary) -> void:
	if not look.has("moss"):
		return
	var m: Array = look.moss
	var up := minf(8.0, h * 0.33)
	out.append([Rect2(x - 2.5, foot - 1.0, 5.0, 1.0), m[1]])
	out.append([Rect2(x - 2.0, foot - 1.5, 4.0, 0.5), m[0]])
	var y := foot - 2.0
	var k := 0
	while y > foot - up:
		out.append([Rect2(x - 2.0 + (1.0 if k % 2 else 0.0), y, 2.0, 1.0), m[1] if k % 3 else m[2]])
		y -= 1.5
		k += 1


## A cut limb (the High Boughs, pass 629): a trunk that stands on a flared root
## and forks under the board, which lies in the crotch. The limb toward the run's
## middle reaches further; under a one-cell plank both reach alike. Vine bound
## at the fork and a sprig still in leaf. No cap, no bolt, no footing stone.
static func _trunk_post(x: float, top: float, bottom: float, look: Dictionary, knees: Array) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var h := bottom - top
	var dir: int = knees[0] if knees.size() == 1 else 0
	var foot := Vector2(x, bottom - 1.5)
	var fork := Vector2(x + dir * 1.0, top + minf(10.0, h * 0.4))
	PlankSupports._strut(out, foot + Vector2(1.0, 0), fork + Vector2(1.0, 0), w[2], w[2])
	PlankSupports._strut(out, foot, fork, w[1], w[1])
	PlankSupports._strut(out, foot + Vector2(-1.0, 0), fork + Vector2(-1.0, 0), w[0], w[0])
	for side: int in [-1, 1]:
		var reach := 6.0 if dir == 0 else (7.0 if side == dir else 2.5)
		var arm := Vector2(x + side * reach, top + 2.0)
		PlankSupports._strut(out, fork + Vector2(0, 1.0), arm + Vector2(0, 1.0), w[2], w[2])
		PlankSupports._strut(out, fork, arm, w[1], w[0])
	out.append([Rect2(x - 3.0, bottom - 2.0, 6.0, 1.0), w[1]])
	out.append([Rect2(x - 4.0, bottom - 1.0, 8.0, 1.0), w[2]])
	PlankSupports._lashing(out, fork + Vector2(0, 2.0), look)
	var leaf := fork + Vector2((dir if dir != 0 else 1) * 3.0 - 1.0, -4.0)
	out.append([Rect2(leaf.x, leaf.y, 2.0, 1.0), look.bolt])
	out.append([Rect2(leaf.x + 0.5, leaf.y - 1.0, 2.0, 1.0), look.bolt])
	out.append([Rect2(leaf.x + 0.5, leaf.y + 1.0, 1.0, 1.0), look.dark])
	return out


## A driven pile (the marsh and the spring, pass 629): a round pile 5 px thick
## with no cap, brackets or footing stone. At a run's end its head stands
## `PILE_HEAD` px above the deck, banded with iron, and rope is wrapped round it
## under the board; its foot is dark with water and stands in a little mud. A
## lone pile under a one-cell plank stops under the board.
static func _pile_post(x: float, top: float, bottom: float, look: Dictionary, knees: Array) -> Array:
	var w: Array = look.wood
	var f: Array = look.foot
	var out: Array = []
	var head := knees.size() == 1
	var y0 := top - BOARD - PILE_HEAD if head else top
	var body := y0 + (1.0 if head else 0.0)
	out.append([Rect2(x - 2.5, body, 5.0, bottom - body), w[1]])
	out.append([Rect2(x - 2.5, body, 1.0, bottom - body), w[0]])
	out.append([Rect2(x + 1.0, body, 1.5, bottom - body), w[2]])
	if head:
		# The rounded head and its iron band.
		out.append([Rect2(x - 1.5, y0, 3.0, 1.0), w[0]])
		out.append([Rect2(x - 2.5, y0 + 3.0, 5.0, 1.0), w[2]])
		out.append([Rect2(x - 0.5, y0 + 3.0, 1.0, 1.0), look.bolt])
	else:
		out.append([Rect2(x - 0.5, top + 1.0, 1.0, 1.0), look.bolt])
	# Rope wrapped round the pile under the board.
	for k in 3:
		out.append([Rect2(x - 3.0, top + 2.0 + k, 6.0, 0.5), look.mid if k != 1 else look.lit])
	out.append([Rect2(x - 3.0, top + 5.0, 6.0, 0.5), look.dark])
	# The foot, dark with water up to a tide line, in a mound of mud.
	out.append([Rect2(x - 2.5, bottom - 7.0, 5.0, 7.0), w[2]])
	out.append([Rect2(x - 2.5, bottom - 7.5, 3.5, 0.5), w[0]])
	out.append([Rect2(x - 4.0, bottom - 1.5, 8.0, 1.5), f[2]])
	out.append([Rect2(x - 3.0, bottom - 2.0, 6.0, 0.5), f[1]])
	return out


## A riveted iron column (the Tower and the Trials, pass 629): an H-section 4 px
## wide (two lit flanges and a dark web) with rivets down the web, a gusset plate
## up to the board on each `knees` side and a bolted base plate. No footing stone.
static func _column_post(x: float, top: float, bottom: float, look: Dictionary, knees: Array) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var h := bottom - top
	out.append([Rect2(x - 2.0, top, 4.0, h), w[2]])
	out.append([Rect2(x - 2.0, top, 1.0, h), w[0]])
	out.append([Rect2(x + 1.0, top, 1.0, h), w[1]])
	var y := top + 12.0
	while y < bottom - 5.0:
		out.append([Rect2(x - 0.5, y, 1.0, 1.0), look.bolt])
		y += 9.0
	# Gusset plates: a stepped triangle from the flange out to the board's underside.
	for side: int in knees:
		for i in 7:
			var run := 7.0 - i
			var px := x + 2.0 if side > 0 else x - 2.0 - run
			out.append([Rect2(px, top + 2.0 + i, run, 1.0), w[1]])
			out.append([Rect2(px + (run - 1.0 if side > 0 else 0.0), top + 2.0 + i, 1.0, 1.0), w[0]])
		out.append([Rect2(x + side * 4.0 - 0.5, top + 3.5, 1.0, 1.0), look.bolt])
	# The cap plate under the board and the base plate, bolted down.
	out.append([Rect2(x - 3.0, top, 6.0, 2.0), w[1]])
	out.append([Rect2(x - 3.0, top, 6.0, 0.5), w[0]])
	out.append([Rect2(x - 4.0, bottom - 2.0, 8.0, 2.0), w[1]])
	out.append([Rect2(x - 4.0, bottom - 2.0, 8.0, 0.5), w[0]])
	for bx: float in [x - 3.5, x + 2.5]:
		out.append([Rect2(bx, bottom - 1.5, 1.0, 1.0), look.bolt])
	return out


## A stone pier (the Spires and the dwarf halls, pass 629): coursed blocks 6 px
## wide in the footing's stone, their upright joints staggered, on a plinth, under
## a head of two courses that corbel out toward each `knees` side. No timber and
## no bolt.
static func _stone_post(x: float, top: float, bottom: float, look: Dictionary, knees: Array) -> Array:
	var f: Array = look.foot
	var out: Array = []
	var y := top + 6.0
	var k := 0
	while y < bottom - 3.0:
		var ch := minf(5.0, bottom - 3.0 - y)
		PlankSupports._block(out, Rect2(x - 3.0, y, 6.0, ch), f)
		if ch > 2.0:
			out.append([Rect2(x - 1.0 + (2.0 if k % 2 == 0 else 0.0), y + 0.5, 0.5, ch - 1.0), f[2]])
		y += 5.0
		k += 1
	for i in 2:
		var reach := 4.0 - i * 2.0
		var l := x - 3.0 - (reach if -1 in knees else 0.0)
		var r := x + 3.0 + (reach if 1 in knees else 0.0)
		PlankSupports._block(out, Rect2(l, top + i * 3.0, r - l, 3.0), f)
	PlankSupports._block(out, Rect2(x - 4.0, bottom - 3.0, 8.0, 3.0), f)
	return out


## The rects of the frame between a run's two posts: a rail low down and a
## cross-brace in every bay (no bay wider than BAY_MAX), with a stud between bays
## and a bolt where each brace meets a post or the rail.
static func frame_parts(left: float, right: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var half := POST_W * 0.5
	var x0 := left + half
	var x1 := right - half
	var out: Array = []
	if x1 - x0 < 8.0:
		return out
	match String(look.get("frame", "x")):
		"lashed":
			return PlankSupports._lashed_parts(x0, x1, top, bottom, look)
		"piling":
			return PlankSupports._piling_parts(x0, x1, top, bottom, look)
		"truss":
			return PlankSupports._truss_parts(x0, x1, top, bottom, look)
		"arch":
			return PlankSupports._arch_parts(x0, x1, top, bottom, look)
		"web":
			return PlankSupports._web_parts(x0, x1, top, bottom, look)
		"forked":
			return PlankSupports._forked_parts(x0, x1, top, bottom, look)
		"pier":
			return PlankSupports._pier_parts(x0, x1, top, bottom, look)
	var rail := bottom - 9.0
	var high := top + 9.0
	var bays := maxi(1, ceili((x1 - x0) / BAY_MAX))
	var bay := (x1 - x0) / bays
	for b in bays:
		var a := x0 + b * bay
		var e := a + bay
		for diag: int in 2:
			var ya := high if diag == 0 else rail
			var ye := rail if diag == 0 else high
			var n := maxi(2, ceili(maxf(e - a, absf(ye - ya)) / 0.75))
			for i in n + 1:
				var t := float(i) / n
				var px := lerpf(a, e, t)
				var py := lerpf(ya, ye, t)
				out.append([Rect2(px - 0.75, py - 0.75, 1.5, 1.5), w[1]])
				out.append([Rect2(px - 0.75, py - 0.75, 1.5, 0.5), w[0]])
		if b > 0:
			out.append([Rect2(a - 1.0, top, 2.0, rail - top), w[1]])
			out.append([Rect2(a - 1.0, top, 0.5, rail - top), w[0]])
			out.append([Rect2(a + 0.5, top, 0.5, rail - top), w[2]])
	# The rail, over the braces' feet.
	out.append([Rect2(x0, rail - 1.0, x1 - x0, 2.5), w[1]])
	out.append([Rect2(x0, rail - 1.0, x1 - x0, 0.5), w[0]])
	out.append([Rect2(x0, rail + 1.0, x1 - x0, 0.5), w[2]])
	for bx: float in [x0 + 1.0, x1 - 2.0]:
		out.append([Rect2(bx, rail - 0.5, 1.0, 1.0), look.bolt])
		out.append([Rect2(bx, high - 0.5, 1.0, 1.0), look.bolt])
	return out


## A strut of 1.5 px squares from `a` to `b`, lit along its top (a brace, a diagonal).
static func _strut(out: Array, a: Vector2, b: Vector2, body: String, lit: String) -> void:
	var n := maxi(2, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y)) / 0.75))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		out.append([Rect2(q.x - 0.75, q.y - 0.75, 1.5, 1.5), body])
		out.append([Rect2(q.x - 0.75, q.y - 0.75, 1.5, 0.5), lit])


## A level beam from x0 to x1 at y, 2.5 px deep, lit on top, shaded beneath.
static func _beam(out: Array, x0: float, x1: float, y: float, w: Array) -> void:
	out.append([Rect2(x0, y - 1.0, x1 - x0, 2.5), w[1]])
	out.append([Rect2(x0, y - 1.0, x1 - x0, 0.5), w[0]])
	out.append([Rect2(x0, y + 1.0, x1 - x0, 0.5), w[2]])


## How many bays a span takes and how wide each is (no bay over BAY_MAX).
static func _bays(x0: float, x1: float) -> Vector2:
	var n := maxi(1, ceili((x1 - x0) / BAY_MAX))
	return Vector2(n, (x1 - x0) / n)


## Rope lashing where two timbers meet: three wraps in the hanger's rope tones.
static func _lashing(out: Array, at: Vector2, look: Dictionary) -> void:
	for k in 3:
		out.append([Rect2(at.x - 1.5, at.y - 1.5 + k, 3.0, 0.5), look.mid if k != 1 else look.lit])
	out.append([Rect2(at.x - 1.5, at.y + 1.5, 3.0, 0.5), look.dark])


## Lashed timber (the woods, the Spires): a low rail, studs between bays, and one
## diagonal per bay, leaning the other way in the next, rope wrapped at each joint.
static func _lashed_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var rail := bottom - 9.0
	var high := top + 7.0
	var bays := PlankSupports._bays(x0, x1)
	# Between raked legs (pass 629) the frame's upper corners come in with the legs.
	var rk := 0.0
	if String(look.get("post", "")) == "raked":
		rk = PlankSupports.rake(bottom - top) * (1.0 - (high - top) / (bottom - top))
	var last := int(bays.x) - 1
	for b in int(bays.x):
		var a := x0 + b * bays.y
		var e := a + bays.y
		var up := b % 2 == 0
		if up and b == last:
			e -= rk
		if not up and b == 0:
			a += rk
		PlankSupports._strut(out, Vector2(a, rail if up else high), Vector2(e, high if up else rail), w[1], w[0])
		if b > 0:
			out.append([Rect2(a - 1.0, top, 2.0, rail - top), w[1]])
			out.append([Rect2(a - 1.0, top, 0.5, rail - top), w[0]])
	PlankSupports._beam(out, x0, x1, rail, w)
	PlankSupports._moss_beam(out, x0, x1, rail, look)
	for b in int(bays.x):
		var a := x0 + b * bays.y
		var e := a + bays.y
		var up := b % 2 == 0
		if up and b == last:
			e -= rk
		if not up and b == 0:
			a += rk
		PlankSupports._lashing(out, Vector2(a + 2.0, (rail if up else high)), look)
		PlankSupports._lashing(out, Vector2(e - 2.0, (high if up else rail)), look)
	return out


## Pilings (the marsh, the spring): stout piles between the posts and two
## stringers, high and low, and no bracing: a boardwalk standing in water.
static func _piling_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var bays := PlankSupports._bays(x0, x1)
	for b in range(1, int(bays.x)):
		var a := x0 + b * bays.y
		out.append([Rect2(a - 1.5, top, 3.0, bottom - top - 1.0), w[1]])
		out.append([Rect2(a - 1.5, top, 1.0, bottom - top - 1.0), w[0]])
		out.append([Rect2(a + 0.5, top, 1.0, bottom - top - 1.0), w[2]])
		# The pile's foot, darkened by water.
		out.append([Rect2(a - 1.5, bottom - 7.0, 3.0, 6.0), w[2]])
	for y: float in [top + 7.0, bottom - 11.0]:
		PlankSupports._beam(out, x0, x1, y, w)
		out.append([Rect2(x0 + 1.0, y - 0.5, 1.0, 1.0), look.bolt])
		out.append([Rect2(x1 - 2.0, y - 0.5, 1.0, 1.0), look.bolt])
	return out


## An iron truss (the Tower, the Trials): a top chord under the board, a bottom
## chord, and a zigzag web of struts between them, riveted at every node.
static func _truss_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var hi := top + 5.0
	var lo := bottom - 9.0
	var panels := maxi(2, roundi((x1 - x0) / 16.0))
	var step := (x1 - x0) / panels
	var nodes: Array[Vector2] = []
	for i in panels + 1:
		nodes.append(Vector2(x0 + i * step, lo if i % 2 == 0 else hi))
	for i in panels:
		PlankSupports._strut(out, nodes[i], nodes[i + 1], w[1], w[0])
	PlankSupports._beam(out, x0, x1, hi, w)
	PlankSupports._beam(out, x0, x1, lo, w)
	for n: Vector2 in nodes:
		out.append([Rect2(n.x - 0.5, n.y - 0.5, 1.0, 1.0), look.bolt])
	return out


## A stone arch (the dwarf halls): voussoirs springing from the posts' feet side
## and rising to a keystone under the board, a band of the footing's stone.
static func _arch_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var f: Array = look.foot
	var out: Array = []
	var spring := bottom - 8.0
	var crown := top + 4.0
	var mid := (x0 + x1) * 0.5
	var half := (x1 - x0) * 0.5
	var n := maxi(8, ceili(half * 2.0 / 0.5))
	var deep := 4.0
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(x0, x1, t)
		var u := (x - mid) / half
		var y := crown + (spring - crown) * u * u
		# On the steep flanks a column also covers the drop to the next, so the
		# band stays whole instead of stepping apart.
		var drop := absf(2.0 * (spring - crown) * u / half) * 0.5
		var h := minf(deep + drop, spring + deep - y)
		out.append([Rect2(x - 0.25, y, 0.5, h), f[1]])
		out.append([Rect2(x - 0.25, y, 0.5, 0.5), f[0]])
		out.append([Rect2(x - 0.25, y + h - 0.5, 0.5, 0.5), f[2]])
		# A joint between voussoirs every few stones.
		if i % 10 == 5:
			out.append([Rect2(x - 0.25, y, 0.5, h), f[2]])
	# The keystone, a shade lighter, standing proud at the crown.
	out.append([Rect2(mid - 2.0, crown - 1.0, 4.0, 5.0), f[1]])
	out.append([Rect2(mid - 2.0, crown - 1.0, 4.0, 1.0), f[0]])
	out.append([Rect2(mid + 1.5, crown - 1.0, 0.5, 5.0), f[2]])
	return out


## Grown sinew (the Evercrown): two strands sag from post to post, crossing low
## in the middle, with a knot of tissue where each takes a post.
static func _web_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var hi := top + 6.0
	var lo := bottom - 10.0
	for strand in 2:
		var a := Vector2(x0, hi if strand == 0 else lo)
		var e := Vector2(x1, lo if strand == 0 else hi)
		var sag := (bottom - top) * 0.18
		var n := maxi(8, ceili((x1 - x0) / 0.75))
		for i in n + 1:
			var t := float(i) / n
			var q := a.lerp(e, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
			q.y = minf(q.y, bottom - 2.0)
			out.append([Rect2(q.x - 0.75, q.y - 0.5, 1.5, 1.0), w[1]])
			out.append([Rect2(q.x - 0.75, q.y - 0.5, 1.5, 0.5), w[0]])
		for end: Vector2 in [a, e]:
			out.append([Rect2(end.x - 1.5, end.y - 1.5, 3.0, 3.0), w[2]])
			out.append([Rect2(end.x - 1.0, end.y - 1.0, 1.0, 1.0), look.bolt])
	return out


## Forked limbs (the High Boughs, pass 625): in every bay a trunk cut from the
## canopy stands on the floor and splits in two under the board, each limb
## running up to it. Vine is bound round the fork, a root flares at the foot and
## a sprig of leaves still grows at the fork and near a limb's end, in the zone's
## leaf accent. No rail, no bolts: nothing here was sawn square.
static func _forked_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var w: Array = look.wood
	var out: Array = []
	var bays := PlankSupports._bays(x0, x1)
	var h := bottom - top
	for b in int(bays.x):
		var cx := x0 + (b + 0.5) * bays.y
		# Each trunk leans a little and forks at its own height, so a row is not one stamp.
		var lean := 1.5 if b % 2 == 0 else -1.5
		var fork := Vector2(cx + lean, top + h * (0.5 if b % 2 == 0 else 0.42))
		# Short of the next trunk's limbs, so each fork stands as its own tree.
		var spread := minf(bays.y * 0.34, h * 0.42)
		var foot := Vector2(cx - lean, bottom - 1.5)
		var arms := [Vector2(cx - spread, top + 3.0), Vector2(cx + spread * (0.8 if b % 2 == 0 else 1.0), top + 3.0)]
		# The trunk: three struts side by side make a limb 3 px thick, lit on its left.
		PlankSupports._strut(out, foot + Vector2(1.0, 0), fork + Vector2(1.0, 0), w[2], w[1])
		PlankSupports._strut(out, foot, fork, w[1], w[0])
		for arm: Vector2 in arms:
			PlankSupports._strut(out, fork, arm, w[1], w[0])
		# A root flaring each way at the foot.
		out.append([Rect2(foot.x - 3.0, bottom - 2.0, 7.0, 1.0), w[1]])
		out.append([Rect2(foot.x - 4.0, bottom - 1.0, 9.0, 1.0), w[2]])
		# Vine bound round the fork.
		PlankSupports._lashing(out, fork + Vector2(0.5, 1.0), look)
		# Leaves: a sprig at the fork and one near the end of the longer limb.
		for at: Vector2 in [fork + Vector2(-3.5, -3.0), arms[1].lerp(fork, 0.3) + Vector2(1.5, -2.5)]:
			out.append([Rect2(at.x, at.y, 2.0, 1.0), look.bolt])
			out.append([Rect2(at.x + 1.0, at.y - 1.0, 2.0, 1.0), look.bolt])
			out.append([Rect2(at.x + 0.5, at.y + 1.0, 1.0, 1.0), look.dark])
	return out


## One course of a stone pier or corbel: a block lit along its top and shaded beneath.
static func _block(out: Array, r: Rect2, f: Array) -> void:
	out.append([r, f[1]])
	out.append([Rect2(r.position.x, r.position.y, r.size.x, 0.5), f[0]])
	out.append([Rect2(r.position.x, r.end.y - 0.5, r.size.x, 0.5), f[2]])
	out.append([Rect2(r.end.x - 0.5, r.position.y, 0.5, r.size.y), f[2]])


## Stone piers (the Spires, pass 625): what the storm left of the city carries
## the board. Corbels step out under each end, three courses deep, and between
## bays stands a pier of coursed blocks under a corbelled head, its joints
## staggered and one block knocked from a flank. No timber between the posts.
static func _pier_parts(x0: float, x1: float, top: float, bottom: float, look: Dictionary) -> Array:
	var f: Array = look.foot
	var out: Array = []
	var bays := PlankSupports._bays(x0, x1)
	var head := top + 2.0
	# Corbels under the board's ends: the top course reaches furthest.
	for i in 3:
		var reach := minf(12.0 - i * 4.0, (x1 - x0) * 0.5)
		PlankSupports._block(out, Rect2(x0, head + i * 3.0, reach, 3.0), f)
		PlankSupports._block(out, Rect2(x1 - reach, head + i * 3.0, reach, 3.0), f)
	for b in range(1, int(bays.x)):
		var cx := x0 + b * bays.y
		# The head: two courses stepping in to the shaft.
		PlankSupports._block(out, Rect2(cx - 7.0, head, 14.0, 3.0), f)
		PlankSupports._block(out, Rect2(cx - 5.0, head + 3.0, 10.0, 3.0), f)
		# The shaft: courses 5 px deep, their upright joints staggered.
		var y := head + 6.0
		var k := 0
		while y < bottom - 4.0:
			var ch := minf(5.0, bottom - 4.0 - y)
			PlankSupports._block(out, Rect2(cx - 3.0, y, 6.0, ch), f)
			out.append([Rect2(cx - 1.0 + (2.0 if k % 2 == 0 else 0.0), y + 0.5, 0.5, ch - 1.0), f[2]])
			# A block knocked out of one flank, part of the way down.
			if k == 2 + b % 2:
				out.append([Rect2(cx + (1.5 if b % 2 == 0 else -3.0), y, 1.5, ch), f[2]])
			y += 5.0
			k += 1
		# The base: one wide course on the floor.
		PlankSupports._block(out, Rect2(cx - 5.0, bottom - 4.0, 10.0, 4.0), f)
	return out


func _draw_brace(cell: Vector2i, side: int) -> void:
	# A diagonal strut from the wall, a tile below the board, up to the plank's
	# underside a tile in from the wall, with a bolt plate at each end.
	var w: Array = _look.wood
	var wall_x := float(cell.x * TILE if side < 0 else (cell.x + 1) * TILE)
	var top := cell.y * TILE + BOARD
	var steps := int(TILE * 2) # half-pixel steps along a 16 px diagonal
	for i in steps:
		var d := i * 0.5
		var px := wall_x - side * d
		var py := top + TILE - d
		draw_rect(Rect2(px - 0.75, py - 0.75, 2.0, 1.5), _c(w[1]))
		draw_rect(Rect2(px - 0.75, py - 0.75, 2.0, 0.5), _c(w[0]))
		draw_rect(Rect2(px - 0.75, py + 0.5, 2.0, 0.5), _c(w[2]))
	draw_rect(Rect2(wall_x - (2.0 if side > 0 else 0.0), top + TILE - 2.0, 2.0, 4.0), _c(w[2]))
