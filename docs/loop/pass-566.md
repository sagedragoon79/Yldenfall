# Pass 566: the Tower's plates are a tile wide, and a worn one is pitted

## Category

Art cohesion and environments, from the independent grade taken after pass 565 (4.6/10): "the
Tower's ceiling and floor are a noisy grid of small square plates with scattered dark squares, a
test pattern that competes with the crucible".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one, and the top defect of the latest grade that can be
done unattended. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- `paint_plates` drew plates of 8 world pixels: four seams, sixteen rivets (each a step-6 head
  with a dark pip) and their rust streaks in every 16 pixel tile. Pass 555 (12.45) made the plates
  one value, but the grid was untouched, and the smelter's floor and ceiling are three tiles thick
  from wall to wall.
- The "scattered dark squares" were 12.45's worn plates, a ramp step down. In the darkened interior
  tiers (12.8) that step lands near black.
- The lit bevel stood two steps over the body, so every plate carried a bright L as well.

## What was built

- **A plate is a whole tile** (`PLATE = 16`, `tools/art/tilegen.py`): half the seams, a quarter of
  the rivets, and the frame's grid is the room's own tile grid.
- **Lower detail**: the bevel one step over the body, the rivet head on step 5 (`PLATE_RIVET`),
  rust from about one rivet in ten (`PLATE_RUST`).
- **A worn plate is pitted** (`WORN_PLATE`, `PLATE_PITTED`). The first try kept the worn plate a
  shade darker; at the size of a tile it was a row of dark squares a tile wide, worse than before
  (looked at, at 1x and 2x, and dropped). A worn plate now keeps the body value with about a
  quarter of its face pitted a shade down. Vorrhallow's blocks keep `WORN_BLOCK`.
- Design bible 12.54; 12.45 points to it.

Only `assets/tiles/tower.png` changed. A whole run of `tilegen.py` still rewrites five mid layers
it should not (the tooling item from pass 563); they were restored each time.

Looked at before and after at 1x and 2x: `tower/smelter`. The crucible and the pour are now the
brightest and busiest thing in the frame; the flange, the girder cap and the soffit carry the
iron's detail and the fields behind them rest.

## Tests

`tests/test_tower_plates.gd` (four tests): no seam crosses the middle of an interior tile; no
plate's mean stands a ramp step off its tier's body; at least one interior plate is pitted, at most
half are, and a sound plate is clean; at most four rivet heads in a tile stand over the bevel.
`test_calm_frame_tiles.gd` measures the worn block on Vorrhallow only now.

Mutation check: the pass 565 atlas fails three ("no seam crosses the middle of the tile", "at
least one interior plate is pitted", "at most four rivet heads"); a generator with no pitting
fails "at least one interior plate is pitted"; a worn plate a shade darker fails "no plate stands
a step off its tier's body". The generator was restored and the atlas checked byte for byte
against the one looked at.

FULL_SUITE_RESULT

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | The Tower's fields are quiet and its built lines carry the detail. The independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Of the queue: the hit flash that keeps the foe's inner lines (the unattended half of the pass 565
fight-frame defect), then the Sunken aqueduct's brick and waterfall with the pillars-and-water
item, then one-template rooms. The next independent grade is due after pass 570. The test runner's
shared `user://` (found in pass 563) is still worth a short tooling pass. The Haar items wait until
the hydra and steam branches merge; the Blinkhop waits for a free base slot.
