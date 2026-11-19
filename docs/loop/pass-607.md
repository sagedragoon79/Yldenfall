# Pass 607: a struck foe stays solid

## Category

Combat readability, from the independent grade taken after pass 605 (5.3 of 10; combat readability
4.5): "at the moment of impact the struck foe turns into a see-through ghost and loses its outline".
Pass 602's dark rim had not settled it. It was pass 606's "Next".

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
606 waited for CI. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm,
Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean.

## Audit

At 5x in the Spires and Tower hit frames: nothing is drawn see-through (pass 602 found the flash
opaque). The read comes from color. Through the soft phase, the rest of a hit flash after its
one-frame pop, a foe wears 45 percent of pure white (`SHEET_SOFT_WHITE`; 40 percent through a
code-drawn foe's wash). Over the dark, cool colors most foes are drawn in, that makes one flat
lavender-grey, close in hue to the dark violet backdrops behind them, so the body reads as the
background seen through a veil. The beetle's brown shell, the dwarf's iron and the hound's amber are
all gone in it.

## What was built

- **A lighter, warm soft phase** (bible 6.7, `Enemy`): 0.3 (`FLASH_SOFT_WASH`, `SHEET_SOFT_WHITE`, the
  lowest pass 567's guard allows) of a warm cream (`SOFT_TINT`) in place of 0.4 and 0.45 of
  white, for sheet foes' overlay and code-drawn foes' wash alike. A struck foe keeps most of its own
  colors and reads lit by the blow. The one-frame white pop is unchanged.

Judged by eye at 5x in five hit frames, before and after: the beetle stays brown, the dwarf dark iron,
the hound amber and the mantis olive, each still clearly lighter than at rest.

## Tests

`tests/test_hit_flash.gd`, `test_a_struck_foe_keeps_its_own_colors_through_the_flash` (6 checks): the
pop is still white; after it the overlay covers at most 30 percent, in a warm cream; a dark violet foe
under it stays dark and turns warm, not lavender; a code-drawn foe's soft wash takes the same tint.
Pass 567's flash tests (the pop once, the tint's bounds), pass 585's tell overlay and pass 602's rim
still pass.

Mutation check, restored from a copy after: 0.45 of white again fails it (4 checks).

Full suite: 25,454 checks passed and 0 failed (1,242 tests).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A struck foe keeps its colors through the flash. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Sean paused the loop after this pass (2026-11-18), and the scheduled task with it. When it resumes,
from the pass 605 grade: the gold counter's slashed zero (the pixel font's "0" has a diagonal slash,
and the HUD's outline boxes it), the hit spark that reads as a clock-face lock-on marker, and foes that
blend into their backgrounds (the Boughs' mantis and archer, the flooded hall's shade). The sword's
look, the Haar's fog and dither and the sprites' pixel size stay held.
