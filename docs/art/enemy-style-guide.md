# Yldenfall enemy and boss style guide

The rules every foe and guardian sheet is made and reviewed against, so threads that work on
different foes at the same time end with one look. It sits under design bible 12 (art style)
and 13 (asset production); where they differ, the bible wins and this file is fixed to match.

The target is **the PixelLab hero** (bible 13.5): HD pixel art at 2x density, a full dark
outline, top-left light, a limited palette per sheet. The foes made in Autosprite (Hornet, Rot
Dwarf, Iron Dwarf, Foreman, Durgan, Gloamweaver) already sit at that level. The code-drawn foes
(flat rectangles from `draw_rect`) and the 1x rig sheets are what the art loop replaces.

The reference foe is the **Shade Knight** (`shade_knight`, art loop pass 1): read its manifest
entry, its PixelLab sources in `art/pixellab/enemies/shade_knight/` and its `_draw` before
starting another foe.

## 1. Design

- **Original.** Yldenfall is an original game. Design each foe from its entry in bible 7 and
  its script's header comment, never from another game's monster. Name nothing after one.
- **One idea per silhouette.** A foe must read as itself in solid black at 1x: what it is,
  which way it faces, and where its weapon or mouth is. The weapon or striking part stands
  clear of the body, never painted over the torso.
- **Zone colours.** Each foe wears its zone's mood (bible 12.2: Heartwood brown, amber and
  fungus cyan; Hollin Tower iron, rust and lamp orange; Haar grey-green, bone and lantern
  yellow; High Boughs leaf green and sky blue; Carillon storm violet and gold; Vorrhallow
  flooded teal and stillglass magenta; the Evercrown black-violet, cyan and blood red), with
  one hostile accent (eyes, a glow, a blade's edge) brighter than anything else on it.
- **Corruption** (the Evercrown's grown-through foes) is a code tint and a code growth
  (`CorruptionGrowth`). Do not draw stillglass into a foe's base art unless the foe is made
  of it (Crystal Dwarf, Glass Slug).

## 2. Scale

World pixels; sheets are drawn at 2x (`"density": 2`), two sheet pixels per world pixel.

| Class | Figure height (world px) | Examples |
|-------|--------------------------|----------|
| Small (fliers, crawlers) | 14 to 28 | Blinkhop, Hornet, Gear Bat, Mothling, Grub Lump |
| Standard | 30 to 48 (the hero is 46) | Rot Dwarf, Shade Knight, Bark Knight, Leaf Mantis, Marsh Hag, Storm Harpy, Spire Sentinel |
| Large | 48 to 64 | Iron Dwarf |
| Mini-boss | 64 to 96 | the Foreman, the Bark Captain |
| Guardian | 80 and up; past about 120, built of parts | Durgan, Gloamweaver, the Haar Wyrm, Skyrend |

- The manifest's `"height"` is the figure's height in its reference frame, without the
  outline. Match the body to the foe's hitbox (`body_size`): the art may overhang by its
  weapon, shield or wings, not by its torso.
- **Never upscale a source.** A source figure must be at least twice its world height in
  pixels. A PixelLab character canvas is 256 px at most, so a figure up to about 110 world px
  is one sheet; anything taller is a rigged set of parts, each from its own 256 px source
  (bible 13.3, Bosses).
- **A weapon the game measures fixes the scale.** Where a weapon is also a hitbox or a ledge
  (the Bark Knight's rooted lance at `LANCE_Y`), pick the height that puts the drawn weapon on
  it (art pass 4: the knight is 36, his hitbox 32, so he sits in Standard, not Large). A weapon
  longer than the 256 px canvas is drawn out from the clip's own pixels on a wider frame
  (`tools/art/bark_lance.py`), never code-drawn over the art.

## 3. Rendering

These come from the importer (`tools/art/autosprite_import.py`), not by hand, so every sheet
gets them the same way:

- **Outline:** the importer drops the source's own soft rim and draws the master 1 px full
  outline. Ask PixelLab for "single color black outline"; never draw a coloured glow outline.
- **Palette:** new art for the 2x redo is drawn in the 96-color master palette (bible 12.2, Sean
  2026-11-07): pass `art/palette/master.json` as `target_palette` to every PixelLab call that takes
  it (`master.png` as `color_image` where that is the only option). Sheets made before the redo keep
  their own palette, `"colors": 40` to `56`, cut from the reference clip, plus the ramps they name,
  until they are redrawn. 96 at most (a test). No pure black or white.
- **Light:** top-left key light. A dark foe (night armour, black chitin) gets a `"gain"` and
  a `"rim"` in its zone's light colour, as the Iron Dwarf has, so it stands off dark walls.
- **No dithering** and no painted motion blur on bodies. A smear frame for a fast strike is
  allowed (bible 12.4), one frame, the body's own colours.
- **Facing (2026-11-06):** anything that **moves** — walk, run, every attack, jumps — is a
  strict east/west profile: the source faces right (east, the face or mouth showing on the right,
  never a back turned to the camera), and the game mirrors it for west. A **still** animation
  (idle, rest, talk, a guardian's intro or taunt) may instead stand in the **south-east
  three-quarter stance**, turned toward the camera, which reads warmer and shows the face. A
  character that has a still three-quarter clip also gets a short **turn clip** that bridges the
  two facings (see 6, step 1b). West is always east mirrored. See 6, step 1a.
- **Effects stay out of the art.** Projectiles, spells, mist, sparks, glows that pulse,
  shockwaves and the tell's white flash are code or shader, drawn over the sheet. If a clip
  bakes one in, cut it at import (`"erase"`, `pick` around it). A glow that is part of the
  body (eyes, a lamp, crystal) stays in the art and may also get a code glow on top.

## 4. Animations

Every foe has these. Names are the sheet's animation names; the foe's `_draw` maps its states
to them. Frame counts are what ships after `pick`, not what was generated.

| Animation | Frames | fps | Loop | Notes |
|-----------|--------|-----|------|-------|
| `idle` | 4 to 8 | 6 to 8 | yes | Breathing or hovering. Fliers: wingbeat, 12 to 24 fps. |
| `walk` (or the foe's move: `crawl`, `fly`, `swim`) | 6 to 12 | so the feet keep pace | yes | fps = frames x speed / stride: no sliding feet (bible 13.5, run speed). |
| `<attack>_tell` | 2 to 4 | 6 to 10 | yes | The wind-up pose, a clear change of silhouette from idle (drawn back, crouched, rearing). It must hold for the whole tell, at least `Enemy.MIN_TELEGRAPH` (0.35 s). |
| `<attack>` | 2 to 4 | 14 to 20 | no | The strike. The frame with the most reach shows while the hitbox is live. |
| `recover` (or `winded`, `stuck`) | 1 to 3 | 3 to 6 | either | The opening after the blow: low guard, weapon down. This is when the player punishes, so it must look open. |
| `hurt` | 1 to 2 | 10 | no | A flinch away from the blow, shown while the foe is in hitstun. |
| `stagger` | 1 to 2 | 3 | yes | Parried or broken: reeling back, guard wide. |
| `death` | 3 to 6 | about 10 | no | A collapse that ends low. The dissolve (`Enemy.DISSOLVE`, 0.45 s) plays over it, so it should be most of the way down by 0.3 s. |

- Bosses add their phase looks and named attacks, each with a tell and a strike, and play
  their own death before they hide (bible 7, bosses).
- One clip may feed several animations (a walk's first frame as a held `recover`), and a
  still may be held across a whole state.

## 5. Telegraphs

Bible 7: every tell is a pose, a flash and a sound, at least 0.35 s.

- **The pose is the art's job.** The tell animation must not look like idle or walk: it is
  the frame the player learns. Draw the weapon back, the body coiled.
- **The flash is the code's job.** `draw_sheet(..., white)` pulses the foe white
  (`telegraph_pulse()`); never draw a white or flashing frame into the art.
- **A charge glow** (the Shade Knight's blade point, an eye lighting up) is code, drawn at a
  point the art gives in the frame's metadata or at a fixed offset, so it tracks the pose.

## 6. Making a foe with PixelLab

What worked for the hero and the Shade Knight, cheapest first:

1. **The base character:** `create-character-v3`, `"view": "side"`, `"image_size"` 256x256 (or
   the smallest square that holds the figure at 2x its world height), `"outline": "single
   color black outline"`, `"detail": "high detail"`, `template_id` `mannequin` for bipeds
   (quadrupeds: `dog`, `cat`, `horse`, `lion`, `bear`). About 9 generations. Describe colours,
   materials and the weapon; say "side-scroller game enemy, full body". Use the `east`
   rotation: that is the profile. Download the rotations with `GET characters/<id>/zip` (the
   rotation URLs it lists are refused through the proxy).
1a. **Check the facing before any clip.** PixelLab's rotation names are not to be trusted:
   on many bases the image saved as `east` is a three-quarter view turned away from the camera
   (we see the back, the hood or the shell, not the face), and the true side profile is under
   another name (`south`, `south-east`, `north-east`) or only in `west`. A clip asked for
   "east" from such a base walks away into the screen (the Grub Lump, Marsh Hag, Mothling, Sap
   Spitter and Silt Adder shipped that way and were remade in art pass 7). Lay all eight
   rotations side by side with `west` mirrored and pick the one that shows the face (or mouth,
   spout, eye) in profile on the right. If none does, mirror `west` (it is usually the cleanest
   profile). Save that as `base/guard.png` and start every clip from it (step 2a). A
   three-quarter view **turned toward the camera** (south-east, south-west) is fine for a still
   pose; one **turned away** (the back, hood or shell to us) is not, in any animation.
1b. **Turn clips bridge a three-quarter still and the moving profile (2026-11-06).** When a
   character rests or idles in the south-east three-quarter stance but moves in strict profile
   (Facing, section 3), generate a short **turn clip** of 2 or 3 frames from the three-quarter
   base (`characters/animations`, about one generation). The foe's `_draw` plays it forward
   (still -> moving) as the character starts to act and backward (moving -> still) as it settles.
   Do not hand-fix the drift PixelLab leaves in turn frames: Sean cleans those up. Copy each turn
   clip's frames to `art/cleanup/<character>/turn/`, list the new ones on the workbench under
   "done" as ready for his cleanup, and leave the raw frames where they are. The importer prefers
   `art/cleanup/<folder>` over the raw PixelLab output (`tools/art/pixellab_sheets.py`), so a
   cleaned frame ships the moment it lands; **never overwrite or regenerate anything already in
   `art/cleanup`.**
1c. **Prompt craft for props and glows (2026-11-06).** PixelLab misreads props badly — asked for
   "a stalk with an orb on its end" on a figure's head, it once drew a light bulb growing out of
   the head. Write prop prompts so it cannot:
   - **Say what holds each prop and where it sits, one prop per sentence.** Sean's wording that
     worked on the Spring Eel: "an anglerfish-style stalk with a dangling glowing orb".
   - **Scope a comparison to the part, never the whole body.** Write "`<creature>`-style
     `<part>`" (an "anglerfish-style stalk"), never "like a `<creature>`" or "like an anglerfish"
     — that turns the whole figure into that creature (the eel came out a long skinny fish).
   - **Keep a part's words physical** (dangling, curving, fleshy, bony), so the model reads a body
     part and not an object.
   - **Say what must stay clear** when a prop could stray onto it ("nothing on his head").
   - **Give a glow a colour** (lantern yellow, cyan), never the words *light*, *lamp* or *bulb*.
   - **Check every base and frame for stray or moved props** before anything goes to Sean. If a
     prop still wanders after one retake, generate the figure **without** it and add it with
     PixelLab's inpaint or the free `pixelart_workbench` — do not keep rerolling.
   - **Name only the part the sprite is, not the whole multi-part creature (2026-11-06).** The Haar
     Wyrm is a three-headed serpent whose heads, necks and coil are drawn in code; a base prompt for
     "a three-headed serpent's head" drew two and three heads fused together (art pass 9). Describe
     the single part the sprite stands in for — "a single dragon-serpent head", "one head only, no
     second head anywhere" — and state the count as one, or the model draws the whole beast. The same
     holds for any limb or part a rig supplies: ask for the one piece, not the animal it belongs to.
1d. **Sean approves each base before animation (2026-11-06).** For a new or redesigned character,
   make **only the base first** — the east profile and the south-east three-quarter stance, a few
   generations — and generate no animations (turns included) until a workbench note from Sean
   approves it. Save one review picture to `shots/<character>-base-for-approval.png` (both views at
   1x and 4x, beside the current in-game sprite and the hero for scale), run
   `python workbench/deploy.py` (`PYTHONUTF8=1`) so it shows on the hosted Shots tab, and put
   "Waiting for Sean's OK on the `<character>` base" under `stuck`. A note asking for changes means
   a retake and a new review picture. While waiting, make bases for the next characters in the
   order (no more than three waiting at once) and otherwise do non-art work.
2a. **One model for every state.** Clips made from the base can drift to a second model (the Shade
   Knight's shield jumped from behind his body to in front). Pick the frame that best shows the
   foe as it fights, save it as `base/guard.png`, and make the clips from it
   (`"custom_start_frame"`, with `initial_pose` describing it).
2. **Clips:** `characters/animations`, `"mode": "pixminimax"`, `"directions": ["east"]`, frame
   count a multiple of 4 (8 or 12 is plenty): 1 generation for 8 frames, 2 for 12. End every action
   with "He stays in strict side profile facing right the whole time and never turns toward
   the camera." Give `subject_description` (300 characters at most). For a held pose (a tell,
   a recover), ask for the motion into it and pick the end frames.
3. **States** (`create-character-state`, about 25): only for a second look of the same foe
   (Bark Knight with and without bark, a phase change).
4. **Log** every call: `tools/art/pixellab.py` writes `art/pixellab-ledger.csv`. Sources go to
   `art/pixellab/enemies/<foe>/` (bosses: `art/pixellab/bosses/<boss>/`).

Then:

5. Add the foe to `ENEMY_SHEETS` in `tools/art/pixellab_sheets.py` and run it: it packs the
   clips into strips in `art/pixellab/sheets/<foe>/` and clears grey slabs.
6. Add its entry to `art/autosprite/manifest.json` (`dir`, `height`, `colors`, `ramps`,
   `density` 2, `reference`, and per animation its strip, `pick`, `fps`, `loop`, `anchor`).
7. Give it a placeholder sheet in `tools/art/castgen.py` (`autosprite_only`, listing every
   animation) if it had no rig sheet, and run `python3 tools/art/castgen.py`, then
   `godot --headless --import`.
8. In the foe's script, draw it with `draw_sheet(sheet, anim, t, white)`, keeping its code
   glows on top, and keep `wash`/`drawn_white` working (the tell-flash test reads it).

Autosprite (22 credits left) is only for a foe PixelLab cannot do after two tries.

## 7. Review

Before a foe merges, check it in the lineup and in its room:

- `xvfb-run -a godot --path . res://tools/art/lineup.tscn -- --out=OUT.png --only=<foe>`
  draws the foe in every state it sets, at 2x. Compare it beside the hero and its zone's
  other foes: same outline weight, same pixel size, palette in the zone's mood.
- `tools/screenshot.sh` in a room where it lives: it must read against the zone's walls
  (grayscale check, bible 12.3).
- Every animation faces right with the face in view: compare its first frame with the base's
  `west` view mirrored (6, step 1a).
- Every state in the foe's script shows an animation that fits it; no state falls back to a
  frame that contradicts it (a strike drawn during a tell).
- Before and after images go in the project files, `art-loop/<foe>/`.
- Tests pass, including `test_every_foes_tell_flashes_it_white` and the sheet palette cap.

## 8. Budget

PixelLab is 5,000 generations a month (Tier 2). The Shade Knight cost 27: 9 for the base and 1 or
2 a clip, his first takes included. Plan about 30 for a standard foe and 60 to 100 for a guardian's parts. Check
`python3 tools/art/pixellab.py balance` before a batch and leave a margin for retakes.
