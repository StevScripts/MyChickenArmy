"""Loyalist tier 3 (Royal): Royal Vanguard, Crown's Shield, The King Returns guards.
Enemy-only mission guards; never rollable. Palette: ivory + gold + crimson, element accents."""
import math, sys
sys.modules.pop('loyal', None)
from loyal import *

ICE = (150, 220, 255)
EMBER = (255, 120, 40)
STORM = (255, 226, 70)
ROYAL_BLUE = (40, 70, 170)

def plate_paint(base, dark, rows=5):
    def paint(n, pos):
        u, v = plane(n, pos)
        return g(base if math.floor(v * rows) % 2 else dark, pos, 10, .03)
    return paint

# ------------------------------------------------------------------ Vanguard Paladin (Royal Vanguard, heavy)
def paladin_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(200, 196, 186))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((246, 242, 234), pos, 6, .03)
    t = tabard(CRIMSON, GOLD, GOLD, half=.62)(part, n, pos)
    if t:
        return t
    return plate_paint(IVORY, (214, 204, 180))(n, pos)

def paladin_props(P):
    P.mat('ivory', IVORY, .35, .3); P.mat('ivory dark', (210, 198, 172), .4, .3); P.mat('gold', GOLD, .25, .9)
    P.mat('red', CRIMSON, .8); P.mat('pole', (120, 80, 44), .7)
    # Great helm with a gold crown ridge.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .2), (1.58, 1.58, .44), 'Head', 'ivory')
    P.box('helm band', (0, HEAD_Y + .05, HEAD_TOP + .02), (1.64, 1.64, .1), 'Head', 'gold')
    for x in (-.5, 0, .5):
        P.box(f'helm crown {x}', (x, HEAD_Y - .2, HEAD_TOP + .5 + (.12 if x == 0 else 0)), (.16, .16, .26 + (.24 if x == 0 else 0)), 'Head', 'gold')
    for s in (-1, 1):
        P.box(f'cheek {s}', (s * .76, HEAD_Y + .1, 3.55), (.1, .9, .8), 'Head', 'ivory dark')
    # Royal banner on a pole in the right wing.
    P.seg('banner pole', (1.42, .2, .8), (1.42, -.2, 5.2), .16, .16, 'Wing_R', 'pole')
    P.box('banner top', (1.42, -.2, 5.3), (.24, .24, .2), 'Wing_R', 'gold')
    P.box('banner bar', (1.42, -.75, 5.0), (.1, 1.2, .1), 'Wing_R', 'gold', (-5, 0, 0))
    P.box('banner cloth', (1.42, -.82, 4.3), (.06, 1.06, 1.3), 'Wing_R', 'red', (-5, 0, 0))
    P.box('banner crown band', (1.46, -.82, 4.2), (.04, .54, .12), 'Wing_R', 'gold', (-5, 0, 0))
    for y, top in ((-1.04, .3), (-.82, .42), (-.6, .3)):
        P.box(f'banner crown {y}', (1.46, y, 4.26 + top / 2), (.04, .12, top), 'Wing_R', 'gold', (-5, 0, 0))
    pauldrons(P, 'ivory', 'gold', z=2.62, w=.72)
    P.box('cape', (0, 1.5, 1.9), (1.9, .1, 1.6), 'Body', 'red')

# ------------------------------------------------------------------ Glacier Lancer (Royal Vanguard, ice)
def glacier_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(170, 206, 226))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 246, 252), pos, 6, .03)
    t = tabard(ROYAL_BLUE, GOLD, GOLD, half=.64)(part, n, pos)
    if t:
        return t
    return plate_paint((206, 232, 248), (160, 200, 228))(n, pos)

def glacier_props(P):
    P.mat('steel', (214, 232, 246), .25, .6); P.mat('steel dark', (150, 186, 212), .3, .6); P.mat('gold', GOLD, .25, .9)
    P.mat('ice', ICE, .1, 0, 2.2); P.mat('shaft', (230, 236, 246), .3, .5); P.mat('cape', (120, 190, 240), .7)
    # Helm with an ice-crystal crest.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .18), (1.56, 1.56, .4), 'Head', 'steel')
    P.box('helm band', (0, HEAD_Y + .05, HEAD_TOP + .02), (1.62, 1.62, .1), 'Head', 'gold')
    for k, (y, hgt) in enumerate(((-.4, .5), (0, .8), (.4, .55))):
        P.box(f'ice crest {k}', (0, HEAD_Y + y, HEAD_TOP + .38 + hgt / 2), (.16, .28, hgt), 'Head', 'ice', (0, 0, 45))
    # Crystal lance raised forward.
    P.seg('lance shaft', (1.42, .6, 1.2), (1.42, -1.2, 4.4), .18, .18, 'Wing_R', 'shaft')
    P.seg('lance crystal', (1.42, -1.2, 4.4), (1.42, -1.75, 5.4), .34, .34, 'Wing_R', 'ice')
    P.seg('lance crystal tip', (1.42, -1.75, 5.4), (1.42, -1.9, 5.7), .16, .16, 'Wing_R', 'ice')
    for k, w in enumerate((.62, .46)):
        P.box(f'vamplate {k}', (1.42, -.1 - k * .1, 2.1 + k * .17), (w, .14, w), 'Wing_R', 'gold', (-29, 0, 0))
    pauldrons(P, 'steel', 'gold', z=2.62, w=.7)
    P.box('cape', (0, 1.5, 1.9), (1.9, .1, 1.6), 'Body', 'cape')

# ------------------------------------------------------------------ Crimson Drake Knight (Royal Vanguard, dragon)
def drake_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(110, 30, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((240, 232, 224), pos, 6, .03)
    t = tabard(IVORY, GOLD, CRIMSON, half=.6)(part, n, pos)
    if t:
        return t
    return plate_paint(CRIMSON, CRIMSON_DARK)(n, pos)

def drake_props(P):
    P.mat('red', CRIMSON, .35, .4); P.mat('red dark', CRIMSON_DARK, .4, .4); P.mat('gold', GOLD, .25, .9)
    P.mat('blade', (230, 232, 240), .2, .9); P.mat('ember', EMBER, .3, 0, 3); P.mat('grip', (60, 30, 30), .8)
    # Helm with gold drake-wing fins.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .18), (1.56, 1.56, .4), 'Head', 'red')
    P.box('helm band', (0, HEAD_Y + .05, HEAD_TOP + .02), (1.62, 1.62, .1), 'Head', 'gold')
    for s in (-1, 1):
        for k in range(3):
            P.box(f'drake fin {s} {k}', (s * (.86 + k * .14), HEAD_Y + .3 + k * .16, HEAD_TOP + .2 + k * .2), (.12, .5 - k * .1, .26), 'Head', 'gold')
    P.box('helm snout', (0, HEAD_Y - .86, HEAD_TOP + .22), (.5, .3, .24), 'Head', 'red dark')
    # Upright flame greatsword.
    P.seg('greatsword', (1.44, -.3, 2.0), (1.44, -.6, 5.2), .14, .42, 'Wing_R', 'blade')
    P.seg('greatsword flame', (1.44, -.42, 2.6), (1.44, -.66, 5.05), .17, .12, 'Wing_R', 'ember')
    P.box('greatsword guard', (1.44, -.27, 1.9), (.2, .9, .18), 'Wing_R', 'gold', (-5, 0, 0))
    P.seg('greatsword grip', (1.44, -.27, 1.85), (1.44, -.23, 1.35), .18, .18, 'Wing_R', 'grip')
    P.box('greatsword pommel', (1.44, -.22, 1.28), (.24, .24, .16), 'Wing_R', 'gold')
    pauldrons(P, 'red', 'gold', z=2.62, w=.72)

# ------------------------------------------------------------------ Crown Shieldbearer (Crown's Shield, ice)
def shieldbearer_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(190, 200, 210))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((244, 242, 236), pos, 6, .03)
    t = tabard(ROYAL_BLUE, GOLD, GOLD, half=.64)(part, n, pos)
    if t:
        return t
    return plate_paint((226, 222, 210), (190, 186, 174))(n, pos)

def shieldbearer_props(P):
    P.mat('ivory', IVORY, .3, .3); P.mat('gold', GOLD, .25, .9); P.mat('red', CRIMSON, .7); P.mat('ice', ICE, .1, 0, 1.8)
    P.mat('steel', (200, 204, 214), .3, .7)
    # Huge crest shield: ivory field, crimson border, gold crown, ice gems.
    rows = [(.7, .8), (1.3, 1.25), (1.5, 1.75), (1.5, 2.25), (1.5, 2.75), (1.3, 3.2), (.9, 3.55)]
    for k, (w, z) in enumerate(rows):
        P.box(f'crest rim {k}', (1.44, -.2, z), (.1, w + .16, .52), 'Wing_R', 'red')
        P.box(f'crest field {k}', (1.5, -.2, z), (.06, w, .5), 'Wing_R', 'ivory')
    P.box('crest crown band', (1.54, -.2, 2.2), (.04, .9, .2), 'Wing_R', 'gold')
    for y, top in ((-.56, .5), (-.2, .7), (.16, .5)):
        P.box(f'crest crown {y}', (1.54, y, 2.3 + top / 2), (.04, .18, top), 'Wing_R', 'gold')
    for y in (-.56, -.2, .16):
        P.box(f'crest gem {y}', (1.56, y, 2.2), (.03, .12, .12), 'Wing_R', 'ice')
    # Gold sallet helm with a blue-ice gem.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .16), (1.56, 1.56, .36), 'Head', 'gold')
    P.box('helm top', (0, HEAD_Y + .05, HEAD_TOP + .4), (1.1, 1.1, .14), 'Head', 'gold')
    P.box('helm gem', (0, HEAD_Y - .8, HEAD_TOP + .2), (.26, .04, .2), 'Head', 'ice')
    pauldrons(P, 'steel', 'gold', z=2.62, w=.7)

# ------------------------------------------------------------------ Royal Warden (Crown's Shield, dragon)
def warden_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(90, 40, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((236, 228, 220), pos, 6, .03)
    t = tabard(CRIMSON, GOLD, GOLD, half=.72)(part, n, pos)
    if t:
        return t
    return plate_paint((80, 50, 46), (58, 36, 34))(n, pos)

def warden_props(P):
    P.mat('iron', (96, 64, 58), .4, .6); P.mat('gold', GOLD, .25, .9); P.mat('red', CRIMSON, .7); P.mat('ember', EMBER, .3, 0, 3)
    P.mat('haft', (70, 44, 36), .8)
    # Tall warden helm with a crimson plume.
    P.box('helm', (0, HEAD_Y + .05, HEAD_TOP + .3), (1.5, 1.5, .64), 'Head', 'iron')
    P.box('helm band', (0, HEAD_Y + .05, HEAD_TOP + .04), (1.6, 1.6, .12), 'Head', 'gold')
    P.box('helm top', (0, HEAD_Y + .05, HEAD_TOP + .66), (1.1, 1.1, .1), 'Head', 'gold')
    for i in range(5):
        P.box(f'plume {i}', (0, HEAD_Y + .15 + i * .16, HEAD_TOP + .8 + i * .16), (.24, .5 - i * .05, .26), 'Head', 'red')
    # Spiked ember mace held upright.
    P.seg('mace haft', (1.42, -.1, 1.2), (1.42, -.4, 4.0), .18, .18, 'Wing_R', 'haft')
    P.box('mace head', (1.42, -.45, 4.3), (.66, .66, .66), 'Wing_R', 'iron')
    P.box('mace core', (1.42, -.45, 4.3), (.7, .3, .3), 'Wing_R', 'ember')
    for d in ((1, 0, 0), (0, 1, 0), (0, 0, 1), (0, -1, 0)):
        P.box(f'mace spike {d}', (1.42 + d[0] * .4, -.45 + d[1] * .4, 4.3 + d[2] * .4), (.18, .18, .18), 'Wing_R', 'gold')
    pauldrons(P, 'iron', 'gold', z=2.62, w=.72)

# ------------------------------------------------------------------ Storm Herald (Crown's Shield, storm)
def herald_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((246, 244, 238), pos, 6, .03)
    if part == 'Body' and is_front(n) and abs(px) < .5 and 1.5 < pz < 2.4:
        bolt = abs((px * 1.6) - (math.floor((pz - 1.5) * 4) % 2) * .3 + .1) < .14
        if bolt:
            return (g(STORM, pos, 8, .03), (180, 150, 20))  # lightning sigil
    if part == 'Body' and (is_front(n) or is_back(n)) and abs(px) < .82:
        quarter = (px > 0) == (pz > 1.95)
        return g(ROYAL_BLUE if quarter else IVORY, pos, 9, .04)  # quartered herald tabard
    return feathers((236, 232, 222), pos, n, rows=7)

def herald_props(P):
    P.mat('gold', GOLD, .2, .95); P.mat('blue', ROYAL_BLUE, .7); P.mat('storm', STORM, .2, 0, 3)
    P.mat('cap', ROYAL_BLUE, .8); P.mat('feather', IVORY, .8)
    # Long gold herald trumpet raised from the right wing, with a banner.
    P.seg('trumpet', (1.42, -.1, 2.2), (1.42, -1.6, 3.6), .14, .14, 'Wing_R', 'gold')
    P.seg('trumpet bell', (1.42, -1.6, 3.6), (1.42, -1.95, 3.93), .5, .5, 'Wing_R', 'gold')
    P.box('trumpet bell rim', (1.42, -1.98, 3.96), (.56, .06, .56), 'Wing_R', 'storm', (-43, 0, 0))
    P.box('trumpet banner', (1.42, -.95, 2.75), (.04, .7, .5), 'Wing_R', 'blue', (-43, 0, 0))
    P.box('trumpet bolt', (1.45, -.95, 2.75), (.03, .16, .32), 'Wing_R', 'storm', (-43, 15, 0))
    # Floppy herald cap with an ivory feather.
    P.box('cap', (0, HEAD_Y + .1, HEAD_TOP + .16), (1.6, 1.6, .3), 'Head', 'cap')
    P.box('cap flop', (.5, HEAD_Y + .4, HEAD_TOP + .32), (.9, 1.0, .2), 'Head', 'cap', (0, 15, 0))
    P.seg('cap feather', (-.5, HEAD_Y + .2, HEAD_TOP + .3), (-.95, HEAD_Y + .9, HEAD_TOP + 1.15), .16, .36, 'Head', 'feather')
    P.box('cap bolt', (0, HEAD_Y - .82, HEAD_TOP + .16), (.16, .04, .26), 'Head', 'storm')

# ------------------------------------------------------------------ King's Guards (The King Returns): one uniform, three elements
def kingsguard(element_color, glow_rgb, plume_color):
    def paint(part, n, pos, *a):
        px, py, pz = pos
        b = basic(part, pos, foot=(40, 40, 46))
        if b:
            return b
        if part in ('Head', 'Neck'):
            return g((244, 242, 236), pos, 6, .03)
        if part == 'Body' and pz < 1.3:
            return g((30, 30, 36), pos, 10, .03)
        if part == 'Body' and is_front(n) and abs(px) < .06:
            return g(GOLD, pos, 7, .03)
        if part == 'Body' and is_front(n) and abs(pz - 2.05) < .07 and abs(px) < .78:
            return (g(element_color, pos, 8, .03), glow_rgb)  # element sash
        if part in ('Body', 'Neck'):
            return g(CRIMSON, pos, 9, .05)  # royal guard coat
        return feathers(CRIMSON_DARK, pos, n, rows=6)
    def hat(P):
        P.mat('bearskin', (28, 26, 32), .95); P.mat('gold', GOLD, .25, .9); P.mat('plume', plume_color, .6)
        P.box('bearskin', (0, HEAD_Y + .05, HEAD_TOP + .55), (1.5, 1.5, 1.1), 'Head', 'bearskin')
        P.box('bearskin top', (0, HEAD_Y + .05, HEAD_TOP + 1.16), (1.2, 1.2, .14), 'Head', 'bearskin')
        P.box('bearskin plate', (0, HEAD_Y - .77, HEAD_TOP + .35), (.44, .04, .44), 'Head', 'gold')
        P.box('chin strap', (0, HEAD_Y - .78, 3.2), (1.2, .04, .08), 'Head', 'gold')
        P.mat('element', element_color, .3, 0, 1.2)
        for i in range(5):
            P.box(f'plume {i}', (.8, HEAD_Y - .1 + i * .04, HEAD_TOP + .5 + i * .24), (.22, .42 - i * .04, .26), 'Head', 'plume')
        for s in (-1, 1):
            wing = 'Wing_L' if s < 0 else 'Wing_R'
            P.box(f'epaulette {s}', (s * 1.2, -.05, 2.72), (.4, .7, .14), wing, 'element')
            for k in range(4):
                P.box(f'fringe {s} {k}', (s * 1.4, -.32 + k * .18, 2.58), (.05, .07, .24), wing, 'gold')
        P.box('element cape', (0, 1.52, 1.9), (1.9, .1, 1.6), 'Body', 'plume')
        P.box('element cape clasp', (0, 1.58, 2.66), (1.9, .12, .14), 'Body', 'gold')
    return paint, hat

frost_paint, frost_hat = kingsguard(ICE, (90, 180, 230), (150, 220, 255))
flame_paint, flame_hat = kingsguard(EMBER, (230, 90, 20), (255, 120, 40))
thunder_paint, thunder_hat = kingsguard(STORM, (210, 180, 30), (255, 226, 70))

def frost_props(P):
    frost_hat(P)
    P.mat('ice', ICE, .1, 0, 2.2); P.mat('haft', (220, 230, 240), .4, .5)
    P.seg('ice halberd haft', (1.42, .1, .8), (1.42, -.45, 5.0), .16, .16, 'Wing_R', 'haft')
    P.box('ice axe', (1.42, -1.1, 4.35), (.16, 1.2, 1.0), 'Wing_R', 'ice', (-7, 0, 0))
    P.box('ice axe back', (1.42, -.1, 4.4), (.14, .4, .5), 'Wing_R', 'ice', (-7, 0, 0))
    P.seg('ice tip', (1.42, -.45, 5.0), (1.42, -.52, 5.6), .2, .2, 'Wing_R', 'ice')

def flame_props(P):
    flame_hat(P)
    P.mat('ember', EMBER, .3, 0, 3); P.mat('haft', (70, 40, 34), .8); P.mat('steel', (220, 224, 232), .25, .85)
    P.seg('flame halberd haft', (1.42, .1, .8), (1.42, -.45, 5.0), .16, .16, 'Wing_R', 'haft')
    P.box('flame axe', (1.42, -1.1, 4.35), (.16, 1.2, 1.0), 'Wing_R', 'steel', (-7, 0, 0))
    P.box('flame edge', (1.42, -1.72, 4.35), (.18, .14, .98), 'Wing_R', 'ember', (-7, 0, 0))
    for k in range(3):
        P.box(f'flame tongue {k}', (1.42, -.52 + k * .02, 5.1 + k * .22), (.26 - k * .06, .26 - k * .06, .24), 'Wing_R', 'ember')

def thunder_props(P):
    thunder_hat(P)
    P.mat('storm', STORM, .2, 0, 3); P.mat('haft', (40, 60, 120), .5, .4); P.mat('steel', (220, 224, 232), .25, .85)
    P.seg('storm spear haft', (1.42, .1, .8), (1.42, -.45, 5.0), .16, .16, 'Wing_R', 'haft')
    P.seg('storm spear head', (1.42, -.45, 5.0), (1.42, -.6, 6.0), .34, .34, 'Wing_R', 'steel')
    for k, (y, z) in enumerate(((-.7, 4.1), (-1.05, 4.4), (-.8, 4.75), (-1.15, 5.05))):
        P.box(f'bolt {k}', (1.42, y, z), (.12, .5, .16), 'Wing_R', 'storm', (35, 0, 0) if k % 2 else (-35, 0, 0))

# ------------------------------------------------------------------ Armada King (boss)
def king_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Head':
        return g((250, 248, 242), pos, 6, .03)
    if part == 'Neck' or (part == 'Body' and pz > 2.55):
        u, v = plane(n, pos)
        spot = (math.floor(u * 5) + math.floor(v * 5)) % 4 == 0
        return g((30, 30, 34) if spot else (248, 246, 240), pos, 7, .02)  # ermine collar
    if part == 'Body' and is_front(n) and abs(px) < .5 and crown(px, pz, cz=1.7, s=1.3):
        return g(GOLD, pos, 8, .02)
    if part == 'Body' and pz < 1.25:
        return g(GOLD, pos, 8, .03)
    if part == 'Body':
        return g(CRIMSON, pos, 9, .05)
    u, v = plane(n, pos)
    return g((150, 24, 40) if math.floor(v * 6) % 2 else (124, 18, 32), pos, 10, .04)

def king_props(P):
    P.mat('gold', GOLD, .2, .95); P.mat('gold dark', GOLD_DARK, .25, .9); P.mat('ruby', (220, 30, 50), .1, 0, 1.5)
    P.mat('sapphire', (60, 120, 255), .1, 0, 1.5); P.mat('emerald', (40, 200, 110), .1, 0, 1.2); P.mat('velvet', (150, 20, 40), .9)
    P.mat('ermine', (248, 246, 240), .9); P.mat('spot', (30, 30, 34), .9); P.mat('orb', (255, 210, 80), .2, 0, 2.5)
    # Grand crown: band, eight points, velvet cap, cross-free orb finial.
    P.box('crown band', (0, HEAD_Y + .05, HEAD_TOP + .14), (1.64, 1.64, .3), 'Head', 'gold')
    P.box('crown velvet', (0, HEAD_Y + .05, HEAD_TOP + .42), (1.36, 1.36, .4), 'Head', 'velvet')
    for k in range(8):
        a = k / 8 * math.tau
        x, y = .72 * math.cos(a), .72 * math.sin(a)
        P.box(f'crown point {k}', (x, HEAD_Y + .05 + y, HEAD_TOP + .5), (.2, .2, .44 if k % 2 else .3), 'Head', 'gold')
    P.box('crown arch a', (0, HEAD_Y + .05, HEAD_TOP + .7), (.14, 1.4, .1), 'Head', 'gold')
    P.box('crown arch b', (0, HEAD_Y + .05, HEAD_TOP + .7), (1.4, .14, .1), 'Head', 'gold')
    P.box('crown orb', (0, HEAD_Y + .05, HEAD_TOP + .86), (.3, .3, .3), 'Head', 'gold')
    for k, (x, gem) in enumerate(((-.5, 'sapphire'), (0, 'ruby'), (.5, 'emerald'))):
        P.box(f'crown gem {k}', (x, HEAD_Y - .84, HEAD_TOP + .14), (.2, .04, .18), 'Head', gem)
    # Ermine-trimmed royal cape.
    P.box('cape', (0, 1.55, 1.85), (2.3, .14, 1.9), 'Body', 'velvet')
    P.box('cape ermine', (0, 1.6, 2.86), (2.4, .3, .3), 'Body', 'ermine')
    for k, x in enumerate((-.8, -.3, .2, .7)):
        P.box(f'ermine spot {k}', (x, 1.76, 2.88), (.08, .04, .14), 'Body', 'spot')
    for s in (-1, 1):
        P.box(f'cape side {s}', (s * 1.18, .8, 1.85), (.12, 1.4, 1.8), 'Body', 'velvet')
    # Gold scepter with a glowing orb, raised in the right wing.
    P.seg('scepter', (1.42, -.1, 1.4), (1.42, -.7, 4.4), .18, .18, 'Wing_R', 'gold')
    for z in (2.2, 3.2):
        P.seg(f'scepter ring {z}', (1.42, -.1 - (z - 1.4) * .2, z), (1.42, -.12 - (z - 1.4) * .2, z + .1), .26, .26, 'Wing_R', 'gold dark')
    P.box('scepter cradle', (1.42, -.72, 4.46), (.4, .4, .14), 'Wing_R', 'gold dark')
    P.box('scepter orb', (1.42, -.74, 4.76), (.56, .56, .56), 'Wing_R', 'orb')
    P.box('scepter orb gem', (1.42, -1.03, 4.76), (.2, .04, .2), 'Wing_R', 'ruby')
    # Gold chain of office.
    for k in range(7):
        t = (k - 3) / 3
        P.box(f'chain {k}', (t * .7, -1.25, 2.55 - (1 - t * t) * .45), (.16, .06, .12), 'Body', 'gold')
    P.box('chain medal', (0, -1.27, 1.98), (.32, .06, .32), 'Body', 'ruby')

SPECS = {
    'LoyalVanguardPaladin': dict(name='Vanguard Paladin', paint=paladin_paint, props=paladin_props, rarity='Loyalist', zone='Royal Vanguard',
                                 earn='enemy only', role='Knight', tier=3, ortho=8.8, vfx='None.'),
    'LoyalGlacierLancer': dict(name='Glacier Lancer', paint=glacier_paint, props=glacier_props, rarity='Loyalist', zone='Royal Vanguard',
                               earn='enemy only', role='IceDuck', tier=3, ortho=9.2, glow=2.2, vfx='Frost Glitter loop around the lance crystal.'),
    'LoyalDrakeKnight': dict(name='Crimson Drake Knight', paint=drake_paint, props=drake_props, rarity='Loyalist', zone='Royal Vanguard',
                             earn='enemy only', role='Dragon', tier=3, ortho=8.8, glow=2.5, vfx='Ember loop along the greatsword; Ember burst on Attack.'),
    'LoyalShieldbearer': dict(name='Crown Shieldbearer', paint=shieldbearer_paint, props=shieldbearer_props, rarity='Loyalist', zone="Crown's Shield",
                              earn='enemy only', role='IceDuck', tier=3, ortho=7.6, glow=1.8, vfx='Ice gem glint (Glitter) on Hit.'),
    'LoyalRoyalWarden': dict(name='Royal Warden', paint=warden_paint, props=warden_props, rarity='Loyalist', zone="Crown's Shield",
                             earn='enemy only', role='Dragon', tier=3, ortho=8.4, glow=2.5, vfx='Ember burst from the mace on Attack.'),
    'LoyalStormHerald': dict(name='Storm Herald', paint=herald_paint, props=herald_props, rarity='Loyalist', zone="Crown's Shield",
                             earn='enemy only', role='StormDuck', tier=3, ortho=7.8, glow=2.5, vfx='Spark burst from the trumpet bell on Attack.'),
    'LoyalFrostGuard': dict(name="King's Frost Guard", paint=frost_paint, props=frost_props, rarity='Loyalist', zone='The King Returns',
                            earn='enemy only', role='IceDuck', tier=3, ortho=9.0, glow=2.2, vfx='Frost Glitter loop on the axe.'),
    'LoyalFlameGuard': dict(name="King's Flame Guard", paint=flame_paint, props=flame_props, rarity='Loyalist', zone='The King Returns',
                            earn='enemy only', role='Dragon', tier=3, ortho=9.0, glow=2.5, vfx='Ember loop from the halberd flame.'),
    'LoyalThunderGuard': dict(name="King's Thunder Guard", paint=thunder_paint, props=thunder_props, rarity='Loyalist', zone='The King Returns',
                              earn='enemy only', role='StormDuck', tier=3, ortho=9.0, glow=2.5, vfx='Spark loop on the spear bolts.'),
    'LoyalArmadaKing': dict(name='Armada King', paint=king_paint, props=king_props, rarity='Loyalist', zone='The King Returns (boss)',
                            earn='enemy only', role='King (boss)', tier=3, ortho=8.4, glow=2.0,
                            vfx='Gold Glitter loop around the crown; scepter-orb Light pulse; Star burst on Attack.'),
}
