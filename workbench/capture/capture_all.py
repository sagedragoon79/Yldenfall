#!/usr/bin/env python3
"""Captures every picture the workbench catalogue uses, from the running game.

Usage: python3 workbench/capture/capture_all.py [--only=rooms,people,...] [--redo] [--jobs=3]
  Needs GODOT set to a Godot 4.7.2 binary (the console build on Windows).
  Pictures land in workbench/catalog/<section>/<id>.(png|jpg). Existing pictures
  are kept unless --redo, so a rerun only fills what is missing.

Kinds: things (foes, guardians and pickups drawn alone), rooms, people (each
townsperson in their room), gear (the hero wearing each piece), dyes, arenas
(guardians made of several parts, shot in their rooms), shops (the shop menu) and
fights (the game being played: a real swing landing on a foe, and a foe's tell).
"""
import concurrent.futures as cf, glob, json, os, re, shutil, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CAT = os.path.join(ROOT, 'workbench', 'catalog')
GODOT = os.environ.get('GODOT', 'godot')
ARGS = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '') for a in sys.argv[1:] if a.startswith('--'))
ONLY = set(filter(None, ARGS.get('only', '').split(',')))
REDO = 'redo' in ARGS
JOBS = int(ARGS.get('jobs', '3'))
fwd = lambda p: p.replace('\\', '/')


def rooms():
    """Room id -> header dict (name, zone, npcs, boss, map)."""
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'levels', '*', '*.room'))):
        rid = fwd(os.path.relpath(path, os.path.join(ROOT, 'levels')))[:-5]
        head, _, grid = open(path, encoding='utf-8').read().partition('\n---\n')
        h = {'npcs': [], 'boss': '', 'grid': grid.rstrip('\n').split('\n')}
        for line in head.splitlines():
            k, _, v = line.partition(':')
            v = v.strip()
            if k == 'npc':
                parts = [p.strip() for p in v.split(',')]
                h['npcs'].append({'x': int(parts[0]), 'y': int(parts[1]), 'id': parts[2], 'cond': parts[3] if len(parts) > 3 else ''})
            elif k in ('name', 'zone', 'boss', 'map'):
                h[k] = v
        out[rid] = h
    return out


def godot(scene, extra, timeout=120):
    # The window opens far off-screen, so captures never pop up over the desktop
    # (an off-screen window still renders).
    cmd = [GODOT, '--path', ROOT, '--position', '-8000,-8000', '--fixed-fps', '60', scene, '--'] + extra
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 'timeout', ''
    return r.returncode, (r.stderr or '')[-400:]


def shot(out, game_args, **kw):
    """Runs workbench/capture/shot.tscn into a temporary PNG, then saves it to `out`."""
    tmp = os.path.join(tempfile.gettempdir(), 'wb_%d_%s.png' % (os.getpid(), re.sub(r'\W', '_', out)[-60:]))
    extra = ['--out=' + fwd(tmp), '--invulnerable'] + ['--%s=%s' % (k, v) if v != '' else '--' + k for k, v in kw.items()] + game_args
    code, err = godot('res://workbench/capture/shot.tscn', extra)
    if code != 0 or not os.path.exists(tmp):
        return 'FAIL %s (%s)' % (os.path.relpath(out, CAT), err.strip().splitlines()[-1] if err.strip() else code)
    save(tmp, out)
    os.remove(tmp)
    return 'ok   ' + os.path.relpath(out, CAT)


def save(src, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if out.endswith('.jpg'):
        from PIL import Image
        im = Image.open(src).convert('RGB')
        im.thumbnail((960, 960), Image.LANCZOS)
        im.save(out, quality=86)
    else:
        shutil.copyfile(src, out)


def floor_mid(grid):
    """A standing tile near the middle of a room: an empty cell with ground under it."""
    w = max(len(r) for r in grid)
    for dx in range(0, w // 2):
        for x in (w // 2 + dx, w // 2 - dx):
            for y in range(len(grid) - 2, 0, -1):
                row, below = grid[y].ljust(w), grid[y + 1].ljust(w)
                if row[x] == '.' and below[x] in '#-' and grid[y - 1].ljust(w)[x] == '.':
                    return x, y
    return w // 2, len(grid) // 2


# Fight frames: (picture id, room, foe's legend character, moment). The hero is put
# beside the first such foe that has floor to stand on; see fight_spot.
FIGHTS = [
    ('heartwood-hit', 'heartwood/entrance', 'M', 'hit'),
    ('heartwood-tell', 'heartwood/dwarf_hall', 'D', 'tell'),
    ('boughs-hit', 'boughs/thicket_road', '!', 'hit'),
    ('haar-hit', 'haar/marsh_road', 'V', 'hit'),
    ('haar-tell', 'haar/marsh_road', 'p', 'tell'),
    ('spires-hit', 'spires/fallen_bridge', 't', 'hit'),
    ('vorrhallow-hit', 'vorrhallow/kings_kennels', 'j', 'hit'),
    ('vorrhallow-tell', 'vorrhallow/flooded_hall', 'q', 'tell'),
    ('tower-hit', 'tower/smelter', 'I', 'hit'),
    ('evercrown-hit', 'evercrown/threshold', 'D', 'hit'),
]


def fight_spot(grid, foe, gap=2):
    """The tile to stand the hero on to fight the first `foe` in a room: `gap` tiles to
    one side of it on the same floor, facing it. Returns (x, y, side) with side 1 when
    the foe is to the hero's right, or None when no such foe has room beside it."""
    w = max(len(r) for r in grid)
    g = [r.ljust(w) for r in grid]
    for y in range(1, len(g) - 1):
        for x in range(w):
            if g[y][x] != foe or g[y + 1][x] != '#':
                continue
            for side in (1, -1):
                xs = [x - side * d for d in range(1, gap + 2)]
                if all(0 < c < w - 1 and g[y][c] == '.' and g[y + 1][c] == '#' and g[y - 1][c] == '.' for c in xs):
                    return x - side * gap, y, side
    return None


def jobs():
    R = rooms()
    items = json.load(open(os.path.join(ROOT, 'data', 'items.json'), encoding='utf-8'))
    shops = json.load(open(os.path.join(ROOT, 'data', 'shops.json'), encoding='utf-8'))
    J = []   # (kind, out, callable)
    add = lambda kind, out, fn: J.append((kind, os.path.join(CAT, out), fn))
    for rid, h in R.items():
        add('rooms', 'rooms/%s.jpg' % rid.replace('/', '__'), lambda o, rid=rid: shot(o, ['--room=' + rid], frames=50))
    seen = set()
    for rid, h in R.items():
        for n in h['npcs']:
            if n['id'] in seen:
                continue
            seen.add(n['id'])
            flags = ','.join(c for c in n['cond'].split() if not c.startswith('!'))
            # Stand the hero five tiles off to one side, away from a door at the room's edge.
            w = max(len(r) for r in h['grid'])
            hx = n['x'] + 5 if n['x'] + 5 < w - 3 else n['x'] - 5
            g = ['--room=' + rid, '--shot-at=%d,%d' % (hx, n['y'])] + (['--flags=' + flags] if flags else [])
            add('people', 'people/%s.png' % n['id'], lambda o, g=g, i=n['id']: shot(o, g, hero='72,72', scale=2, focus='npc:' + i, frames=50))
    for iid, it in items.items():
        k = it['kind']
        if k == 'blade':
            add('gear', 'gear/%s.png' % iid, lambda o, i=iid: shot(o, ['--room=hearthroot/plaza', '--wear=' + i, '--shot-pose=slash1:1'], hero='80,64', scale=2))
        elif k == 'shield':
            add('gear', 'gear/%s.png' % iid, lambda o, i=iid: shot(o, ['--room=hearthroot/plaza', '--wear=' + i, '--shot-pose=block:0'], hero='80,64', scale=2))
        elif k in ('armor', 'helmet'):
            add('gear', 'gear/%s.png' % iid, lambda o, i=iid: shot(o, ['--room=hearthroot/plaza', '--wear=' + i], hero='80,64', scale=2))
        elif k == 'dye':
            add('dyes', 'dyes/%s.png' % iid, lambda o, i=iid: shot(o, ['--room=hearthroot/plaza', '--dye=' + i], hero='64,64', scale=2))
    for rid, h in R.items():
        if h['boss'] in ('gnarlmaw', 'haar_wyrm', 'everbloom_veins'):
            g = ['--room=' + rid, '--shot-at=%d,%d' % floor_mid(h['grid'])]
            if h['boss'] == 'gnarlmaw':
                # Gnarlmaw spends most of the fight in the walls; at frame 330 its whole body lunges across the floor.
                add('arenas', 'guardians/gnarlmaw.png', lambda o, g=g: shot(o, g, frames=330))
            else:
                add('arenas', 'guardians/%s.png' % h['boss'], lambda o, g=g: shot(o, g, hero='400,240', focus='boss', frames=240))
    for fid, rid, foe, when in FIGHTS:
        # A tell is shot from four tiles off, so the foe is not already touching the hero.
        spot = fight_spot(R[rid]['grid'], foe, 2 if when == 'hit' else 4) if rid in R else None
        if spot is None:
            add('fights', 'fights/%s.png' % fid, lambda o, rid=rid, foe=foe: 'FAIL %s (no %s with floor beside it in %s)' % (os.path.relpath(o, CAT), foe, rid))
            continue
        g = ['--room=' + rid, '--shot-at=%d,%d' % spot[:2]] + (['--face-left'] if spot[2] < 0 else [])
        if when == 'hit':
            # A real swing: the smear, the spark and the foe's flash share the frame.
            add('fights', 'fights/%s.png' % fid, lambda o, g=g: shot(o, g + ['--shot-attack=24'], when='hit', after=2, frames=600))
        else:
            # The hero only stands there, so the frame is the foe's wind-up and nothing else.
            add('fights', 'fights/%s.png' % fid, lambda o, g=g: shot(o, g, when='tell', after=4, frames=600))
    keeper = {}
    for rid, h in R.items():
        for n in h['npcs']:
            keeper.setdefault(n['id'], (rid, n))
    npcs = json.load(open(os.path.join(ROOT, 'data', 'npcs.json'), encoding='utf-8'))
    for sid in shops:
        who = next((nid for nid, v in npcs.items() if v.get('shop') == sid and nid in keeper), None)
        if who is None:
            continue
        rid, n = keeper[who]
        flags = ','.join(c for c in n['cond'].split() if not c.startswith('!'))
        g = ['--room=' + rid, '--shot-at=%d,%d' % (n['x'] + 2, n['y']), '--open=shop:' + sid, '--gold=5000'] + (['--flags=' + flags] if flags else [])
        add('shops', 'shops/%s.jpg' % sid, lambda o, g=g: shot(o, g, ui='', frames=50))
    return J


def main():
    if 'things' in ONLY or not ONLY:
        if REDO or not glob.glob(os.path.join(CAT, 'foes', '*.png')):
            t0 = time.time()
            code, err = godot('res://workbench/capture/things.tscn', ['--out=' + fwd(os.path.join(CAT, '_things'))], timeout=300)
            for sub in ('foes', 'pickups'):
                src = os.path.join(CAT, '_things', sub)
                for f in glob.glob(os.path.join(src, '*.png')):
                    os.makedirs(os.path.join(CAT, sub), exist_ok=True)
                    shutil.move(f, os.path.join(CAT, sub, os.path.basename(f)))
            shutil.rmtree(os.path.join(CAT, '_things'), ignore_errors=True)
            print('things: exit %s in %.0fs' % (code, time.time() - t0), flush=True)
    todo = [(k, o, fn) for k, o, fn in jobs() if (not ONLY or k in ONLY) and (REDO or not os.path.exists(o))]
    print('%d pictures to capture with %d at a time' % (len(todo), JOBS), flush=True)
    t0 = time.time()
    with cf.ThreadPoolExecutor(JOBS) as pool:
        for i, msg in enumerate(pool.map(lambda j: j[2](j[1]), todo), 1):
            print('[%d/%d %.0fs] %s' % (i, len(todo), time.time() - t0, msg), flush=True)


if __name__ == '__main__':
    main()
