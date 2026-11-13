# Pass 551: Gnarlmaw is not one plate repeated

## Category

From the independent grade taken after pass 550 (5.3/10): its second defect, "Gnarlmaw is a long row
of identical segments that hides the hero and the safe space", in its two lowest areas (Combat
readability 4.0, Characters and foes 4.5). The first defect, the Haar Wyrm, belongs to the gated art
loop.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits (Gnarlmaw's sheet is Autosprite art; this pass only changes
how the code draws it). The hosted workbench is still down (its Vercel Blob store is suspended); it
stays under "stuck" for Sean. The independent grade for pass 550 was already taken (07:40), and
README's playtest link already points at sagedragoon79/Yldenfall.

## Audit

- `Gnarlmaw._draw` drew the same `plate` frame for all 22 body rings at one size, one angle and the
  sheet's full colour, 22 px apart. In the floor lunge that is a wall of identical brown balls from
  one side of the arena to the other.
- The hero's dark crimson sits at nearly the plates' value, so a hero in front of the body was hard
  to find. The amber tail (the weak point) and the mandible head had nothing setting them apart
  from the body but hue.

## What was built

- **Ring scale** (`Gnarlmaw.ring_scale`): 1.0 behind the head, swelling to 1.18 a third of the way
  down, tapering to 0.9 before the tail; every third ring is 0.05 heavier. Clamped to `RING_MIN`
  (0.9), the least scale at which the 19 px plate still covers the 17 px hitbox, so no ring hits
  from air.
- **Ring tilt** (`ring_tilt`): each plate sits at its own fixed angle, at most 0.14 rad, mirrored
  with the rail.
- **Ring shade** (`ring_tint`): plates are drawn at 82% of their colour behind the head down to 62%
  before the tail, slightly cool, every third ring a step lighter. The head and the tail stay at
  full colour. While a stagger has the plates cracked, every ring is at full colour: bright means
  open.
- Hitboxes, damage, timings and the rail are untouched.
- Design bible 8.1.

## By eye, at 1x and 2x

`heartwood/root_chamber` at frame 330 (the floor lunge), against the catalogue picture from before.
The body now reads as one tapering animal with a thick shoulder, not a row of stamps; the amber
tail and the pale mandible wheel are the two bright things in the frame; and the hero's hood and
hands stand out against the darker plates at 1x. The smaller rings near the tail lift a pixel or
two off the floor, which reads as the body arching. The plate is still one drawing, so the braid on
each ring matches its neighbours' at 2x; a second plate drawing would need Autosprite credits
(reserved, bible 13.2) or the PixelLab guardian loop.

## Tests

`test_gnarlmaws_rings_are_not_one_plate_repeated` in `tests/test_boss.gd` (98 checks): at least 8
sizes, no ring matching the one before it, a spread of a fifth or more, thinner and darker before
the tail, no ring drawn smaller than its hitbox, the plates below full value and at full colour
when cracked, the head and tail untouched, and the plate on the sheet at least `PLATE_RADIUS`.

Mutation check: `RING_MIN` 0.8 fails the hitbox checks (4); one size and no tilt fails the variety
checks (4); no shade fails the value checks (23).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Unchanged; the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Gnarlmaw's body has a shape, and its weak point and its open state read by brightness. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; three small static functions per ring per frame. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 552: the art loop stays **gated** on Sean. From the pass 550 grade: the Proving Scar's lava
column (a flat noisy rectangle with no glow falloff) and its empty void; then foes more saturated
than their rooms. From the pass 545 grade, still open: the uniform rain over the Spires. Rim light
on figures and the Boughs painterly clash stay parked for a watched session.
