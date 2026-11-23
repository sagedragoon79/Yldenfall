# Pass 643: the far columns break

## Category

Art cohesion and environments. The top item of the queue, the rest of the pass 640 grade's
first item: "the same pine band and trunk columns behind five areas". Pass 642 gave the
Heartwood a ridge of its own; this pass takes the trunk columns.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

In `heartwood/entrance`, `tower/foot` and `vorrhallow/alpha_den`, the far layer was a row of
columns, each running the full height of the layer:

- **The Heartwood's fibres**: 14 bars of streaked bark, swaying a little, top to bottom.
- **The Tower's shafts**: 6 masonry shafts, top to bottom, with slit windows.
- **Vorrhallow's pillars**: 7 pillars, top to bottom, with a faint band near the top for an arch.

Measured as the longest run, in one column of pixels, of anything drawn over the layer's sky
(bridging gaps of up to 12 world px), each layer scored 1.00 of its height.

## What was built

Design bible 12.119, in `tools/art/tilegen.py`. No far column now runs more than
`FAR_RUN_MAX` (0.8) of its layer's height.

- **The Heartwood: a braid** (`heartwood_far`, `_fibre`). 22 fibres, half hanging from the
  hollow's roof and half rising from its floor, each 0.4 to 0.7 of the layer long, leaning its own
  way and curving, narrowing to a quarter of its width at its end, lit on its west edge. One in
  two forks, the strand leaning away. Longest run: 0.47.
- **The Tower: storeys** (`tower_far`). Three storeys of five shafts, each on a gallery floor (a
  lit lip, a dark slab, a railing), each storey half a bay over from the one under it, each shaft's
  head stepping out in corbels under the floor above. Longest run: 0.53.
- **Vorrhallow: an arcade** (`vorrhallow_far`). The pillars rise out of the water to capitals at
  one spring line, with round voussoir arches between them and the vault lost in the dark above.
  Two pillars are broken off lower (jagged tops, no capital), and the arches beside them have
  fallen, leaving a stub on the standing side. The stillglass is seated below each pillar's top.
  Longest run: 0.66 (the water counts).

Thrown out on the way:

- **Fibres tapering to a point**, 10 to 24 px wide, 16 of them. The far wall read nearly empty,
  a few blades of grass on the dark. They are now 16 to 36 px wide, 22 of them, and end at a
  quarter of their width.
- **Arches fallen to three quarters of the bay** beside a broken pillar. Too little stood to read
  as a springing; the stub is now 0.4 of the bay.

## Checked by eye

At 1x and 2x in the three rooms, before and after (after a Godot reimport). The Heartwood's far
wall is a braid of crossing fibres, the Tower's has a gallery and corbelled shaft heads across
the top of the view, and Vorrhallow's hall is an arcade. The mid layers' columns (the Tower's
girders, Vorrhallow's colonnade) still run the room's height; see Next.

## Tests

`test_no_far_column_runs_the_height_of_its_layer` in `tools/art/test_tilegen.py`: in each of the
three far layers no column runs more than `FAR_RUN_MAX` of the height, and columns still stand in
more than a quarter of the width at 0.55 of the height (so an empty sky does not pass).

| Mutation | Result |
| --- | --- |
| every fibre the layer's full length | fails (0.81) |
| the Tower in one storey | fails (1.00) |
| the storeys' shafts stacked over each other | fails (1.00) |
| Vorrhallow's pillars run to the top | fails (1.00) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 36,986 checks, all passed. `tools/art/test_tilegen.py` ran alone first: 110 checks, all passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The far columns of three zones no longer read as one band of bars: a braid, storeys, an arcade. The mid layers' columns, the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (baked pictures). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The mid layers' full-height columns (the Tower's girders, Vorrhallow's colonnade), and no
foreground layer framing the rooms. Then: foes in two styles (the knight's grey-green blends
in); set dressing pasted on (crystals, the tree through the shrine gate, identical islands);
spikes that read as grass or railings; light as additive circles; ground strip tiling. Held as
before: the Haar's fog and dither, the sword's slab and the hero's attack pose, the hero's size,
the shop portrait. The next independent grade is due after pass 645.
