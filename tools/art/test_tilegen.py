#!/usr/bin/env python3
"""Guards for the backdrop gradient (bible 12.6), the moss cap (bible 12.7), the
tileset variant row (bible 12.8), the foreground silhouette (bible 12.11) and the
distant ridge layer (bible 12.12).

These cover the pure tilegen helpers that shape every far layer's sky (so the
moire dot-grid the independent grade flagged at passes 497/500/501 stays fixed)
and the grass fringe (`cap_moss`), so the flat bright-green band the pass-500
grade flagged keeps its shaded ramp, dark root line and per-tile variation. The
game test suite is Godot-only and CI does not run Python unit tests; run this
guard with `python tools/art/test_tilegen.py` after touching either. Exit code
is non-zero on the first failure, so it mutation-checks by a plain re-run.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tilegen as tg  # noqa: E402


def _nearest(name):
    """The palette name nearest in RGB to `name` (identity for a palette name)."""
    target = tg.c(name)[:3]
    return min(tg.PAL, key=lambda n: sum((tg.PAL[n][i] - target[i]) ** 2 for i in range(3)))


def test_ramp_is_palette_locked():
    ramp = tg.gradient_ramp("night-0", "crystal-1")
    assert ramp, "ramp is non-empty"
    for name in ramp:
        assert name in tg.PAL, f"{name} is a master-palette colour"


def test_ramp_has_several_steps_between_far_apart_ends():
    # The whole point: far-apart endpoints get intermediate palette steps, not a
    # two-colour field. (Mutating gradient_ramp back to [top, bottom] fails here.)
    for top, bottom in [("night-0", "sky-2"), ("night-1", "crystal-2"), ("sky-5", "sky-7")]:
        ramp = tg.gradient_ramp(top, bottom)
        assert len(ramp) >= 3, f"{top}->{bottom} ramps through >=3 palette steps, got {ramp}"


def test_ramp_ends_sit_on_the_endpoints():
    ramp = tg.gradient_ramp("night-0", "sky-2")
    assert ramp[0] == _nearest("night-0"), f"ramp starts at the top colour, got {ramp[0]}"
    assert ramp[-1] == _nearest("sky-2"), f"ramp ends at the bottom colour, got {ramp[-1]}"


def test_ramp_keeps_to_the_saturated_ramps():
    # The muted material ramps (pass 506) never enter a sky: their near-blacks are
    # closer to neutral, and picking them turned the Tower's violet night brown.
    import palette
    for top, bottom in [("night-0", "sky-2"), ("night-1", "crystal-2"), ("night-0", "stone-1"), ("night-0", "bark-2")]:
        for name in tg.gradient_ramp(top, bottom):
            assert name.split("-")[0] not in palette.MUTED, f"{top}->{bottom} uses muted {name}"


def test_ramp_has_no_repeated_neighbours():
    ramp = tg.gradient_ramp("night-0", "stone-1")
    assert all(a != b for a, b in zip(ramp, ramp[1:])), f"adjacent ramp steps differ, got {ramp}"


def test_a_solid_band_is_fully_solid():
    # At the very top the gradient is one flat colour (no stray dither pixels).
    ramp = ["night-0", "stone-0", "sky-2"]
    row = {tg.gradient_pixel(ramp, x, 0, 300) for x in range(400)}
    assert row == {ramp[0]}, f"the top row is solid, got {row}"


def test_a_seam_dithers_between_adjacent_steps_only():
    ramp = ["night-0", "stone-0", "sky-2"]
    # p = y/(h-1)*(n-1); pick y so the seam between ramp[0] and ramp[1] is active.
    h = 300
    y = round((0.5 / (len(ramp) - 1)) * (h - 1))  # frac ~ 0.5 in the first seam
    row = [tg.gradient_pixel(ramp, x, y, h) for x in range(600)]
    assert set(row) == {ramp[0], ramp[1]}, f"a seam mixes only its two neighbours, got {set(row)}"


def test_the_dither_is_noise_not_a_rigid_grid():
    # The moire signature is a fixed small period in x (the old ordered dither
    # repeated every 4 px). Value-noise dither has no such period. Mutating
    # gradient_pixel back to an ordered grid pushes a shift's match rate to ~1.0.
    ramp = ["night-0", "stone-0", "sky-2"]
    h = 300
    y = round((0.5 / (len(ramp) - 1)) * (h - 1))
    row = [tg.gradient_pixel(ramp, x, y, h) for x in range(2000)]
    for shift in (1, 2, 4, 8):
        matches = sum(1 for x in range(len(row) - shift) if row[x] == row[x + shift])
        rate = matches / (len(row) - shift)
        assert rate < 0.9, f"shift {shift}: {rate:.2f} of pixels repeat — reads as a grid, not grain"


def _moss_indices(seed, light="leaf", top=5):
    """Every (x, y, shade-index) of `light` painted by one cap_moss tile."""
    img = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
    tg.cap_moss(img, 0, 0, seed, 0, tg.T, light, None, top)
    names = {v[:3]: k for k, v in tg.PAL.items()}
    out = []
    for x in range(tg.T):
        for y in range(tg.T):
            px = img.getpixel((x, y))
            if px[3] == 0:
                continue
            name = names.get(px[:3])
            if name is None:
                continue
            ramp, i = name.rsplit("-", 1)
            if ramp == light:
                out.append((x, y, int(i)))
    return out


def test_cap_moss_is_a_shaded_ramp():
    # The fringe must span several shades, not paint one flat bright band
    # (mutating the body to a single shade fails here).
    idx = {k for _, _, k in _moss_indices(11)}
    assert len(idx) >= 3, f"the moss cap ramps through >=3 shades, got {sorted(idx)}"


def test_cap_moss_darkens_to_a_root_line():
    # Grass is lit at the tips and dark where it roots into the soil: the lowest
    # painted row is darker than the highest. (Flattening the ramp fails this.)
    px = _moss_indices(11)
    top_y = min(y for _, y, _ in px)
    bot_y = max(y for _, y, _ in px)
    top_mean = sum(k for _, y, k in px if y == top_y) / sum(1 for _, y, _ in px if y == top_y)
    bot_mean = sum(k for _, y, k in px if y == bot_y) / sum(1 for _, y, _ in px if y == bot_y)
    assert bot_mean < top_mean, f"the root line ({bot_mean:.1f}) is darker than the tips ({top_mean:.1f})"


def test_cap_moss_varies_per_tile():
    # The per-tile value shift must actually change a tile's overall brightness,
    # so a run of ground tiles reads as patches, not one stripe. Across a dozen
    # seeds the mean shade should span ~2 steps; setting tilt to 0 fails this.
    means = []
    for seed in range(11, 11 + 12):
        px = _moss_indices(seed)
        means.append(sum(k for _, _, k in px) / len(px))
    assert max(means) - min(means) >= 1.0, f"per-tile brightness barely moves: {min(means):.2f}..{max(means):.2f}"


def _build_atlas(zone="gym"):
    """Builds `zone`'s atlas into a temp dir and returns the PIL image."""
    import tempfile
    from pathlib import Path as _P
    orig = tg.TILES
    try:
        tg.TILES = _P(tempfile.mkdtemp()) / "tiles"
        tg.build_tileset(zone)
        return tg.Image.open(tg.TILES / f"{zone}.png").convert("RGBA")
    finally:
        tg.TILES = orig


def _tile(img, cx, cy):
    T = tg.T
    return img.crop((cx * T, cy * T, cx * T + T, cy * T + T))


def _differ(a, b):
    return a.tobytes() != b.tobytes()


def test_atlas_has_the_variant_row():
    # The atlas must carry row 7 (8 rows of 32 px tiles), or the factory's variant
    # coords would point past the texture. (Leaving the atlas at 7 rows fails here.)
    img = _build_atlas()
    assert img.size[1] == tg.T * 8, f"atlas is 8 rows tall for the variant row, got {img.size}"


def test_full_variants_differ_from_the_base_and_each_other():
    # The three surface variants (row 7, cols 0-2) must each be a distinct masonry
    # pattern, else scattering them would still read as one repeated tile.
    img = _build_atlas()
    masks = tg.blob_masks()
    full_i = masks.index(255)
    base = _tile(img, full_i % 8, full_i // 8)
    v = [_tile(img, k, 7) for k in range(3)]
    for k, var in enumerate(v):
        assert _differ(base, var), f"FULL variant {k} differs from the base FULL tile"
    assert _differ(v[0], v[1]) and _differ(v[1], v[2]), "the three FULL variants differ from each other"


def test_mid_and_deep_variants_are_darker_than_their_surface():
    # The row-7 MID/DEEP variants (cols 3-4, 5-6) carry the same darkening as the
    # row-6 interiors, so a darkened field does not mix bright and dark tiles.
    img = _build_atlas()

    def mean(t):
        data = t.tobytes()  # RGBA bytes
        tot = cnt = 0
        for i in range(0, len(data), 4):
            if data[i + 3]:
                tot += data[i] + data[i + 1] + data[i + 2]
                cnt += 1
        return tot / max(1, cnt)

    surface = mean(_tile(img, 0, 7))  # a bright FULL variant
    mid = mean(_tile(img, 3, 7))
    deep = mean(_tile(img, 5, 7))
    assert mid < surface, f"MID variant ({mid:.0f}) is darker than the surface ({surface:.0f})"
    assert deep < mid, f"DEEP variant ({deep:.0f}) is darker than the MID variant ({mid:.0f})"


def _fore(zone):
    """One zone's foreground image and its alpha-band measurements (bible 12.11)."""
    img = tg.foreground(zone)
    w, h = img.size
    q = h // 4
    a = img.getchannel("A")

    def opaque(region):
        return sum(region.histogram()[1:])  # alpha > 0

    top = opaque(a.crop((0, 0, w, q)))
    bot = opaque(a.crop((0, h - q, w, h)))
    bottom_row = a.crop((0, h - 1, w, h)).histogram()
    maxch = max(ch[1] for ch in img.convert("RGB").getextrema())
    return {"w": w, "h": h, "q": q, "top": top, "bot": bot,
            "bottom_clear": bottom_row[0], "maxch": maxch}


def test_foreground_exists_for_every_shipped_zone():
    # Every playable zone gets a foreground silhouette; the gym and any new zone
    # has none (Backdrop falls back to no fore layer).
    shipped = ["hearthroot", "heartwood", "tower", "haar", "boughs",
               "vorrhallow", "evercrown", "sunken", "spires"]
    for z in shipped:
        assert z in tg.FORE_KIND, f"{z} has a foreground silhouette kind"
    assert "gym" not in tg.FORE_KIND, "the gym has no foreground"


def test_foreground_is_bottom_weighted_and_clear_up_top():
    # The silhouette hugs the view bottom; the top of the frame stays clear so the
    # centre of the screen is readable in combat. (Filling the top band instead of
    # the bottom — mutating _fore_fill's range — fails the bottom-weighting.)
    for z in tg.FORE_KIND:
        m = _fore(z)
        assert m["bot"] > m["top"] * 5, f"{z}: bottom ({m['bot']}) far outweighs top ({m['top']})"
        top_frac = m["top"] / (m["w"] * m["q"])
        assert top_frac < 0.05, f"{z}: top quarter is {top_frac:.3f} opaque — not clear enough"


def test_foreground_band_reaches_the_very_bottom():
    # The ground band must fill the bottom edge, or the foreground would float.
    for z in tg.FORE_KIND:
        m = _fore(z)
        assert m["bottom_clear"] == 0, f"{z}: the bottom row has {m['bottom_clear']} transparent pixels"


def test_foreground_is_a_dark_silhouette():
    # An unlit near-black silhouette: no opaque pixel is brighter than the night
    # shades it is drawn in. (Painting it in a lit colour fails here.)
    for z in tg.FORE_KIND:
        m = _fore(z)
        assert m["maxch"] < 70, f"{z}: brightest channel {m['maxch']} is too light for a silhouette"


def _ridge(zone):
    """One zone's ridge image (bible 12.12) and its silhouette measurements: the
    first opaque y per column (the crest line), the sky clear above, the band at
    the very bottom, the brightest channel, and the seam jump against the roughest
    interior join."""
    img = tg.ridge(zone)
    w, h = img.size
    q = h // 4
    a = img.getchannel("A")
    firsts = [h] * w
    seen = 0
    data = a.tobytes()  # row-major alpha bytes
    for y in range(h):
        base = y * w
        for x in range(w):
            if firsts[x] == h and data[base + x]:
                firsts[x] = y
                seen += 1
        if seen == w:
            break
    jumps = [abs(firsts[x] - firsts[x - 1]) for x in range(1, w)]
    return {
        "w": w, "h": h, "q": q,
        "top": sum(a.crop((0, 0, w, q)).histogram()[1:]),
        "bottom_clear": a.crop((0, h - 1, w, h)).histogram()[0],
        "maxch": max(ch[1] for ch in img.convert("RGB").getextrema()),
        "horizon": sum(firsts) / w,
        "wrap_jump": abs(firsts[0] - firsts[-1]),
        "max_interior_jump": max(jumps),
    }


def test_ridge_exists_for_every_shipped_zone():
    # Every playable zone gets a distant ridge layer; the gym and any new zone has
    # none (Backdrop falls back to no ridge layer).
    shipped = ["hearthroot", "heartwood", "tower", "haar", "boughs",
               "vorrhallow", "evercrown", "sunken", "spires"]
    for z in shipped:
        assert z in tg.RIDGE_KIND, f"{z} has a ridge kind"
        assert z in tg.RIDGE_COLOR, f"{z} has a ridge colour"
    assert "gym" not in tg.RIDGE_KIND, "the gym has no ridge"


def test_ridge_is_horizon_weighted_and_clear_above():
    # The ridgeline sits at the horizon (RIDGE_BASE), its crest rising above and a
    # solid distant ground filled below; the sky above the crest stays clear so
    # the far layer grades through. (Filling from the top instead fails this.)
    for z in tg.RIDGE_KIND:
        m = _ridge(z)
        top_frac = m["top"] / (m["w"] * m["q"])
        assert top_frac < 0.02, f"{z}: top quarter is {top_frac:.3f} opaque — the sky is not clear"
        assert tg.RIDGE_BASE - 120 * tg.D < m["horizon"] < tg.RIDGE_BASE + 8 * tg.D, \
            f"{z}: crest line {m['horizon']:.0f} is not around the horizon {tg.RIDGE_BASE}"


def test_ridge_reaches_the_bottom_edge():
    # The distant ground fills to the bottom edge, so the ridge never floats with a
    # hard lower seam. (Clipping the fill short fails this.)
    for z in tg.RIDGE_KIND:
        assert _ridge(z)["bottom_clear"] == 0, f"{z}: the bottom row has transparent pixels"


def test_ridge_is_a_dark_tinted_silhouette():
    # A receded silhouette in a dark shade of the zone's ramp: darker than the lit
    # gameplay layer, so the haze can push it back without it competing. (Painting
    # it in a lit colour fails here.)
    for z in tg.RIDGE_KIND:
        m = _ridge(z)
        assert m["maxch"] < 150, f"{z}: brightest channel {m['maxch']} is too light for a receding ridge"


def test_ridge_colours_are_dark_palette_shades():
    # The body and rim are master-palette names, the body a dark shade (index <= 2)
    # and the rim one step lighter, so the ridge reads as a crest-lit silhouette.
    for z, (body, rim) in tg.RIDGE_COLOR.items():
        assert body in tg.PAL and rim in tg.PAL, f"{z}: ridge colours are palette names"
        bi = int(body.rsplit("-", 1)[1])
        ri = int(rim.rsplit("-", 1)[1])
        assert bi <= 2, f"{z}: ridge body {body} is a dark shade"
        assert ri == bi + 1, f"{z}: ridge rim {rim} is one step lighter than the body {body}"


def test_ridge_is_seamless_at_the_seam():
    # The layer repeats sideways, so the crest at column 0 must continue from the
    # last column with no cut: the roll is built from whole-cycle sines and the
    # teeth wrap, so the seam join is no rougher than the roughest interior join.
    # (Clamping the teeth to the edge instead of wrapping fails this.)
    for z in tg.RIDGE_KIND:
        m = _ridge(z)
        assert m["wrap_jump"] <= m["max_interior_jump"], \
            f"{z}: the seam jump {m['wrap_jump']} exceeds the roughest interior join {m['max_interior_jump']}"


def _course_gaps(spacing, seed=7, top=0, bottom=4000):
    """Gaps between consecutive mortar-course starts from tg.masonry_courses, with
    the 1-2px course thickness collapsed to one start per course (bible 12.14)."""
    rows = sorted(tg.masonry_courses(top, bottom, seed, spacing))
    starts = [r for i, r in enumerate(rows) if i == 0 or r - rows[i - 1] > 1]
    return [b - a for a, b in zip(starts, starts[1:])]


def test_masonry_courses_have_no_fixed_period():
    # The old lattice drew a course every `spacing` pixels on the dot (the grade's
    # "repeated stamp", passes 497/502/504). The weathered courses jitter, so the
    # gaps take several distinct values instead of one. (Removing the jitter term
    # collapses every gap to `spacing` and fails this.)
    for spacing in (24, 48, 60):
        gaps = _course_gaps(spacing)
        assert len(set(gaps)) >= 4, f"spacing {spacing}: only gaps {sorted(set(gaps))} — too regular"


def test_masonry_courses_are_partly_worn_away():
    # Roughly one course in six is missing, so some gaps run to two courses or
    # more — a gap wider than the widest a jitter alone allows (1.5x spacing).
    # (Dropping the wear test in masonry_courses keeps every course and fails this.)
    for spacing in (24, 48, 60):
        gaps = _course_gaps(spacing)
        assert max(gaps) > spacing * 1.6, \
            f"spacing {spacing}: widest gap {max(gaps)} shows no worn-away course"


def test_masonry_courses_never_overlap():
    # However the gaps jitter or a course wears away, two courses never fall on
    # top of each other: every gap stays at least half the spacing. (A jitter
    # term that could go fully negative would collapse a gap and fail this.)
    for spacing in (24, 48, 60):
        gaps = _course_gaps(spacing)
        assert min(gaps) >= spacing * 0.5, f"spacing {spacing}: a gap {min(gaps)} is too tight"


def test_masonry_shade_varies_across_a_field():
    # A masonry field draws all three values — body, a darker stone and a lighter
    # one — so it reads as varied stone, not one flat colour (the grade's flat
    # "stamp"). (Making masonry_shade always return `body` fails this.)
    seen = set()
    for x in range(0, 640, 4):
        for y in range(0, 480, 4):
            seen.add(tg.masonry_shade(x, y, 3, "night-0", "night-1", "stone-2"))
    assert {"night-0", "night-1", "stone-2"} <= seen, f"field is not varied: {seen}"


def test_masonry_shade_is_mostly_body():
    # The body colour dominates; the dark and light stones are the minority accents
    # (thresholds >0.93 and <0.16), so the field reads as stone with variation, not
    # noise. (Widening the accent bands past this balance fails.)
    counts = {"night-0": 0, "night-1": 0, "stone-2": 0}
    total = 0
    for x in range(0, 1600, 2):
        for y in range(0, 960, 2):
            counts[tg.masonry_shade(x, y, 11, "night-0", "night-1", "stone-2")] += 1
            total += 1
    assert counts["night-1"] / total > 0.6, f"body is only {counts['night-1'] / total:.2f} of the field"
    assert counts["stone-2"] / total < 0.12, f"light stone is {counts['stone-2'] / total:.2f} — too busy"


def test_flagged_backdrop_fields_use_weathered_courses():
    # Every brick/column/pier field the grade called a "regular mortar lattice"
    # (passes 497/502/504) now draws its courses through masonry_courses (jittered,
    # partly worn) instead of a fixed `y % spacing` period. Reverting any one of
    # these painters to the old on-the-dot course (dropping its masonry_courses
    # call) fails this. Swept over passes 514 (tower/vorrhallow_mid/hearthroot_far)
    # and 515 (vorrhallow_far, sunken_mid).
    import inspect

    for name in (
        "tower_far", "tower_mid", "hearthroot_far", "vorrhallow_mid",
        "vorrhallow_far", "sunken_mid",
    ):
        src = inspect.getsource(getattr(tg, name))
        assert "masonry_courses(" in src, f"{name} no longer uses weathered courses"
        # No vertical-period course lattice (`y % spacing`); a horizontal `dx %`
        # window/bolt stride is fine.
        assert "y % (" not in src and "- deck) % (" not in src, (
            f"{name} still draws a course on a fixed vertical period"
        )


def _mote_count(img, x0, y0, x1, y1, floor):
    """Pixels in a box whose RGB sum exceeds `floor` — the motes/glows far_motes lit."""
    n = 0
    for x in range(x0, x1, 2):
        for y in range(y0, y1, 2):
            if sum(img.getpixel((x, y))[:3]) > floor:
                n += 1
    return n


def test_far_motes_lift_the_dark_sky():
    # far_motes dresses a dark far sky with faint depth (design bible 12.15): over a
    # flat near-black field it adds a scatter of brighter motes and soft glows, so
    # the far backdrop reads as atmosphere with particles, not one dead dark band.
    # (A no-op far_motes — drawing nothing — fails this.)
    from PIL import Image
    import random as _r

    base = tg.c("night-0")
    img = Image.new("RGBA", (tg.BG_W, tg.BG_H), base)
    before = _mote_count(img, 0, 0, tg.BG_W, tg.BG_H, sum(base[:3]) + 8)
    tg.far_motes(img, _r.Random(1), ["sky-3", "gold-3", "sky-4"], glows=5)
    after = _mote_count(img, 0, 0, tg.BG_W, tg.BG_H, sum(base[:3]) + 8)
    assert before == 0, "the bare night-0 field has no lit pixels before"
    assert after > 150, f"far_motes barely lit the dark sky: {after} pixels"


def test_far_motes_are_biased_to_the_top():
    # The motes weight to the upper far sky — where a tall room shows only backdrop —
    # so the depth lands in the band that read as dead, not down in the structured
    # lower sky. (Dropping the top-weighting spreads them evenly and fails this.)
    from PIL import Image
    import random as _r

    base = tg.c("night-0")
    img = Image.new("RGBA", (tg.BG_W, tg.BG_H), base)
    tg.far_motes(img, _r.Random(4), ["sky-3", "gold-4", "sky-4"], glows=6)
    floor = sum(base[:3]) + 8
    top = _mote_count(img, 0, 0, tg.BG_W, tg.BG_H // 2, floor)
    bottom = _mote_count(img, 0, tg.BG_H // 2, tg.BG_W, tg.BG_H, floor)
    assert top > bottom, f"motes are not top-weighted: top {top} vs bottom {bottom}"


def test_far_motes_spare_a_bright_feature():
    # The motes are gated to dark pixels, so they never speck over a lit backdrop
    # feature (a glowing fungus, a window). The upper sky — where the motes
    # concentrate — is filled bright here, so a working gate leaves it untouched.
    # (Removing the dark gate lets the top-weighted motes land on it and fails this.)
    from PIL import Image
    import random as _r

    img = Image.new("RGBA", (tg.BG_W, tg.BG_H), tg.c("night-0"))
    bright = tg.c("gold-6")
    for x in range(tg.BG_W):
        for y in range(tg.BG_H // 2):
            img.putpixel((x, y), bright)
    tg.far_motes(img, _r.Random(9), ["sky-3", "gold-3", "sky-4"], glows=6)
    changed = 0
    for x in range(0, tg.BG_W, 2):
        for y in range(0, tg.BG_H // 2, 2):
            if img.getpixel((x, y))[:3] != bright[:3]:
                changed += 1
    assert changed == 0, f"far_motes drew over the bright upper sky in {changed} spots"


def test_dark_far_fields_dress_their_sky():
    # Every shipped dark-sky far layer calls far_motes so its far sky gets depth; the
    # daylit boughs canopy is deliberately left out (a bright sky needs no motes).
    import inspect

    for name in (
        "heartwood_far", "hearthroot_far", "tower_far", "haar_far", "vorrhallow_far",
        "evercrown_far", "sunken_far", "trials_far", "spires_far",
    ):
        src = inspect.getsource(getattr(tg, name))
        assert "far_motes(" in src, f"{name} no longer dresses its far sky with depth"
    assert "far_motes(" not in inspect.getsource(tg.boughs_far), (
        "boughs is a daylit canopy and should not get dark-sky motes"
    )


def _shrine_tile(seed):
    from PIL import Image

    img = Image.new("RGBA", (tg.T, tg.T), (0, 0, 0, 0))
    tg.paint_shrine(img, 0, 0, seed, "stone")
    return img


def test_shrine_gold_inlay_is_sparse():
    # The Spires ashlar's gold inlay is a rare, scattered accent, never a groove
    # marching across every course — the regular gold cadence read as a repeated
    # stamp (independent grade pass 515: "Spires brick field reads as one repeated
    # stamp", bible 12.8). (Lowering the inlay threshold back toward the old 0.62
    # gilds far more blocks and fails this.)
    gold = {tg.c("gold-4"), tg.c("gold-5")}
    seeds = range(200, 224)
    total = 0.0
    for seed in seeds:
        img = _shrine_tile(seed)
        g = sum(1 for y in range(tg.T) for x in range(tg.T) if img.getpixel((x, y)) in gold)
        total += g / (tg.T * tg.T)
    mean = total / len(list(seeds))
    assert mean < 0.02, f"Spires gold inlay is not sparse: {mean:.4f} of the field"


def test_shrine_course_scale_varies_with_seed():
    # The ashlar block scale is keyed to the seed, so the factory's scattered row-7
    # variants (each a fresh seed) read as differently-coursed masonry rather than
    # one stamp. A full mortar course (ly == bh-1) paints the whole row stone-1, so
    # the number of such rows in a tile tracks its course height — and that count
    # must not be constant across seeds. (A fixed bh makes every seed draw the same
    # course density and fails this.)
    stone1 = tg.c("stone-1")
    counts = set()
    for seed in range(200, 224):
        img = _shrine_tile(seed)
        rows = 0
        for y in range(tg.T):
            if sum(1 for x in range(tg.T) if img.getpixel((x, y)) == stone1) > 0.8 * tg.T:
                rows += 1
        counts.add(rows)
    assert len(counts) >= 2, f"Spires course scale does not vary with the seed: {counts}"


def test_hearthroot_houses_vary_rooflines():
    # The distant Hearthroot houses pick among several roof silhouettes (arch,
    # gable, battlement, stepped) and some carry a chimney, so a row of houses stops
    # reading as the same arch copied across (independent grade pass 515:
    # "Hearthroot background buildings are the same two silhouettes"). (Collapsing
    # the roofline back to the single sine arch drops these and fails this.)
    import inspect

    src = inspect.getsource(tg.hearthroot_far)
    for style in ("gable", "battlement", "stepped"):
        assert f'"{style}"' in src, f"hearthroot_far no longer draws a {style} roof"
    assert "chimney" in src.lower(), "hearthroot_far no longer draws chimneys"


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        t()
        print(f"ok  {t.__name__}")
    print(f"\n{len(tests)} checks passed")


if __name__ == "__main__":
    main()
