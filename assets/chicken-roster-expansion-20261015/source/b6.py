"""Batch 6 — special (zero roll weight) chickens: two seasonal limiteds and two earned rewards.
Earn paths for Kingslayer/Ascendant still need an owner decision; the art does not imply them."""
import math
from pal import *

HEAD_Y, HEAD_TOP = -0.794, 4.29

def basic(part, pos, beak=BEAK, wattle=WATTLE, foot=FEET):
    if feet(part):
        return g(foot, pos, 3)
    if part == 'Beak':
        return g(beak, pos, 4)
    if part == 'Wattle':
        return g(wattle, pos, 5)
    return None

# ------------------------------------------------------------------ Gingerbread
def ginger_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    ICING = (252, 250, 246)
    if part.startswith('Toe') or part.startswith('Foot'):
        return g((176, 102, 52), pos, 3)
    if part == 'Beak':
        return g((236, 176, 80), pos, 4)
    if part == 'Wattle':
        return g((220, 40, 50), pos, 5)
    # Icing outline one texel in from every face edge, with a wavy squiggle.
    inset = 1 if not part.startswith('Leg') else 99
    if (x == inset or y == inset or x == w - 1 - inset or y == hh - 1 - inset) and w > 4 and hh > 4:
        return ICING
    if part.startswith('Wing') and pz < 1.5:
        return (220, 40, 50) if math.floor((py + pz) * 4.5) % 2 else ICING  # candy cane tips
    if part == 'Head' and is_front(n) and abs(pz - (3.4 + .5 * px * px)) < .05 and abs(px) < .5:
        return ICING  # icing smile
    return g((182, 108, 56), pos, 6, .06)

def ginger_props(P):
    for i, (c, z) in enumerate([((255, 60, 90), 1.98), ((70, 200, 110), 1.62), ((70, 150, 255), 1.26)]):
        P.mat(f'gumdrop {i}', c, .25)
        P.box(f'gumdrop {i}', (0, -1.29, z), (.34, .14, .3), 'Body', f'gumdrop {i}')
        P.box(f'gumdrop top {i}', (0, -1.31, z + .18), (.2, .12, .1), 'Body', f'gumdrop {i}')

# ------------------------------------------------------------------ Firework
BURSTS = [(255, 210, 70), (255, 90, 190), (70, 230, 255), (140, 255, 120)]

def firework_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 200, 70), wattle=(255, 90, 190), foot=(40, 46, 90))
    if b:
        return b
    u, v = plane(n, pos)
    cell = 1.25; cu, cv = math.floor(u / cell), math.floor(v / cell)
    cx, cy = (cu + .5) * cell, (cv + .5) * cell
    du, dv = u - cx, v - cy; r = math.hypot(du, dv)
    if h(cu, cv, 7 + len(part)) < .75 and r < .56:
        ang = math.atan2(dv, du); ray = abs(((ang / (2 * math.pi) * 8) % 1) - .5) < .2
        c = BURSTS[int(h(cu, cv, 8) * 3.999)]
        if r < .09 or (ray and r > .14):
            return c, c
    if h(math.floor(u * 9), math.floor(v * 9), 33) > .985:
        return (255, 255, 230), (200, 200, 160)
    return g((24, 30, 76), pos, 6, .05)

def firework_props(P):
    P.mat('rocket', (230, 40, 60), .4); P.mat('rocket stripe', (250, 250, 250), .4); P.mat('cone', (250, 200, 70), .3, .5)
    P.mat('fuse', (60, 50, 40), .7); P.mat('spark', (255, 230, 120), .3, 0, 6)
    P.box('rocket body', (0, HEAD_Y, HEAD_TOP + .28), (.42, .42, .56), 'Head', 'rocket')
    P.box('rocket stripe', (0, HEAD_Y, HEAD_TOP + .3), (.44, .44, .1), 'Head', 'rocket stripe')
    P.box('rocket cone', (0, HEAD_Y, HEAD_TOP + .64), (.3, .3, .16), 'Head', 'cone')
    P.box('rocket tip', (0, HEAD_Y, HEAD_TOP + .77), (.16, .16, .1), 'Head', 'cone')
    for s in (-1, 1):
        P.box(f'rocket fin {s}', (s * .26, HEAD_Y, HEAD_TOP + .1), (.14, .3, .2), 'Head', 'cone')
    P.seg('fuse', (.1, HEAD_Y, HEAD_TOP + .5), (.32, HEAD_Y - .05, HEAD_TOP + .72), .05, .05, 'Head', 'fuse')
    P.box('fuse spark', (.34, HEAD_Y - .05, HEAD_TOP + .76), (.1, .1, .1), 'Head', 'spark')

# ------------------------------------------------------------------ Kingslayer
PURPLE, GOLD = (92, 44, 150), (244, 196, 64)

def king_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 196, 60), foot=(60, 40, 80))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((244, 240, 230), pos, 6, .04)
    if (part == 'Body' and (pz > 2.8 or pz < 1.12)) or (part.startswith('Wing') and (pz > 2.62 or pz < 1.36)):
        return g(GOLD, pos, 7)
    u, v = plane(n, pos)
    if part == 'Body' and is_front(n) and abs(px) < .07:
        return g(GOLD, pos, 8)
    return g(PURPLE if math.floor(v * 3.5) % 2 else shade(PURPLE, .85), pos, 9, .04)

def king_props(P):
    P.mat('crown', GOLD, .25, .8); P.mat('gem', (220, 30, 60), .2, 0, 1.2); P.mat('cape', (200, 26, 40), .6)
    P.mat('fur', (250, 248, 244), .9); P.mat('fur spot', (30, 30, 34), .9); P.mat('medal', (250, 210, 70), .25, .8)
    P.mat('ribbon', (40, 80, 200), .6)
    tilt = (0, 14, 0)
    P.box('crown band', (.1, HEAD_Y, HEAD_TOP + .14), (1.3, 1.3, .24), 'Head', 'crown', tilt)
    for k, (x, hh) in enumerate([(-.42, .32), (0, .42), (.42, .14)]):  # the right point is snapped off
        P.box(f'crown point {k}', (x * math.cos(math.radians(14)) + .1, HEAD_Y - .62, HEAD_TOP + .3 + hh / 2 - x * .24), (.22, .1, hh), 'Head', 'crown', tilt)
    P.box('crown gem', (.1, HEAD_Y - .66, HEAD_TOP + .14), (.2, .06, .14), 'Head', 'gem', tilt)
    P.box('crown shard', (.85, HEAD_Y - .2, HEAD_TOP - .1), (.14, .1, .14), 'Head', 'crown', (30, 20, 40))
    P.box('cape', (0, 1.53, 1.92), (2.36, .08, 2.1), 'Body', 'cape')
    P.box('cape collar', (0, .2, 3.02), (2.3, 1.0, .22), 'Body', 'fur')
    for k in range(4):
        P.box(f'fur spot {k}', (-.9 + k * .6, .2 + (.3 if k % 2 else -.3), 3.14), (.1, .1, .04), 'Body', 'fur spot')
    P.box('medal ribbon', (.45, -1.25, 2.3), (.16, .05, .34), 'Body', 'ribbon')
    P.box('medal', (.45, -1.27, 2.05), (.28, .05, .28), 'Body', 'medal')

# ------------------------------------------------------------------ Ascendant
def asc_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 214, 110), wattle=(250, 200, 120), foot=(240, 200, 100))
    if b:
        return b
    if part.startswith('Wing') and pz < 1.55:
        return (255, 214, 90), (200, 150, 40)
    if part == 'Body' and (pz > 2.84 or pz < 1.1):
        return (255, 214, 90), (160, 120, 30)
    f = field(pos, 1.6, 12)
    c = mix((250, 248, 242), (236, 232, 252), f)
    return g(c, pos, 6, .03), (60, 58, 56)

def asc_eye(part):
    if 'Highlight' in part:
        return (255, 240, 180), (255, 200, 80)
    return None

def asc_props(P):
    P.mat('halo', (255, 214, 90), .2, .3, 3)
    def ring(label, center, radius, tilt_x, tilt_y, bone, segs=16, t=.09):
        cx, cy, cz = center; pts = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            x, y, z = radius * math.cos(a), radius * math.sin(a), 0
            y, z = y * math.cos(tilt_x), y * math.sin(tilt_x)
            x, z = x * math.cos(tilt_y) + z * math.sin(tilt_y), -x * math.sin(tilt_y) + z * math.cos(tilt_y)
            pts.append((cx + x, cy + y, cz + z))
        for k in range(segs):
            P.seg(f'{label} {k}', pts[k], pts[(k + 1) % segs], t, t, bone, 'halo')
    ring('head halo', (0, HEAD_Y, HEAD_TOP + .45), .55, 0, 0, 'Head', 12, .1)
    ring('orbit ring a', (0, .1, 2.1), 1.75, math.radians(70), math.radians(18), 'Body', 22, .09)
    ring('orbit ring b', (0, .1, 2.1), 1.85, math.radians(110), math.radians(-24), 'Body', 22, .09)

SPECS = {
    'Gingerbread': dict(name='Gingerbread Chicken', paint=ginger_paint, props=ginger_props, rarity='Epic', band=6, rough=.7,
                        earn='Christmas 2026 limited (zero roll weight, like Pumpkin)',
                        vfx='Snowflake sprinkle on Celebrate; jingle sound.'),
    'Firework': dict(name='Firework Chicken', paint=firework_paint, props=firework_props, rarity='Legendary', band=7, glow=2.5,
                     earn='New Year 2027 limited (zero roll weight)',
                     vfx='Fuse spark particles while idle; firework burst (colored sparks) on Celebrate.'),
    'Kingslayer': dict(name='Kingslayer', paint=king_paint, props=king_props, rarity='Mythic', band=10, glow=1.5,
                       earn='Needs owner decision: beat the Chicken King N times (like Hill Champion)',
                       vfx='Gold glint on the crown; cape flutter is the existing Walk motion.'),
    'Ascendant': dict(name='Ascendant Chicken', paint=asc_paint, eye=asc_eye, props=asc_props, rarity='Mythic', band=10, glow=2.2,
                      ortho=7.6, earn='Needs owner decision: reach Rebirth N',
                      vfx='Halo rings rotate slowly (looping rotation tweens on the ring parts); soft pearl glow; one extra ring per Rebirth (runtime toggle).'),
}
