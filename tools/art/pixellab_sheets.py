#!/usr/bin/env python3
"""Packs PixelLab clips (one PNG per frame, as tools/art/pixellab.py saves them) into the strip
sheets the sprite importer reads (tools/art/autosprite_import.py), so PixelLab characters go
through the same import as Autosprite ones: scale, palette, outline, rim light and anchors.

Each strip is one row of 256 px cells, frames in order. The manifest entry points its "dir" at
the strip folder (relative to art/autosprite/, so "../pixellab/sheets/hero_base") and picks
frames from the strips as usual.

Usage: python3 tools/art/pixellab_sheets.py      rebuilds every strip in SHEETS
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "art" / "pixellab"
# Sean's hand-cleaned frames. A clip folder here (same relative path as under art/pixellab/) wins
# over the raw PixelLab output, so a frame he has cleaned ships without touching the raw frames.
# Turn clips in particular land here for cleanup (enemy style guide, step 1b).
CLEANUP = ROOT / "art" / "cleanup"
OUT = SOURCES / "sheets"
CELL = 256

# sheet -> {strip file: clip folder under art/pixellab/ (frames 00.png, 01.png ...)}
CLIPS = (("idle.png", "idle"), ("run.png", "run"), ("walk.png", "walk"), ("jump.png", "jump"),
         ("pogo.png", "pogo"), ("delvers_pick_swing.png", "swing"), ("slash1.png", "slash1"),
         ("slash2.png", "slash2"), ("slash3.png", "slash3"), ("slash_up.png", "slash_up"),
         ("dash.png", "dash"), ("wall.png", "wall"), ("hurt.png", "hurt"), ("death.png", "death"),
         ("drink.png", "drink"), ("cast.png", "cast"), ("throw.png", "lthrow_l1"), ("throw_up.png", "lthrow_up_l1"),
         # The crouch (design bible 6.15): its held pose and its one low cut. No set has them yet
         # (the placeholder squats the idle until the 128 px hero's art), so they pack as they land;
         # add "crouch" and "crouch_slash" to the set's art/autosprite/manifest.json entry then.
         ("crouch.png", "crouch"), ("crouch_slash.png", "crouch_slash"))
SETS = ("base", "leather", "riveted", "plate", "battle", "battle_helm")

# The bare elf and the armor tiers (character states of Sean's elf, design bible 13.5), each with
# the cloak drawn in a key green the game dyes: clips made from the set's cloaked state, its state
# holding the Short Sword (attacks and the left-hand Rune Dagger throw) and holding the Delver's Pick
# (pogo and swing).
SHEETS = {"hero_" + s: {strip: f"hero/{s}_cloak/{clip}" for strip, clip in CLIPS} for s in SETS}
# Each set's four attacks again with the other blades (Sean: swords are drawn into the attacks),
# from its state holding that blade: sheet "hero_<set>_<blade>".
for _set in SETS:
    for _blade in ("long_sword", "broad_sword", "severance"):
        # The set's own idle too, as the importer's reference for scale (it never plays from here).
        SHEETS[f"hero_{_set}_{_blade}"] = {"idle.png": SHEETS[f"hero_{_set}"]["idle.png"], **{
            f"{clip}.png": f"hero/{_set}_cloak/{_blade}/{clip}" for clip in ("slash1", "slash2", "slash3", "slash_up")}}
        # The Rune Dagger flicked from the left hand, the blade kept in the right (Sean, 2026-10-30).
        SHEETS[f"hero_{_set}_{_blade}"].update({"throw.png": f"hero/{_set}_cloak/{_blade}/lthrow_l1",
                                                 "throw_up.png": f"hero/{_set}_cloak/{_blade}/lthrow_up_l1"})

# Each set's block, from its state holding each shield up to guard (the shields are drawn in):
# sheet "hero_<set>_<shield>", the block and the set's idle as the importer's reference.
for _set in SETS:
    for _shield in ("small_shield", "large_shield", "magic_shield"):
        SHEETS[f"hero_{_set}_{_shield}"] = {"idle.png": SHEETS[f"hero_{_set}"]["idle.png"],
                                             "block.png": f"hero/{_set}_cloak/{_shield}/block"}

# Retakes where the first take's cloak dropped out of the frame (drawn as an empty outline).
SHEETS["hero_plate"].update({"run.png": "hero/plate_cloak/run_r1", "walk.png": "hero/plate_cloak/walk_r1",
                             "drink.png": "hero/plate_cloak/drink_r2", "hurt.png": "hero/plate_cloak/hurt_r1",
                             "slash1.png": "hero/plate_cloak/slash1_r1"})
SHEETS["hero_riveted"]["walk.png"] = "hero/riveted_cloak/walk_r2"
SHEETS["hero_battle_helm"].update({"walk.png": "hero/battle_helm_cloak/walk_r2", "slash2.png": "hero/battle_helm_cloak/slash2_r1"})
SHEETS["hero_battle_helm_severance"]["slash1.png"] = "hero/battle_helm_cloak/severance/slash1_r1"
# The Kite Shield again on every set but the base, to match its crimson face and silver rim
# (the first takes drew it plain steel or dark), and blocks whose cloak dropped out.
for _set in ("leather", "riveted", "plate", "battle", "battle_helm"):
    SHEETS[f"hero_{_set}_large_shield"]["block.png"] = f"hero/{_set}_cloak/large_shield/block_r1"
for _set in ("leather", "battle"):
    SHEETS[f"hero_{_set}_magic_shield"]["block.png"] = f"hero/{_set}_cloak/magic_shield/block_r1"
SHEETS["hero_base_magic_shield"]["block.png"] = "hero/base_cloak/magic_shield/block_r2"

# Foes and guardians (the art loop, docs/art/enemy-style-guide.md): sheet -> {strip: clip folder}.
# The slab cleaner runs on them too; a foe whose hide or armour is a flat dull grey goes in
# NO_SLAB_CLEANING (check a frame's opaque pixel count before and after when adding one).
ENEMY_SHEETS = {
    # Clips made from his guard pose (shield up in front, base/guard.png) so every state shares
    # one model; the stagger and the death are from the base character's own east view.
    "shade_knight": {f"{clip}.png": f"enemies/shade_knight/{folder}" for clip, folder in
                     (("idle", "idle_g"), ("walk", "walk_g"), ("thrust", "thrust_g"), ("cut", "cut_g"),
                      ("winded", "winded_g"), ("stagger", "stagger"), ("death", "death"))},
    # Art loop batch 1 (art pass 2): each from its base character's east view, one model per foe.
    # Art pass 7: these five foes' "east" views turned their backs to the camera, so their clips
    # (the *_s folders) were remade from base/guard.png, the base's west view mirrored.
    "sap_spitter": {f"{c}.png": f"enemies/sap_spitter/{c}_s" for c in ("idle", "spit", "death")},
    "grub_lump": {f"{c}.png": f"enemies/grub_lump/{c}_s" for c in ("crawl", "rear", "death")},
    # The roost is the folded-wing clip turned upside down (roost_hang): it hangs from the ceiling.
    "gear_bat": {f"{c}.png": f"enemies/gear_bat/{f}" for c, f in
                 (("fly", "fly"), ("windup", "windup"), ("roost", "roost_hang"), ("death", "death"))},
    "minecart_rider": {f"{c}.png": f"enemies/minecart_rider/{c}" for c in ("roll", "rev", "charge", "crash", "death")},
    "silt_adder": {f"{c}.png": f"enemies/silt_adder/{c}_s" for c in ("float", "strike", "death")},
    # Art loop batch 4 (Carillon): each foe's clips start from one frame of its base so every
    # state shares one model. The Thunder Beetle's spent is made from its charge's open-cased frame.
    "thunder_beetle": {f"{c}.png": f"enemies/thunder_beetle/{f}" for c, f in
                       (("idle", "idle"), ("walk", "walk"), ("charge", "charge"), ("spent", "spent2"),
                        ("hurt", "hurt"), ("death", "death"))},
    "storm_harpy": {f"{c}.png": f"enemies/storm_harpy/{c}" for c in
                    ("hover", "windup", "throw", "recover", "hurt", "death")},
    # The Spire Sentinel's base came out as steel plate; base/guard.png is it recoloured to pale
    # lilac shrine stone (tools/art/stone_tint.py), and its clips were made from that frame.
    "spire_sentinel": {f"{c}.png": f"enemies/spire_sentinel/{c}" for c in ("stalk", "slam", "stagger", "death")},
    # Art loop pass 4, the High Boughs foes. The Leaf Mantis's clips start from its north-east
    # view (base/guard.png: its true side profile; the base's east view faces the camera); the
    # rear of strike_r is the retake of strike's, which turned toward the camera.
    "leaf_mantis": {f"{c}.png": f"enemies/leaf_mantis/{c}" for c in
                    ("idle", "walk", "fold", "strike", "strike_r", "recover", "hurt", "death")},
    # The Bark Knight's clips start from his guard pose (base/guard.png, the lance laid in his hand);
    # bare heartwood is a character state of him (bare_base). His thrust and rooted clips are
    # lengthened to the lance's full reach by tools/art/bark_lance.py, which writes its own strips.
    "bark_knight": {f"{c}.png": f"enemies/bark_knight/{c}" for c in
                    ("idle", "walk", "hurt", "death", "bare_idle", "bare_walk", "bare_hurt", "bare_death")},
    "seed_bomber": {f"{c}.png": f"enemies/seed_bomber/{c}" for c in ("fly", "squeeze", "downed", "hurt", "death")},
    "mothling": {f"{c}.png": f"enemies/mothling/{f}" for c, f in
                 (("fly_r", "fly_s"), ("screech", "screech_s"), ("dive", "dive_s"), ("hurt", "hurt_s"), ("death", "death_s"))},
    # Art loop pass 6 (Vorrhallow and the Sunken Spring). Clips from each base's own east view
    # (the Spring Eel's from its south view, which PixelLab drew as the level side profile).
    "clockwork_hound": {f"{clip}.png": f"enemies/clockwork_hound/{folder}" for clip, folder in
                        (("idle", "idle"), ("trot", "trot"), ("wind", "wind_r1"), ("pounce", "pounce"),
                         ("flipped", "flipped"), ("hurt", "hurt"), ("death", "death"))},
    "crystal_dwarf": {f"{clip}.png": f"enemies/crystal_dwarf/{clip}" for clip in
                      ("idle", "walk", "slam", "hurt", "death")},
    "meteor_slug": {f"{clip}.png": f"enemies/meteor_slug/{clip}" for clip in
                    ("idle", "crawl", "swell", "heave", "hurt", "death")},
    # The Spring Eel was remade with an anglerfish lure, a stalk arching to a glowing orb
    # (Sean, 2026-11-05): base3b, clips in the *_l folders.
    "spring_eel": {f"{clip}.png": f"enemies/spring_eel/{clip}_l" for clip in
                   ("swim", "coil", "dart", "slack", "hurt", "death")},
    # The Haar's foes (art loop pass 3): every clip from the base character's east view.
    "lantern_ghost": {f"{clip}.png": f"enemies/lantern_ghost/{clip}" for clip in ("idle", "lunge", "fade", "death")},
    "bog_puffcap": {f"{clip}.png": f"enemies/bog_puffcap/{clip}" for clip in ("idle", "swell", "spent", "death")},
    # The mire frames are cut from the sink clip by tools/art/mire_frames.py.
    "drowned_dwarf": {**{f"{clip}.png": f"enemies/drowned_dwarf/{clip}" for clip in
                         ("idle", "walk", "heave", "stagger", "death")},
                      "sunk.png": "enemies/drowned_dwarf/mire_sunk", "rise.png": "enemies/drowned_dwarf/mire_rise",
                      "sink_mire.png": "enemies/drowned_dwarf/mire_sink"},
    "marsh_hag": {f"{clip}.png": f"enemies/marsh_hag/{clip}_s" for clip in ("idle", "walk", "hex", "fumble", "death")},
}
NO_SLAB_CLEANING = set()
# Art pass 6: the Glass Slug's grey-violet foot is a flat dull grey the cleaner would eat.
NO_SLAB_CLEANING |= {"meteor_slug"}


def frames_of(folder):
    # Prefer Sean's cleaned frames (art/cleanup/<folder>) over the raw PixelLab output.
    clean = sorted((CLEANUP / folder).glob("[0-9][0-9].png"))
    if clean:
        return clean
    return sorted(p for p in (SOURCES / folder).glob("[0-9][0-9].png"))


def is_cleaned(path):
    """A frame Sean has already cleaned: it must not be slab- or flat-cleaned again."""
    return CLEANUP in path.parents


# PixelLab sometimes leaves a flat grey slab behind a smear or a cloak: a big patch of dull grey,
# often one exact colour (about (130, 128, 130), (150, 142, 146), (128, 130, 126) or the bluer (119, 135, 142)) with a few
# mottled neighbours. A connected patch of dull grey is erased when it is bigger than SLAB_MIN and
# mostly one flat colour; the armor's steel is shaded, so no one colour dominates that much of it.
SLAB_MIN = 400
SLAB_FLAT = 0.5


def is_slab_grey(c):
    r, g, b, a = c
    # Not green-cast: the tunic's dull green is never a slab.
    return a > 0 and 95 <= max(r, g, b) <= 160 and max(r, g, b) - min(r, g, b) <= 32 and g <= max(r, b) + 4


def clear_slabs(im):
    px = im.load()
    w, h = im.size
    seen = set()
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not is_slab_grey(px[x, y]):
                continue
            patch, todo, counts = [], [(x, y)], {}
            seen.add((x, y))
            while todo:
                cx, cy = todo.pop()
                patch.append((cx, cy))
                counts[px[cx, cy]] = counts.get(px[cx, cy], 0) + 1
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and is_slab_grey(px[nx, ny]):
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            if len(patch) >= SLAB_MIN and max(counts.values()) >= SLAB_FLAT * len(patch):
                for q in patch:
                    px[q] = (0, 0, 0, 0)
    return im


# A slab that touches the shaded steel floods into it and fails the flatness test above. In the
# takes listed here a large connected patch of one exact grey is erased on its own (not
# everywhere: the Broad Sword's blade and some tunics are flat greys that size).
FLAT_MIN = 600
FLAT_SLABS = {"hero/plate_cloak/large_shield/block_r1"}


def clear_flat(im):
    px = im.load()
    w, h = im.size
    seen = set()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if (x, y) in seen or c[3] == 0 or not (95 <= max(c[:3]) <= 170 and max(c[:3]) - min(c[:3]) <= 40):
                continue
            patch, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                cx, cy = todo.pop()
                patch.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] == c:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            if len(patch) >= FLAT_MIN:
                for q in patch:
                    px[q] = (0, 0, 0, 0)


def pack(paths, slabs=True):
    strip = Image.new("RGBA", (CELL * len(paths), CELL))
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        if is_cleaned(p):
            # Sean cleaned it by hand; composite it as-is, no slab or flat pass.
            strip.alpha_composite(im, (i * CELL + (CELL - im.width) // 2, CELL - im.height))
            continue
        if slabs:
            clear_slabs(im)
        if p.parent.relative_to(SOURCES).as_posix() in FLAT_SLABS:
            clear_flat(im)
        # PixelLab clips are 256 px canvases; a smaller one is centred on the cell's floor.
        strip.alpha_composite(im, (i * CELL + (CELL - im.width) // 2, CELL - im.height))
    return strip


def main():
    for sheet, strips in [*SHEETS.items(), *ENEMY_SHEETS.items()]:
        dest = OUT / sheet
        dest.mkdir(parents=True, exist_ok=True)
        for name, folder in strips.items():
            paths = frames_of(folder)
            if not paths:
                print(f"{sheet}/{name}: no frames in art/pixellab/{folder}, skipped")
                continue
            pack(paths, sheet not in NO_SLAB_CLEANING).save(dest / name)
            print(f"{sheet}/{name}: {len(paths)} frames")


if __name__ == "__main__":
    main()
