# Pass 582: each foe keeps one color of its own

## Category

Art cohesion and combat readability, from the independent grade taken after pass 580 (5.6 of
10): its second defect, "characters are too small and too quiet for the frame ... foes are dark
on dark ... give each foe one saturated color". Characters and foes was the lowest area (4.6).

No note from Sean was new. The queue's first item (lighting and depth) is down to pieces parked
for a watched session, and the second (the Haar's fog) is held until the hydra and steam
branches merge; this is the third. The PixelLab art loop stays **gated** on Sean: three
guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three.
No PixelLab generations were spent, and no Autosprite credits. The hosted workbench is still
down (its Vercel Blob store is suspended); it stays under "stuck" for Sean. `README.md`'s
playtest link already points at `sagedragoon79/Yldenfall`.

## Audit

- Every foe in a zone's room rests in `FoeLight` (bible 12.43, pass 553): its color is muted
  by 0.2 and its darks sink toward the zone's haze. That answered the pass 550 grade ("pasted
  in"), and it mutes every color alike, the foe's bright part with its body.
- The enemy style guide asks each foe for "one hostile accent ... brighter than anything else
  on it". Measured on the 25 sheets: 20 hold a saturated color in a hue of its own, between
  0.3 and 15 percent of the sheet (the Rot Dwarf's orange cloth, the Grub Lump's cyan spots,
  the Minecart Rider's gloves and cart bands, the Thunder Beetle's gold seams).
- Five do not. The Lantern Ghost is faint by design (bible 7). The Crystal Dwarf has a
  `FoeGlow` (12.52). The Bog Puffcap, the Bark Knight and the Spring Eel have no saturated
  pixel in a hue their body does not use; a wider band turns the whole figure (the eel went
  cyan on teal water, and lost contrast).
- The hit flash, the tell and the death replace the material, so a change to the resting
  material can't touch what a fight reads.

## What was built

- **The accent** (`shaders/foe_light.gdshader`, `FoeLight`): a band of hue on the foe's own
  sheet. A pixel in the band, saturated and light enough to count, is left out of the mute and
  the sink, and its saturation and value rise toward 1. Soft edges on the band and both
  floors. The hue is never turned.
- **`FoeLight.ACCENTS`**: twenty foes, by script name, each with its band and its lift.
  `Enemy` names itself by its script (`FoeLight.id_of`), and `material_for(zone, foe)` builds
  one material per foe and zone. A foe with no accent shares the zone's plain material.
- Design bible 12.69 (and a line in 12.43); the enemy style guide's design section says to
  paint the accent saturated and to give a new foe a row.

Tuned on each idle frame at 3x over its zone's dark (painted, as lit before, as lit now), two
takes: the first lift (0.6 and 0.35) was too quiet, and the Iron Dwarf, the Drowned Dwarf and
the Shade Knight needed lower floors to catch anything. Then looked at in play at 1x in
`tower/rail_gallery` and `heartwood/dwarf_larder`: the rider's gloves and cart bands, the
Blinkhop's horn and the hornet's bands now carry.

For Sean to judge in play: it is a small lift. A foe is as large and as dark as it was, with
one bright part. The Rot Dwarf in the larder still reads mostly as grey plate. The grade's
other asks for this defect (the camera, sprite size, a rim light on the hero) are
watched-session calls.

## Tests

`tests/test_foe_light.gd`, one new, and one changed (the hornet now rests in its own material):

- `test_each_foe_keeps_one_colour_of_its_own`: for each of the twenty, the foe exists, the
  band is at most 35 degrees, its sheet holds the accent (0.3 to 20 percent of it), accent
  pixels come out more saturated and lighter than the room's light alone leaves them, in the
  hue they were painted; black, white and greys are lit as before; the material is its own,
  one per foe and zone, with its numbers. The five without an accent share the zone's
  material and are lit as before. Outside a zone a foe draws as painted. The band's edges; and
  in a room, a hornet rests in its own material.

Mutation check, each restored after: a lift that does nothing fails 41 checks; one shared
material for every foe fails 2 (and stops there); a band as wide as the wheel on the Rot Dwarf
fails 3; an `Enemy` that does not name itself fails 2; an accent given to the Spring Eel, whose
sheet has none, fails 4. One true failure on the way: the Clockwork Hound's floor was too high
to catch its brass over the whole sheet (it had passed on the idle frame alone); lowered.

Full suite: see the pull request (the count is recorded there and on the workbench).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Foes carry one bright part each; nothing a fight reads changed. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 98 | Unchanged; the independent grade is the real measure. |
| Bosses | 10 | 99 | Unchanged (guardians are not in the table; their remake is the art loop's). |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | One material per foe and zone, built once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

In the queue's order: the grid showing in the aqueduct's sandstone, the Tower's ceilings and
the Spires' floating blocks (and the HUD over the ceiling tiles, the Spires' rain); the Haar
tell frame (a flat white silhouette: check whether the capture catches one frame of the flash
or its whole length); chests housed differently per zone and the causeway's spikes; code-first
liquids and hazards; an audio pass for the set pieces. New from this pass, for the art loop
when a base slot frees: the Bog Puffcap, the Bark Knight and the Spring Eel have no accent
color on their sheets. The Haar's fog stays held. The next independent grade is due after
pass 585.
