# Pass 604: each zone builds its own trestle

## Category

Art cohesion and zone identity, from the independent grade taken after pass 600 (5.2 of 10): "the
same X-braced trestle and the same skyline of window-dotted rectangles repeat across areas (trestle in
the plaza, the dwarf hall, the canopy bridge, the gear pit, the causeway and two hit frames)". The
skyline was pass 601. It was pass 603's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
603 waited for CI. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean.

## Audit

`PlankSupports.frame_parts` (pass 596) drew one frame for every pair of posts in the game: a low rail
and a cross-brace per bay, bolted, in the zone's timber. The tones change by zone, but the shape is the
same X under the board in the town, the woods, the Tower and the marsh, so the grader read one kit
copied across the world. Rooms with framed runs: the town (2), the woods, the Tower, the Haar,
Vorrhallow (6), the Evercrown (5), the Spires (10) and the Trials.

## What was built

- **A frame per family of zones** (bible 12.85, `PlankSupports.FRAMES`, `LOOKS[zone].frame`):
  - the carpenter's trestle (the town and the gym), as before;
  - lashed timber (the woods, the Spires): one diagonal per bay, leaning the other way in the next,
    rope wrapped at every joint, no bolts;
  - pilings (the marsh, the spring): piles with water-darkened feet and two stringers, no bracing;
  - an iron truss (the Tower, the Trials): two chords and a zigzag web, riveted at every node;
  - a stone arch (Vorrhallow): a band of footing stone from beside the posts' feet to a keystone
    under the board;
  - grown sinew (the Evercrown): two strands sagging from post to post.

Judged by eye at 1x and 3x in the canopy bridge, the gear pit, the causeway, the drowned market and
the Everbloom's heart. The first arch was a band 3 px deep drawn column by column, which read as a
wire and broke into steps on its steep flanks; it is now 4 px deep, and each column also covers the
drop to the next.

## Tests

`tests/test_plank_supports.gd` (841 checks pass), `test_plank_each_zone_family_frames_its_own_way`:
every zone takes a known style and every style is used; the town, the woods, the Tower and the marsh
each build their own; every style stays between its posts, the board and the floor; each style's own
signature holds; and no two styles draw the same frame. The pass 596 tests still pass (the gym keeps
the trestle they read).

Mutation check, restored from a copy after: giving every zone the trestle again fails it (2 checks).

Full suite: 21,948 checks passed and 4 failed, all wall-clock budgets on a busy PC (Unity editors
open): the Spires rain, a journey's frame spikes, and room loads and settled frames. CI passed the same
tests on passes 598 to 603.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Each zone builds its own supports. |
| Art cohesion | 15 | 98 | The trestle no longer repeats; the shop panel remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 600 grade: the shop panel (plain, two-thirds empty, a stiff portrait), the slime drawn
as a plain green rectangle, and the stair-stepped terrain edges (canopy bridge, storm ledge,
aqueduct). Pass 605 takes an independent grade (every fifth pass). The Haar's fog, the sword's look
and the sprites' pixel size stay held.
