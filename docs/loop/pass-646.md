# Pass 646: a struck foe is lit on the blow's side

Date: 2026-11-23. From the queue, first item: the independent grade of pass 645 (5.2/10). Its
lowest areas were characters and foes and combat readability (4.5 each). Of its unheld items, this
pass takes "fight contact points are mush (small sparks, no hurt flash at this scale)".

## Audit

The fight frames (`workbench/catalog/fights/*-hit.png`) are a real swing caught after the
hit-stop, once the swing's smear is drawn. By then the flash (6.7) is past its one-frame white pop
and in its soft phase: a 0.3 warm-cream overlay over the whole foe. Cropped at 3x in `tower/foot`
and `boughs/canopy_bridge`, the bandaged brute's plates and the Bark Knight's armor had flattened
into one muddy tone close to the room behind them. The dark rim (pass 602) was there but thin
against the muddied body. The grader's "no hurt flash" is this: a soft tint that reads as a
low-contrast smear, not a blow.

## What changed

- **The struck edge** (`Enemy.STRUCK_EDGE`, `STRUCK_EDGE_WIDTH`, `struck_side`,
  `struck_edge_drawn`). Through a hit flash a sheet foe's silhouette is drawn in warm white, then
  its body set back from the blow by one world pixel, so a crescent of white shows inside its
  outline on the side the blow came from. The dark rim is drawn about both, so the crescent never
  merges with the swing's white arc.
- **The body keeps its colors.** `SHEET_SOFT_WHITE` drops from 0.3 to 0.15. The pop
  (`SHEET_WHITE` 0.85) is unchanged, as is the code-drawn foes' 0.3 wash.
- **The bible:** 6.7 (the flash) and 12.122.

Also found: after #725 merged, Godot's class cache did not know `HydraDrench`, and every capture
failed at once ("no hit within 600 frames", tells included). A `--import` fixed it; the test runner
already does one.

## Checked by eye

All eleven fight frames recaptured. At 3x the brute shows its bandage plates and a lit left edge
against the dark foundry; the Bark Knight's armor plates read and its edge facing the hero is lit.
The knight's grey-green still sits close to the Boughs' mist, a separate item already queued.

## Tests

`tests/test_hit_flash.gd`: `test_a_struck_foe_is_lit_on_the_side_the_blow_came_from` (no edge at
rest; a blow pushing right lights the left, through the soft phase; gone with the flash; a blow
pushing left lights the right; a warm white, far from the tell's gold; one to two pixels; never in
a tell). The tint bounds test now holds a sheet foe's soft tint between 0.1 and 0.2; the colors
test checks a dark violet foe keeps its hue under it, and still turns warm under the code-drawn
wash.

| Mutation | Result |
| --- | --- |
| the edge lit on the side the blow pushes toward | fails (3 checks) |
| the edge never drawn | fails (3 checks) |

## Full suite

FULL_SUITE_RESULT

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A struck foe keeps its colors and is lit on the blow's side. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged; guardians drawn in code keep the wash. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Five more silhouette draws per struck foe, only through a flash. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 645 grade, in its order: foes in three styles (the bandaged brute reads as mush, the
knight's grey-green blends in); the spark itself is small at this scale; dead voids (the grub
burrows' black top half, the Evercrown veins' flat purple); walls that end mid-air at the screen's
edge; barcode stripes in the dirt tiles; copied hazards and cloned town towers; floating islands
and chain platforms hung from nothing; the Spires' rain too heavy; an oversized minimap. Held as
before: the Haar's render, the sword's flat bar, the hero's size.
