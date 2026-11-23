# Pass 645: a frame hangs into the top of the view

Date: 2026-11-23. From the queue, first item: the independent grade of pass 640 (5.2/10) named
"no foreground layer framing the rooms". Passes 641 to 644 took the deep water, the Heartwood's
pine band and the far and mid columns; this is the last of that grade's environment items before
its foes and set dressing.

## Audit

The only near layer was the low fringe (design bible 12.11): ferns, reeds, crystals, rubble or a
broken fence rising at most 36 px from the view's bottom edge (12.29), see-through and leaned
55% toward the zone's fog. Nothing framed the top of the view. In the dark zones the fringe fades
into the ground tiles, so most screens had no near layer that read at all.

## What changed

- **A hanging frame** (`hanging`, `HANG_KIND` in `tools/art/tilegen.py`; `<zone>_hang.png` for the
  ten zones with a fringe). The zone's material hangs from the view's top edge in clusters with air
  between them: root tangles (Heartwood), leaf clumps with vines (the High Boughs), moss beards (the
  Haar, the Sunken Spring), crystal stalactites under a rock lip (the Evercrown, Vorrhallow), a broken
  lintel with chains (the Tower, the Trials) and a rafter's end with ropes (Hearthroot, the Spires).
  Each clump's underside is ragged, not a clean scallop.
- **The layer** (`Backdrop.hang_layer`). Locked to the view's top edge (`HANG_SCROLL` = (1.3, 0)),
  sliding a little slower than the fringe so the two near layers shear; drawn at `FORE_Z`; leaned
  toward the fog by `HANG_TINT` (0.2) so it stays darker than the room behind it.
- **No band.** Nothing drops below `HANG_MAX_DROP` (60 world px), at most half the top row is
  covered, and somewhere a run of 80 px is clear (Sean's note on the dark band, 12.25).
- **It gives way.** Both near layers now also thin in front of hazards, enemy shots, chests and
  pickups (`REVEAL_GROUPS`; `ItemPickup` joins a new `pickup` group), since the frame covers the top
  of the view where ceiling spikes and pickups sit.
- **The bible:** 12.121.

Thrown out on the way:

- **The fringe's tint and alphas** (0.55 toward the fog, 176). In the Haar the blue-grey fog is
  lighter than the room, and the frame turned into pale ghosts. It now has its own tint and is more
  solid (224 for a clump, 200 for a strand).
- **Clean half-ellipse clumps.** They read as cartoon clouds. The underside now wanders.
- **Leaf pairs as short strokes.** They read as fishbones. The leaves are now drooping ovals,
  alternating down the vine.
- **The Boughs' clumps at the other zones' spacing.** They covered 52% of the top row; their gaps
  are wider now (40%).

## Checked by eye

At 1x and 2x in `haar/marsh_road`, `boughs/canopy_bridge`, `heartwood/grub_burrows`,
`evercrown/veins`, `tower/foot`, `spires/sky_steps` and `hearthroot/plaza`, before and after (after
a Godot reimport). The Boughs' leaf clumps and the Haar's moss read clearly as a near frame; the
Evercrown's stalactites and the Heartwood's roots read at 2x; in the darkest rooms (the Tower, the
Spires in rain, Hearthroot's rafters over dark stone) the frame is a quiet dark edge. No actor, sign
or pickup in these shots sits under a clump.

## Tests

`tools/art/test_tilegen.py`: `test_the_hanging_frame_frames_the_top_without_a_band` (every fringe
zone has a frame; it touches the top edge; drops more than 20 px and no more than `HANG_MAX_DROP`;
covers 10% to `HANG_MAX_COVER` of the top row; has an 80 px clear run; is a dark silhouette).

`tests/test_backdrop.gd`: `test_the_hanging_frame_hangs_into_the_top_of_the_view` (the shipped art),
`test_the_hanging_frame_is_locked_to_the_top_and_near`,
`test_the_hanging_frame_thins_over_a_hazard_in_view`, and top-edge checks added to
`test_fore_ground_band_stays_off_screen_at_any_camera_height` (which now picks the fringe by name,
since the frame shares its z).

| Mutation | Result |
| --- | --- |
| roots twice as long (limit raised to match) | fails (drops 103.5 px) |
| a 6 px band across the top | fails (covers 1.00 of the top row) |
| the frame starts 10 px below the top | fails (does not hang from the top edge) |
| painted in a lit moss colour | fails (brightest channel 184) |
| `HANG_SCROLL.y` = 1 (pinned to the world) | fails |
| `hazard` left out of `REVEAL_GROUPS` | fails (3 checks) |
| the frame tinted like the fringe | fails |
| the frame slides with the fringe | fails |
| the frame never added to the backdrop | fails (2 checks) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 37,045 checks; 37,024 passed and 21 failed, all in two tests in `tests/test_rooms.gd` that counted a zone's backdrop layers as four (three back layers and the fringe): `test_every_zone_is_dressed` and `test_decor_and_backgrounds_are_drawn_at_double_density`. Both now count five, and the first also checks each zone has exactly one hanging frame beside its one fringe. Run alone afterwards: 98 checks, all passed. `tools/art/test_tilegen.py` alone: 112 checks, all passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the near layers now thin over hazards, shots and pickups too. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | A near frame hangs into the top of every zone's view, in the zone's material. It is quiet in the darkest rooms. The town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One more baked layer per zone, sharing the fringe's shader and actor list. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due after this pass. Then, from the pass 640 grade: foes in two styles (the
knight's grey-green blends in); set dressing pasted on (crystals, the tree through the shrine gate,
identical islands); spikes that read as grass or railings; light as additive circles; ground strip
tiling. Held as before: the Haar's fog and dither, the sword's slab and the hero's attack pose, the
hero's size, the shop portrait.
