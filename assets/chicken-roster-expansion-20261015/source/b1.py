"""Batch 1 — thin rarities + chase chickens."""
import math
from pal import *

HEAD_Y, HEAD_TOP = -0.794, 4.29

# ------------------------------------------------------------------ Hatchling
def hatchling_paint(part, n, pos, *a):
    if feet(part):
        return g((248, 150, 34), pos, 3)
    if part == 'Beak':
        return g((250, 158, 40), pos, 4)
    if part == 'Wattle':
        return g((250, 198, 90), pos, 5)
    c = (255, 230, 124) if field(pos, 2.6, 5) > .64 else (255, 238, 150)
    return g(c, pos, 6, .05)

def hatchling_props(P):
    P.mat('shell', (250, 248, 238), .45); P.mat('shell shade', (232, 228, 214), .5)
    P.box('shell cap', (0, HEAD_Y, HEAD_TOP + .14), (1.56, 1.56, .5), 'Head', 'shell')
    P.box('shell dome', (0, HEAD_Y, HEAD_TOP + .45), (1.28, 1.28, .14), 'Head', 'shell')
    P.box('shell top', (0, HEAD_Y, HEAD_TOP + .56), (.86, .86, .1), 'Head', 'shell shade')
    for k in range(6):
        t = -.65 + k * .26; low = k % 2 == 0
        for (x, y, sx, sy) in [(t, HEAD_Y - .76, .26, .06), (t, HEAD_Y + .76, .26, .06), (-.76, HEAD_Y + t, .06, .26), (.76, HEAD_Y + t, .06, .26)]:
            P.box(f'shell tooth {k} {x:.2f} {y:.2f}', (x, y, HEAD_TOP - .2 - (.1 if low else 0)), (sx, sy, .2 + (.2 if low else 0)), 'Head', 'shell')

# ------------------------------------------------------------------ Silkie
def silkie_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((128, 134, 152), pos, 3)
    if part == 'Beak':
        return g((116, 126, 158), pos, 4)
    if part == 'Wattle':
        return g((112, 40, 82), pos, 5)
    if part == 'Head' and is_front(n) and 3.3 < pz < 4.08 and abs(px) < .7:
        return g((82, 88, 126), pos, 6)
    c = (252, 250, 246) if field(pos, 4, 9) > .42 else (232, 230, 226)
    return g(c, pos, 7, .1)

def silkie_props(P):
    P.mat('fluff', (254, 252, 248), .9); P.mat('fluff shade', (236, 234, 230), .9)
    P.box('pom base', (0, HEAD_Y + .12, HEAD_TOP + .2), (1.72, 1.66, .5), 'Head', 'fluff')
    P.box('pom mid', (0, HEAD_Y + .16, HEAD_TOP + .56), (1.4, 1.36, .3), 'Head', 'fluff shade')
    P.box('pom top', (0, HEAD_Y + .2, HEAD_TOP + .8), (.9, .86, .2), 'Head', 'fluff')
    P.box('pom fringe', (0, HEAD_Y - .76, HEAD_TOP + .04), (1.3, .28, .34), 'Head', 'fluff')
    P.box('tail puff', (0, 1.62, 2.7), (1.3, .5, .9), 'Body', 'fluff')
    P.box('tail puff top', (0, 1.7, 3.2), (.9, .4, .3), 'Body', 'fluff shade')
    for s in (-1, 1):
        P.box(f'pom side {s}', (s * .62, HEAD_Y + .05, HEAD_TOP - .02), (.32, 1.0, .42), 'Head', 'fluff shade')
        leg = 'Leg_L' if s < 0 else 'Leg_R'
        P.box(f'leg fluff {s}', (s * .62, -.13, .62), (.5, .5, .36), leg, 'fluff')
        P.box(f'cheek puff {s}', (s * .66, HEAD_Y - .45, 3.1), (.18, .56, .5), 'Head', 'fluff shade')

# ------------------------------------------------------------------ Speckled Hen
def speckled_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((250, 204, 70), pos, 3)
    if part == 'Beak':
        return g((250, 198, 62), pos, 4)
    if part == 'Wattle':
        return g((214, 40, 36), pos, 5)
    u, _ = plane(n, pos)
    k = 4.5
    on = (math.floor((py if is_top(n) else pz) * k) + math.floor(u * k)) % 2
    return g((52, 52, 60) if on else (240, 238, 232), pos, 6, .05)

def speckled_props(P):
    P.mat('comb', (216, 40, 36), .6)
    for k, (dy, dz, hgt) in enumerate([(-.48, .2, .36), (-.16, .3, .52), (.16, .3, .46), (.46, .2, .32)]):
        P.box(f'comb {k}', (0, HEAD_Y + dy, HEAD_TOP + dz - hgt / 2 + .06), (.3, .32, hgt), 'Head', 'comb')

# ------------------------------------------------------------------ Bacon Hair
def bacon_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((250, 200, 60), pos, 3)
    if part == 'Beak':
        return g((250, 160, 50), pos, 4)
    if part == 'Wattle':
        return g(WATTLE, pos, 5)
    if part in ('Head', 'Neck'):
        return g((236, 196, 146), pos, 6, .05)
    if part == 'Body' and pz < 1.16:
        return g((40, 150, 56), pos, 7)
    if part.startswith('Wing') and pz < 1.45:
        return g((236, 196, 146), pos, 8)  # bare "arms" below the sleeves
    return g((64, 194, 74), pos, 9, .05)

def bacon_props(P):
    P.mat('bacon dark', (126, 70, 34), .7); P.mat('bacon light', (182, 116, 64), .7)
    for k in range(7):
        x = -.72 + k * .24
        P.box(f'bacon {k}', (x, HEAD_Y - .02, HEAD_TOP + .1 + (.07 if k % 2 else 0)), (.25, 1.58, .2), 'Head', 'bacon dark' if k % 2 else 'bacon light')
    for s in (-1, 1):
        P.box(f'bacon side {s}', (s * .77, HEAD_Y + .1, HEAD_TOP - .12), (.1, 1.3, .36), 'Head', 'bacon dark')
    P.box('bacon fringe', (0, HEAD_Y - .77, HEAD_TOP - .04), (1.52, .12, .3), 'Head', 'bacon dark')
    P.box('bacon swoop', (-.32, HEAD_Y - .84, HEAD_TOP - .16), (.86, .1, .26), 'Head', 'bacon light', (0, 12, 0))

# ------------------------------------------------------------------ Phoenix
def fire(t):
    if t < .45:
        return mix((255, 236, 110), (255, 150, 34), t / .45)
    return mix((255, 150, 34), (214, 34, 30), (t - .45) / .55)

def phoenix_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((236, 150, 40), pos, 3), (60, 20, 0)
    if part == 'Beak':
        return g((255, 204, 64), pos, 4), (60, 40, 0)
    if part == 'Wattle':
        return g((236, 60, 30), pos, 5), (90, 10, 0)
    u, _ = plane(n, pos)
    t = (py + 1.5) / 3.0 - (pz - 2.0) * .12 + .28
    tongue = .1 * math.sin(u * 7 + pz * 2) + .06 * (h(math.floor(u * 6), math.floor(pz * 6), 3) - .5)
    c = fire(max(0, min(1, t + tongue)))
    return g(c, pos, 6, .06), shade(c, .45)

def phoenix_props(P):
    P.mat('flame yellow', (255, 230, 90), .4, 0, 3); P.mat('flame orange', (255, 140, 30), .4, 0, 2.5)
    P.mat('flame red', (226, 44, 28), .4, 0, 2)
    for x, hgt in [(-.32, .85), (0, 1.2), (.32, .8)]:
        P.seg(f'crest {x}', (x, HEAD_Y + .05, HEAD_TOP - .05), (x * 1.2, HEAD_Y + .45, HEAD_TOP + hgt * .65), .4, .34, 'Head', 'flame red')
        P.seg(f'crest mid {x}', (x * 1.2, HEAD_Y + .4, HEAD_TOP + hgt * .55), (x * 1.3, HEAD_Y + .62, HEAD_TOP + hgt * .9), .28, .24, 'Head', 'flame orange')
        P.seg(f'crest tip {x}', (x * 1.3, HEAD_Y + .58, HEAD_TOP + hgt * .85), (x * 1.35, HEAD_Y + .72, HEAD_TOP + hgt * 1.12), .16, .14, 'Head', 'flame yellow')
    P.seg('tail main', (0, 1.3, 2.3), (0, 2.3, 3.35), .7, .36, 'Body', 'flame red')
    P.seg('tail main tip', (0, 2.2, 3.25), (0, 2.6, 3.95), .32, .2, 'Body', 'flame orange')
    P.seg('tail main flare', (0, 2.5, 3.85), (0, 2.65, 4.3), .16, .12, 'Body', 'flame yellow')
    for s in (-1, 1):
        P.seg(f'tail side {s}', (s * .45, 1.3, 2.0), (s * .78, 2.25, 2.85), .5, .3, 'Body', 'flame orange')
        P.seg(f'tail side tip {s}', (s * .6, 2.18, 2.8), (s * .7, 2.55, 3.3), .2, .16, 'Body', 'flame yellow')

# ------------------------------------------------------------------ Unicorn
PASTEL = [(255, 108, 182), (168, 118, 255), (72, 214, 176), (84, 168, 255), (255, 186, 80)]

def unicorn_paint(part, n, pos, *a):
    if feet(part):
        return g((240, 192, 64), pos, 3)
    if part == 'Beak':
        return g((255, 206, 74), pos, 4)
    if part == 'Wattle':
        return g((255, 150, 196), pos, 5)
    c = (252, 250, 255) if field(pos, 3, 4) > .4 else (240, 236, 252)
    return g(c, pos, 6, .05)

def unicorn_props(P):
    P.mat('gold', (255, 206, 70), .3, .6); P.mat('gold light', (255, 236, 150), .3, .5)
    for i, c in enumerate(PASTEL):
        P.mat(f'pastel {i}', c, .6)
    z = HEAD_TOP
    for k, (s, hgt) in enumerate([(.34, .22), (.29, .2), (.24, .19), (.19, .17), (.14, .15), (.09, .14)]):
        P.box(f'horn {k}', (0, -1.18 - k * .05, z + hgt / 2), (s, s, hgt), 'Head', 'gold' if k % 2 == 0 else 'gold light', (0, 0, k * 12))
        z += hgt
    # Mane: a tall two-tone crest along the head top, flowing down the head back and right side.
    for k in range(5):
        y = HEAD_Y - .55 + k * .3
        P.box(f'mane top {k}', (.12, y, HEAD_TOP + .2), (.5, .32, .44 - k * .02), 'Head', f'pastel {k % 5}')
    for k in range(4):
        P.box(f'mane back {k}', (.12, -.02, HEAD_TOP - .1 - k * .34), (.56, .2, .36), 'Head', f'pastel {(k + 3) % 5}')
    for k in range(4):
        P.box(f'mane lock {k}', (.76, HEAD_Y + .25 - k * .12, HEAD_TOP - .1 - k * .3), (.14, .5, .34), 'Head', f'pastel {(k + 1) % 5}')
    for k in range(5):
        P.box(f'tail {k}', (0, 1.56 + k * .14, 2.6 - k * .3), (.5 - k * .04, .34, .38), 'Body', f'pastel {k % 5}')

def unicorn_fx(fx):
    for i, (x, y, z) in enumerate([(-1.3, -.9, 3.8), (1.2, -1.3, 4.5), (-.4, -1.8, 4.7), (1.4, .9, 3.2), (-1.5, .5, 2.6)]):
        fx(f'FX_Unicorn_Sparkle_{i}', (x, y, z), (.1, .1, .1), (255, 240, 255), 8, 'Head')

# ------------------------------------------------------------------ Kraken
def kraken_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((92, 40, 124), pos, 3)
    if part == 'Beak':
        return g((74, 40, 76), pos, 4)
    if part == 'Wattle':
        return g((96, 44, 132), pos, 5)
    u, v = plane(n, pos)
    if (part == 'Body' and (is_front(n) or n[2] < 0)) or (part.startswith('Wing') and abs(px) < 1.15):
        if dots(u, v, .44, 17, .24, .4):
            return (238, 170, 228)
        return g((174, 112, 204), pos, 6)
    if part.startswith('Wing') and pz < 1.62:
        return g((30, 126, 134), pos, 7)
    c = (110, 50, 152) if field(pos, 2.6, 8) > .4 else (92, 40, 134)
    if part == 'Head':
        c = shade(c, .92)
    return g(c, pos, 8, .06)

def kraken_eye(part):
    if 'Highlight' in part:
        return (150, 255, 255), (60, 220, 230)
    return None

def kraken_props(P):
    P.mat('tentacle', (120, 56, 162), .5); P.mat('tentacle tip', (196, 132, 220), .5); P.mat('sucker', (240, 178, 230), .5)
    for x in (-.45, -.15, .15, .45):
        s = 1 if x > 0 else -1; o = abs(x)
        p0, p1 = (x, -1.72, 2.82), (x + s * o * .25, -1.86, 2.36)
        p2, p3 = (x + s * (o * .5 + .08), -2.04, 2.04), (x + s * (o * .7 + .16), -2.26, 2.12)
        P.seg(f'tentacle {x} a', p0, p1, .22, .2, 'Wattle', 'tentacle')
        P.seg(f'tentacle {x} b', p1, p2, .18, .17, 'Wattle', 'tentacle')
        P.seg(f'tentacle {x} c', p2, p3, .13, .13, 'Wattle', 'tentacle tip')
        P.box(f'sucker {x}', (p1[0], -1.98, 2.38), (.08, .05, .08), 'Wattle', 'sucker')

# ------------------------------------------------------------------ The First Hen
def rune(u, v, cell, seed):
    cu, cv = math.floor(u / cell), math.floor(v / cell)
    if h(cu, cv, seed) > .6:
        return False
    fu, fv = u / cell - cu, v / cell - cv; k = int(h(cu, cv, seed + 1) * 4)
    stroke = .075
    vertical = abs(fu - .5) < stroke and .15 < fv < .85
    if k == 0:
        return vertical or (abs((fv - .55) - (fu - .5)) < stroke and fu > .5 and fv < .9) or (abs((fv - .3) - (fu - .5)) < stroke and fu > .5 and fv < .65)
    if k == 1:
        return vertical or (abs((fv - .5) - (fu - .5)) < stroke and fu > .5 and fv > .5)
    if k == 2:
        return (abs(fu - fv) < stroke or abs(fu + fv - 1) < stroke) and .15 < fv < .85
    return vertical or (abs(fv - .3) < stroke and fu > .5) or (abs(fv - .62) < stroke and fu < .5)

def stone(pos, base=(184, 156, 116), n=(0, 1, 0)):
    u, v = plane(n, pos)
    if is_top(n):
        v = pos[1]
    row = math.floor(v / .62); vv = (v / .62) % 1
    uu = ((u + (.45 if row % 2 else 0)) / .9) % 1
    if vv < .13 or uu < .09:
        return g(shade(base, .7), pos, 15, .04)
    c = shade(base, .93 + .14 * h(row, math.floor((u + (.45 if row % 2 else 0)) / .9), 5))
    return g(c, pos, 15, .04)

def firsthen_paint(part, n, pos, *a):
    px, py, pz = pos
    if part == 'Beak':
        return g((160, 132, 96), pos, 3, .05)
    if feet(part) or part == 'Wattle':
        return g((150, 124, 90), pos, 4, .05)
    u, v = plane(n, pos)
    if not is_top(n) and part in ('Body', 'Wing_L', 'Wing_R', 'Head') and rune(u + 3, v, .82, 9 if part == 'Body' else 21):
        return (255, 212, 90), (255, 170, 40)
    return stone(pos, n=n)

def firsthen_eye(part):
    if 'Highlight' in part:
        return (255, 226, 130), (255, 180, 40)
    return None

def firsthen_props(P):
    P.mat('egg', (222, 200, 160), .85); P.mat('egg shade', (200, 178, 140), .85); P.mat('rune', (255, 210, 84), .4, 0, 3)
    P.mat('moss', (90, 132, 64), .9)
    z = 2.9
    for k, (w, d, hgt) in enumerate([(.7, .64, .2), (1.0, .9, .3), (1.08, .98, .38), (1.0, .9, .32), (.78, .7, .26), (.5, .46, .2)]):
        P.box(f'egg {k}', (0, .5, z + hgt / 2), (w, d, hgt), 'Body', 'egg' if k % 2 else 'egg shade'); z += hgt
    P.box('egg rune band', (0, .5, 3.6), (1.1, 1.0, .08), 'Body', 'rune')
    P.box('egg rune mark', (0, .0, 3.82), (.16, .04, .36), 'Body', 'rune')
    P.box('moss back', (-.7, 1.1, 2.97), (.4, .34, .1), 'Body', 'moss')

# ------------------------------------------------------------------ Rift Walker
def rift_paint(part, n, pos, *a):
    px, py, pz = pos
    u, v = plane(n, pos)
    if abs(px) < .075 and not is_side(n):
        c = (255, 70, 210) if math.floor(pz * 6 + py * 3) % 2 else (90, 240, 255)
        return c, c
    if px < 0:
        if feet(part):
            return g(FEET, pos, 3)
        if part == 'Beak':
            return g(BEAK, pos, 4)
        if part == 'Wattle':
            return g(WATTLE, pos, 5)
        return g((246, 246, 242), pos, 6, .05)
    if stars(u * 1.0, v, .3, 23 + PARTS_INDEX.get(part, 0), .45):
        c = (255, 255, 255) if h(math.floor(u / .3), math.floor(v / .3), 2) > .4 else (140, 230, 255)
        return c, shade(c, .8)
    f = field(pos, 2.2, 5)
    c = mix((22, 12, 44), (76, 30, 120), f * f)
    return g(c, pos, 7, .06), shade(c, .25)

PARTS_INDEX = {'Body': 0, 'Head': 3, 'Neck': 5, 'Wing_R': 7, 'Beak': 9, 'Wattle': 11}

def rift_eye(part):
    if part == 'Eye_Highlight_R':
        return (150, 245, 255), (90, 220, 255)
    return None

def rift_props(P):
    P.mat('rift magenta', (255, 70, 210), .3, 0, 4); P.mat('rift cyan', (90, 240, 255), .3, 0, 4)
    for k, (y, z, s) in enumerate([(-1.0, HEAD_TOP + .22, .16), (-.55, HEAD_TOP + .36, .12), (-.2, HEAD_TOP + .18, .1)]):
        P.box(f'shard head {k}', (.04 * (-1) ** k, y, z), (s, s, s), 'Head', 'rift magenta' if k % 2 else 'rift cyan', (20 * k, 35, 10))
    for k, (y, z, s) in enumerate([(1.75, 2.7, .16), (2.0, 2.3, .12), (1.62, 1.95, .1)]):
        P.box(f'shard back {k}', (.03 * (-1) ** k, y, z), (s, s, s), 'Body', 'rift cyan' if k % 2 else 'rift magenta', (30, 20 * k, 40))

# ------------------------------------------------------------------ Supernova
def nova(t):
    if t < .32:
        return mix((255, 255, 246), (255, 246, 170), t / .32)
    if t < .58:
        return mix((255, 246, 170), (255, 186, 50), (t - .32) / .26)
    if t < .82:
        return mix((255, 186, 50), (250, 96, 32), (t - .58) / .24)
    return mix((250, 96, 32), (196, 36, 44), (t - .82) / .18)

def supernova_paint(part, n, pos, *a):
    px, py, pz = pos
    d = math.sqrt(px * px * .8 + (py + 1.0) ** 2 * .55 + (pz - 2.2) ** 2 * .7)
    t = max(0, min(1, d / 2.3 + .04 * (h(math.floor(px * 6), math.floor(py * 6), math.floor(pz * 6)) - .5)))
    if part == 'Beak':
        t = min(t, .4)
    c = nova(t)
    return g(c, pos, 6, .04), shade(c, .55)

def supernova_props(P):
    P.mat('ray', (255, 238, 120), .3, 0, 4); P.mat('ray hot', (255, 252, 230), .3, 0, 5)
    for x, hgt, mat in [(-.5, .55, 'ray'), (0, .8, 'ray hot'), (.5, .55, 'ray')]:
        P.seg(f'head ray {x}', (x, HEAD_Y, HEAD_TOP - .05), (x * 1.6, HEAD_Y + .05, HEAD_TOP + hgt), .24, .24, 'Head', mat)
    for x, y, z in [(0, 2.15, 2.95), (-.75, 1.95, 2.55), (.75, 1.95, 2.55), (0, 2.05, 1.9)]:
        P.seg(f'back ray {x} {z}', (x * .7, 1.4, z - .45), (x, y, z), .26, .26, 'Body', 'ray')
    for s in (-1, 1):
        P.seg(f'wing ray {s}', (s * 1.22, .2, 2.0), (s * 1.85, .25, 2.4), .24, .24, 'Wing_L' if s < 0 else 'Wing_R', 'ray')

SPECS = {
    'Hatchling': dict(name='Hatchling', paint=hatchling_paint, props=hatchling_props, rough=.85, rarity='Common', band=1,
                      vfx='None required. Optional: shell crumbs on Hit.'),
    'Silkie': dict(name='Silkie', paint=silkie_paint, props=silkie_props, rough=.9, rarity='Common', band=1, vfx='None required.'),
    'SpeckledHen': dict(name='Speckled Hen', paint=speckled_paint, props=speckled_props, rough=.75, rarity='Common', band=1,
                        vfx='None required.'),
    'BaconHair': dict(name='Bacon Hair Chick', paint=bacon_paint, props=bacon_props, rough=.75, rarity='Common', band=1,
                      vfx='None required.'),
    'Phoenix': dict(name='Phoenix Chicken', paint=phoenix_paint, props=phoenix_props, rough=.55, glow=1.6, ortho=7.6,
                    rarity='Legendary', band=8,
                    vfx='Fire trail (ParticleEmitter, short lifetime) behind the tail while walking; flame burst + rising embers on Defeat (rebirth flare).'),
    'Unicorn': dict(name='Unicorn Chicken', paint=unicorn_paint, props=unicorn_props, fx=unicorn_fx, rough=.6, ortho=7.2,
                    rarity='Legendary', band=8, vfx='Pastel sparkle trail while walking; star burst on Celebrate; horn soft glow.'),
    'Kraken': dict(name='Kraken Chicken', paint=kraken_paint, eye=kraken_eye, props=kraken_props, rough=.45, glow=2,
                   rarity='Legendary', band=8, zone='Pirate Cove', vfx='Ink-splash puff on Hit; dripping water droplets while idle.'),
    'FirstHen': dict(name='The First Hen', paint=firsthen_paint, eye=firsthen_eye, props=firsthen_props, rough=.9, glow=2.5,
                     ortho=7.0, rarity='Mythic', band=10, vfx='Rune pulse (emission tween up/down, 2 s loop); dust motes rising; golden ring on Celebrate.'),
    'RiftWalker': dict(name='Rift Walker', paint=rift_paint, eye=rift_eye, props=rift_props, rough=.5, glow=2.5,
                       rarity='Mythic', band=10, vfx='Portal swirl particles along the seam; shards orbit slowly (tween); void wisps on Walk.'),
    'Supernova': dict(name='Supernova Chicken', paint=supernova_paint, props=supernova_props, rough=.4, glow=1.4, ortho=7.4,
                      rarity='Mythic', band=10, vfx='Pulsing PointLight (Brightness tween, reverses); radial light burst on Celebrate; heat shimmer.'),
}
