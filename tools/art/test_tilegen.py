#!/usr/bin/env python3
"""Guards for the backdrop gradient (bible 12.6), the moss cap (bible 12.7) and
the tileset variant row (bible 12.8).

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


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        t()
        print(f"ok  {t.__name__}")
    print(f"\n{len(tests)} checks passed")


if __name__ == "__main__":
    main()
