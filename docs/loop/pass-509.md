# Pass 509: room light sources — drawn emissive light pools (RoomLight)

## Category

Lighting / depth, from Sean's own queue item (2026-11-07), not the rubric rotation. The art loop stays
**blocked** — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK, the
limit of three, and no note frees a slot — so the headline PixelLab work cannot move. (Pass 508, PR #569,
the four-tall passages for the 2x hero, is Sean's own merge, held; this is the next loop number.)

Sean's top-queue request is a lighting-and-depth pass. Pass 505 shipped the **distance-fog colour**,
pass 507 the **per-zone whole-scene colour grade** — both light the *whole* frame. This pass takes the
next, nearer piece pass 507's "Next" named first: **room light sources**. The independent grade kept
flagging that "the few light sources (lanterns, candles) cast no falloff, bloom or coloured pools onto
nearby geometry" (passes 501/503/504) — a lamp was a bright sprite stuck on a flat scene. Fully
code-first, GPU-only (an additive overlay), no art touched. No PixelLab generations.

## What was built

**`RoomLight`** (`scripts/world/room_light.gd`), a per-room overlay that draws a soft radial **pool** of
each fixed scenery source's own colour onto the floor and walls around it (design bible 12.10):

- **The pool maths.** Each pool is `STEPS` (6) concentric filled circles, largest to smallest, each the
  same faint alpha; stacked additively they sum to a centre peak and step linearly down to the edge
  (`RoomLight.rings`). So `peak` is the true centre brightness, capped at `READABLE_CAP` (0.16).
- **Additive and capped, so combat stays readable.** A pool only ever *adds* a little light; it tints
  its pocket, never washes it out, and the lit gameplay layer keeps its contrast.
- **Under the actors.** The overlay is added to the room right after the tile layer — before the
  sources, decor and actors — so by tree order the pool draws over the raw tiles but under every foe and
  the player: a pool lights the ground a foe stands on, not the foe.
- **Fixed sources only.** A source opts into the `room_light` group and exposes `glow_color` /
  `glow_radius`. Enlisted: **town lamps** (warm gold, 112 px), **meditation shrines** (rune cyan,
  96 px), the **Kettleforge forge** (ember, 118 px), and the **decor's own candle/fungus glows** (each
  zone's glow colour, a tighter 46 px pool). Dynamic lights — projectiles, foes, pickups — stay in the
  fog's separate `light` group and are deliberately never pooled, so a thrown fireball drags no light
  across the floor.
- **Static.** Pools are gathered once, when the room enters the tree (a deferred `_collect`), then never
  recomputed — no per-frame cost, like `EdgeShade` (12.3).

The overlay reuses the existing light decor unchanged: a lamp still draws its own flickering flame and a
shrine its rune; `RoomLight` adds only the *spill* onto the surrounding geometry that the grade flagged
as missing. It is multiplied by the per-zone grade (12.9) like everything else, so a warm hearth's pools
stay warm and a cold spring's cool — the three lighting layers (fog recession, whole-scene grade, local
pools) agree.

## Tests

`tests/test_room_light.gd` (7 tests, 36 checks):

- **Falloff maths** (pure): the rings shrink strictly, every ring adds light at the same alpha, and the
  centre sums to the requested peak (0.16 / 0.11 / 0.05); neither pool brightness exceeds the cap.
- **Colour/reach read**: a source's own `glow_color` / `glow_radius` is read (the shrine's rune and
  96 px), and a bare node falls back to the warm defaults.
- **Collect** (integration): a room with a save shrine builds a `RoomLight` that pools a rune-coloured
  light under the cap; the overlay sits before (under) the actors in the room's children; a `Fireball`
  added to the room adds no pool.

**Mutation-checked:** collecting the fog `light` group instead of `room_light` lights the fireball and
fails the projectile test; making the ring radii flat (ignoring the step) fails the falloff test.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Pools are additive, capped at 0.16 and drawn under the actors, so foes and telegraphs keep their contrast. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 92 | Fixed lights now bleed their colour onto the stones around them, on top of pass 505's distance fog and pass 507's whole-scene grade — the three lighting layers agree, so a lamp reads as a warm pocket in the dark rather than a sticker. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Static additive overlay gathered once per room; GPU-only, no per-frame cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 97.95.

## Next

Pass 510: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The remaining
unblocked pieces of Sean's lighting/depth request are **rim light on figures** (a directional key edge on
the player and foes, so a lit figure separates from its backdrop), **dark foreground silhouette layers**
that pass in front of the camera for depth, and **more parallax layers**. Rim light on figures is the
natural next step and the one that most lifts the hero's read, but it must be judged hard against combat
readability. The queued **midground-variant** pass (vary `<zone>_mid.png` so the backdrop brick stops
repeating) is the strongest non-lighting code-first item. The hero sprite (the grade's top defect) needs
PixelLab and would be a fourth base — held until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
