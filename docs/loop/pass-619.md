# Pass 619: a fire seal lights the stone round it

## Category

Art cohesion (environments, the Haar). The top unheld item of the queue, from the pass 615
grade (5.6 of 10): "the Haar's lava column is a saturated orange strip with a flat pattern and
no glow falloff onto what is round it (Haar hit)".

No note from Sean was new. The PixelLab art loop stays **gated** on Sean: three guardian bases
(Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab
generations were spent, and no Autosprite credits. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

The "lava column" is the Marsh Road's fire seal (`FireSeal`, legend `Z`), worked on in passes
544, 549 and 552. Looked at in the fight capture at 3x:

- **The glow is in the air only.** The seal casts a pool (RoomLight) and a dithered halo
  (12.40). Both tint the air, and the Haar's fog (0.88) lies over them. The floor at the
  seal's foot and the arch over it were as dark as stone across the room.
- **The inside is one heat.** From three pixels in, the fire burned at `CORE_HEAT` with licks
  over it, so a column one tile wide was a sheet of gold blotches edged in orange: lava.
- **Nothing leaves it.** No spark or ember, so the column sat in the picture like a strip.

## What was built

- **The stone's lip is lit** (`FireSeal.lit_cells`, `lit`, `LIT_REACH` 44, `LIT_DEPTH`,
  `LIT_PEAK`, `LIT_FLUSH`). A face of solid ground that looks at a seal takes a hot edge, gold
  on the lip and red behind it, up to five pixels into the stone, stepping down four times
  along the face. A face that looks away is dark. Drawn on the halo's node: added light that
  breathes with the halo and goes out with the douse. A tile lights nothing past a joined
  side, so a column never lights a pixel twice.
- **A gold spine and red flanks** (`rim_cool`, `RIM_COOL`, `RIM`). The heat dips a few pixels
  in from an open side and recovers by seven pixels in. The ragged edge itself is untouched,
  so the seal's outline and its earlier tests hold.
- **Embers** (`FireSeal.embers`). Up to two single pixels off each open side of a tile,
  climbing, drifting out and cooling down the heat ramp over 14 frames.
- Bible 12.96 (new), and 4.5's line on fire seals.

Looked at in `haar/marsh_road` at 1x and 3x beside the picture from before: the column has a
round body, the floor's lip glows gold at its foot and fades along the boards, the arch's
underside takes a warm edge, and embers hang beside it. In `evercrown/proving_scar` the wall
beside the wide seal takes the lip and nothing else changes.

Not done: the halo's dither and the fog over it are the Haar's held item. The lit lip is on
tiles only; decor, foes and the hero beside the fire take no warm edge.

A first try cooled only the core's heat. The test showed the flanks were still as hot as the
spine (the edge's own heat formula kept them hot), so the cooling moved onto the whole flame.

## Tests

`tests/test_fire_seal_art.gd`, four new: `test_fire_seal_lights_the_stone_round_it`,
`test_fire_seal_lights_its_room_floor`, `test_fire_seal_gives_off_embers`,
`test_fire_seal_has_a_gold_spine_and_red_flanks`. The twelve older seal tests pass unchanged.

Mutation check: with `LIT_FLUSH` at 800 (no facing rule), the first fails; with `lit()`
returning nothing in a room, the second fails; with embers ignoring joined sides, the third
fails; with `RIM_COOL` at 0, the fourth fails (spine 3.95 against flanks 3.91, where the
shipped fire gives 3.52 against 2.79). Restored, all pass.

Full suite: see the pull request.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | A seal lights its stone; the Haar's fog and dither stay held. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The pass 615 grade's remaining items: the water's hard top line (aqueduct, flooded hall), the
hit's missing flash in the fight captures, and the Spires' ridge as more than one value. The
next independent grade is due after pass 620. The Haar's fog and dither, the sprites' pixel
size, the hero's rim light and the sword's look stay held.
