"""Batch 2 — zone chickens (camps, King's Court and mission sites)."""
import math
from pal import *

HEAD_Y, HEAD_TOP = -0.794, 4.29
WHITE_HEAD = (244, 242, 236)

def basic(part, pos, beak=BEAK, wattle=WATTLE, foot=FEET):
    if feet(part):
        return g(foot, pos, 3)
    if part == 'Beak':
        return g(beak, pos, 4)
    if part == 'Wattle':
        return g(wattle, pos, 5)
    return None

# ------------------------------------------------------------------ Crate Runner
def crate_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Body':
        if is_front(n):
            for cx in (-.5, .5):
                if abs(px - cx) < .3 and 1.32 < pz < 1.86:
                    return (74, 82, 40) if (abs(px - cx) > .24 or pz > 1.8 or pz < 1.38) else g((96, 106, 52), pos, 6)
        return g((112, 122, 64), pos, 7, .06)
    return g((224, 188, 132), pos, 8, .06)

def crate_props(P):
    P.mat('wood', (182, 128, 72), .8); P.mat('wood dark', (128, 86, 46), .8); P.mat('olive', (96, 108, 52), .75)
    P.mat('strap', (92, 64, 40), .7)
    P.box('crate', (0, 1.84, 2.5), (1.4, .72, 1.5), 'Body', 'wood')
    for z in (1.8, 3.2):
        P.box(f'crate slat {z}', (0, 1.84, z), (1.44, .76, .12), 'Body', 'wood dark')
    for x in (-.66, .66):
        P.box(f'crate post {x}', (x, 1.84, 2.5), (.12, .76, 1.52), 'Body', 'wood dark')
    P.box('crate stencil', (0, 2.21, 2.5), (.5, .02, .3), 'Body', 'olive')
    for x in (-.5, .5):
        P.box(f'strap {x}', (x, -1.25, 2.25), (.14, .06, 1.2), 'Body', 'strap')
    P.box('cap', (0, HEAD_Y, HEAD_TOP + .1), (1.48, 1.48, .2), 'Head', 'olive')
    P.box('cap brim', (0, HEAD_Y - .92, HEAD_TOP + .02), (1.1, .44, .07), 'Head', 'olive')

# ------------------------------------------------------------------ Miner
def miner_paint(part, n, pos, *a):
    b = basic(part, pos, foot=(112, 112, 118))
    if b:
        return b
    c = (192, 122, 70)
    if field(pos, 2.4, 13) > .62:
        c = mix(c, (92, 80, 72), .55)
    return g(c, pos, 6, .07)

def miner_props(P):
    P.mat('hat', (250, 200, 40), .45); P.mat('hat dark', (214, 160, 24), .5); P.mat('lamp', (64, 64, 70), .4, .5)
    P.mat('lens', (255, 242, 176), .2, 0, 5); P.mat('handle', (128, 84, 44), .8); P.mat('pick', (150, 156, 164), .35, .7)
    P.box('hat brim', (0, HEAD_Y - .06, HEAD_TOP + .03), (1.84, 1.9, .07), 'Head', 'hat dark')
    P.box('hat dome', (0, HEAD_Y, HEAD_TOP + .17), (1.56, 1.56, .26), 'Head', 'hat')
    P.box('hat crown', (0, HEAD_Y, HEAD_TOP + .37), (1.22, 1.22, .16), 'Head', 'hat')
    P.box('hat ridge', (0, HEAD_Y, HEAD_TOP + .49), (.26, 1.3, .1), 'Head', 'hat dark')
    P.box('lamp', (0, HEAD_Y - .9, HEAD_TOP + .24), (.62, .3, .5), 'Head', 'lamp')
    P.box('lamp lens', (0, HEAD_Y - 1.06, HEAD_TOP + .24), (.48, .04, .38), 'Head', 'lens')
    P.seg('pick handle', (1.42, .25, .95), (1.42, -.32, 2.95), .14, .14, 'Wing_R', 'handle')
    P.seg('pick head', (1.42, -.9, 2.6), (1.42, .25, 3.1), .2, .16, 'Wing_R', 'pick')

def miner_fx(fx):
    pass

# ------------------------------------------------------------------ Paratrooper
def para_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and abs(pz - 1.5) < .08:
        return g((70, 60, 40), pos, 7)
    if part == 'Body' and is_front(n) and abs(abs(px) - .5) < .22 and 1.0 < pz < 1.38:
        return g((84, 94, 48), pos, 8)
    return g((108, 120, 66), pos, 9, .07)

def para_props(P):
    P.mat('leather', (124, 76, 40), .7); P.mat('pack', (82, 92, 50), .75); P.mat('pack dark', (64, 72, 38), .75)
    P.mat('strap', (172, 142, 92), .7); P.mat('brass', (150, 120, 60), .35, .6); P.mat('glass', (120, 204, 214), .15, 0, .6)
    P.mat('buckle', (190, 190, 196), .3, .7)
    P.box('cap', (0, HEAD_Y + .05, HEAD_TOP + .1), (1.48, 1.5, .22), 'Head', 'leather')
    for s in (-1, 1):
        P.box(f'ear flap {s}', (s * .75, HEAD_Y + .15, 3.9), (.08, .56, .66), 'Head', 'leather')
        P.box(f'goggle {s}', (s * .32, -1.56, HEAD_TOP - .1), (.38, .1, .3), 'Head', 'brass')
        P.box(f'goggle glass {s}', (s * .32, -1.62, HEAD_TOP - .1), (.26, .04, .2), 'Head', 'glass')
        P.box(f'shoulder strap {s}', (s * .55, -1.25, 2.2), (.14, .06, 1.4), 'Body', 'strap')
    P.box('goggle strap', (0, HEAD_Y, HEAD_TOP - .1), (1.46, 1.46, .08), 'Head', 'pack dark')
    P.box('chute pack', (0, 1.78, 2.2), (1.5, .62, 1.3), 'Body', 'pack')
    P.box('chute flap', (0, 1.8, 2.9), (1.54, .66, .16), 'Body', 'pack dark')
    P.box('chute handle', (.5, 2.12, 2.4), (.12, .06, .4), 'Body', 'strap')
    P.box('chest buckle', (0, -1.27, 1.78), (.32, .06, .22), 'Body', 'buckle')

# ------------------------------------------------------------------ Coral Reef
def coral_paint(part, n, pos, *a):
    b = basic(part, pos, beak=(250, 220, 120), wattle=(255, 100, 90), foot=(240, 112, 100))
    if b:
        return b
    f = field(pos, 2.4, 19)
    c = (255, 122, 124) if f > .55 else (64, 202, 192) if f < .38 else (255, 174, 160)
    u, v = plane(n, pos)
    if dots(u, v, .3, 29, .2, .5):
        c = shade(c, 1.15)
    return g(c, pos, 6, .06)

def coral_props(P):
    P.mat('star', (255, 142, 40), .6); P.mat('star dot', (255, 206, 120), .6); P.mat('barnacle', (222, 220, 210), .8)
    P.mat('coral branch', (255, 90, 120), .6)
    cx, cy, cz = .1, HEAD_Y - .15, HEAD_TOP + .05
    P.box('star center', (cx, cy, cz), (.28, .28, .1), 'Head', 'star')
    for k in range(5):
        a = math.radians(90 + 72 * k)
        P.seg(f'star arm {k}', (cx, cy, cz), (cx + .5 * math.cos(a), cy + .5 * math.sin(a), cz), .18, .08, 'Head', 'star')
        P.box(f'star dot {k}', (cx + .3 * math.cos(a), cy + .3 * math.sin(a), cz + .05), (.06, .06, .03), 'Head', 'star dot')
    for s in (-1, 1):
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        for k, (y, z) in enumerate([(-.4, 2.3), (.3, 1.8), (.8, 2.4), (-.1, 1.5)]):
            P.box(f'barnacle {s} {k}', (s * 1.31, y, z), (.12, .16, .16), wing, 'barnacle')
    P.seg('coral a', (.3, 1.0, 2.9), (.45, 1.15, 3.5), .14, .14, 'Body', 'coral branch')
    P.seg('coral b', (.4, 1.1, 3.25), (.7, 1.2, 3.55), .12, .12, 'Body', 'coral branch')
    P.seg('coral c', (.35, 1.05, 3.1), (.1, 1.2, 3.4), .1, .1, 'Body', 'coral branch')

# ------------------------------------------------------------------ Castle Guard
def guard_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(122, 122, 128))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    u, v = plane(n, pos)
    if part == 'Body' and (is_front(n) or is_back(n)) and abs(px) < .82:
        if abs(px) > .74 or pz < 1.14:
            return g((226, 180, 50), pos, 7)  # gold trim
        if abs(px) < .34 and 1.5 < pz < 2.12 and not (pz > 1.98 and math.floor((px + .34) / .136) % 2):
            return g((236, 190, 54), pos, 8)  # tower crest
        return g((40, 82, 172), pos, 9, .05)
    mail = (math.floor(u * 9) + math.floor(v * 9)) % 2
    return g((150, 156, 164) if mail else (122, 128, 136), pos, 10, .04)

def guard_props(P):
    P.mat('steel', (172, 178, 186), .35, .6); P.mat('steel dark', (120, 126, 134), .4, .6); P.mat('wood', (150, 96, 50), .8)
    P.box('helmet brim', (0, HEAD_Y, HEAD_TOP + .02), (2.0, 2.0, .08), 'Head', 'steel')
    P.box('helmet dome', (0, HEAD_Y, HEAD_TOP + .18), (1.5, 1.5, .3), 'Head', 'steel')
    P.box('helmet top', (0, HEAD_Y, HEAD_TOP + .39), (1.1, 1.1, .14), 'Head', 'steel dark')
    for k, (w, z) in enumerate([(.56, 1.53), (.86, 1.73), (1.0, 1.95), (.86, 2.17), (.56, 2.37)]):
        P.box(f'shield rim {k}', (1.38, -.05, z), (.08, w + .12, .24), 'Wing_R', 'steel dark')
        P.box(f'shield {k}', (1.43, -.05, z), (.08, w, .22), 'Wing_R', 'wood')
    P.box('shield boss', (1.49, -.05, 1.95), (.06, .3, .3), 'Wing_R', 'steel')

# ------------------------------------------------------------------ Court Jester
def jester_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((214, 40, 48) if part.endswith(('_L', 'L_1', 'L_2', 'L_3')) or '_L' in part else (250, 200, 40), pos, 3)
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((250, 246, 240), pos, 6, .04)
    u, v = plane(n, pos)
    on = (math.floor(u / .66 + v / .84) + math.floor(u / .66 - v / .84)) % 2
    return g((214, 40, 48) if on else (250, 200, 40), pos, 7, .04)

def jester_props(P):
    P.mat('red', (214, 40, 48), .6); P.mat('yellow', (250, 200, 40), .6); P.mat('bell', (255, 214, 70), .25, .7)
    P.mat('ruff', (250, 248, 240), .8); P.mat('ruff shade', (226, 222, 212), .8)
    for k in range(10):
        a = 2 * math.pi * k / 10
        P.box(f'ruff {k}', (.88 * math.cos(a), HEAD_Y + .02 + .78 * math.sin(a), 2.78), (.36, .36, .22), 'Neck', 'ruff' if k % 2 else 'ruff shade', (0, 0, math.degrees(a)))
    for s, mat in ((-1, 'red'), (1, 'yellow')):
        P.box(f'hat band {s}', (s * .38, HEAD_Y, HEAD_TOP + .1), (.76, 1.5, .22), 'Head', mat)
        P.seg(f'hat point a {s}', (s * .36, HEAD_Y, HEAD_TOP + .14), (s * .82, HEAD_Y, HEAD_TOP + .82), .62, .62, 'Head', mat)
        P.seg(f'hat point b {s}', (s * .8, HEAD_Y, HEAD_TOP + .8), (s * 1.18, HEAD_Y, HEAD_TOP + .66), .42, .42, 'Head', mat)
        P.seg(f'hat point c {s}', (s * 1.16, HEAD_Y, HEAD_TOP + .68), (s * 1.32, HEAD_Y, HEAD_TOP + .3), .28, .28, 'Head', mat)
        P.box(f'bell {s}', (s * 1.34, HEAD_Y, HEAD_TOP + .16), (.24, .24, .24), 'Head', 'bell')

# ------------------------------------------------------------------ Ironbeak
def iron_paint(part, n, pos, *a):
    px, py, pz = pos
    if part == 'Beak':
        u, v = plane(n, pos)
        if dots(u + 3, v, .28, 7, .18, .9):
            return (70, 72, 78)
        return g((128, 132, 140), pos, 3, .05)
    b = basic(part, pos, foot=(92, 86, 80))
    if b:
        return b
    if part == 'Head' and is_front(n):
        # Scar across the left brow and cheek.
        t = (pz - 4.25) / (3.25 - 4.25); sx = -.75 + t * .6
        if 0 <= t <= 1 and abs(px - sx) < .06:
            return (226, 140, 136)
    if part == 'Neck':
        return g((52, 92, 52), pos, 6)
    c = (132, 118, 102) if field(pos, 2.8, 33) > .45 else (110, 98, 86)
    return g(c, pos, 7, .07)

def iron_props(P):
    P.mat('bandana', (54, 96, 54), .7); P.mat('tag', (196, 200, 206), .3, .7); P.mat('chain', (150, 154, 160), .35, .7)
    P.mat('rivet', (80, 82, 88), .35, .7)
    P.box('bandana wrap', (0, -.82, 2.74), (1.28, 1.06, .26), 'Body', 'bandana')
    P.box('bandana knot', (0, -.2, 2.95), (.3, .24, .22), 'Body', 'bandana')
    P.box('bandana tail', (.12, -.08, 2.72), (.16, .1, .4), 'Body', 'bandana', (0, 20, 0))
    P.seg('chain l', (-.3, -1.25, 2.55), (.2, -1.26, 2.05), .05, .05, 'Body', 'chain')
    P.box('dog tag', (.26, -1.27, 1.92), (.22, .05, .3), 'Body', 'tag')
    for s in (-1, 1):
        P.box(f'beak plate rivet {s}', (s * .73, -1.9, 3.1), (.05, .1, .1), 'Beak', 'rivet')

# ------------------------------------------------------------------ Deepsea Diver
BRASS = (198, 150, 64)

def diver_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part) or part.startswith('Leg'):
        return g((72, 76, 84), pos, 3)
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 230, 220), pos, 4)
    u, v = plane(n, pos)
    if abs((v * 3) % 1 - .5) < .05:
        return g((150, 76, 34), pos, 5)  # canvas seams
    return g((204, 112, 52), pos, 6, .07)

def diver_props(P):
    P.mat('brass', BRASS, .3, .75); P.mat('brass dark', (150, 108, 40), .35, .7); P.mat('glass', (140, 214, 232), .1, 0, .4)
    P.mat('hose', (52, 52, 58), .6); P.mat('lead', (96, 100, 108), .5, .4)
    c = (0, HEAD_Y, 3.52)
    P.box('helmet top', (0, HEAD_Y, 4.42), (1.74, 1.74, .22), 'Head', 'brass')
    P.box('helmet crown', (0, HEAD_Y, 4.6), (1.2, 1.2, .16), 'Head', 'brass')
    P.box('helmet valve', (0, HEAD_Y + .2, 4.76), (.3, .3, .18), 'Head', 'brass dark')
    P.box('helmet back', (0, HEAD_Y + .87, 3.5), (1.74, .16, 1.84), 'Head', 'brass')
    for s in (-1, 1):
        P.box(f'helmet side {s}', (s * .87, HEAD_Y, 3.5), (.16, 1.74, 1.84), 'Head', 'brass')
        P.box(f'porthole frame {s}', (s * .97, HEAD_Y - .05, 3.62), (.08, .62, .62), 'Head', 'brass dark')
        P.box(f'porthole glass {s}', (s * 1.0, HEAD_Y - .05, 3.62), (.06, .44, .44), 'Head', 'glass')
        P.box(f'window jamb {s}', (s * .79, -1.66, 3.5), (.18, .14, 1.62), 'Head', 'brass dark')
        P.box(f'bolt {s}', (s * .79, -1.74, 3.9), (.08, .04, .08), 'Head', 'brass')
        P.box(f'weight {s}', (s * .55, -1.28, 1.75), (.42, .12, .44), 'Body', 'lead')
    P.box('window lintel', (0, -1.66, 4.2), (1.74, .14, .3), 'Head', 'brass dark')
    P.box('window sill', (0, -1.66, 2.74), (1.74, .14, .18), 'Head', 'brass dark')
    P.box('breastplate', (0, -.62, 2.82), (1.96, 1.5, .26), 'Body', 'brass')
    P.seg('hose a', (0, .1, 3.9), (0, 1.25, 3.3), .16, .16, 'Body', 'hose')
    P.seg('hose b', (0, 1.25, 3.3), (0, 1.62, 2.4), .16, .16, 'Body', 'hose')

def diver_fx(fx):
    for i, (x, y, z) in enumerate([(.3, -1.0, 5.1), (.1, -.8, 5.5), (.35, -.9, 5.85)]):
        fx(f'FX_Diver_Bubble_{i}', (x, y, z), (.12 - i * .02,) * 3, (200, 240, 255), 2, 'Head')

# ------------------------------------------------------------------ Dragon Hatchling
def hatch_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((150, 50, 30), pos, 3)
    if part == 'Beak':
        return g((242, 152, 52), pos, 4)
    if part == 'Wattle':
        return g((226, 80, 34), pos, 5)
    if part == 'Body' and is_front(n) and abs(px) < .78:
        return g((252, 204, 92), pos, 6) if (pz * 4.5) % 1 > .2 else g((222, 160, 60), pos, 6)
    u, v = plane(n, pos)
    cu = math.floor(u / .24 + (.5 if math.floor(v / .2) % 2 else 0)); fv = (v / .2) % 1
    c = (228, 88, 40) if h(cu, math.floor(v / .2), 3) > .3 else (204, 64, 34)
    if fv < .25:
        c = shade(c, .75)
    return g(c, pos, 7, .04)

def hatch_eye(part):
    if 'Highlight' in part:
        return (255, 196, 70), (255, 150, 30)
    return None

def hatch_props(P):
    P.mat('horn', (70, 46, 42), .5); P.mat('shell', (248, 244, 232), .5); P.mat('spike', (168, 40, 30), .55)
    P.mat('membrane', (150, 36, 30), .6)
    for s in (-1, 1):
        P.seg(f'horn {s}', (s * .38, HEAD_Y + .3, HEAD_TOP - .02), (s * .56, HEAD_Y + .62, HEAD_TOP + .48), .18, .18, 'Head', 'horn')
        P.box(f'wing membrane {s}', (s * .95, .55, 3.18), (.06, .8, .56), 'Body', 'membrane', (0, s * 28, 0))
        P.box(f'wing bone {s}', (s * 1.02, .55, 3.42), (.08, .86, .1), 'Body', 'spike', (0, s * 28, 0))
    for k, (x, y, r) in enumerate([(-.2, HEAD_Y - .5, 15), (.25, HEAD_Y - .35, -20), (0, HEAD_Y + .05, 8)]):
        P.box(f'shell shard {k}', (x, y, HEAD_TOP + .06), (.34, .3, .12), 'Head', 'shell', (r, -r, r * 2))
    for k in range(5):
        P.box(f'back spike {k}', (0, -.1 + k * .36, 3.04 - k * .03), (.16, .24, .3 - k * .02), 'Body', 'spike')

# ------------------------------------------------------------------ Royal Guard
def royal_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((40, 50, 92), pos, 3)
    if feet(part):
        return g((38, 38, 42), pos, 3)
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n):
        if abs(px - (pz - 2.05) * .7) < .13:
            return g((246, 246, 244), pos, 7)  # cross belt
        if abs(px + .02) < .07 and (pz * 3.3) % 1 < .35 and 1.2 < pz < 2.8:
            return (255, 210, 60)  # gold buttons
    if part.startswith('Wing') and pz < 1.46:
        return g((246, 246, 244), pos, 8)
    if part == 'Body' and pz < 1.12:
        return g((246, 246, 244), pos, 9)
    return g((204, 30, 42), pos, 10, .05)

def royal_props(P):
    P.mat('fur', (28, 28, 34), .95); P.mat('fur shade', (44, 44, 52), .95); P.mat('chin', (232, 186, 60), .3, .7)
    P.mat('plume', (214, 30, 44), .7)
    P.stack('bearskin', (0, HEAD_Y + .02, HEAD_TOP - .02), [(1.54, 1.54, .5), (1.5, 1.5, .5), (1.36, 1.36, .34), (1.04, 1.04, .16)], 'Head', 'fur')
    P.box('bearskin tuft', (.3, HEAD_Y - .5, HEAD_TOP + .9), (.5, .3, .3), 'Head', 'fur shade')
    P.box('chin strap', (0, -1.55, 3.02), (1.3, .05, .08), 'Head', 'chin')
    P.seg('plume', (-.78, HEAD_Y + .1, HEAD_TOP + .2), (-.86, HEAD_Y + .25, HEAD_TOP + 1.0), .16, .16, 'Head', 'plume')

SPECS = {
    'CrateRunner': dict(name='Crate Runner', paint=crate_paint, props=crate_props, rarity='Common', band=2, zone='Supply Depot',
                        vfx='None required. Optional: small dust kick on Walk.'),
    'Miner': dict(name='Miner Chicken', paint=miner_paint, props=miner_props, fx=miner_fx, rarity='Uncommon', band=3, zone='Crystal Mine',
                  glow=3, vfx='Headlamp SpotLight forward from the lamp lens (warm white); pebble sparks on Peck.'),
    'Paratrooper': dict(name='Paratrooper Chicken', paint=para_paint, props=para_props, rarity='Rare', band=4, zone='Loyalist Landing',
                        vfx='None required. Optional: parachute pop-out on Celebrate (a tweened canopy part).'),
    'Coral': dict(name='Coral Reef Chicken', paint=coral_paint, props=coral_props, rarity='Rare', band=4, zone='Pirate Cove',
                  vfx='Occasional bubbles rising while idle.'),
    'CastleGuard': dict(name='Castle Guard Chicken', paint=guard_paint, props=guard_props, rarity='Rare', band=5, zone='Watchtower Fort',
                        ortho=7.0, vfx='None required. Optional: shield clang spark on Hit.'),
    'Jester': dict(name='Court Jester', paint=jester_paint, props=jester_props, rarity='Rare', band=5, zone="Chicken King's Court",
                   ortho=7.4, vfx='Bell jingle sound + small confetti puff on Celebrate.'),
    'Ironbeak': dict(name='Ironbeak Chicken', paint=iron_paint, props=iron_props, rarity='Rare', band=5, zone='Ironbeak HQ',
                     vfx='Metal spark on Peck (beak hits).'),
    'DeepseaDiver': dict(name='Deepsea Diver', paint=diver_paint, props=diver_props, fx=diver_fx, rarity='Epic', band=6, zone='Pirate Cove',
                         ortho=7.2, rough=.7, vfx='Bubble trail rising from the helmet valve; porthole glass glint.'),
    'DragonHatchling': dict(name='Dragon Hatchling', paint=hatch_paint, eye=hatch_eye, props=hatch_props, rarity='Epic', band=6,
                            zone='Dragon Roost', glow=2, vfx='Ember puff from the beak on Peck; tiny smoke ring on Celebrate.'),
    'RoyalGuard': dict(name='Royal Guard Chicken', paint=royal_paint, props=royal_props, rarity='Epic', band=6,
                       zone="Chicken King's Court", ortho=7.6, vfx='None required.'),
}
