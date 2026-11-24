# Pass 650: wood grain ends

Date: 2026-11-23. No new notes from Sean. From the queue, first item: the independent grade of
pass 645 (5.2/10), next in its order after the walls that end mid-air: "barcode stripes in the dirt
tiles". The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no
PixelLab generations or Autosprite credits were spent. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

The "dirt" is the Heartwood's wood (`paint_wood`), which the Haar's limbs share (`paint_limb`).
Since pass 534 it was vertical strands 4 to 9 render pixels wide in two values with a dark seam
between them, and the layout was the same in every tile so a strand ran on into the tile below.
Over a wall, every strand ran from the top to the foot: stripes of light and dark on a fixed beat,
the barcode (`heartwood/grub_burrows`, `haar/marsh_road`). The Boughs had the same fault until
pass 615 (12.92).

## What changed

Design bible 12.126 (and the wood line of 12.28), `tools/art/tilegen.py`.

- **One body value and streaks that end.** The face is the ramp's `lo + 1` step. Grain streaks a
  step darker (`wood_lens_cells`) run 5 to 14 world pixels, one or two wide, taper to a point at
  each end and lean a pixel over their length. The odd streak of a tile's own has a lit west edge
  (one a tile at least).
- **Joined at the seams.** Seven shared streaks (`WOOD_GRAIN`) wrap over the tile's edges, two
  across the side seams, so the grain runs on across every seam and no column at a tile's edge is
  bare. Each tile adds three of its own from its seed (`wood_seed_lenses`), inside it, so the wall
  does not repeat on a 32-pixel beat.
- **The rind's notches** sit where a shared streak reaches the row under the trim
  (`wood_strand_starts`).
- **The blends between tiers** (12.99). With the strands gone the wood has no joints worth the
  name, and the Haar's blend of MID and DEEP left its east half nearly all one tier (the full
  suite's `test_no_half_of_a_blend_is_one_tier`). `tile_blocks` now reads a wood tile as jointless
  (one block cut into soft blobs), and every blob of a cut block is a block of its own; before, a
  cut block was two halves of noise, too few to balance. Every half of every wood blend now stands
  31% to 66% in the darker tier.
- Atlases regenerated: the Heartwood and the Haar for the grain; the Boughs, the Tower and
  Vorrhallow for their blends only (cut finer, checked by eye against the old ones).

## Checked by eye

A wall of 8 by 5 tiles of each zone at 3x, then `heartwood/grub_burrows` and `haar/marsh_road` in
the game at 1x and a 2x crop. The first try let streaks grow three cells wide with a dark heart:
blotches, and the shared one drew the same dark eye every 32 px. The second left the two columns at
each tile's edge with no grain, a bare seam every tile. Both fixed. The wood now reads as bark
grain; in the darker tiers the grain sinks with the shade.

## Tests

`tools/art/test_tilegen.py`, `test_wood_is_no_barcode`: over a wall of 4 by 4 fill tiles in each
zone, no column holds the grain's shade for two tiles, every column carries some grain and none is
all grain, and one body value holds 45% to 85% of the face. `test_wood_trim_is_notched_where_grain_meets_it`
keeps the rind's notches to a few a tile. `test_wood_strands_run_on_from_tile_to_tile` assumed
the wood was the same all the way down a column (bottom row of one tile against the top row of the
next); it now checks that tiles of any seed have the same pixels along all four edges, so the grain
runs on across every seam whatever lies next to a tile (a first draft let a tile's own streak lean
onto its edge, which this caught). `tests/test_bough_bark.gd` said the Heartwood keeps its
strands; it now says no grain streak runs a whole Heartwood tile.

Mutation check: the old strand painter (`origin/main`'s `tilegen.py`) fails
`test_wood_is_no_barcode` with "a grain streak runs 128 px down the wall".

## Full suite

Two runs (`TEST_TIMEOUT=7200`). The first: 37,130 checks passed, 4 failed. One was this pass's:
`test_no_half_of_a_blend_is_one_tier` in the Haar (fixed above). Three were frame-time budgets in
rooms the pass does not touch (`evercrown/proving_scar`, `gym/gym` and `trials/stillness` loading
in 533 to 611 ms against 500; `spires/sky_steps` at 8.4 ms against 8). The second, after the blend
fix: 37,131 passed, 3 failed, all frame-time budgets again (`test_spires_rain_stays_cheap` 9.35 ms,
`spires/sky_steps` 9.1 to 10.1 ms, `tower/smelter` 11.8 ms), none in a wood zone. Run alone, each of
the timing tests passed every check (`test_every_room_loads_and_settles_inside_the_budget`,
`test_every_foes_spoils_rest_in_its_room`, `test_spires_rain_stays_cheap`). The tiles are baked
atlases, so the change costs no frame time. `python tools/art/test_tilegen.py`: every check passed
after its blend test was given the same jointless reading of wood that `paint_blend` uses
(`zone_has_joints`).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The Heartwood's and the Haar's wood reads as bark grain, not stripes. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (tiles are baked). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (pass 650). Then, from the pass 645 grade in its order, unless the
new grade reorders it: copied hazards and cloned town towers; floating islands and chain platforms
hung from nothing; the Spires' rain too heavy; an oversized minimap; the spark's size at this scale.
Held as before: the Haar's render, the sword's flat bar, the hero's size; foes in three styles stays
with the art loop.
