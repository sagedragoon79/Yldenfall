# Pass 585: a tell keeps the foe's pose

## Category

Combat readability and characters, from the independent grades taken after passes 575 and 580
(5.6 of 10): "the Haar tell frame shows the foe as a flat white featureless silhouette, like a
missing texture, with no direction, weapon or reach".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, the second (the Haar's fog) is held until the hydra and steam branches
merge, and the third is watched-session calls and art-loop work. The fourth (the aqueduct's
second face tile, the shop panel, the HUD over the ceiling) is small beside this one, which is
in every grade set (two to four fight frames, bible 12.0), so this pass took the fifth. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no
Autosprite credits. The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

Looked at the catalogue's three tell frames (`heartwood-tell`, `haar-tell`, `vorrhallow-tell`)
at 1x and 2x, and at how a tell is drawn.

- **The capture was honest.** `Enemy.telegraph_pulse` whites the foe on every other sixteenth
  of a second, for the whole wind-up. A sheet foe wore its flat mask in white at 0.85
  (`SHEET_WHITE`); a code-drawn one was washed 0.72 toward white. Half of every wind-up was a
  white hole in the shape of a foe.
- **It was a decision, and the wrong one for the art.** Pass 567 softened the hit flash so a
  struck foe keeps its lines, and left the tell at full white "because it is a warning". But
  the wind-up pose is the frame the player learns, and the one the art loop draws most
  carefully; the pulse erased the raised axe, the shield and the facing.
- Three foes (the Grub Lump, the Lantern Ghost, the Spring Eel) drew their own white overlay
  at a fixed 0.85, so pass 567's softer hit flash never reached them.

## What was built

- **A tell is a warm tint and a rim** (`Enemy.TELL_TINT`, `SHEET_TELL` 0.42, `TELL_WASH` 0.45,
  `TELL_RIM`, `RIM_STEPS`). The pulse mixes the foe toward gold by less than half, and a foe
  drawn from a sheet wears its mask in the tint one pixel out on each side, behind the sprite.
  The beat, length and sound of every tell are unchanged.
- **White means a blow landed; gold means one is coming.** `Enemy.flash_overlay` picks the
  overlay for every sheet foe: the white pop, the pale tint, or the tell's tint. A blow that
  lands in a wind-up pops white over the tell.
- `Enemy.wash` (code-drawn foes and five guardians) uses a third material, the tell's, in a
  state named `windup` or ending in `_tell`; `shaders/wash.gdshader` has a `tint`. A guardian's
  death blink and Snapcrown's head flash stay white.
- The Grub Lump, the Lantern Ghost and the Spring Eel draw through `flash_overlay`, so their
  hit flash softens like every other foe's.
- Design bible 6.7, 7, 12.43 and a new 12.72; the enemy style guide's "the flash is the
  code's job".

One take: the first try stood at 0.5 for both; the body read as a gold statue at 1x, so the
sheet overlay went down to 0.42 and the rim carries the warning.

For Sean to judge in play: whether gold reads as a warning as fast as white did. `TELL_TINT`
is the one place to change the hue, `SHEET_TELL` how much of the foe shows.

Not looked at in a picture: the five code-drawn guardians' tells (the Drowned Warden,
Gloamweaver, Skyrend, Snapcrown, Thane Vorrund). They take the same wash at 0.45 with no rim;
the fight set has no guardian tell frame. Queued: add one to `FIGHTS` and look.

## Tests

- `tests/test_hit_flash.gd`: `test_a_tells_pulse_is_its_own_tint_and_never_a_blows_white`
  (replaces `test_a_tells_pulse_stays_full_white`),
  `test_the_overlay_is_the_tint_for_a_tell_and_white_for_a_blow`,
  `test_the_tell_keeps_the_foes_pose_and_is_not_white`, and the wash test now checks the
  tell's material, amount and tint in `windup` and a `_tell` state.
- `test_every_foes_tell_flashes_it_white` still passes unchanged: a tell still counts as
  drawn flashed.

Mutation check, each restored after and the file compared byte for byte: a white `TELL_TINT`
fails 2 checks of the numbers test; an overlay that is never a tell fails 2 checks of the
pulse test and 3 of the overlay test; a wash that is never a tell fails 6 checks of the wash
test.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A wind-up shows its pose through the pulse; timing and rules unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | No white cutouts are left in a fight; the independent grade is the real measure. |
| Bosses | 10 | 99 | Five code-drawn guardians' tells take the tint; not yet seen in a picture. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Four more draws of a mask on a pulsing foe; nothing measurable. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due now (after pass 585); its top defects go to the queue. Then, in
the queue's order: what is left of the grid item (the aqueduct's second face tile, the HUD
over the ceiling tiles, the shop panel); a guardian tell frame in the fight set; chests housed
differently per zone and the causeway's spikes; code-first liquids and hazards; an audio pass
for the set pieces; the five mid backdrops `tilegen.py` no longer reproduces. For the art loop
when a base slot frees: the Bog Puffcap, the Bark Knight and the Spring Eel have no accent
color on their sheets. The Haar's fog stays held.
