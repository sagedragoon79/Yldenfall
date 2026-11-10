# Pass 532: the HUD's gold agrees with the shop's footer

## Category

A defect from the pass-529 independent grade, the first queue item an unattended pass could do: the
Hearthroot arms shop's footer said "Gold 5000" while the HUD beside it said 4968, and the town
backdrop behind the shop looked different from the room's. UI and menus.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first item
(rim light on figures and the rest of the lighting pass) stays parked for a watched session.

## Audit

- **The gold.** The footer prints `p.gold`. The HUD prints `_shown_gold`, a counter that rolls
  toward the purse (at least 40 gold a second, faster for a big gap). It began at 0, so every load
  counted the purse up from nothing for about a second and a half, and the HUD keeps running while a
  menu pauses the world (it sits under the Game node), so after a purchase it was still rolling down
  beside a footer that already showed the new sum. The capture opens the shop on frame 2 with
  `--gold=5000`, which is why the picture caught 4968: both causes at once.
- **The backdrop.** Shot again at the same spot with and without the shop open, the backdrop is the
  room's own in both (`hearthroot/market`: the warm grade, the ruined skyline, the light shafts and
  the foreground posts). The catalog's shop picture was older than passes 505 to 531, which changed
  that backdrop; the room pictures had been refreshed and the shop pictures had not. Nothing in the
  game draws a different backdrop for a shop. Refreshing the shop pictures settles it.

## What was built (design bible 12, the gold counter)

- `GameHud.shown_gold_after(shown, gold, delta, paused)`: an unseen counter (`shown` below 0, its
  new start) takes the purse as it is, a paused one shows the exact sum, and a running one rolls as
  before. Gold found or spent in play still rolls like an arcade score.
- The HUD draws no less than 0 in the one frame before it first sees the purse.

## By eye

`shots/shop-gold/pass532-before-after.png` (top before, bottom after) and `pass532-hud-2x.png`: the
HUD and the footer both say 5000, over the market's own backdrop.

## Tests

`tests/test_economy.gd`, **`test_the_huds_gold_agrees_with_the_shops_footer`**: the arms dealer
with the real controller. The counter starts on a 500-gold purse; 100 gold found in play rolls; Up
opens the shop and the HUD shows the whole 600 at once; Jump buys the Wayfarer's Sword and the footer
and the HUD both say 200; Dash leaves. Plus the three cases of `shown_gold_after` and the bible's
mention.

Mutations: dropping the paused snap fails 3 checks; starting the counter at 0 again fails 3.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97.5 | Unchanged; the HD hero and the guardian bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | The purse reads the same everywhere it is shown. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.875.

## Next

Pass 533: the art loop stays **gated** on Sean (three guardian bases wait). Next in the queue: the
noisy terrain fill and the square "missing pixel" blocks in the midground ruins (code-first, in the
tile and backdrop painters). Further VFX-tool trials (the slash smear, the dash afterimage, the
enemy death dissolve) follow. Pass 535 is due an independent grade.
