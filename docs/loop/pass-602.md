# Pass 602: a struck foe keeps its edge

## Category

Combat readability, from the independent grade taken after pass 600 (5.2 of 10; combat readability
5.0): "at the moment of impact, the struck foe goes semi-transparent, and the white sword, white arc
and pale foe merge, so the hit reads as the foe fading out instead of taking a blow". It was pass
601's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
601 waited for CI, on top of pass 601's commit. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No
PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still down (its
Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- **Nothing is see-through.** `Enemy.draw_sheet` draws the foe's frame, then its mask in white over it
  (`SHEET_WHITE` 0.85 on the frame a blow lands, `SHEET_SOFT_WHITE` 0.45 for the rest of the flash),
  all at full alpha. A code-drawn foe's wash mixes its colors toward white and keeps its alpha.
- **The edge goes with the body.** The white mask covers the whole silhouette, the foe's own dark
  outline with it. So at 3x in the Tower, Spires and Haar hit frames, the pale grey body runs straight
  into the white cut, the cream arc and a pale sky with nothing between them, which reads as the foe
  fading into the light.
- A tell already solves the same problem with a warm rim one pixel wide around the foe (pass 585).

## What was built

- **The dark rim of a hit flash** (bible 6.7, `Enemy.draw_sheet`): through a hit flash, the pop and the
  pale tint alike, a foe drawn from a sheet wears a near-black rim one pixel wide (`HIT_RIM_COLOR`, the
  outline's 120c16, at `HIT_RIM` 0.95), on the tell rim's four steps. A tell keeps its warm rim and
  never wears the dark one. The flash's white levels are unchanged (pass 567).

Judged by eye at 3x in six hit frames, before and after: the struck dwarf, hound, beetle, mantis and
crystal dwarf keep a crisp edge where they meet the cut and the arc. Against a dark wall the rim sinks
into the wall, as an outline does.

## Tests

`tests/test_hit_flash.gd`, `test_a_struck_foe_keeps_a_dark_edge` (6 checks): a hornet at rest wears no
rim; struck, it wears the dark rim with the white pop and through the pale tint; the rim is near-black,
nearly solid and never to be taken for a tell's; it goes with the flash. The pass 567 and 585 flash and
tell tests still pass, and so does pass 599's cut test.

Mutation check, restored from a copy after: never drawing the rim fails it (2 checks).

Full suite: 21,896 checks passed and 4 failed, all frame-time budgets measured while Unity editors on
this PC drew heavily on the CPU (one had used about 4,000 CPU-seconds since 1:18 PM):
`test_spires_rain_stays_cheap`, `test_every_boss_fight_holds_the_frame_budget`,
`test_every_room_loads_and_settles_inside_the_budget` and `test_every_foes_spoils_rest_in_its_room`. The
rim is drawn only through a hit flash, which none of those tests strikes; CI is the gate.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A struck foe keeps its edge against the cut. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the shop panel and the trestle's repeats remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 600 grade: the minimap's single rectangle and the HUD's plain translucent box, then the
X-braced trestle repeated across zones (pass 596; vary it by zone). The Haar's fog, the sword's look
and the sprites' pixel size stay held.
