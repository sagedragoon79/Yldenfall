# Pass 512: carved sign faces instead of the placeholder scribble card

## Category

Art cohesion, from the queue (independent grade, pass 504), not the rubric rotation. The PixelLab art
loop stays **gated**: three guardian bases (Haar Wyrm, Thane Vorrund, Drowned Warden) wait for Sean's OK,
the limit of three, and no note frees a slot, so the headline guardian/hero work cannot move even though
`PIXELLAB_API_KEY` is now set on this PC. Pass 511's named next item — the midground-variant masonry pass —
would touch a dozen hand-painted backdrop painters judged only by eye; this pass instead takes the
**sign/tablet** queue item, which is self-contained, fully testable, and a clear win: a pervasive
"un-authored UI stub" the grade flagged in five rooms.

Sean's own top queue item (lighting/depth) is parked on its last piece, **rim light on figures**, which a
run of passes (505/507/509/510/511) left as the one piece best landed when combat readability can be
watched, not in an unattended loop pass.

## What was built

The lore tablet — every sign in the world is a `LoreTablet` (bible 11), 142 of them — was a plain grey
card with **four identical flat horizontal bars** for "writing". The independent grade (pass 504) saw it
in five rooms (shots 1, 2, 5, 6, 7) and called it an un-authored UI stub left in the world: the same
meaningless scribble, repeated. It is now a **carved stone sign** (`scripts/world/lore_tablet.gd`,
bible 12.13):

- **A bevelled slab.** The stone face is lit along the top and left edges and shadowed down the right and
  bottom, so it reads as cut stone with depth instead of a flat card.
- **Engraved runes, seeded per sign.** A new pure function `LoreTablet.rune_strokes(seed)` lays short
  grooved strokes — upright stems (some with a cross-tick), short bars and dots — in two or three lines
  across the face, read left to right with word gaps, each line opening with a stem so it reads as
  writing. The seed is a hash of the sign's own text (`_seed_text`, every variant line joined), so each
  distinct sign carves its own marks and the same stamp no longer repeats across rooms; a flag-swapped
  sign (bible 11, pass 251) keeps its carving. Each stroke is a dark groove with the tan inlay (`GLYPH`)
  over it, so the marks read as incised.

`_draw()` renders from the tested layout (the EdgeShade pattern, 12.3: the drawing is driven by a pure
rule). No behaviour changed — reading, the flag-driven variants, the prompt, `z_index -1` and the
`tablet_read` sound are all untouched — so the existing tablet tests (`test_rooms.gd`) stay green.

Verified by eye in the Boughs (`leaf_landing`, the sign at tile 24,19): at gameplay 1x it reads as a small
carved marker; zoomed, the bevelled grey slab carries rows of tan engraved marks (stems, ticks, dots) —
authored writing, not filler. Combat is untouched: the sign is background decor behind the play field.

## Tests

`tests/test_lore_tablet.gd` (3 new tests, registered in `test_runner.gd`) holds `rune_strokes` to its rule
across 40 seeds:

- **Within the face.** Every stroke rect stays inside the slab's writing face (`FACE`).
- **Reads as engraved lines.** The runes fall on at least two lines, each opening with an upright stem
  (taller than wide) — the discriminator against the old row of flat bars, which had no verticals.
- **Stable and per sign.** The same seed carves the same runes (deterministic), and two different signs
  carve different runes (no repeated stamp).

**Mutation-checked:** turning the upright stem back into a flat horizontal bar (the old bug) fails both the
within-face and the engraved-lines tests; collapsing the layout to one line fails the engraved-lines test;
shifting a stroke off the face fails the within-face test. (Verified by patching and running the filtered
suite; all three mutations fail, reverted.)

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; the sign is `z_index -1` background decor, no effect on the play field. |
| World and level design | 15 | 99 | Unchanged. |
| Art cohesion | 15 | 95 | A recurring placeholder — the grade's un-authored scribble card in five rooms — is now a carved sign with per-sign engraving, on top of the fog (505), grade (507), room-light (509), foreground (510) and ridge (511) depth work. The hero and guardian HD bases remain the open gap (gated art loop). |
| Bosses | 10 | 99 | Unchanged; the thirteen arenas that hold tablets read the same, now carved. |
| Systems | 10 | 99 | Unchanged; reading, variants and the pause-on-read behaviour are untouched. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | The runes are laid out once per sign and cached (recomputed only when the variant set changes); `_draw` renders a handful of small rects. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.4.

## Next

Pass 513: the art loop stays **gated** on Sean (three guardian bases wait, the limit; the PixelLab key is
now set, so the moment a base is approved the Haar Wyrm animation can begin). The strongest non-art
code-first items left on the queue are the **midground-variant masonry** pass (vary `<zone>_mid.png` and
the far layers' masonry so the backdrop brick/column field stops reading as one repeated stamp — scatter
wear, shade variation and broken courses; grade pass 504) and the **haar/sunken low-contrast** pass (the
swamp and underwater zones collapse into grey-green/grey-teal so platforms do not separate; grade pass
505). Sean's **rim light on figures** is the highest-value lighting piece but wants a watched session, not
an unattended pass.

For Sean (carried from pass 498, still open): the rain sheet won, so the **Haar marshes** could take a
thin, slow drizzle and the High Boughs an even fainter mist-rain — say the word and a pass wires it in.
