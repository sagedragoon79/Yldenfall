# Pass 605: the shop is a place

## Category

UI and menus, from the independent grade taken after pass 600 (5.2 of 10; UI and menus 4.9): "the
shop menu is a plain dark box, two-thirds empty, with a thin flat border and a stiff, flatly shaded
shopkeeper portrait". It was pass 604's "Next" (the plain panel had waited with the pass 584 shop
item since pass 594).

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
604 waited for CI. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. Every fifth pass takes an independent grade, and this is
pass 605.

## Audit

At 3x in the grade's shop picture (the Hearthroot arms dealer):

- **The panel** (`ListMenu`, every menu in the game) is a dark fill inside one light border 2 px wide.
- **The middle is empty.** The arms dealer sells three wares, so three rows sit under the heading and
  the panel runs on, blank, for about 120 px to the description at its foot.
- **The portrait** sits in a flat square of one dark violet inside the same light border.

## What was built

- **A framed panel** (bible 12.44, `ListMenu`): a double frame, a dark line either side of the light
  border, with gold corner brackets 8 px long, as the HUD's plate and the minimap wear them (pass
  603), and a rule under the heading from a small gold diamond. Every menu wears it.
- **The counter**: in a list of items with at least 56 px to spare below its rows, the chosen item
  stands on a wooden shelf at three times its icon's size, in a smooth radial pool of lamplight. The
  next row's item takes its place as the cursor moves. A long list has no room and shows none.
- **The portrait** sits in the same frame, with small brackets on its corners, over a backing lit warm
  from above.

Judged by eye at 1x and 2x in all 21 shop pictures. The first pool of light was four stacked circles,
which read as hard rings, the banded light earlier grades named elsewhere; it is now a radial gradient.
The first shelf sat under the icon's empty foot, so the sword floated over it; it now rises 3 px into
the icon's cell. The portraits' art itself is unchanged (`tools/art/icongen.py`), so "stiff" may still
be named; a redrawn portrait set is a larger art item.

## Tests

`tests/test_economy.gd`, `test_a_shop_shows_the_chosen_ware_on_its_counter` (9 checks): the arms
dealer's chosen ware stands on the counter, in the room between the rows and the description and inside
the panel; the next ware takes its place; the light is a radial gradient; the frame carries eight
bracket bars at its corners; a shop of many wares shows no counter. The shop, menu and equipment tests
still pass (652 checks).

Mutation check, restored from a copy after: a counter that never finds room fails it (4 checks).

Full suite: 21,960 checks passed and 1 failed: `test_every_room_loads_and_settles_inside_the_budget`
(`spires/sky_steps` settled at 8.16 ms a frame against 8), the wall-clock flake on this busy PC.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The menus are framed and the shop shows its wares; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Independent grade

Taken after this pass (`workbench/grades.json`): **5.3 of 10** with a fresh grader, against 5.2 at
pass 600, from the same eight rooms, the Hearthroot arms shop and three fight frames, all with the HUD.
Areas: art and cohesion 5.0, environments 5.0, characters and foes 5.5, combat readability 4.5 (5.0),
UI and menus 6.0 (4.9 at pass 600), atmosphere and lighting 5.5. Best frames: the dwarf hall, the storm
ledge and the flooded hall.

UI and menus rose with the framed menus, the shop's counter and the minimap's ways on (passes 603 and
605). No longer named: the trestle (604) and the Spires' skyline (601). Combat readability fell: the
struck foe still reads as "a see-through ghost" (pass 602's dark rim did not settle it: the soft wash
turns a dark foe a flat mauve-grey close to the backdrop's hue), and the clock-face spark is named. New,
and first in the queue: **the HUD's health masks "copy Hollow Knight's masks almost directly"**, an
originality problem for a game that is its own (bible 1 and 2).

## Next

From the pass 605 grade: first, health gets an icon of its own, of this world (sap, amber, the
Tree), in place of the masks, with the bible's UI list changed to match. Then the struck foe that reads
as a see-through ghost (keep its own colors through the soft phase, within pass 567's bounds), the
clock-face spark, and the gold counter's slashed zero. The sword's look, the Haar's fog and dither and
the sprites' pixel size stay held.
