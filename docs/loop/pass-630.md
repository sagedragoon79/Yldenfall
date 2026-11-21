# Pass 630: what you can still use catches the light

## Category

Art cohesion (props). The top item of the queue, the next unheld defect of the pass 625
grade: "chests, signs and pickups do not separate from the scenery" (flooded hall, aqueduct,
the fog rooms).

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the drowned aqueduct, the flooded hall and the Lampwick causeway at 1x. Each zone's
chest and stele are built in the zone's own stone and timber (12.31, 12.80), which is why they
belong and also why they vanish: the Sunken Spring's strongbox and runestone are the grey of
the piers behind them, under a dark outline, against a dark sky. The only accent was a 2 px
lock light and a single 10 percent disc 13 px wide. An opened chest looked the same as a
closed one from a distance.

## What was built

Design bible 12.106. `Standout` (`scripts/world/standout.gd`) gives a thing three marks in the
accent it already has:

| Mark | What it is | Who carries it |
| --- | --- | --- |
| Halo | Three flat discs in the accent (9, 10, 14 percent), breathing by a pixel | Closed chests (22 px), steles (20 px) |
| Rim | The top of the silhouette drawn in the accent, where the dark outline was | Closed chests, steles |
| Glint | A warm-white plus sign, 3 px to 5 px across, half a second, at three spots in turn | Closed chests |

An opened chest carries none of them, so what is left to do in a room reads from across it.

Thrown out or fixed on the way:

- The glint was first drawn on the chest's half-pixel grid and came out 2.5 px across, too
  small to see at 1x. It is in whole pixels now.
- The first halo (7, 8, 11 percent) did not show against the aqueduct's sky. It went up a step.
- The High Boughs hamper's lock was pale yellow on pale wicker, so its rim did not read. Its
  accent is the palette's warm white now. The test that caught it judges an accent by light or
  by saturation, because Vorrhallow's magenta is no lighter than its stone and still reads.

## Checked by eye

At 1x and 2x: the drowned aqueduct (the strongbox and the runestone on the east ledge now have
a cyan top edge and a soft pool of light on the dark sky), the flooded hall (the chest on the
mound sits in a magenta halo), leaf landing (the hamper and two steles against leaves) and the
root shrine (the stele's gold halo beside the shrine). On the Lampwick causeway the chest is
still under the fog; its rim shows faintly. The fog is a held item.

## Tests

`tests/test_standout.gd`, six new tests. Mutation-checked:

| Test | Mutation | Result |
| --- | --- | --- |
| `test_standout_the_halo_is_stepped_and_faint` | a one-step halo | fails |
| `test_standout_an_opened_chest_goes_dull` | an open chest still stands out | fails |
| `test_standout_one_glint_at_a_time` | the glint never shuts | fails |
| `test_standout_a_closed_chest_is_rimmed_in_its_accent` | the hamper's old yellow accent | fails |
| `test_standout_a_stele_is_rimmed_in_its_inlay` | the rim on the stone, not the outline | fails (92 checks) |

Full suite: 33,293 checks; 33,290 passed in the whole run (pass 629: 32,925). The three that
failed were wall-clock budgets in two tests (`test_every_room_loads_and_settles_inside_the_budget`
and `test_every_foes_spoils_rest_in_its_room`: the Proving Scar, the Old Flue, the Mossy Overhang
and the Sky Steps over their load or frame times), the flake the queue has carried since pass 570.
Both tests passed on the first rerun alone, and neither room's drawing was touched beyond a
chest's three discs.

## Not done

- Item pickups already carry a light and sparkle of their own and were left.
- Nothing lifts a chest out of the Haar's fog (held).
- A stele does not go dull once read; reading is not recorded.
- Coins and drops are as they were.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Chests and steles read; the fog, the dither and the plank's board stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 625 grade's items, in its order: the rain's splash and wet stone and the
lightning's light; the one-value midground bands. Then a second ceiling pitch and the plank's
board. An independent grade follows this pass. The Haar's fog and dither, the sprites' pixel
size, the hero's rim light and the sword's look stay held.
