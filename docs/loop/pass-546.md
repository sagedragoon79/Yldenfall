# Pass 546: the HUD's plate is a soft shade

## Category

A defect from the pass 540 independent grade, carried in pass 545's "Next": "stray black bars in the shop
shot". UI and menus in the grade; Art cohesion in the rubric.

No note from Sean was new. The PixelLab art loop stays **gated** on him (three guardian bases wait), and
its own thread now keeps its records as `docs/loop/art-pass-NN.md`, so the main loop's numbers stay
this one's. This is the first pass after Sean lifted the pause (2026-11-13). It ran in the claude.ai
project, from the repository's new name, sagedragoon79/Yldenfall.

## Audit

The shops were captured again (`workbench/capture/capture_all.py --only=shops`, 21 shots). The shop
panel itself is clean: its inner boxes (the chosen row, the description) sit inside the gold frame. The
stray bar is the HUD's backing plate (`GameHud._draw_plate`): a hard-edged rectangle of dark at half
alpha behind the masks, the MP bar and the purse, with a gold rule along its top edge. It ends in a
square corner over the room, so over a busy wall it reads as a black bar laid across the scene, and
the gold rule draws a line where nothing is. The trial and boss-rush clocks use the same plate.

## What was built

- The plate is six nested layers (`GameHud.plate_layers`, `PLATE_FEATHER`), each one unit (two screen
  pixels) inside the last and each a little darker, so it fades in from nothing at its edge, over
  12 px, to the full plate (`PLATE`, alpha 0.5) behind the HUD itself. The gold rule is gone.
- The shade behind the masks and the purse is as dark as before, so the HUD still reads over a bright
  room. Checked by eye in the Hearthroot arms shop and the Bell-Tower Scriptorium shots.

`test_the_huds_plate_is_a_soft_shade` (test_economy) holds it: several layers, an outer layer barely
there, the fade outside the HUD's own rect, each layer inside the last, and the full shade behind the
HUD. Bible 13.5 (UI) gains "The HUD's plate is a soft shade (pass 546)".

Mutation check: with the plate back to one layer (`PLATE_FEATHER` 1, the old hard rectangle), the test
fails (3 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground and one-template rooms remain. |
| Art cohesion | 15 | 98 | Score unchanged. The HUD's plate no longer lies over the room as a black bar. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 547: the art loop stays **gated** on Sean (three guardian bases wait). Next, the pass 540 grade's
repeating tile stripes and grids (and the thorn column on the Sky Steps walls that repeats one stamp),
then its thin shop UI (no item icons). The VFX-tool trials continue on the dash afterimage, then the
enemy death dissolve. Rim light on figures and the Boughs painterly clash stay parked for a watched
session.
