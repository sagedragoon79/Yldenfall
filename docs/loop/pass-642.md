# Pass 642: the Heartwood stands on roots of its own

## Category

Art cohesion and environments. The top item of the queue, from the pass 640 grade: "the same
pine band and trunk columns behind five areas, and no foreground layer framing the rooms".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

- **The pine band.** In the grade's spread, the same band of tiered firs stood behind the
  Heartwood's two rooms and the High Boughs' bridge: both zones had the ridge kind "fir"
  (12.12, 12.111). The High Boughs are a canopy wood, so firs belong there; the Heartwood is a
  hollow under one great tree, roofed with roots, and a pine forest on its horizon made no sense.
- **The trunk columns.** The Heartwood's far fibres, Vorrhallow's far pillars and the Tower's far
  shafts are all full-height vertical bars, and read as one band across three zones. Left for a
  later pass (see Next).

## What was built

Design bible 12.118, in `tools/art/tilegen.py`.

- **A ridge of great roots.** The Heartwood's ridge kind is "root": a row of roots, each arching
  out of the ground to its crown and back in, leaning (each side its own reach), with a knot or
  two on its back, thin at the crown and flared into buttresses at its feet. Neighbours cross at
  the feet.
- **Through the arch.** Under a crest root the plane thins to alpha 48, so the far layer shows
  through the arch.
- **A tangle in depth.** Each root's body is laid darker than the plane, lit on its west back;
  the far haze lies in its arch, and rootlets hang into it. Two inner rows of smaller roots stand
  lower in the plane, each darker. Dim cyan fungus glows at a foot or two.

Thrown out on the way:

- **Hollows darker than the plane.** The first try filled the space under each arch with the
  seam: every root became a dark dome with a lit rim, and the row read as huts with doors. The
  root is now the dark thing, and the arch is the far haze.
- **A half-thinned arch** (alpha 120). The arches read as glassy domes over the far layer.
  Thinned to 48 they read open.

## Checked by eye

At 1x and 2x in `heartwood/entrance` and `hollow_02`, before and after (after a Godot reimport:
the first shot showed the old firs from the import cache). The far band is a tangle of arching
roots under the hall's roof of roots, and the High Boughs keep their firs.

## Tests

`test_the_heartwood_stands_on_roots_of_its_own` in `tools/art/test_tilegen.py`;
`test_a_fir_on_the_crest_is_tiered` now asks only the High Boughs for firs.

| Mutation | Result |
| --- | --- |
| the Heartwood given the firs back | fails (a ridge of its own) |
| no flare at the feet | fails (the feet flare) |
| the arch filled (no thinning) | fails (the far layer shows through in 0 columns; the check reads half the plane's alpha, not the thinning's own constant, which this mutation would move with it) |
| every root the same reach each side | fails (the roots lean their own ways) |
| a root with no arch (its underside on the ground) | fails (1 check) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 36,986 checks, 36,984 passed. The two failures were frame
budgets in rooms this pass does not touch (`tower/kettleforge` at 8.26 ms against 8 ms, and
`evercrown/proving_scar` at 10.55 ms), while `tools/art/test_tilegen.py` (109 checks, all
passed) ran beside the suite for its first eight minutes. Rerun alone, both tests pass
(`test_every_room_loads_and_settles_inside_the_budget` and `test_every_foes_spoils_rest_in_its_room`,
3 checks each).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Heartwood's horizon is a tangle of great roots of its own, not the High Boughs' pines. The trunk columns, the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (a baked picture). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 640 grade's first item: the trunk columns (the far layers of the Heartwood,
Vorrhallow and the Tower are all full-height vertical bars) and no foreground layer framing the
rooms. Then: foes in two styles (the knight's grey-green blends in); set dressing pasted on
(crystals, the tree through the shrine gate, identical islands); spikes that read as grass or
railings; light as additive circles; ground strip tiling. Held as before: the Haar's fog and
dither, the sword's slab and the hero's attack pose, the hero's size, the shop portrait. The
next independent grade is due after pass 645.
