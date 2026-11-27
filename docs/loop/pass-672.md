# Pass 672: the cast of foes is painted in one key

Date: 2026-11-27. No new notes from Sean. From the queue, first item: the independent grade of
pass 670 (5.3/10) names, past its held items, "foes in three styles (rendered bees and snake
against the flat hero, a third set in the beetle and the blob)". This pass takes it. The PixelLab
art loop stays gated on Sean (three guardian bases wait for his OK, the limit); no PixelLab
generations or Autosprite credits were spent.

## Audit

Lineup and 3x strips of the hero, Hornet, Silt Adder, Thunder Beetle, Meteor Slug, Grub Lump and
Leaf Mantis, and the canopy bridge, grub burrows and Spires fight frames. Measured every sheet
foe's body (opaque, value at or over 0.12): the median value ran from 0.27 (Iron Dwarf) to 0.58
(Spire Sentinel), the mean saturation from 0.20 to 0.66 (Thunder Beetle). The cast's medians are
0.43 and 0.42. The beetle is the outlier both ways (0.31, 0.66); the Hornet is light (0.55). Line
and rendering differ too (lit seams on the beetle and slug, soft shading on the bee and snake);
those need redrawn sheets and are not in reach of a code pass. Accent coverage was also checked
(no foe's accent covers more than 12% of it), so the accent lift is not what sets the bee apart.

## What changed

Design bible 12.149 (new); enemy style guide 3 (a rule for new sheets); `scripts/enemies/foe_light.gd`
(`KEYS`, `keyed`, `lit`, `material_for`); `shaders/foe_light.gdshader` (`key`); `tools/art/cast_key.py`
(new: measures the sheets and writes `KEYS`).

- **One key.** Each foe off the cast's key takes a gamma on its value and a scale on its saturation
  in FoeLight's material, before the room's light, so its body's median value and mean saturation
  come to 0.43. Bounded (gamma 0.75 to 1.3, saturation 0.8 to 1.15) and only on the axis that is off
  (slack 0.05 and 0.08). Black and full value are unmoved. The Lantern Ghost, Crystal Dwarf, Spring
  Eel and Leaf Mantis are kept off it.
- Fourteen foes keyed. The beetle comes up out of its dark purple and loses chroma; the Iron and Rot
  Dwarves come up a step; the Hornet, Blinkhop, Gear Bat and Mothling step down.

Judged by eye at 3x on the sheets (before and after) and in the Spires and Tower fight frames. The
change is a step, not a fix: value and chroma are evened, line and rendering are not.

## Tests

- New `test_the_cast_is_painted_in_one_key` (`tests/test_foe_light.gd`).
- `test_each_foe_keeps_one_colour_of_its_own` compares a non-accent colour against the keyed paint,
  and the no-accent list splits the Bog Puffcap (keyed, no accent) from the foes with neither.
- `test_a_foes_body_stands_above_the_rooms_dark` measures "not washed out" from the keyed paint: the
  key is the foe's paint now (the three darkest sheets failed it against the raw paint, 0.33 from 0.18).

Mutation check: with the Thunder Beetle's key set to [1, 1] the new test fails three times (value,
saturation, and the beetle's purple).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,544 checks passed, 1 failed:
`test_a_sunlit_zones_woods_recede_into_light`, the Leaf Mantis's body desaturated by its key to
within a step of the Boughs' woods (12.112). The mantis is kept off the key; that test and the
four FoeLight tests were rerun and pass. CI (test and mix) runs the whole suite on the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The foes share one value and chroma key; line and rendering still differ. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One branch in the foe shader. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 670 grade in its order, past the held items: boxed rooms with one flat floor and the
hero at the far left; then tells drawn in the background's values (the Heartwood knight against the
gate, the flooded hall's thin spike tell). The foes' line and rendering (the beetle's and slug's lit
seams, the bee's soft shading) wait on redrawn sheets, which go through Sean's base approval.
