# Pass 618: a tier has no specks

## Category

Art cohesion (environments). The top unheld item of the queue, seen in pass 614 and named
again with the pass 615 grade (5.6 of 10): "the darker interior tiers step by the tile, so
single dark tiles sit inside a lit field (the Flooded Hall's ceiling, the storm ledge's upper
left)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Two causes, and the louder one was not the tiers.

- **Vorrhallow's worn block is half a tile.** Its upper course is one block the width of the
  tile. A tier has four tiles, so one worn upper block made every fourth tile of a field a
  dark slab. Mean values (0 to 255): MID 53 to 68, DEEP 30 to 41, and the full-solid blob tile
  82 beside variants at 88 to 94. A whole tier step is about 20, so a worn tile read as a lone
  tile of the next tier down. The Spires' tiers were already even (within 4 percent).
- **Specks of a tier.** A cell's tier is its distance from open air, so a nub or a notch
  leaves one or two cells of a darker tier alone. The Flooded Hall had one, the storm ledge
  two and the aqueduct one.

## What was built

- **A field tile wears only its half blocks** (`tools/art/tilegen.py`:
  `drowned_block_is_worn`, `DEEP_SEEDS`, `FULL_SEED`). The full-solid blob tile, the row-7
  variants and the MID tiles wear only the half blocks of the lower course; the DEEP tier wears
  none. Four tiles of `assets/tiles/vorrhallow.png` change; every other generated picture is
  byte for byte the same. After: surface 88 to 94, MID 60 to 68, DEEP 40.5 to 41.6.
- **A tier needs three cells together** (`TilesetFactory.settle_tiers`, `TIER_GROUP`;
  `Room._depth`, `_raw_depth`, `_tiers`). A group of fewer than three cells of a tier, joined
  edge to edge, takes the tier above; the deepest settles first. Worked out once a room and
  again after `tear_floor`.
- Bible 12.95 (new).

Looked at in the Flooded Hall at 1x and 2x beside the picture from before: the black slabs in
the ceiling's depth are gone and the tiers read as bands. On the storm ledge the change is two
tiles and hard to see.

Not done: a tier's edge still follows the tile grid (softening it needs drawn transition
tiles; left for a watched look). The gym's MID tier keeps a 21 percent spread. The quarter
blocks of the lit field are still worn, as 12.45 means them to be.

## Tests

`tests/test_tier_specks.gd`, four new: `test_a_speck_takes_the_tier_above`,
`test_what_the_deep_tier_gives_up_joins_the_middle_one`,
`test_no_room_draws_a_speck_of_a_darker_tier`,
`test_vorrhallows_field_tiles_are_one_value_a_tier`.

Mutation check: with the pass 617 atlas put back, the last fails; with `settle_tiers` left out
of `Room._depth`, the rooms test fails. Restored, all pass.

`tools/art/test_tilegen.py` (run by hand, not in CI): 93 checks pass, the stale-atlas checks
among them.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Vorrhallow's tiers are bands; a tier's edge still steps by the tile. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 615 grade's remaining items: the Haar's lava column (a flat strip with no glow
falloff), the water's hard top line, the hit's missing flash in the fight captures, and the
Spires' ridge as more than one value. The next independent grade is due after pass 620. The
Haar's fog and dither, the sprites' pixel size, the hero's rim light and the sword's look stay
held.
