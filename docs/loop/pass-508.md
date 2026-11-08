# Pass 508: every passage four tiles tall for the 2x hero

## Category

Sean's own work, from the project session (2026-11-07), not the rubric rotation. He chose the full
128 px hero (about 60 world px tall) over keeping today's height. The audit for that switch found that
**every door in the game was exactly three tiles (48 px) tall**: all 198 side doors, plus about 370
other standing spots with three tiles of headroom. A 60 px hero fits through none of them. Sean also set
the direction for the rooms themselves: every room is to be rebuilt, zone by zone with its new 32 px
tiles, to be confined (tunnels, hollows and chambers in a climb up one great tree), with the canopy
zones airy but full of cover. This pass makes today's rooms fit the new hero until then.

One PixelLab generation ($0.15): a hero base made from today's idle as a style reference, hood down, in
the master palette. Sean then pointed to his own hood-down state of the 128 px size test, which is the
stronger design, so it is the base and this one is kept only as a record
(`art/pixellab/hero128/base/`).

## What was built

**`tools/levels/raise_passages.py`** finds every standing spot with only three clear tiles over the feet
(gates counted open, since a passage matters once its gate opens) and makes room, one run of neighbouring
spots at a time:

| Fix | When | What it does |
| --- | --- | --- |
| carve | the ceiling is two or more rows thick | the ceiling's bottom row opens, and the column past each end of the run too, so stepping off a ledge or in from a gap clears the old ceiling |
| lower | a thin slab over a thick floor (a vault) | the floor drops a row with everything in the column, and the column outside the doorway drops too, so the step down comes before the lintel, not under it |
| sink | a thin floor (slab or plank) with air under it | that floor drops a row with what stands on it |
| lift | anything else | the slab rises a row with what stands on it |

A door, gate, fake wall or ladder that filled the old three rows grows to four, so a doorway stays one
door and a gate still seals its passage. Jumps whose arc now clipped a ceiling the body passes under but
never stands below were found by the reach tests and carved by hand (the script's `HAND` list, seven
rooms), and the Ore Vault's bump of slope under its drop-in was flattened (`SET`). One run settles every
room, and a second changes nothing: 723 spots in 120 of 126 rooms.

**Saves keep what they opened.** A pickup's id is its room and cell, and so is a key door's and a
breakable wall's. The 18 chests, pickups, key doors and the Elven Helm that a lowered floor carried down a row are in
`GameState.MOVED_PICKUPS`. The 11 breakable walls (cracked stone, bramble, stone seals) that grew a cell
are in the new `GameState.GROWN_GATES`: a save that broke the old wall has broken the new cell too, so no
lone block stands in the doorway. Header lines that place things by tile (signs, people, props, chests,
locks) follow their column, and hidden rooms' covers grow over the rows their pockets gained.

**`Reach.BODY_ROWS` = 4.** The reach checker's body was three rows, spelled out in a dozen places
(`y - 2`, `top - 2`, `y - 3`); it is now one constant, with `HEAD` the rows from feet to head.

**Key doors and the Sky Key gate are four tiles tall** (`KeyDoor.SIZE` 16x64, bands and mark redrawn to
the new height).

**`tools/levels/reach_map.tscn`** prints rooms with the checker's standing spots marked over the grid,
or with no room named, the rooms an ability set never reaches. It found every hand fix here, and it is
the tool for the zone rebuilds.

**`art/palette/master.hex`** (Lospec's one-colour-per-line format) joins the palette files, for Sean to
paste into PixelLab's web app (it takes pasted hex, a palette image or a Lospec link).

The hero's hitbox stays 12x40 in this pass: it grows to about 14x54 with the new sheets, when section 6
and the movement tests change with it.

## Docs

- Bible 3.3: two new entries, "Passages four tiles tall" and "Room density, the redesign" (Sean's
  direction, his Hollow Knight map and screenshots as density references, never layouts, and his note
  that the solid mass is drawn tree, not black void).
- Bible 4.5: key doors, fire seals and the gates' numbers say four tiles; 12.1 records the 2x hero and
  his base (Sean's hood-down state, `d81e27dc`).
- `levels/README.md`: four tiles of headroom, gates and doors four tall, a plank (not a slab) for a
  platform you also walk under, and the two new tools.

- Bible 12.3 and the enemy style guide: Sean's rule that every sprite and animation is strict
  orthographic, both feet on one ground line (a tilted camera lifts the back foot). His hood-down
  state's side views pass: their feet's lowest rows are 124 and 125, a boot sole apart.

## Checks

- Every reachability test passes (116 checks): the critical path in order, every pickup, chest and shrine
  with each ability set, no soft-locks, and every gated secret still gated.
- Full suite: see the PR.
- Screenshots of the Feather Hollow vault (its Silver door four tall, the vault a row deeper), the West
  Gate (cracked wall and stone seal four tall), the East Gate's hidden room and the Vorrhallow upper
  stair's carved ledge. They also show what Sean asked to change next: rooms of open air with platforms
  floating in it.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged; the hitbox comes with the new hero. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 97 | Every passage fits the 2x hero and every route still holds, but the raise leaves small dips and notches the zone rebuilds will replace. |
| Art cohesion | 15 | 92 | Unchanged; the hero base is chosen (Sean's hood-down state) and in palette from here. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Old saves keep their opened chests, doors and walls. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Level data and constants only. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 97.65.

## Next

- **The hero, for Sean:** his hood-down state is the base. Next, its 18 bare-hero clips, each made with
  `master.json` as the palette, checked in game; the cloak's dye key needs checking against the darker
  forest green. Then the hitbox (about 14x54), section 6 and the movement tests.
- **Room rebuilds, zone by zone** with the 32 px tiles, to the density rule in bible 3.3.
