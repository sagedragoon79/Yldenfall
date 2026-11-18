# Pass 594: a menu names its keys

## Category

UI and menus, from the independent grade taken after pass 590 (5.3 of 10). Its eighth defect: "The
shop UI is plain: crude portrait, generic panel, odd 'Jump: choose / Dash: leave' labels." Passes
591 to 593 closed the grade's ceiling, impact and thorn items, and pass 593 named this one next.

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked for
a watched session; the second is the pass 590 grade, and this is its next unanswered defect. The
PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned
Warden) wait for his OK, the limit of three. No PixelLab generations were spent, and no Autosprite
credits. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. `README.md`'s playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

Looked at the Hearthroot arms shop picture at 1x and 4x. Every `ListMenu` ended in one fixed line,
"Jump: choose   Dash: leave", dim, in the panel's bottom right. Three faults, the grade's "odd":

- It named the hero's moves (Jump, Dash), not the keys. A player in a shop thinks "which key buys",
  and the line made them translate "Jump" into Space or A.
- "Choose" is not what a shop does, and "leave" was said by the pause menu, the skill tree and the
  lift too, where it means resume, back or nothing.
- It was the same words on read-only pages (Journey, Inventory), where confirming does nothing.

## What was built

`ListMenu` (bible 12.79):

- **Key caps.** The line is now a row of prompts, each a key cap and a verb. A cap shows the key
  bound to the action (`Controls.key_name`), or its pad button while a pad is plugged in
  (`Controls.button_name`), so a rebound key shows at once. Left and Right are drawn as `<` and `>`.
  The cap is a one-pixel frame (`8a7f9e`) around a dark face (`2a2440`, the portrait's backing) with a
  drop shadow, two rows clear above a capital and below it, where a "p" descends.
- **Verbs.** `confirm_verb` and `back_verb`, reset on each open: a shop says Buy and Leave, a
  Ringreader Leave, the skill tree Learn, the Inner Rings Begin, the Grain Road Travel, the lift Ride,
  Equipment Equip and the pause menu Resume. The defaults are Choose, and Close (Back in a sub menu).
  Journey and Inventory name no confirm. Options says `< / >` Change. The Controls page, listening
  for a key, says "Press a key or button" and names the key that cancels.

Judged by eye in all 21 shop pictures (this PC has a pad plugged in, so they read "A Buy  B Leave").
The first caps were 10 px tall and clipped the top of their letters; they are 13 px now.

The title screen's save picker (`SlotPicker`) keeps its own line of words; it is not a `ListMenu`.

## Tests

`tests/test_shop_pictures.gd`, `test_a_menu_names_its_keys_and_what_they_do`: a cap shows the bound
key or button; the shop's prompts are exactly Buy and Leave on the jump and dash caps; no prompt
names Jump or Dash or carries a colon; every prompt has a key; the row fits right of the gold; a
cap's frame clears a capital's top and a "p"'s tail and sits inside the panel; a plain menu chooses
and closes, a sub menu goes back, a read-only page names no confirm; the skill tree learns, the
pause menu resumes, Options changes with arrows, and the Controls page names the key that cancels.

Mutation check, each restored from a copy after: the shop saying Choose fails it (1 check); a cap
only as tall as the ascent fails it (1 check); a cap that shows the action's name fails it (3 checks).

Full suite: 19,310 checks passed, 0 failed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The shop's labels are key caps; its portrait and plain panel remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Every menu names its real keys and what they do. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The independent grade is due after pass 595 (every fifth pass). Before it, from the queue: the
repeated chest and sign (pass 585's set-dressing item), then the grid item's leftovers. The shop's
plain panel and crude portrait stay with the pass 584 shop item. The sword's look and the Haar's fog
stay held.
