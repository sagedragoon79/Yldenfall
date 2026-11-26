# Pass 667: the Crystal Dwarf's tell shows where the spikes come

Date: 2026-11-26. No new notes from Sean. From the queue, first item: the independent grade of
pass 665 (5.5/10). Past its held items, its first named defect is "fights that don't read": the
foe and its spark lost on the Heartwood gate, hero and beetle bodies merged on a hit, and the
flooded hall's tell that "shows no attack". This pass takes the third. The PixelLab art loop stays
gated on Sean (three guardian bases wait for his OK); no PixelLab generations or Autosprite
credits were spent.

## Audit

- **The flooded hall's tell frame** (`vorrhallow-tell`, the Crystal Dwarf in `vorrhallow/flooded_hall`),
  cropped at 4x: the windup raises the crystal fist to his face, and the tell's glint and the fist's
  soft disc sit on his head. He stands in the tide, so his legs are under it. At 1x the frame shows a
  dwarf standing still with a spark on him; nothing says the attack is a chain of spikes along the
  floor toward the hero, or where it will land.
- **The two hit frames** (`spires-hit`, `boughs-hit`) at 3x: the hero and the foe touch because the
  frame is taken one frame after the blade lands, through the hit-stop. Both already recoil apart
  (`slash_recoil`, the foe's knockback), so that part of the item is the moment of the capture more
  than the game. It stays in the queue with the Heartwood gate.

## What changed

Design bible 12.144 (new), and the Crystal Dwarf's entry in section 7; `scripts/enemies/crystal_dwarf.gd`.

- **A lit lane through the windup:** a jagged crack of crystal light with a white-hot core runs along
  the floor from his toes, the way he faces, over the first 0.4 of the windup, under a low glow in two
  clean steps, with a hot running tip.
- **A crystal tip at every spike's spot,** faint from the first frame and full once the crack reaches
  it. The spots are the eruption's own (`spike_spots`, which `_erupt` now reads too), so the lane stops
  at a wall or a ledge where the chain does and the spikes rise where the tips stood.
- **Drawn over the tide** on its own layer (z 2): the first take drew it with the dwarf, and the tide
  (z 1) hid it.

The windup's length (0.6 s) and the fist's glow are unchanged. Judged by eye at 1x and 3x in the
Flooded Hall, before and after; a second take brightened the first (a 1 px line and 5 px posts were
lost on the floor at 1x).

## Tests

- New `test_the_crystal_dwarfs_tell_lights_the_spikes_lane` (`tests/test_enemies.gd`): nothing lit
  walking; the layer over the tide and under a struck foe; lit on the windup's first frame with a tip
  at every spike spot, the far ones faint; the crack starting at his toes and running out to reach every
  tip before he strikes; out when the fist falls; the spikes rising where the tips stood; and a wall
  cutting the lane short.

Mutation check: with the lane's layer at z 0, and with nothing ever lit, the test fails.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,329 checks passed, 4 failed, all timing budgets:
`test_spires_rain_stays_cheap` (8.11 ms), `test_every_room_loads_and_settles_inside_the_budget`
(six rooms over 500 ms to load and six over 8 ms a frame) and `test_every_foes_spoils_rest_in_its_room`
(its frame budget in `proving_scar` and `sky_steps`). Rerun alone, the rain and spoils tests passed;
the room budget failed only on load time in `evercrown/proving_scar` (584 ms) and `gym/gym` (591 ms),
neither with a Crystal Dwarf, as in passes 665 and 666. The PC was running Unity, Chrome and Wave Link.
CI (test and mix) is the clean run.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Crystal Dwarf's tell shows its attack and where it lands. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | A few rects a winding-up dwarf. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 665 grade in its order, past the held items: the rest of fights that don't read (the
foe and its spark lost on the Heartwood gate; hero and beetle bodies touching in the hit frame); then
the black foreground blobs at the foot of the frame.
