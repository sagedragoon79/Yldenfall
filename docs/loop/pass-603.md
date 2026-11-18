# Pass 603: the minimap shows the ways on

## Category

UI and menus, from the independent grade taken after pass 600 (5.2 of 10; UI and menus 4.9, down from
6.0 once the HUD was in the frames): "the minimap is an empty dark panel holding one flat coloured
rectangle, and the HUD sits on a plain translucent box, both of which look like placeholders". It was
pass 602's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
602 waited for CI. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean.

## Audit

At 3x in the grade's frames:

- **The minimap** draws only the rooms you have walked or charted, so a fresh game's room is one
  teal rectangle in a dark panel with a grey edge. The full map draws a grid and each room's door
  openings; the minimap drew neither, so nothing said where the room leads.
- **The HUD's plate** is a half-clear dark box with a faint gold line along its top and nothing else.

## What was built

- **The ways on** (bible 12's UI list, `Minimap`): a stub of path 4 px long out of each door of your
  room that leads to a room the map does not show yet. A stub goes once you walk the room beyond it.
- **The map's grid** under the window, one faint cell per screen of a room, laid from the map's own
  origin so it scrolls with the map, and **door openings** in each walked room's outline, as the full
  map draws them.
- **A frame shared with the HUD**: gold corner brackets on the minimap and on the HUD's plate
  (`Minimap.bracket_rects`), and a faint edge all round the plate.

Judged by eye at 3x in the dwarf hall: the minimap shows its grid, the room's door opening and the two
ways on out of it, under gold brackets that match the plate's.

## Tests

`tests/test_systems.gd`, `test_the_minimap_shows_the_ways_on` (19 checks): every side door out of a
fresh room is a way on, each starting on the room's edge at its door; a door into a room you walked is
no longer one; the grid is faint and laid from the map's origin; the frame's four corners each hold a
bracket of two bars, all inside the frame. The pass 373 minimap test still passes.

Mutation check, restored from a copy after: no ways on fails it (2 checks); brackets of one bar each
fail it (5 checks).

Full suite: 21,917 checks passed and 2 failed, both frame-time budgets a little over on a busy PC:
`test_every_room_loads_and_settles_inside_the_budget` (`tower/smelter` 8.11 ms against 8) and
`test_every_foes_spoils_rest_in_its_room` (8.53 and 8.86 ms). `test_hud_soak_draws_every_frame_and_stays_lean`,
which holds the HUD's own drawing to its budget, passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The minimap and the plate are framed; the shop panel and the trestle's repeats remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | The minimap shows the ways on. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 600 grade: the X-braced trestle repeated across zones (pass 596): vary it by zone. Then
the shop panel (plain, two-thirds empty, a stiff portrait) and the slime drawn as a plain green
rectangle. The Haar's fog, the sword's look and the sprites' pixel size stay held.
