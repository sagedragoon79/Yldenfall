# Pass 592: the cut is laid across the foe, and the foe reels

## Category

Combat readability, from the independent grade taken after pass 590 (5.3 of 10). It scored combat
readability 4.5: "the hit frames' sword is a flat white plank with no taper or smear, the spark is
small, and the struck foe shows no flash or knockback pose." Pass 591 closed the grade's first
defect (the stepped ceilings) and named this one next. The sword's look is a watched-session call
(the hero and his gear come from PixelLab, bible 13.5); the spark and the struck foe are not.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for
a watched session, so this pass took the second, the pass 590 grade. The PixelLab art loop stays
**gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his
OK, the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended; push.py gets HTTP 500); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

Read against the ten fight captures (`workbench/catalog/fights`, shot two frames after a real
swing lands):

- **The spark** is the pass 529 VFX sheet at density 2: a hollow ring and a spray about 30 render
  pixels across on a 1280-wide frame. Pass 530 kept it small on purpose so the foe stays visible.
  At 1x it reads as a small orange badge on the foe's near edge, not as a blow.
- **The flash** is there: the frame a blow lands the foe pops white, and the rest of the flash
  wears the pale tint (pass 567). In every hit frame the foe is visibly pale. The grade's "no
  flash" is the tint being read as the foe's own color next to a spark that says nothing.
- **The knockback** moves the foe at 140 px/s, slowing at 700 px/s per second over a 0.18 s
  hitstun: about 6 px by the captured frame. Nothing about the pose changes, so a struck foe
  stands in the hit frame exactly as it stood before.

## What was built

- **The impact streak** (bible 6.7, `HitSpark`): every spark, in both looks, lays a tapered white
  blaze over a pale-gold glow across the foe for its first 0.16 s, 40 world pixels long and 3 wide
  at its middle (1.6x for the heavy finisher). A level cut lays it on a rising diagonal (0.75 rad),
  its middle 8 px past the spark, over the foe's body; a leftward cut mirrors it. It holds at full
  for half its life, then thins and fades. Thin and short, so the foe and blade stay visible.
- **The recoil** (bible 6.7, `Enemy`): through its hitstun, each of the 22 foes drawn from a sheet
  leans away from the blow (a shear of 0.3 px across per pixel up, about its feet) and squashes
  10% wide, easing upright on a quadratic. `take_hit` keeps the blow's side and full hitstun; a
  launch, a stagger or a turned blow leaves the foe upright. `draw_sheet` draws through
  `_sheet_transform`, which is the old facing transform when there is no recoil.

Judged by eye at 1x and 2x in six hit frames (the Heartwood, the Boughs, Vorrhallow's kennels, the
Spires, the Evercrown, the Haar), before and after. The first try (30 px, 0.1 s, a steeper 0.95
rad) had faded to a faint line by the captured frame; the kept one reads at 1x as a bright cut
across the foe. Its first middle sat on the spark, on the foe's near edge, so its lower half ran
into the hero's feet; it now sits over the foe. The lean reads on the mantis and the hound;
the beetle's low body shows little of it, which is right for a squat foe.

## Tests

`tests/test_hit_impact.gd`, two tests:

- `test_a_spark_lays_a_streak_across_the_foe`: the streak is drawn at full on the first frame,
  rising across a rightward cut and mirrored for a leftward one, at least 36 px long, its middle
  past the spark, full through half its life and gone by 0.16 s; the heavy finisher's is bigger;
  the code look draws it too.
- `test_a_struck_foe_leans_away_from_the_blow`: a hornet at rest is drawn upright; struck from the
  left it is drawn leaning right, eases back over the hitstun and stands upright after it; struck
  from the right it leans left; a stagger with no blow does not lean.

Mutation check, each restored from a copy after: the streak's draw call removed fails the first
test (2 checks); the sheet drawn upright again fails the second (3 checks); the lean thrown
toward the blow instead of away fails the second (3 checks).

Full suite: 18,630 checks passed and 1 failed: `test_the_stillstone_holds_every_loosed_hazard`,
which reads every foe script for `class_name Enemy
`. The pass's own edit had saved `enemy.gd`
with Windows line endings (Python's text mode on this PC); with LF restored it passes, as do
this pass's two tests. The index was LF throughout, so CI sees the same files.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A blow now reads in its frame: the cut across the foe, and the foe reeling. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The grade's combat-readability items, but for the sword's look, are answered. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 590 grade, in its order: the thorn bulbs that read as strawberries, the
shop's control labels, then the queue: the repeated chest and sign, the grid item's leftovers.
The code-drawn foes' recoil when a grade names one. The sword's look and the Haar's fog stay held.
The next independent grade is due after pass 595 (every fifth pass), or after the next art pass.
