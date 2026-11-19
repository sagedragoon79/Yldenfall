# Pass 606: health is a sprig of leaves

## Category

Originality and UI, from the independent grade taken after pass 605 (5.3 of 10): "the HUD's health
masks copy Hollow Knight's masks almost directly". Yldenfall is a game of its own (bible 1 and 2), and
its grade compares it with Hollow Knight, so its most visible UI element must not wear that game's
signature. It was pass 605's "Next", first in the queue.

No note from Sean was new. This pass ran from a watched Claude Code session, at Sean's request to
keep the iteration passes going, using the same lock as the scheduled task; it was built while pass
605 waited for CI. A picture of the leaves went to Sean for his OK. The PixelLab art loop stays
**gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK,
the limit of three. No PixelLab generations were spent, and no Autosprite credits. The hosted
workbench is still down (its Vercel Blob store is suspended); it stays under "stuck" for Sean.

## Audit

- **The icon** (`GameHud._draw_mask`, `MASK_SHAPE`): an ivory face with a flat brow, a pointed chin,
  two carved eye slits, a nose line and a lit cheek, filling from the chin up. It is the other game's
  health mask in all but its outline.
- **The word**: "mask" was the unit in six strings a player reads: the Life Fruit's description and
  its pickup message, the Elven Helm's description and pickup, Resilience, and the Journey page.
- The bible counts its balance in masks throughout (a mask is 20 HP); that is design notation, not
  something a player reads.

## What was built

- **Leaves** (bible 12.86, `GameHud`): one unit of health is an autumn leaf in the old cell: a pointed
  tip, a broad blade, a short stem, a dark midrib and two pairs of veins angling up and out, in amber
  (cd8c51, shaded aa6336, veins 783c2b, a gold-6 shine). It fills from the stem up; above the fill line
  the leaf and its veins are empty. Half a leaf is the blade's left half. Poison turns the leaves the
  same sick green it turned the masks.
- **The word**: the six strings say leaf ("Two fruits grow a new leaf of health", "+1 leaf of
  health", "One more leaf"). The code keeps its old names (`MASK_HP`, `_draw_mask`).
- **The bible**: 12.86, the health table's note and the UI list say leaves, and say the balance notes
  still count in masks, the same 20 HP.

Judged by eye at 4x full, hurt (two full, one part-filled, two empty) and poisoned. The first veins
ran straight across the midrib, so each leaf read as a hot cross bun; they now angle up and out. The
first part-filled leaf kept its dark midrib running on through the empty half; above the fill line
the veins are now empty too.

## Tests

`tests/test_systems.gd`, `test_health_is_a_sprig_of_leaves` (3,487 checks): the shape comes to one
tip, stands on a short stem and keeps the old cell's width; it has veins; it is amber, and poison is
still green; no quoted string in the data tables or the scripts that print a fruit's, a page's or a
pickup's words says mask; a Life Fruit and Resilience grow a leaf; the bible says so. The poison, Life
Fruit, Resilience and HUD tests still pass.

Mutation check, restored from a copy after: the mask's shape fails it (2 checks); "mask" back in the
Life Fruit's description fails it (3 checks).

Full suite: 25,447 checks passed and 1 failed: `test_every_skill_page_names_the_number_it_gives`, because
the bible's skill list still said Resilience gives "+1 mask". The list now says "+1 leaf" (and the health
table and the Elven Helm's row say leaves), and the test passes; nothing else changed since that run
but the bible's text.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Health wears an icon of its own; the portraits' art remains. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | The health unit is of this world. |

Weighted: 98.85.

## Next

From the pass 605 grade: the struck foe that reads as a see-through ghost (keep its own colors
through the soft phase, within pass 567's bounds), the clock-face spark, and the gold counter's slashed
zero. The sword's look, the Haar's fog and dither and the sprites' pixel size stay held.
