#!/usr/bin/env python3
"""Guards for the backdrop gradient (bible 12.6), the moss cap (bible 12.7), the
tileset variant row (bible 12.8), the foreground silhouette (bible 12.11), the
distant ridge layer (bible 12.12) and the Spires' sky islands (bible 12.33).

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


def test_masonry_shade_lays_a_running_bond_not_a_column_grid():
    # The mid column/pier fields (sunken, vorrhallow) and the far brick fields draw
    # their stones with masonry_shade. It used to key on (x // cell, y // cell), so
    # every cell boundary fell on the same vertical line for every row — same-value
    # stones stacked into straight columns and the field read as one stamped lattice
    # (independent grade, pass 504). A running bond shifts each course horizontally,
    # so no single x carries a shade transition on more than a fraction of rows.
    cell, seed, span = 16, 560, 16 * 40
    rows = [[tg.masonry_shade(x, y, seed, "night-0", "night-1", "stone-2", cell)
             for x in range(span)] for y in range(16 * 40)]
    n = len(rows)
    peak = max(sum(1 for r in rows if r[x] != r[x - 1]) / n for x in range(1, span))
    # Running bond holds the peak near 0.15; reverting to the aligned grid
    # (dropping the per-course offset) pushes it to ~0.48 and fails.
    assert peak < 0.30, f"a vertical seam carries transitions on {peak:.2f} of rows — reads as a stacked column grid, not a bond"


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


def _moss_top_clear(seed, sculpt):
    """How many top-row (y==0) columns a cap_moss tile leaves transparent."""
    img = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
    tg.cap_moss(img, 0, 0, seed, 0, tg.T, "leaf", None, 4, sculpt)
    return sum(1 for x in range(tg.T) if img.getpixel((x, 0))[3] == 0)


def test_cap_moss_sculpt_carves_the_silhouette():
    # The sculpted crown (heartwood / haar) carves dips the flat cap never had,
    # so the ledge top is not a razor-straight shelf. Across seeds the sculpted
    # tile leaves strictly more top-row pixels transparent than the flat one.
    # (Dropping the `crown` carve makes the two equal and fails here.)
    more = 0
    for seed in range(11, 11 + 12):
        if _moss_top_clear(seed, True) > _moss_top_clear(seed, False):
            more += 1
    assert more >= 10, f"the sculpted crown carves more top-row dips on {more}/12 seeds"


def test_cap_moss_sculpt_is_a_deeper_fringe():
    # The muted sculpt runs the upper fringe a shade deeper (less neon), so the
    # grass trim reads closer to the dressed-stone lip. The mean leaf shade of a
    # sculpted tile is lower (darker) than the flat one. (Dropping `mute` ties
    # them and fails here.)
    lower = 0
    for seed in range(11, 11 + 12):
        flat = _moss_indices(seed, top=4)
        scu = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
        tg.cap_moss(scu, 0, 0, seed, 0, tg.T, "leaf", None, 4, True)
        names = {v[:3]: k for k, v in tg.PAL.items()}
        svals = []
        for x in range(tg.T):
            for y in range(tg.T):
                px = scu.getpixel((x, y))
                if px[3] == 0:
                    continue
                nm = names.get(px[:3])
                if nm and nm.rsplit("-", 1)[0] == "leaf":
                    svals.append(int(nm.rsplit("-", 1)[1]))
        fmean = sum(k for _, _, k in flat) / len(flat)
        if svals and sum(svals) / len(svals) < fmean:
            lower += 1
    assert lower >= 10, f"the sculpted fringe is deeper than the flat one on {lower}/12 seeds"


def _wood_shades(seed, ramp="bark"):
    img = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
    tg.paint_wood(img, 0, 0, seed, ramp)
    names = {v[:3]: k for k, v in tg.PAL.items()}
    seen = {}
    for x in range(tg.T):
        for y in range(tg.T):
            nm = names.get(img.getpixel((x, y))[:3])
            if nm and nm.rsplit("-", 1)[0] == ramp:
                seen[int(nm.rsplit("-", 1)[1])] = seen.get(int(nm.rsplit("-", 1)[1]), 0) + 1
    return seen


def test_paint_wood_has_surface_value_variation():
    # The wood face must span several shades with no single shade swamping it, so
    # it reads as mottled heartwood, not a flat grain field. (Removing the patch
    # term collapses it toward two shades and fails the spread or the dominance.)
    seen = _wood_shades(11)
    assert len(seen) >= 3, f"the wood face spans >=3 shades, got {sorted(seen)}"
    total = sum(seen.values())
    assert max(seen.values()) / total < 0.80, "no single wood shade swamps the face"


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


def test_foreground_stays_a_low_fringe():
    # The grade of pass 535: posts and reeds up to 128 px tall stood over the play
    # layer as black bars. No silhouette rises more than FORE_MAX_RISE world pixels
    # above the band (bible 12.29; Backdrop.FORE_MAX_RISE mirrors it).
    base = tg.FORE_FLOOR - tg.FORE_BAND
    for z in tg.FORE_KIND:
        bbox = tg.foreground(z).getchannel("A").getbbox()
        rise = (base - bbox[1]) / tg.D
        assert rise <= tg.FORE_MAX_RISE, f"{z}: silhouettes rise {rise:.1f} px, over {tg.FORE_MAX_RISE}"


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


def _accent_field(seed=560, cell=16, w=640, h=480):
    """A masonry_shade field with sentinel names: D(ark), B(ody), L(ight)."""
    return [[tg.masonry_shade(x, y, seed, "D", "B", "L", cell) for x in range(w)] for y in range(h)]


def test_proud_stones_are_bricks_with_a_shadowed_foot():
    # The accent stones used to be flat squares a shade lighter or darker than the
    # body, with no edge of their own, which the pass-529 grade read as random
    # "missing pixel" blocks in the tower, Vorrhallow and Hearthroot ruins (bible
    # 12.27). A proud stone is now a brick half as tall as it is wide, its lit face
    # ending on a shadow along its foot. (Reverting to the flat square fails: its
    # light runs are a whole cell tall and end on the body.)
    cell = 16
    f = _accent_field(cell=cell)
    runs = 0
    for x in range(len(f[0])):
        y = 1
        while y < len(f) - 1:
            if f[y][x] == "L" and f[y - 1][x] != "L":
                n = 0
                while y + n < len(f) and f[y + n][x] == "L":
                    n += 1
                if n >= 3 and y + n < len(f):
                    runs += 1
                    assert n <= cell // 2, f"a lit stone {n} px tall at x={x} — a square, not a brick"
                    assert f[y + n][x] == "D", f"a lit stone at x={x} ends on {f[y + n][x]}, not its shadow"
                y += max(n, 1)
            else:
                y += 1
    assert runs > 50, f"only {runs} proud stones in the field"


def test_recessed_stones_carry_a_lit_sill():
    # A darker stone is a recess (a slot window or a missing stone): dark inside
    # with a lit sill along its foot, so it reads as an opening and not a hole in
    # the picture. Many lit pixels sit right under a dark one. (Dropping the sill
    # leaves the recess flat dark and the share falls to a few percent.)
    f = _accent_field()
    lit = sill = 0
    for y in range(1, len(f)):
        for x in range(len(f[0])):
            if f[y][x] == "L":
                lit += 1
                if f[y - 1][x] == "D":
                    sill += 1
    assert sill / lit > 0.15, f"only {sill / lit:.2f} of the lit pixels are sills under a recess"


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


# --- One-way plank material and support (bible 12.20, pass 521) ----------------
def _one_way_tile(zone):
    """The one-way plank tile (atlas col 0, row 6) for `zone`."""
    return _tile(_build_atlas(zone), 0, 6)


def _ramp_of(px):
    """The master-palette ramp family nearest in RGB to an opaque pixel."""
    best = min(tg.PAL, key=lambda n: sum((tg.PAL[n][i] - px[i]) ** 2 for i in range(3)))
    return best.rsplit("-", 1)[0]


def _dominant_board_ramp(zone):
    """The ramp family most of a zone's plank BOARD (its top 6 world px) is painted
    in, ignoring the dark grooves and night-0 outline."""
    from collections import Counter
    t = _one_way_tile(zone)
    px = t.load()
    counts = Counter()
    for y in range(3, 6 * tg.D):  # the board body, below the catch-light rows
        for x in range(tg.T):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            fam = _ramp_of((r, g, b))
            if fam != "night" or tg.PLANK[zone]["wood"] == "night":  # skip the groove/outline shadow
                counts[fam] += 1
    return counts.most_common(1)[0][0] if counts else None


def test_one_way_plank_differs_across_the_graded_trio():
    # The grade (pass 520) named heartwood, haar and spires as sharing one copy-
    # pasted plank. Each now carries its own material, so the three tiles differ.
    # (Reverting paint_one_way to the hardcoded single `bark` board makes all three
    # byte-identical and fails this.)
    planks = {z: _one_way_tile(z) for z in ("heartwood", "haar", "spires")}
    pairs = [("heartwood", "haar"), ("haar", "spires"), ("heartwood", "spires")]
    for a, b in pairs:
        assert _differ(planks[a], planks[b]), f"{a} and {b} planks are distinct materials"


def test_one_way_plank_board_uses_its_zone_material():
    # Each plank's board is painted in its zone's own wood/stone ramp, not one
    # shared bark. (Hardcoding `wood = "bark"` turns haar's board bark, not umber,
    # and spires' bark, not ochre, so the dominant ramp no longer matches the spec
    # and this fails.)
    for zone in ("heartwood", "haar", "spires", "evercrown", "tower"):
        want = tg.PLANK[zone]["wood"]
        got = _dominant_board_ramp(zone)
        assert got == want, f"{zone} plank board is {got!r}, expected its {want!r} material"


def test_one_way_plank_rests_on_a_trestle_below_the_board():
    # The stub bracket became a drawn trestle whose legs reach into the lower half
    # of the tile, so the ledge reads as carried, not floating. Opaque pixels must
    # appear below the old bracket depth (10 world px). (Dropping the leg-drawing
    # loop leaves nothing that deep and fails this.)
    deep = 11 * tg.D  # render row below the former stub (which stopped at 10*D)
    # (The Evercrown's shelf is grown, not built, since pass 542: tendrils, not a
    # trestle, hang under it; test_evercrown_shelf_* cover it.)
    for zone in ("heartwood", "haar", "sunken"):
        t = _one_way_tile(zone)
        px = t.load()
        opaque = sum(1 for y in range(deep, tg.T) for x in range(tg.T) if px[x, y][3] != 0)
        assert opaque > 0, f"{zone} plank has no trestle below the board (row >= {deep})"


def _lum(col):
    return 0.299 * col[0] + 0.587 * col[1] + 0.114 * col[2]


def test_evercrown_mid_tendrils_read_against_the_ribbed_far_wall():
    # The nearer stillglass tendrils used to be painted in the far wall's own two
    # rib colours (night-1 / crystal-1), so they camouflaged into it (the grade's
    # 'ambiguous translucent blocks / mid tendrils unclear against the ribbed far
    # wall', pass 503/520, bible 12.20). They now carry a lit crystal body
    # (crystal-2/-3) and a dark night-0 silhouette rim, a clear step brighter than
    # the wall. (Reverting the body to night-1/crystal-1 drops crystal-2/-3 and the
    # brightness margin, so this fails.)
    mid = tg.evercrown_mid()
    px = mid.load()
    w, h = mid.size
    cols = [px[x, y] for y in range(h) for x in range(w) if px[x, y][3] != 0]
    present = set(cols)
    for shade in ("crystal-2", "crystal-3", "night-0"):
        assert tg.c(shade) in present, f"evercrown tendrils carry {shade}"
    body = [col for col in cols if col in (tg.c("crystal-2"), tg.c("crystal-3"))]
    assert body, "tendrils have a lit crystal body"
    body_lum = sum(_lum(col) for col in body) / len(body)
    wall_lum = max(_lum(tg.c("crystal-1")), _lum(tg.c("night-1")))
    assert body_lum > wall_lum + 20, (
        f"tendril body (lum {body_lum:.0f}) reads a clear step brighter than the far "
        f"wall ribs (lum {wall_lum:.0f})")


def _solid_body_warmth(zone):
    """Mean (R - B) of a fully-solid interior tile for `zone`: positive is warm,
    negative cool. Covers the whole tile (body, sides, outline, cap)."""
    img = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
    tg.paint_tile(img, 0, 0, 255, zone, 101)
    rs = bs = n = 0
    for y in range(tg.T):
        for x in range(tg.T):
            p = img.getpixel((x, y))
            if p[3] == 0:
                continue
            rs += p[0]
            bs += p[2]
            n += 1
    return (rs - bs) / n


def test_haar_and_sunken_play_tiles_read_warm_against_their_cool_backdrop():
    # The independent grade (pass 505) read haar and sunken as a low-contrast
    # grey-green / grey-teal where the play field merged into the backdrop and mist.
    # Pass 524 warms their solid tiles from the cool "stone" lavender to "umber", so
    # the standable geometry (paint_limb "old bone", paint_spring "pale limestone")
    # reads warm against each zone's cool backdrop. Backdrop.ZONE_HAZE for both is
    # cool (haar Color8(74,84,98) and sunken Color8(56,62,80), each R-B = -24), so a
    # warm play tile is a clear temperature split. (Reverting either ramp to "stone"
    # makes the body cool, R-B negative, and fails this.)
    for zone in ("haar", "sunken"):
        warmth = _solid_body_warmth(zone)
        assert warmth >= 10.0, (
            f"{zone} play tile reads warm (R-B {warmth:+.1f} >= +10) against its "
            f"cool backdrop (haze R-B -24)")


def _scatter_seed(cx, cy):
    # Mirror TilesetFactory.ground(): four FULL variants (base tile + row-7 cols
    # 0-2) scattered across a solid field by a per-cell hash.
    full_idx = tg.blob_masks().index(255)
    h = abs((cx * 73856093) ^ (cy * 19349663))
    k = h % 4
    return (11 + full_idx) if k == 0 else 201 + (k - 1)


def test_paint_bricks_does_not_stack_its_vertical_joints_across_a_field():
    # The independent grade (pass 525) read the gameplay brick columns as one 32 px
    # tile copy-pasted down a pier. paint_bricks now carries a per-tile vertical
    # phase and a per-course horizontal jitter (running bond, bible 12.23), so the
    # vertical joints no longer land at the same x in every scattered tile. Over a
    # tall scattered field, no single interior pixel column is a vertical colour
    # edge (a joint) in most of its rows. The tile-seam columns (x % T == 0) are
    # skipped: adjacent atlas tiles are independent there, so an edge is inherent
    # and not the stacking the fix targets. Mutation: dropping the vertical phase
    # and the horizontal jitter (the old fixed half-brick bond) re-aligns the
    # interior joints (peak ~0.52) and fails.
    cols, rows = 6, 16
    img = tg.Image.new("RGBA", (cols * tg.T, rows * tg.T), tg.CLEAR)
    for cy in range(rows):
        for cx in range(cols):
            tg.paint_bricks(img, cx * tg.T, cy * tg.T, _scatter_seed(cx, cy), "stone")
    W, H = img.size
    peak = 0.0
    for x in range(1, W):
        if x % tg.T == 0:
            continue
        edges = sum(1 for y in range(H)
                    if img.getpixel((x, y))[:3] != img.getpixel((x - 1, y))[:3])
        peak = max(peak, edges / H)
    assert peak < 0.45, f"brick joints still stack into a column (peak interior edge share {peak:.2f})"


def _spring_lum_col(seed, x):
    img = tg.Image.new("RGBA", (tg.T, tg.T), tg.CLEAR)
    tg.paint_spring(img, 0, 0, seed, "umber")
    return [sum(img.getpixel((x, y))[:3]) / 3.0 for y in range(tg.T)]


def test_paint_spring_wraps_across_the_tile_width():
    # The sunken ashlar (bible 12.39) places its head joints modulo the tile width
    # and gives every block one body value, so a tile's right edge flows into its
    # own left edge (the seam guard of bible 12.23 still holds). The mean
    # luminance step across that wrap seam (col T-1 -> col 0) is no worse than a
    # typical interior step.
    for seed in (201, 202, 203):
        left, right = _spring_lum_col(seed, 0), _spring_lum_col(seed, tg.T - 1)
        seam = sum(abs(a - b) for a, b in zip(left, right)) / tg.T
        interior = 0.0
        for x in (tg.T // 4, tg.T // 2, 3 * tg.T // 4):
            a, b = _spring_lum_col(seed, x), _spring_lum_col(seed, x - 1)
            interior += sum(abs(p - q) for p, q in zip(a, b)) / tg.T
        interior /= 3.0
        assert seam <= interior * 1.6 + 6.0, (
            f"sunken ashlar does not wrap (seed {seed}): wrap seam {seam:.1f} vs "
            f"interior step {interior:.1f}")


def test_paint_spring_is_ashlar_not_stripes():
    # The pass 545 grade read the Sunken pillars as "striped wallpaper": the old
    # strata alternated two body values layer by layer at the same heights in
    # every tile. The ashlar gives every course the same body value (the most
    # common colour in each course is one palette name), and the head joints land
    # at different x across the scattered variants, so no joint runs down a
    # pillar. (Alternating the course value, or fixing the joint x, fails.)
    T, ch = tg.T, tg.SPRING_COURSE * tg.D
    seeds = (11 + tg.blob_masks().index(255), 201, 202, 203)
    joints = set()
    for seed in seeds:
        img = tg.Image.new("RGBA", (T, T), tg.CLEAR)
        tg.paint_spring(img, 0, 0, seed, "umber")
        bodies = []
        for course in range(T // ch):
            counts = {}
            for y in range(course * ch, course * ch + ch):
                for x in range(T):
                    p = img.getpixel((x, y))
                    counts[p] = counts.get(p, 0) + 1
            bodies.append(max(counts, key=counts.get))
            joints.update(tg.spring_joints(seed, course))
        assert len(set(bodies)) == 1, f"seed {seed}: the courses alternate body value {bodies}"
        assert bodies[0] == tg.c("umber-4"), f"seed {seed}: the body is umber-4"
    assert len(joints) >= 5, f"the head joints line up across the variants: {sorted(joints)}"
    for seed in range(300, 340):
        for course in range(T // ch):
            js = sorted(tg.spring_joints(seed, course))
            assert all(4 * tg.D <= j <= 12 * tg.D for j in js), f"a joint strays near the tile edge: {js}"
            if len(js) == 2:
                assert js[1] - js[0] >= 6 * tg.D, f"two joints make a sliver: {js}"


def _fill_busyness(zone, seed):
    """The share of neighbouring pixel pairs (right and below, wrapping) in one
    zone's full interior tile that change colour, and the share of pixels that
    differ from all four neighbours (single-pixel static)."""
    T = tg.T
    img = tg.Image.new("RGBA", (T, T), tg.CLEAR)
    tg.paint_tile(img, 0, 0, 255, zone, seed)
    px = lambda x, y: img.getpixel((x % T, y % T))[:3]
    diff = iso = 0
    for y in range(T):
        for x in range(T):
            p = px(x, y)
            n = [px(x + 1, y), px(x - 1, y), px(x, y + 1), px(x, y - 1)]
            diff += (p != n[0]) + (p != n[2])
            iso += all(p != q for q in n)
    return diff / (2 * T * T), iso / (T * T)


def test_graded_play_fill_is_calm():
    # The independent grade (pass 529) read the play tiles' interior fill as noisy
    # high-frequency texture: static-like dirt in the Haar and the Heartwood,
    # zig-zag strata in the Sunken, busy cobble in the Evercrown. Pass 534 rebuilt
    # those painters from long, flat marks (bible 12.28). Over the full tile and its
    # scattered variants, fewer than 23% of neighbouring pixel pairs change colour
    # (the old painters ran 26% to 33%) and almost no pixel stands alone. (Restoring
    # the old wood grain, strata or small cells fails the share.)
    for zone in ("haar", "heartwood", "sunken", "evercrown", "boughs"):  # boughs: pass 555
        seeds = (11 + tg.blob_masks().index(255), 201, 202, 203)
        edge = sum(_fill_busyness(zone, s)[0] for s in seeds) / len(seeds)
        iso = sum(_fill_busyness(zone, s)[1] for s in seeds) / len(seeds)
        assert edge < 0.23, f"{zone} fill is busy: {edge:.3f} of neighbour pairs change"
        assert iso < 0.01, f"{zone} fill has single-pixel static: {iso:.3f}"


def test_wood_strands_run_on_from_tile_to_tile():
    # With the noise gone, a strand layout drawn per tile cut a hard seam across
    # every tile row of the Heartwood walls. The strands now share one layout
    # (WOOD_STRANDS), so the bottom row of one tile matches the top row of the
    # next over most columns; only grain lines and knots break it. (Keying the
    # layout on the tile's seed again drops the match to about half.)
    T = tg.T
    for a, b in ((201, 202), (57, 203), (101, 211)):
        top = tg.Image.new("RGBA", (T, T), tg.CLEAR)
        low = tg.Image.new("RGBA", (T, T), tg.CLEAR)
        tg.paint_wood(top, 0, 0, a, "bark")
        tg.paint_wood(low, 0, 0, b, "bark")
        same = sum(top.getpixel((x, T - 1)) == low.getpixel((x, 0)) for x in range(T))
        assert same / T >= 0.75, f"wood strands break at the tile seam ({a}->{b}): {same}/{T}"


def test_evercrown_cells_join_across_tile_edges():
    # The broad Evercrown cells (pass 534) were first drawn per tile, so every
    # one-tile ledge broke into the same cut-off cells every 32 px. The cells now
    # wrap over the tile (two across, two down, the points outside the tile copied
    # from the cells inside it) and share one layout (MEAT_CELLS), so any two
    # tiles meet with their seams joined (checked by eye on the drift_well ledges).
    # Held as: tiles of different seeds draw the same cells and differ only in the
    # rare pores. (Keying the cell centres on the seed again drops the agreement
    # to about half.)
    T = tg.T
    for a, b in ((201, 202), (57, 203), (101, 221)):
        ia = tg.Image.new("RGBA", (T, T), tg.CLEAR)
        ib = tg.Image.new("RGBA", (T, T), tg.CLEAR)
        tg.paint_meteor(ia, 0, 0, a, "night")
        tg.paint_meteor(ib, 0, 0, b, "night")
        same = sum(ia.getpixel((x, y)) == ib.getpixel((x, y)) for x in range(T) for y in range(T))
        assert same / (T * T) >= 0.95, (
            f"evercrown tiles {a} and {b} draw different cells ({same}/{T * T} agree)")



# --- Sky islands (design bible 12.33) ---------------------------------------------------

def _island_image(cx=300, cy=200, w=160, seed=3):
    import random as _r
    img = tg.Image.new("RGBA", (tg.BG_W, tg.BG_H), tg.CLEAR)
    tg.island(img, cx * tg.D, cy * tg.D, w * tg.D, _r.Random(seed))
    return img


def _island_pixels(img):
    return {(x, y): img.getpixel((x, y)) for x in range(0, tg.BG_W) for y in range(0, tg.BG_H)
            if img.getpixel((x, y))[3]}


def test_island_is_shaded_on_a_ramp_not_one_fill():
    # The pass 540 grade called the Spires' sky islands "flat single-fill props":
    # a magenta cone with one green line. The rock is now a four-tone ramp plus an
    # outline, the grass three tones, every one a master palette value. (Painting
    # the rock in one tone fails the count.)
    px = _island_pixels(_island_image())
    names = {n for n, v in tg.PAL.items()}
    used = {next(n for n in names if tg.PAL[n][:3] == col[:3]) for col in set(px.values())}
    rock = used & set(tg.ISLAND_ROCK)
    assert rock == set(tg.ISLAND_ROCK), f"the rock uses only {sorted(rock)}"
    assert tg.ISLAND_LINE in used, "no outline"
    assert set(tg.ISLAND_GRASS) <= used, f"the grass lip uses only {sorted(used & set(tg.ISLAND_GRASS))}"


def test_island_keeps_the_world_pixel_grain():
    # The old island was hatched at half-size atlas pixels; the prop is now painted
    # in whole world pixels (D x D blocks), like the rest of the game.
    img = _island_image()
    D = tg.D
    for (x, y) in _island_pixels(img):
        bx, by = x - x % D, y - y % D
        assert img.getpixel((bx, by)) == img.getpixel((x, y)), f"a half pixel at {x},{y}"


def test_island_is_lit_from_the_upper_left():
    # Light falls from the upper left: the rock's left half is brighter than its
    # right, and its top band brighter than its hanging spurs. (Swapping the
    # light to the right fails the first; dropping the depth term the second.)
    px = _island_pixels(_island_image())
    rock = {p: c for p, c in px.items() if c[:3] in {tg.PAL[n][:3] for n in tg.ISLAND_ROCK}}
    xs = sorted(x for x, _ in rock)
    ys = sorted(y for _, y in rock)
    xm, ym = xs[len(xs) // 2], ys[0] + (ys[-1] - ys[0]) // 3

    def lum(sel):
        v = [sum(c[:3]) for p, c in rock.items() if sel(p)]
        return sum(v) / max(1, len(v))
    assert lum(lambda p: p[0] < xm) > lum(lambda p: p[0] >= xm) + 10, "the left flank is not the lit one"
    assert lum(lambda p: p[1] < ym) > lum(lambda p: p[1] >= ym) + 10, "the spurs are as bright as the top"


def test_island_outline_is_selective():
    # The dark outline closes the shadow side and the underside, not the lit
    # flank: almost every rock pixel with open sky to its right is outline, while
    # most with open sky to its left are a lit tone. (A full outline all round
    # fails the second.)
    px = _island_pixels(_island_image())
    D = tg.D
    line = tg.PAL[tg.ISLAND_LINE][:3]
    rock = {tg.PAL[n][:3] for n in tg.ISLAND_ROCK} | {line}
    drawn = {(x // D, y // D) for (x, y) in px}  # open sky is undrawn, not moss
    cells = {(x // D, y // D): c[:3] for (x, y), c in px.items() if c[:3] in rock}
    right = [c for (x, y), c in cells.items() if (x + 1, y) not in drawn]
    left = [c for (x, y), c in cells.items() if (x - 1, y) not in drawn and (x, y + 1) in cells]
    assert len(right) > 20 and len(left) > 10
    assert sum(c == line for c in right) / len(right) > 0.9, "the shadow side is not outlined"
    assert sum(c == line for c in left) / len(left) < 0.3, "the lit flank is outlined"


def test_islands_are_not_one_stamp():
    # Each island's silhouette comes from its own seed: a belly and a cluster of
    # spurs, so two islands of one width differ, and the underside hangs in more
    # than one point. (Dropping the lesser spurs fails the point count.)
    a = tg.island_cells(300 * tg.D, 200 * tg.D, 160 * tg.D, 120 * tg.D, 11)
    b = tg.island_cells(300 * tg.D, 200 * tg.D, 160 * tg.D, 120 * tg.D, 12)
    assert a != b, "two seeds drew the same island"
    for cells in (a, b):
        bottoms = {}
        for x, y in cells:
            bottoms[x] = max(bottoms.get(x, y), y)
        def side(x, a, b):
            return [bottoms[v] for v in range(x + a, x + b + 1) if v in bottoms] or [0]
        # A tip is the deepest column within three of it and hangs at least four world
        # pixels below a column within eight on each side, so a bump of noise on the
        # sloping belly is not a spur.
        tips = [x for x in sorted(bottoms) if bottoms[x] - 200 > 10
                and bottoms[x] == max(side(x, -3, 3)) and bottoms.get(x + 1, 0) < bottoms[x]
                and bottoms[x] - min(side(x, -8, -1)) >= 4 and bottoms[x] - min(side(x, 1, 8)) >= 4]
        assert len(tips) >= 2, f"the underside hangs in only {len(tips)} point(s)"


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        t()
        print(f"ok  {t.__name__}")
    print(f"\n{len(tests)} checks passed")


# --- The Evercrown's grown shelf (bible 12.34, pass 542) -------------------------
def _shelf():
    t = _one_way_tile("evercrown")
    return t, t.load()


def test_evercrown_shelf_is_grown_from_the_zone_not_hot_stillglass():
    # The grade (pass 540) read the old crystal-ramp board as a flat hot-magenta
    # prop. The shelf is now night-ramp matter with only a glaze of crystal-3.
    # (Restoring PLANK["evercrown"]["wood"] = "crystal" fails this.)
    t, px = _shelf()
    hot = {tg.c(f"crystal-{i}")[:3] for i in (4, 5, 6, 7)}
    names = {tg.c(n)[:3]: n for n in tg.PAL}
    seen = {}
    for y in range(t.height):
        for x in range(t.width):
            p = px[x, y]
            if p[3]:
                assert p[:3] not in hot, f"hot stillglass at {x},{y}"
                # The sinew in the notches is crystal-1 (wine, bible 12.48); the
                # glaze on the lit rim is the lighter crystal.
                n = "sinew" if names[p[:3]] == "crystal-1" else names[p[:3]].rsplit("-", 1)[0]
                seen[n] = seen.get(n, 0) + 1
    total = sum(seen.values())
    assert seen.get("night", 0) > 0.7 * total, f"the shelf is mostly night matter: {seen}"
    assert 0 < seen.get("crystal", 0) < 0.08 * total, f"crystal is only a glaze: {seen}"
    assert seen.get("sinew", 0) > 0, "sinew shows in the notches"


def test_evercrown_shelf_sits_on_the_world_pixel_grain():
    t, px = _shelf()
    D = tg.D
    for y in range(0, t.height, D):
        for x in range(0, t.width, D):
            block = {px[x + i, y + j] for i in range(D) for j in range(D)}
            assert len(block) == 1, f"block {x},{y} is split: {block}"


def test_evercrown_shelf_has_an_unbroken_lit_top_and_a_shadowed_underside():
    # The top band runs the whole tile, so a run of shelves reads as one ledge;
    # the top is lit and the underside closes in night-0, the top never does.
    # (Shading the lobes from below, or outlining all round, fails this.)
    t, px = _shelf()
    W = tg.T // tg.D
    top = [px[x * tg.D, 0] for x in range(W)]
    assert all(p[3] for p in top), "the top band is unbroken"
    assert tg.c("night-0") not in top, "no outline along the lit top"
    lum_top = sum(_lum(p) for p in top) / W
    skip = {tg.c(n)[:3] for n in ("night-0", "crystal-1", "sky-4", "sky-6")}
    under = [px[x * tg.D, y * tg.D] for x in range(W) for y in (2, 3, 4)
             if px[x * tg.D, y * tg.D][3] and px[x * tg.D, y * tg.D][:3] not in skip]
    assert lum_top > sum(_lum(p) for p in under) / len(under) + 20, "the top is lit, the lobes fall into shade"
    for x in range(W):
        col = [px[x * tg.D, y * tg.D] for y in range(6)]
        body = [i for i, p in enumerate(col) if p[3] and p[:3] != tg.c("crystal-1")[:3]]
        if body:
            assert col[body[-1]][:3] == tg.c("night-0")[:3], f"column {x} closes in night-0"


def test_evercrown_shelf_tiles_seamlessly():
    # Lobes sum to the tile width and the top band meets itself across the seam.
    t, px = _shelf()
    assert sum(tg.SHELF_SEGS) == tg.T // tg.D
    for y in range(2):
        assert px[0, y * tg.D] == px[t.width - 1, y * tg.D] or (px[0, y * tg.D][3] and px[t.width - 1, y * tg.D][3])


def _ember():
    return {tg.c(f"ember-{i}")[:3] for i in range(8)}


def _uses(img, colours):
    """How many opaque pixels of `img` are one of `colours` (RGB triples)."""
    px = img.convert("RGBA").load()
    w, h = img.size
    return sum(1 for y in range(h) for x in range(w) if px[x, y][3] and px[x, y][:3] in colours)


def test_the_evercrown_keeps_red_for_what_hurts():
    # Design bible 12.48: in the Evercrown the ember ramp belongs to what hurts
    # (thorn bulbs, fire seals, a foe's tell). Its tiles, backdrops and decor
    # carry none, so a red thing on screen is a threat. (Putting the ember seam
    # back in paint_meteor, the red bead on a tendril or the red core glow fails.)
    ember = _ember()
    tile = tg.Image.new("RGBA", (tg.T * 4, tg.T), tg.CLEAR)
    for i in range(4):
        tg.paint_tile(tile, i * tg.T, 0, 255, "evercrown", 101 + i)
    assert _uses(tile, ember) == 0, "the Evercrown's solid tiles carry no ember"
    assert _uses(tg.evercrown_far(), ember) == 0, "the Evercrown's far wall carries no ember"
    assert _uses(tg.evercrown_mid(), ember) == 0, "the Evercrown's tendrils carry no ember"
    root = Path(__file__).resolve().parents[2]
    for rel in ("assets/tiles/evercrown.png", "assets/bg/evercrown_far.png",
                "assets/bg/evercrown_mid.png", "assets/decor/evercrown.png"):
        assert _uses(tg.Image.open(root / rel), ember) == 0, f"{rel} carries no ember"


def test_evercrown_floor_stubs_do_not_pass_for_spikes():
    # Design bible 12.48: the floor's crystal stubs were tall bright splinters, the
    # shape and brightness of a row of spikes. They are short (under a spike's 10
    # world pixels) and no brighter than their night-3 rim.
    import random
    import decorgen as dg
    assert dg.EVERCROWN_STUB < 10, "a stub is shorter than a floor spike"
    cap = _lum(tg.c("night-3"))
    for seed in range(12):
        cell = dg.evercrown_shards(random.Random(seed))
        px = cell.img.load()
        w, h = cell.img.size
        rows = [y for y in range(h) if any(px[x, y][3] for x in range(w))]
        assert rows, "a stub is drawn"
        tall = (max(rows) - min(rows) + 1) / dg.D  # world pixels, with the outline
        assert tall <= dg.EVERCROWN_STUB + 2, f"seed {seed}: a stub stands {tall} px tall"
        for y in rows:
            for x in range(w):
                if px[x, y][3]:
                    assert _lum(px[x, y]) <= cap + 1, f"seed {seed}: a stub pixel is brighter than its rim"


def test_the_crystal_halls_ridges_sit_deep_in_their_own_hue():
    # Design bible 12.48: both halls shared one crystal-1 ridge, the value and hue
    # of their play tiles' shadows. Each ridge is now the darkest shade of its
    # zone's own hue: Vorrhallow's drowned blue, the Evercrown's wine.
    assert tg.RIDGE_COLOR["vorrhallow"] == ("sky-0", "sky-1")
    assert tg.RIDGE_COLOR["evercrown"] == ("crystal-0", "crystal-1")
    for z in ("vorrhallow", "evercrown"):
        body = tg.c(tg.RIDGE_COLOR[z][0])
        assert _lum(body) < 25, f"{z}: the ridge body (lum {_lum(body):.0f}) sits deep"
    v, e = tg.c("sky-0"), tg.c("crystal-0")
    assert v[2] > v[0] and e[0] > e[1], "blue for Vorrhallow, wine for the Evercrown"


def test_the_core_glow_is_a_fine_dither_not_blocks():
    # Design bible 12.48: the glow at the foot of the Evercrown's far wall was
    # random 4 px blocks, a band of checker noise behind the floor. It is an ordered
    # dither one world pixel fine that thickens downward to CORE_GLOW.
    far = tg.evercrown_far()
    px = far.load()
    glow = tg.c("crystal-2")
    def share(y0, y1):
        n = sum(1 for y in range(y0, y1) for x in range(0, tg.BG_W) if px[x, y] == glow)
        return n / ((y1 - y0) * tg.BG_W)
    top, foot = int(tg.BG_H * 0.8), tg.BG_H
    upper, lower = share(top, top + 8 * tg.D), share(foot - 8 * tg.D, foot)
    assert upper < 0.15 < lower <= tg.CORE_GLOW + 0.1, f"the glow thickens downward ({upper:.2f} to {lower:.2f})"
    # No lit run longer than two world pixels along the foot row: a dither, not blocks.
    y, run, longest = foot - tg.D, 0, 0
    for x in range(tg.BG_W):
        run = run + 1 if px[x, y] == glow else 0
        longest = max(longest, run)
    assert longest <= 2 * tg.D, f"the foot row has a lit run {longest} px long"


if __name__ == "__main__":
    main()
