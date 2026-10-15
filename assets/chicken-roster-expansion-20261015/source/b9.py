"""Batch 9 — round two: Legendary and Mythic finishers."""
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

# ------------------------------------------------------------------ Jade
def jade_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    if part == 'Beak':
        return g((244, 196, 64), pos, 4, .04)
    if part == 'Wattle':
        return g((236, 186, 56), pos, 5, .04)
    if (x == 0 or y == 0 or x == w - 1 or y == hh - 1) and w > 4 and hh > 4 and not feet(part):
        return (244, 196, 64)  # gold filigree edge
    if feet(part):
        return g((236, 186, 56), pos, 3, .04)
    f = field(pos, 1.8, 31); vein = abs(field(pos, 2.6, 32) - .5) < .02
    c = mix((20, 100, 58), (70, 168, 110), f * f)
    if vein:
        c = mix(c, (170, 230, 190), .5)
    return g(c, pos, 6, .02)

def jade_props(P):
    P.mat('gold', (244, 196, 64), .25, .8); P.mat('gem', (60, 200, 130), .1, 0, .8)
    P.box('crest base', (0, HEAD_Y - .2, HEAD_TOP + .06), (.6, .5, .12), 'Head', 'gold')
    P.box('crest mid', (0, HEAD_Y - .2, HEAD_TOP + .22), (.36, .3, .2), 'Head', 'gold')
    P.box('crest gem', (0, HEAD_Y - .37, HEAD_TOP + .22), (.18, .04, .14), 'Head', 'gem')
    P.box('crest tip', (0, HEAD_Y - .2, HEAD_TOP + .4), (.14, .14, .16), 'Head', 'gold')
    for s in (-1, 1):
        P.box(f'wing medallion {s}', (s * 1.29, .2, 2.0), (.04, .4, .4), f'Wing_{"L" if s < 0 else "R"}', 'gold')
        P.box(f'wing gem {s}', (s * 1.32, .2, 2.0), (.03, .2, .2), f'Wing_{"L" if s < 0 else "R"}', 'gem')

# ------------------------------------------------------------------ Griffin
TAWNY = (226, 156, 56)

def griffin_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(242, 188, 52), wattle=(200, 140, 60), foot=(242, 200, 62))
    if b:
        return b
    if part == 'Head':
        if pz > 4.0 or is_top(n):
            return g((248, 240, 220), pos, 6, .03)
        return g((214, 146, 50), pos, 6, .05)
    if part.startswith('Wing'):
        u, v = plane(n, pos)
        return g((150, 96, 46) if math.floor(v * 4.5) % 2 else (176, 120, 60), pos, 7, .05)
    return g(TAWNY if field(pos, 3, 4) > .4 else shade(TAWNY, .92), pos, 8, .04)

def griffin_props(P):
    P.mat('beak hook', (236, 176, 44), .4); P.mat('mane', (150, 92, 44), .9); P.mat('mane dark', (124, 74, 34), .9)
    P.mat('tail', TAWNY, .8); P.mat('tuft', (110, 66, 30), .9); P.mat('feather', (246, 240, 226), .8); P.mat('feather dark', (120, 76, 36), .8)
    P.box('beak hook', (0, -2.12, 2.78), (.5, .2, .26), 'Beak', 'beak hook')
    for k, (x, z, w, hh) in enumerate([(-.55, 2.55, .5, .6), (0, 2.45, .6, .8), (.55, 2.55, .5, .6), (-.3, 2.0, .4, .5), (.3, 2.0, .4, .5), (0, 1.75, .36, .4)]):
        P.box(f'mane bib {k}', (x, -1.3, z), (w, .16, hh), 'Body', 'mane' if k % 2 else 'mane dark', (0, (k - 2) * 6, 0))
    for s in (-1, 1):
        P.box(f'mane side {s}', (s * .95, -.95, 2.7), (.3, .6, .6), 'Body', 'mane dark')
    P.seg('tail a', (0, 1.4, 1.9), (0, 1.95, 2.4), .2, .2, 'Body', 'tail')
    P.seg('tail b', (0, 1.95, 2.4), (0, 2.1, 3.3), .18, .18, 'Body', 'tail')
    P.box('tail tuft', (0, 2.12, 3.45), (.36, .36, .4), 'Body', 'tuft')
    for s in (-1, 1):
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        for k in range(5):
            P.box(f'flight feather {s} {k}', (s * 1.18, -.6 + k * .4, 1.1 - (k % 2) * .08), (.12, .3, .4), wing, 'feather' if k % 2 else 'feather dark')

# ------------------------------------------------------------------ Valkyrie
def valk_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(150, 156, 168))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and (is_front(n) or is_top(n)) and pz > 1.5:
        u, v = plane(n, pos)
        if abs(px) < .04 or abs((pz * 2.5) % 1 - .5) > .46:
            return (130, 136, 150)
        return g((196, 202, 214), pos, 7, .04)
    if part == 'Body' and pz < 1.5:
        u, _ = plane(n, pos)
        return g((52, 92, 182) if math.floor(u * 4.5) % 2 else (40, 72, 150), pos, 8)
    return g((52, 92, 182), pos, 9, .05)

def valk_props(P):
    P.mat('silver', (200, 206, 218), .25, .8); P.mat('feather', (250, 250, 250), .7); P.mat('braid', (240, 200, 92), .7)
    P.mat('braid band', (200, 150, 60), .6); P.mat('shaft', (170, 176, 188), .3, .8); P.mat('blade', (110, 200, 255), .2, 0, 4)
    P.box('helmet', (0, HEAD_Y, HEAD_TOP + .14), (1.54, 1.54, .3), 'Head', 'silver')
    P.box('helmet top', (0, HEAD_Y, HEAD_TOP + .34), (1.06, 1.06, .14), 'Head', 'silver')
    P.box('helmet brow', (0, HEAD_Y - .78, HEAD_TOP - .04), (1.56, .1, .14), 'Head', 'silver')
    for s in (-1, 1):
        for k, (dy, dz, w) in enumerate([(-.1, .15, .8), (.12, .42, .72), (.32, .68, .6), (.5, .92, .44)]):
            P.box(f'helmet wing {s} {k}', (s * (.86 + k * .1), HEAD_Y + dy, HEAD_TOP + dz), (.1, w, .26), 'Head', 'feather', (0, s * -18, 0))
    pts = [(.62, HEAD_Y + .5, 4.0), (.92, HEAD_Y + .55, 3.3), (.98, HEAD_Y + .35, 2.55)]
    for k in range(2):
        P.seg(f'braid {k}', pts[k], pts[k + 1], .24, .24, 'Head', 'braid')
    for k, (x, y, z) in enumerate([(.78, HEAD_Y + .52, 3.65), (.96, HEAD_Y + .46, 2.9)]):
        P.box(f'braid band {k}', (x, y, z), (.28, .28, .08), 'Head', 'braid band')
    P.box('braid tip', (.98, HEAD_Y + .33, 2.45), (.16, .16, .2), 'Head', 'braid')
    P.seg('spear shaft', (1.44, .55, .55), (1.44, -.35, 3.95), .1, .1, 'Wing_R', 'shaft')
    P.seg('spear blade', (1.44, -.36, 3.95), (1.44, -.46, 4.45), .08, .22, 'Wing_R', 'blade')

# ------------------------------------------------------------------ Eclipse
def eclipse_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    e = min(x, y, w - 1 - x, hh - 1 - y)
    if e == 0:
        return (255, 176, 56), (255, 150, 30)
    if e == 1 and w > 4 and hh > 4:
        return (120, 46, 14), (90, 30, 6)
    f = field(pos, 2.2, 3)
    return g(mix((10, 8, 12), (26, 18, 22), f), pos, 6, .03)

def eclipse_eye(part):
    if 'Highlight' in part:
        return (230, 40, 40), (200, 20, 20)
    return (6, 4, 8)

def eclipse_props(P):
    P.mat('flare', (255, 170, 50), .3, 0, 4); P.mat('flare hot', (255, 200, 90), .3, 0, 4)
    for k, (a, b, w, mat) in enumerate([((-.7, -.8, 4.29), (-.95, -.9, 4.75), .14, 'flare'),
                                        ((.7, -.2, 4.29), (1.05, -.1, 4.6), .12, 'flare hot'),
                                        ((1.08, 1.3, 2.9), (1.5, 1.7, 3.3), .16, 'flare'),
                                        ((-1.08, 1.0, 1.1), (-1.45, 1.3, .8), .12, 'flare hot'),
                                        ((0, 1.46, 2.9), (0, 2.0, 3.4), .14, 'flare')]):
        P.seg(f'flare {k}', a, b, w * .6, w * .6, 'Head' if k < 2 else 'Body', mat)

# ------------------------------------------------------------------ Forest Guardian
def bark(pos, n, base=(84, 62, 40)):
    u, _ = plane(n, pos)
    rib = math.floor(u * 9 + .3 * math.sin(pos[2] * 3)) % 4
    return g(shade(base, (1.0, .86, .94, .8)[rib]), pos, 9, .05)

def forest_paint(part, n, pos, *a):
    px, py, pz = pos
    if part == 'Beak':
        return g((156, 116, 74), pos, 4)
    if part == 'Wattle':
        return g((96, 156, 64), pos, 5)
    if feet(part):
        return bark(pos, n, (92, 62, 38))
    if is_top(n) or field(pos, 2.0, 19) > .55:
        c = (82, 136, 52) if field(pos, 4, 20) > .45 else (60, 104, 40)
        return g(c, pos, 6, .06)
    return bark(pos, n)

def forest_eye(part):
    if 'Highlight' in part:
        return (150, 255, 140), (90, 240, 90)
    return None

def forest_props(P):
    P.mat('branch', (100, 70, 42), .8); P.mat('leaf', (84, 170, 60), .7); P.mat('leaf light', (130, 210, 80), .7)
    P.mat('cap', (130, 255, 120), .3, 0, 3); P.mat('stem', (230, 226, 210), .7); P.mat('vine', (70, 140, 52), .7)
    for s in (-1, 1):
        base = (s * .45, HEAD_Y + .1, HEAD_TOP - .02)
        mid = (s * .8, HEAD_Y + .25, HEAD_TOP + .75)
        P.seg(f'antler {s}', base, mid, .2, .2, 'Head', 'branch')
        P.seg(f'antler tip {s}', mid, (s * .9, HEAD_Y + .4, HEAD_TOP + 1.3), .15, .15, 'Head', 'branch')
        P.seg(f'antler fork {s}', (s * .72, HEAD_Y + .22, HEAD_TOP + .6), (s * 1.15, HEAD_Y + .1, HEAD_TOP + .95), .13, .13, 'Head', 'branch')
        P.seg(f'antler fork b {s}', (s * .85, HEAD_Y + .3, HEAD_TOP + 1.0), (s * .6, HEAD_Y + .45, HEAD_TOP + 1.3), .1, .1, 'Head', 'branch')
        P.box(f'leaf a {s}', (s * .92, HEAD_Y + .42, HEAD_TOP + 1.36), (.3, .12, .22), 'Head', 'leaf', (0, s * 20, 0))
        P.box(f'leaf b {s}', (s * 1.18, HEAD_Y + .08, HEAD_TOP + 1.0), (.26, .12, .2), 'Head', 'leaf light', (0, s * -25, 0))
        P.seg(f'antler vine {s}', (s * 1.15, HEAD_Y + .1, HEAD_TOP + .95), (s * 1.2, HEAD_Y + .1, HEAD_TOP + .45), .05, .05, 'Head', 'vine')
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        P.seg(f'vine {s}', (s * 1.29, -.3, 1.3), (s * 1.31, -.36, .8), .06, .06, wing, 'vine')
        P.box(f'vine leaf {s}', (s * 1.32, -.36, .82), (.06, .16, .12), wing, 'leaf')
    for s in (-1, 1):
        P.box(f'wing shroom stem {s}', (s * 1.3, .3, 1.7), (.06, .08, .1), f'Wing_{"L" if s < 0 else "R"}', 'stem')
        P.box(f'wing shroom cap {s}', (s * 1.33, .3, 1.8), (.06, .24, .1), f'Wing_{"L" if s < 0 else "R"}', 'cap')
    for k, (x, y, z, bone) in enumerate([(.45, HEAD_Y + .4, HEAD_TOP + .05, 'Head'), (-.6, .7, 2.95, 'Body'), (.55, 1.0, 2.95, 'Body'), (-.2, .2, 2.95, 'Body')]):
        P.box(f'shroom stem {k}', (x, y, z + .04), (.08, .08, .12), bone, 'stem')
        P.box(f'shroom cap {k}', (x, y, z + .14), (.22, .22, .08), bone, 'cap')

SPECS = {
    'Jade': dict(name='Jade Chicken', paint=jade_paint, props=jade_props, rarity='Legendary', band=7, rough=.2,
                 vfx='Soft green glint (Glitter, rate 1.5) sliding over the body; gold sparkle on Celebrate.'),
    'Griffin': dict(name='Griffin Chicken', paint=griffin_paint, props=griffin_props, rarity='Legendary', band=8, ortho=7.0,
                    vfx='Feather burst (white/brown) on Celebrate; screech sound.'),
    'Valkyrie': dict(name='Valkyrie Chicken', paint=valk_paint, props=valk_props, rarity='Legendary', band=8, glow=3, ortho=7.4,
                     vfx='Spear tip glow pulse (tween) + blue Spark trail on Peck; feather Glitter on Celebrate.'),
    'Eclipse': dict(name='Eclipse Chicken', paint=eclipse_paint, eye=eclipse_eye, props=eclipse_props, rarity='Mythic', band=9, glow=3,
                    vfx='Corona glow pulse (emission tween); slow orbiting flare wisps (Ember, 2 orbit anchors); dark aura shell (Smoke, deep red).'),
    'ForestGuardian': dict(name='Forest Guardian', paint=forest_paint, eye=forest_eye, props=forest_props, rarity='Mythic', band=9, glow=2.5,
                           ortho=7.4, vfx='Mushroom glow pulse; drifting leaf/firefly motes (Glitter green, rate 3); leaf burst on Celebrate.'),
}
