#!/usr/bin/env python3
"""Writes workbench/catalog/catalog.json from the game's own data, rooms and scripts.

Usage: python3 workbench/capture/build_catalog.py
  Run capture_all.py first for the pictures; a row whose picture is missing has none.
  Sources: data/*.json, levels/**/*.room, levels/README.md (the legend), and the
  foe, guardian, pickup and spell scripts. Row ids are the game's own ids, so notes
  stay attached across reruns.
"""
import glob, json, os, re, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CAT = os.path.join(ROOT, 'workbench', 'catalog')
sys.path.insert(0, HERE)
rd = lambda *p: open(os.path.join(ROOT, *p), encoding='utf-8').read()
data = lambda name: json.loads(rd('data', name + '.json'))


def img(rel):
    return rel if os.path.exists(os.path.join(CAT, rel)) else None


def clean(row):
    """Drops empty keys, so the page shows nothing rather than a blank."""
    return {k: v for k, v in row.items() if v not in (None, '', [], {})}


def title(s):
    return ' '.join(w.capitalize() for w in s.replace('_', ' ').split())


# --- The world -------------------------------------------------------------------
ZONES = {m.group(1): m.group(2) for m in re.finditer(r'"(\w+)": \{"name": "([^"]+)"', rd('scripts', 'world', 'world.gd').split('const ZONES', 1)[1].split('\n}', 1)[0])}
ZONE_ORDER = ['hearthroot', 'heartwood', 'tower', 'haar', 'boughs', 'spires', 'vorrhallow', 'sunken', 'evercrown', 'trials', 'gym']
LEGEND = {}
for m in re.finditer(r'^\| `(.+?)`(?: `(.+?)`)? \| (.+?) \|?$', rd('levels', 'README.md'), re.M):
    LEGEND[m.group(1).replace('\\|', '|')] = m.group(3)


def rooms():
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'levels', '*', '*.room'))):
        rid = os.path.relpath(path, os.path.join(ROOT, 'levels')).replace('\\', '/')[:-5]
        head, _, grid = open(path, encoding='utf-8').read().partition('\n---\n')
        h = {'id': rid, 'npcs': [], 'signs': [], 'doors': 0, 'secrets': 0, 'chests': 0, 'grid': grid.rstrip('\n').split('\n')}
        for line in head.splitlines():
            k, _, v = line.partition(':')
            v = v.strip()
            if k == 'npc':
                h['npcs'].append([p.strip() for p in v.split(',')][2])
            elif k == 'sign':
                h['signs'].append(v.split(',', 2)[-1].strip())
            elif k == 'door':
                h['doors'] += 1
            elif k == 'secret':
                h['secrets'] += 1
            elif k in ('chest', 'chest_gold'):
                h['chests'] += 1
            elif k in ('name', 'zone', 'boss', 'music', 'ambience'):
                h[k] = v
        g = h['grid']
        h['w'], h['h'] = max(len(r) for r in g), len(g)
        h['cells'] = ''.join(g)
        out[rid] = h
    return out


R = rooms()

# Foe legend characters -> script ids, read from room.gd's spawner.
CLASS_FILE = {}
for f in glob.glob(os.path.join(ROOT, 'scripts', 'enemies', '*.gd')) + glob.glob(os.path.join(ROOT, 'scripts', 'bosses', '*.gd')):
    m = re.search(r'^class_name (\w+)', open(f, encoding='utf-8').read(), re.M)
    if m:
        CLASS_FILE[m.group(1)] = os.path.basename(f)[:-3]
CHAR_FOE = {}
for m in re.finditer(r'\t\t"(.)":\n(?:\t\t\t.*\n){0,3}?\t\t\t_spawn_enemy\((\w+)\.new', rd('scripts', 'world', 'room.gd')):
    CHAR_FOE[m.group(1)] = CLASS_FILE.get(m.group(2), m.group(2))


def script(kind, fid):
    path = os.path.join(ROOT, 'scripts', kind, fid + '.gd')
    return open(path, encoding='utf-8').read() if os.path.exists(path) else ''


def num(src, name):
    m = re.search(r'^\s*(?:const )?%s\s*(?::=|=)\s*(-?\d+(?:\.\d+)?)' % name, src, re.M)
    return float(m.group(1)) if m and '.' in m.group(1) else int(m.group(1)) if m else None


def doc(src, n=2):
    """The first sentences of a script's ## doc comment."""
    lines = []
    for line in src.splitlines()[1:12]:
        if line.startswith('##'):
            lines.append(line[2:].strip())
        elif lines:
            break
    text = ' '.join(lines)
    return ' '.join(re.split(r'(?<=[.!?])\s+', text)[:n]).strip()


sections = []

# Zones
zone_rows = []
for z in ZONE_ORDER:
    rs = [h for h in R.values() if h.get('zone') == z]
    if not rs:
        continue
    town = max(rs, key=lambda h: (len(h['npcs']), -len(h['id'])))
    pic = town if town['npcs'] else rs[0]
    bosses = sorted({h['boss'] for h in rs if h.get('boss')})
    foes = sorted({CHAR_FOE[c] for h in rs for c in set(h['cells']) if c in CHAR_FOE})
    zone_rows.append(clean({
        'id': z, 'name': ZONES.get(z, title(z)), 'sub': '%d rooms' % len(rs),
        'img': img('rooms/%s.jpg' % pic['id'].replace('/', '__')),
        'text': 'Pictured: %s.' % pic.get('name', pic['id']),
        'tags': [title(b) for b in bosses],
        'list': [{'name': h.get('name', h['id']), 'text': '%d x %d tiles' % (h['w'], h['h'])} for h in rs],
        'fields': {'Rooms': len(rs), 'People': sum(len(h['npcs']) for h in rs), 'Foe kinds': len(foes),
                   'Guardians': len(bosses), 'Secrets': sum(h['secrets'] for h in rs), 'Chests': sum(h['chests'] for h in rs)},
    }))
sections.append({'id': 'zones', 'group': 'World', 'label': 'Zones', 'title': 'Zones of the Tree',
                 'lede': 'Each region of the climb, from the roots to the crown, in story order. The picture is the zone\'s town, or its first room.',
                 'layout': 'wide', 'keepOrder': True, 'rows': zone_rows})

room_rows = []
for z in ZONE_ORDER:
    for h in sorted((h for h in R.values() if h.get('zone') == z), key=lambda h: h['id']):
        foes = sorted({CHAR_FOE[c] for c in set(h['cells']) if c in CHAR_FOE})
        room_rows.append(clean({
            'id': h['id'].replace('/', '__'), 'name': h.get('name', title(h['id'].split('/')[1])), 'sub': ZONES.get(z, z),
            'img': img('rooms/%s.jpg' % h['id'].replace('/', '__')),
            # A sign's text may open with [flag] conditions; show the first plain one, else strip them.
            'text': next((t for t in h['signs'] if not t.startswith('[')), re.sub(r'^\[[^\]]*\]\s*', '', h['signs'][0]) if h['signs'] else ''),
            'tags': [title(f) for f in foes] + (['Guardian: ' + title(h['boss'])] if h.get('boss') else []),
            'fields': {'Zone': ZONES.get(z, z), 'Id': h['id'], 'Width': h['w'], 'Height': h['h'], 'Doors': h['doors'],
                       'People': len(h['npcs']), 'Foes': sum(h['cells'].count(c) for c in CHAR_FOE), 'Secrets': h['secrets'],
                       'Chests': h['chests'], 'Signs': len(h['signs']), 'Music': h.get('music', '')},
        }))
sections.append({'id': 'rooms', 'group': 'World', 'label': 'Rooms', 'title': 'Every room',
                 'lede': 'All %d rooms, each shot where the hero enters it, with the interface hidden.' % len(room_rows),
                 'layout': 'wide', 'filter': 'Zone', 'rows': room_rows})

# --- Fights: the game being played (capture_all.py, FIGHTS) ---------------------------
import capture_all as CAP
fight_rows = []
for fid, rid, foe, when in CAP.FIGHTS:
    h = R.get(rid)
    if h is None:
        continue
    who = title(CHAR_FOE.get(foe, foe))
    fight_rows.append(clean({
        'id': fid, 'name': '%s: %s' % (h.get('name', rid), 'a blow lands' if when == 'hit' else 'a tell'), 'sub': ZONES.get(h.get('zone'), ''),
        'img': img('fights/%s.png' % fid),
        'text': ("A real swing on the %s: the smear, the hit spark and the foe's flash in one frame." % who) if when == 'hit'
                else ('The %s winds up an attack; the hero only stands there.' % who),
        'tags': [who, 'Hit' if when == 'hit' else 'Tell'],
        'fields': {'Zone': ZONES.get(h.get('zone'), ''), 'Room': rid, 'Foe': who, 'Moment': when},
    }))
sections.append({'id': 'fights', 'group': 'World', 'label': 'Fights', 'title': 'Fight frames',
                 'lede': 'The game being played, at the size the player sees it: nothing here is staged. The hero is put beside a foe and swings (or stands), and the capture waits for the moment itself.',
                 'layout': 'wide', 'filter': 'Zone', 'rows': fight_rows})

# --- People ------------------------------------------------------------------------
NPCS = data('npcs')
SHOPS = data('shops')
where = {}
for h in R.values():
    for n in h['npcs']:
        where.setdefault(n, h)
ROLE = {'talk': 'Townsfolk', 'shop': 'Shopkeeper', 'king': 'Reeve', 'ringreader': 'Ringreader', 'physician': 'Physician'}
people = []
for nid, n in NPCS.items():
    h = where.get(nid)
    lines = n.get('lines') or n.get('lines_cleared') or []
    if isinstance(lines, str):
        lines = [lines]
    role = ROLE.get(n.get('role', 'talk'), title(n.get('role', '')))
    people.append(clean({
        'id': nid, 'name': n.get('name', title(nid)), 'sub': role + (' - ' + SHOPS[n['shop']]['name'] if n.get('shop') in SHOPS else ''),
        'img': img('people/%s.png' % nid),
        'quote': lines[0] if lines else SHOPS.get(n.get('shop'), {}).get('greeting', ''),
        'text': 'Shown after the world changes (a "%s" variant).' % nid.rsplit('_', 1)[-1] if nid.endswith('_glad') else '',
        'list': [{'name': 'Line %d' % (i + 1), 'text': l} for i, l in enumerate(lines[1:6], 2)],
        'fields': {'Role': role, 'Town': ZONES.get(h['zone'], '') if h else 'Not placed', 'Room': h.get('name', '') if h else ''},
    }))
sections.append({'id': 'people', 'group': 'People', 'label': 'People', 'title': 'People of the Tree',
                 'lede': 'Every townsperson in data/npcs.json, shot standing in their own room. Some appear only after a guardian falls or a spring flows; those are shot with that flag set.',
                 'layout': 'grid', 'filter': 'Role', 'rows': people})

# --- Foes and guardians ---------------------------------------------------------------
foe_rows, boss_rows = [], []
placed = {}
for h in R.values():
    for c in set(h['cells']):
        if c in CHAR_FOE:
            placed.setdefault(CHAR_FOE[c], []).append(h)
char_of = {v: k for k, v in CHAR_FOE.items()}
for f in sorted(glob.glob(os.path.join(ROOT, 'scripts', 'enemies', '*.gd'))):
    fid = os.path.basename(f)[:-3]
    src = open(f, encoding='utf-8').read()
    if fid == 'enemy' or 'extends Enemy' not in src:
        continue
    cname = re.search(r'^class_name (\w+)', src, re.M)
    name = re.sub(r'(?<!^)(?=[A-Z])', ' ', cname.group(1)) if cname else title(fid)
    hs = placed.get(fid, [])
    zones = sorted({ZONES.get(h['zone'], h['zone']) for h in hs})
    legend = LEGEND.get(char_of.get(fid, ''), '')
    foe_rows.append(clean({
        'id': fid, 'name': name, 'sub': ', '.join(zones) if zones else 'Summoned by a guardian',
        'img': img('foes/%s.png' % fid),
        'text': legend or doc(src),
        'tags': ['Room char ' + char_of[fid]] if fid in char_of else [],
        'list': [{'name': h.get('name', h['id']), 'text': ZONES.get(h['zone'], '')} for h in hs[:12]],
        'fields': {'Zone': zones[0] if len(zones) == 1 else ('Several' if zones else 'Summoned'), 'Health': num(src, 'max_hp'),
                   'XP': num(src, 'xp'), 'Gold min': num(src, 'gold_min'), 'Gold max': num(src, 'gold_max'), 'Rooms': len(hs)},
    }))
sections.append({'id': 'foes', 'group': 'Foes', 'label': 'Foes', 'title': 'Foes',
                 'lede': 'Every enemy, drawn alone by its own script in its idle pose. Descriptions come from the level legend.',
                 'layout': 'grid', 'filter': 'Zone', 'rows': foe_rows})

ARENA = re.findall(r'\["(\w+)", "([\w/]+)"\]', rd('scripts', 'data', 'boss_rush.gd').split('const ORDER', 1)[1].split(']\n', 1)[0] + ']')
arena_src = rd('scripts', 'bosses', 'boss_arena.gd')
boss_room = {h['boss']: h for h in R.values() if h.get('boss')}
order = [b for b, _ in ARENA] + sorted(b for b in boss_room if b not in dict(ARENA))
for bid in order:
    fid = {'everbloom': 'everbloom_heart', 'everbloom_veins': 'everbloom_core'}.get(bid, bid)
    src = script('bosses', fid)
    name = re.search(r'DISPLAY_NAME := "([^"]+)"', src)
    epithet = re.search(r'EPITHET := "([^"]+)"', src)
    reward = re.search(r'"%s": \{([^}]*)\}' % bid, arena_src)
    rw = ''
    if reward:
        r = reward.group(1)
        m = re.search(r'"(?:ring_name|title)": "([^"]+)"', r)
        rw = m.group(1) if m else ''
    phases = re.search(r'const PHASES := \[([^\]]*)\]', src)
    h = boss_room.get(bid)
    pic = img('guardians/%s.png' % bid) or img('foes/%s.png' % fid)
    boss_rows.append(clean({
        'id': bid, 'name': (name.group(1) if name else title(bid)) + (' (veins)' if bid == 'everbloom_veins' else ' (heart)' if bid == 'everbloom' else ' (avatar)' if bid == 'everbloom_avatar' else ''),
        'sub': epithet.group(1) if epithet else '', 'img': pic, 'r': 3,
        'text': doc(src, 3),
        'tags': ['Reward: ' + rw] if rw else [],
        'fields': {'Zone': ZONES.get(h['zone'], '') if h else '', 'Arena': h.get('name', '') if h else '',
                   'Health': num(src, 'MAX_HP') or num(src, 'max_hp'), 'Phases': (len([p for p in phases.group(1).split(',') if p.strip()]) + 1) if phases else None,
                   'XP': num(src, 'xp'), 'Gold min': num(src, 'gold_min'), 'Gold max': num(src, 'gold_max')},
    }))
sections.append({'id': 'guardians', 'group': 'Foes', 'label': 'Guardians', 'title': 'Guardians',
                 'lede': 'The bosses, in the order the boss rush meets them. Gnarlmaw, the Haar Wyrm and the Everbloom\'s veins are shot in their arenas mid-fight; the rest are drawn alone.',
                 'layout': 'grid', 'keepOrder': True, 'rows': boss_rows})

# --- Items -------------------------------------------------------------------------------
ITEMS = data('items')
price = {}
for sid, s in SHOPS.items():
    for st in s.get('stock', []):
        price.setdefault(st['item'], []).append((st.get('price', 0), s['name'], st.get('requires', '')))
KIND = {'blade': 'Blade', 'armor': 'Armor', 'shield': 'Shield', 'helmet': 'Helmet'}
gear, dyes, goods = [], [], []
for iid, it in ITEMS.items():
    p = sorted(price.get(iid, []))
    sold = {'Price': p[0][0] if p else None, 'Sold at': ', '.join(sorted({x[1] for x in p})) if p else 'Found, not sold'}
    tier = it.get('tier')
    if it['kind'] in KIND:
        f = {'Kind': KIND[it['kind']], 'Tier': tier, 'Slash': it.get('slash'), 'Heavy': it.get('heavy'), 'Reach': it.get('reach'),
             'Defense %': round(it['defense'] * 100) if it.get('defense') else None, 'Guard %': round(it['guard'] * 100) if it.get('guard') else None,
             'Ward %': round(it['ward'] * 100) if it.get('ward') else None, 'Health': it.get('hp')}
        f.update(sold)
        gear.append(clean({'id': iid, 'name': it['name'], 'sub': KIND[it['kind']] + (' - tier %d' % tier if tier else ''),
                           'img': img('gear/%s.png' % iid), 'r': max(0, min(3, (tier or 1) - 1)), 'text': it.get('desc', ''),
                           'tags': ['Two-handed'] if it.get('two_handed') else [], 'fields': {k: v for k, v in f.items() if v is not None}}))
    elif it['kind'] == 'dye':
        dyes.append(clean({'id': iid, 'name': it['name'], 'img': img('dyes/%s.png' % iid), 'text': it.get('desc', ''),
                           'fields': {k: v for k, v in sold.items() if v is not None}}))
    else:
        kind = {'stat': 'Upgrade', 'ointment': 'Supply', 'elixir': 'Supply', 'temper': 'Smithing', 'chart': 'Chart', 'spell': 'Spell scroll', 'key': 'Key'}.get(it['kind'], title(it['kind']))
        f = {'Kind': kind}
        f.update(sold)
        goods.append(clean({'id': iid, 'name': it['name'], 'sub': kind, 'text': it.get('desc', ''),
                            'tags': ['Needs ' + x[2] for x in p if x[2]][:1], 'fields': {k: v for k, v in f.items() if v is not None}}))
sections.append({'id': 'gear', 'group': 'Items', 'label': 'Gear', 'title': 'Blades, armor and shields',
                 'lede': 'The hero wearing each piece: blades mid-swing, shields raised, armor and helm at rest.',
                 'layout': 'grid', 'filter': 'Kind', 'rows': gear})
sections.append({'id': 'dyes', 'group': 'Items', 'label': 'Cloak dyes', 'title': 'Cloak dyes',
                 'lede': 'Every dye from Ilse\'s Dyeworks, worn by the hero.', 'layout': 'grid', 'rows': dyes})

PICK = rd('scripts', 'pickups', 'item_pickup.gd')
ABIL = re.search(r'const ABILITIES := \[([^\]]*)\]', PICK).group(1)
SPELLS = re.findall(r'"(\w+)": \{"name": "([^"]+)", "cost": ([\d.]+), "damage": (\d+)', rd('scripts', 'combat', 'spells.gd'))
spell = {s[0]: s for s in SPELLS}
finds = []
for m in re.finditer(r'"(\w+)": \{"title": "([^"]+)", "text": "([^"]*)"', PICK):
    k, name, text = m.groups()
    kind = 'Spell' if k in spell else 'Ability' if '"%s"' % k in ABIL else 'Upgrade' if k in ('life_fruit', 'mana_dew', 'potion_shard', 'grain_shard', 'meteor_shard') else 'Relic'
    f = {'Kind': kind}
    if k in spell:
        f.update({'MP cost': int(float(spell[k][2])), 'Damage': int(spell[k][3])})
    finds.append(clean({'id': k, 'name': name, 'sub': kind, 'img': img('pickups/%s.png' % k), 'text': text or ITEMS.get(k, {}).get('desc', ''),
                        'r': 2 if kind in ('Ability', 'Spell') else 1 if kind == 'Relic' else 0, 'fields': f}))
sections.append({'id': 'finds', 'group': 'Items', 'label': 'Finds', 'title': 'Abilities, spells and finds',
                 'lede': 'Everything the hero picks up in the world, drawn as it floats there.', 'layout': 'grid', 'filter': 'Kind', 'rows': finds})
sections.append({'id': 'goods', 'group': 'Items', 'label': 'Goods', 'title': 'Keys, charts and supplies',
                 'lede': 'Goods bought in shops. Each has an icon on its shelf row (pass 554); the Shops tab shows them there.',
                 'layout': 'list', 'filter': 'Kind', 'rows': goods})

# --- Systems ------------------------------------------------------------------------------
SK = data('skills')
skill_rows = []
names = {n['id']: n['name'] for n in SK['nodes']}
for n in SK['nodes']:
    skill_rows.append(clean({'id': n['id'], 'name': n['name'], 'sub': n['branch'] + ' bough', 'text': n.get('desc', ''),
                             'tags': ['Needs ' + names.get(n['needs'], n['needs'])] if n.get('needs') else ['Root of the bough'],
                             'fields': {'Bough': n['branch'], 'Cost': n.get('cost')}}))
sections.append({'id': 'skills', 'group': 'Systems', 'label': 'Skills', 'title': 'The skill tree',
                 'lede': 'Every node on the three boughs, in tree order. Grain Shards and guardians give the points.',
                 'layout': 'list', 'keepOrder': True, 'filter': 'Bough', 'rows': skill_rows})

keeper = {n.get('shop'): (nid, n) for nid, n in NPCS.items() if n.get('shop')}
shop_rows = []
for sid, s in SHOPS.items():
    k = keeper.get(sid)
    h = where.get(k[0]) if k else None
    stock = s.get('stock', [])
    shop_rows.append(clean({
        'id': sid, 'name': s['name'], 'sub': (k[1].get('name', '') if k else '') + (' - ' + ZONES.get(h['zone'], '') if h else ''),
        'img': img('shops/%s.jpg' % sid), 'quote': s.get('greeting', ''),
        'list': [{'name': ITEMS.get(st['item'], {}).get('name', title(st['item'])), 'text': '%d gold%s' % (st.get('price', 0), ' (needs %s)' % st['requires'] if st.get('requires') else '')} for st in stock],
        'fields': {'Zone': ZONES.get(h['zone'], '') if h else '', 'Goods': len(stock), 'Cheapest': min((st.get('price', 0) for st in stock), default=None),
                   'Dearest': max((st.get('price', 0) for st in stock), default=None)},
    }))
sections.append({'id': 'shops', 'group': 'Systems', 'label': 'Shops', 'title': 'Shops',
                 'lede': 'Every shop menu as the player sees it, opened beside its keeper with 5000 gold in hand.',
                 'layout': 'wide', 'filter': 'Zone', 'rows': shop_rows})

tracks = []
used = {}
for h in R.values():
    for key in ('music', 'ambience'):
        if h.get(key):
            used.setdefault(h[key], []).append(h.get('name', h['id']))
for f in sorted(glob.glob(os.path.join(ROOT, 'assets', 'music', '*.ogg'))):
    tid = os.path.basename(f)[:-4]
    kind = 'Ambience' if tid.startswith('amb_') else 'Music'
    z = tid.replace('amb_', '').split('_')[0]
    tracks.append(clean({'id': tid, 'name': title(tid.replace('amb_', '')), 'sub': kind, 'text': 'assets/music/%s.ogg' % tid,
                         'tags': used.get(tid, [])[:6],
                         'fields': {'Kind': kind, 'Zone': ZONES.get(z, ''), 'Size KB': os.path.getsize(f) // 1024, 'Rooms set': len(used.get(tid, []))}}))
sections.append({'id': 'music', 'group': 'Systems', 'label': 'Music', 'title': 'Music and ambience',
                 'lede': 'Every track in assets/music. Zones play their own track by default; rooms listed here set one in their header.',
                 'layout': 'list', 'filter': 'Kind', 'rows': tracks})

cat = {'made': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'sections': sections}
os.makedirs(CAT, exist_ok=True)
json.dump(cat, open(os.path.join(CAT, 'catalog.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
for s in sections:
    rows = s['rows']
    print('%-10s %3d rows, %3d with pictures' % (s['id'], len(rows), sum(1 for r in rows if r.get('img'))))
