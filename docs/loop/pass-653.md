# Pass 653: the play plane stands off the backdrop

Date: 2026-11-24. No new notes from Sean. From the queue, first item: the independent grade of
pass 650 (5.2/10). Passes 651 and 652 took its foreground and hung platforms; the next item in its
order is "no value split between the play plane and the backdrop" (`evercrown/veins`, `tower/foot`,
the Spires fight). The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK);
no PixelLab generations or Autosprite credits were spent. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

Screenshots of `tower/foot` and `evercrown/veins` at rest. In the Tower the ridge layer's cliffs
and the mid layer's scaffold stand at a mid grey behind the hung decks, the decks' bodies at about
the same value; in the Evercrown the decks' violet and the backdrop's wine are one purple. In both,
an edge is told from the air behind it only by its lit top line. `EdgeShade`, `SoffitShade` and
`DeepShade` all shade the solid's own side of its edge; nothing touched the air's side.

## What changed

Design bible 12.129, `scripts/world/air_shade.gd` (new), `scripts/world/room.gd`.

- **The air darkens toward every edge.** `AirShade` darkens the air next to every solid edge,
  plank board and hung deck to 0.6 of a near-black at the edge, falling off with the key light from
  the top left: 18 px under an underside, 10 px beside a wall, 4 px over a walking surface, so the
  lit top stays the brightest thing at an edge. A board casts from its top 5 px, a hung deck from
  its whole cell. Slopes and the room's outside cast none.
- **Clean steps.** Four steps in 2-pixel blocks. The first try used `DeepShade`'s ordered dither;
  in the Boughs' pale day air the checker read as grime, so the steps are clean.
- **Cheap.** One texture per room, painted once at load from a cached pattern per neighbourhood of
  cells, drawn at `z_index` -3 behind the tiles, set pieces, light shafts and actors.

The first version cast evenly on every side and read as a dark glow round each deck; the
directional reach made it read as a cast shadow. Judged by eye at 1x and 2x in `tower/foot`,
`evercrown/veins`, `boughs/canopy_bridge`, `spires/sky_steps` and `hearthroot/plaza`.

## Tests

New `tests/test_air_shade.gd`:

- `test_air_darkens_at_an_edge_and_most_below`: under a ledge the air is at its darkest and the
  darkness ends past 18 px; over it only a thin line; beside its end for 10 px; the reaches are in
  that order; nothing is painted over the solid.
- `test_air_shade_falls_off_in_clean_steps`: the darkness never rises away from an edge, steps
  through four levels to none, and one depth is one step along the run (no checker).
- `test_air_a_board_casts_from_its_top_only`: a board is not painted and casts from its foot; a
  hung deck's cell is its own and casts from the cell's foot.
- `test_air_open_rooms_and_the_outside_cast_nothing`.
- `test_air_a_room_builds_its_shade_behind_the_tiles`: a Tower room builds the shade behind its
  tiles, under its hung deck, a block and beside its wall.

Mutation check: with the underside measured against `UP_REACH`,
`test_air_darkens_at_an_edge_and_most_below` and `test_air_shade_falls_off_in_clean_steps` fail
(3 checks); with no pattern written into the room's image, all four painting tests fail (10 checks).

## Full suite

Run on a busy PC (a Unity editor, audio and launcher apps were running). One full run
(`TEST_TIMEOUT=7200`): 37,266 checks passed, 4 failed, all frame-time or load-time budgets:
the Carillon's rain (13.65 ms), every room's load behind the fade (eight rooms over 500 ms) and
settled frame (`evercrown/proving_scar` 9.16 ms), and the spoils soak's frame budget. A second full
run was cut off by a termination signal after an hour, with only the same timing checks failed.

Those checks were then run alone twice, with the shade and with `AirShade.setup` switched off
(the code of main), back to back. Both fail all three under the same load: with the shade off, the
rain averaged 10.63 ms, six rooms loaded over 500 ms (`gym/gym` 804 ms, `proving_scar` 775 ms)
and five settled rooms ran over 8 ms. Timed inside `Room`, the shade costs at most 18 ms of a load
(`gym/gym`, 170 x 46 tiles) and is one draw call a frame. The tests for this pass
(`--filter=test_air_`): 54 checks passed.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Each solid mass stands on a cast shadow of its own; the backdrop recedes behind it. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (painted once per room load). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 650 grade in its order (the next independent grade is due at pass 655): the sword's flat bar (held), a small spark, the damage numbers; the Heartwood gate
tree's flat band; repeated skyline and ruin cut-outs; flat ceiling bands; the minimap's empty frame
and plain health and mana; stamped spike rows. The floor's level top line (12.127) waits behind
them. Held as before: the Haar's fog, the hero's size; foes in mixed styles stays with the art loop.
