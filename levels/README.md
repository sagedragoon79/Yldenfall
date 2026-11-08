# Room files

A room is a text file: `key: value` header lines, a line with `---`, then the tile grid.
One character is one 16x16 tile. The room's size is the grid's size.

```
name: Movement Gym
zone: gym
map: 0, 0          (the room's top-left on the map, in screens)
door: 1, heartwood/hollow_02, 3   (door 1 here leads to door 3 of that room)
label: 3, 33, Some text placed at tile (3, 33)
sign: 8, 19, First page|Second page   (a lore tablet at tile (8, 19); | splits pages)
sign: 8, 19, [spring:heartwood] Later   (lines on one cell are one tablet; it reads the first whose
                   bracketed flags hold, so put the plain line last, as the default)
npc: 12, 19, ringreader  (a person from data/npcs.json standing on tile (12, 19); an optional
                   fourth field shows them only once a flag is set, or with !flag until then;
                   several conditions, space-separated, must all hold)
secret: 57, 5, 62, 7   (covers tiles 57,5 to 62,7 with fake wall so a hidden room's
                        contents can't be seen until the player walks in)
enemy_respawn: 5   (optional: seconds until defeated enemies return; 0 = never)
corrupted: true    (optional: foes are grown through with meteor crystal; default true in zone evercrown)
chest_gold: 100    (optional: gold in each chest in this room)
chest: 2, 19, 900   (optional, repeatable: the chest on tile (2, 19) holds 900 gold instead)
lock: 4, 19, silver   (optional, repeatable: the `J` on tile (4, 19) is a silver, gold, thorn or glass door)
prop: 40, 19, fountain   (a set piece standing on tile (40, 19): fountain, spring_heartwood, spring_haar (clears only after boss:haar_wyrm), house, lamp (a lamp post whose lantern lights the fog), taproot, lift, forge, winch, crucible, trial_goal (the bell at the end of a Ringreader Trial), glass_key (the one Glass Key), elven_helm (the found helmet, in its own slot since pass 185), pendant and briar_wand (the original's two relics, pass 201); and Sean's PixelLab buildings, `SetPiece.NAMES`: shop_arms, shop_sundries, shop_dyeworks, shop_cartographer)
boss: gnarlmaw   (a boss arena: doors seal until the boss is beaten)
music: title       (optional: a track other than the zone's, from assets/music/)
ambience: heights  (optional: an ambience bed other than the zone's; plays assets/music/amb_heights)
fog: 0.5           (optional: The Haar's fog density over this room, 0 for none; the zone's otherwise)
surface: stone     (optional: the ground's footstep sound if not the zone's: stone, moss, mud, plank, iron, sap)
retro: true        (optional: the world is drawn through the NES filter, RetroFilter: chunky pixels in a 4:3 frame, NES palette only. Old Hearthroot)
tide: 19          (optional: Vorrhallow's standing water: from this row down to the floor in every column open at it, a tile deep on the floors and filling the pits; wading splashes. It drains once Thane Vorrund is at rest, leaving a tide mark)
calm: boss:thane_vorrund   (optional: once this world flag is set the room spawns no foes; a town woken again. The Drowned Market)
camera: wide       (optional: the camera eases out to show 25% more each way, for big arenas and sky rooms; never past the room's edges, so make the room at least 50x29 tiles to get all of it)
---
##########
#P.......#
##########
```

| Char | Meaning |
| --- | --- |
| `#` | Solid ground (top-exposed tiles get a moss edge) |
| `-` | One-way platform (jump up through, Down + Jump to drop) |
| `"` | Ladder (bible 6.11): a column of these; Up/Down climb, Jump leaves. The top cell is also a one-way plank you can stand on |
| `/` `\` | 45° slope, solid below the diagonal: `/` rises to the east, `\` to the west. Put ground under it and on its high side; the reachability checker counts it as a whole block |
| `^` | Floor spikes (hazard, pogo-able) |
| `o` | Thorn bulb (hazard, pogo target) |
| `C` | Cracked stone (Delver's Pick breaks it) |
| `E` | Training dummy |
| `M` | Blinkhop (hopper) |
| `H` | Hornet (flier; placed at the tile center) |
| `D` | Rot Dwarf (shielded walker) |
| `T` | Sap Spitter (turret; lobs sap that leaves a slowing puddle) |
| `U` | Grub Lump (crawls on floors, walls and ceilings; clings to the floor first, else the ceiling, else a wall) |
| `I` | Iron Dwarf (armored; slams a hammer that sends a shockwave along the floor; hit him while it is stuck) |
| `B` | Gear Bat (roosts upside down; place it just under a ceiling. Flings a returning gear; parry it back at the bat) |
| `K` | Minecart Rider (rolls the floor; revs, then charges to a wall or the floor's end and tips over: hit him then) |
| `A` | Lantern Ghost (drifts through walls; out in the Haar's fog it shows only near light. Eyes flare, then it lunges) |
| `V` | Bog Puffcap (rooted; its gills glow as it swells, then it bursts into a lingering spore cloud. Soft while spent) |
| `p` | Drowned Dwarf (the Haar: lies sunk in the mire, unhittable, a crest and bubbles showing; rises when you come near, heaves his anchor, then slams it down in front of him (parryable). Soft while rising and while the anchor is buried; sinks again once he loses you) |
| `m` | Leaf Mantis (hides folded on a bough; unfolds, lunges with its scythes, stops at ledges. Parryable; soft while overreached) |
| `!` | Bark Knight (the High Boughs: paces in living bark, braces, then thrusts a bough lance about four tiles (parryable) and roots with it out, so the lance is a ledge you can stand on or pogo off. Each blow on his bark only chips one of three plates; bare or rooted he takes full damage, and one plate grows back as he pulls free) |
| `;` | Seed Bomber (the High Boughs: a pod-bellied bird that keeps about five tiles over your head; squeezes its glowing husk, then drops a seed that sputters and bursts in thorns. Strike the seed back up to knock the bird down. Placed at the tile center; give it open air above the road) |
| `?` | Marsh Hag (the Haar): keeps her distance and hexes the mire under your feet; strike her mid-hex to break it |
| `t` | Thunder Beetle (Carillon: trundles the floor; its shell turns side blows but not a pogo. Near it, its wing cases crackle, then it discharges a ring of lightning (unparryable, above too); spent, it takes full damage) |
| `y` | Storm Harpy (Carillon: hangs above and beside you; rears and spreads her wings with a screech, then flings a fan of three parryable feathers (a parried one flies back at her); winded, she sags into reach) |
| `]` | Spire Sentinel (Carillon: a stone knight that moves only while your back is turned and turns every blow; raises its halberd, then slams in front of it, parryable; cracked open after a parry or a miss) |
| `q` | Crystal Dwarf (Vorrhallow: trudges toward you; raises his crystal fist, then drives it into the floor and a chain of crystal spikes erupts toward you (unparryable: jump them); his crystal back turns blows from behind except from above; rooted after, he takes every blow) |
| `R` | Root-gate tile (solid roots; a column of four is usual) |
| `Z` | Fire seal tile (red runic flames: solid, burns on touch; one Deluge bolt douses every seal in the room for good. Wall it in above, or it can be jumped) |
| `c` | Dead conduit (a copper coil, not solid; a Tempest Lance bolt passing within 72 px wakes it for good) |
| `k` | Conduit gate tile (solid; slides open for good once every conduit in the room is awake) |
| `h` | The Tempest Lance scroll |
| `:` | The Lithic Fracture scroll (spell pickup, bible 4.1): an optional find in the Kettleforge tower |
| `w` | Bramble wall tile (dry thorn-vine: solid; a Emberfall spell burns the whole knot to ash for good. Emberfall is optional, so hide only secrets behind it) |
| `[` | Cracked stone seal tile (rune-bound stone: solid; a Lithic Fracture cast shatters every seal of the run in the room for good. Lithic Fracture is optional, so hide only secrets behind it) |
| `u` | Dry basin mud bed (solid ground, cracked) |
| `=` | Dry basin water-line stain: a run of these across a tank above its `u` bed. A Deluge bolt across the tank fills it and the run becomes a one-way raft for good |
| `b` | Drowned boardwalk (the Haar): nothing until the Haar Spring flows (`spring:haar`), then a one-way platform. Lay it over a spiked dip |
| `@` | Bounce-pod (High Boughs): stands on the floor of its cell; land on it and it throws you about nine tiles up. Not solid |
| `r` | Stride seed (bible 6.4): floats at the cell's center; touched in the air with a double jump or dash spent, it bursts and gives both back, and grows again after 2.5 s. Seeds only help: the checker ignores them, so never make one the only way to a pickup or exit |
| `>` `<` | Wind current (High Boughs): a band of wind blowing east (`>`) or west (`<`) that carries an airborne player and bears up a fall; holding Down drops out. Once the Sky Spring is restored every current blows the other way. Draw them as whole rectangles over open sky
| `Q` | Flue damper tile (iron louvers, solid until Durgan falls and the winch turns; a row of three is usual) |
| `N` | Root Heart: strike it and every root-gate in the room opens for good |
| `\|` | Elven veil (pass 216): a wall to the player, but a dash passes it (the Elven Stride). A column of four seals an alcove; only the player is stopped, so keep foes out of veiled spaces |
| `Y` | Bound fog (the Haar): solid until the player brings the Lantern Key near, then every curtain in the room parts for good (a row of three is usual) |
| `P` | Player spawn (feet at the bottom of the tile) |
| `1`-`9` | Door cells (see below) |
| `%` | Fake wall: looks solid, walk through it (a secret). With the Seer's Lens a thin violet seam shimmers around it |
| `i` | Hidden plank: a one-way platform that is always there but unseen; the Seer's Lens shows it faintly |
| `n` | Seer's Lens (passive ability pickup) |
| `f` | Time-locked water: a block of falling water that bears you down; frozen by the Stillstone, it has a foothold every 3 rows up from its bottom. Fill a shaft wall to wall so nothing climbs past it |
| `v` | Wrong gravity (the Evercrown): a block where the player keeps 40% of their weight, so a jump rises about 11 tiles and a fall drifts. The checker allows a 9-tile rise from a spot inside one when the column up to the landing is drift too |
| `a` | Deep water (the Sunken Spring): the player swims while the middle of the body is in it (floats up, sinks holding Down, jump strokes up, and with the head out jumps clear). Not solid. Draw pools as whole blocks; the checker swims through water cells and jumps out from the surface |
| `)` | Silt Adder (the original's serpent: floats up and down its own column, most often over a ladder; level with it and in front, it flares its hood and hisses, then strikes straight out along that level. Placed at the middle of its swing, at the tile center) |
| `l` | Spring Eel (the Sunken Spring), in a cell of water: it never leaves the water; it coils, then darts and bites |
| `x` | Light vein (the Veins, the Everbloom's second phase): a lit vein of stillglass flesh feeding the core. One cut or pogo severs it, and the core's health is the veins still lit (bible 8) |
| `+` | Heart seal (the Evercrown): living flesh across a passage, a wall to every blade but the Severance, which tears it open for good |
| `{` | The Witherbloom scroll (spell pickup, bible 4.1): a late secret |
| `&` | The Severance (bible A10): found, it goes straight into your hand. Unused since pass 217: Thane Vorrund gives it up |
| `}` | The Rune Dagger (bible 5.2): the Throw button hurls it; it reforms at your hip. In the Heartwood's Hornet Gallery |
| `z` | Stillstone (ability pickup) |
| `e` | Shade Knight (Vorrhallow: tower shield turns frontal blows; parry his thrust or cut) |
| `j` | Clockwork Hound (Vorrhallow: winds up and pounces; parry flips it; the Stillstone stops it) |
| `s` | Glass Slug (Vorrhallow: lobs three burning globs; shell turns pogos; the Stillstone holds the globs) |
| `~` | Sap pool: halves run speed and weakens jumps (Heartwood) |
| `S` | Meditation Shrine (save, refill, respawn point) |
| `J` | Copper door, 4 tiles tall from this cell up (opens with a Copper Key). A `lock:` header line makes it a Silver, Gold, Thorn or Glass door |
| `g` | Vorrhallow's upper gate, 4 tiles tall from this cell up (opens with the Sky Key, Skyrend's reward) |
| `$` | Treasure chest (gold, opens once) |
| `G` | Climbing Glove (ability pickup) |
| `X` | Featherstep Boots (ability pickup: double jump; glows in the fog) |
| `O` | Deluge scroll (spell pickup; glows in the fog) |
| `d` | Elven Stride (a warden's feather; grants the dash) |
| `L` | Life Fruit (+1 mask) |
| `W` | Mana Dew (+10 max MP) |
| `F` | Potion Shard (3 = +1 flask charge) |
| `*` | Grain Shard (3 = +1 skill point) |
| `(` | Stillglass Shard (Temper Blade II at the Kettleforge smith costs one) |
| `.` | Empty |

## Rooms and doors

A room's id is its path under `levels/` without `.room`, e.g. `hearthroot/gate`. The file's
directory is its zone folder; set `zone:` to match (it picks the map color and the area name).

Rooms are at least one screen and at most 4x3 screens (design bible 3.3, pass 331): a screen
is 40 tiles wide and 23 tall (two screens tall is 45, three 68). Most rooms are whole screens,
but a hall or arena may be a screen and a half wide (60 tiles), and the Heart Gate is 56; the
camera stops at a room's edges, so a part screen only means the camera travels less.
`tests/test_rooms.gd` (`test_every_room_keeps_the_bibles_size`) holds the bounds.
`map: x, y` places the room's top-left corner on the map grid, counted in screens.

Mark a door with a digit, repeated over every cell of the opening, and add a `door:` line.
- A door touching the left or right edge is walked through. Put floor right under it; the
  player arrives standing just inside the matching door.
- A door on the top or bottom edge is a shaft. Coming up through a floor door, the player
  pops up with a small boost, so put a ledge beside the shaft's top.
- A door away from the edges is an inner doorway, used by pressing Up.

Every door must lead to a door that leads back (`tests/test_rooms.gd` checks this).
Pickups, chests and cracked walls remember being taken or broken (by room id and tile), so
moving one in a room file makes it collectable again.

## Design rules the tests enforce

`tests/test_reachability.gd` runs the reachability checker (`scripts/world/reach.gd`) on
every room: from the new game spawn, with no abilities, the Climbing Glove must be reachable
and the boss must not be; with the glove (and keys) every room, pickup, chest and shrine must
be reachable; and no reachable spot may be a soft-lock (unable to get back to a save, or on
to the glove). It also boots every room and checks the player lands safely.
"Pickup" includes the finds a `prop:` line lays (`Room.FOUND_PROPS`: the Glass Key, the
Elven Helm, the Acorn Charm and the Briar Wand; pass 203). Until then the sweeps read only
grid cells, so a find moved somewhere out of reach would have passed.

A pickup meant to open only after the Heartwood Spring (sap hardens into amber) goes in
`AMBER_SECRETS` in `tests/test_reachability.gd`; the test then proves it is gated.

Sap with open air beside it and more sap below draws as a pouring falls (Amber Falls).

Every character a room's grid uses has a row in the legend above, and every legend row is one
the room loader knows (`tests/test_rooms.gd`, `test_the_readme_legend_matches_the_rooms`, pass 363).

Safe numbers for layouts (a little under the real movement): a standing jump clears 4 tiles
up with 2 across, 3 up with 4 across, or 2 up with 5 across. Leave 4 clear tiles of headroom
for the body (the 2x hero, pass 508), and doors, gates and passages 4 tiles tall: under a jump's
arc as well as over a floor. `python3 tools/levels/raise_passages.py` finds and fixes any spot with
only 3, and `tools/levels/reach_map.tscn` prints where the checker can stand in a room (its header
says how to run it). Platforms that should be reachable from the floor go 4 rows above it; make
one you also walk under a one-way plank (`-`), since a solid one leaves only 3 tiles beneath.
`tests/test_movement.gd` (`test_the_readmes_safe_jumps_are_real`, pass 355) reads these
numbers here and makes each jump with the real controller, from a standstill.
A slope (`/`, `\`) starts on open floor at its low side and meets ground at its high side;
stack them diagonally for a taller ramp, with ground under each. Walkers turn at a ramp.
- Moving a pickup (any item, chest or shard) changes its id, which is its room and cell. Add
  the move to `GameState.MOVED_PICKUPS` so a save that took it doesn't find it again (pass 213).
- A find meant to be out of reach until an ability (the `*_SECRETS` lists) needs a real gate.
  The checker's jumps are short of real ones, so it can never prove "out of reach". Use a
  gate tile (veil, bramble, cracked stone, amber), or for the Featherstep Boots a rise of 5 rows or
  more over every footing within reach, with no wall to climb (a single jump tops out at 4.5),
  and prove it with a real jump in `tests/` (pass 219).
