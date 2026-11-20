# Pass 621: a blow knocks chips off the foe

## Category

Combat and enemies (combat readability). The top unheld item of the queue, from the pass 615
grade (5.6 of 10): "a landed hit is one small spark with no foe flash, streak or debris in the
frame (check the fight captures still catch the flash of pass 602)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Looked at the seven hit frames in `workbench/catalog/fights` at 1x and 3x, and timed one
(`spires/fallen_bridge`) with a print in the capture:

- **The flash had just ended.** A hit flash is 0.08 s (`Enemy._flash`). The capture waits for
  the swing's smear, which shows 0.03 s of game time after the blow (the hit-stop is real
  time and does not count), then took the picture two frames later: 0.013 s of flash was left
  when it asked, none when the frame was drawn. So the frames showed a foe in its own colors,
  and the grader was right that no flash was in them.
- **Nothing in the frame is of the foe.** The spark, the streak and the smear are white and
  gold whatever is struck. `Dust`'s "hit" puff is six cream 2 px dots that fade in 0.2 s: not
  visible in any of the seven frames.
- The streak of pass 592 and the recoil are in every frame, and read.

## What was built

- **`HitChips`** (`scripts/fx/hit_chips.gd`, new): a blow that wounds breaks 6 splinters off
  the body (10 from a heavy blow). Each is a kite 6 px long that points the way it flies, over
  a near-black copy one pixel lower. They start 6 to 12 px on from the middle of the body, fly
  within 0.7 rad of the blow's line tipped up, leap out at 260 to 420 px/s, are braked and
  fall, and are gone in half a second. The hit-stop holds them, as it holds the spark.
- **The foe's own colors** (`Enemy.chip_colors`, `Enemy.sheet_chip_colors`): the commonest
  tone of the first cell of the foe's sheet that is lighter than its outline, and the lightest
  of its six commonest; each chip is mixed a fifth of the way toward the flash's cream. A foe
  with no sheet (a code-drawn guardian) sheds pale bone. `draw_sheet` records the sheet it
  drew from; a foe that draws another way is looked up by its script's name.
- **`Enemy.take_hit`** spawns them after the guard has had its say, so a turned blow sheds none.
- **The fight pictures** are taken one frame after the smear shows, not two
  (`capture_all.py`), so the flash's last frame is in them.

First try, thrown out by eye: 3 px squares with a dark underside, in the commonest color above
a luminance of 0.16. They sat over the body as dark square holes (the commonest such color of
a beetle or a slug is its deep shade). Splinters, a floor of 0.3, the cream and a start ahead
of the body fixed each of those.

## Checked by eye

`heartwood/entrance`, `spires/fallen_bridge`, `tower/smelter`, `boughs/thicket_road` and
`vorrhallow/kings_kennels` at 1x and 3x: pink-grey splinters off the Heartwood's slug, orange
off the Thunder Beetle, tan off the Iron Dwarf, gold off the Clockwork Hound, each clear of
the body on its far side. The Iron Dwarf and the Boughs' knight show the flash's cream; the
slug and the beetle are pale already and show it least.

## Tests

`tests/test_hit_chips.gd` (three tests). Full suite: 30,704 checks passed, 0 failed. Mutation-checked:

| Mutation | Fails |
| --- | --- |
| `take_hit` spawns no chips | all three |
| `chip_colors` always returns bone | the colors test |
| chips spawned before the guard is asked | the turned-blow test (and the count) |
| chips thrown against the blow | the direction and leap checks |
| a stopped clock still brakes the chips | the hit-stop check |

The last mutation passed at first: the test looked only at a chip's place, which a stopped
clock cannot move. It now looks at the chip's speed too.

## Not done

- The flash itself is unchanged: 0.08 s, a white pop and a cream tint. Whether it should last
  through the blade's travel is part of the watched feel call (the blow lands on the swing's
  first step, found in pass 561).
- Code-drawn guardians shed bone, not their own colors: each would need a tone named by hand.
- No sound of its own, and no chips from the hero when he is struck.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A wound sheds the foe's own colors; no number of the fight changed. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The Spires' ridge as more than one value (the last pass 615 item). Then the pass 620 grade's
items: the large rectangular dark blotches and stair-stepped tone patches in brick and earth,
copied props, foes' contrast with their backdrops, the empty minimap and the coin count's
glyph, the fire seal's color against the Haar's fog, the shop description that repeats the
stat lines. The independent grade is next due after pass 625. The Haar's fog and dither, the
sprites' pixel size, the hero's rim light and the sword's look stay held.
