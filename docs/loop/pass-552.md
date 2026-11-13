# Pass 552: a fire seal burns in tall licks

## Category

From the independent grade taken after pass 550 (5.3/10), as pass 551's "Next" named it: "the
Proving Scar's lava column is a flat noisy rectangle with no glow falloff, and over half the screen
is empty void". Art cohesion and Atmosphere in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

- The "lava column" is the Proving Scar's fire seal, two tiles wide and seven tall (`FireSeal`,
  legend `Z`). Inside the sheet, two octaves of round value noise drove the whole heat ramp
  (`0.7 * (n - 0.5)` on a core that saturates 2.5 px from an open side), so a wide seal was an even
  mottle of yellow, orange and white with no up or down: lava, not flame.
- Each tile started its clock from its own position, so neighbouring tiles scrolled the field out
  of step. The mottle hid it; any directional fire shows it as a hard line at every seam.
- The halo (pass 549) faded on a straight line over 20 px at 0.3 alpha: a faint even band, which
  the grader did not read as light.
- The "empty void" is the room's solid mass, drawn by `DeepShade` (bible 12.38), which sinks the
  inside of rock into the dark on purpose. The catalogue's camera stands where that mass fills the
  right half of the frame. This is a room-layout matter, not a drawing fault; it is not changed
  here and stays in the queue.

## What was built

- **Tall licks** (`FireSeal.lick`): a second tiling field, the same noise stretched six to one up
  the column, rising 2.5 px a frame. Three pixels in from an open side the heat is a steady core
  (`CORE_HEAT` 0.68, `CORE_DEEP` 0.08 more in the depth of a wide seal) carried by the licks
  (`LICK_GAIN` 0.42); the round noise stays at `GRAIN_GAIN` 0.2 to break their edges. At an open
  side the round noise rags the flame as before.
- **The bank** (`FireSeal.bank`): a column burns `BANK_COOL` 0.1 cooler at its top than `BANK` 4
  tiles down, so a tall seal has a hot foot and a red crown.
- **One time**: every tile of a seal steps on the same frame, so a lick crosses the seams whole.
- **The halo**: `HALO` 20 to 32 px, `HALO_FLOOR` 5 to 6, `HALO_PEAK` 0.3 to 0.42, and a falloff
  curve (`HALO_CURVE` 1.7), so it is bright against the flames and thins out in a long tail. Still
  four dithered steps, drawn once per tile.
- Hitboxes, the burn, the runes, the coals, the `RoomLight` pools and the douse are untouched.
- Design bible 12.42, and the fire-seal line of 4.5.

## By eye, at 1x and 3x

`evercrown/proving_scar`, before and after. The seal now reads as fire that rises: tall yellow
tongues with orange between them, a pale hot foot, a redder top, and no line at any tile seam. The
glow on the purple wall either side is plainly brighter at the flames and falls away to nothing
about two tiles out. The runes still read. The halo's dither is visible at 3x, as it was, and
matches the room's other dithers.

## Tests

`test_fire_seal_burns_in_tall_licks` in `tests/test_fire_seal_art.gd` (9 checks): runs of one tone
are longer down than across inside a wall of seals; the licks outweigh the round noise; the lick
field changes faster across than up, and tiles; a column is hotter at its foot than at its top; the
halo's reach and curve; and a built seal's eight tiles keep one time. The 13 older fire-seal tests
pass unchanged.

Mutation check: no licks (the old heat) fails the runs check; a straight halo fails the curve
checks; no bank fails the foot-and-top check; a clock per tile fails the one-time check.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms, the empty mid-ground and the Proving Scar's framing remain. |
| Art cohesion | 15 | 98 | A fire seal reads as flame and lights the stone with a falloff. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; one more cached field, the halo still drawn once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 14,370 checks passed, 0 failed.

## Next

Pass 553: the art loop stays **gated** on Sean. From the pass 550 grade: foes more saturated than
their rooms (bee, snake, Bark Knight); then the shop's missing item icons. From the pass 545 grade,
still open: the uniform rain over the Spires. The Proving Scar's framing (half the picture is solid
mass) is a room-layout item in the queue. Rim light on figures and the Boughs painterly clash stay
parked for a watched session.
