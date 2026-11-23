# Pass 641: the piers sink into the deep water, and what is under it wavers

## Category

Art cohesion and environments. The top item of the queue, from the pass 640 grade: "the deep
water still a flat teal slab (strengthen the mirror and let the submerged pillars waver under
the surface)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

- **The stone in the water.** `SwimWater`'s body is drawn behind the room's tiles, so stone
  standing in the water was drawn at full light over it. Only the 20% front tint and a dark band
  at each face (12.97) touched it. The aqueduct's piers and floor stubs stood on the water as
  cut-outs, and the pool's bed read as dry ground under it.
- **Nothing wavered.** Under the surface every edge was as straight as over it.
- **The mirror** (12.116) reached one row, at 0.45. The grade found it too faint.

## What was built

Design bible 12.117, in `scripts/world/swim_water.gd`.

- **Drowned stone.** Stone that fills a gap in a row of water, and the first course of a wall
  beside the water, takes the body's tone by depth: 0.22 under the surface to 0.62 at full depth,
  in 4 px bands. The bed's course takes it too and fades out down its tile, so it meets the dry
  stone under it without a seam.
- **The waver.** A screen-reading rect over every row of water and drowned stone slides each
  pixel row by up to one pixel on a slow wave. The piers, the bed, the backdrop's columns and
  swimmers waver; neighbouring rows differ by a pixel at most, and the top 3 px hold still.
- **The mirror** is 0.6 and reaches two rows wherever the water goes on under its run (one over a
  shallow pool), laid over the waver.

Thrown out on the way:

- **The drowned tone only on gap stone.** The first try left the bed and the walls at full light:
  a bright band along the pool's floor under dark stubs. The shore's first course was added.
- **The bed's course at a flat tone.** It met the next course down in a hard line. It now fades
  out down its tile.
- **The stone's face bands drawn in front.** They would not have wavered with the stone they lie
  on, so they are now drawn behind the front, before the waver reads the screen.

## Checked by eye

At 1x and 3x in `sunken/drowned_aqueduct`, `source_hall`, `wellspring` and `spring_gate`, before
and after. The piers fade into the water by depth instead of standing on it, and the bed sinks
under the pool.

## Tests

In `tests/test_water_edge.gd`: `test_stone_in_the_water_takes_its_tone`,
`test_everything_under_the_surface_wavers` and `test_a_shallow_pool_mirrors_one_row`;
`test_the_deep_water_mirrors_what_stands_over_it` now checks the mirror's two rows.

| Mutation | Result |
| --- | --- |
| no drowned stone | fails (7 checks) |
| the bed's course does not fade | fails (1 check) |
| no shore course (walls left dry) | fails (1 check) |
| a waver of 2 px | fails (a pixel either way, no more) |
| the rows under the surface do not hold still | fails (1 check) |
| a one-row mirror | fails (4 checks; it first passed, since the check compared the mirror with its own constant: it is absolute now) |
| a mirror always two rows deep | fails over the shallow pool (2 checks) |
| the waver skips the drowned stone | fails (2 checks) |
| the wavers laid after the mirrors | fails (4 checks) |
| the waver's clock stopped | fails (1 check) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 36,986 checks, 36,942 passed (pass 640: 36,853). All 44
failures were in five tests that read the design bible (`test_every_guardians_numbers_are_written_in_bible_8`,
`test_every_zone_sounds_as_the_bible_says`, `test_every_zone_holds_the_secrets_the_bible_counts`,
`test_every_shelf_asks_the_shop_tables_price`, `test_the_gold_sheet_counts_the_rooms`): the script
that added 12.117 wrote the bible back with Windows line ends, so each table cell kept a stray
carriage return ("the bible says 120 |"). With the line ends put back, all five pass (342 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The piers and the bed sink into the deep water and waver under it; the mirror is stronger. The town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One screen read per row of water in the Sunken Spring. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 640 grade's next items: the same pine band and trunk columns behind five areas, and no
foreground layer framing the rooms; foes in two styles (the knight's grey-green blends in); set
dressing pasted on (crystals, the tree through the shrine gate, identical islands); spikes that
read as grass or railings; light as additive circles; ground strip tiling. Held as before: the
Haar's fog and dither, the sword's slab and the hero's attack pose, the hero's size, the shop
portrait.
