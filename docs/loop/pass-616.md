# Pass 616: a ware is weighed against what you wear

## Category

Art cohesion (UI and menus), from the independent grade taken after pass 610 (5.6 of 10):
"the shop panel is plain: dead area round one small icon, a crude portrait, no comparison
with equipped gear". The pass 615 grade said "a large dead area" again. It was the top of the
queue after passes 611 to 615 took the items before it.

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

Pass 605 gave a shop of few wares a counter: the chosen ware's icon at three times its size
on a lit shelf, in the room between the rows and the description. That room is 324 px wide
and the icon is 42, so two thirds of it stayed empty either side. And nothing on the panel
said what you have: to learn whether the Wayfarer's Sword beats the blade in your hand, you
read "Cuts 11, heavy 19, reach +8" and remembered your own numbers from the Equipment page.

## What was built

- **The ware steps aside** (`ListMenu.counter_center`, `compare_rect`, `compare_layout`,
  `_draw_compare`): when the chosen row carries a `compare`, its icon stands a fifth of the
  way along the counter and a table fills the counter from two fifths on.
- **Yours, an arrow, the ware's, a mark**: "Cut 8 → 11" with a green triangle pointing up
  when the ware is better and a red one pointing down when it is worse. A caption heads the
  table: "Yours: Short Sword", "Nothing worn there." or "You wear this.".
- **What is weighed** (`Menus.compare`, `COMPARE_STATS`, `worn_against`): every kind of gear
  against what you wear in its place (blades with their own tempers in); a temper against
  your blade as it is; keys, Barkbalms, tonics, the Amber Draught and Hawthorn Spikes against
  how many you carry. A chart, a scroll, a dye and a Life Fruit have nothing to weigh and keep
  the middle of the counter.
- **A cost is a cost**: the Dwarvish Broad Sword's slower swing is marked worse beside its
  better cuts, and its second hand is told with no mark.
- Bible 12.93 (new).

Two layouts were looked at in the game. At 12 px a line, the Broad Sword's table (a caption
and six numbers) lost "Two hands" and "Sweep" on the arms shop's four-row counter. At 11 px,
with the costs moved before the sweep, it keeps "Swing time" and "Two hands" and drops only
"Sweep", which its description names.

Not done: the keepers' portraits ("crude" in both grades) are generated art, an art-loop
item. The description under the counter still repeats a blade's numbers in words, and the
Broad Sword's runs to three lines there, as before this pass. Long shelves (six wares or more)
have no counter, so no table. The Equipment page could take the same table later. For Sean to
judge in play: whether the table's values sit too far from their labels on a short
comparison (the Tanned Jerkin's one line).

## Tests

`tests/test_shop_pictures.gd`, one new: `test_a_ware_is_weighed_against_what_you_wear`. It
holds the numbers against `data/items.json` (a blade against the one in hand, armor on a bare
back, a Buckler against a worn Kite Shield, the Broad Sword's costs, a worn thing, a temper,
a tempered blade, belt things and keys, nothing for a chart or a scroll); that every ware of
every shop that can be weighed is, and that every caption and line fits the table; and the
layout on the counter (the ware left of its table, each line on the counter, the columns in
order, a chart alone in the middle).

Mutation check: with the swing's sign dropped, the "slower swing is marked worse" check
fails; with the icon back in the middle, "the ware stands left of its table" fails; with a
13 px line, "the Broad Sword's costs are among the lines that fit" fails; with no `compare`
on a shop's rows, the test fails on the first line that reads one. Restored, it passes.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The shop's counter is filled and useful; the portraits remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | A shop now says what a ware changes. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 610 grade's last unheld item: the plaza skyline's gridded windows (with the pass 615
grade's "far skylines are flat one-value silhouettes"). Then the tiers that step by the tile
(seen in pass 614), and the pass 615 grade's new items: the Haar's lava column, the water's
hard top line, the hit's missing flash in the fight captures. The next independent grade is
due after pass 620. The Haar's fog and dither, the sprites' pixel size, the hero's rim light
and the sword's look stay held.
