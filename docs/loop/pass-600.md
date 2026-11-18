# Pass 600: the pictures show the game as played

## Category

Tooling for the grade, from the independent grade taken after pass 595: "no HUD in the captured room
shots or fight frames (check the capture options before changing the game)". It is the last open
part of that grade's queue item that is not held for a watched session. Two tooling items from the
queue go with it (46 and 50): a whole run of `tools/art/tilegen.py` rewrote five mid layers that no
painter had touched.

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task. The PixelLab art loop
stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his
OK, the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. Every
fifth pass takes an independent grade, and this is pass 600.

## Audit

- **The HUD.** `workbench/capture/shot.gd` saves the world's own render target unless it is given
  `--ui`, and only the shop pictures passed it. The game draws its HUD in the main viewport, not the
  world, so every room picture and every fight frame came out with no hearts, magic, flasks, gold or
  minimap. The game was right; the capture options were not.
- **The mid layers.** A whole run of `tilegen.py` rewrote `boughs_mid`, `haar_mid`, `hearthroot_mid`,
  `heartwood_mid` and `trials_mid`. In pass 598 each was checked against main pixel by pixel: the
  pixels are the same, only the encoded bytes differ (Pillow on this PC), so every run left five
  unchanged pictures to put back by hand.

## What was built

- **Fight frames keep the HUD** (bible 12.0, `capture_all.py`): the hit and tell frames save the
  whole window, at 1280x720. The guardians' wind-ups stay cropped close-ups (the crop works on the
  world's render only). The catalogue's room pictures stay clean, so a room can be browsed whole; a
  grade set takes its room frames through the game window (`tools/screenshot.sh`) instead.
- **A run leaves an unchanged picture alone** (`tilegen.save_png`): every tileset and backdrop is
  written only when its pixels change. A whole run now leaves the working tree as it was.

Judged by eye: the eleven fight frames were recaptured and each shows the HUD; the Tower's hit frame
shows the hearts, the magic bar, the flasks and gold, and the minimap, over the pass 598 ridge and
the pass 599 cut.

## Tests

`tools/art/test_tilegen.py` (83 checks pass), `test_a_run_leaves_an_unchanged_picture_alone`: a new
picture is written, the same pixels encoded another way are not written again and the committed
bytes stay, and a changed picture is written. Mutation check: saving unconditionally fails it (the
same pixels are written again). A whole run of `tilegen.py` changed no file.

Full suite: 21,891 checks passed and 3 failed, all wall-clock budgets: `test_every_room_loads_and_settles_inside_the_budget`
(room loads and settled frame times) and `test_every_foes_spoils_rest_in_its_room` (one room's frame
budget). Two Unity editors opened on this PC during the run and drew about 40 percent of the CPU; run
alone, the spoils test passed and the room test failed on other rooms. This pass changes no game code
(queue item 48 is the timing test's flake).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the shop's portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Independent grade

Taken after this pass (`workbench/grades.json`): **5.2 of 10** with a fresh grader, against 5.3 at
pass 595, from the same eight rooms, the Hearthroot arms shop and three fight frames, the first set with
the HUD in every frame. Areas: art and cohesion 4.8, environments 5.4, characters and foes 5.5, combat
readability 5.0, UI and menus 4.9 (6.0 at pass 595: with the HUD in view the grader named the empty
minimap and the plain HUD box), atmosphere and lighting 5.6. Best frames: the gear pit, the dwarf hall
and the storm ledge.

No longer named: the flat parallax (pass 598), the floating blocks and crystals (597), the bare
platforms (596) and the slash covering the foe (599). Newly named: the window-dotted skyline repeats in
Hearthroot and the Spires, because pass 598 gave both zones one roofline ridge; and at impact the struck
foe goes semi-transparent and merges with the white sword and arc. The grade's other defects (the
sprites' finer pixel size than the terrain, the Haar's dither halos and fog, the sword's look, the
shop panel) are held or parked as before; its full list is at the top of the queue.

## Next

From the pass 600 grade: first, give the Spires a ridge of their own (ruined spires), so the
window-dotted skyline is Hearthroot's alone. Then the struck foe that goes semi-transparent at impact
(find why the soft wash reads as see-through, and keep the body opaque), the minimap's single
rectangle and plain HUD box, and the X-braced trestle repeated across zones. The Haar's fog, the
sword's look and the sprites' pixel size stay held.
