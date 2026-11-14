# Pass 562: Gnarlmaw's body is dressed and bowed

## Category

Art cohesion and bosses, from the independent grade taken after pass 560 (4.9/10): "Gnarlmaw reads
as one husk segment stamped about twenty times in a straight line with three flat sacs." Pass 561
named it as the next item.

No note from Sean was new. The queue's first item (lighting and depth) is parked for a watched
session. The PixelLab art loop stays **gated** on Sean: three guardian bases (Haar Wyrm, Thane
Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations were spent,
and no Autosprite credits. The hosted workbench is still down (its Vercel Blob store is
suspended); it stays under "stuck" for Sean. `README.md`'s playtest link already points at
`sagedragoon79/Yldenfall`.

## Audit

- Pass 551 gave every ring its own size, tilt and shade, and the grade still saw a stamp. Size,
  tilt and shade do not change an outline: all 22 rings were one sprite, so the top edge of the
  body was 22 copies of one arc.
- The line was straight: the body wiggled 2 px to each side of its rail, on a wave six rings long.
  That reads as a shiver, not a bend.
- The three tail sacs were one sprite at one size.
- The plate and the tail are one Autosprite still each (`art/autosprite/gnarlmaw/`), packed by
  `tools/art/autosprite_parts.py`. New looks can be drawn over those stills in code, so the pass
  costs no credits.
- Not done here: rimming the hero against the body. Rim light on figures is parked for a watched
  session; the plates already sit back in the dark (pass 551).

## What was built

- **`tools/art/autosprite_parts.py`**: `--dress spines|moss|sting` makes a second look of a still.
  `spines` shrinks the part in its cell and stands three bark thorns, raked back, along its top, in
  the part's own colours. `moss` lays tufts of moss (the master palette's moss ramp) over the crest
  and back, clipped to the part. `sting` shrinks the part and adds a blunt horn behind it. `spines`
  and `sting` print the `height`, `lower` and `feet_x` for the manifest, so the round part keeps
  the size and the middle it has on the plain sheet.
- **`art/autosprite/gnarlmaw/`**: `plate_spined.png`, `plate_mossy.png` and `tail_tip.png`, each
  with its two states (plain and cracked, or cold and hot), and their manifest entries.
  `tools/art/castgen.py` lists the three as animations. Only Gnarlmaw's sheet was regenerated.
- **`scripts/bosses/gnarlmaw.gd`**:
  - `RING_LOOKS` gives each of the 22 body rings a fixed look: thorns on the swell behind the neck,
    moss gathering toward the tail, no look three rings in a row. `ring_look(i)` names the sprite.
  - The tail's sacs are drawn at 1.14, 1.05 and 1.0 (`TAIL_SCALES`), and the last is the horned tip.
  - `bow_reach(i, stuck)`: the wave is now about 12 rings long and swings the middle of the body
    6 px to each side of the rail. The head and the tail keep their 2 px, so the bite and the weak
    point stay where the rail puts them. Stuck in a wall every segment thrashes 4 px or more, as
    before. The hitboxes ride the wave with the plates.
- Design bible 8.1 says all of this.

## Judged by eye

The arena at frames 330 and 345, at 1x and a 2x crop of the body. The top edge of the body is now
broken by thorns and moss caps, the line humps in the middle, and the tail reads as three sacs of
three sizes ending in a horn. At 1x the thorns are small (about 4 px) but they break the row of
identical arcs. The first draft of the moss read as glossy green bubbles and the thorns as flat
knives; both were redrawn (matte tufts, shorter and stouter thorns) before import.

What it does not fix: the hero is still dark maroon on dark brown when he stands in front of the
body, and each ring still shows the same pale belly legs along the floor.

## Tests

`tests/test_boss.gd`: `test_gnarlmaws_body_is_dressed_and_bowed` (56 checks): three looks, each on
four rings or more, no run of three; the looks are on the sheet in two states and differ from the
plain part; the thorns stand above the plate and the horn behind the sac while the round part keeps
its size; the sacs shrink toward the tip; the bow's reach at the middle, the head and the tail; and
in a real lunge the rings in the room span 10 px or more across the rail while the tail stays in
its lane. `test_gnarlmaws_rings_are_not_one_plate_repeated` now allows a tail sac to be drawn
larger than its sprite.

Mutation check: with `BOW_BODY` at 2, every ring plain and the tip drawn as a plain sac, six checks
fail (three looks, the run of three, the tip is the plain part, the horn, the swing at the middle,
the span in a real lunge).

## Resumed

An app restart cut the pass off during the full suite. It was resumed on 2026-11-14: `main` (#633,
#634) was merged in, the arena was shot again at frame 330 and looked at, and the suite was rerun:
15269 checks passed and one failed, `test_every_room_loads_and_settles_inside_the_budget`
(`spires/sky_steps` at 21.51 ms a frame). That is a wall-clock budget, the PC was busy with other
work, and the pass touches nothing in the Spires; run alone the test passes (3 checks).

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Gnarlmaw's body is no longer one stamp. The independent grade is the real measure. |
| Bosses | 10 | 99 | The body bows 6 px at its middle; the hitboxes follow. Tells and timings unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

The next independent grade is due after pass 565, or after the next art pass, and uses fight
frames. Of the queue: the Boughs' painterly foliage against the pixel tiles, then one-template
rooms, then Vorrhallow's stillglass shards. The Haar items wait until the hydra and steam branches
merge; the Blinkhop waits for a free base slot.
