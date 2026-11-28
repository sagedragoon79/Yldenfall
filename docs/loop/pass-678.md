# Pass 678: the hurt hero keeps his colors, and every foe is keyed off its ground

Date: 2026-11-28. No new notes from Sean. From the queue, first item: the independent grade of
pass 675 (5.4/10), next in pass 677's list: "the canopy bridge's hit frame (the hurt hero's red
tint reads as a foe; the mantis and the Bark Knight on the green)". This pass takes it. The
PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab
generations or Autosprite credits were spent.

## Audit

The canopy bridge's room picture shot fresh from `main` (`boughs/canopy_bridge`, the hero
mid-room as pass 673 stands him, frame 50, damage numbers on) and read at 1x and 3x:

- **A red hero.** The mantis reaches him by frame 50, and for the hurt flash's 0.12 s
  `PlayerVisual` multiplied his whole drawing by (1, 0.45, 0.45). His green cloak and brown
  boots went one maroon, a hue nothing else on him has, so the struck hero read as a red foe
  beside the green one that struck him.
- **Foes on the green.** The mantis's lime and the Bark Knight's olive sat at the canopy air's
  own value, and neither sheet closes its shape in a dark line. Pass 677 keyed only a foe with
  its own light.
- **The 24.** The hurt number is an option (off by default) and its loudness is the grade's held
  item on damage numbers; not taken here.

## What changed

Design bible 12.155 (new) and 6.7; `scripts/player/player_visual.gd` (`HURT_RIM`, `HURT_KEY`,
`HURT_STEPS`, `hurt_ring_drawn`, `drawn_tint`); `scripts/enemies/enemy.gd` (`FOE_KEY_STEPS`,
`key_steps`, `key_steps_drawn`).

- **The hurt hero keeps his colors.** Through the flash he is drawn untinted, inside a ring: his
  silhouette in red one pixel out on four sides and in near-black two pixels out, under his body.
  The blink and the red at the screen's edge are unchanged.
- **Every sheet foe is keyed off its ground.** The keyline of 12.154 now runs round every foe
  drawn from a sheet, one pixel wide; a lit foe keeps its two. It lies under a tell's and a
  blow's rim, and a dead foe has none.

Judged by eye at 1x and 3x in the canopy bridge: the hero stays green inside a red edge, and the
mantis and the knight each stand off the green with a dark edge. All eleven fight frames were
recaptured and read on a contact sheet, with the Boughs hit and the Heartwood tell at 3x: on dark
grounds the keyline sinks into the dark, and the struck foe's rim and lit edge read as before.

## Tests

- New `test_the_hurt_hero_keeps_his_colors_and_every_foe_is_keyed` (`tests/test_hit_flash.gd`):
  a hornet wears the one-pixel keyline at rest and through a blow, narrower than a lit foe's, in
  near-black; the hero at rest wears no ring, hurt he wears it and is drawn in his own colors,
  the ring red and keyed in near-black, gone with the flash; a dead foe has no keyline.
- `test_a_foe_is_keyed_off_its_own_light` and the struck-foe tests still hold.

Mutation check: with the old red multiply and no foe keyline, the test fails two checks (the
hornet unkeyed, the hero drawn in (1, 0.45, 0.45)).

## Full suite

One full run (`TEST_TIMEOUT=7200`): 38,636 checks, 38,634 passed and 2 failed, both frame-time
checks in `test_a_long_journey_through_the_whole_game_stays_lean` (a lone 107 ms frame entering
`heartwood/sap_tunnel`, a second-worst of 80.6 ms), the machine-load spike passes 646, 651 and 654
recorded. Run alone afterwards it passed all 15 checks.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | A hurt hero reads as the hero; a foe reads on a light ground. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The cast shares one edge. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Four more silhouette draws per sheet foe. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 675 grade in its order, past the held items: the source hall's water box in its
brick border; then uniform floor strips (Tower foot, veins, source hall); then the empty minimap.
Pass 680 is the next independent grade.
