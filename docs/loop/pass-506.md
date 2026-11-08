# Pass 506: one master palette for the 2x redo, with four muted ramps

## Category

Art cohesion, from Sean's own decision in the project session (2026-11-07), not the rubric rotation. This
pass was run by hand from that session, holding the loop's lock. Sean chose the 2x look for the redo: a hero
on a 128 px canvas and 32 px tiles. He then asked how the colours would hold together across the hero,
PixelLab scenery, his Hearthroot pieces (painted in Resurrect 64) and any third-party tiles. His answer:
one palette, the Yldenfall master, with muted ramps added. "We're redoing it all anyway, so might as well
nail this palette down."

No PixelLab generations.

## Why the master palette needed muted ramps

Sean compared remaps in the session. Each subject was mapped to the old 64-colour master and to candidate
palettes, with the colour error measured as the mean CIELAB distance per pixel:

| Subject | Master 64 | + umber, sage | + umber, ash | + umber, ash, moss | **+ umber, ash, moss, ochre** |
| --- | --- | --- | --- | --- | --- |
| October hero (muted leather) | 8.4 | 6.6 | 6.5 | 6.3 | **6.0** |
| 128 px test hero (PixelLab) | 8.8 | 7.6 | 8.7 | 7.7 | **7.5** |
| Hearthroot Arms (Resurrect 64) | 15.7 | 10.7 | 10.8 | 10.4 | **10.0** |
| Graveyard tileset (third party) | 15.3 | 10.7 | 8.7 | 8.6 | **7.6** |

By eye: with the saturated ramps alone, dull browns snapped to bark and ember (the October hero's red
leather, bible 12.2), grey stone snapped to the cool stone ramp and turned lavender, and Hearthroot's roof
moss broke into green and brown speckles. Sage tinted grey stone green, and without moss Hearthroot's
moss turned beige. Without ochre, dry autumn brush turned orange. The four-ramp set was closest
everywhere and left the PixelLab hero unchanged.

## What was built

- **`tools/art/palette.py`:** four muted ramps at the end of `RAMPS`, so the first eight keep their
  names and order: umber (32°, 0.20; leather, rope, old wood), ash (60°, 0.07; weathered stone, dust),
  moss (80°, 0.12; lichen, dull foliage) and ochre (46°, 0.34; dry grass, straw). The master is now 96
  colours. `palette.MUTED` names the four. The script also writes `art/palette/master.json`, the colours
  as hex in PixelLab's `target_palette` shape, and sizes `master.png` to the ramp count (it was a fixed
  64 x 64).
- **Sky gradients stay saturated.** Regenerating with the new palette changed two far layers
  (`tower_far`, `heartwood_far`): `tilegen.gradient_ramp` picks the nearest colour from the whole palette,
  and the muted ramps' near-blacks won the darkest steps, so the Tower's violet night turned brown.
  Gradients are atmosphere, not material, so `gradient_ramp` now picks only from the eight saturated ramps.
  Every backdrop then regenerates identical to main.
- **NPC sheets (35) regenerated.** `castgen` snaps each NPC's `look` colours from `data/npcs.json` to the
  nearest palette colour, so muted clothing now lands on the muted ramps and matches its spec. The
  Kettleforge smith's robe is `#3a2a1e`, dark brown, but drew maroon; the Polesend ferryman's brown robe
  drew violet-grey. Both draw brown now, and the green robes of the merchant and Sylvarre's warden draw as
  the muted greens they are written as. Seen in Kettleforge at 2x; the NPCs still read against the walls.
- **Bible 12.2** describes the 96-colour palette and the rule for the redo: every new asset is drawn in the
  master palette from the start (`master.json` as `target_palette`, or `master.png` as `color_image`), and
  the importer maps to it as a safety net. Remapping finished art afterward is the fallback, not the
  method. Sheets made before the redo keep their own 56-colour palette until they are redrawn.
- **Enemy style guide**, Rendering: the same palette rule for foes and bosses.

`Backdrop.ZONE_HAZE` needs no change: it is computed from the first eight ramps, which are unchanged.

## Finding: decorgen drifted from its atlases

`tools/art/decorgen.py` does not reproduce the committed `assets/decor/*.png` even on unchanged main
(checked in a clean worktree at main): seven zones come out with different props and layouts. This
predates the pass and has nothing to do with the palette, so the atlases are left as committed. The cause
is unknown: either the generator changed after its last run, or something in it isn't deterministic.
It's worth its own pass before the decor is redrawn.

## Checks

- `tools/art/test_tilegen.py` gains `test_ramp_keeps_to_the_saturated_ramps`. **Mutation-checked:**
  letting `gradient_ramp` search the whole palette fails it (`night-0 -> bark-2` picks `umber-1`).
- `tests/test_animation.gd` gains `test_the_master_palette_has_muted_ramps_and_a_pixellab_copy`: 12 ramps
  of 8, the four muted ramps present, and `master.json` listing the master colours in order.
  **Mutation-checked:** cutting `master.json` to 64 colours fails it. The existing
  `test_sheets_use_the_master_palette` passes with the regenerated NPC sheets.
- Regeneration diffed by pixel, not by file: every generator output identical to main was restored, so the
  pull request holds only the 35 NPC sheets whose pixels changed.
- Full local Godot suite green: 8527 checks, 0 failed (45 soak tests, 60 minutes of play). CI test and mix.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 93 | One palette for the redo, with muted ramps so leather, stone, moss and straw keep their colour; NPC clothing now matches its spec. The hero and the 2x redraws remain the open gap. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Data and tooling only. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.1.

## Next

Sean's decisions from 2026-11-07 shape the redo: the 2x look (a hero on a 128 px canvas, 32 px tiles, the
640 x 360 world units kept), this palette, and a sharp scaling filter for 1080p screens. The plan for the
128 px hero comes next in the project session: a bigger hitbox, an audit of passages and jump heights,
then the hero base in PixelLab with this palette as its `target_palette`, for Sean's approval. Until then
the loop continues Sean's lighting and depth queue item (per-zone colour grade, room lights, foreground
silhouettes). The decorgen drift above wants its own pass.

Third-party art packs Sean downloaded are kept on his PC only, outside the repo, because their licenses
forbid redistribution and the repo is public. Don't commit them or give them to PixelLab.
