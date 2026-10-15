"""Batch 5 — Rare/Epic costume chickens."""
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

# ------------------------------------------------------------------ Firefighter
def fire_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(34, 34, 38))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    for z in ((1.5,) if part.startswith('Wing') else (1.32, 2.1)):
        if abs(pz - z) < .1:
            return (214, 218, 224) if abs(pz - z) < .035 else (250, 228, 50)
    return g((196, 160, 96), pos, 7, .05)

def fire_props(P):
    P.mat('red', (214, 34, 36), .35, .1); P.mat('badge', (240, 200, 70), .3, .7); P.mat('brim', (180, 26, 30), .4)
    P.box('helmet', (0, HEAD_Y + .05, HEAD_TOP + .17), (1.52, 1.56, .34), 'Head', 'red')
    P.box('helmet top', (0, HEAD_Y + .05, HEAD_TOP + .38), (1.1, 1.3, .12), 'Head', 'red')
    P.box('helmet ridge', (0, HEAD_Y + .05, HEAD_TOP + .48), (.18, 1.4, .1), 'Head', 'brim')
    P.box('brim', (0, HEAD_Y + .1, HEAD_TOP + .02), (1.96, 2.0, .07), 'Head', 'brim')
    P.box('back brim', (0, HEAD_Y + 1.1, HEAD_TOP - .02), (1.7, .5, .07), 'Head', 'brim', (-14, 0, 0))
    P.box('front shield', (0, HEAD_Y - .8, HEAD_TOP + .3), (.56, .06, .5), 'Head', 'badge')
    P.box('front shield top', (0, HEAD_Y - .8, HEAD_TOP + .6), (.3, .06, .14), 'Head', 'badge')

# ------------------------------------------------------------------ Chef
def chef_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Neck':
        return g((214, 36, 40), pos, 6)
    if part == 'Body' and is_front(n) and any(abs(px - x) < .07 for x in (-.3, .3)) and (pz * 3) % 1 < .35 and pz > 1.3:
        return (32, 32, 36)
    return g((250, 250, 248), pos, 7, .03)

def chef_props(P):
    P.mat('toque', (252, 252, 250), .85); P.mat('toque shade', (234, 234, 232), .85); P.mat('kerchief', (214, 36, 40), .7)
    P.mat('spoon', (196, 146, 86), .7)
    P.box('toque band', (0, HEAD_Y, HEAD_TOP + .16), (1.44, 1.44, .32), 'Head', 'toque shade')
    P.box('toque puff', (0, HEAD_Y + .02, HEAD_TOP + .62), (1.7, 1.7, .62), 'Head', 'toque')
    P.box('toque top', (0, HEAD_Y + .02, HEAD_TOP + .98), (1.9, 1.9, .3), 'Head', 'toque shade')
    P.box('toque crown', (0, HEAD_Y + .02, HEAD_TOP + 1.17), (1.5, 1.5, .14), 'Head', 'toque')
    P.box('kerchief', (0, -.85, 2.74), (1.2, 1.0, .2), 'Body', 'kerchief')
    P.box('kerchief tip', (-.35, -1.33, 2.55), (.3, .08, .3), 'Body', 'kerchief', (0, 30, 0))
    P.seg('spoon handle', (1.42, .3, 1.15), (1.42, -.3, 2.75), .1, .1, 'Wing_R', 'spoon')
    P.box('spoon bowl', (1.42, -.38, 2.95), (.16, .42, .56), 'Wing_R', 'spoon', (-20, 0, 0))

# ------------------------------------------------------------------ Detective
TRENCH = (192, 160, 108)

def det_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(92, 62, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and abs(pz - 1.62) < .08:
        return g((120, 88, 52), pos, 7)  # belt
    if part == 'Body' and is_front(n) and abs(abs(px) - .4) < .06 and (pz * 3) % 1 < .35 and pz > 1.75:
        return (90, 62, 40)
    if part == 'Body' and is_front(n) and abs(px - (pz - 2.5) * .9) < .05 and pz > 2.1:
        return g((160, 128, 80), pos, 8)  # lapel edge
    return g(TRENCH, pos, 9, .05)

def det_props(P):
    P.mat('cap', (142, 98, 58), .85); P.mat('cap check', (112, 76, 44), .85); P.mat('handle', (90, 60, 36), .7)
    P.mat('rim', (200, 160, 70), .3, .7); P.mat('lens', (200, 230, 240), .05, 0, .3)
    P.box('cap', (0, HEAD_Y, HEAD_TOP + .14), (1.52, 1.52, .3), 'Head', 'cap')
    P.box('cap top', (0, HEAD_Y, HEAD_TOP + .34), (1.0, 1.2, .12), 'Head', 'cap check')
    P.box('front peak', (0, HEAD_Y - .92, HEAD_TOP + .05), (1.0, .4, .07), 'Head', 'cap')
    P.box('back peak', (0, HEAD_Y + .92, HEAD_TOP + .05), (1.0, .4, .07), 'Head', 'cap')
    for s in (-1, 1):
        P.box(f'ear flap {s}', (s * .8, HEAD_Y, HEAD_TOP + .18), (.1, .5, .2), 'Head', 'cap check')
    P.seg('glass handle', (1.0, -1.42, 1.95), (1.18, -1.3, 1.35), .11, .11, 'Wing_R', 'handle')
    for k, (w, z) in enumerate([(.26, 2.0), (.5, 2.12), (.58, 2.3), (.5, 2.48), (.26, 2.6)]):
        P.box(f'glass rim {k}', (.92, -1.45, z), (w, .06, .14), 'Wing_R', 'rim')
    P.box('glass lens', (.92, -1.49, 2.3), (.42, .04, .42), 'Wing_R', 'lens')

# ------------------------------------------------------------------ Samurai
def samurai_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(40, 36, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    row = math.floor(pz / .26)
    if abs((pz / .26) % 1 - .5) > .4:
        return (240, 196, 70)  # gold lacing between plates
    return g((196, 30, 38) if row % 2 else (30, 26, 32), pos, 7, .04)

def samurai_props(P):
    P.mat('lacquer', (190, 28, 36), .3, .1); P.mat('black', (30, 26, 32), .35); P.mat('gold', (244, 200, 70), .3, .7)
    P.box('kabuto bowl', (0, HEAD_Y + .05, HEAD_TOP + .18), (1.56, 1.56, .36), 'Head', 'lacquer')
    P.box('kabuto top', (0, HEAD_Y + .05, HEAD_TOP + .42), (1.1, 1.1, .14), 'Head', 'lacquer')
    for s in (-1, 1):
        P.box(f'fukigaeshi {s}', (s * .86, HEAD_Y - .45, HEAD_TOP - .05), (.14, .5, .4), 'Head', 'black', (0, 0, s * -20))
        P.box(f'shoulder {s}', (s * 1.0, -.2, 2.9), (.5, 1.2, .2), 'Body', 'lacquer', (0, s * 12, 0))
        P.box(f'shoulder b {s}', (s * 1.12, -.2, 2.7), (.3, 1.2, .2), 'Body', 'black', (0, s * 12, 0))
        P.seg(f'crest {s}', (0, HEAD_Y - .8, HEAD_TOP + .3), (s * .62, HEAD_Y - .86, HEAD_TOP + .78), .18, .1, 'Head', 'gold')
        P.seg(f'crest tip {s}', (s * .62, HEAD_Y - .86, HEAD_TOP + .76), (s * .72, HEAD_Y - .86, HEAD_TOP + 1.12), .16, .1, 'Head', 'gold')
    P.box('neck guard', (0, HEAD_Y + .7, HEAD_TOP - .25), (1.7, .3, .4), 'Head', 'black')
    P.box('crest base', (0, HEAD_Y - .8, HEAD_TOP + .3), (.22, .1, .2), 'Head', 'gold')

# ------------------------------------------------------------------ Cowboy
def cowboy_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((62, 92, 150), pos, 3)
    b = basic(part, pos, foot=(112, 70, 38))
    if b:
        return b
    if part in ('Head',):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Neck':
        return g((206, 36, 40), pos, 6)
    if part == 'Body' and is_front(n) and abs(px) < .32:
        return g((236, 228, 210), pos, 7, .03)  # shirt between vest sides
    if part.startswith('Wing'):
        return g((236, 228, 210), pos, 8, .03)
    return g((176, 128, 74), pos, 9, .06)

def cowboy_props(P):
    P.mat('hat', (132, 86, 46), .75); P.mat('hat band', (70, 44, 26), .7); P.mat('bandana', (206, 36, 40), .7)
    P.mat('star', (246, 204, 70), .3, .7)
    P.box('hat brim', (0, HEAD_Y, HEAD_TOP + .04), (2.0, 1.9, .08), 'Head', 'hat')
    for s in (-1, 1):
        P.box(f'brim curl {s}', (s * .96, HEAD_Y, HEAD_TOP + .14), (.12, 1.9, .2), 'Head', 'hat')
    P.box('hat crown', (0, HEAD_Y + .04, HEAD_TOP + .32), (1.1, 1.2, .5), 'Head', 'hat')
    P.box('hat dent', (0, HEAD_Y + .04, HEAD_TOP + .6), (.5, .9, .08), 'Head', 'hat band')
    P.box('hat band', (0, HEAD_Y + .04, HEAD_TOP + .14), (1.14, 1.24, .1), 'Head', 'hat band')
    P.box('bandana', (0, -.84, 2.72), (1.24, 1.02, .2), 'Body', 'bandana')
    P.box('bandana point', (0, -1.3, 2.45), (.36, .1, .34), 'Body', 'bandana', (0, 45, 0))
    P.box('sheriff star a', (-.6, -1.26, 2.05), (.3, .05, .3), 'Body', 'star')
    P.box('sheriff star b', (-.6, -1.26, 2.05), (.3, .05, .3), 'Body', 'star', (0, 45, 0))

# ------------------------------------------------------------------ Steampunk
def steam_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(214, 156, 70), foot=(96, 64, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((214, 194, 160), pos, 6, .05)
    if part == 'Body' and is_front(n) and abs(px) > .38:
        return g((110, 70, 40), pos, 7)  # leather vest
    if part == 'Body' and is_front(n):
        return g((228, 220, 200), pos, 8)
    u, v = plane(n, pos)
    if dots(u + 2, v, .5, 71, .1, .8):
        return (216, 170, 80)  # rivets
    return g((150, 92, 52), pos, 9, .06)

def steam_props(P):
    P.mat('brass', (210, 164, 70), .3, .75); P.mat('copper', (184, 104, 60), .3, .75); P.mat('glass', (120, 200, 190), .1, 0, .5)
    P.mat('strap', (70, 46, 30), .7); P.mat('dark', (60, 52, 46), .4, .5)
    P.box('goggle strap', (0, HEAD_Y, HEAD_TOP - .02), (1.48, 1.48, .12), 'Head', 'strap')
    for s in (-1, 1):
        P.box(f'goggle {s}', (s * .3, -1.4, HEAD_TOP + .12), (.42, .3, .34), 'Head', 'brass')
        P.box(f'goggle lens {s}', (s * .3, -1.56, HEAD_TOP + .12), (.3, .04, .24), 'Head', 'glass')
    for k, (y, z, r) in enumerate([(.4, 2.6, .55), (1.0, 2.0, .45), (.1, 1.8, .38)]):
        P.box(f'gear {k}', (1.33, y, z), (.08, r * 1.6, r * 1.6), 'Body', 'copper' if k % 2 else 'brass')
        P.box(f'gear b {k}', (1.33, y, z), (.08, r * 1.6, r * 1.6), 'Body', 'copper' if k % 2 else 'brass', (45, 0, 0))
        P.box(f'gear hub {k}', (1.38, y, z), (.06, r * .6, r * .6), 'Body', 'dark')
    P.box('back plate', (0, 1.55, 2.1), (1.6, .1, 1.4), 'Body', 'copper')
    P.seg('pipe', (.45, 1.62, 2.4), (.45, 1.62, 3.5), .2, .2, 'Body', 'brass')
    P.box('pipe cap', (.45, 1.62, 3.55), (.28, .28, .1), 'Body', 'dark')

def steam_fx(fx):
    for i, z in enumerate((3.85, 4.2)):
        fx(f'FX_Steampunk_Steam_{i}', (.45 + i * .08, 1.62, z), (.22 + i * .08,) * 3, (236, 236, 236), .6, 'Body')

# ------------------------------------------------------------------ Neon
PINK, CYAN = (255, 60, 200), (60, 230, 255)

def neon_paint(part, n, pos, x, y, w, hh):
    edge = x == 0 or y == 0 or x == w - 1 or y == hh - 1
    if part in ('Beak', 'Wattle') or feet(part):
        c = PINK if part in ('Beak',) or part.startswith('Toe') else CYAN
        return (c, c) if edge else ((30, 30, 36), (0, 0, 0))
    if edge:
        c = CYAN if part in ('Head', 'Neck') or part.startswith('Wing') else PINK
        return c, c
    return g((22, 22, 28), pos, 6, .05)

# ------------------------------------------------------------------ Norse Raider
def norse_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(88, 62, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 226, 206), pos, 6, .04)
    u, v = plane(n, pos)
    if part == 'Body' and pz < 1.6 or part.startswith('Wing') and pz < 1.7:
        return g((120, 80, 46), pos, 7)  # leather
    mail = (math.floor(u * 9) + math.floor(v * 9)) % 2
    return g((140, 144, 150) if mail else (112, 116, 124), pos, 8, .04)

def norse_props(P):
    P.mat('iron', (130, 134, 142), .35, .6); P.mat('horn', (236, 226, 200), .6); P.mat('beard', (230, 140, 50), .8)
    P.mat('beard dark', (200, 110, 36), .8); P.mat('fur', (120, 84, 54), .95); P.mat('fur light', (150, 112, 74), .95)
    P.mat('wood', (150, 100, 56), .8); P.mat('paint', (40, 90, 170), .7)
    P.box('helmet', (0, HEAD_Y, HEAD_TOP + .14), (1.52, 1.52, .3), 'Head', 'iron')
    P.box('helmet top', (0, HEAD_Y, HEAD_TOP + .34), (1.1, 1.1, .14), 'Head', 'iron')
    P.box('nose guard', (0, -1.56, 4.0), (.16, .06, .5), 'Head', 'iron')
    for s in (-1, 1):
        P.seg(f'horn a {s}', (s * .74, HEAD_Y, HEAD_TOP + .12), (s * 1.1, HEAD_Y, HEAD_TOP + .45), .26, .26, 'Head', 'horn')
        P.seg(f'horn b {s}', (s * 1.08, HEAD_Y, HEAD_TOP + .42), (s * 1.18, HEAD_Y, HEAD_TOP + .85), .16, .16, 'Head', 'horn')
        P.box(f'beard braid {s}', (s * .3, -1.9, 2.3), (.18, .18, .5), 'Head', 'beard dark')
    P.box('beard', (0, -1.88, 2.62), (1.1, .3, .44), 'Head', 'beard')
    P.box('fur wrap', (0, -.35, 2.98), (2.3, 1.6, .26), 'Body', 'fur')
    P.box('fur wrap top', (0, -.35, 3.1), (1.6, 1.2, .1), 'Body', 'fur light')
    for k, (w, z) in enumerate([(.56, 1.53), (.86, 1.73), (1.0, 1.95), (.86, 2.17), (.56, 2.37)]):
        P.box(f'shield {k}', (1.42, -.05, z), (.08, w, .22), 'Wing_R', 'wood' if k != 2 else 'paint')
    P.box('shield boss', (1.48, -.05, 1.95), (.06, .26, .26), 'Wing_R', 'iron')

SPECS = {
    'Firefighter': dict(name='Firefighter Chicken', paint=fire_paint, props=fire_props, rarity='Rare', band=4,
                        vfx='None required. Optional: water spray on Peck.'),
    'Chef': dict(name='Chef Chicken', paint=chef_paint, props=chef_props, rarity='Rare', band=4, ortho=7.4,
                 vfx='None required. Optional: steam wisps from the spoon.'),
    'Detective': dict(name='Detective Chicken', paint=det_paint, props=det_props, rarity='Rare', band=4,
                      vfx='Lens glint on the magnifying glass (sparkle on Celebrate).'),
    'Samurai': dict(name='Samurai Chicken', paint=samurai_paint, props=samurai_props, rarity='Rare', band=5, ortho=7.0,
                    vfx='None required. Optional: cherry-blossom petals on Celebrate.'),
    'Cowboy': dict(name='Cowboy Chicken', paint=cowboy_paint, props=cowboy_props, rarity='Rare', band=5,
                   vfx='None required. Optional: dust puff on Walk.'),
    'Steampunk': dict(name='Steampunk Scratcher', paint=steam_paint, props=steam_props, fx=steam_fx, rarity='Rare', band=5,
                      vfx='Steam puffs from the back pipe (smoke particle, 2 s interval); gears spin (rotation tweens).'),
    'Neon': dict(name='Neon Chicken', paint=neon_paint, rarity='Epic', band=6, glow=3.2, rough=.5,
                 vfx='Neon outline glow (emission); subtle flicker on Hit; colored PointLight underglow.'),
    'NorseRaider': dict(name='Norse Raider', paint=norse_paint, props=norse_props, rarity='Epic', band=6, ortho=7.2,
                        vfx='None required. Optional: war-horn sound on Celebrate.'),
}
