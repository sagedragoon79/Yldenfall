#!/usr/bin/env python3
"""Packs Autosprite animation sheets into the game's sheet format (design bible 13.1 to 13.3).

Autosprite renders smooth, high-resolution frames (usually 256x256). This turns them into
game frames: the figure is scaled so a reference frame matches a target height, area-averaged
down, cut to a hard alpha edge, mapped onto the master palette (only the ramps the character
uses), its dark anti-aliased rim is dropped and it gets the same 1 px full outline as the
code-drawn sprites (12.3). The feet land on the sheet's origin, so the frames line up with the
code-drawn ones and the game code does not change.

Sources live in art/autosprite/<dir>/ (the downloaded sheet PNGs, kept so the import is
reproducible without spending credits) and art/autosprite/manifest.json says which
animations of which sheet they replace:

  "player": {                         sheet name in assets/sprites/
    "dir": "elf",
    "ramps": ["night", "bark", ...],  palette ramps the figure may use
    "height": 42,                     reference figure height in world px, before the outline
    "colors": 40,                     instead of the master ramps, the sheet's own palette of this
                                      many colors, cut from the reference animation (12.2: HD
                                      characters); "ramps" and "extra_ramps" then only add colors
    "flags": {"scarf": false},        sheet-wide switches written for the game (the hooded hero's
                                      cloak is in the art, so the code scarf is off)
    "density": 2,                     sheet pixels per world pixel (design bible 12.1, default 1):
                                      the sheet is written at double size and drawn at half, so
                                      the figure keeps its world size with twice the detail
    "reference": "idle",              animation whose first picked frame sets the scale
    "animations": {
      "idle": {"file": "idle.png", "frame_size": 256, "columns": 4, "count": 16,
               "pick": [0, 4, 8, 12],    source frames to keep (default: all)
               "seq": [...], "fps": 8, "loop": true,   playback (default: the code rig's)
               "anchor": "ground",       "ground": each frame's lowest pixel on the origin;
                                         "fixed": the reference frame's feet (jumps, deaths);
                                         "center": the reference frame's middle (fliers)
               "lower": 58,              source pixels the figure is moved down after anchoring: the
                                         pogo's delvers_pick reaches below the feet (hero sheets are 84
                                         world px tall, 23 under the origin, for it)
               "feet_x": "self",         "self": find the feet in this sheet's first picked frame
                                         (attack moves come in 512 px cells, figure bottom-centre);
                                         a number: the source column (poses packed on one spot)
               "drop": ["blade"],        code-rig metadata keys to leave out (the clip draws the sword)
               "meta": {"art_prop": true},  keys added to every frame's metadata
               "extra_ramps": ["stone"], more palette ramps for this animation (a steel blade)
               "recolor": {"hue": [150, 215], "shift": -10, "sat": 1.4},  (entry level) hues in
                                         the range turned and saturated before anything else
               "erase": [170, 250],      hue range (degrees) to cut out first, e.g. a spell glow
                                         the game draws itself
               "erase_white": true,      also cut out the glow's near-white core
               "graft": {"above": 152, "from": {"33": 23}},  per source frame, the rows above
                                         `above` taken from another frame of the clip, moved so
                                         the heads line up (the Iron Dwarf's walk lets go of his
                                         hammer for half a stride: that half gets a gripping arm)
               "face": {"from": 2, "box": [x0, y0, x1, y1], "match": [x0, y0, x1, y1]},
                                         every frame's `box` (in the donor's place) replaced by
                                         source frame `from`'s, found where the `match` patch
                                         (the helmet) lines up best: one still face, for a clip
                                         whose mouth works as if talking (the Foreman's walk)
               "clear": {"20": [x0, y0, x1, y1]},  per source frame, a box (cell pixels) where
                                         pale grey pixels are cleared: background the clip left
                                         closed in (between the hero's raised arm and his face)
               "paint": {"20": [x0, y0, x1, y1]},  as "spill", for a pale grey blot (painted
                                         from row neighbours up to 14 px away: a fleck of white
                                         on the hero's boot in the wall slide)
               "spill": {"20": [x0, y0, x1, y1]},  per source frame, a box (cell pixels) where
                                         stray red liquid is painted over from its row neighbours
                                         (the drink clip spills the potion down his chest)
               "height": 38}             this animation's own figure height (world px) and middle,
                                         for a part drawn apart from the reference (boss segments)
    },
    "gain": 1.3,                      brightens a figure drawn too dark for the game's dark rooms
                                      (the Iron Dwarf's black iron), before the palette is cut
    "rim": {"color": [r, g, b],       a cool rim light (12.2: readability): the figure's top and
            "mix": 0.5}               back edges (left, the sheets face right) lifted toward this
                                      color, so a brown figure stands off brown trees
  }

pixelrig.write_sheet() calls imported() for every sheet it writes, so spritegen.py and
castgen.py pick up the imported animations and keep the code-drawn ones for the rest.
Per-frame metadata (hand, neck, blade, eye...) comes from the code rig's frame at the same
point of the animation; for the player, the neck and front hand are found in the pixels.
Metadata is always in world pixels, whatever the density.

Usage: python3 tools/art/autosprite_import.py             reruns spritegen.py and castgen.py
       python3 tools/art/autosprite_import.py --loop elf/run.png [min max]
                                                          finds the cleanest loop (start, length) in a
                                                          full-rate sheet, for the manifest's "pick"
       python3 tools/art/autosprite_import.py --selftest  round trip: blows the code-drawn run up to a
                                                          fake 256 px sheet, imports it, checks the result
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "art" / "autosprite"
MANIFEST = SOURCES / "manifest.json"

PAL = {}
for _name, _hue, _sat in palette.RAMPS:
    for _i in range(8):
        PAL[f"{_name}-{_i}"] = palette.shade(_hue, _sat, _i)
OUTLINE = PAL["night-0"]


def _lab(rgb):
    """sRGB (..., 3) uint8 -> CIE Lab, for perceptual nearest-color matching."""
    c = np.asarray(rgb, np.float64) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def load_manifest():
    if not MANIFEST.exists():
        return {}
    return json.loads(MANIFEST.read_text())


def source_frames(spec, src_dir):
    """The picked frames of one Autosprite sheet as float RGBA arrays (premultiplied)."""
    sheet = Image.open(src_dir / spec["file"]).convert("RGBA")
    n = spec["frame_size"]
    cols = spec.get("columns", sheet.width // n)
    count = spec.get("count", cols * (sheet.height // n))
    out = []
    for i in spec.get("pick", range(count)):
        x, y = (i % cols) * n, (i // cols) * n
        a = np.asarray(sheet.crop((x, y, x + n, y + n)), np.float64) / 255.0
        a[..., :3] *= a[..., 3:4]
        out.append(a)
    return out


def _bbox(alpha, cut=0.5):
    ys, xs = np.nonzero(alpha >= cut)
    if len(ys) == 0:
        return None
    return xs.min(), ys.min(), xs.max(), ys.max()


def _shifted(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    out[max(0, dy):min(h, h + dy), max(0, dx):min(w, w + dx)] = \
        mask[max(0, -dy):min(h, h - dy), max(0, -dx):min(w, w - dx)]
    return out


def _n4(mask):
    return _shifted(mask, 1, 0) | _shifted(mask, -1, 0) | _shifted(mask, 0, 1) | _shifted(mask, 0, -1)


def _morph(mask, r, grow):
    """`mask` eroded (grow False) or dilated (grow True) by a (2r+1)-square."""
    out = np.zeros_like(mask) if grow else np.ones_like(mask)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            s = _shifted(mask, dx, dy)
            out = (out | s) if grow else (out & s)
    return out


def head_point(img, r=4):
    """The crown of the figure's head in sheet pixels (x, y), or None: the top of what is
    left once the cloak (green) is masked out and anything thinner than the head (a blade, a
    fist, a strand of hair) is opened away. A raised fist can still read a few pixels high."""
    px = np.asarray(img).astype(int)
    green = (px[..., 1] > px[..., 0] + 8) & (px[..., 1] > px[..., 2])
    body = (px[..., 3] > 0) & ~green
    # The figure's top, a blade or a stray pixel aside.
    raw = np.nonzero(_morph(_morph(body, 2, False), 2, True).any(1))[0]
    if len(raw) == 0:
        return None
    # A head half hidden by the cloak is narrower: open less until the crown lands
    # near the top of the figure.
    for k in range(r, 2, -1):
        solid = _morph(_morph(body, k, False), k, True)
        rows = np.nonzero(solid.any(1))[0]
        if len(rows) and rows.min() - raw.min() <= 12:
            break
    else:
        solid = _morph(_morph(body, 2, False), 2, True)
    top = np.nonzero(solid.any(1))[0].min()
    xs = np.nonzero(solid[top:top + 6])[1]
    return round(xs.mean()), top


def _erase_hue(src, lo, hi, white=False):
    """Clears saturated pixels whose hue lies in [lo, hi] degrees (premultiplied RGBA), and
    with `white` the near-white core of a glow too."""
    a = src[..., 3:4]
    rgb = np.where(a > 1e-6, src[..., :3] / np.maximum(a, 1e-6), 0)
    mx, mn = rgb.max(-1), rgb.min(-1)
    c = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.maximum(c, 1e-6)
    h = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60
    sat = c / np.maximum(mx, 1e-6)
    out = src.copy()
    gone = (h >= lo) & (h <= hi) & (sat > 0.25) & (c > 0.12)
    if white:
        gone |= (sat < 0.15) & (mx > 0.8)
    out[gone] = 0
    return out


def _recolor(src, spec):
    """`src` (premultiplied RGBA) with the hues in spec["hue"] (degrees) turned by
    spec["shift"] degrees and their saturation scaled by spec["sat"]: a set's colors moved to
    match a layer drawn over it (the Elven Plate's teal onto the Elven Helm's)."""
    lo, hi = spec["hue"]
    a = src[..., 3:4]
    rgb = np.where(a > 1e-6, src[..., :3] / np.maximum(a, 1e-6), 0)
    mx, mn = rgb.max(-1), rgb.min(-1)
    c = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.maximum(c, 1e-6)
    h = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60
    sat = c / np.maximum(mx, 1e-6)
    hit = (h >= lo) & (h <= hi) & (sat > 0.06)
    h2 = (h + float(spec.get("shift", 0))) % 360
    s2 = np.clip(sat * float(spec.get("sat", 1.0)), 0, 1)
    # Back to RGB at the same value (max channel).
    k = lambda n: (n + h2 / 60) % 6
    f = lambda n: mx - mx * s2 * np.clip(np.minimum(k(n), 4 - k(n)), 0, 1)
    new = np.stack([f(5), f(3), f(1)], -1)
    out = src.copy()
    out[..., :3] = np.where(hit[..., None], new * a, src[..., :3])
    return out


def _head(src, rows=30):
    """(x middle, top row) of the figure's top `rows` rows."""
    ys, xs = np.nonzero(src[..., 3] > 0.5)
    top = ys.min()
    band = xs[ys < top + rows]
    return (band.min() + band.max()) / 2.0, top


def _graft(src, donor, above):
    """`src` with its rows above `above` replaced by `donor`'s, shifted so the heads line up."""
    (sx, sy), (dx, dy) = _head(src), _head(donor)
    ox, oy = int(round(sx - dx)), int(round(sy - dy))
    moved = np.zeros_like(donor)
    h, w = donor.shape[:2]
    moved[max(0, oy):min(h, h + oy), max(0, ox):min(w, w + ox)] = \
        donor[max(0, -oy):min(h, h - oy), max(0, -ox):min(w, w - ox)]
    out = src.copy()
    out[:above] = moved[:above]
    # Bits of the free arm the cut leaves below `above` float loose: keep the figure only.
    from autosprite_poses import components
    labels, sizes = components(out[..., 3] > 0.02)
    if len(sizes) > 1:
        out[labels != int(np.argmax(sizes[1:])) + 1] = 0
    return out


def _match_offset(src, donor, box, reach=10):
    """The shift (dx, dy) that best lays `donor`'s `box` onto `src`."""
    x0, y0, x1, y1 = box
    patch = donor[y0:y1, x0:x1]
    best = None
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            if y0 + dy < 0 or x0 + dx < 0 or y1 + dy > src.shape[0] or x1 + dx > src.shape[1]:
                continue
            d = np.abs(src[y0 + dy:y1 + dy, x0 + dx:x1 + dx] - patch).mean()
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best[1], best[2]


def _face(src, donor, box, match):
    """`src` with `donor`'s `box` pasted where the `match` patch lines up."""
    dx, dy = _match_offset(src, donor, match)
    x0, y0, x1, y1 = box
    patch = donor[y0:y1, x0:x1]
    out = src.copy()
    region = out[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
    solid = patch[..., 3] > 0.5
    region[solid] = patch[solid]
    return out


def _clear_grey(src, box):
    """Clears pale, unsaturated pixels inside `box` (background left behind in a gap)."""
    a = src[..., 3]
    rgb = np.where(a[..., None] > 1e-6, src[..., :3] / np.maximum(a[..., None], 1e-6), 0)
    mx, mn = rgb.max(-1), rgb.min(-1)
    grey = (a > 0.05) & ((mx - mn) / np.maximum(mx, 1e-6) < 0.15) & (mx > 0.35)
    x0, y0, x1, y1 = box
    out = src.copy()
    out[y0:y1, x0:x1][grey[y0:y1, x0:x1]] = 0
    return out


def _paint_spill(src, box, grey=False, reach=6):
    """Paints over saturated red (hue within 12 degrees of 0), or with `grey` pale grey, inside
    `box`: each such pixel takes the mean of the nearest clean opaque pixels left and right on
    its row (within `reach`), or is cleared where it hangs over the background."""
    a = src[..., 3]
    rgb = np.where(a[..., None] > 1e-6, src[..., :3] / np.maximum(a[..., None], 1e-6), 0)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    # Red is the largest channel and green and blue are within a fifth of the chroma: hue 0 +- 12.
    red = (rgb.argmax(-1) == 0) & (np.abs(rgb[..., 1] - rgb[..., 2]) <= 0.2 * (mx - mn)) & \
        (sat > 0.5) & (mx > 0.25) & (a > 0.05)
    if grey:
        red = (sat < 0.3) & (mx > 0.45) & (a > 0.05)
    x0, y0, x1, y1 = box
    gone = np.zeros_like(red)
    gone[y0:y1, x0:x1] = red[y0:y1, x0:x1]
    out = src.copy()
    for y, x in zip(*np.nonzero(gone)):
        picks = []
        for step in (-1, 1):
            xx = x + step
            while 0 <= xx < src.shape[1] and gone[y, xx]:
                xx += step
            if 0 <= xx < src.shape[1] and abs(xx - x) <= reach:
                picks.append(src[y, xx])
        opaque = [q for q in picks if q[3] > 0.5]
        out[y, x] = np.mean(opaque, 0) if len(opaque) == len(picks) and opaque else 0
    return out


def density(name):
    """Sheet pixels per world pixel for sheet `name` (1 unless the manifest says otherwise
    and its reference source is downloaded)."""
    cfg = load_manifest().get(name)
    if not cfg or not (SOURCES / cfg["dir"] / cfg["animations"][cfg.get("reference", "idle")]["file"]).exists():
        return 1
    return int(cfg.get("density", 1))


def flags(name):
    """Sheet-wide switches for the game (manifest "flags", e.g. {"scarf": false}), once the
    reference source is downloaded."""
    cfg = load_manifest().get(name)
    if not cfg or not (SOURCES / cfg["dir"] / cfg["animations"][cfg.get("reference", "idle")]["file"]).exists():
        return {}
    return cfg.get("flags", {})


def own_colors(name):
    """The size of sheet `name`'s own palette, or 0 if it uses the master ramps."""
    cfg = load_manifest().get(name)
    if not cfg or not (SOURCES / cfg["dir"] / cfg["animations"][cfg.get("reference", "idle")]["file"]).exists():
        return 0
    return int(cfg.get("colors", 0))


class Importer:
    def __init__(self, name, cfg, cell, origin):
        """`cell` and `origin` are in sheet pixels (world pixels times the density)."""
        self.name, self.cfg = name, cfg
        self.cell, self.origin = cell, origin
        self.density = int(cfg.get("density", 1))
        self.gain = float(cfg.get("gain", 1.0))
        self.dir = SOURCES / cfg["dir"]
        self.own = {}
        ref = cfg["animations"][cfg.get("reference", "idle")]
        frames = self.recolor(source_frames(ref, self.dir))
        self.set_reference(frames[0], cfg["height"])
        if cfg.get("colors"):
            # Cut from the reference clip plus the first frame of every other animation
            # whose source is here, so a differently colored part keeps its colors.
            others = [self.recolor(source_frames(dict(spec, pick=spec.get("pick", [0])[:1]), self.dir))[0]
                      for spec in cfg["animations"].values()
                      if spec is not ref and (self.dir / spec["file"]).exists()]
            self.own = self.own_palette(frames + others, int(cfg["colors"]))
        self.rim = []
        if cfg.get("rim"):
            # Rim shades: the sheet's tones lifted toward the rim color, cut to a few colors.
            self.rim_color = np.array(cfg["rim"]["color"], float)
            self.rim_mix = float(cfg["rim"].get("mix", 0.4))
            tones = np.array(list(self.own.values()) or [(80, 80, 80)], float)
            lifted = (tones * (1 - self.rim_mix) + self.rim_color * self.rim_mix).round().astype(np.uint8)
            img = Image.fromarray(lifted.reshape(1, -1, 3), "RGB").quantize(8, Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
            for c in np.array(img.getpalette()[:24], np.uint8).reshape(-1, 3):
                self.own[f"rim-{len(self.rim)}"] = tuple(int(v) for v in c)
                self.rim.append(f"rim-{len(self.rim)}")
        self.use_ramps(cfg["ramps"])

    def recolor(self, srcs):
        """The manifest's "recolor" (see _recolor) applied to source frames."""
        spec = self.cfg.get("recolor")
        return [_recolor(src, spec) for src in srcs] if spec else srcs

    def set_reference(self, frame, height):
        """Scales so `frame` is `height` world px tall and measures its feet and middle."""
        x0, y0, x1, y1 = _bbox(frame[..., 3])
        self.scale = height * self.density / float(y1 - y0 + 1)
        # The reference feet: bottom of the figure, centered on its lowest rows.
        self.ref_x = self.feet_x(frame)
        # The reference middle, for fliers whose origin is their center.
        self.ref_cx, self.ref_cy = (x0 + x1 + 1) / 2.0, (y0 + y1 + 1) / 2.0
        self.ref_y = y1 + 1.0

    def use_ramps(self, ramps):
        self.keys = list(self.own) + [k for k in PAL if k.split("-")[0] in ramps]
        self.colors = np.array([self.own.get(k) or PAL[k] for k in self.keys], np.uint8)
        self.lab = _lab(self.colors)
        # Ordinary pixels never take a rim shade; rim pixels only take one.
        self.is_rim = np.array([k in self.rim for k in self.keys])
        # Shades as dark as the outline's neighbor: the anti-aliased rim the outline replaces.
        self.dark = [i for i, k in enumerate(self.keys) if k in ("night-0", "night-1")
                     or (k in self.own and self.lab[i][0] <= _lab(np.array([PAL["night-1"]], np.uint8))[0][0])]

    def small(self, src):
        """A source frame area-averaged down to game scale: (rgb 0..1, alpha)."""
        size = max(1, int(round(src.shape[0] * self.scale)))
        chans = [np.asarray(Image.fromarray(src[..., c].astype(np.float32), "F")
                            .resize((size, size), Image.BOX)) for c in range(4)]
        small = np.stack(chans, -1)
        alpha = small[..., 3]
        rgb = np.where(alpha[..., None] > 1e-6, small[..., :3] / np.maximum(alpha[..., None], 1e-6), 0)
        return (rgb * self.gain).clip(0, 1), alpha

    def own_palette(self, frames, count):
        """{"own-i": rgb} cut from the frames at game scale (median cut), darkest first."""
        px = []
        for src in frames:
            rgb, alpha = self.small(src)
            px.append((rgb[alpha >= 0.5] * 255).clip(0, 255).astype(np.uint8))
        px = np.concatenate(px)
        img = Image.fromarray(px.reshape(1, -1, 3), "RGB").quantize(count, Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        pal = np.array(img.getpalette()[:count * 3], np.uint8).reshape(-1, 3)
        pal = pal[np.argsort(_lab(pal)[:, 0])]
        return {f"own-{i}": tuple(int(v) for v in c) for i, c in enumerate(pal)}

    def quantize(self, rgb, rim=False):
        d = ((_lab(rgb)[:, None, :] - self.lab[None, :, :]) ** 2).sum(-1)
        if self.is_rim.any():
            d[:, self.is_rim != rim] = np.inf
        return d.argmin(1)

    @staticmethod
    def feet_x(frame):
        """The middle of the figure's lowest rows, in source pixels."""
        x0, y0, x1, y1 = _bbox(frame[..., 3])
        bottom = frame[..., 3][max(y0, y1 - 6):y1 + 1] >= 0.5
        xs = np.nonzero(bottom.any(0))[0]
        return (xs.min() + xs.max() + 1) / 2.0

    def frame(self, src, anchor, ref_x=None, lower=0.0):
        """One source frame -> (RGBA image, white mask image, palette key grid). `lower` moves
        the figure down by that many source pixels (a pogo's delvers_pick reaching under the feet)."""
        s = self.scale
        rgb, alpha = self.small(src)
        # Where the frame lands in the cell: the reference feet (scaled) on the origin.
        fy = self.ref_y
        if anchor == "center":
            fy = self.ref_cy
            ref_x = self.ref_cx if ref_x is None else ref_x
        elif anchor == "ground":
            box = _bbox(src[..., 3])
            fy = box[3] + 1.0 if box else fy
        ox = int(round(self.origin[0] - (self.ref_x if ref_x is None else ref_x) * s))
        oy = int(round(self.origin[1] - (fy - lower) * s))
        # Where source pixel (0, 0) lands in the cell, for points marked on the source frames.
        self.offset = (ox, oy)
        cw, ch = self.cell
        solid = np.zeros((ch, cw), bool)
        keys = np.full((ch, cw), -1, np.int32)
        ys, xs = np.nonzero(alpha >= 0.5)
        cx, cy = xs + ox, ys + oy
        ok = (cx >= 1) & (cx < cw - 1) & (cy >= 1) & (cy < ch - 1)
        ys, xs, cx, cy = ys[ok], xs[ok], cx[ok], cy[ok]
        solid[cy, cx] = True
        keys[cy, cx] = self.quantize((rgb[ys, xs] * 255).clip(0, 255))
        # Drop lone pixels, then the dark anti-aliased rim the outline replaces.
        lone = solid & ~(_shifted(solid, 1, 0) | _shifted(solid, -1, 0) | _shifted(solid, 0, 1) | _shifted(solid, 0, -1))
        solid &= ~lone
        dark = np.isin(keys, self.dark)
        rim = solid & _n4(~solid) & dark
        solid &= ~rim
        outline = _n4(solid) & ~solid
        if self.rim:
            # Lit from above and behind: solid pixels with open space over them or at their back.
            # One sheet pixel: a thin highlight just inside the outline.
            lit = solid & (~_shifted(solid, 0, 1) | ~_shifted(solid, 1, 0))
            lifted = self.colors[keys[lit]] * (1 - self.rim_mix) + self.rim_color * self.rim_mix
            keys[lit] = self.quantize(lifted, rim=True)
        img = np.zeros((ch, cw, 4), np.uint8)
        img[solid, :3] = self.colors[keys[solid]]
        img[solid, 3] = 255
        img[outline, :3] = OUTLINE
        img[outline, 3] = 255
        mask = np.zeros((ch, cw, 4), np.uint8)
        mask[solid | outline] = 255
        grid = np.full((ch, cw), "", object)
        grid[solid] = np.array(self.keys, object)[keys[solid]]
        return Image.fromarray(img, "RGBA"), Image.fromarray(mask, "RGBA"), grid

    def mark_hands(self, meta, mark):
        """A frame's weapon points marked by hand on its source frame (the 128 px hero's
        body-only clips): [x, y, blade degrees] for the sword fist, then optionally [x, y]
        for the shield fist. The game draws the sword through "hand" at "blade" (0 points
        forward, positive turns down) and the shield at "off"."""
        meta = dict(meta)
        ox, oy = self.offset
        s = self.scale
        meta["hand"] = self.to_point(ox + mark[0] * s, oy + mark[1] * s)
        meta["blade"] = mark[2]
        if len(mark) > 3 and mark[3]:
            meta["off"] = self.to_point(ox + mark[3][0] * s, oy + mark[3][1] * s)
        return meta

    def detect_eye(self, grid, meta):
        """A one-eyed creature's eye (the white), for the pupil the game draws."""
        meta = dict(meta)
        c = _eye_center(grid)
        if c:
            d = self.density
            meta["eye"] = [round((c[0] - self.origin[0]) / d, 1), round((c[1] - self.origin[1]) / d, 1)]
        return meta

    def to_point(self, x, y):
        """A sheet pixel as a point in world pixels from the origin."""
        d = self.density
        return [int(round((x - self.origin[0]) / d)), int(round((y - self.origin[1]) / d))]

    def detect(self, grid, meta):
        """The player's neck (top of the tunic) and front hand (forward-most skin away from the face)."""
        meta = dict(meta)
        tunic = np.vectorize(lambda k: k.startswith("leaf-"))(grid)
        if tunic.any():
            # The first row with a real run of tunic, so stray green pixels in the hair don't count.
            rows = np.nonzero(tunic.sum(1) >= 3)[0]
            if len(rows) == 0:
                return meta
            top = rows.min()
            neck_x = np.nonzero(tunic[top])[0].mean()
            meta["neck"] = self.to_point(round(neck_x), top - 1)
            skin = np.vectorize(lambda k: k in ("bark-5", "bark-6", "bark-7"))(grid)
            skin[:top + 2] = False
            if skin.any():
                sy, sx = np.nonzero(skin)
                front = sx.max()
                pick = sx >= front - 1
                meta["hand"] = self.to_point(round(sx[pick].mean()), round(sy[pick].mean()))
        return meta


    def detect_hero(self, img, meta):
        """Anchors for the layers drawn over a body set (weapon, shield, helmet, cloak), found
        in the frame's pixels so every armor set and clip gets its own: "neck", "back" (the
        nape of the shoulders, where a cloak hangs from) and "hand" (the leading fist: the
        forward-most point of the arm band, as the code rig's front hand). The "head" (the
        crown, for the helmet and the hood) comes from head_point: the entry sets "head"."""
        meta = dict(meta)
        a = np.asarray(img)
        solid = a[..., 3] > 0
        ys, xs = np.nonzero(solid)
        if len(ys) == 0:
            return meta
        top, h = ys.min(), ys.max() - ys.min() + 1

        def filled(row):
            # The nearest row at or below `row` with pixels: a loose speck or a lifted
            # cloak tip can top the frame with a gap under it.
            while row < solid.shape[0] - 1 and not solid[row].any():
                row += 1
            return row, np.nonzero(solid[row])[0]

        row, cols = filled(int(top + 0.16 * h))
        meta["neck"] = self.to_point((cols.min() + cols.max()) / 2.0, row)
        row, cols = filled(int(top + 0.21 * h))
        meta["back"] = self.to_point(cols.min() + 0.03 * h, row)
        band = solid.copy()
        band[:int(top + 0.2 * h)] = False
        band[int(top + 0.56 * h):] = False
        by, bx = np.nonzero(band)
        if len(by):
            front = bx.max()
            near = bx >= front - 0.02 * h
            # The fist's middle, half a fist in from its leading edge.
            meta["hand"] = self.to_point(front - 0.025 * h, by[near].mean())
        return meta


def _eye_center(grid):
    """Center of the largest patch of eye-white (the two lightest stone shades)."""
    white = np.isin(grid, ["stone-6", "stone-7"])
    if not white.any():
        return None
    ys, xs = np.nonzero(white)
    return float(xs.mean()), float(ys.mean())


def imported(name, cell, origin, code_meta):
    """{anim: (frames [(img, mask, meta)], seq or None, fps or None, loop or None)} for the
    animations of sheet `name` that have Autosprite sources. `cell` and `origin` are in sheet
    pixels (see density()). `code_meta` is the code rig's {anim: [per-frame metadata]} to
    carry over."""
    cfg = load_manifest().get(name)
    if not cfg:
        return {}
    ref = cfg["animations"][cfg.get("reference", "idle")]
    if not (SOURCES / cfg["dir"] / ref["file"]).exists():
        print(f"  {name}: reference source {cfg['dir']}/{ref['file']} not downloaded yet, keeping the code-drawn frames")
        return {}
    imp = Importer(name, cfg, cell, origin)
    out = {}
    for anim, spec in cfg["animations"].items():
        if not (imp.dir / spec["file"]).exists():
            print(f"  {name}.{anim}: source {spec['file']} missing, keeping the code-drawn frames")
            continue
        frames = []
        srcs = imp.recolor(source_frames(spec, imp.dir))
        # A sheet with "own_meta" (the 128 px hero) takes nothing from the code rig: its points
        # come from its own frames and the manifest's "hands".
        base = [{}] if cfg.get("own_meta") else (code_meta.get(anim) or [{}])
        imp.use_ramps(cfg["ramps"] + spec.get("extra_ramps", []))
        if "erase" in spec:
            srcs = [_erase_hue(src, *spec["erase"], white=spec.get("erase_white", False)) for src in srcs]
        picks = list(spec.get("pick", range(len(srcs))))
        if "graft" in spec:
            g = spec["graft"]
            donors = dict(zip(*[[int(k) for k in g["from"]], source_frames(
                {**spec, "pick": [int(v) for v in g["from"].values()]}, imp.dir)]))
            srcs = [_graft(src, donors[k], g["above"]) if k in donors else src for k, src in zip(picks, srcs)]
        if "face" in spec:
            f = spec["face"]
            donor = source_frames({**spec, "pick": [f["from"]]}, imp.dir)[0]
            srcs = [src if k == f["from"] else _face(src, donor, f["box"], f["match"])
                    for k, src in zip(picks, srcs)]
        if "clear" in spec:
            srcs = [_clear_grey(src, spec["clear"][str(k)]) if str(k) in spec["clear"] else src
                    for k, src in zip(picks, srcs)]
        if "paint" in spec:
            srcs = [_paint_spill(src, spec["paint"][str(k)], grey=True, reach=14)
                    if str(k) in spec["paint"] else src for k, src in zip(picks, srcs)]
        if "spill" in spec:
            srcs = [_paint_spill(src, spec["spill"][str(k)]) if str(k) in spec["spill"] else src
                    for k, src in zip(picks, srcs)]
        if "height" in spec:
            # A part drawn on its own (a boss segment) sets its own scale and middle.
            imp.set_reference(srcs[0], spec["height"])
        ref_x = spec.get("feet_x")
        if ref_x == "self":
            ref_x = imp.feet_x(srcs[0])
        for i, src in enumerate(srcs):
            img, mask, grid = imp.frame(src, spec.get("anchor", "ground"), ref_x, spec.get("lower", 0))
            meta = base[min(len(base) - 1, i * len(base) // len(srcs))]
            meta = {k: v for k, v in meta.items() if k not in spec.get("drop", [])}
            meta.update(spec.get("meta", {}))
            if cfg.get("detect") == "elf":
                meta = imp.detect(grid, meta)
            elif cfg.get("detect") == "hero":
                meta = imp.detect_hero(img, meta)
            elif cfg.get("detect") == "eye":
                meta = imp.detect_eye(grid, meta)
            hands = spec.get("hands")
            if hands and picks[i] < len(hands) and hands[picks[i]]:
                meta = imp.mark_hands(meta, hands[picks[i]])
            if cfg.get("head") == "top":
                # A set drawn helmed (the Elven Plate with its helmet): the crown is
                # simply the top of the figure, the crest included.
                ys, xs = np.nonzero(np.asarray(img)[..., 3] > 0)
                if len(ys):
                    meta["head"] = imp.to_point(round(xs[ys < ys.min() + 6].mean()), ys.min())
            elif cfg.get("head"):
                # Where a helmet layer sits (pass 185): the sheet is drawn bare-headed.
                h = head_point(img)
                if h:
                    meta["head"] = imp.to_point(*h)
            frames.append((img, mask, meta))
        heads = [m.get("head") for _, _, m in frames]
        for i in range(1, len(frames) - 1):
            # A fist raised over the head reads as the crown: a crown that jumps more
            # than 2 px above both neighbours' drops to the height between theirs.
            prev, here, after = heads[i - 1], heads[i], heads[i + 1]
            if prev and here and after and here[1] < min(prev[1], after[1]) - 2:
                frames[i][2]["head"] = [here[0], round((prev[1] + after[1]) / 2)]
        if cfg.get("detect") == "hero" and cfg.get("head") is True and all(m.get("head") for _, _, m in frames):
            # A body set's crown wobbles a pixel or two with the hair from frame to frame,
            # which would shake the helmet: take the median of five (around the loop).
            heads = [m["head"] for _, _, m in frames]
            n = len(heads)
            for i in range(n):
                near = [heads[(i + k) % n] if spec.get("loop") else heads[min(max(i + k, 0), n - 1)]
                        for k in range(-2, 3)]
                frames[i][2]["head"] = [int(np.median([p[0] for p in near])), int(np.median([p[1] for p in near]))]
        if "height" in spec:
            imp.set_reference(source_frames(ref, imp.dir)[0], cfg["height"])
        out[anim] = (frames, spec.get("seq"), spec.get("fps"), spec.get("loop"))
        print(f"  {name}.{anim}: {len(frames)} frames from Autosprite ({spec['file']})")
    return out


def selftest():
    """Imports a smooth 4x blow-up of the code-drawn run and checks that the figure, the
    feet and the detected neck and hand land where the code rig put them."""
    import tempfile
    import pixelrig
    import spritegen
    mod = pixelrig.autosprite_import  # this file as pixelrig sees it (not __main__)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "elf").mkdir()
        # The code-drawn sheet, with no imports (the real one may hold Autosprite frames).
        mod.SOURCES, mod.MANIFEST = tmp, tmp / "manifest.json"
        sprites = pixelrig.SPRITES
        pixelrig.SPRITES = tmp / "code"
        spritegen.main()
        pixelrig.SPRITES = sprites
        real = json.loads((tmp / "code" / "player.json").read_text())["animations"]["run"]
        src = Image.open(tmp / "code" / "player.png")
        row = real["row"] * 64
        sheet = Image.new("RGBA", (4 * 256, 2 * 256))
        for i in range(8):
            cell = src.crop((i * 64, row, i * 64 + 64, row + 64)).resize((256, 256), Image.BICUBIC)
            sheet.paste(cell, ((i % 4) * 256, (i // 4) * 256))
        sheet.save(tmp / "elf" / "run.png")
        mod.MANIFEST.write_text(json.dumps({"player": {
            "dir": "elf", "ramps": ["night", "bark", "leaf", "gold"], "height": 42, "reference": "run",
            "detect": "elf", "animations": {"run": {"file": "run.png", "frame_size": 256, "columns": 4}}}}))
        pixelrig.SPRITES = tmp / "out"
        spritegen.main()
        got = json.loads((tmp / "out" / "player.json").read_text())["animations"]["run"]["frames"]
        worst = 0.0
        for g, r in zip(got, real["frames"]):
            for key in ("neck", "hand"):
                worst = max(worst, abs(g[key][0] - r[key][0]), abs(g[key][1] - r[key][1]))
        before = np.asarray(src.crop((0, row, 512, row + 64)))[..., 3] > 0
        after = np.asarray(Image.open(tmp / "out" / "player.png").crop((0, row, 512, row + 64)))[..., 3] > 0
        overlap = (before & after).sum() / float((before | after).sum())
    print(f"selftest: silhouette overlap {overlap:.2f}, worst neck/hand error {worst:.1f} px")
    assert overlap > 0.8 and worst <= 4, "round trip drifted"
    rim_selftest()


def rim_selftest():
    """A brown block with a rim light: its top and back (left) edges come out lighter and
    cooler than its middle, its front and bottom edges do not."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "block").mkdir()
        src = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        src.paste(Image.new("RGBA", (128, 192), (110, 70, 45, 255)), (64, 32))
        src.save(tmp / "block" / "idle.png")
        old = globals()["SOURCES"]
        globals()["SOURCES"] = tmp
        try:
            cfg = {"dir": "block", "colors": 8, "ramps": ["night"], "height": 24,
                   "rim": {"color": [176, 204, 232], "mix": 0.4},
                   "animations": {"idle": {"file": "idle.png", "frame_size": 256, "columns": 1, "count": 1}}}
            imp = Importer("block", cfg, (32, 32), (16, 30))
            img = np.asarray(imp.frame(source_frames(cfg["animations"]["idle"], imp.dir)[0], "ground")[0]).astype(int)
        finally:
            globals()["SOURCES"] = old
    ys, xs = np.nonzero((img[..., 3] > 0) & (img[..., :3].sum(-1) > 3 * 40))
    top, left, right, bottom = ys.min(), xs.min(), xs.max(), ys.max()
    mid = img[(top + bottom) // 2, (left + right) // 2, :3]
    lit, front, base = img[top, (left + right) // 2, :3], img[(top + bottom) // 2, right, :3], img[bottom, (left + right) // 2, :3]
    print(f"selftest: rim {list(lit)} over {list(mid)}")
    assert lit.sum() > mid.sum() + 60 and lit[2] > mid[2] + 40, "no rim on the top edge"
    assert img[(top + bottom) // 2, left, :3].sum() > mid.sum() + 60, "no rim on the back edge"
    assert (front == mid).all() and (base == mid).all(), "rim on the front or bottom edge"


def find_loop(path, frame_size=256, min_len=6, max_len=40):
    """(start, length, score) of the cut whose last frame flows best into its first: the
    silhouette of frame start+length matches frame start. Autosprite clips hold several
    cycles, so the shortest strong match is one cycle."""
    sheet = np.asarray(Image.open(path).convert("RGBA"))[..., 3] >= 128
    cols = sheet.shape[1] // frame_size
    frames = []
    for i in range(cols * (sheet.shape[0] // frame_size)):
        x, y = (i % cols) * frame_size, (i // cols) * frame_size
        f = sheet[y:y + frame_size, x:x + frame_size]
        if not f.any():
            break
        frames.append(f)

    def iou(a, b):
        return (a & b).sum() / float(max(1, (a | b).sum()))

    best = None
    for start in range(len(frames)):
        for length in range(min_len, min(max_len, len(frames) - start - 1) + 1):
            score = iou(frames[start], frames[start + length])
            # Prefer short loops: a two-cycle loop matches as well as a one-cycle loop.
            if best is None or score > best[2] + 0.02 or (score >= best[2] - 0.005 and length < best[1]):
                best = (start, length, score)
    return best, len(frames)


def main():
    if "--loop" in sys.argv:
        args = sys.argv[sys.argv.index("--loop") + 1:]
        lo, hi = (int(args[1]), int(args[2])) if len(args) >= 3 else (6, 40)
        (start, length, score), total = find_loop(SOURCES / args[0], min_len=lo, max_len=hi)
        print(f"{args[0]}: {total} frames; loop start {start}, length {length} (match {score:.2f})")
        print(f'  "pick": {list(range(start, start + length))}')
        return
    if "--selftest" in sys.argv:
        selftest()
        return
    for script in ("spritegen.py", "castgen.py"):
        subprocess.run([sys.executable, str(Path(__file__).resolve().parent / script)], check=True)


if __name__ == "__main__":
    main()
