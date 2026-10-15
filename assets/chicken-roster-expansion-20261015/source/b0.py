"""Batch 0 — Halloween: Pumpkin (remake of the existing catalog ID), Witch, Animatronic,
Zombie Hunter, Mummy, Vampire. Original designs; no third-party characters."""
import math
from pal import *

HEAD_Y, HEAD_TOP = -0.794, 4.29

# ------------------------------------------------------------------ Pumpkin
def pumpkin_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    GLOW, RIM = ((255, 214, 80), (255, 150, 24)), (112, 46, 8)
    if feet(part):
        return g((150, 84, 36), pos, 3)
    if part == 'Beak':
        return g((222, 104, 20), pos, 4)
    if part == 'Wattle':
        return g((196, 78, 14), pos, 5)
    # Carved jagged grin on the chest, lit from inside, with a dark cut rim.
    if part == 'Body' and is_front(n) and abs(px) < .86:
        curve = 1.55 + .32 * (px / .86) ** 2; d = abs(pz - curve)
        tooth = math.floor((px + .86) / .29) % 2 == 0 and pz > curve - .02 and abs(px) < .7
        if d < .15 and not tooth:
            return GLOW
        if d < .21 and not (tooth and pz > curve):
            return RIM
    # Triangle cheeks carved into the head sides.
    if part == 'Head' and is_side(n):
        cy, top, bot = -1.0, 3.55, 2.98
        if bot < pz < top:
            half = (pz - bot) * .55
            if abs(py - cy) < half - .05:
                return GLOW
            if abs(py - cy) < half + .05 or pz < bot + .06:
                return RIM
    u, _ = plane(n, pos)
    if is_top(n):
        return g((236, 128, 26), pos, 8, .08)
    rib = (u * 2.35 + .5) % 1
    if rib < .09:
        return g((176, 74, 10), pos, 6, .05)
    c = mix((224, 108, 16), (255, 160, 42), math.sin(math.pi * (rib - .09) / .91) ** .7)
    return g(c, pos, 7, .05)

def pumpkin_props(P):
    P.mat('stem', (104, 116, 42), .8); P.mat('leaf', (78, 158, 52), .7); P.mat('vine', (58, 120, 40), .7)
    P.box('stem', (0, HEAD_Y, HEAD_TOP + .2), (.28, .28, .44), 'Head', 'stem', (0, 10, 0))
    P.box('stem cap', (.05, HEAD_Y, HEAD_TOP + .44), (.22, .3, .14), 'Head', 'stem', (0, 22, 0))
    P.box('leaf', (.36, HEAD_Y + .1, HEAD_TOP + .12), (.56, .36, .06), 'Head', 'leaf', (0, -16, 24))
    P.box('vine 1', (-.3, HEAD_Y - .2, HEAD_TOP + .06), (.36, .08, .08), 'Head', 'vine', (0, 0, 30))
    P.box('vine 2', (-.5, HEAD_Y - .05, HEAD_TOP + .1), (.08, .26, .08), 'Head', 'vine', (0, 0, 10))

# ------------------------------------------------------------------ Witch
def witch_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    if feet(part):
        return g((54, 36, 74), pos, 3)
    if part == 'Beak':
        return g((250, 190, 52), pos, 4)
    if part == 'Wattle':
        return g((74, 178, 82), pos, 5)
    if part in ('Head', 'Neck'):
        return g((96, 60, 156), pos, 6, .08)
    u, v = plane(n, pos)
    if part == 'Body' and pz < 1.2:
        return g((206, 158, 52), pos, 8)  # gold cloak hem
    if stars(u, v, .78, 11 + (1 if part.startswith('Wing') else 0), .55):
        return (178, 138, 240) if h(math.floor(u / .78), math.floor(v / .78), 3) > .3 else (244, 204, 84)
    return g((62, 38, 108), pos, 9, .06)

def witch_props(P):
    P.mat('hat', (82, 48, 138), .75); P.mat('band', (40, 22, 72), .7); P.mat('gold', (236, 182, 44), .35, .6)
    P.mat('stick', (122, 80, 40), .8); P.mat('straw', (218, 172, 82), .85); P.mat('tie', (150, 52, 40), .7)
    P.box('brim', (0, HEAD_Y, HEAD_TOP + .05), (1.86, 1.82, .1), 'Head', 'hat')
    P.box('band', (0, HEAD_Y, HEAD_TOP + .19), (1.08, 1.08, .18), 'Head', 'band')
    P.box('buckle', (0, HEAD_Y - .56, HEAD_TOP + .19), (.36, .06, .26), 'Head', 'gold')
    P.box('buckle hole', (0, HEAD_Y - .6, HEAD_TOP + .19), (.18, .04, .12), 'Head', 'band')
    P.stack('cone', (0, HEAD_Y, HEAD_TOP + .28), [(1.0, 1.0, .34), (.8, .8, .3), (.6, .6, .28), (.42, .42, .26), (.28, .28, .22)],
            'Head', 'hat', lean=(.05, .07))
    P.box('tip', (.32, HEAD_Y + .42, HEAD_TOP + 1.72), (.2, .34, .18), 'Head', 'hat', (0, 0, 20))
    P.seg('broom stick', (1.44, .3, .9), (1.44, -.45, 3.25), .15, .15, 'Wing_R', 'stick')
    P.seg('broom straw', (1.44, .55, .2), (1.44, .3, .95), .5, .44, 'Wing_R', 'straw')
    P.seg('broom tie', (1.44, .33, .84), (1.44, .28, .98), .54, .48, 'Wing_R', 'tie')

def witch_fx(fx):
    for i, (x, y, z) in enumerate([(-.9, -1.4, 3.9), (1.0, -1.1, 4.6), (-1.3, -.2, 2.9), (.6, -1.6, 2.5)]):
        fx(f'FX_Witch_Sparkle_{i}', (x, y, z), (.12, .12, .12), (120, 255, 150), 6, 'Head')

# ------------------------------------------------------------------ Animatronic
TEAL, CREAM, STEEL = (66, 138, 130), (224, 206, 158), (156, 160, 166)

def screw(u, v, corners, r=.06):
    return any(abs(u - cu) < r and abs(v - cv) < r for cu, cv in corners)

def worn(c, pos):
    if field(pos, 2.6, 21) > .82:
        c = shade(c, .86)
    return g(c, pos, 12, .07)

def animatronic_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    SEAM = (34, 44, 44)
    if part.startswith('Leg'):
        return worn(STEEL if math.floor(pz * 5) % 3 else (100, 104, 112), pos)
    if feet(part):
        return worn((116, 120, 128), pos)
    if part == 'Beak':
        if abs(pz - 3.06) < .05:
            return (36, 28, 24)
        return worn((204, 176, 116), pos)
    if part == 'Wattle':
        return worn((180, 154, 100), pos)
    if part == 'Neck':
        return worn((52, 52, 58), pos)
    if part == 'Body' and is_front(n):
        if abs(px) > .9 or pz < 1.12 or pz > 2.8:
            return worn(TEAL, pos)
        if abs(px) > .84 or pz < 1.18 or pz > 2.74:
            return SEAM
        if screw(px, pz, [(-.72, 1.32), (.72, 1.32), (-.72, 2.6), (.72, 2.6)], .07):
            return (70, 66, 60)
        return worn(CREAM, pos)
    u, v = plane(n, pos)
    if part == 'Body' and is_side(n):
        if abs(pz - 2.0) < .035 or abs(py - .3) < .03:
            return SEAM
        if screw(py, pz, [(-.95, 1.2), (-.95, 2.75), (1.25, 1.2), (1.25, 2.75), (.2, 1.85), (.42, 2.15)], .06):
            return SEAM
    if part == 'Head' and is_side(n) and abs(pz - 3.3) < .03:
        return SEAM
    if part.startswith('Wing') and is_side(n):
        if screw(py, pz, [(-.68, 1.4), (1.05, 1.4), (-.68, 2.58), (1.05, 2.58)], .06) or abs(pz - 1.95) < .03:
            return SEAM
    return worn(TEAL, pos)

def animatronic_eye(part):
    if part == 'Eye_R':
        return (210, 22, 22), (255, 30, 20)
    if part == 'Eye_Highlight_R':
        return (255, 190, 170), (255, 120, 100)
    return None

def animatronic_props(P):
    P.mat('red wire', (214, 36, 36), .5); P.mat('blue wire', (40, 90, 226), .5); P.mat('hinge', (84, 86, 92), .35, .7)
    P.mat('yellow wire', (238, 198, 40), .5)
    for side in (-1, 1):
        P.seg(f'neck wire red {side}', (side * .42, -1.27, 2.86), (side * .52, -1.31, 2.3), .1, .08, 'Body', 'red wire')
        P.seg(f'neck wire blue {side}', (side * .6, -1.27, 2.86), (side * .68, -1.3, 2.42), .1, .08, 'Body', 'blue wire')
        P.box(f'jaw hinge {side}', (side * .75, -1.58, 3.06), (.08, .22, .22), 'Beak', 'hinge')
        leg = f'Leg_{"L" if side < 0 else "R"}'
        P.seg(f'hip wire a {side}', (side * .56, -.05, 1.05), (side * .8, -.28, .62), .08, .08, leg, 'red wire' if side < 0 else 'yellow wire')
        P.seg(f'hip wire b {side}', (side * .8, -.28, .62), (side * .72, -.05, .4), .08, .08, leg, 'red wire' if side < 0 else 'yellow wire')
    P.seg('chest wire a', (.5, -1.25, 1.14), (.86, -1.32, .9), .08, .08, 'Body', 'blue wire')
    P.seg('chest wire b', (.86, -1.32, .9), (.98, -1.2, .7), .08, .08, 'Body', 'blue wire')

# ------------------------------------------------------------------ Zombie Hunter
JACKET, FUR = (98, 62, 38), (230, 212, 176)

def hunter_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((54, 60, 78), pos, 3)
    if feet(part):
        return g((96, 84, 72), pos, 4) if pz < .07 else g((46, 38, 32), pos, 4)
    if part == 'Beak':
        return g((250, 162, 58), pos, 5)
    if part == 'Wattle':
        return g(WATTLE, pos, 5)
    if part == 'Head':
        return g((236, 206, 160), pos, 6, .06)
    if part == 'Neck' or (part == 'Body' and pz > 2.62 and py < .1):
        return g(FUR, pos, 7, .16)
    if part == 'Body' and is_front(n):
        if abs(px) < .95 and pz > 1.15:
            return g((40, 42, 46), pos, 8, .1)
    if part.startswith('Wing') and abs(pz - 1.55) < .05:
        return (72, 44, 28)
    if part == 'Body' and pz < 1.12:
        return g((70, 44, 28), pos, 9)
    return g(JACKET, pos, 10, .09)

def hunter_props(P):
    P.mat('hair', (150, 98, 46), .8); P.mat('hair dark', (116, 72, 32), .8); P.mat('vest', (88, 90, 64), .75)
    P.mat('strap', (120, 86, 52), .7); P.mat('lamp', (60, 62, 66), .4, .6); P.mat('lens', (255, 244, 196), .3, 0, 4)
    P.box('hair cap', (0, HEAD_Y - .08, HEAD_TOP + .07), (1.46, 1.34, .16), 'Head', 'hair')
    P.box('hair back', (0, HEAD_Y + .62, 3.95), (1.46, .14, .7), 'Head', 'hair dark')
    P.box('fringe', (.2, -1.56, 4.08), (1.0, .1, .38), 'Head', 'hair', (0, -14, 0))
    P.box('fringe sweep', (.56, -1.6, 3.9), (.42, .1, .32), 'Head', 'hair dark', (0, -34, 0))
    P.box('side hair', (.72, HEAD_Y - .3, 3.95), (.08, .7, .6), 'Head', 'hair')
    for x in (-.55, .55):
        P.box(f'strap {x}', (x, -1.26, 2.3), (.18, .06, 1.1), 'Body', 'strap')
    for x in (-.52, 0, .52):
        P.box(f'pouch {x}', (x, -1.32, 1.5), (.42, .2, .4), 'Body', 'vest')
        P.box(f'pouch flap {x}', (x, -1.43, 1.66), (.44, .04, .12), 'Body', 'strap')
    P.box('flashlight', (-.55, -1.38, 2.5), (.22, .24, .22), 'Body', 'lamp')
    P.box('flashlight lens', (-.55, -1.51, 2.5), (.17, .04, .17), 'Body', 'lens')

# ------------------------------------------------------------------ Mummy
def mummy_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    u, _ = plane(n, pos)
    t = (py if is_top(n) else pz) + .16 * u + (.07 if part.startswith('Wing') else 0)
    band = math.floor(t / .34); f = (t / .34) % 1
    if f < .3:
        return g((168, 152, 120), pos, 3)
    c = [(236, 228, 204), (216, 206, 178), (244, 238, 220)][int(h(band, 7, 1) * 2.999)]
    if field(pos, 1.6, 31) > .86:
        c = mix(c, (196, 180, 140), .4)
    if part == 'Beak':
        c = mix(c, (238, 212, 150), .45)
    return g(c, pos, 4, .05)

def mummy_eye(part):
    if part == 'Eye_L':
        return (14, 30, 16), (0, 0, 0)
    if part == 'Eye_Highlight_L':
        return (150, 255, 140), (90, 255, 90)
    return (226, 216, 190)

def mummy_props(P):
    P.mat('wrap', (230, 222, 196), .9); P.mat('wrap dark', (204, 192, 160), .9)
    P.box('eye wrap', (.42, -1.545, 3.78), (.66, .05, .2), 'Head', 'wrap', (0, -14, 0))
    P.box('loose end 1', (.74, -.55, 3.7), (.06, .24, .8), 'Head', 'wrap dark')
    P.box('loose end 2', (.82, -.48, 3.12), (.06, .22, .46), 'Head', 'wrap', (0, -24, 0))
    P.box('wing loose end', (-1.32, .7, 1.25), (.06, .2, .5), 'Wing_L', 'wrap dark', (0, 16, 0))

def mummy_fx(fx):
    fx('FX_Mummy_EyeGlow', (-.54, -1.6, 3.86), (.1, .06, .1), (120, 255, 120), 8, 'Head')

# ------------------------------------------------------------------ Vampire
def vampire_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    if feet(part):
        return g((62, 62, 70), pos, 3)
    if part == 'Beak':
        return g((246, 186, 58), pos, 4)
    if part == 'Wattle':
        return g((168, 18, 40), pos, 5)
    if part == 'Head':
        peak = 4.0 + .26 * abs(px) / .7
        if is_top(n) or (is_side(n) and pz > 3.98) or (is_back(n) and pz > 3.2) or (is_front(n) and pz > peak):
            return g((30, 26, 38), pos, 6, .1)
    if part == 'Body' and is_front(n) and abs(px) < .26 and 1.15 < pz < 2.2:
        return g((154, 16, 36), pos, 7)  # red cravat line under the medallion
    return g((228, 228, 234), pos, 8, .05)

def vampire_eye(part):
    if part in ('Eye_L', 'Eye_R'):
        return (176, 14, 30), (90, 0, 8)
    return (255, 196, 196)

def vampire_props(P):
    P.mat('cape', (24, 22, 30), .6); P.mat('lining', (176, 16, 38), .5); P.mat('fang', (252, 252, 248), .3)
    P.mat('gold', (232, 180, 48), .3, .7); P.mat('gem', (210, 20, 40), .2, 0, 1.5)
    for side in (-1, 1):
        wing = 'Wing_L' if side < 0 else 'Wing_R'
        P.box(f'fang {side}', (side * .3, -2.02, 2.73), (.12, .12, .2), 'Beak', 'fang')
        P.box(f'cape wing {side}', (side * 1.35, .22, 1.95), (.07, 2.24, 1.82), wing, 'cape')
        P.box(f'cape lining {side}', (side * 1.3, .22, 1.97), (.04, 2.14, 1.7), wing, 'lining')
        for k in range(4):
            P.box(f'cape scallop {side} {k}', (side * 1.35, -.6 + k * .56, .98), (.07, .3, .16), wing, 'cape')
        P.box(f'collar {side}', (side * .46, .05, 3.28), (.72, .08, .86), 'Body', 'cape', (0, 0, side * -18))
        P.box(f'collar lining {side}', (side * .45, .0, 3.27), (.66, .04, .78), 'Body', 'lining', (0, 0, side * -18))
    P.box('cape back', (0, 1.53, 1.98), (2.42, .08, 2.12), 'Body', 'cape')
    P.box('medallion', (0, -1.26, 1.96), (.3, .06, .3), 'Body', 'gold')
    P.box('medallion gem', (0, -1.3, 1.96), (.14, .04, .14), 'Body', 'gem')

SPECS = {
    'Pumpkin': dict(name='Pumpkin Chicken', paint=pumpkin_paint, props=pumpkin_props, rough=.62, glow=2.4,
                    vfx='Warm flickering PointLight inside the carved grin and cheeks; optional ember wisps on Celebrate.'),
    'Witch': dict(name='Witch Chicken', paint=witch_paint, props=witch_props, ortho=7.4, rough=.75,
                  vfx='Green cauldron sparkles burst on Celebrate; slow drifting star motes around the hat while idle.'),
    'Animatronic': dict(name='Animatronic Chicken', paint=animatronic_paint, eye=animatronic_eye, props=animatronic_props,
                        rough=.55, metal=.15, glow=3,
                        vfx='Right eye flickers (emission on/off tween, random interval); tiny spark on Hit from the neck wires.'),
    'ZombieHunter': dict(name='Zombie Hunter', paint=hunter_paint, props=hunter_props, rough=.7,
                         vfx='Flashlight SpotLight beam from the chest lamp, aimed forward.'),
    'Mummy': dict(name='Mummy Chicken', paint=mummy_paint, eye=mummy_eye, props=mummy_props, fx=mummy_fx, rough=.9, glow=3,
                  vfx='Green eye glow (PointLight); dust puff when walking and on Defeat.'),
    'Vampire': dict(name='Vampire Chicken', paint=vampire_paint, eye=vampire_eye, props=vampire_props, rough=.6, glow=1.5,
                    vfx='Small bat swarm (3–5 billboard bats) on Celebrate; faint red eye glow.'),
}

for _id, _r, _b in [('Pumpkin', 'Epic', 6), ('Witch', 'Legendary', 7), ('Animatronic', 'Epic', 6),
                    ('ZombieHunter', 'Rare', 5), ('Mummy', 'Rare', 4), ('Vampire', 'Epic', 6)]:
    SPECS[_id].update(rarity=_r, band=_b)
SPECS['Pumpkin']['earn'] = 'Halloween 2026 limited (existing catalog ID)'
