# Pass 608: a plain zero

## Category

UI and menus, from the independent grade taken after pass 605 (5.3 of 10): "the gold counter's
slashed zero reads as a debug glyph". It was first on pass 607's "Next".

No note from Sean was new. This is the first scheduled pass since Sean restarted the loop on
2026-11-19. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. README's playtest link already points at sagedragoon79/Yldenfall.

## Audit

The pixel font's "0" (`tools/art/fontgen.py`) is the "O" with a diagonal stroke through it, from
the lower left to the upper right. In a 5x7 face the slash fills most of the ring, and under the
HUD's one-texel outline the counter's zeros read as boxed, struck-out marks, the look of a debug
readout rather than a purse. The slash was there only to tell "0" from "O"; nothing else needs it.

## What was built

- **A plain zero** (bible 12, the font): "0" is an oval with nothing inside, 4 columns wide
  against the "O"'s 5, so the two still never read alike. The font was regenerated
  (`assets/fonts/pixel.png`, `pixel.json`).

Judged by eye at 2x in the HUD with 1,008 gold: the counter reads as plain numerals beside the
coin, the zeros clearly rounder and narrower than the letter "O" in the menus.

## Tests

`tests/test_systems.gd`, `test_the_pixel_fonts_zero_is_plain` (3 checks), reading the glyph from
the font image: nothing is inked inside the zero's ring, both sides of the ring are inked, and it is
narrower than "O". The pass 40 font test (every printable character, whole-number scales) still
passes.

Mutation check, restored from a copy after: the slashed zero again fails it (2 checks).

Full suite: 25,457 checks passed and 0 failed (1,243 tests). The first run hit `tools/run_tests.sh`'s 45-minute cap on this PC (`TEST_TIMEOUT`, default 2700 s); the full run took longer, so it was rerun with `TEST_TIMEOUT=6000`.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The counter's zero is plain; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 605 grade: the hit spark that reads as a clock-face lock-on marker, then foes that
blend into their backgrounds (the Boughs' mantis and archer, the flooded hall's shade, the gear
pit's ceiling creatures) and the flat green block in the canopy bridge. The sword's look, the
Haar's fog and dither and the sprites' pixel size stay held. Pass 610 takes the next independent
grade (every fifth pass).
