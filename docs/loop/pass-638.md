# Pass 638: a chest is set down, not stood on a plinth

## Category

Art cohesion and environments. The top item of the queue, the other half of the pass 635
grade's prop defect: "lone chests sit on featureless plinths" (the plaza's chest on its trestle,
the flooded hall's on its heap).

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

- **The chest is already the zone's own** (12.80): eight kinds, each with its halo, rim and
  glint (12.106) and a contact shadow (12.110).
- **What reads as a plinth is the emptiness round it.** In the plaza a 21 px strongbox stands
  alone in the middle of an 80 px board; in the flooded hall it stands alone on the heap's top.
  Nothing says anyone set it there.

## What was built

Design bible 12.114, in `scripts/pickups/chest.gd` and `scripts/world/room.gd`.

| Zone (chest) | Beside it |
| --- | --- |
| Gym, Trials (trunk) | coins, a tied sack |
| High Boughs (hamper) | coins, a leaf-tied bundle |
| Heartwood (coffer) | coins, red toadstools on moss; a moss mound with a pale toadstool |
| Haar (sea chest) | coins, a coil of rope; a corked green bottle |
| Hearthroot, Sunken Spring, Vorrhallow (strongbox) | coins, a hooped keg; a lit lantern in the chest's glow |
| Tower (crate) | coins, a heap of gold-flecked ore; a small crate |
| Spires (reliquary) | coins, two lit votive candles on a dish |
| Evercrown (geode) | coins, crystal grown out of the floor |

- Drawn in whole world pixels with a one-pixel outline in the chest's outline tone, so a prop
  is as heavy as the chest.
- The room measures open floor beside each chest (`Room.floor_run`, up to three cells a side, a
  slope, wall or gap ends it). The larger prop takes the side with more floor, the coins lie
  between it and the chest, and a prop that does not fit is left out.

Thrown out on the way:

- **Props in half-pixels.** At the chest's half-pixel grain the keg was 7 px tall and the props
  read as specks on the plaza's board. Doubled.
- **A rope coil side on, its turns stacked.** It read as a woven basket, then as a loaf. Drawn as a
  ring seen a little from above, with a dark hole.

## Checked by eye

At 1x and 4x: the plaza (lantern, strongbox, coins, keg on the trestle), the flooded hall (the
coins on the heap's two-cell top), the drowned stair (bottle, coins, coil, under the fog),
Amberlee (toadstools both sides), the broken shrine (a one-cell niche: no setting), and a sheet
of all eleven zones at 3x on a broad and a narrow floor.

## Tests

`test_chest_is_set_down_with_things_beside_it` (`tests/test_chest.gd`): every zone's setting is
in the palette, stands on the ground line, lies beside the chest and never past its floor, has
things on both sides of a broad floor, is big enough to read, none on a one-cell floor, east
only when the floor runs east only, and the zones' settings are not one stamp.
`test_chest_the_room_measures_its_floor`: a wall, a plank, a gap and the three-cell limit.

| Mutation | Result |
| --- | --- |
| `setting` returns nothing | fails (45 checks) |
| the setting ignores the floor's reach | fails (337 checks) |
| a gap does not end the floor | fails (2 checks) |
| the room never measures the floor | fails (2 checks) |

Full suite: 35,716 checks, every one passed (pass 637: 33,801).

## Not done

- A strongbox's lantern lights nothing round it.
- The flooded hall's floating shards and its water, the aqueduct's flat water and its
  waterfall, light that rarely shapes surfaces.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | A chest is set down with the zone's things; the town's skyline, the fog and the Haar's dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A few dozen more rects per chest, built once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The flooded hall's floating shards and its water, then the aqueduct's water and waterfall. An
independent grade is due after pass 640. The Haar's fog and dither, the sprites' pixel size,
the hero's rim light and the sword's look stay held.
