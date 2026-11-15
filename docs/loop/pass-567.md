# Pass 567: a struck foe's hit flash keeps its inner lines

## Category

Combat readability, from the independent grade taken after pass 565 (4.6/10): "both hit frames
show the sword as a flat grey-white bar wider than the hero with no arc, and the struck foe as a
solid white cutout". This is the unattended half, the foe.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session; this is the next one, as pass 566 named under "Next". The PixelLab art loop
stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for
his OK, the limit of three. No PixelLab generations were spent, and no Autosprite credits. The
hosted workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for
Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- A hit sets `Enemy._flash` to 0.08 s, and for all of it the foe was drawn at full white: the
  wash shader at 0.72, or a white copy of the sprite at 0.85 alpha over a foe drawn from a sheet.
  At 0.72 a dark outline sits within a quarter of the brightest light; nothing inside the
  silhouette reads.
- The flash counts down on game time and the 50 ms hit-stop holds game time at zero, so the
  white cutout stood for the hit-stop too: about eight frames to the eye, and the whole of the
  moment a blow is looked at.
- The fight capture (`--when=hit`) waits for the smear, which opens on the swing's strike frame
  0.05 s of game time after the hit-stop, plus two frames. The flash is still up then, so every
  hit picture in a grade set showed the cutout.
- The sword half of the defect was checked and left: the capture catches the hero's strike frame,
  which is the sheet's own blur of the blade (`PlayerVisual.STRIKE_FRAME`, bible 6.7). Whether
  that frame should show an arc is the watched feel call found in pass 561; it stays in the queue.

## What was built

- **One frame of white, then a tint** (`Enemy._flash_is_soft`, `scripts/enemies/enemy.gd`). The
  frame a blow lands keeps the full white, the pop (`FLASH_WASH` 0.72, `SHEET_WHITE` 0.85). Every
  later frame of that flash, the hit-stop included, is a pale tint (`FLASH_SOFT_WASH` 0.4,
  `SHEET_SOFT_WHITE` 0.45) that leaves more than half of the foe's own contrast.
- The pop is found from the flash itself: a flash that stands higher than it was last drawn is a
  new blow. So the guardians that set `_flash` themselves get it, a second blow inside a flash
  pops again, and no foe's script changed: all of them draw through `Enemy.wash` or
  `Enemy.draw_sheet`.
- **A tell is never softened.** With no hit flash running, a wash or a white sheet is full
  strength, as before. A blow that lands in the middle of a tell softens the pulse for the 0.08 s
  of its flash at most; the tell is 0.35 s or longer.
- `Enemy.white_strength()` reports how white the last drawing was, for the tests.
- Design bible 6.7 (the Flash line).

Looked at before and after at 2x, in the recaptured fight frames (`workbench/catalog/fights`):
the Heartwood's grub was a white lump and is now a pale grey body with its segments showing; the
Vorrhallow hound was a white cutout and now shows its head, ribs and legs under the tint. The
spark and the smear are still the brightest things in the frame.

## Tests

`tests/test_hit_flash.gd` (four tests): a hit flash is drawn for three frames or more, its first
is the pop, the pop is one frame, the rest are the tint, and a second blow inside the flash pops
again; a tell's pulse is always the full white; a code-drawn foe's wash softens the same way, with
the shader's amount checked, and a wash with no hit flash behind it is full; the tint's numbers
keep more than half of the contrast and are still a flash.

Mutation check: a flash that is never soft fails the first and third tests (five checks); one that
is soft from its first frame fails the same two (six checks); one that softens a tell fails the
second and third. The code was restored from a copy each time.

Full suite: 15734 checks passed, 5 failed, in four tests, all wall-clock budgets
(`test_spires_rain_stays_cheap`, `test_a_long_journey_through_the_whole_game_stays_lean`,
`test_every_room_loads_and_settles_inside_the_budget`, `test_every_foes_spoils_rest_in_its_room`)
while another project's scripts ran on this PC (processor load near 50%). Each passes when run
alone right after (26 checks). Nothing in this pass draws or loads more: a flash picks one of two
ready materials or one of two alphas. CI's full suite on a quiet machine is the check for it.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A struck foe stays readable through the blow. The independent grade is the real measure. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged; they take the same flash. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Of the queue: the Sunken aqueduct's brick and waterfall with the pillars-and-water item, then
one-template rooms. The sword in the hit frames (a flat bar with no arc) waits for a watched feel
call. The next independent grade is due after pass 570. The test runner's shared `user://` (found
in pass 563) is still worth a short tooling pass. The Haar items wait until the hydra and steam
branches merge; the Blinkhop waits for a free base slot.
