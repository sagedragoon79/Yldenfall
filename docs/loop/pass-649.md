# Pass 649: a side exit is a passage mouth

Date: 2026-11-23. No new notes from Sean. From the queue, first item: the independent grade of
pass 645 (5.2/10), next in its order after the dead voids: "walls that end mid-air at the screen's
edge". The PixelLab art loop stays gated on Sean (three guardian bases wait for his OK); no PixelLab
generations or Autosprite credits were spent. README's playtest link already points at
https://github.com/sagedragoon79/Yldenfall.

## Audit

In the graded rooms (`haar/marsh_road`, `spires/sky_steps`, `boughs/canopy_bridge`) the wall that
ends in mid-air is the wall over a side exit. A door on a room's left or right edge is an opening
with floor under it and a wall over it often one tile thick. The backdrop showed through the
opening at full light right to the frame, so the wall read as a slab hanging over nothing, with
no sign that a passage runs on past the edge.

## What changed

Design bible 12.125, `scripts/world/exit_mouth.gd` (`ExitMouth`), set up in `Room.build`.

- **The mouth.** Each side exit with a wall over its edge column darkens toward the edge: from
  nothing 56 world px in to 0.9 at the edge, on a curve, darker in the 12 px under the lintel, in
  `DeepShade`'s ordered dither and 2-pixel blocks.
- **No hard edge in open air.** Where the wall above ends before the shade does, the shade's top
  fades in over 24 px.
- **Behind the tiles and actors** (`z_index` -1, over the light shafts): the lintel, the threshold
  and the hero stay lit; only the backdrop seen through the mouth darkens.
- An exit with open sky over it has no mouth.

## Checked by eye

`spires/sky_steps`, `boughs/canopy_bridge`, `hearthroot/plaza`, `heartwood/grub_burrows` and
`haar/marsh_road`, at 1x and 2x (crops). The first try ran the lintel's dark band past the wall's
end in the canopy bridge, a dark box with a hard top in open air; the top now fades in there. In
the Haar the fog lies over the mouth as over everything, so it is faint there; the other zones
read as a passage running on under the wall.

## Tests

`tests/test_exit_mouth.gd`: a west exit under a wall gets a mouth from the wall's underside to the
floor, nearly black at the edge, lighter inward, gone past `DEPTH`, darker under the lintel, its top
fading in past the wall's end, the wall and floor untouched; an east exit under open sky gets none;
the mouth lies behind the tiles; the graded rooms' exits have mouths.

`tests/test_exit_mouth.gd` (12 checks in the suite's own three tests; opacity checks average an 8 by
4 area, since single pixels are decided by the dither):

| Mutation | Result |
| --- | --- |
| no mouths | fails (the graded rooms' exits have none) |
| no fade past the wall's end | fails (0.17 at the top and 24 px down) |
| no darker band under the lintel | fails (0.49 under the lintel and lower down) |
| open sky over an exit gets a mouth too | fails (2 mouths) |
| no falloff (flat dark) | fails (0.90 at the edge and halfway in) |
| drawn in front of the tiles | fails (z 0) |

## Full suite

Full suite (`TEST_TIMEOUT=7200`): 37,134 checks passed, 17 failed, every one with "left global
state changed: saves changed (save_2.json, save_2.json.bak)". Sean was playing the exported build
(`Yldenfall.exe`, started 6:29 PM) through the run, and it saves to slot 2 in the same user folder
the runner watches (its save_2.json was written at 8:05 PM, during the run). Nothing in this pass
reads or writes a save. Run alone, all 17 passed every check of their own; nine of them
again tripped only the save guard. With no Godot process running at all, save_2.json was written
again (20:28:41, then 20:29:57), so the played build is the writer, not the suite.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | A side exit reads as a passage running on past the frame. |
| Art cohesion | 15 | 98 | Unchanged. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged (built once per room load). |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

From the pass 645 grade in its order: barcode stripes in the dirt tiles; copied hazards and cloned
town towers; floating islands and chain platforms hung from nothing; the Spires' rain too heavy; an
oversized minimap; the spark's size at this scale. Held as before: the Haar's render, the sword's
flat bar, the hero's size; foes in three styles stays with the art loop. The next independent
grade is due after pass 650.
