# Pass 518: volumetric light shafts rake the open air behind the play field

## Category

Depth and lighting, from the queue — Sean's own 2026-11-07 lighting-and-depth note (queue item 0)
and the independent grade's recurring "flat lighting / depth collapse" and "dark empty upper
backdrop void". Sean's reference shots for the room-density redesign (bible 12.0 / the room-density
note) call for "deep layered backgrounds with light shafts and drifting motes": the motes have
shipped since early on (`Motes`), the **light shafts** are the piece that was missing.

The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane Vorrund,
Drowned Warden) wait for his OK, the limit of three, and no new note frees a slot. Of Sean's
lighting/depth note, the per-zone fog (505), colour grade (507), room-light pools (509), foreground
silhouettes (510) and ridge layer (511) have all shipped; **rim light on figures** and a **second
foreground band** are parked for a watched session (combat-readability call). This pass takes the one
remaining **unattended-safe** slice of that note — its "windows / light sources" that the radial
room-light pools did not cover — as a fully-testable, behind-the-play-field, no-readability-risk
overlay.

## What this adds

`LightShaft` (`scripts/world/light_shaft.gd`, bible 12.17) draws a few broad, soft, angled god-ray
beams down from the top of each room, in the zone's own light colour:

- **Behind the tiles** (`z_index = -1`), so solid geometry occludes a beam and it shows only in the
  open air, raking over the backdrop and cut off by any wall or platform in front of it. Every actor
  (player, foes, projectiles, at `z >= 0`) also draws over the beams, so — like the room-light pools
  (12.10) and the drift pockets (12.16) — a shaft never falls across a foe or a telegraph.
- **Additive and faint** (`PEAK` = 0.085). A beam tints the air; it never washes anything out.
- **Per-zone light** (`SHAFTS`, mirroring the `ZONE_HAZE`/`GRADE` families): warm gold in the
  hearths, green-gold canopy sun in the woods, pale cool light in the springs, violet crystal light
  in the Evercrown/Vorrhallow, bare pale light in the grey stone. Bright colours (high luminance) so
  the additive draw adds light; each pair leans opposite ways; a zone with no entry (the gym) gets none.
- **Stable, not a comb.** Feathered strips (no hard side edge) in vertical bands that brighten toward
  the top (`along_alpha`); beam count scales with room width and centres are jittered off the even
  spacing, seeded by the room id, so a room's shafts are the same every frame and save but never a
  dead row. Geometry built once (12.3); a slow unison breathe is a `self_modulate` tween, no redraw.

Wired into `Room` right after the tile layer and the room-light overlay. Judged by eye at 1x and 2x
in `hearthroot/plaza`, `heartwood/dwarf_hall`, `haar/spring_of_haar` and `evercrown/throne`: the
shafts fill the previously dark upper air with the zone's own light and the play field reads clear in
front of them. Covers the queue's "dark empty upper backdrop void" (part (a), the far-layer region)
alongside pass 516's far-sky motes.

## Combat is untouched

The shafts sit behind the tiles and every actor; they are additive and capped low. Foes, hazards and
telegraphs draw over them with the contrast they read by. `tests/test_light_shaft.gd` drives the pure
geometry — beam count within its width range, centres inside the margins and deterministic-but-jittered,
`across_alpha` bright-core-to-feathered-edge, `along_alpha` soft-head-to-dimmed-tail (mutation-checked:
a flat profile fails the ceiling/floor guards), and the per-zone light bright with opposite-leaning
pairs.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; shafts stay behind the tiles and every actor (`z = -1`), additive and capped, so foes and telegraphs read over them. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 97 | The dark upper air of tall rooms now carries the zone's own raking light — the "light shafts" Sean's reference shots call for. Builds on the fog (505), grade (507), room-light (509), foreground (510), ridge (511), masonry (514/515), far-mote (516) and drift-light (517) depth work. The empty band above the far layer and the HD hero/guardian bases remain open. |
| Bosses | 10 | 99 | Unchanged — a boss arena gets the same safe behind-the-field light as any room. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 98 | One more static overlay per room, built once (no per-frame redraw); the breathe is a modulate tween. Bounded quad count per room. |
| Story and world | 5 | 99 | Unchanged — light through windows and canopy fits every zone's fiction. |

Weighted: 98.6.

## Next

Pass 519: the art loop stays **gated** on Sean (three guardian bases wait, the limit). The next
code-first grade items are the remaining **stamp repetition** (the Spires brick field and Hearthroot's
distant buildings — a third masonry/variation sweep) and the **zone-to-zone style incohesion** between
the painterly Market/Plaza and the flat tile-grass zones. Sean's **rim light on figures**, a **second
foreground band**, and the **empty band above the far layer** all still want a watched session for the
combat-readability call, not an unattended pass.
