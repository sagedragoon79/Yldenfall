# Pass 628: a ceiling is a few large shapes, not a row of teeth

## Category

Art cohesion (environments). The top item of the queue, the last of the first defect of the
pass 625 grade: "terrain is a uniform fill cut into 45-degree stairs, with no top-lip
variation, no shadowed underside and no large form". Pass 626 did the underside and pass 627
the top lip. This pass does the large form.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits.

## Audit

Looked at the storm ledge, the drowned aqueduct and the canopy bridge at 1x. The haunches
(12.78) made every step a diagonal, so what reads as a stair is the layout: passes 587 to 590
made these ceilings ragged with many small forms of one size. Counted how often each room's
underside changes direction, leaving out walls and piers:

| Room | Turns | Columns |
| --- | --- | --- |
| Storm Ledge | 9 | 38 |
| Flooded Hall | 13 | 58 |
| Canopy Bridge | 7 | 38 |
| Every other room | 5 or fewer in 38, 5 in 78 | |

The storm ledge's overhang was four notches about five tiles wide, side by side.

## What was built

Design bible 12.104, and a rule of thumb in `levels/README.md`.

- **The rule.** A ceiling's underside changes direction once in seven columns at most, and one
  form is plainly the largest.
- **Storm Ledge.** One great vault, open to the storm over seven columns and twelve wide at
  row 4, with a wedge and prong hanging west of it, a shorter spur east of it and a small
  peaked pocket past that. 5 turns, from 9.
- **Canopy Bridge.** One great notch eight columns wide, then one of three and one of two, with
  a blunt knot and a tapered one between them. 5 turns, from 7. The wind's rectangle is as it
  was.
- **Flooded Hall.** The fallen vault's hole is one opening whose edge comes down once, to the
  hanging voussoir. 9 turns, from 13. The bays, pillars and heap are as they were.

Only ceilings changed, and only upward or within the top rows: no floor, door, pickup or foe
moved.

Thrown out or fixed on the way:

- The first west mass on the storm ledge tapered on both sides, so its tip stood only one row
  below its shoulder and was no spur (12.76 asks for two). Its east shoulder is now one
  haunch and the prong hangs two rows.
- The first count took wall columns as ceiling and gave every room two turns it does not
  have. Columns of ground that come down past the middle of the room are left out.
- A limit of one turn in ten columns would have flattened the flooded hall's niches and bays,
  which are architecture, not teeth. One in seven keeps them.

## Checked by eye

The three rooms at 1x, before and after. The storm ledge changed most: the overhang reads as
one arch with broken ends in place of a saw. The canopy bridge's change is smaller, since its
canopy is only three rows deep over the wind. In the flooded hall the hole reads as one
opening. Not zoomed: nothing was redrawn, only laid out.

## Tests

`tests/test_ceiling_forms.gd` (five tests, 149 checks). Mutation-checked by putting back the
three rooms as they were:

| Test | Result with the old rooms |
| --- | --- |
| `test_no_ceiling_is_a_row_of_teeth` | fails for the three rooms (7, 9 and 13 turns) |
| `test_the_storm_ledge_is_one_vault_with_two_masses` | fails all four checks |
| `test_the_canopy_has_one_great_notch` | fails two checks (four notches, the widest five) |
| `test_the_fallen_vault_has_one_broken_edge` | fails three checks (a comb of four steps) |

The rooms' older tests still pass (12.74, 12.76, 12.77, 12.78: six heights, the crown, two
spurs, the knots, the voussoir, no square inner corner, 25 haunches or more).

Full suite: SUITE_LINE

## Not done

- The slopes are still 45 degrees. A second pitch (a shallow and a steep haunch) would let a
  vault curve; it needs tiles, collision, shade and the reach checker.
- The drowned aqueduct's piers still step down under water, where a haunch cannot go.
- The rule counts turns, not size: a flat ceiling passes it.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Three ceilings reshaped; no route changed. |
| Art cohesion | 15 | 98 | Ceilings read as large forms; the single pitch, the fog and the dither stay. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The rest of the pass 625 grade's items, in its order: the plank on two posts (vary the board,
the posts and the run's outline by zone, or carry runs on ledges, boughs or chains); chests,
signs and pickups against the scenery; the rain's splash and wet stone and the lightning's
light; the one-value midground bands. Then a second ceiling pitch. The next independent grade
is due after pass 630. The Haar's fog and dither, the sprites' pixel size, the hero's rim
light and the sword's look stay held.
