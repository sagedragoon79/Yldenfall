#!/usr/bin/env python3
"""Packs the Haar Wyrm's rig parts into sheets for `WyrmRig` (the rig prototype).

Usage: python3 tools/art/wyrm_rig_pack.py [--sheet OUT.png]

Reads Sean's PixelLab art as it was downloaded:
  art/pixellab/bosses/haar_wyrm/head   the head (92 px canvas), its states and clips
  art/pixellab/bosses/haar_wyrm/body   the body (256x128 canvas), its states and clips
  art/pixellab/hydra_neck              the eight tapering neck sections, side and front
and writes assets/bosses/haar_wyrm/: one sheet per part and rig.json, which names every
clip (first cell, frame count, frames a second) and every joint (in art pixels).

Nothing is redrawn or resized. PixelLab gives each clip its own canvas size, so each clip
is slid to where its first frame best covers the still it grew from, and every cell of a
sheet then shares one origin. `--sheet` also writes a contact sheet to look at.
"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'art', 'pixellab', 'bosses', 'haar_wyrm')
NECK = os.path.join(ROOT, 'art', 'pixellab', 'hydra_neck')
OUT = os.path.join(ROOT, 'assets', 'bosses', 'haar_wyrm')
COLUMNS = 8

# part -> (cell size, [clip, folder under SRC, every Nth frame, frames a second, still it aligns to]).
# A folder of `rotations` gives one still; a clip folder gives its frames in order.
HEAD = 'head/Idle/animations/'
BODY = 'body/Idle/animations/'
PARTS = {
    'head_east': ((176, 192), [
        ('idle', 'head/Idle/rotations/east.png', 1, 1, None),
        ('open', 'head/Mouth_wide_open_as_i/rotations/east.png', 1, 1, 'idle'),
        ('pull', HEAD + 'Pull_the_head_back_with_a_sharp_controlled_tension/east', 2, 10, 'idle'),
        ('roar', HEAD + 'The_dragon_head_let_s_out_a_silent_roar_in_the_dir/east', 1, 10, 'idle'),
        ('jaw', HEAD + 'The_jaw_drops_open_with_a_quick_snapping_motion_as/east', 2, 10, 'idle'),
        # In the tunnel's dark, before the fight: eyes shut, then open.
        ('shut', 'head/Eyes_closed/rotations/east.png', 1, 1, 'idle'),
        ('shadow', 'head/Shadowed/rotations/east.png', 1, 1, 'idle'),
    ]),
    'head_south': ((128, 192), [
        ('idle', 'head/Idle/rotations/south.png', 1, 1, None),
        ('open', 'head/Mouth_wide_open_as_i/rotations/south.png', 1, 1, 'idle'),
        ('glow', HEAD + 'Open_the_jaw_wide_to_reveal_a_glowing_yellow_core/south', 2, 10, 'idle'),
        ('roar', HEAD + 'The_dragon_head_let_s_out_a_silent_roar_in_the_dir/south', 1, 10, 'idle'),
        ('shut', 'head/Eyes_closed/rotations/south.png', 1, 1, 'idle'),
        ('shadow', 'head/Shadowed/rotations/south.png', 1, 1, 'idle'),
        # Its eyes open and it snorts; then the shadow draws off it as it comes out.
        ('wake', 'head/Eyes_closed/animations/Eyes_open_and_the_dragon_snorts_a_small_burst_of_s/south', 1, 10, 'shut'),
        ('recede', 'head/Shadowed/animations/Facing_south_the_entire_time_the_shadows_slowly_re/south', 1, 10, 'shadow'),
    ]),
    'body': ((256, 256), [
        ('idle', 'body/Idle/rotations/south.png', 1, 1, None),
        ('cloaked', 'body/Cloaked_in_shadow._C/rotations/south.png', 1, 1, 'idle'),
        ('slumped', 'body/slumped_to_floor_aft/rotations/south.png', 1, 1, 'idle'),
        ('shift', BODY + 'Shift_the_weight_forward_onto_the_front_limbs_whil/south', 1, 8, 'idle'),
        ('flail', BODY + 'The_claws_flail_erratically_as_the_heavy_tail_whip/south', 1, 10, 'idle'),
        ('rise', 'body/Cloaked_in_shadow._C/animations/Shift_weight_forward_while_lifting_the_heavy_torso/south', 1, 8, 'cloaked'),
    ]),
}

# Joints, in the art pixels of each part's still (x right, y down, from the still's top left).
JOINTS = {
    # Where the neck meets the skull, and where a breath leaves the jaws.
    'head_east': {'neck': (30, 68), 'mouth': (84, 66), 'eyes': [(62, 47)], 'size': (92, 92)},
    'head_south': {'neck': (46, 62), 'mouth': (46, 80), 'eyes': [(35, 52), (59, 52)], 'size': (92, 92)},
    # The three stumps on its shoulders (west, middle, east) and where it meets the ground.
    'body': {'stumps': [(85, 21), (127, 11), (168, 21)], 'ground': (128, 124), 'size': (256, 128)},
}


def frames_of(folder):
    path = os.path.join(SRC, folder)
    if path.endswith('.png'):
        return [Image.open(path).convert('RGBA')]
    return [Image.open(f).convert('RGBA') for f in sorted(glob.glob(os.path.join(path, '*.png')))]


def paste_centered(cell, im, shift=(0, 0)):
    out = Image.new('RGBA', cell, (0, 0, 0, 0))
    out.alpha_composite(im, ((cell[0] - im.width) // 2 + shift[0], (cell[1] - im.height) // 2 + shift[1]))
    return out


def best_shift(cell, still, im, reach=40):
    """How far to slide `im` so its silhouette best covers `still`'s (both centred in a cell)."""
    a = still.getchannel('A').point(lambda v: 255 if v > 40 else 0)
    b0 = paste_centered(cell, im).getchannel('A').point(lambda v: 255 if v > 40 else 0)
    best = (-1, (0, 0))
    # Coarse, then fine: a silhouette's overlap is smooth enough for it.
    for step, span, around in ((4, reach, (0, 0)), (1, 4, None)):
        cx, cy = around if around is not None else best[1]
        for dy in range(cy - span, cy + span + 1, step):
            for dx in range(cx - span, cx + span + 1, step):
                b = ImageChops.offset(b0, dx, dy)
                score = sum(ImageChops.multiply(a, b).histogram()[255:])
                if score > best[0]:
                    best = (score, (dx, dy))
    return best[1]


def pack_part(name, cell, clips):
    cells = []
    meta = {}
    stills = {}
    for clip, folder, every, fps, align in clips:
        ims = frames_of(folder)[::every]
        if not ims:
            sys.exit('no frames: ' + folder)
        shift = (0, 0)
        if align is not None:
            shift = best_shift(cell, stills[align], ims[0])
        if len(ims) == 1:
            stills[clip] = paste_centered(cell, ims[0], shift)
        meta[clip] = {'start': len(cells), 'count': len(ims), 'fps': fps}
        for im in ims:
            if im.width > cell[0] or im.height > cell[1]:
                sys.exit('%s/%s: a %dx%d frame is larger than the %dx%d cell' % (name, clip, im.width, im.height, cell[0], cell[1]))
            cells.append(paste_centered(cell, im, shift))
    rows = (len(cells) + COLUMNS - 1) // COLUMNS
    sheet = Image.new('RGBA', (cell[0] * COLUMNS, cell[1] * rows), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((i % COLUMNS) * cell[0], (i // COLUMNS) * cell[1]))
    sheet.save(os.path.join(OUT, name + '.png'))
    j = dict(JOINTS[name])
    size = j.pop('size')
    # Joints are measured on the still; the cell centres it.
    off = ((cell[0] - size[0]) // 2, (cell[1] - size[1]) // 2)

    def moved(p):
        return [p[0] + off[0], p[1] + off[1]]
    joints = {k: ([moved(p) for p in v] if isinstance(v, list) else moved(v)) for k, v in j.items()}
    return {'sheet': name + '.png', 'cell': list(cell), 'columns': COLUMNS, 'clips': meta, 'joints': joints}, cells


def row_centre(im, y0, y1):
    """The middle of the opaque pixels in rows y0..y1."""
    a = im.getchannel('A')
    xs = [x for y in range(y0, y1) for x in range(im.width) if a.getpixel((x, y)) > 40]
    return (min(xs) + max(xs) + 1) / 2.0 if xs else im.width / 2.0


def pack_neck(view):
    ims = [Image.open(os.path.join(NECK, 'neck_%s_%d.png' % (view, i))).convert('RGBA') for i in range(1, 9)]
    cell = (max(i.width for i in ims), max(i.height for i in ims))
    sheet = Image.new('RGBA', (cell[0] * len(ims), cell[1]), (0, 0, 0, 0))
    sections = []
    for i, im in enumerate(ims):
        bb = im.getbbox()
        # Each section stands on the cell's floor, centred.
        at = ((cell[0] - im.width) // 2, cell[1] - bb[3])
        sheet.alpha_composite(im, (i * cell[0] + at[0], at[1]))
        # Its foot (where it sits in the section below) and its rim (where the next one sits).
        foot = [at[0] + row_centre(im, bb[3] - 4, bb[3]), float(cell[1])]
        rim = [at[0] + row_centre(im, bb[1], bb[1] + 4), float(at[1] + bb[1])]
        sections.append({'foot': foot, 'rim': rim, 'width': bb[2] - bb[0], 'height': bb[3] - bb[1]})
    sheet.save(os.path.join(OUT, 'neck_%s.png' % view))
    return {'sheet': 'neck_%s.png' % view, 'cell': list(cell), 'sections': sections}, ims


def main():
    os.makedirs(OUT, exist_ok=True)
    rig = {'about': 'Packed by tools/art/wyrm_rig_pack.py from art/pixellab. Do not edit by hand.'}
    looks = []
    for name, (cell, clips) in PARTS.items():
        rig[name], cells = pack_part(name, cell, clips)
        looks.append((name, cells))
        print('%s: %d cells of %dx%d' % (name, len(cells), cell[0], cell[1]))
    for view in ('side', 'front'):
        rig['neck_' + view], _ = pack_neck(view)
    with open(os.path.join(OUT, 'rig.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(rig, f, indent=1)
        f.write('\n')
    sheet_to = next((sys.argv[i + 1] for i, a in enumerate(sys.argv[:-1]) if a == '--sheet'), None)
    if sheet_to:
        # Every clip's first, middle and last cells over its still, to check the alignment.
        rows = []
        for name, cells in looks:
            still = cells[0]
            for clip, c in rig[name]['clips'].items():
                picks = sorted({c['start'], c['start'] + c['count'] // 2, c['start'] + c['count'] - 1})
                row = Image.new('RGBA', (still.width * len(picks), still.height), (58, 62, 70, 255))
                for k, p in enumerate(picks):
                    ghost = still.copy()
                    ghost.putalpha(ghost.getchannel('A').point(lambda v: v // 3))
                    row.alpha_composite(ghost, (k * still.width, 0))
                    row.alpha_composite(cells[p], (k * still.width, 0))
                rows.append(row)
        w = max(r.width for r in rows)
        out = Image.new('RGBA', (w, sum(r.height for r in rows)), (58, 62, 70, 255))
        y = 0
        for r in rows:
            out.paste(r, (0, y))
            y += r.height
        out.save(sheet_to)
        print('contact sheet:', sheet_to)


if __name__ == '__main__':
    main()
