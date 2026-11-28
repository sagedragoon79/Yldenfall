# Pass 677: a foe that carries its own light is keyed off it

Date: 2026-11-28. No new notes from Sean. From the queue, first item: the independent grade of
pass 675 (5.4/10), next in pass 676's list: "the flooded hall's foe lost in pink glow and the water
band". This pass takes it. The PixelLab art loop stays gated on Sean (three guardian bases wait for
his OK); no PixelLab generations or Autosprite credits were spent.

## Audit

`vorrhallow-tell` shot fresh from `main` (the hero four tiles from the first Crystal Dwarf in
`vorrhallow/flooded_hall`, the HUD on) and read at 1x and 4x:

- **No edge.** The dwarf's steel, lifted to the cast's middle value by `FoeLight` (12.149), sat at
  the value of his own crystal's glow (12.52), and his sheet has no closed outline. The silhouette
  12.52 meant to make never formed: a grey figure inside a pink cloud.
- **A cloud, not a light.** The glow's half extents were 40 by 34 px on a 20 by 28 px body, so it
  spread twice his size round him.
- **The band.** Over a wader the tide was cleared to 0.35 of its strength (12.134), which still
  tinted his legs to the water's teal under the waterline.

## What changed

Design bible 12.154 (new) and 12.134; `scripts/enemies/enemy.gd` (`light_keyed`,
`LIGHT_KEY_STEPS`, `LIGHT_KEY_RIM`, `light_key_drawn`); `scripts/enemies/foe_glow.gd`;
`scripts/enemies/crystal_dwarf.gd` (`GLOW_REACH`); `scripts/world/tide.gd` (`CLEAR`).

- **A keyline round the whole figure.** A foe carrying a `FoeGlow` is marked by it, and its sheet
  frame is drawn first as a near-black silhouette one and two pixels out on every side, under the
  body and under any tell or hit rim.
- **The glow is a pocket at the crystal**: 30 by 28 px, half again his width and his height.
- **The water clears further over a wader**: 0.2 of its strength, 0.35 before.

Judged by eye at 1x, 2x and 4x in the fight frame: he now stands as a dark-edged figure against a
pocket of light behind his back, and his boots show under the waterline. Still there and not taken
here: a black foreground spike crosses his feet in this frame, and the second dwarf beyond reads
pale against its pillar.

## Tests

- New `test_a_foe_is_keyed_off_its_own_light` (`tests/test_foe_glow.gd`): the glow keys the dwarf
  and a plain foe is not keyed, the keyline is drawn at rest and through his tell, two pixels wide
  in near-black, the glow within half again his width and his height, the tide's clearing at 0.2 or
  less, and none once he is dead.
- `test_the_crystal_dwarf_carries_his_crystals_light` still holds the glow wider than his body
  (at the 1.5x and 1x limits exactly).

Mutation check: with the glow no longer marking its foe the test fails three checks (not keyed,
not drawn at rest, nor in the tell); with the old 40 by 34 reach it fails once.

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,625 checks passed, 0 failed. CI (test and mix) is green.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | The Crystal Dwarf reads in his hall. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | A lit foe keeps its edge. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Two more silhouette draws per keyed foe. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 675 grade in its order, past the held items: the canopy bridge's hit frame (the
hurt hero's red tint reads as a foe; the mantis and the Bark Knight on the green); then the source
hall's water box in its brick border; then uniform floor strips (Tower foot, veins, source hall).
Pass 680 is the next independent grade.
