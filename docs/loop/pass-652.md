# Pass 652: a hung run is a deck

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 650 (5.2/10). Pass 651 framed the foot of the view; the next item in its order is
"hanging and chain platforms read as debug geometry, thin and the backdrop's value"
(`tower/foot`, `evercrown/veins`). The PixelLab art loop stays gated on Sean (three guardian bases
wait for his OK); no PixelLab generations or Autosprite credits were spent. README's playtest link
already points at https://github.com/sagedragoon79/Yldenfall.

## Audit

Screenshots of `tower/foot` and `evercrown/veins` at rest. A plank run with nothing under it within
`POST_MAX` hangs on two hangers (12.30). Its board is 3 world px with the plank tile's light
trestle under it; the Tower's chains were 3 px wide and the ropes and sinew 1.5 px, so at 1x each
hung run was a line on two hairs. Against the Tower's dark stone and the Evercrown's violet the
deck was the backdrop's value; only the board's lit top edge told it apart.

## What changed

Design bible 12.128, `scripts/world/plank_supports.gd`.

- **A girder under the board.** Every run with a hanger is now a deck as deep as its cell
  (`hung_decks`, `deck_parts`): a dark web from under the board to a bottom chord at the cell's
  foot, lit on top and dark below, a bolt under each trestle foot, end plates, and a soft shadow
  on the air under it. Runs held by posts, frames or wall braces are unchanged.
- **Heavier hangers.** Chain links 4 px wide and 4 px long with a dark eye; rope and sinew 2.5 px;
  a 6 px cleat. Each hanger runs past the board and takes the chord in a stirrup.
- **Grown shelves swell.** The Evercrown's `web` look grows a rounded underside instead, deepest at
  the middle, lit along its top third and dark below, with a pore here and there.

The first grown underside was one flat mid tone and read as a bright purple slab; it now faces
down, into shadow. Judged by eye at 1x and 2x in `tower/foot`, `evercrown/veins`,
`spires/sky_steps` and `haar/marsh_road`.

## Tests

New in `tests/test_plank_supports.gd`:

- `test_plank_a_hung_run_is_a_deck`: a hung run gives one deck over its cells; in four zones its
  girder runs from under the board to the cell's foot, is solid at every column, has a dark web
  across the run, eight bolts or more and a soft shadow beneath.
- `test_plank_a_grown_shelf_swells_underneath`: the Evercrown's underside is deepest at the middle
  and more of it is dark than lit.
- `test_plank_a_held_run_is_no_deck_and_hangers_are_heavy`: a run on posts gets no girder; chains
  are 4 px or more and ropes 2.5 px or more.
- `test_plank_a_room_takes_its_decks_chord_in_stirrups`: a Tower room builds the deck and each
  hanger takes the chord at the cell's foot.

Mutation check: with `hung_decks` returning no decks, `test_plank_a_hung_run_is_a_deck` fails with "the hung run is one deck: []" and `test_plank_a_room_takes_its_decks_chord_in_stirrups` with "the room builds one deck". `python tools/art/test_tilegen.py` is untouched by this pass (no art regenerated).

## Full suite

One run (`TEST_TIMEOUT=7200`): 37,223 checks passed, 1 failed, a frame-time budget in a room the
decks do not touch per frame (`test_spires_rain_stays_cheap`: the Carillon's rain averaged 8.40 ms
in the full run). Run alone it passed every check (6.82 ms). The decks are drawn once per room
load in the same `PlankSupports` layer, so they cost no frame time. The tests for this pass (`--filter=test_plank`): 1,063 checks passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Hung runs are built decks with weight, not lines on hairs. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (drawn once per room load, as before). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 650 grade in its order: no value split between the play plane and the backdrop
(Evercrown veins, Tower foot, Spires fight); the sword's flat bar (held), a small spark, the
damage numbers; the Heartwood gate tree's flat band; repeated skyline and ruin cut-outs; flat
ceiling bands; the minimap's empty frame and plain health and mana; stamped spike rows. The
floor's level top line (12.127) waits behind them. Held as before: the Haar's fog, the hero's
size; foes in mixed styles stays with the art loop.
