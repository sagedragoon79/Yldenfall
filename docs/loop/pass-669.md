# Pass 669: a near mass is solid, low and lit along its top

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 665 (5.5/10), past the fights (passes 667 and 668): "the black foreground blobs at the foot of
the frame". The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no
PixelLab generations or Autosprite credits were spent.

## Audit

Six rooms shot at the default spawn (`tower/foot`, `spires/sky_steps`, `hearthroot/plaza`,
`haar/marsh_road`, `heartwood/grub_burrows`, `evercrown/veins`), the foot of each frame cropped at 2x
and 3x:

- **See-through.** A near mass was alpha 236 (rim 216), leaned 35% toward the fog by the shader: the
  lit floor showed through, so each mass read as a dark stain on the ground, not a thing in front of it.
- **The bank was the mass.** The low bank of 12.137 rose 26 to 32 px in one tone; at 1x it was most of
  what you saw (the blue domes in the marsh road, the brown domes in the Spires and the plaza).
- **Pieces merged.** Only a few edges were lit, so fronds, blades and timbers sank into the bank.
- **Tombstones.** A fallen block had both upper corners chipped, so the Tower's heaps read as a row of
  gravestones.

## What changed

Design bible 12.146 (new; 12.127 and 12.137 point to it); `tools/art/tilegen.py`, the ten
`assets/bg/<zone>_fore.png`.

- A near mass is opaque (`MOUND_A`, `MOUND_RIM_A` 255); the low fringe stays see-through, and the
  mass still thins in front of an actor (12.26).
- The bank is a low foot (`MOUND_BANK` 12 to 18 px).
- Every piece is lit along its top (`_mound_contour`): a mass pixel with air above it takes the rim
  tone, one world pixel deep.
- A fallen block has one corner broken on a straight cut, a lit top face 3 px deep and a steeper
  tilt; the upper course stands 16 to 22 px over the lower (so a heap still rises past the fringe).

Judged by eye at 1x and 3x, before and after, in all six rooms: the Tower's heaps are tumbled slabs,
the Spires and the plaza a broken post and boards, the marsh road a reed clump, the burrows' ferns and
the veins' shards crisper. The edge stays the zone's step-1 tone, so the masses stay darker than the
floor they stand in front of.

## Tests

- New `test_a_near_mass_is_solid_low_banked_and_lit_along_its_top` (`tools/art/test_tilegen.py`): a
  mass is opaque with nothing see-through over the fringe, its bank is a low foot and it is already
  open a few pixels above it, and no column of a mass ends in an unlit top.
- `test_the_foot_of_the_view_holds_broad_masses` measures a mass's broad foot at half its bank's
  height (half the fringe's before; the bank is now lower than that).

Mutation check: with the contour off, with the masses at 236 and 216, and with the old bank (both by
the constant and by the geometry alone, 0.69 solid 22 px up), the new test fails. All 119 tilegen
checks and the 178 backdrop checks pass.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,339 checks passed, 0 failed, the timing budgets included.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The foot of the frame reads as matter near the lens, not stains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade (every fifth pass: pass 670). After it, from the pass 665 grade in its order,
past the held items: the chain and rope platforms hung from nothing, and the veins' one value band.
