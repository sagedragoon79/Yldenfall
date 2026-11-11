# Pass 539: every zone carves its own lore stele

## Category

A defect from the pass 535 independent grade (workbench queue): "placeholder-looking set pieces",
first among them the "identical grey sign slabs in most rooms." Art cohesion, and Environments in the
grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. The queue's first two items
(rim light on figures; the Boughs painterly clash) stay parked for a watched session, and pass 538 took
the planks, so this was the first item an unattended pass could do. No PixelLab generations were spent.

## Audit

`LoreTablet` drew one 18x20 rectangle in a grey (`5d5670`, not a master palette tone) with a one-pixel
bevel, the same in every zone. 112 of the game's 127 rooms have at least one sign, and most stand by the
room's entry, so the same grey card sat beside the hero in nearly every screenshot the grade saw (shots
01, 04, 07, 09). The runes on its face (pass 512) were already per-sign; the slab was not.

## What was built

- Five stele silhouettes (`LoreTablet.SHAPES`), each a column profile from `LoreTablet.profile`: a
  round-topped arch, a pointed gable, a sloping waystone with a chip broken out of its top, a dwarf
  runestone with a raised crown and an overhanging cornice, and a crystal shard tapering to a point.
- Per-zone looks (`LoreTablet.LOOKS`, bible 12.31): root-wood arches in the Heartwood and moss-green
  ones in the High Boughs (both moss-capped), a moss-capped umber waystone in the Haar, ochre gables in
  the Spires and slate ones in the Tower and Trials, runestones banded in bronze (Hearthroot), sea-blue
  (Sunken Spring) and crystal magenta (Vorrhallow), and a violet shard with a cyan tip in the Evercrown.
  Each inlay takes its zone's accent. Every tone is a master palette value.
- Each stele stands on a plinth wider than the stone, is outlined, lit down its left edge and along its
  top, shadowed down its right, carries a few weathering pits, and sets its runes in a recessed panel
  lit along its foot. The face narrowed to 12 px so two pixels of stone frame it.
- `Room` hands each tablet its zone before adding it.

## By eye, at 1x and 2x

A lineup of all eleven looks at 2x, then the tablets in `spires/sky_steps`, `evercrown/veins`,
`heartwood/sap_cistern` and `haar/marsh_road` at play scale. A first take let the panel fill all but a
pixel of the stone, so it still read as a framed card; the face was narrowed until the stone shows round
it. The stele now reads as a thing of its place: an ochre gable in the Spires rain, a crystal shard in
the Evercrown, a mossy root-wood marker in the Heartwood, a chipped waystone by the Haar's lamp. At play
scale the runes stay legible and the stele stays below the hero's shoulder, so it never competes with
foes.

## Tests

`tests/test_lore_tablet.gd`, three new tests: every zone with rooms has a look, and every look's tones
(and the moss) are master palette values; every shape covers the recessed panel, stands on the plinth,
stays over it, and has a shaped top, with five distinct silhouettes all in use; a room's tablet takes the
room's zone (and an unknown zone falls back to the slate arch). The pass 512 rune tests still hold on the
narrowed face.

Mutations: dropping the zone hand-off in `Room` fails the room test; flattening the gable's top fails the
shape test.

Bible: 12.31 (every zone carves its own lore stele).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; the empty mid-ground remains. |
| Art cohesion | 15 | 98 | The most-seen set piece now belongs to its zone. The other placeholder pieces, the HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the stele draws only on redraw. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 540: the art loop stays **gated** on Sean (three guardian bases wait). Pass 540 is the fifth since
the last grade, so it takes an independent grade. Next from the pass 535 grade's placeholder set pieces:
the Spires' red orb columns down the walls, the flat Heartwood grotto liquid, the Evercrown's flat cyan
diamonds and the Haar's orange glyph blocks; then the dressed mid-ground. The VFX-tool trials continue on
the dash afterimage, then the enemy death dissolve. Rim light on figures and the Boughs painterly clash
stay parked for a watched session.
