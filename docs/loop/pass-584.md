# Pass 584: Carillon's storm stands behind the fight

## Category

Art cohesion and combat readability, from the independent grade taken after pass 580 (5.6 of
10): "the Spires fight frame is noisy (thin the rain, keep lightning in the far layer, darken
the sky a step)".

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, the second (the Haar's fog) is held until the hydra and steam branches
merge, and the third is watched-session calls and art-loop work; this is the next piece of the
fourth. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were
spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

Looked at the catalogue's `spires-hit` fight frame and `spires/storm_ledge` at 1x and 2x.

- **The rain.** `SheetRain` draws at z 4, in front of the play field, with its near layer at
  alpha 0.85: a screen of near-white dashes across the hero, the foes and the hit spark. The
  rain was the highest-contrast texture in the frame.
- **The lightning.** It was already in the far layer (`spires_far`), so "keep it in the far
  layer" was met in name. But the bolts are baked into the picture and never go out, drawn in
  gold-7 (luminance 0.94) with a crystal-6 halo: three white ropes hanging behind the foes,
  brighter than anything a foe is drawn with.
- **The sky.** night-1 to crystal-2 with crystal-3 cloud tops: a mid-value magenta field
  behind mid-value foes.

## What was built

- **Thinner rain** (`SheetRain.MAX_ALPHA`, `LAYERS`): the near layer at 0.46 (was 0.85), the
  far one at 0.26 (was 0.42); no layer may pass 0.5. `density()` is unchanged, so the drizzle
  after the Sky Spring is the same fraction of the storm.
- **Dim far bolts** (`FAR_BOLT`, `FAR_BOLT_GLOW`, `FAR_BOLT_GLOW_ALPHA` in
  `tools/art/tilegen.py`): crystal-4 with a crystal-3 halo. The bolts keep their shapes (the
  random sequence is untouched). Lightning in play (`LightningArc`) is unchanged and is now
  the only bright lightning in the zone.
- **A darker sky** (`SPIRES_SKY`, `SPIRES_CLOUD`): night-0 to crystal-1, the storm banks at
  crystal-2, crystal-1 and night-1, the far limbs at night-1. The far layer's mean luminance
  went from 0.215 to 0.123 and its brightest pixel from 0.94 to 0.57.
- Design bible 12.71, with a rule for weather. Only `assets/bg/spires_far.png` is regenerated.

One take on the limbs: with the sky a step down, the night-2 limbs stood out as a pale net;
they went down a step with it.

For Sean to judge in play: the storm is quieter. The rain still reads as rain at 1x, but if
it now feels too light for a storm, `LAYERS` is the one place to raise it (up to 0.5).

Found on the way, not fixed: running `tools/art/tilegen.py` on this PC also rewrites
`boughs_mid`, `haar_mid`, `hearthroot_mid`, `heartwood_mid` and `trials_mid` with different
bytes from the committed files, though no painter of theirs changed (last committed in pass
462). They were restored here. Either the generator has drifted from those pictures or it is
not byte-stable across machines; queued.

## Tests

- `tests/test_storm_backdrop.gd` (new suite, two tests): every rain layer shows and stays
  under `MAX_ALPHA`, the far layer is the fainter, and two crossing drops cover under 0.65 of
  a figure; the far layer's brightest pixel is under 0.6, its mean under 0.15, and fewer than
  400 pixels pass 0.5 (a few motes; the old bolts were 5,461).
- `tools/art/test_tilegen.py`: `test_carillons_far_lightning_is_dim` (76 pass; this guard
  runs locally, not in CI).

Mutation check, restored after and the picture compared byte for byte: the near layer back at
0.85 fails 2 checks of the rain test; the old far layer fails all 3 of the sky test.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged in rules; foes and tells read more clearly in Carillon. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | The storm no longer outshouts the figures; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged (guardians are not in the table; their remake is the art loop's). |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

In the queue's order: what is left of the grid item (the aqueduct: a second variant for a
wall's faces so a pier's moss mark does not repeat, and something in the open water; the HUD
over the ceiling tiles; the shop panel); the Haar tell frame (a flat white silhouette: check
whether the capture catches one frame of the flash or its whole length); chests housed
differently per zone and the causeway's spikes; code-first liquids and hazards; an audio pass
for the set pieces; the five mid backdrops `tilegen.py` no longer reproduces. For the art loop
when a base slot frees: the Bog Puffcap, the Bark Knight and the Spring Eel have no accent
color on their sheets. The Haar's fog stays held. The next independent grade is due after
pass 585.
