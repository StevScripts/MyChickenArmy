"""Batch 3 — Legendary and Mythic chickens."""
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

# ------------------------------------------------------------------ Geode
AMETHYST = ((156, 82, 228), (206, 150, 255), (120, 54, 196))

def geode_paint(part, n, pos, *a):
    px, py, pz = pos
    if part == 'Wattle':
        return (184, 104, 240), (110, 40, 190)
    b = basic(part, pos, beak=(74, 72, 80), foot=(80, 78, 86))
    if b:
        return b
    e = None
    if part == 'Body' and is_front(n):
        e = math.hypot(px / .74, (pz - 1.85) / .62)
    elif part.startswith('Wing') and is_side(n):
        e = math.hypot((py - .18) / .74, (pz - 1.95) / .56)
    if e is not None and e < 1.12:
        if e < .9:
            k = int(h(math.floor(px * 5 + py * 5), math.floor(pz * 5), 4) * 2.99)
            c = mix(AMETHYST[1], AMETHYST[k], .35 + .65 * e)
            return c, shade(c, .55)
        if e < 1.0:
            return g((236, 226, 246), pos, 6, .04)
        return (52, 48, 58)
    c = (118, 116, 124) if field(pos, 2.2, 7) > .5 else (102, 100, 108)
    return g(c, pos, 7, .06)

def geode_props(P):
    P.mat('crystal', (176, 104, 244), .15, 0, 2.5); P.mat('crystal light', (222, 176, 255), .15, 0, 3)
    for k, (a, b, w) in enumerate([((-.45, .55, 2.85), (-.62, .78, 3.7), .3), ((.35, .95, 2.85), (.5, 1.15, 3.5), .26),
                                   ((0, .25, 2.85), (.05, .3, 3.85), .34), ((.6, .3, 2.85), (.85, .35, 3.35), .2)]):
        P.seg(f'back crystal {k}', a, b, w, w, 'Body', 'crystal' if k % 2 else 'crystal light')
    P.seg('head crystal', (.38, HEAD_Y + .35, HEAD_TOP - .05), (.48, HEAD_Y + .45, HEAD_TOP + .45), .2, .2, 'Head', 'crystal light')
    P.seg('head crystal b', (.12, HEAD_Y + .45, HEAD_TOP - .05), (.1, HEAD_Y + .55, HEAD_TOP + .3), .14, .14, 'Head', 'crystal')

# ------------------------------------------------------------------ Airship Captain
NAVY = (32, 46, 98)

def captain_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n):
        if abs(abs(px) - .36) < .07 and (pz * 3) % 1 < .4 and pz > 1.2:
            return (250, 204, 70)
        if abs(px) < .1:
            return g((22, 32, 72), pos, 7)
    if pz < 1.14 or (part.startswith('Wing') and pz < 1.42):
        return g((236, 190, 60), pos, 8)  # gold hem and cuffs
    return g(NAVY, pos, 9, .06)

def captain_props(P):
    P.mat('navy', NAVY, .6); P.mat('gold', (240, 192, 60), .3, .7); P.mat('visor', (22, 22, 26), .3)
    P.mat('brass', (198, 150, 64), .3, .75); P.mat('wood', (160, 104, 54), .7); P.mat('glass', (150, 214, 236), .1, 0, .4)
    P.box('hat band', (0, HEAD_Y, HEAD_TOP + .14), (1.5, 1.5, .28), 'Head', 'navy')
    P.box('hat trim', (0, HEAD_Y, HEAD_TOP + .2), (1.54, 1.54, .07), 'Head', 'gold')
    P.box('hat top', (0, HEAD_Y + .05, HEAD_TOP + .36), (1.7, 1.8, .16), 'Head', 'navy')
    P.box('hat visor', (0, HEAD_Y - .92, HEAD_TOP + .06), (1.16, .42, .06), 'Head', 'visor')
    P.box('hat badge', (0, HEAD_Y - .78, HEAD_TOP + .26), (.3, .05, .22), 'Head', 'gold')
    for s in (-1, 1):
        P.box(f'epaulette {s}', (s * .9, -.55, 2.97), (.5, .62, .12), 'Body', 'gold')
        for k in range(3):
            P.box(f'fringe {s} {k}', (s * 1.12, -.75 + k * .2, 2.84), (.06, .08, .2), 'Body', 'gold')
    P.seg('telescope', (1.42, -1.0, 2.0), (1.42, .75, 2.3), .2, .2, 'Wing_R', 'brass')
    P.seg('telescope eye', (1.42, .65, 2.28), (1.42, .95, 2.33), .26, .26, 'Wing_R', 'brass')
    P.box('telescope lens', (1.42, -1.03, 1.99), (.16, .04, .16), 'Wing_R', 'glass')
    P.box('prop pack', (0, 1.72, 2.4), (1.0, .5, .84), 'Body', 'brass')
    P.box('prop hub', (0, 2.06, 2.55), (.22, .2, .22), 'Body', 'visor')
    P.box('prop blade a', (0, 2.12, 2.55), (1.5, .06, .2), 'Body', 'wood', (0, 20, 0))
    P.box('prop blade b', (0, 2.12, 2.55), (.2, .06, 1.5), 'Body', 'wood', (0, 20, 0))

# ------------------------------------------------------------------ Dragon Knight
def dk_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part) or part.startswith('Leg'):
        return g((40, 36, 40), pos, 3)
    b = basic(part, pos, beak=(236, 168, 52), wattle=(140, 20, 30))
    if b:
        return b
    if pz > 2.82 and part == 'Body' or (part.startswith('Wing') and pz > 2.64):
        return g((232, 182, 58), pos, 4)  # gold trim
    u, v = plane(n, pos)
    cu = math.floor(u / .22 + (.5 if math.floor(v / .18) % 2 else 0)); fv = (v / .18) % 1
    c = (138, 22, 34) if h(cu, math.floor(v / .18), 3) > .35 else (112, 16, 28)
    if fv < .28:
        c = (62, 10, 18)
    return g(c, pos, 5, .04)

def dk_eye(part):
    if 'Highlight' in part:
        return (255, 160, 40), (255, 120, 20)
    return (30, 8, 4), (90, 20, 0)

def dk_props(P):
    P.mat('bone', (184, 180, 172), .6); P.mat('bone shade', (150, 146, 140), .6); P.mat('cape', (150, 20, 32), .6); P.mat('horn', (52, 40, 40), .5)
    P.mat('armor', (128, 20, 32), .45, .3); P.mat('gold', (234, 184, 58), .3, .7)
    P.box('skull top', (0, HEAD_Y + .02, HEAD_TOP + .16), (1.58, 1.62, .34), 'Head', 'bone')
    P.box('mask brow', (0, -1.56, 4.17), (1.5, .1, .26), 'Head', 'bone shade')
    P.box('mask cheek', (0, -1.56, 3.44), (1.5, .1, .14), 'Head', 'bone shade')
    P.box('mask bridge', (0, -1.56, 3.75), (.18, .1, .6), 'Head', 'bone')
    for s in (-1, 1):
        P.box(f'mask side {s}', (s * .72, -1.56, 3.75), (.08, .1, .6), 'Head', 'bone')
    P.box('skull crest', (0, HEAD_Y + .1, HEAD_TOP + .4), (.24, 1.3, .2), 'Head', 'bone shade')
    for s in (-1, 1):
        P.box(f'skull cheek {s}', (s * .8, HEAD_Y - .2, 3.75), (.14, 1.0, .9), 'Head', 'bone')
        P.seg(f'horn a {s}', (s * .55, HEAD_Y + .25, HEAD_TOP + .24), (s * .9, HEAD_Y + .62, HEAD_TOP + .78), .26, .26, 'Head', 'horn')
        P.seg(f'horn b {s}', (s * .88, HEAD_Y + .58, HEAD_TOP + .74), (s * .82, HEAD_Y + 1.05, HEAD_TOP + 1.0), .17, .17, 'Head', 'horn')
        P.box(f'pauldron {s}', (s * 1.02, -.45, 2.98), (.52, .96, .3), 'Body', 'armor')
        P.box(f'pauldron rim {s}', (s * 1.02, -.45, 3.14), (.56, 1.0, .06), 'Body', 'gold')
    P.box('chest emblem', (0, -1.26, 1.85), (.34, .06, .34), 'Body', 'gold')
    P.box('cape', (0, 1.52, 1.95), (2.3, .08, 2.0), 'Body', 'cape')
    P.box('cape hem', (0, 1.53, .98), (2.32, .1, .1), 'Body', 'gold')

# ------------------------------------------------------------------ Pharaoh
def pharaoh_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 200, 60), foot=(232, 182, 60))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 210, 160), pos, 6, .04)
    if part == 'Body' and pz > 2.2 and (is_front(n) or is_side(n) or is_top(n)):
        row = math.floor((pz - 2.2) / .14)
        return g([(240, 192, 54), (48, 190, 190), (240, 192, 54), (40, 70, 172)][row % 4], pos, 7, .04)
    if part.startswith('Wing') and 1.56 < pz < 1.78:
        return g((240, 192, 54), pos, 8)
    u, _ = plane(n, pos)
    return g((240, 234, 214) if math.floor(u * 9) % 3 else (222, 214, 190), pos, 9, .03)

def pharaoh_props(P):
    P.mat('gold', (240, 194, 56), .35, .6); P.mat('lapis', (36, 70, 170), .5); P.mat('turq', (48, 190, 190), .5)
    P.box('nemes top', (0, HEAD_Y + .02, HEAD_TOP + .09), (1.58, 1.58, .18), 'Head', 'lapis')
    P.box('nemes brow', (0, HEAD_Y - .79, HEAD_TOP - .02), (1.6, .1, .22), 'Head', 'gold')
    P.box('uraeus', (0, -1.62, HEAD_TOP + .14), (.16, .1, .34), 'Head', 'gold')
    for s in (-1, 1):
        for k in range(7):
            P.box(f'lappet {s} {k}', (s * .8, HEAD_Y - .42, 4.2 - k * .22), (.16, .46, .22), 'Head', 'gold' if k % 2 else 'lapis')
        P.box(f'side drape {s}', (s * .8, HEAD_Y + .25, 3.9), (.14, .9, .9), 'Head', 'lapis')
    for k in range(6):
        P.box(f'back flap {k}', (0, HEAD_Y + .79, 4.2 - k * .22), (1.44, .12, .22), 'Head', 'gold' if k % 2 else 'lapis')

# ------------------------------------------------------------------ Stained Glass
GLASS = [(214, 30, 50), (36, 86, 214), (30, 170, 80), (250, 186, 40), (150, 60, 200), (40, 190, 210)]

def voronoi(u, v, cell, seed):
    cu, cv = math.floor(u / cell), math.floor(v / cell); best = [(9, None), (9, None)]
    for du in (-1, 0, 1):
        for dv in (-1, 0, 1):
            x, y = cu + du, cv + dv
            sx = (x + .15 + .7 * h(x, y, seed)) * cell; sy = (y + .15 + .7 * h(x, y, seed + 1)) * cell
            d = math.hypot(u - sx, v - sy)
            if d < best[0][0]:
                best = [(d, (x, y)), best[0]]
            elif d < best[1][0]:
                best[1] = (d, (x, y))
    return best

def glass_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    if x == 0 or y == 0 or x == w - 1 or y == hh - 1:
        return (22, 20, 26)
    if feet(part):
        return (255, 170, 50), (200, 110, 20)
    if part == 'Beak':
        return (255, 196, 64), (140, 90, 10)
    if part == 'Wattle':
        return (214, 30, 50), (110, 10, 20)
    u, v = plane(n, pos)
    if is_top(n):
        v = py
    best = voronoi(u + 7 * n[0] + 3 * n[1], v + 5 * n[2], .95, 3 + PARTS_I.get(part, 0))
    if best[1][0] - best[0][0] < .12:
        return (24, 22, 28)
    c = GLASS[int(h(*best[0][1], 9 + PARTS_I.get(part, 0)) * 5.999)]
    c = mix(shade(c, .78), mix(c, (255, 255, 255), .3), 1 - min(1, best[0][0] / .5))
    return c, shade(c, .5)

PARTS_I = {'Body': 0, 'Head': 2, 'Neck': 4, 'Wing_L': 6, 'Wing_R': 8}

# ------------------------------------------------------------------ Moon
def moon_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(222, 222, 234), wattle=(150, 170, 232), foot=(182, 186, 200))
    if b:
        return b
    u, v = plane(n, pos)
    if part.startswith('Wing') and (is_side(n) or pz < 1.75):
        if stars(u, v, .4, 5, .5):
            return (255, 240, 170), (200, 180, 80)
        return g((32, 42, 96), pos, 6, .05)
    cu, cv = math.floor(u / .7), math.floor(v / .7)
    if h(cu, cv, 21) < .5:
        cx = (cu + .3 + .4 * h(cu, cv, 22)) * .7; cy = (cv + .3 + .4 * h(cu, cv, 23)) * .7
        r = .14 + .14 * h(cu, cv, 24); d = math.hypot(u - cx, v - cy)
        if d < r:
            return g((184, 190, 206), pos, 7, .04), (24, 26, 34)
        if d < r + .07:
            return g((236, 238, 246), pos, 7, .04), (40, 40, 50)
    return g((214, 218, 232), pos, 8, .05), (30, 32, 42)

def moon_props(P):
    P.mat('crescent', (255, 214, 90), .3, .3, 2.2)
    cx, cz = .0, HEAD_TOP + .62
    for k in range(9):
        a = math.radians(100 + k * 20); r = .5
        thick = .14 + .14 * math.sin(math.pi * k / 8)
        P.box(f'crescent {k}', (cx + r * math.cos(a), HEAD_Y + .1, cz + r * math.sin(a) * 1.0), (thick + .06, .16, .2), 'Head', 'crescent', (0, -math.degrees(a), 0))

# ------------------------------------------------------------------ Time Keeper
TEAL = (24, 92, 98)

def clock(py, pz):
    cy, cz = .18, 1.99; dy, dz = py - cy, pz - cz; r = math.hypot(dy, dz)
    if r > .74:
        return None
    if r > .62:
        return (196, 138, 58)
    ang = math.atan2(dz, dy)
    tick = abs(((ang / (2 * math.pi / 12)) % 1) - .5) > .38 and .46 < r < .58
    if tick:
        return (52, 40, 30)
    for a, L, w in ((math.radians(60), .42, .055), (math.radians(-20), .54, .045)):
        t = dy * math.cos(a) + dz * math.sin(a); off = abs(-dy * math.sin(a) + dz * math.cos(a))
        if 0 < t < L and off < w:
            return (52, 40, 30)
    if r < .07:
        return (196, 138, 58)
    return (242, 232, 204)

def tk_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(206, 146, 62), wattle=(30, 120, 124), foot=(196, 138, 58))
    if b:
        return b
    if (part == 'Body' and pz > 2.82) or (part == 'Body' and pz < 1.1):
        return g((196, 138, 58), pos, 6)
    return g(TEAL, pos, 7, .06)

def tk_eye(part):
    if 'Highlight' in part:
        return (255, 222, 120), (200, 150, 40)
    return None

def tk_props(P):
    P.mat('bronze', (196, 138, 58), .3, .7); P.mat('glass', (210, 236, 240), .05, 0, .2); P.mat('sand', (255, 210, 90), .5, 0, 2.5)
    P.mat('gold', (244, 200, 70), .3, .7)
    cx, cy = 0, .75
    for z in (3.0, 3.95):
        P.box(f'hourglass plate {z}', (cx, cy, z), (.84, .64, .1), 'Body', 'bronze')
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.box(f'hourglass post {sx} {sy}', (cx + sx * .34, cy + sy * .24, 3.47), (.08, .08, .86), 'Body', 'bronze')
    P.box('glass top', (cx, cy, 3.72), (.5, .38, .36), 'Body', 'glass')
    P.box('glass bottom', (cx, cy, 3.22), (.5, .38, .36), 'Body', 'glass')
    P.box('glass neck', (cx, cy, 3.47), (.14, .14, .14), 'Body', 'glass')
    P.box('sand bottom', (cx, cy, 3.14), (.4, .3, .18), 'Body', 'sand')
    P.box('sand top', (cx, cy, 3.62), (.3, .22, .1), 'Body', 'sand')
    P.box('sand stream', (cx, cy, 3.4), (.05, .05, .4), 'Body', 'sand')
    P.mat('face', (30, 34, 40), .5); P.mat('tick', (244, 200, 70), .3, .6, .6)
    for s, wing in ((-1, 'Wing_L'), (1, 'Wing_R')):
        x = s * 1.31
        for k, (w, z) in enumerate([(.5, 1.36), (.9, 1.56), (1.12, 1.78), (1.2, 2.0), (1.12, 2.22), (.9, 2.44), (.5, 2.64)]):
            P.box(f'clock frame {s} {k}', (x, .18, z), (.08, w + .14, .24), wing, 'bronze')
            P.box(f'clock face {s} {k}', (x + s * .04, .18, z), (.06, w - .06, .23), wing, 'face')
        for k in range(12):
            a = 2 * math.pi * k / 12
            P.box(f'clock tick {s} {k}', (x + s * .08, .18 + .48 * math.cos(a), 2.0 + .48 * math.sin(a)), (.04, .1, .1), wing, 'tick')
        P.seg(f'hour hand {s}', (x + s * .09, .18, 2.0), (x + s * .09, .18 + .3 * s, 2.2), .04, .08, wing, 'tick')
        P.seg(f'minute hand {s}', (x + s * .09, .18, 2.0), (x + s * .09, .18 - .05, 2.42), .04, .06, wing, 'tick')
    gz = HEAD_TOP + .32
    P.box('gear body', (0, HEAD_Y, gz), (.46, .12, .46), 'Head', 'gold')
    for k in range(8):
        a = 2 * math.pi * k / 8
        P.box(f'gear tooth {k}', (.3 * math.cos(a), HEAD_Y, gz + .3 * math.sin(a)), (.14, .12, .14), 'Head', 'gold', (0, -math.degrees(a), 0))
    P.box('gear stem', (0, HEAD_Y, HEAD_TOP + .04), (.16, .12, .1), 'Head', 'bronze')

# ------------------------------------------------------------------ Mecha
def mecha_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((122, 128, 138), pos, 3)
    if feet(part):
        return g((96, 100, 110), pos, 3)
    b = basic(part, pos, beak=(156, 162, 172), wattle=(220, 40, 52))
    if b:
        return b
    if part == 'Head':
        if (is_front(n) or is_side(n)) and 3.42 < pz < 4.06:
            return (24, 28, 36), (0, 30, 40)
        if is_top(n) or pz > 4.12:
            return g((220, 40, 52), pos, 4)
    u, v = plane(n, pos)
    if abs((u * 1.8) % 1 - .5) > .47 or abs((v * 1.6) % 1 - .5) > .47:
        return (150, 156, 166)  # panel seams
    if (part == 'Body' and is_side(n) and 1.7 < pz < 2.2) or (part.startswith('Wing') and pz < 1.6):
        return g((220, 40, 52), pos, 5, .03)
    return g((240, 242, 246), pos, 6, .03)

def mecha_eye(part):
    if 'Highlight' in part:
        return (220, 255, 255), (150, 255, 255)
    return (40, 220, 255), (20, 200, 255)

def mecha_props(P):
    P.mat('white', (240, 242, 246), .35, .2); P.mat('red', (220, 40, 52), .4, .2); P.mat('steel', (90, 96, 106), .35, .7)
    P.mat('thrust', (255, 150, 40), .3, 0, 5)
    for s, foot in ((-1, 'Foot_L'), (1, 'Foot_R')):
        P.box(f'boot {s}', (s * .62, -.48, .2), (.7, 1.0, .42), foot, 'white')
        P.box(f'boot stripe {s}', (s * .62, -.48, .43), (.72, 1.02, .08), foot, 'red')
        P.box(f'nozzle {s}', (s * .62, .1, .2), (.36, .2, .26), foot, 'steel')
        P.box(f'nozzle glow {s}', (s * .62, .21, .2), (.26, .04, .18), foot, 'thrust')
        P.box(f'missile pod {s}', (s * .96, .35, 3.08), (.42, .76, .36), 'Body', 'white')
        P.box(f'pod cap {s}', (s * .96, -.04, 3.08), (.34, .06, .28), 'Body', 'red')
    P.seg('antenna', (.45, HEAD_Y + .4, HEAD_TOP - .02), (.56, HEAD_Y + .52, HEAD_TOP + .55), .07, .07, 'Head', 'steel')
    P.box('antenna tip', (.57, HEAD_Y + .53, HEAD_TOP + .58), (.13, .13, .13), 'Head', 'red')

# ------------------------------------------------------------------ Kitsune
RED = (214, 34, 44)

def kitsune_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 214, 120), foot=(58, 52, 58))
    if b:
        return b
    if part == 'Head' and is_front(n):
        for s in (-1, 1):
            if abs((px * s) - .45) < .2 and abs(pz - (3.36 - (px * s - .45) * .4)) < .05:
                return RED
        if abs(px) < .05 and 4.1 < pz < 4.3:
            return RED
    if part == 'Head' and is_side(n):
        if abs(pz - (3.3 + (py + 1.4) * .5)) < .06 and py < -.4:
            return RED
    if part.startswith('Wing') and is_side(n):
        for off in (0, .42):
            if abs(pz - (1.5 + off + (py + .8) * .45)) < .07 and -.7 < py < 1.0:
                return RED
    if part == 'Body' and is_side(n) and abs(pz - (1.25 + (py + 1.2) * .3)) < .06:
        return RED
    return g((252, 250, 248), pos, 6, .04)

def kitsune_props(P):
    P.mat('fur', (252, 250, 248), .85); P.mat('fur shade', (234, 230, 228), .85); P.mat('red', RED, .6)
    for s in (-1, 1):
        x = s * .44
        for k, (w, d, hh, mat) in enumerate([(.52, .34, .3, 'fur'), (.4, .3, .3, 'fur'), (.28, .26, .26, 'fur'), (.16, .2, .22, 'red')]):
            P.box(f'ear {s} {k}', (x + s * k * .03, HEAD_Y - .05, HEAD_TOP + .15 + k * .28), (w, d, hh), 'Head', mat)
        P.box(f'ear inner {s}', (x, HEAD_Y - .23, HEAD_TOP + .36), (.26, .04, .5), 'Head', 'red')
    P.seg('tail a', (0, 1.35, 2.2), (0, 1.95, 2.85), .72, .6, 'Body', 'fur')
    P.seg('tail b', (0, 1.9, 2.8), (0, 2.1, 3.5), .62, .54, 'Body', 'fur shade')
    P.seg('tail tip', (0, 2.08, 3.45), (0, 2.16, 3.95), .46, .42, 'Body', 'red')

def kitsune_fx(fx):
    for i, (x, y, z) in enumerate([(-1.55, -.6, 3.4), (1.6, -.2, 3.9), (1.45, 1.2, 2.6)]):
        fx(f'FX_Kitsune_Foxfire_{i}', (x, y, z), (.22, .22, .3), (90, 170, 255), 6, 'Body')

SPECS = {
    'Geode': dict(name='Geode Chicken', paint=geode_paint, props=geode_props, rarity='Legendary', band=7, zone='Crystal Mine', glow=2.2,
                  rough=.6, vfx='Crystal glow PointLight (purple); sparkle glints on the crystals; crystal shards on Hit.'),
    'AirshipCaptain': dict(name='Airship Captain', paint=captain_paint, props=captain_props, rarity='Legendary', band=7,
                           zone='Loyalist Landing', vfx='Propeller spins (looping TweenService rotation); small steam puffs from the pack.'),
    'DragonKnight': dict(name='Dragon Knight', paint=dk_paint, eye=dk_eye, props=dk_props, rarity='Legendary', band=8, zone='Dragon Roost',
                         ortho=7.4, glow=2.5, vfx='Ember eyes glow; ember sparks on Peck; smoke from horns on Celebrate.'),
    'Pharaoh': dict(name='Pharaoh Chicken', paint=pharaoh_paint, props=pharaoh_props, rarity='Legendary', band=7, rough=.6,
                    vfx='Sand swirl particles around the feet while idle; golden glint on the headdress.'),
    'StainedGlass': dict(name='Stained Glass Chicken', paint=glass_paint, rarity='Legendary', band=7, rough=.18, glow=1.8,
                         vfx='Soft inner glow (emission); colored light shafts (Beam) on Celebrate.'),
    'Moon': dict(name='Moon Chicken', paint=moon_paint, props=moon_props, rarity='Legendary', band=7, glow=1.4,
                 vfx='Moon-glow halo (soft PointLight, pale blue); twinkling stars on the wing tips.'),
    'TimeKeeper': dict(name='Time Keeper', paint=tk_paint, eye=tk_eye, props=tk_props, rarity='Mythic', band=9, glow=2.5,
                       vfx='Clock hands rotate (looping tweens on the wing decal or separate hands); falling sand particles in the hourglass; gear spins.'),
    'Mecha': dict(name='Mecha Chicken', paint=mecha_paint, eye=mecha_eye, props=mecha_props, rarity='Mythic', band=9, glow=3,
                  rough=.35, vfx='Thruster flames (ParticleEmitter) under the boots; visor glow pulse; small hover on Celebrate.'),
    'Kitsune': dict(name='Kitsune Spirit', paint=kitsune_paint, props=kitsune_props, fx=kitsune_fx, rarity='Mythic', band=9,
                    ortho=7.2, vfx='Three blue foxfire orbs orbiting slowly (tweened attachments + flame particles); spirit wisps on Walk.'),
}
