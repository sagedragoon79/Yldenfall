# Pass 554: the shop shows what it sells

## Category

From the independent grade taken after pass 550 (5.3/10), as pass 553's "Next" named it: "the shop
is a plain box with no item icons or portrait". The pass 540 grade said the same ("the shop has no
item icons or merchant bust and a dead middle"). UI and menus in the grade (5.5).

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

- Shot `hearthroot_arms`: a title, a greeting, three names with prices, and nothing drawn. No item
  in the game had a picture outside the world (a find floats as its pickup; a good bought in a shop
  had none at all), and no person had a portrait.
- `ListMenu` draws at the window's resolution, as the HUD does, so a picture can be drawn at 2x
  density (one texel is half a UI pixel) and sit beside the 1x font the way the HUD's masks do.
- The shop's menu opens over its keeper, so the one person you are talking to is the one you can't
  see. The bible's list (13.3) had dropped the dialogue box's portrait frame because people stand
  beside it; that reason does not hold for a shop.
- The cast's painter (`tools/art/pixelrig.py`: palette materials, top-left light, one outline) is
  the right tool: an icon drawn with it belongs to the same family as the people and foes.

## What was built

- **`tools/art/icongen.py`**: an icon for each of the 47 items (28x28 texels, shown at 14 UI
  pixels) and a portrait for each of the 58 people with a `look` (80x80 texels, shown at 40).
  Blades, coats, shields, the helm, keys, the fruit, the dew, the balm and the draught each have a
  painter; dyes, charts, scrolls and tempers share one that takes the colour, the zone, the spell
  or the level. A portrait reads the same fields as the person's sprite. An item with no painter
  stops the script.
- **`UiArt`** (`scripts/ui/ui_art.gd`): loads both sheets and draws from them.
- **`ListMenu`**: a row may name an `icon`; when any row has one, the labels move right 18 px. A
  menu may name a `portrait`: it is framed in the top right corner, the greeting wraps before it,
  and the rows start under it. Both are cleared when another menu opens.
- **`Menus`**: each shelf row names its item; `Menus.keeper` finds who keeps a shop and
  `open_shop` frames them.
- Design bible 12.44 (new), 13.3 and the icon list; CLAUDE.md's commands; the workbench catalogue's
  Goods lede.

## Judged by eye

Looked at the contact sheet at 4x and at `hearthroot_arms`, `hearthroot_items` and
`hearthroot_dyes` in the game at 1x. Retakes before keeping it: the Thorn Key's thorns were stray
red lines and are now three spikes off the bow; a dwarf's beard began under the eye and read as a
mask, so it now starts under the nose with a moustache over it; an elf's ear was hidden by the
hair and is drawn over it. Icons are small (28 screen pixels at 720p) and read by shape and
colour; the 14 dyes are told apart by colour alone, as they should be.

Not done: the panel's lower middle is still empty in a shop with three rows; the Equipment and
Inventory pages and the dialogue box do not use the pictures yet.

## Tests

`test_the_shop_shows_what_it_sells` in `tests/test_shop_pictures.gd` (344 checks): every item has
an icon in its own 2x cell with at least 120 solid texels and four colours; ten look-alike pairs
differ; every shop has a keeper whose portrait is a 2x picture; two keepers are two faces; every
shelf row of every shop names its item's icon; the arms shop opens with its keeper framed inside
the panel, the greeting wrapping before the frame and each icon inside its row; a menu opened
after it has neither picture and its words run the panel's width.

Mutation check: rows without `icon` fail the shelf checks (67); `open_shop` not naming the keeper,
and `open` not clearing the portrait, each fail two; the greeting running under the portrait fails
one; an icon one row low fails three; `keeper` returning anyone fails 22.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms, the empty mid-ground and the Proving Scar's framing remain. |
| Art cohesion | 15 | 98 | Shop goods and keepers are drawn on the cast's palette. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | The shop shows its goods and its keeper. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; two small sheets, loaded once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: SUITE_TOTAL checks passed, 0 failed.

## Next

Pass 555: the art loop stays **gated** on Sean. Pass 555 is a fifth pass, so it takes the
independent grade. From the pass 550 grade, still open: the Proving Scar's framing and the loud
repeating frame tiles (Tower and Vorrhallow stone, Heartwood and Boughs dirt). From the pass 545
grade: the uniform rain over the Spires. The same pictures on the Equipment and Inventory pages
are a follow-on to this pass. Rim light on figures and the Boughs painterly clash stay parked for a
watched session.
