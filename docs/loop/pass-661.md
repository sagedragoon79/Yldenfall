# Pass 661: a near mass is built of its matter

Date: 2026-11-25. No new notes from Sean. From the queue, first item: the independent grade of
pass 660 (5.4/10). Its third named defect, after two held ones (the fight's tells and the sword's
flat bar, both with the hero's size): "the foreground silhouettes as blobby stains at every frame's
foot". The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no
PixelLab generations or Autosprite credits were spent.

## Audit

Every zone's `<zone>_fore.png` laid out against a flat grey, and the foot of
`heartwood/grub_burrows`, `evercrown/veins` and `vorrhallow/flooded_hall` at 1x and 2x. The two
broad masses of 12.127 in each zone were smooth half-ellipse domes 44 to 64 px tall, one flat tone
with a faint rim, with a few blades, shards or blocks on the crown. The domes carried nearly all of
the area, so at the foot of a dark room each read as a dark hole, the same shape in every zone; only
the crown said fern or rubble, and it was small.

## What changed

Design bible 12.137 (new), with a line in 12.127 and 12.11; `tools/art/tilegen.py`, the ten
`assets/bg/<zone>_fore.png`.

- **A low bank.** `MOUND_BANK` 26 to 32 px: the dome is a bank under the fringe's top, with a broken
  lip under its rim and grit in the rim tone over its upper third (`MOUND_GRIT`).
- **The matter carries the height.** Fern banks are seven to ten arching fronds with leaflets off
  both sides; reed tussocks eleven to fifteen blades and two or three cattails; crystal clusters
  three or four great shards and small ones, each with a lit west face; block heaps two courses of
  chipped blocks with a seam of air between each; timber piles a post with one plank high on it and
  one slid down it. Pieces lean only as far as keeps them inside their span (`_fit_lean`).
- First takes: fronds leaning out past the span broke the fringe rule (only masses rise over it,
  and only inside their spans); a 22 px bank failed the mound's solid-run check; the timber pile's
  two matched boards read as a tent; with seams between blocks, one Trials heap lost its second
  course and fell under the fringe (the first block of a course is now always laid).

Judged by eye at 1x and 2x in `heartwood/grub_burrows` (a fern clump at the foot instead of a
mound), `evercrown/veins` (a crystal cluster) and `hearthroot/plaza`.

## Tests

- New `test_a_near_mass_is_built_of_its_matter` (`tools/art/test_tilegen.py`): the bank stays under
  the fringe; over the fringe no row of a mass is more than `MOUND_OPEN` (0.6) solid, a block heap
  `MOUND_OPEN_BLOCKS` (0.85); the pieces carry lit pixels in the zone's rim tone.
- `test_the_foot_of_the_view_holds_broad_masses`, `test_foreground_stays_a_low_fringe` and
  `test_near_layers_wear_their_zones_hue` pass unchanged on the new art.

Mutation checks: with the old 52 to 62 px domes, the new test fails (0.78 solid 36 px up); with no
rim tone on the masses, it fails (0 lit pixels).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,873 checks passed, 0 failed. The Python art suite: 118 checks passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The foot's masses read as ferns, reeds, crystals, blocks and timber, not domes. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 660 grade in its order, past the held items (the hero's size and walk pose through a
tell, the sword's flat bar, the Haar's dither halos and fog): large empty boxed rooms (the plaza's
ceiling, the burrows' black top band, the veins in one purple); flat water rectangles (the source
hall, the flooded hall); then the oversized bee (a smaller Hornet sheet).
