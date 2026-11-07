#!/usr/bin/env python3
"""Turns a PixelLab side-scroller tileset into a zone atlas for TilesetFactory.

PixelLab's side-scroller tilesets are 16 corner ("wang") tiles on a dual grid: each
tile is centred on the point where four cells meet, and its corners say which of
those cells are ground ("lower"). The game's atlas is 47 blob tiles, one per cell,
chosen by the cell's 8 neighbours (scripts/world/tileset_factory.gd). Each blob tile
is built from four 16 px quarters, one per corner of the cell: the quarter of the
wang tile centred on that corner which overlaps the cell.

  python3 tools/art/pixellab_tileset.py fetch <tileset_id> <dir>
      Saves the 16 tiles as art/pixellab/<dir>/wang_<NW><NE><SW><SE>.png (1 = ground).
  python3 tools/art/pixellab_tileset.py fetch-result <job_dir> <dir>
      The same from a create call's result.json (art/pixellab/<job_dir>/), whose tiles are
      URLs; for sets the GET answers with an error.
  python3 tools/art/pixellab_tileset.py preview <dir> <out.png>
      A test strip: a floor, a wall, a pillar and a ledge built from the set.

tilegen.py builds a zone from a set when PIXELLAB_SETS names one (design bible 13.6): the
set gives only the edges (the lip on top, the rim on the sides and underneath), and the
inside of every wall is left clear for the zone's fill texture (assets/tiles/<zone>_fill.png,
a seamless 128 px PixelLab texture drawn by GroundFill behind the tiles), so walls are not
one 32 px tile repeated.
"""
import base64
import io
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
T = 32
H = T // 2
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128


def fetch(tileset_id: str, out_dir: str) -> None:
    raw = subprocess.run([sys.executable, str(ROOT / "tools/art/pixellab.py"), "get", f"tilesets-sidescroller/{tileset_id}"],
                         capture_output=True, text=True, check=True).stdout
    data = json.loads(raw)
    out = ROOT / "art" / "pixellab" / out_dir
    out.mkdir(parents=True, exist_ok=True)
    for t in data["tileset"]["tiles"]:
        c = t["corners"]
        key = "".join("1" if c[k] == "lower" else "0" for k in ["NW", "NE", "SW", "SE"])
        Image.open(io.BytesIO(base64.b64decode(t["image"]["base64"]))).convert("RGBA").save(out / f"wang_{key}.png")
    meta = {k: data["metadata"].get(k) for k in ["terrain_prompts", "transition_size"]}
    meta["id"] = tileset_id
    (out / "tileset.json").write_text(json.dumps(meta, indent=1) + "\n")
    print(f"{out}: 16 tiles")


def fetch_result(job_dir: str, out_dir: str) -> None:
    data = json.loads((ROOT / "art" / "pixellab" / job_dir / "result.json").read_text())["last_response"]
    out = ROOT / "art" / "pixellab" / out_dir
    out.mkdir(parents=True, exist_ok=True)
    for t in data["tileset_data"]["tiles"]:
        c = t["corners"]
        key = "".join("1" if c[k] == "lower" else "0" for k in ["NW", "NE", "SW", "SE"])
        subprocess.run(["curl", "-sSf", "-o", str(out / f"wang_{key}.png"), t["image"]["url"]], check=True)
    (out / "tileset.json").write_text(json.dumps({"id": data["tileset_id"], "job": job_dir}, indent=1) + "\n")
    print(f"{out}: {len(data['tileset_data']['tiles'])} tiles")


def load(set_dir: Path) -> dict:
    return {p.stem[5:]: Image.open(p).convert("RGBA") for p in set_dir.glob("wang_*.png")}


def wang(tiles: dict, nw: bool, ne: bool, sw: bool, se: bool) -> Image.Image:
    return tiles["".join("1" if b else "0" for b in (nw, ne, sw, se))]


def blob_tile(tiles: dict, mask: int) -> Image.Image:
    """The tile for a ground cell whose neighbours are `mask` (reduced blob mask)."""
    has = lambda bit: bool(mask & bit)
    out = Image.new("RGBA", (T, T))
    # (quarter of the cell, wang corners around that corner as NW NE SW SE, quarter of the wang tile)
    quarters = [
        ((0, 0), (has(NW), has(N), has(W), True), (H, H)),
        ((H, 0), (has(N), has(NE), True, has(E)), (0, H)),
        ((0, H), (has(W), True, has(SW), has(S)), (H, 0)),
        ((H, H), (True, has(E), has(S), has(SE)), (0, 0)),
    ]
    for (dx, dy), corners, (sx, sy) in quarters:
        out.alpha_composite(wang(tiles, *corners).crop((sx, sy, sx + H, sy + H)), (dx, dy))
    return out


def shade(img: Image.Image, k: float) -> Image.Image:
    """Darkens a tile toward night, for wall interiors far from open air."""
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            po[x, y] = (int(r * k + 0x16 * (1 - k)), int(g * k + 0x12 * (1 - k)), int(b * k + 0x24 * (1 - k)), a)
    return out


# How far in from an open side the set's own pixels are kept (source px); past that the
# fill shows, with a dithered band two pixels wide between them.
KEEP_TOP = 10
KEEP_SIDE = 6
NIGHT = (0x16, 0x12, 0x24)


def edge_only(tile: Image.Image, mask: int) -> Image.Image:
    """Clears a blob tile's inside, keeping its edges near open air."""
    out = tile.copy()
    px = out.load()
    for y in range(T):
        for x in range(T):
            cx, cy = x + 0.5, y + 0.5
            d = []
            if not mask & N:
                d.append(cy - (KEEP_TOP - KEEP_SIDE))
            if not mask & S:
                d.append(T - cy)
            if not mask & W:
                d.append(cx)
            if not mask & E:
                d.append(T - cx)
            for bit, a, b, (qx, qy) in [(NE, N, E, (T, 0)), (SE, S, E, (T, T)), (SW, S, W, (0, T)), (NW, N, W, (0, 0))]:
                if mask & a and mask & b and not mask & bit:
                    d.append(((cx - qx) ** 2 + (cy - qy) ** 2) ** 0.5 - (KEEP_TOP - KEEP_SIDE if qy == 0 else 0))
            dist = min(d) if d else 99
            if dist >= KEEP_SIDE + 2 or (dist >= KEEP_SIDE and (x + y) % 2):
                px[x, y] = (0, 0, 0, 0)
    return out


def slope(tile: Image.Image, fill: Image.Image, rising_east: bool) -> Image.Image:
    """A 45-degree slope: a capped tile over the fill, sheared so its cap runs along the
    diagonal (solid below it), as tilegen.paint_slope does for painted zones."""
    base = fill.crop((0, 0, T, T))
    base.alpha_composite(tile)
    out = Image.new("RGBA", (T, T))
    for x in range(T):
        drop = T - 1 - x if rising_east else x
        for y in range(drop, T):
            out.putpixel((x, y), base.getpixel((x, y - drop)))
    return out


def atlas(set_dir: str, fill_png: Path, out_png: Path, ledge_png: Path | None = None) -> None:
    """Writes a zone atlas laid out as TilesetFactory reads it (rows 0-5 blob tiles, row 6
    one-way, amber, two MID, two DEEP, two slopes; row 7 the masonry variants, bible 12.8)."""
    sys.path.insert(0, str(ROOT / "tools/art"))
    import tilegen
    tiles = load(ROOT / "art" / "pixellab" / set_dir)
    fill = Image.open(fill_png).convert("RGBA")
    img = Image.new("RGBA", (T * 8, T * 8))
    for i, m in enumerate(tilegen.blob_masks()):
        img.alpha_composite(edge_only(blob_tile(tiles, m), m), ((i % 8) * T, (i // 8) * T))
    if ledge_png:
        ledge = Image.open(ledge_png).convert("RGBA")
        top = ledge.getbbox()[1]
        for k in range(0, T, ledge.width):
            img.alpha_composite(ledge.crop((0, top, ledge.width, T)), (k, 6 * T))
    else:
        tilegen.paint_one_way(img, 0, 6 * T, "hearthroot")
    tilegen.paint_amber(img, T, 6 * T)
    # Wall interiors away from open air: a veil of night over the fill.
    for k, alpha in enumerate([60, 60, 110, 110]):
        img.alpha_composite(Image.new("RGBA", (T, T), NIGHT + (alpha,)), ((2 + k) * T, 6 * T))
    cap = blob_tile(tiles, E | S | W | SE | SW)
    img.alpha_composite(slope(cap, fill, True), (6 * T, 6 * T))
    img.alpha_composite(slope(cap, fill, False), (7 * T, 6 * T))
    # Row 7 masonry variants (bible 12.8). The factory scatters these across a
    # solid field. A pixellab zone's interior is a seamless GroundFill texture, so
    # it has no 32 px grid banding to break; the variants simply mirror their row-6
    # equivalents so every coord the factory references exists. FULL variants
    # (cols 0-2) stay clear, like the base FULL tile, so the fill shows through;
    # the MID extras (cols 3-4) and DEEP extras (cols 5-6) keep the same night veil.
    for k, alpha in enumerate([60, 60]):
        img.alpha_composite(Image.new("RGBA", (T, T), NIGHT + (alpha,)), ((3 + k) * T, 7 * T))
    for k, alpha in enumerate([110, 110]):
        img.alpha_composite(Image.new("RGBA", (T, T), NIGHT + (alpha,)), ((5 + k) * T, 7 * T))
    img.save(out_png)


def preview(set_dir: str, out_png: str) -> None:
    sys.path.insert(0, str(ROOT / "tools/art"))
    import tilegen
    tiles = load(ROOT / "art" / "pixellab" / set_dir)
    grid = [
        "..........................",
        "..........................",
        ".......###.......####.....",
        ".......###.......####.....",
        "....#..###....#..####.....",
        "....#.........#...........",
        "##########################",
        "##########################",
        "##########################",
    ]
    img = Image.new("RGBA", (len(grid[0]) * T, len(grid) * T), (0x2b, 0x24, 0x3c, 255))
    solid = lambda x, y: 0 <= y < len(grid) and (x < 0 or x >= len(grid[0]) or grid[y][x] == "#")
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            m = 0
            for bit, (ox, oy) in [(N, (0, -1)), (NE, (1, -1)), (E, (1, 0)), (SE, (1, 1)), (S, (0, 1)), (SW, (-1, 1)), (W, (-1, 0)), (NW, (-1, -1))]:
                if solid(x + ox, y + oy):
                    m |= bit
            img.alpha_composite(blob_tile(tiles, tilegen.reduce_mask(m)), (x * T, y * T))
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(out_png)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "fetch":
        fetch(sys.argv[2], sys.argv[3])
    elif cmd == "fetch-result":
        fetch_result(sys.argv[2], sys.argv[3])
    elif cmd == "preview":
        preview(sys.argv[2], sys.argv[3])
