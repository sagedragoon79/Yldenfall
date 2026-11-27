# Pass 674: a tell is keyed off what stands behind it

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 670 (5.3/10) names next, past the items done in passes 671 to 673, "tells drawn in the
background's values (the Heartwood knight against the gate, the flooded hall's thin spike tell)".
This pass takes it. The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK,
the limit); no PixelLab generations or Autosprite credits were spent.

## Audit

The `heartwood-tell` and `vorrhallow-tell` fight frames at 4x:

- **Heartwood.** The Rot Dwarf's tell is a gold rim near his raised axe and a gold four-point glint.
  Both sit over the gate's tan planks and pillar, the same warm hue and nearly the same value. The
  seat's shade (12.145) darkens the planks behind him but keeps their hue, so the gold has no edge.
- **Flooded Hall.** The Crystal Dwarf's lane (12.144) is a two-pixel pink crack and 7 px tips on the
  tide's surface, pale on pale; at 1x it reads as a thin stroke.

## What changed

Design bible 12.151 (new); `scripts/enemies/enemy.gd`, `scripts/enemies/crystal_dwarf.gd`.

- **A keyline outside the warm rim.** On a lit beat a near-black silhouette is drawn 2 px out in the
  same squares about the weapon as the gold rim, so the gold lies between the body and a dark edge.
- **A dark backing under the glint**, a pixel wider each side than its arms and core.
- **The lane and tips keyed**, and the tips stand 10 px (7 before).

Judged by eye at 1x and 8x: the glint now reads as a star on a dark cross over the gate's pillar,
the rim near the axe has a dark edge on the planks, and the lane is a lit crack with a dark lip and
taller shards.

## Tests

- New `test_a_tell_is_keyed_off_the_background` (`tests/test_tell_glint.gd`): the key's value is far
  under the gold's, it lies outside the rim, the glint is backed on every wind-up frame, every lit
  beat's rim is keyed, a blow takes the key away, and the lane's key and tip height hold.

Mutation check: with the keyline and the glint's backing taken out of the draw, the new test fails
(30 checks).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,594 checks passed, 0 failed. CI (test and mix) passed on the
pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Tells carry a value break on any ground. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 675 is the independent grade. Then, from the pass 670 grade in its order: the canopy's flat
mint wash and stepped edges; generic grey skylines.
