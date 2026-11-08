# Pass 511: a distant ridge parallax layer between far and mid

## Category

Lighting / depth, from Sean's own queue item (2026-11-07), not the rubric rotation. The art loop stays
**blocked** — three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK, the
limit of three, and no note frees a slot — so the headline PixelLab work cannot move. (Pass 508, PR #569,
the four-tall passages for the 2x hero, is Sean's own merge, held; this is the next loop number.)

Sean's top-queue request is a lighting-and-depth pass, worked across passes 505 (distance-fog colour),
507 (per-zone whole-scene grade), 509 (room light sources) and 510 (foreground silhouette layers). Two
pieces of it were still open: **rim light on figures** and **more parallax layers**. Rim light on figures
is the piece that most lifts the hero's read, but every figure is drawn procedurally with a swapping
material (the hero's dye, a foe's hurt-wash and death-dissolve) and code-drawn accessories, so a uniform
rim needs a cross-cutting compositing change (a `CanvasGroup` per figure) that is risky to land unattended
against Sean's combat-readability guardrail. This pass takes the other open piece — **more parallax
layers** — which is squarely within the same request, uses the proven `tilegen`/`Backdrop` machinery, and
is combat-safe because it only adds a layer *behind* the play field.

## What was built

A new **distant ridge parallax layer** (design bible 12.12): a third painted back layer between `far` and
`mid`, so the parallax recedes through three depths instead of two and the play field reads clear of the
backdrop (the independent grade's recurring "depth collapse").

**The art** — `tools/art/tilegen.py` paints one `<zone>_ridge.png` per shipped zone with a single
parametrized painter (like the foreground, 12.11): a seamless rolling ridgeline filled from the horizon
(`RIDGE_BASE`, canvas y = 0.56·height) down to the bottom, over an otherwise transparent sky. The crest
profile is the zone's distant material (`RIDGE_KIND`):

- **Firs** (Heartwood, the High Boughs) — a pointed treeline.
- **Low mounds** (the Haar, the Sunken Spring) — a calm marsh horizon.
- **Crystal shards** (the Evercrown, Vorrhallow) — sharp leaning spikes.
- **Broken crags** (the Tower, the Trials) — a jagged rock ridge.
- **Battlemented roofs** (Hearthroot, the Spires) — a distant town skyline.

The silhouette is a dark shade of each zone's dominant ramp with a one-step-lighter crest rim
(`RIDGE_COLOR`), so a warm hearth and a cold spring never share one ridge. The roll is summed from
whole-cycle sines and the teeth wrap at the seam, so the layer tiles sideways with no join.

**The layer** — `Backdrop` draws it like the other back layers, between `far` and `mid`:

- **Between, in depth.** `LAYERS` is insertion-ordered back to front, so `far` (scroll 0.15/0.1) draws
  first and furthest back, the `ridge` (0.26/0.19) between, `mid` (0.4/0.3) nearest. Its scroll sits
  between the two, so it parallaxes as a mid-distance.
- **Receded by the haze.** It carries the atmosphere material (12.5) with knobs between the two —
  `ATMOS["ridge"]` desat 0.42 / fade 0.37, stronger than `mid` (0.3 / 0.24) and lighter than `far`
  (0.55 / 0.5) — so it sits back in the zone's fog colour and the three layers recede in order.
- **Only where art exists.** A zone with no `<zone>_ridge.png` (the gym, any new zone) gets no layer and
  draws exactly as before.

Verified by eye at 1x and 2x in Heartwood (amber_falls), the Haar (drowned_stair), the Evercrown
(drift_well) and the Tower (bell_loft): the ridge reads as receded depth where the backdrop is open (the
Haar's blue hills behind the light pools, the Evercrown's faint violet shards), is quietly hidden where a
room is enclosed, and the play field, platforms, hero and foes stay clearly readable throughout — the
ridge is hazed into the fog and never touches the contrast of the gameplay layer.

## Tests

`tests/test_backdrop.gd` (4 new tests): the back layers run far → ridge → mid in draw order; the ridge
scrolls between far and mid on both axes; the ridge is desaturated and faded between far and mid (the
three layers recede in order, driven through the tested `haze_color` maths); and `atmos_material("ridge")`
carries the ridge parameters. `tests/test_rooms.gd` updated: every dressed zone now builds four backdrop
children (far, ridge, mid, fore), exactly one of them the ridge.

`tools/art/test_tilegen.py` (6 new tests, run locally — CI runs no Python): every shipped zone has a ridge
and the gym none; the ridge is horizon-weighted with a clear sky above; it fills to the bottom edge; it is
a dark tinted silhouette (brightest channel < 150); the body/rim are dark palette shades one step apart;
and the seam join is no rougher than the roughest interior join (seamless tiling).

**Mutation-checked:** a non-periodic roll (non-integer sine cycles) spikes the seam join and fails the
seamless guard; painting the ridge in a lit shade fails the dark-silhouette guard; reordering `ATMOS` or
`LAYERS` fails the recede/ordering tests.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The ridge is a distant layer behind the play field, hazed into the fog; it never touches the contrast of the gameplay layer, so foes and telegraphs still pop (checked in four zones). |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 94 | The parallax now recedes through three painted depths (far, ridge, mid) plus the foreground (510), on top of the fog (505), grade (507) and room-light pools (509) — the play field separates further from the backdrop, the grade's recurring "depth collapse". Each zone's ridge is its own material and colour. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged; arenas stay fully readable with the receded ridge. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A static parallax sprite layer per room, drawn by the same GPU path as the far/mid layers; no per-frame CPU cost. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.25.

## Next

Pass 512: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The last open piece
of Sean's lighting/depth request is **rim light on figures** (a directional key edge on the player and
foes) — the piece that most lifts the hero's read, but it needs a cross-cutting `CanvasGroup` per figure
to compose a rim over every figure's swapping dye/wash/dissolve material, best landed when its combat
readability can be watched rather than in an unattended pass. The queued **midground-variant** pass (vary
`<zone>_mid.png` so the backdrop brick stops repeating) is the strongest non-lighting code-first item. The
hero sprite (the grade's top defect) needs PixelLab and would be a fourth base — held until a slot frees.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle to suit the fog, and the High Boughs an even fainter mist-rain — say the word and a
pass wires it in.
