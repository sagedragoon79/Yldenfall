# Pass 656: the near layers move with the room and wear its zone

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 655 (5.0/10). Its first unheld defect, after the hero's size (held): "the foreground
silhouettes at the foot of every frame look stamped in the same spots, hide the floor line and
belong to no zone". The PixelLab art loop stays gated on Sean (three guardian bases wait for his
OK); no PixelLab generations or Autosprite credits were spent.

## Audit

Screenshots of `heartwood/grub_burrows`, `tower/foot`, `hearthroot/plaza` and `haar/marsh_road`
side by side: the two near masses of 12.127 stood at the same two screen places, about a fifth and
three fifths of the way across, in all four. `Backdrop.set_room` slides the far, ridge and mid
layers for each room (12.101) but left the foreground and the hanging frame alone, and a room's
first frame has its camera near its west wall, so every room opened on the same stretch of the near
art. Both near layers were also painted in `night-0` with a `night-1` edge in every zone, so after
the fog lean a fern bank, a block heap and a timber pile were the same grey-violet shape.

## What changed

Design bible 12.132 (new), with pointers in 12.11 and 12.101; `scripts/world/backdrop.gd`,
`tools/art/tilegen.py`, the 20 `assets/bg/<zone>_fore.png` and `<zone>_hang.png`.

- **Slid for the room.** `Backdrop._slide_near` sets the foreground's and the hanging frame's
  `scroll_offset` from `room_shift(room, NEAR_FORE)` and `room_shift(room, NEAR_HANG)`, on every
  `set_zone` and `set_room`. The reveal holes (12.26) read the sprite's global transform, so they
  follow the slide with no change.
- **In the zone's hue.** `FORE_TONES` gives each zone a body (step 0 of its ramp) and a lit edge
  (step 1): leaf, sky, crystal, stone or bark. `foreground` and `hanging` paint under
  `_zone_tones(zone)`, which swaps `FORE_BODY` and `FORE_RIM` for the zone's pair. The silhouette
  caps in two art tests move from a brightest channel under 70 to under 76 (step 1 is 72 at most).

`NEAR_FORE` is `"foot"`: with `"fore"` the MD5 slide put the grub burrows and the Tower foot 16 px
apart, the same spot again in two of the graded rooms; `"foot"` puts them 128 px apart. The spread
over every zone's rooms holds either way.

Judged by eye at 1x and 2x in the six rooms above plus `evercrown/veins` and `spires/sky_steps`:
the masses now stand at a different place in each, the Heartwood's fern bank reads green-black, the
plaza's timber pile warm, the Tower's heap stone. All stay darker than the ground before them.

Not done: a mass still crosses the floor's top line where it stands.

## Tests

- New `test_backdrop_shift_the_foot_masses_stand_somewhere_else_in_each_room`
  (`tests/test_backdrop_room_shift.gd`): in every zone of six rooms or more, the foreground and the
  frame start at no fewer places than half the rooms; the grub burrows and the Tower foot start
  48 px or more apart.
- `test_backdrop_shift_the_world_slides_the_backdrop_for_the_room_it_enters` now expects both near
  layers slid for the room, and slid again in the next room (it asserted the foreground was not).
- New `test_near_layers_wear_their_zones_hue` (`tools/art/test_tilegen.py`): each zone's
  foreground and frame lean its family's way on average and carry a lit edge over the body.

Mutation checks: with `_slide_near` not called, the world test fails 3 checks; with every zone
painted in `night-0` and `night-1`, the hue test fails (the Heartwood's mean is 18, 15, 26).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 37,707 checks passed, 1 failed:
`test_every_room_loads_and_settles_inside_the_budget`, two rooms loading over the 500 ms budget
(the Evercrown's proving scar 548 ms, the gym 505 ms). Run alone it failed again on the proving scar
alone (513 ms). With main's `backdrop.gd` and near art put back, the same test failed the same way,
as passes 654 and 655 found on this PC; the gym has no near layers, and the slide is one assignment
per room. Every backdrop and art test passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The near layers move with the room and wear their zone's hue. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (the slide is set once a room). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 655 grade in its order: fights hard to read (the burst over a small foe, a foe half
under the flooded hall's cyan water band, the hero over the gate tree's trunk); then the canopy's
dithered tile edges and the oversized bee; the large empty chained-platform rooms in one hue (the
Tower foot, the Evercrown veins); the dead black band over the grub burrows. Held as before: the
hero's size, the sword's flat bar, the Haar's dither halos and fog; foes in mixed styles stays with
the art loop.
