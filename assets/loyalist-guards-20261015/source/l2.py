"""Loyalist tier 2 (Elite): Shadow Battery, Iron Fleet, Dragon Commander guards.
Enemy-only mission guards; never rollable. Palette: shadow navy + violet (+ fleet blue)."""
import math, sys
sys.modules.pop('loyal', None)
from loyal import *

SHADOW = (46, 50, 70)
SHADOW_DARK = (30, 32, 48)
VIOLET_GLOW = (190, 120, 255)

# ------------------------------------------------------------------ Shadow Bulwark (Shadow Battery, tank)
def bulwark_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(70, 72, 90))
    if b:
        return b
    t = tabard(NAVY, VIOLET, GOLD, half=.74)(part, n, pos)
    if t:
        return t
    if part in ('Head', 'Neck'):
        return g((92, 96, 118), pos, 6, .05)
    u, v = plane(n, pos)
    plate = math.floor(v * 5) % 2
    return g(SHADOW if plate else SHADOW_DARK, pos, 10, .04)

def bulwark_props(P):
    P.mat('iron', (96, 100, 132), .4, .6); P.mat('iron dark', (62, 64, 88), .45, .6); P.mat('violet', VIOLET, .5)
    P.mat('glow', VIOLET_GLOW, .2, 0, 3); P.mat('gold', GOLD, .3, .8)
    # Tall tower shield on the right wing with a violet crown.
    for k, z in enumerate((1.0, 1.45, 1.9, 2.35, 2.8, 3.2)):
        P.box(f'tower {k}', (1.44, -.15, z), (.1, 1.3, .46), 'Wing_R', 'iron' if k % 2 else 'iron dark')
    P.box('tower rim top', (1.5, -.15, 3.45), (.06, 1.42, .1), 'Wing_R', 'violet')
    for y in (-.84, .54):
        P.box(f'tower rim {y}', (1.5, y, 2.2), (.06, .1, 2.6), 'Wing_R', 'violet')
    P.box('tower crown band', (1.51, -.15, 2.05), (.04, .6, .12), 'Wing_R', 'gold')
    for y, top in ((-.38, .32), (-.15, .42), (.08, .32)):
        P.box(f'tower crown {y}', (1.51, y, 2.11 + top / 2), (.04, .12, top), 'Wing_R', 'gold')
    # Closed visor helm with a glowing eye slit (above the painted eyes).
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .2), (1.56, 1.56, .44), 'Head', 'iron dark')
    P.box('helm crest', (0, HEAD_Y + .05, HEAD_TOP + .5), (.2, 1.4, .2), 'Head', 'violet')
    P.box('visor', (0, HEAD_Y - .79, HEAD_TOP + .05), (1.4, .06, .3), 'Head', 'iron')
    P.box('visor slit', (0, HEAD_Y - .83, HEAD_TOP + .05), (1.1, .04, .08), 'Head', 'glow')
    pauldrons(P, 'iron dark', 'violet', z=2.62, w=.7)

# ------------------------------------------------------------------ Shadow Gunner (Shadow Battery, splash)
def sgunner_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(80, 80, 96))
    if b:
        return b
    if part == 'Body' and is_front(n) and abs((px + pz * .9) - 2.6) < .13:
        return g((60, 44, 36), pos, 7, .04)  # bandolier
    t = tabard(NAVY, VIOLET, GOLD, half=.66)(part, n, pos)
    if t:
        return t
    if part in ('Head', 'Neck'):
        return g((70, 72, 88), pos, 6, .05)
    return feathers((84, 86, 104), pos, n, rows=7, dark=.84)

def sgunner_props(P):
    P.mat('barrel', (58, 60, 80), .35, .7); P.mat('barrel dark', (34, 36, 50), .4, .7); P.mat('brass', (210, 160, 70), .3, .8)
    P.mat('glow', VIOLET_GLOW, .2, 0, 3.2); P.mat('lens', (180, 120, 255), .1, 0, 1.6); P.mat('strap', (52, 40, 34), .8)
    P.mat('shell', (120, 86, 200), .4, .3)
    # Shoulder hand-cannon resting on the right wing, glowing muzzle forward.
    P.seg('cannon', (1.38, .9, 2.55), (1.38, -1.5, 2.95), .52, .52, 'Wing_R', 'barrel')
    for k, y in enumerate((.5, -.2, -.9)):
        P.seg(f'cannon band {k}', (1.38, y + .07, 2.6 + (.9 - y) * .16), (1.38, y - .07, 2.62 + (.9 - y) * .16), .6, .6, 'Wing_R', 'brass')
    P.seg('cannon muzzle', (1.38, -1.4, 2.93), (1.38, -1.7, 2.98), .66, .66, 'Wing_R', 'barrel dark')
    P.box('muzzle glow', (1.38, -1.73, 2.98), (.42, .04, .42), 'Wing_R', 'glow', (10, 0, 0))
    P.box('cannon grip', (1.38, .2, 2.2), (.18, .2, .5), 'Wing_R', 'barrel dark')
    # Round violet goggles over the eyes and a soft cap.
    P.box('goggle strap', (0, HEAD_Y, 3.78), (1.46, 1.46, .16), 'Head', 'strap')
    for s in (-1, 1):
        P.box(f'goggle rim {s}', (s * .42, -1.58, 3.75), (.52, .1, .52), 'Head', 'brass')
        P.box(f'goggle lens {s}', (s * .42, -1.64, 3.75), (.36, .04, .36), 'Head', 'lens')
    P.box('cap', (0, HEAD_Y + .08, HEAD_TOP + .12), (1.44, 1.44, .24), 'Head', 'barrel dark')
    for k, x in enumerate((-.56, -.3, -.04)):
        P.box(f'shell {k}', (x, -1.27, 2.0 + k * .26), (.14, .08, .24), 'Body', 'shell')

# ------------------------------------------------------------------ Night Captain (Shadow Battery, heavy)
def ncaptain_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(70, 72, 90))
    if b:
        return b
    if part == 'Head':
        return g((214, 216, 228), pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(abs(px) - .3) < .05:
        return g((200, 204, 216), pos, 7, .03)  # silver coat trim
    if part == 'Body' and is_front(n) and abs(px) < .25 and crown(px, pz, cz=1.9, s=.7):
        return g(GOLD, pos, 8, .03)
    if part in ('Body', 'Neck'):
        return g(NAVY, pos, 9, .05)
    return feathers((54, 58, 92), pos, n, rows=6)

def ncaptain_props(P):
    P.mat('hat', (28, 28, 42), .7); P.mat('silver', (206, 210, 222), .3, .8); P.mat('violet', VIOLET, .7)
    P.mat('pole', (60, 50, 70), .6, .3); P.mat('lantern', (40, 40, 56), .4, .6); P.mat('flame', VIOLET_GLOW, .2, 0, 4)
    # Tricorn hat with a violet plume.
    P.box('tricorn base', (0, HEAD_Y + .05, HEAD_TOP + .08), (1.9, 1.7, .16), 'Head', 'hat')
    P.box('tricorn crown', (0, HEAD_Y + .1, HEAD_TOP + .3), (1.2, 1.2, .34), 'Head', 'hat')
    for s in (-1, 1):
        P.box(f'tricorn wing {s}', (s * .9, HEAD_Y + .1, HEAD_TOP + .26), (.16, 1.5, .34), 'Head', 'hat')
    P.box('tricorn trim', (0, HEAD_Y - .8, HEAD_TOP + .2), (1.6, .06, .1), 'Head', 'silver')
    P.seg('hat plume', (-.5, HEAD_Y + .3, HEAD_TOP + .4), (-.9, HEAD_Y + .9, HEAD_TOP + 1.1), .16, .34, 'Head', 'violet')
    # Lantern staff in the right wing with a violet flame.
    P.seg('staff', (1.42, -.1, .8), (1.42, -.5, 4.3), .16, .16, 'Wing_R', 'pole')
    P.seg('staff hook', (1.42, -.5, 4.3), (1.42, -1.0, 4.4), .14, .14, 'Wing_R', 'pole')
    P.box('lantern cap', (1.42, -1.05, 4.22), (.62, .62, .14), 'Wing_R', 'lantern')
    P.box('lantern glass', (1.42, -1.05, 3.84), (.52, .52, .64), 'Wing_R', 'flame')
    P.box('lantern base', (1.42, -1.05, 3.46), (.62, .62, .14), 'Wing_R', 'lantern')
    for s in (-1, 1):
        P.box(f'epaulette {s}', (s * 1.2, -.05, 2.72), (.34, .62, .12), 'Wing_L' if s < 0 else 'Wing_R', 'silver')

# ------------------------------------------------------------------ Fleet Marine (Iron Fleet, heavy)
FLEET = (40, 70, 140)

def marine_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Head':
        return g((240, 238, 232), pos, 6, .04)
    if part == 'Body' and is_front(n) and (abs((px - pz * .55) + .55) < .1 or abs((px + pz * .55) - .55) < .1):
        return g((240, 240, 236), pos, 7, .03)  # white cross belts
    if part == 'Body' and pz < 1.3:
        return g((240, 240, 236), pos, 10, .03)
    if part in ('Body', 'Neck'):
        return g(FLEET, pos, 9, .05)
    return feathers((34, 58, 118), pos, n, rows=6)

def marine_props(P):
    P.mat('shako', (30, 34, 56), .6); P.mat('gold', GOLD, .3, .8); P.mat('red', CRIMSON, .7); P.mat('white', (240, 240, 236), .7)
    P.mat('wood', (130, 84, 46), .8); P.mat('steel', (190, 196, 206), .3, .8)
    # Tall shako with a gold plate and red pompom.
    P.box('shako', (0, HEAD_Y + .05, HEAD_TOP + .45), (1.3, 1.3, .9), 'Head', 'shako')
    P.box('shako top', (0, HEAD_Y + .05, HEAD_TOP + .93), (1.42, 1.42, .08), 'Head', 'gold')
    P.box('shako peak', (0, HEAD_Y - .78, HEAD_TOP + .04), (1.1, .4, .06), 'Head', 'shako')
    P.box('shako plate', (0, HEAD_Y - .66, HEAD_TOP + .45), (.5, .04, .5), 'Head', 'gold')
    P.box('pompom', (0, HEAD_Y - .5, HEAD_TOP + 1.1), (.3, .3, .3), 'Head', 'red')
    # Shouldered musket with a bayonet.
    P.seg('musket stock', (1.4, .7, 1.4), (1.4, .1, 2.2), .22, .14, 'Wing_R', 'wood')
    P.seg('musket barrel', (1.4, .1, 2.2), (1.4, -.9, 4.0), .12, .12, 'Wing_R', 'steel')
    P.seg('bayonet', (1.4, -.9, 4.0), (1.4, -1.1, 4.7), .06, .1, 'Wing_R', 'steel')
    for s in (-1, 1):
        P.box(f'epaulette {s}', (s * 1.2, -.05, 2.72), (.34, .62, .12), 'Wing_L' if s < 0 else 'Wing_R', 'gold')
    P.box('belt plate', (0, -1.27, 1.95), (.3, .06, .26), 'Body', 'gold')

# ------------------------------------------------------------------ Deck Raider (Iron Fleet, fighter)
def raider_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Head':
        return g((236, 214, 180), pos, 6, .04)
    if part == 'Body' and pz < 1.3:
        return g((70, 50, 36), pos, 10, .04)  # belt
    if part in ('Body', 'Neck'):
        return g((236, 236, 236) if math.floor(pz * 6) % 2 else FLEET, pos, 9, .03)  # striped shirt
    return feathers((210, 186, 150), pos, n, rows=7)

def raider_props(P):
    P.mat('bandana', CRIMSON, .8); P.mat('bandana dark', CRIMSON_DARK, .8); P.mat('steel', (214, 220, 230), .25, .85)
    P.mat('gold', GOLD, .3, .85); P.mat('grip', (60, 40, 30), .8); P.mat('buckle', (200, 170, 90), .3, .8)
    # Knotted bandana with tails.
    P.box('bandana', (0, HEAD_Y + .05, HEAD_TOP + .1), (1.48, 1.48, .22), 'Head', 'bandana')
    P.box('bandana top', (0, HEAD_Y + .1, HEAD_TOP + .26), (1.1, 1.2, .12), 'Head', 'bandana dark')
    P.box('bandana knot', (0, HEAD_Y + .78, HEAD_TOP - .02), (.3, .2, .26), 'Head', 'bandana dark')
    P.seg('bandana tail a', (0, HEAD_Y + .82, HEAD_TOP - .1), (.2, HEAD_Y + 1.2, 3.6), .2, .06, 'Head', 'bandana')
    P.seg('bandana tail b', (0, HEAD_Y + .82, HEAD_TOP - .1), (-.25, HEAD_Y + 1.15, 3.7), .2, .06, 'Head', 'bandana')
    P.box('earring', (.74, -.5, 3.3), (.06, .16, .16), 'Head', 'gold')
    # Raised cutlass in the right wing.
    P.seg('cutlass blade', (1.4, -.3, 2.3), (1.4, -1.25, 4.0), .1, .3, 'Wing_R', 'steel')
    P.seg('cutlass tip', (1.4, -1.25, 4.0), (1.4, -1.45, 4.25), .08, .2, 'Wing_R', 'steel')
    P.box('cutlass guard', (1.4, -.25, 2.18), (.16, .5, .14), 'Wing_R', 'gold', (-30, 0, 0))
    P.seg('cutlass grip', (1.4, -.2, 2.1), (1.4, 0, 1.75), .14, .14, 'Wing_R', 'grip')
    P.box('belt buckle', (0, -1.25, 1.18), (.3, .06, .2), 'Body', 'buckle')

# ------------------------------------------------------------------ Frost Gunner (Iron Fleet, ice)
ICE = (176, 222, 246)

def frost_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(150, 186, 210))
    if b:
        return b
    if part == 'Body' and pz > 2.6:
        return g((236, 240, 246), pos, 7, .05)  # fur collar
    if part == 'Head':
        return g((230, 242, 250), pos, 6, .04)
    t = tabard(FLEET, (236, 240, 246), GOLD, half=.78)(part, n, pos)
    if t:
        return t
    return feathers(ICE, pos, n, rows=7, dark=.88)

def frost_props(P):
    P.mat('gun', (96, 120, 150), .35, .7); P.mat('gun dark', (60, 74, 98), .4, .7); P.mat('ice', (170, 230, 255), .1, 0, 1.8)
    P.mat('fur', (236, 240, 246), .9); P.mat('hat', (40, 64, 120), .8); P.mat('rope', (200, 180, 140), .8)
    # Harpoon gun on the right wing with an ice-crystal harpoon.
    P.seg('harpoon gun', (1.4, .7, 2.1), (1.4, -1.0, 2.6), .44, .44, 'Wing_R', 'gun')
    P.box('gun drum', (1.4, .3, 2.0), (.5, .5, .5), 'Wing_R', 'gun dark')
    P.seg('harpoon shaft', (1.4, -1.0, 2.6), (1.4, -1.6, 2.78), .1, .1, 'Wing_R', 'gun dark')
    P.box('harpoon head', (1.4, -1.9, 2.86), (.48, .6, .48), 'Wing_R', 'ice', (16, 0, 45))
    P.box('harpoon barb', (1.4, -1.6, 2.78), (.42, .08, .14), 'Wing_R', 'ice', (16, 0, 0))
    P.seg('harpoon rope', (1.4, .3, 1.8), (1.0, .6, 1.2), .08, .08, 'Wing_R', 'rope')
    # Fur-trimmed watch cap with frost goggles.
    P.box('cap', (0, HEAD_Y + .05, HEAD_TOP + .2), (1.44, 1.44, .4), 'Head', 'hat')
    P.box('cap fur', (0, HEAD_Y + .05, HEAD_TOP + .02), (1.6, 1.6, .2), 'Head', 'fur')
    P.box('pompom', (0, HEAD_Y + .05, HEAD_TOP + .5), (.32, .32, .26), 'Head', 'fur')
    for s in (-1, 1):
        P.box(f'goggle {s}', (s * .32, HEAD_Y - .8, HEAD_TOP + .18), (.42, .14, .3), 'Head', 'ice')

# ------------------------------------------------------------------ Honor Guard (Dragon Commander, heavy)
EMBER = (255, 120, 40)

def honor_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(60, 46, 56))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((70, 50, 66), pos, 6, .05)
    t = tabard((110, 24, 40), GOLD_DARK, GOLD, half=.7)(part, n, pos)
    if t:
        return t
    u, v = plane(n, pos)
    scale = (math.floor(u * 6 + (math.floor(v * 6) % 2) * .5) + math.floor(v * 6)) % 2
    return g((72, 44, 70) if scale else (52, 32, 54), pos, 10, .04)  # dragon-scale plate

def honor_props(P):
    P.mat('plate', (76, 48, 76), .4, .6); P.mat('plate dark', (48, 30, 50), .45, .6); P.mat('gold', GOLD, .3, .8)
    P.mat('haft', (60, 40, 40), .8); P.mat('blade', (214, 218, 228), .25, .85); P.mat('ember', EMBER, .3, 0, 2.5)
    # Finned dragon-scale helm.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .2), (1.56, 1.56, .42), 'Head', 'plate')
    for k in range(4):
        P.box(f'helm fin {k}', (0, HEAD_Y - .5 + k * .36, HEAD_TOP + .5 + (2 - abs(k - 1.5)) * .12), (.12, .3, .3 + (2 - abs(k - 1.5)) * .2), 'Head', 'gold')
    for s in (-1, 1):
        P.box(f'cheek {s}', (s * .76, HEAD_Y + .1, 3.55), (.1, .9, .8), 'Head', 'plate dark')
    # Halberd in the right wing with an ember edge.
    P.seg('halberd haft', (1.42, .1, .8), (1.42, -.5, 4.9), .16, .16, 'Wing_R', 'haft')
    P.box('halberd axe', (1.42, -1.05, 4.3), (.12, .96, .9), 'Wing_R', 'blade', (-8, 0, 0))
    P.box('halberd edge', (1.42, -1.55, 4.3), (.14, .08, .86), 'Wing_R', 'ember', (-8, 0, 0))
    P.box('halberd spike', (1.42, -.18, 4.4), (.1, .36, .16), 'Wing_R', 'blade', (-8, 0, 0))
    P.seg('halberd tip', (1.42, -.5, 4.9), (1.42, -.56, 5.4), .12, .12, 'Wing_R', 'blade')
    pauldrons(P, 'plate dark', 'gold', z=2.62, w=.7)

# ------------------------------------------------------------------ Ember Adept (Dragon Commander, splash)
def adept_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(70, 40, 40))
    if b:
        return b
    if part == 'Head':
        return g((238, 226, 214), pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px) < .14:
        return (g((255, 150, 60), pos, 7, .03), (255, 110, 30))  # glowing robe seam
    if part == 'Body' and pz < 1.3:
        return g((255, 140, 50), pos, 8, .04)
    if part in ('Body', 'Neck'):
        return g((70, 34, 70), pos, 9, .05)  # ember-violet robe
    return feathers((90, 44, 84), pos, n, rows=6)

def adept_props(P):
    P.mat('hood', (58, 28, 60), .9); P.mat('hood trim', (255, 140, 50), .6); P.mat('staff', (60, 36, 30), .8)
    P.mat('gold', GOLD, .3, .8); P.mat('orb', (255, 110, 30), .2, 0, 4); P.mat('orb core', (255, 230, 150), .2, 0, 5)
    # Pointed hood.
    P.box('hood', (0, HEAD_Y + .1, HEAD_TOP + .12), (1.58, 1.6, .3), 'Head', 'hood')
    P.box('hood mid', (0, HEAD_Y + .25, HEAD_TOP + .4), (1.1, 1.2, .3), 'Head', 'hood')
    P.box('hood tip', (0, HEAD_Y + .45, HEAD_TOP + .66), (.6, .7, .26), 'Head', 'hood')
    P.box('hood back', (0, HEAD_Y + .82, 3.6), (1.58, .14, 1.3), 'Head', 'hood')
    P.box('hood rim', (0, HEAD_Y - .78, HEAD_TOP + .0), (1.6, .06, .12), 'Head', 'hood trim')
    # Staff holding a floating ember orb.
    P.seg('staff', (1.42, -.1, .8), (1.42, -.45, 4.2), .16, .16, 'Wing_R', 'staff')
    for s in (-1, 1):
        P.seg(f'staff claw {s}', (1.42, -.45, 4.2), (1.42 + s * .22, -.6, 4.62), .08, .08, 'Wing_R', 'gold')
    P.box('orb', (1.42, -.64, 4.86), (.7, .7, .7), 'Wing_R', 'orb')
    P.box('orb core', (1.42, -.64, 4.86), (.4, .4, .4), 'Wing_R', 'orb core')
    P.box('orb flare a', (1.42, -.64, 5.3), (.26, .26, .3), 'Wing_R', 'orb')
    P.box('orb flare b', (1.42, -.64, 4.42), (.2, .2, .2), 'Wing_R', 'orb')

# ------------------------------------------------------------------ Dragon Commander (boss)
def dcmd_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(54, 34, 38))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 230, 220), pos, 6, .04)
    t = tabard(CRIMSON, GOLD, GOLD, half=.66)(part, n, pos)
    if t:
        return t
    u, v = plane(n, pos)
    scale = (math.floor(u * 7 + (math.floor(v * 7) % 2) * .5) + math.floor(v * 7)) % 2
    return g((44, 30, 38) if scale else (66, 40, 50), pos, 10, .04)

def dcmd_props(P):
    P.mat('helm', (150, 30, 40), .4, .5); P.mat('helm dark', (96, 18, 30), .45, .5); P.mat('horn', (236, 224, 196), .6)
    P.mat('gold', GOLD, .3, .85); P.mat('wing', (120, 24, 36), .7); P.mat('wing bone', (60, 36, 40), .7)
    P.mat('eye', (255, 190, 60), .2, 0, 3); P.mat('blade', (226, 230, 240), .2, .9); P.mat('ember', EMBER, .3, 0, 3)
    P.mat('cape', (140, 24, 36), .85)
    # Dragon-head helm: snout over the brow, jaw sides, swept horns, glowing eyes.
    P.box('dragon crown', (0, HEAD_Y + .05, HEAD_TOP + .2), (1.6, 1.6, .44), 'Head', 'helm')
    P.box('dragon snout', (0, HEAD_Y - .98, HEAD_TOP + .2), (1.0, .7, .34), 'Head', 'helm')
    P.box('dragon nostrils', (0, HEAD_Y - 1.34, HEAD_TOP + .28), (.6, .06, .12), 'Head', 'helm dark')
    for x in (-.4, -.13, .13, .4):
        P.box(f'dragon tooth {x}', (x, HEAD_Y - 1.3, HEAD_TOP + .0), (.1, .08, .14), 'Head', 'horn')
    for s in (-1, 1):
        P.box(f'dragon eye {s}', (s * .42, HEAD_Y - .8, HEAD_TOP + .44), (.24, .06, .12), 'Head', 'eye')
        P.seg(f'horn {s}', (s * .55, HEAD_Y + .3, HEAD_TOP + .36), (s * .9, HEAD_Y + .9, HEAD_TOP + .8), .34, .34, 'Head', 'horn')
        P.seg(f'horn mid {s}', (s * .9, HEAD_Y + .9, HEAD_TOP + .8), (s * 1.0, HEAD_Y + 1.4, HEAD_TOP + .86), .26, .26, 'Head', 'horn')
        P.seg(f'horn tip {s}', (s * 1.0, HEAD_Y + 1.4, HEAD_TOP + .86), (s * 1.0, HEAD_Y + 1.75, HEAD_TOP + 1.12), .16, .16, 'Head', 'horn')
        P.box(f'jaw {s}', (s * .78, HEAD_Y - .2, 3.5), (.12, 1.1, .7), 'Head', 'helm dark')
    for k in range(3):
        P.box(f'crest spine {k}', (0, HEAD_Y + .2 + k * .3, HEAD_TOP + .5 - k * .06), (.12, .22, .3 - k * .06), 'Head', 'gold')
    # Bat-like dragon wings on the back.
    for s in (-1, 1):
        P.seg(f'wing arm {s}', (s * .5, 1.5, 2.7), (s * 2.0, 1.9, 4.0), .16, .16, 'Body', 'wing bone')
        P.seg(f'wing finger a {s}', (s * 2.0, 1.9, 4.0), (s * 2.6, 2.0, 2.6), .1, .1, 'Body', 'wing bone')
        P.seg(f'wing finger b {s}', (s * 2.0, 1.9, 4.0), (s * 1.6, 2.0, 2.2), .1, .1, 'Body', 'wing bone')
        P.box(f'wing web a {s}', (s * 1.75, 1.85, 3.1), (1.0, .06, 1.2), 'Body', 'wing', (0, s * -15, 0))
        P.box(f'wing web b {s}', (s * 2.2, 1.92, 3.2), (.6, .06, 1.2), 'Body', 'wing', (0, s * 10, 0))
        P.box(f'wing web c {s}', (s * 1.2, 1.75, 3.0), (.6, .06, .8), 'Body', 'wing')
    P.box('cape', (0, 1.5, 1.85), (1.9, .12, 1.7), 'Body', 'cape')
    # Flame sword raised in the right wing.
    P.seg('sword blade', (1.42, -.25, 2.4), (1.42, -1.1, 4.7), .14, .32, 'Wing_R', 'blade')
    P.seg('sword fire', (1.42, -.4, 2.8), (1.42, -1.05, 4.55), .16, .1, 'Wing_R', 'ember')
    P.box('sword guard', (1.42, -.2, 2.25), (.2, .7, .16), 'Wing_R', 'gold', (-20, 0, 0))
    P.seg('sword grip', (1.42, -.18, 2.2), (1.42, .02, 1.75), .16, .16, 'Wing_R', 'helm dark')
    pauldrons(P, 'helm', 'gold', z=2.64, w=.74)

SPECS = {
    'LoyalShadowBulwark': dict(name='Shadow Bulwark', paint=bulwark_paint, props=bulwark_props, rarity='Loyalist', zone='Shadow Battery',
                               earn='enemy only', role='Bucket', tier=2, ortho=7.2, glow=2.5, vfx='Violet visor-slit glow (Light, pulse).'),
    'LoyalShadowGunner': dict(name='Shadow Gunner', paint=sgunner_paint, props=sgunner_props, rarity='Loyalist', zone='Shadow Battery',
                              earn='enemy only', role='Wizard', tier=2, ortho=7.4, glow=2.5, vfx='Violet muzzle flash + Smoke on Attack.'),
    'LoyalNightCaptain': dict(name='Night Captain', paint=ncaptain_paint, props=ncaptain_props, rarity='Loyalist', zone='Shadow Battery',
                              earn='enemy only', role='Knight', tier=2, ortho=8.0, glow=2.5, vfx='Violet lantern Light (pulse) + Glitter motes.'),
    'LoyalFleetMarine': dict(name='Fleet Marine', paint=marine_paint, props=marine_props, rarity='Loyalist', zone='Iron Fleet',
                             earn='enemy only', role='Knight', tier=2, ortho=8.0, vfx='None.'),
    'LoyalDeckRaider': dict(name='Deck Raider', paint=raider_paint, props=raider_props, rarity='Loyalist', zone='Iron Fleet',
                            earn='enemy only', role='Viking', tier=2, ortho=7.6, vfx='None.'),
    'LoyalFrostGunner': dict(name='Frost Gunner', paint=frost_paint, props=frost_props, rarity='Loyalist', zone='Iron Fleet',
                             earn='enemy only', role='IceDuck', tier=2, ortho=7.4, glow=2.0, vfx='Frost sparkle (Glitter, pale blue) on Attack.'),
    'LoyalHonorGuard': dict(name='Honor Guard', paint=honor_paint, props=honor_props, rarity='Loyalist', zone='Dragon Commander',
                            earn='enemy only', role='Knight', tier=2, ortho=8.6, glow=2.0, vfx='Ember burst on Attack.'),
    'LoyalEmberAdept': dict(name='Ember Adept', paint=adept_paint, props=adept_props, rarity='Loyalist', zone='Dragon Commander',
                            earn='enemy only', role='Wizard', tier=2, ortho=8.0, glow=2.5, vfx='Orb Light pulse + rising Ember loop; Ember burst on Attack.'),
    'LoyalDragonCommander': dict(name='Dragon Commander', paint=dcmd_paint, props=dcmd_props, rarity='Loyalist', zone='Dragon Commander (boss)',
                                 earn='enemy only', role='Dragon (boss)', tier=2, ortho=9.0, glow=2.5,
                                 vfx='Ember loop from the flame sword; dragon-eye Light; Ember + Smoke burst on Attack.'),
}
