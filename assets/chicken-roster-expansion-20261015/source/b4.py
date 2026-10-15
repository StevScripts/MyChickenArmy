"""Batch 4 — Common/Uncommon farm, food and hobby chickens."""
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

# ------------------------------------------------------------------ Scarecrow
def scarecrow_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(170, 128, 66))
    if b:
        return b
    u, v = plane(n, pos)
    if part == 'Body' and is_front(n) and -.9 < px < -.2 and 1.25 < pz < 1.9:
        if abs(px + .9) < .06 or abs(px + .2) < .06 or abs(pz - 1.25) < .06 or abs(pz - 1.9) < .06:
            return (70, 50, 36)
        return g((150, 96, 70), pos, 6)  # patch
    if part.startswith('Wing') and is_side(n) and .1 < py < .8 and 1.6 < pz < 2.3:
        if abs(py - .1) < .06 or abs(py - .8) < .06 or abs(pz - 1.6) < .06 or abs(pz - 2.3) < .06:
            return (70, 50, 36)
        return g((118, 138, 88), pos, 7)
    if part == 'Head' and is_front(n) and abs(pz - 3.42) < .05 and abs(px) < .6 and math.floor(px * 9) % 2:
        return (70, 50, 36)  # stitched smile line under the eyes
    weave = (math.floor(u * 9) + math.floor(v * 9)) % 2
    return g(shade((198, 162, 106), .92 if weave else 1.0), pos, 8, .05)

def scarecrow_props(P):
    P.mat('straw', (230, 194, 96), .85); P.mat('straw dark', (196, 156, 66), .85); P.mat('band', (122, 80, 42), .8)
    P.box('hat brim', (0, HEAD_Y - .05, HEAD_TOP + .04), (2.1, 2.1, .08), 'Head', 'straw', (4, -5, 0))
    P.box('hat crown', (0, HEAD_Y, HEAD_TOP + .26), (1.2, 1.2, .38), 'Head', 'straw dark')
    P.box('hat band', (0, HEAD_Y, HEAD_TOP + .14), (1.24, 1.24, .1), 'Head', 'band')
    for s, wing in ((-1, 'Wing_L'), (1, 'Wing_R')):
        for k, (y, r) in enumerate([(-.6, -20), (-.2, 10), (.25, -8), (.7, 18)]):
            P.box(f'wing straw {s} {k}', (s * 1.18, y, 1.1), (.08, .1, .36), wing, 'straw' if k % 2 else 'straw dark', (r, 0, 0))
    for k, (x, r) in enumerate([(-.6, 25), (-.25, -10), (.3, 12), (.62, -22)]):
        P.box(f'neck straw {k}', (x, -1.24, 2.95), (.1, .08, .34), 'Body', 'straw', (0, r, 0))

# ------------------------------------------------------------------ Pajama
def pajama_paint(part, n, pos, *a):
    b = basic(part, pos, foot=(250, 182, 204))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    u, v = plane(n, pos)
    if stars(u, v, .48, 31, .55):
        return (255, 222, 90)
    return g((152, 198, 242), pos, 7, .04)

def pajama_props(P):
    P.mat('cap', (132, 182, 236), .8); P.mat('pom', (252, 252, 250), .9); P.mat('lid', WHITE_HEAD, .7)
    P.mat('slipper', (250, 182, 204), .95); P.mat('slipper dark', (232, 150, 178), .95)
    for s in (-1, 1):
        P.box(f'eyelid {s}', (s * .445, -1.54, 3.88), (.48, .05, .24), 'Head', 'lid')
    P.box('cap band', (0, HEAD_Y, HEAD_TOP + .08), (1.52, 1.52, .2), 'Head', 'cap')
    P.seg('cap a', (0, HEAD_Y, HEAD_TOP + .1), (.12, HEAD_Y + .15, HEAD_TOP + .62), 1.0, 1.0, 'Head', 'cap')
    P.seg('cap b', (.1, HEAD_Y + .15, HEAD_TOP + .58), (.58, HEAD_Y + .3, HEAD_TOP + .8), .58, .58, 'Head', 'cap')
    P.seg('cap c', (.56, HEAD_Y + .3, HEAD_TOP + .8), (.98, HEAD_Y + .3, HEAD_TOP + .52), .34, .34, 'Head', 'cap')
    P.box('cap pom', (1.04, HEAD_Y + .3, HEAD_TOP + .42), (.32, .32, .32), 'Head', 'pom')
    for s, foot in ((-1, 'Foot_L'), (1, 'Foot_R')):
        P.box(f'slipper {s}', (s * .62, -.52, .17), (.76, 1.02, .34), foot, 'slipper')
        P.box(f'slipper cuff {s}', (s * .62, -.08, .34), (.78, .2, .12), foot, 'slipper dark')
        P.box(f'slipper pom {s}', (s * .62, -1.06, .3), (.2, .1, .18), foot, 'pom')

# ------------------------------------------------------------------ Lumberjack
def lumber_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((62, 92, 150), pos, 3)
    b = basic(part, pos, foot=(102, 66, 36))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((168, 112, 64), pos, 6, .05)
    u, v = plane(n, pos)
    if is_top(n):
        v = py
    a1, a2 = math.floor(u * 4.2) % 2, math.floor(v * 4.2) % 2
    c = (34, 28, 30) if a1 and a2 else (136, 22, 28) if a1 or a2 else (204, 34, 40)
    return g(c, pos, 7, .05)

def lumber_props(P):
    P.mat('beanie', (112, 116, 124), .9); P.mat('beanie fold', (88, 92, 100), .9); P.mat('beard', (110, 66, 34), .85)
    P.box('beanie', (0, HEAD_Y, HEAD_TOP + .14), (1.52, 1.52, .38), 'Head', 'beanie')
    P.box('beanie top', (0, HEAD_Y, HEAD_TOP + .4), (1.1, 1.1, .14), 'Head', 'beanie')
    P.box('beanie fold', (0, HEAD_Y, HEAD_TOP - .05), (1.56, 1.56, .2), 'Head', 'beanie fold')
    P.box('beard main', (0, -1.86, 2.62), (1.2, .3, .5), 'Head', 'beard')
    P.box('beard low', (0, -1.84, 2.3), (.8, .26, .3), 'Head', 'beard')
    for s in (-1, 1):
        P.box(f'sideburn {s}', (s * .66, -1.35, 2.95), (.12, .4, .5), 'Head', 'beard')

# ------------------------------------------------------------------ Party
CONFETTI = [(255, 70, 120), (60, 170, 255), (255, 210, 50), (90, 220, 110), (180, 100, 255)]

def party_paint(part, n, pos, *a):
    b = basic(part, pos)
    if b:
        return b
    u, v = plane(n, pos)
    cu, cv = math.floor(u / .26), math.floor(v / .26)
    if h(cu, cv, 41 + len(part)) < .3:
        fu, fv = (u / .26) % 1, (v / .26) % 1
        if .25 < fu < .75 and .25 < fv < .75:
            return CONFETTI[int(h(cu, cv, 42) * 4.999)]
    return g((250, 250, 248), pos, 6, .03)

def party_props(P):
    P.mat('pink', (255, 110, 170), .6); P.mat('blue', (70, 170, 255), .6); P.mat('pom', (255, 216, 60), .7)
    P.mat('horn', (255, 90, 120), .5); P.mat('horn end', (60, 170, 255), .5)
    z = HEAD_TOP
    for k, (w, hh) in enumerate([(.86, .26), (.66, .26), (.48, .26), (.3, .22)]):
        P.box(f'hat {k}', (.12 + k * .02, HEAD_Y - .05, z + hh / 2), (w, w, hh), 'Head', 'pink' if k % 2 == 0 else 'blue')
        z += hh
    P.box('hat pom', (.2, HEAD_Y - .05, z + .12), (.28, .28, .26), 'Head', 'pom')
    P.seg('party horn', (.1, -2.12, 3.08), (.45, -2.85, 3.0), .12, .12, 'Beak', 'horn')
    P.box('horn bell', (.47, -2.9, 3.0), (.26, .12, .26), 'Beak', 'horn end')

# ------------------------------------------------------------------ Cow
def cow_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((44, 42, 46), pos, 3)
    if part == 'Beak':
        if is_front(n) and abs(abs(px) - .3) < .08 and abs(pz - 3.15) < .08:
            return (120, 60, 70)
        return g((242, 170, 180), pos, 4)
    if part == 'Wattle':
        return g((242, 170, 180), pos, 5)
    if field(pos, 1.5, 77) > .56:
        return g((32, 30, 34), pos, 6, .04)
    return g((248, 248, 246), pos, 7, .03)

def cow_props(P):
    P.mat('horn', (240, 230, 200), .6); P.mat('ear', (248, 248, 246), .8); P.mat('ear in', (242, 170, 180), .8)
    P.mat('collar', (200, 40, 44), .7); P.mat('bell', (220, 172, 60), .3, .7)
    for s in (-1, 1):
        P.seg(f'horn {s}', (s * .5, HEAD_Y + .05, HEAD_TOP - .02), (s * .72, HEAD_Y + .05, HEAD_TOP + .4), .18, .18, 'Head', 'horn')
        P.box(f'ear {s}', (s * .86, HEAD_Y + .05, 4.02), (.32, .14, .2), 'Head', 'ear', (0, s * -15, 0))
        P.box(f'ear inner {s}', (s * .88, HEAD_Y - .03, 4.02), (.24, .04, .14), 'Head', 'ear in', (0, s * -15, 0))
    P.box('collar', (0, -.82, 2.76), (1.3, 1.1, .16), 'Body', 'collar')
    P.box('bell', (.5, -1.34, 2.42), (.3, .24, .34), 'Body', 'bell')

# ------------------------------------------------------------------ Piggy
def piggy_paint(part, n, pos, *a):
    b = basic(part, pos, beak=(244, 146, 168), wattle=(236, 132, 156), foot=(204, 112, 134))
    if b:
        return b
    c = (250, 172, 184) if field(pos, 2.4, 3) > .4 else (244, 160, 174)
    return g(c, pos, 6, .04)

def piggy_props(P):
    P.mat('snout', (236, 128, 152), .6); P.mat('nostril', (150, 60, 84), .6); P.mat('ear', (244, 150, 170), .7)
    P.box('snout', (0, -2.24, 3.1), (.9, .14, .58), 'Beak', 'snout')
    for s in (-1, 1):
        P.box(f'nostril {s}', (s * .2, -2.32, 3.1), (.16, .04, .22), 'Beak', 'nostril')
        P.box(f'ear {s}', (s * .5, HEAD_Y - .3, HEAD_TOP + .1), (.44, .12, .36), 'Head', 'ear', (-38, 0, s * 15))
    pts = [(0, 1.46, 2.35), (.06, 1.66, 2.5), (.22, 1.76, 2.38), (.2, 1.68, 2.2), (.08, 1.62, 2.28)]
    for k in range(len(pts) - 1):
        P.seg(f'tail {k}', pts[k], pts[k + 1], .11, .11, 'Body', 'snout')

# ------------------------------------------------------------------ Sushi
def sushi_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 196, 90), wattle=(250, 170, 170), foot=(250, 176, 170))
    if b:
        return b
    if part in ('Body',) and 1.5 < pz < 2.05 and not is_top(n):
        return g((30, 54, 38), pos, 6, .06)
    if part.startswith('Wing') and 1.55 < pz < 2.0:
        return g((30, 54, 38), pos, 6, .06)
    u, v = plane(n, pos)
    rice = h(math.floor(u * 9), math.floor(v * 9), 51 + len(part))
    return g((252, 252, 248) if rice > .3 else (230, 230, 222), pos, 7, .03)

def sushi_props(P):
    P.mat('salmon', (250, 132, 80), .35); P.mat('fat', (255, 222, 200), .4); P.mat('wasabi', (130, 190, 70), .7)
    P.box('salmon', (0, .25, 3.12), (2.0, 2.1, .4), 'Body', 'salmon')
    for k in range(5):
        P.box(f'fat stripe {k}', (0, -.55 + k * .4, 3.33), (2.02, .1, .04), 'Body', 'fat', (0, 0, 18))
    P.box('wasabi', (.25, HEAD_Y + .1, HEAD_TOP + .1), (.42, .4, .2), 'Head', 'wasabi')
    P.box('wasabi top', (.28, HEAD_Y + .12, HEAD_TOP + .24), (.24, .24, .1), 'Head', 'wasabi')

# ------------------------------------------------------------------ Donut
SPRINKLES = [(255, 255, 255), (255, 214, 60), (70, 170, 255), (90, 210, 110), (190, 110, 255)]

def donut_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((204, 140, 74), pos, 3)
    if part == 'Beak':
        return g((222, 160, 84), pos, 4)
    if part == 'Wattle':
        return g((255, 140, 190), pos, 5)
    u, v = plane(n, pos)
    edge = 2.05 + .22 * math.sin(u * 5.5) + (.18 if h(math.floor(u * 4), 0, 9) > .7 else 0) * -1
    frosted = part in ('Head', 'Neck') or is_top(n) or pz > edge
    if not frosted:
        return g((214, 148, 78) if field(pos, 3, 2) > .45 else (230, 168, 92), pos, 6, .05)
    cu, cv = math.floor(u / .22), math.floor((py if is_top(n) else v) / .22)
    if h(cu, cv, 61 + len(part)) < .22:
        return SPRINKLES[int(h(cu, cv, 62) * 4.999)]
    return g((255, 140, 190), pos, 7, .04)

# ------------------------------------------------------------------ Popcorn
def popcorn_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(250, 214, 110))
    if b:
        return b
    u, v = plane(n, pos)
    if part in ('Body', 'Wing_L', 'Wing_R') and pz < 1.72 and not is_top(n):
        return g((222, 38, 42) if math.floor(u * 3.2) % 2 else (250, 250, 250), pos, 6, .03)
    f = field(pos, 4.5, 81)
    c = (252, 248, 232) if f > .45 else (250, 222, 120) if f < .3 else (240, 232, 206)
    if h(math.floor(u * 9), math.floor(v * 9), 82) > .88:
        c = shade(c, .88)
    return g(c, pos, 7, .04)

def popcorn_props(P):
    P.mat('kernel', (252, 248, 232), .8); P.mat('butter', (250, 214, 100), .7)
    for k, (x, y, z, s) in enumerate([(-.3, HEAD_Y - .2, HEAD_TOP + .1, .3), (.25, HEAD_Y + .1, HEAD_TOP + .12, .34),
                                      (.0, HEAD_Y + .3, HEAD_TOP + .28, .26), (.4, HEAD_Y - .45, HEAD_TOP + .08, .22)]):
        P.box(f'pop head {k}', (x, y, z), (s, s * .9, s * .8), 'Head', 'kernel' if k % 2 == 0 else 'butter', (k * 17, k * 23, k * 11))
    for k, (x, y) in enumerate([(-.5, .6), (.4, .9), (0, .2)]):
        P.box(f'pop back {k}', (x, y, 3.04), (.3, .28, .24), 'Body', 'kernel' if k % 2 else 'butter', (k * 20, k * 15, 30))

# ------------------------------------------------------------------ Gamer
def rgb(t):
    t = t % 1
    stops = [(255, 50, 120), (255, 170, 40), (60, 230, 120), (50, 170, 255), (180, 80, 255), (255, 50, 120)]
    i = int(t * 5); f = t * 5 - i
    return mix(stops[i], stops[i + 1], f)

def gamer_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((50, 56, 70), pos, 3)
    b = basic(part, pos, foot=(240, 240, 242))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part.startswith('Wing') and pz < 1.42:
        c = rgb((py + .9) / 2.2)
        return c, shade(c, .8)
    if part == 'Body' and is_front(n) and abs(abs(px) - .25) < .05 and pz > 2.0:
        return (236, 236, 240)  # hoodie strings
    if part == 'Body' and is_front(n) and abs(px) < .6 and 1.15 < pz < 1.6:
        return g((48, 50, 58), pos, 7)  # front pocket
    return g((64, 66, 76), pos, 8, .05)

def gamer_props(P):
    P.mat('band', (28, 28, 32), .5); P.mat('cup', (36, 36, 42), .5); P.mat('ring a', (255, 60, 200), .3, 0, 4)
    P.mat('ring b', (60, 220, 255), .3, 0, 4)
    P.box('headband', (0, HEAD_Y, HEAD_TOP + .07), (1.64, .22, .14), 'Head', 'band')
    for s, ring in ((-1, 'ring a'), (1, 'ring b')):
        P.box(f'band side {s}', (s * .8, HEAD_Y, 4.06), (.12, .22, .5), 'Head', 'band')
        P.box(f'ear cup {s}', (s * .84, HEAD_Y, 3.66), (.22, .64, .64), 'Head', 'cup')
        P.box(f'cup ring {s}', (s * .96, HEAD_Y, 3.66), (.04, .5, .5), 'Head', ring)
    P.seg('mic boom', (.9, HEAD_Y - .2, 3.5), (.5, -1.7, 3.15), .07, .07, 'Head', 'band')
    P.box('mic', (.48, -1.74, 3.14), (.16, .16, .16), 'Head', 'cup')

# ------------------------------------------------------------------ Frog
def frog_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(196, 222, 84), wattle=(240, 120, 150), foot=(72, 160, 62))
    if b:
        return b
    if part == 'Body' and is_front(n):
        return g((206, 232, 116), pos, 6, .04)
    u, v = plane(n, pos)
    if dots(u, v, .46, 91 + len(part), .24, .55):
        return g((52, 132, 52), pos, 7)
    return g((96, 192, 72), pos, 8, .05)

def frog_props(P):
    P.mat('bump', (96, 192, 72), .5); P.mat('pad', (60, 150, 60), .6); P.mat('pad light', (90, 180, 70), .6)
    P.mat('petal', (255, 150, 200), .6); P.mat('center', (255, 220, 70), .6)
    for s in (-1, 1):
        P.box(f'eye bump {s}', (s * .44, HEAD_Y - .42, HEAD_TOP + .14), (.46, .44, .3), 'Head', 'bump')
    P.box('lily pad', (.05, HEAD_Y + .35, HEAD_TOP + .04), (1.1, .9, .06), 'Head', 'pad', (0, 0, 12))
    P.box('lily pad b', (-.15, HEAD_Y + .45, HEAD_TOP + .05), (.7, .7, .06), 'Head', 'pad light', (0, 0, -20))
    for k in range(4):
        a = math.pi / 2 * k + .4
        P.box(f'petal {k}', (.08 + .14 * math.cos(a), HEAD_Y + .4 + .14 * math.sin(a), HEAD_TOP + .16), (.18, .18, .14), 'Head', 'petal')
    P.box('flower center', (.08, HEAD_Y + .4, HEAD_TOP + .22), (.12, .12, .1), 'Head', 'center')

SPECS = {
    'Scarecrow': dict(name='Scarecrow Chicken', paint=scarecrow_paint, props=scarecrow_props, rarity='Common', band=1, rough=.9,
                      ortho=7.0, vfx='None required. Optional: straw bits on Hit.'),
    'Pajama': dict(name='Pajama Chicken', paint=pajama_paint, props=pajama_props, rarity='Common', band=1, rough=.9,
                   vfx='"Zzz" bubbles while idle (BillboardGui or particle).'),
    'Lumberjack': dict(name='Lumberjack Chicken', paint=lumber_paint, props=lumber_props, rarity='Common', band=2, rough=.85,
                       vfx='None required. Optional: wood chips on Peck.'),
    'Party': dict(name='Party Chicken', paint=party_paint, props=party_props, rarity='Common', band=2,
                  vfx='Confetti burst on Celebrate; party-horn toot sound.'),
    'Cow': dict(name='Cow Chicken', paint=cow_paint, props=cow_props, rarity='Common', band=2, vfx='Cowbell clink sound on Walk steps.'),
    'Piggy': dict(name='Piggy Chicken', paint=piggy_paint, props=piggy_props, rarity='Common', band=2, rough=.6,
                  vfx='Mud splat puff on Defeat; oink sound.'),
    'Sushi': dict(name='Sushi Chicken', paint=sushi_paint, props=sushi_props, rarity='Uncommon', band=3, rough=.6, vfx='None required.'),
    'Donut': dict(name='Donut Chicken', paint=donut_paint, rarity='Uncommon', band=3, rough=.45, vfx='Sprinkle burst on Celebrate.'),
    'Popcorn': dict(name='Popcorn Chicken', paint=popcorn_paint, props=popcorn_props, rarity='Uncommon', band=3, rough=.8,
                    vfx='Popcorn kernels pop out on Hit (short-life part particles).'),
    'Gamer': dict(name='Gamer Chicken', paint=gamer_paint, props=gamer_props, rarity='Uncommon', band=3, glow=2.5,
                  vfx='Slow RGB color cycle on headset rings and wing tips (Color3 tween loop).'),
    'Frog': dict(name='Frog Chicken', paint=frog_paint, props=frog_props, rarity='Uncommon', band=3, rough=.5,
                 vfx='Ribbit sound on Celebrate; small hop on Celebrate is already in the clip.'),
}
