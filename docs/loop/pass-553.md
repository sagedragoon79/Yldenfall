# Pass 553: a foe stands in its room's light

## Category

From the independent grade taken after pass 550 (5.3/10), as pass 552's "Next" named it: "foes
(bee, snake, Bark Knight) are more saturated and detailed than the muted rooms, so they look pasted
in". Art cohesion and Characters and foes in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent, and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. README's playtest link already points at
sagedragoon79/Yldenfall.

## Audit

- Shot `tower/foot` (hornet, Silt Adder, Iron Dwarf), `heartwood/dwarf_larder` (hornet, Rot Dwarf)
  and `boughs/sunlit_bough` (Bark Knight, mantis). The grader is right about the first two: the
  hornet's yellow and the adder's teal are the most saturated things in rooms of dark violet and
  brown, and both are outlined in pure black, which no room uses.
- The zone grade (12.9) multiplies the whole scene by a tint no channel of which is under 0.84. It
  shifts everything together and cannot bring a foe toward its room.
- The Bark Knight's fault is the other one (queue: "enemies camouflaged against their tiles"): green
  on the Boughs' green. Whatever is done for the first two must not push him further in.
- Every foe sheet and every code-drawn foe goes through `Enemy`'s canvas item, whose material slot
  is used only by the white wash and the death's dissolve.

## What was built

- **`FoeLight`** (`scripts/enemies/foe_light.gd`, `shaders/foe_light.gdshader`): one shared
  material per zone that every `Enemy` in that zone's room rests in. It pulls colour `MUTE` 0.2
  toward the foe's own grey and sinks the darks toward the deep of the zone's haze
  (`Backdrop.ZONE_HAZE` at `DEEP` 0.6), `SINK` 0.55 at black and falling with the square of the
  darkness. Lights keep their value; white is untouched.
- **`Enemy`** finds its room's zone when it enters the tree and takes that material; the wash, the
  dissolve and a respawn hand it back instead of clearing the slot. A foe outside a zone (the gym,
  a bare test room) has no material, as before.
- The hero, pickups, hazards and shots are not `Enemy` and are untouched.
- Design bible 12.43.

## By eye, at 1x and 3x

Before and after in the three rooms. The hornet and the adder keep their hue and their light
values, but their outlines are now the room's own shadow colour (deep violet in the Tower, deep
green-black in the Heartwood) and their yellow and teal sit a step back: they read as lit by the
room. The Iron Dwarf and Rot Dwarf barely change, which is right; they were not the fault.

A first try sank the darks to the haze itself. In the Boughs, whose haze is a mid green, that
lifted the Bark Knight's outline into the leaves behind him. `DEEP` fixes it: his outline stays
dark, and he is no harder to see than before. He is no easier either; his camouflage stays in the
queue.

## Tests

`test_foes_stand_in_their_rooms_light` in `tests/test_foe_light.gd` (113 checks): every zone with
rooms has a light and the gym has none; per zone, a strong colour is muted but keeps its hue, an
outline takes the room's shadow colour and stays dark, white is untouched and a light keeps its
value; the material carries the same numbers as the sum and is shared; a hornet in the Tower rests
in it, loses it to the wash and the dissolve, and has it back after each and after a respawn; a
foe in a room with no zone has no material.

Mutation check: no mute fails the muted checks; sinking to the full haze fails "never up to it" and
"stays an outline"; no sink fails the falloff and per-zone checks; not setting it at ready fails
the rest and respawn checks; the wash clearing the slot fails "comes back when the wash ends".

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; flash, tell and death are as they were. |
| World and level design | 15 | 99 | Unchanged; one-template rooms, the empty mid-ground and the Proving Scar's framing remain. |
| Art cohesion | 15 | 98 | Foes share their room's shadow colour. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; one shared material per zone. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85. Full suite: 14,484 checks passed, 0 failed.

## Next

Pass 554: the art loop stays **gated** on Sean. From the pass 550 grade: the shop's missing item
icons and portrait. From the pass 545 grade, still open: the uniform rain over the Spires. The Bark
Knight's camouflage on the Boughs' green (a reserved accent or rim for foes) is in the queue, as is
the Proving Scar's framing. Rim light on figures and the Boughs painterly clash stay parked for a
watched session.
