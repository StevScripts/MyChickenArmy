"""Batch 7 — round two: Commons, Uncommons and the Snowman."""
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

# ------------------------------------------------------------------ Rooster
def rooster_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(250, 200, 60))
    if b:
        return b
    if part in ('Head', 'Neck') or (part == 'Body' and pz > 2.55 and py < .2):
        c = (214, 76, 40) if field(pos, 3.5, 3) > .5 else (236, 132, 44)
        return g(c, pos, 6, .05)
    if part.startswith('Wing') and pz < 1.55:
        return g((34, 62, 52), pos, 7)
    c = (150, 38, 26) if field(pos, 3, 4) > .4 else (122, 30, 22)
    return g(c, pos, 8, .05)

def rooster_props(P):
    P.mat('comb', (222, 34, 36), .55); P.mat('tail', (30, 58, 50), .3, .2); P.mat('tail sheen', (40, 90, 72), .3, .2)
    for k, (dy, hh) in enumerate([(-.6, .38), (-.3, .56), (0, .66), (.3, .56), (.58, .38)]):
        P.box(f'comb {k}', (0, HEAD_Y + dy, HEAD_TOP + hh / 2), (.3, .32, hh), 'Head', 'comb')
    for x, top, mat in [(0, 4.3, 'tail'), (-.34, 3.9, 'tail sheen'), (.34, 3.9, 'tail sheen'), (-.6, 3.5, 'tail'), (.6, 3.5, 'tail')]:
        P.seg(f'tail a {x}', (x * .8, 1.3, 2.4), (x, 1.95, top), .4, .24, 'Body', mat)
        P.seg(f'tail b {x}', (x, 1.95, top - .05), (x * 1.1, 2.55, top - .6), .3, .2, 'Body', mat)

# ------------------------------------------------------------------ Sheep
WOOL = (242, 232, 204)

def sheep_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((62, 58, 62), pos, 3)
    b = basic(part, pos, wattle=(80, 76, 80))
    if b:
        return b
    if part == 'Head' and not is_top(n) and pz < 4.14:
        return g((66, 60, 64), pos, 6, .05)
    u, v = plane(n, pos)
    bump = (math.floor(u * 4.5) + math.floor(v * 4.5)) % 2
    fu, fv = (u * 4.5) % 1, (v * 4.5) % 1
    edge = min(fu, 1 - fu, fv, 1 - fv) < .14
    return g(shade(WOOL, .9 if edge else (1.0 if bump else .97)), pos, 7, .03)

def sheep_props(P):
    P.mat('wool', WOOL, .95); P.mat('wool shade', (226, 218, 198), .95); P.mat('ear', (66, 60, 64), .8)
    P.box('wool cap', (0, HEAD_Y + .1, HEAD_TOP + .1), (1.6, 1.56, .34), 'Head', 'wool')
    P.box('wool fringe', (0, HEAD_Y - .76, HEAD_TOP - .06), (1.5, .16, .26), 'Head', 'wool shade')
    P.box('wool chest', (0, -1.3, 1.75), (1.6, .16, 1.0), 'Body', 'wool')
    P.box('wool cap top', (0, HEAD_Y + .05, HEAD_TOP + .32), (1.0, 1.0, .16), 'Head', 'wool shade')
    for s in (-1, 1):
        P.box(f'ear {s}', (s * .84, HEAD_Y - .2, 3.95), (.4, .14, .2), 'Head', 'ear', (0, s * 25, 0))
    for k, (x, y, w) in enumerate([(-.55, -.6, .7), (.5, -.3, .8), (-.35, .5, .9), (.45, .85, .7), (0, .1, .8)]):
        P.box(f'wool puff {k}', (x, y, 3.02), (w, w * .9, .28), 'Body', 'wool' if k % 2 else 'wool shade')
    for s, wing in ((-1, 'Wing_L'), (1, 'Wing_R')):
        P.box(f'wing puff {s}', (s * 1.32, .2, 2.2), (.12, 1.2, .9), wing, 'wool')

# ------------------------------------------------------------------ Plushie
FELT = (250, 196, 170)

def plush_paint(part, n, pos, x, y, w, hh):
    px, py, pz = pos
    stitch = (x == 1 or y == 1 or x == w - 2 or y == hh - 2) and w > 5 and hh > 5 and (x + y) % 2 == 0
    if feet(part):
        return (255, 255, 255) if stitch else g((250, 156, 80), pos, 3, .03)
    if part == 'Beak':
        return (255, 255, 255) if stitch else g((250, 160, 80), pos, 4, .03)
    if part == 'Wattle':
        return g((236, 80, 90), pos, 5, .03)
    if part == 'Body' and is_side(n) and px > 0 and .1 < py < .9 and 1.55 < pz < 2.35:
        e = min(py - .1, .9 - py, pz - 1.55, 2.35 - pz)
        return (255, 255, 255) if e < .07 and math.floor((py + pz) * 9) % 2 else g((130, 172, 232), pos, 6, .03)
    if stitch:
        return (255, 255, 255)
    return g(FELT, pos, 7, .04)

def plush_props(P):
    P.mat('button', (92, 58, 46), .4); P.mat('hole', (40, 24, 20), .5); P.mat('tag', (250, 250, 248), .8); P.mat('tag red', (220, 50, 60), .7)
    for s in (-1, 1):
        cx = s * .445
        P.box(f'button {s}', (cx, -1.55, 3.75), (.46, .06, .46), 'Head', 'button')
        for hx in (-.08, .08):
            for hz in (-.08, .08):
                P.box(f'hole {s} {hx} {hz}', (cx + hx, -1.585, 3.75 + hz), (.06, .02, .06), 'Head', 'hole')
    P.box('tag', (.3, 1.5, 2.3), (.3, .04, .22), 'Body', 'tag')
    P.box('tag stripe', (.3, 1.53, 2.3), (.3, .02, .06), 'Body', 'tag red')

# ------------------------------------------------------------------ Mailman
def mail_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(60, 56, 60))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px) < .05:
        return (240, 240, 244)
    if part == 'Body' and pz < 1.12:
        return g((36, 48, 92), pos, 7)
    return g((150, 192, 232), pos, 8, .04)

def mail_props(P):
    P.mat('navy', (36, 48, 92), .6); P.mat('visor', (24, 24, 30), .3); P.mat('badge', (240, 200, 70), .3, .7)
    P.mat('bag', (130, 84, 46), .7); P.mat('bag dark', (100, 62, 34), .7); P.mat('letter', (252, 252, 250), .8)
    P.box('cap', (0, HEAD_Y, HEAD_TOP + .13), (1.5, 1.5, .26), 'Head', 'navy')
    P.box('cap visor', (0, HEAD_Y - .9, HEAD_TOP + .03), (1.1, .4, .06), 'Head', 'visor')
    P.box('cap badge', (0, HEAD_Y - .76, HEAD_TOP + .16), (.26, .05, .16), 'Head', 'badge')
    P.seg('strap', (-.75, -1.26, 2.85), (.75, -1.27, 1.7), .14, .05, 'Body', 'bag dark')
    P.box('satchel', (.86, -1.36, 1.5), (.62, .3, .56), 'Body', 'bag')
    P.box('satchel flap', (.86, -1.52, 1.66), (.64, .04, .28), 'Body', 'bag dark')
    for k, (x, r) in enumerate([(.72, -12), (.9, 6), (1.04, 18)]):
        P.box(f'letter {k}', (x, -1.36, 1.86), (.26, .05, .3), 'Body', 'letter', (0, r, 0))

# ------------------------------------------------------------------ Raincoat
def rain_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(214, 36, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px - .12) < .06 and (pz * 3) % 1 < .3 and pz > 1.3:
        return (110, 70, 30)  # toggles
    if part == 'Body' and is_front(n) and abs(px - .02) < .025:
        return (214, 170, 20)
    return g((255, 212, 40), pos, 7, .04)

def rain_props(P):
    P.mat('hat', (255, 210, 36), .25); P.mat('boot', (220, 34, 40), .25); P.mat('sole', (60, 40, 30), .6)
    P.box('hat crown', (0, HEAD_Y + .05, HEAD_TOP + .17), (1.44, 1.44, .34), 'Head', 'hat')
    P.box('hat brim', (0, HEAD_Y + .1, HEAD_TOP + .03), (1.86, 1.86, .07), 'Head', 'hat')
    P.box('hat back brim', (0, HEAD_Y + 1.05, HEAD_TOP - .08), (1.7, .6, .07), 'Head', 'hat', (-16, 0, 0))
    for s, foot in ((-1, 'Foot_L'), (1, 'Foot_R')):
        P.box(f'boot {s}', (s * .62, -.48, .22), (.72, 1.04, .44), foot, 'boot')
        P.box(f'boot sole {s}', (s * .62, -.48, .03), (.74, 1.06, .06), foot, 'sole')
        P.box(f'boot top {s}', (s * .62, -.13, .62), (.4, .4, .4), f'Leg_{"L" if s < 0 else "R"}', 'boot')

# ------------------------------------------------------------------ Skater
def skater_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Toe') or part.startswith('Foot'):
        return g((214, 36, 44), pos, 3) if pz < .06 else g((246, 246, 246), pos, 3)
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px) < .5 and 1.5 < pz < 2.1:
        return g((250, 210, 60), pos, 7) if abs(pz - 1.8) > .08 else g((236, 80, 60), pos, 7)
    return g((62, 192, 190), pos, 8, .04)

def skater_props(P):
    P.mat('cap', (214, 36, 44), .6); P.mat('deck', (44, 44, 54), .5); P.mat('deck art', (250, 150, 40), .5)
    P.mat('truck', (170, 174, 182), .3, .7); P.mat('wheel', (255, 150, 40), .5)
    P.box('cap', (0, HEAD_Y, HEAD_TOP + .12), (1.5, 1.5, .24), 'Head', 'cap')
    P.box('cap brim', (0, HEAD_Y + .92, HEAD_TOP + .03), (1.0, .44, .06), 'Head', 'cap')
    P.box('deck', (0, 1.6, 2.3), (.9, .08, 2.3), 'Body', 'deck')
    P.box('deck stripe', (0, 1.645, 2.3), (.3, .02, 2.0), 'Body', 'deck art')
    for z in (1.4, 3.2):
        P.box(f'truck {z}', (0, 1.7, z), (.6, .1, .1), 'Body', 'truck')
        for x in (-.32, .32):
            P.box(f'wheel {z} {x}', (x, 1.76, z), (.16, .14, .18), 'Body', 'wheel')

# ------------------------------------------------------------------ Taco
def taco_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(236, 170, 70))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    u, v = plane(n, pos)
    if is_top(n) or pz > 2.55:
        return g((96, 190, 64), pos, 7, .1)  # lettuce
    if dots(u, v, .32, 13, .22, .6):
        return g((226, 52, 44), pos, 8)  # tomato bits
    if dots(u + 5, v, .4, 14, .18, .5):
        return g((250, 176, 40), pos, 9)  # cheese
    return g((132, 76, 40), pos, 10, .12)  # seasoned filling

def taco_props(P):
    P.mat('shell', (236, 186, 86), .7); P.mat('shell dark', (214, 156, 64), .7); P.mat('tomato', (222, 50, 44), .4)
    P.mat('cheese', (250, 170, 40), .5); P.mat('lettuce', (110, 206, 70), .6); P.mat('chili', (220, 30, 30), .3); P.mat('stem', (60, 140, 50), .6)
    for s in (-1, 1):
        P.box(f'shell side {s}', (s * 1.36, .12, 1.95), (.12, 2.56, 1.8), 'Body', 'shell')
        P.box(f'shell curve {s}', (s * 1.2, .12, 1.0), (.3, 2.56, .3), 'Body', 'shell dark', (0, s * 45, 0))
        for k in range(5):
            P.box(f'shell spot {s} {k}', (s * 1.43, -.8 + k * .45, 1.5 + (k % 2) * .6), (.03, .14, .12), 'Body', 'shell dark')
        for k, y in enumerate([-.9, -.4, .1, .6, 1.1]):
            P.box(f'lettuce {s} {k}', (s * 1.22, y, 2.9 + (k % 2) * .08), (.3, .42, .26), 'Body', 'lettuce', (0, s * 15, 0))
        P.box(f'tomato {s}', (s * 1.18, -.15, 3.05), (.24, .24, .2), 'Body', 'tomato')
        P.box(f'cheese {s}', (s * 1.18, .75, 3.0), (.12, .5, .1), 'Body', 'cheese', (25, 0, 0))
    P.box('shell bottom', (0, .12, .96), (2.3, 2.56, .12), 'Body', 'shell')
    P.seg('chili', (.1, HEAD_Y - .2, HEAD_TOP + .08), (.45, HEAD_Y + .2, HEAD_TOP + .12), .18, .18, 'Head', 'chili')
    P.seg('chili tip', (.44, HEAD_Y + .18, HEAD_TOP + .12), (.56, HEAD_Y + .36, HEAD_TOP + .04), .12, .12, 'Head', 'chili')
    P.box('chili stem', (.05, HEAD_Y - .26, HEAD_TOP + .12), (.1, .14, .1), 'Head', 'stem')

# ------------------------------------------------------------------ Painter
SPLATS = [(236, 50, 60), (60, 140, 236), (250, 200, 40), (80, 200, 90), (180, 90, 230)]

def painter_paint(part, n, pos, *a):
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    u, v = plane(n, pos)
    cu, cv = math.floor(u / .5), math.floor(v / .5)
    if h(cu, cv, 77 + len(part)) < .35:
        cx = (cu + .5) * .5; cy = (cv + .5) * .5
        if math.hypot(u - cx, v - cy) < .12 + .08 * h(cu, cv, 78):
            return SPLATS[int(h(cu, cv, 79) * 4.999)]
    return g((246, 244, 236), pos, 7, .03)

def painter_props(P):
    P.mat('beret', (200, 30, 44), .8); P.mat('wood', (196, 150, 96), .7); P.mat('brush', (120, 80, 44), .7)
    for i, c in enumerate(SPLATS):
        P.mat(f'paint {i}', c, .3)
    P.box('beret', (.08, HEAD_Y, HEAD_TOP + .09), (1.58, 1.58, .18), 'Head', 'beret', (0, 10, 0))
    P.box('beret nub', (.1, HEAD_Y, HEAD_TOP + .24), (.14, .14, .12), 'Head', 'beret')
    P.box('palette', (1.38, -.1, 1.95), (.07, .96, .72), 'Wing_R', 'wood')
    P.box('palette b', (1.38, .25, 1.6), (.07, .4, .3), 'Wing_R', 'wood')
    for i, (y, z) in enumerate([(-.42, 2.15), (-.12, 2.2), (.18, 2.12), (-.3, 1.8), (.05, 1.75)]):
        P.box(f'blob {i}', (1.43, y, z), (.04, .16, .14), 'Wing_R', f'paint {i}')
    P.seg('brush', (-.45, HEAD_Y + .62, 3.95), (-.2, HEAD_Y + .78, 4.62), .07, .07, 'Head', 'brush')
    P.box('brush tip', (-.19, HEAD_Y + .79, 4.66), (.1, .1, .12), 'Head', 'paint 1')

# ------------------------------------------------------------------ Sunflower
def sunflower_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((70, 150, 56), pos, 3)
    if part == 'Beak':
        return g((222, 172, 62), pos, 4)
    if part == 'Wattle':
        return g((96, 180, 66), pos, 5)
    if part == 'Head':
        u, v = plane(n, pos)
        return g((116, 72, 40) if (math.floor(u * 9) + math.floor(v * 9)) % 2 else (92, 56, 32), pos, 6, .05)
    if part.startswith('Wing') and is_side(n) and abs(pz - (1.95 + (py - .18) * .3)) < .04:
        return (52, 120, 44)  # leaf vein
    return g((84, 172, 62) if part.startswith('Wing') else (70, 150, 56), pos, 7, .05)

def sunflower_props(P):
    P.mat('petal', (255, 206, 40), .55); P.mat('petal dark', (246, 176, 26), .55)
    cx, cy, cz = 0, -1.06, 3.5
    for k in range(16):
        a = 2 * math.pi * k / 16
        x, z = 1.08 * math.cos(a), 1.08 * math.sin(a)
        P.box(f'petal {k}', (cx + x, cy, cz + z), (.6, .18, .34), 'Head', 'petal' if k % 2 else 'petal dark', (0, -math.degrees(a), 0))
    for k in range(16):
        a = 2 * math.pi * (k + .5) / 16
        P.box(f'petal back {k}', (cx + .82 * math.cos(a), cy + .08, cz + .82 * math.sin(a)), (.5, .14, .3), 'Head', 'petal dark', (0, -math.degrees(a), 0))

# ------------------------------------------------------------------ Snowman
def snowman_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((110, 78, 48), pos, 3)
    if part == 'Beak':
        return g((250, 130, 30), pos, 4)
    if part == 'Wattle':
        return g((40, 40, 44), pos, 5)
    if part == 'Body' and is_front(n) and abs(px) < .1 and any(abs(pz - z) < .1 for z in (1.35, 1.75, 2.15)):
        return (36, 36, 40)  # coal buttons
    c = (248, 250, 254) if field(pos, 2.4, 3) > .42 else (226, 234, 246)
    return g(c, pos, 6, .03)

def snowman_props(P):
    P.mat('hat', (30, 30, 34), .5); P.mat('band', (200, 30, 40), .6); P.mat('scarf', (214, 36, 44), .85)
    P.mat('scarf white', (250, 250, 250), .85); P.mat('twig', (110, 76, 44), .8)
    P.box('hat brim', (0, HEAD_Y, HEAD_TOP + .03), (1.4, 1.4, .06), 'Head', 'hat')
    P.box('hat crown', (0, HEAD_Y, HEAD_TOP + .3), (.96, .96, .5), 'Head', 'hat')
    P.box('hat band', (0, HEAD_Y, HEAD_TOP + .12), (.98, .98, .1), 'Head', 'band')
    for k in range(4):
        P.box(f'scarf ring {k}', (0, -.82, 2.66 + k * .07), (1.32, 1.1, .07), 'Body', 'scarf' if k % 2 == 0 else 'scarf white')
    for k in range(5):
        P.box(f'scarf tail {k}', (.5, -1.3, 2.5 - k * .14), (.3, .08, .14), 'Body', 'scarf' if k % 2 == 0 else 'scarf white')
    for s, wing in ((-1, 'Wing_L'), (1, 'Wing_R')):
        P.seg(f'twig {s}', (s * 1.2, .1, 2.2), (s * 1.95, -.1, 2.75), .09, .09, wing, 'twig')
        P.seg(f'twig b {s}', (s * 1.7, -.04, 2.58), (s * 1.92, -.2, 2.38), .07, .07, wing, 'twig')

SPECS = {
    'Rooster': dict(name='Rooster', paint=rooster_paint, props=rooster_props, rarity='Common', band=1, rough=.6, ortho=7.2,
                    vfx='None required. Optional: crow sound on Celebrate.'),
    'Sheep': dict(name='Sheep Chicken', paint=sheep_paint, props=sheep_props, rarity='Common', band=1, rough=.95,
                  vfx='None required. Optional: baa sound; wool tufts on Hit.'),
    'Plushie': dict(name='Plushie Chicken', paint=plush_paint, props=plush_props, rarity='Common', band=1, rough=.95,
                    vfx='None required. Optional: soft squeak on Hit.'),
    'Mailman': dict(name='Mailman Chicken', paint=mail_paint, props=mail_props, rarity='Common', band=2, zone='Supply Depot',
                    vfx='None required. Optional: a letter flutters out on Hit.'),
    'Raincoat': dict(name='Raincoat Chicken', paint=rain_paint, props=rain_props, rarity='Common', band=2, rough=.3,
                     vfx='Small water-splash puff on Walk steps (optional).'),
    'Skater': dict(name='Skater Chicken', paint=skater_paint, props=skater_props, rarity='Common', band=2, ortho=7.0,
                   vfx='None required. Optional: board-spin trick on Celebrate (tween on the board part).'),
    'Taco': dict(name='Taco Chicken', paint=taco_paint, props=taco_props, rarity='Uncommon', band=3, vfx='None required.'),
    'Painter': dict(name='Painter Chicken', paint=painter_paint, props=painter_props, rarity='Uncommon', band=3,
                    vfx='Paint-splat burst (Confetti tinted) on Celebrate.'),
    'Sunflower': dict(name='Sunflower Chicken', paint=sunflower_paint, props=sunflower_props, rarity='Uncommon', band=3, ortho=7.0,
                      vfx='Petals gently sway (tiny rotation tween on the petal ring) — optional.'),
    'Snowman': dict(name='Snowman Chicken', paint=snowman_paint, props=snowman_props, rarity='Rare', band=4, ortho=7.4,
                    vfx='Light snowfall around the chicken (Star white, rate 2); snow puff on Hit.'),
}
