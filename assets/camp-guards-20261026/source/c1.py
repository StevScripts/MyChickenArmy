"""Camp guards (October 26, 2026): enemy-only chickens made for each main-route camp.
Stevin: "make unique chickens for each of the camps ... Cluck Camp can just be the normal
white chickens but the rest should be custom". Fort Roost = a frontier timber fort
(pine green, timber, straw); Ironbeak HQ = a steel army base (olive drab, riveted iron,
hazard yellow). Each guard takes the stats of the camp guard it replaces (PetCatalog)."""
import math, sys
sys.modules.pop('loyal', None)
from loyal import *

PINE = (52, 112, 64)
PINE_DARK = (34, 78, 44)
TIMBER = (150, 102, 58)
TIMBER_DARK = (104, 68, 38)
STRAW = (232, 196, 96)
STRAW_DARK = (196, 156, 64)
OLIVE = (98, 112, 62)
OLIVE_DARK = (70, 80, 44)
STEEL = (150, 156, 166)
STEEL_DARK = (96, 102, 112)
HAZARD = (250, 204, 40)
INK = (28, 28, 30)


def acorn(px, pz, cx=0.0, cz=1.9, s=1.0):
    """Fort Roost badge: a small acorn on the chest."""
    x = (px - cx) / s; z = (pz - cz) / s
    if -.2 <= z < .02 and abs(x) < .2 - (abs(z + .09) * .6):
        return 'nut'
    if .02 <= z < .16 and abs(x) < .24:
        return 'cap'
    if .16 <= z < .26 and abs(x) < .05:
        return 'cap'
    return None


def beak_plate(P, mat, rivet):
    """Riveted iron plate over the beak (the Ironbeak look)."""
    P.box('beak plate', (0, -1.86, 3.1), (.66, .78, .44), 'Beak', mat)
    P.box('beak plate tip', (0, -2.28, 3.06), (.4, .14, .3), 'Beak', mat)
    for s in (-1, 1):
        P.box(f'beak rivet {s}', (s * .2, -2.0, 3.33), (.08, .08, .06), 'Beak', rivet)


# ------------------------------------------------------------------ Roost Warden (Fort Roost, tank)
def warden_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Body' and is_front(n) and abs(px) < .72 and pz > 1.2:
        if abs(px) > .64 or pz < 1.3:
            return g(TIMBER_DARK, pos, 7, .04)
        badge = acorn(px, pz)
        if badge == 'nut':
            return g(TIMBER, pos, 8, .03)
        if badge == 'cap':
            return g(STRAW_DARK, pos, 8, .03)
        return g(PINE, pos, 9, .05)  # pine tabard
    if part == 'Body' and pz < 1.3:
        return g(TIMBER_DARK, pos, 10, .04)  # belt
    if part in ('Head', 'Neck'):
        return g((240, 236, 226), pos, 6, .04)
    return feathers((214, 196, 160), pos, n)


def warden_props(P):
    P.mat('log', TIMBER, .85); P.mat('log dark', TIMBER_DARK, .85); P.mat('rope', STRAW_DARK, .9)
    P.mat('helm', PINE_DARK, .7); P.mat('helm rim', TIMBER_DARK, .8); P.mat('feather', STRAW, .8)
    # Palisade shield on the right wing: four pointed logs lashed with rope.
    for k, y in enumerate((-.66, -.22, .22, .66)):
        P.box(f'log {k}', (1.44, y - .05, 1.9), (.16, .4, 1.5), 'Wing_R', 'log' if k % 2 else 'log dark')
        P.box(f'log tip {k}', (1.44, y - .05, 2.74), (.14, .24, .22), 'Wing_R', 'log' if k % 2 else 'log dark')
    for z in (1.5, 2.25):
        P.box(f'lashing {z}', (1.53, -.05, z), (.04, 1.72, .12), 'Wing_R', 'rope')
    # Kettle helmet in pine green with a timber rim and a straw plume.
    P.box('helm rim', (0, HEAD_Y, HEAD_TOP + .02), (1.86, 1.86, .1), 'Head', 'helm rim')
    P.box('helm', (0, HEAD_Y, HEAD_TOP + .26), (1.46, 1.46, .42), 'Head', 'helm')
    P.box('helm top', (0, HEAD_Y, HEAD_TOP + .52), (.9, .9, .12), 'Head', 'helm')
    plume(P, 'plume', (0, HEAD_Y + .2, HEAD_TOP + .5), .9, 'feather')
    pauldrons(P, 'log dark', 'rope', z=2.62, w=.66)


# ------------------------------------------------------------------ Roost Archer (Fort Roost, fighter)
def archer_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Head':
        if pz > 3.95 or is_back(n) or (is_side(n) and pz > 3.2):
            return g(PINE_DARK, pos, 6, .05)  # hood
        return g((242, 238, 228), pos, 6, .04)
    if part == 'Neck':
        return g(PINE_DARK, pos, 6, .05)
    if part == 'Body' and pz < 1.32:
        return g(TIMBER_DARK, pos, 10, .04)
    if part == 'Body' and is_front(n) and abs(px) < .6:
        badge = acorn(px, pz, cz=2.0, s=.9)
        if badge == 'nut':
            return g(TIMBER, pos, 8, .03)
        if badge == 'cap':
            return g(STRAW_DARK, pos, 8, .03)
        return g((112, 150, 72), pos, 9, .05)  # leaf-green jerkin
    return feathers((120, 150, 80), pos, n, rows=8)


def archer_props(P):
    P.mat('bow', TIMBER_DARK, .8); P.mat('string', (236, 232, 220), .9); P.mat('quiver', TIMBER, .85)
    P.mat('fletch', (214, 60, 46), .8); P.mat('hood', PINE_DARK, .8); P.mat('leaf', (96, 168, 72), .8)
    # Long bow in the left wing (curved from three segments) with its string.
    P.seg('bow lower', (-1.42, -.35, .95), (-1.42, -.62, 1.85), .14, .14, 'Wing_L', 'bow')
    P.seg('bow mid', (-1.42, -.62, 1.85), (-1.42, -.62, 2.75), .16, .16, 'Wing_L', 'bow')
    P.seg('bow upper', (-1.42, -.62, 2.75), (-1.42, -.35, 3.65), .14, .14, 'Wing_L', 'bow')
    P.seg('bow string', (-1.42, -.32, .98), (-1.42, -.32, 3.62), .03, .03, 'Wing_L', 'string')
    # Quiver of red-fletched arrows on the back.
    P.seg('quiver', (.4, 1.6, 1.5), (-.25, 1.6, 2.9), .44, .4, 'Body', 'quiver')
    for k, dx in enumerate((-.14, 0, .14)):
        P.box(f'fletch {k}', (-.3 + dx, 1.6, 3.12 + k * .04), (.1, .2, .3), 'Body', 'fletch')
    # Pointed hood tip and a leaf pinned to it.
    P.box('hood peak', (0, HEAD_Y + .55, HEAD_TOP + .12), (.9, .7, .26), 'Head', 'hood')
    P.box('hood tip', (0, HEAD_Y + .9, HEAD_TOP + .32), (.42, .36, .24), 'Head', 'hood')
    P.box('hood leaf', (.5, HEAD_Y + .1, HEAD_TOP + .1), (.08, .36, .2), 'Head', 'leaf', (0, 0, 20))


# ------------------------------------------------------------------ Roost Recruit (Fort Roost, grunt)
def recruit_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Body' and (is_front(n) or is_back(n)) and abs(px) < .7 and pz < 2.35:
        if is_front(n) and abs(px) < .3 and 1.85 < pz < 2.25:
            return g(TIMBER_DARK, pos, 8, .03)  # bib pocket
        u, v = plane(n, pos)
        stitch = (math.floor(v * 10) % 2 == 0) and abs(abs(px) - .66) < .05
        return g((60, 92, 150) if not stitch else (220, 210, 170), pos, 9, .05)  # denim overalls
    if part == 'Body' and is_front(n) and abs(abs(px) - .5) < .08:
        return g((60, 92, 150), pos, 9, .05)  # straps
    if part in ('Head', 'Neck'):
        return g((246, 242, 232), pos, 6, .04)
    u, v = plane(n, pos)
    check = (math.floor(u * 5) + math.floor(v * 5)) % 2
    return g((196, 54, 44) if check else (150, 36, 32), pos, 10, .05)  # red plaid shirt


def recruit_props(P):
    P.mat('straw', STRAW, .9); P.mat('straw dark', STRAW_DARK, .9); P.mat('band', (196, 54, 44), .8)
    P.mat('shaft', TIMBER, .85); P.mat('tine', (190, 196, 206), .3, .7)
    # Wide straw hat with a red band.
    P.box('hat brim', (0, HEAD_Y, HEAD_TOP + .02), (2.1, 2.1, .08), 'Head', 'straw')
    P.box('hat crown', (0, HEAD_Y, HEAD_TOP + .24), (1.2, 1.2, .36), 'Head', 'straw dark')
    P.box('hat band', (0, HEAD_Y, HEAD_TOP + .12), (1.24, 1.24, .1), 'Head', 'band')
    P.box('straw tuft', (.3, HEAD_Y - .6, HEAD_TOP + .5), (.06, .06, .3), 'Head', 'straw', (20, 0, 10))
    # Pitchfork held upright in the right wing.
    P.seg('fork shaft', (1.42, -.2, .6), (1.42, -.45, 4.0), .14, .14, 'Wing_R', 'shaft')
    P.box('fork bridge', (1.42, -.46, 4.05), (.1, .7, .1), 'Wing_R', 'tine')
    for k, y in enumerate((-.3, 0, .3)):
        P.box(f'fork tine {k}', (1.42, -.46 + y, 4.35), (.07, .07, .55), 'Wing_R', 'tine')


# ------------------------------------------------------------------ Ironbeak Grunt (Ironbeak HQ, tank)
def grunt_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(84, 84, 90))
    if b:
        return b
    if part == 'Body' and pz < 1.32:
        return g(INK, pos, 10, .04)
    if part == 'Body' and is_front(n) and abs(px) < .7 and 1.4 < pz < 2.6:
        if abs(px) < .5 and 1.55 < pz < 1.75:
            return g(HAZARD, pos, 7, .03)  # unit stripe
        return g(OLIVE_DARK, pos, 9, .05)  # flak vest
    if part in ('Head', 'Neck'):
        return g((214, 212, 206), pos, 6, .04)
    u, v = plane(n, pos)
    camo = field((pos[0], pos[1], pos[2]), 1.6, 31)
    return g(OLIVE if camo < .45 else (OLIVE_DARK if camo < .62 else (128, 120, 84)), pos, 10, .04)


def grunt_props(P):
    P.mat('steel', STEEL, .35, .7); P.mat('steel dark', STEEL_DARK, .4, .7); P.mat('rivet', (200, 204, 212), .3, .8)
    P.mat('hazard', HAZARD, .6); P.mat('ink', INK, .8); P.mat('visor', (130, 190, 230), .1, 0, .4)
    beak_plate(P, 'steel dark', 'rivet')
    # Steel helmet with a hazard stripe and a raised visor.
    P.box('helm', (0, HEAD_Y, HEAD_TOP + .2), (1.6, 1.6, .4), 'Head', 'steel')
    P.box('helm rim', (0, HEAD_Y, HEAD_TOP - .02), (1.74, 1.74, .08), 'Head', 'steel dark')
    P.box('helm stripe', (0, HEAD_Y, HEAD_TOP + .42), (.24, 1.62, .06), 'Head', 'hazard')
    P.box('visor', (0, HEAD_Y - .84, HEAD_TOP + .12), (1.2, .06, .24), 'Head', 'visor')
    # Riot shield: a tall steel slab with a window and rivets.
    P.box('shield', (1.44, -.12, 1.95), (.12, 1.4, 1.8), 'Wing_R', 'steel')
    P.box('shield rim', (1.5, -.12, 1.95), (.04, 1.46, 1.86), 'Wing_R', 'steel dark')
    P.box('shield window', (1.52, -.12, 2.5), (.04, .9, .28), 'Wing_R', 'visor')
    P.box('shield stripe', (1.52, -.12, 1.5), (.04, 1.4, .16), 'Wing_R', 'hazard')
    for y in (-.66, .42):
        for z in (1.2, 2.7):
            P.box(f'shield rivet {y} {z}', (1.55, y, z), (.06, .1, .1), 'Wing_R', 'rivet')
    pauldrons(P, 'steel dark', 'ink', z=2.62, w=.66)


# ------------------------------------------------------------------ Ironbeak Sapper (Ironbeak HQ, fighter)
def sapper_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(84, 84, 90))
    if b:
        return b
    if part == 'Body' and (is_front(n) or is_back(n) or is_side(n)) and 1.35 < pz < 2.7:
        if abs(pz - 1.75) < .1 or abs(pz - 2.25) < .1:
            return g((236, 236, 230), pos, 7, .02)  # reflective stripes
        return g((246, 140, 30), pos, 9, .05)  # hazard-orange vest
    if part == 'Body' and pz <= 1.35:
        return g(INK, pos, 10, .04)
    if part in ('Head', 'Neck'):
        return g((232, 228, 220), pos, 6, .04)
    return feathers((120, 126, 96), pos, n, rows=7)


def sapper_props(P):
    P.mat('hard hat', HAZARD, .5); P.mat('hard hat dark', (210, 166, 20), .5); P.mat('steel', STEEL, .35, .7)
    P.mat('steel dark', STEEL_DARK, .4, .7); P.mat('rivet', (200, 204, 212), .3, .8); P.mat('lamp', (255, 236, 160), .2, 0, 2.0)
    P.mat('pouch', OLIVE_DARK, .85)
    beak_plate(P, 'steel', 'rivet')
    # Hard hat with a ridge and a headlamp.
    P.box('hat', (0, HEAD_Y, HEAD_TOP + .22), (1.5, 1.5, .44), 'Head', 'hard hat')
    P.box('hat brim', (0, HEAD_Y - .2, HEAD_TOP + .02), (1.7, 1.9, .08), 'Head', 'hard hat dark')
    P.box('hat ridge', (0, HEAD_Y, HEAD_TOP + .48), (.2, 1.3, .1), 'Head', 'hard hat dark')
    P.box('headlamp', (0, HEAD_Y - .78, HEAD_TOP + .24), (.3, .1, .22), 'Head', 'lamp')
    # Big wrench in the right wing.
    P.seg('wrench handle', (1.42, -.1, 1.0), (1.42, -.5, 3.3), .2, .14, 'Wing_R', 'steel')
    P.box('wrench jaw', (1.42, -.55, 3.5), (.16, .7, .3), 'Wing_R', 'steel dark', (-10, 0, 0))
    P.box('wrench jaw top', (1.42, -.75, 3.72), (.16, .26, .24), 'Wing_R', 'steel dark', (-10, 0, 0))
    # Tool pouches on the belt.
    for x in (-.6, .6):
        P.box(f'pouch {x}', (x, -1.27, 1.25), (.36, .14, .3), 'Body', 'pouch')


# ------------------------------------------------------------------ Ironbeak Major (Ironbeak HQ, commander)
def major_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(70, 70, 76))
    if b:
        return b
    if part == 'Body' and pz < 1.32:
        return g(INK, pos, 10, .04)
    if part == 'Body' and is_front(n) and abs(px) < .07 and pz < 2.7:
        return g(HAZARD, pos, 7, .03)  # brass buttons
    if part == 'Body' and is_front(n) and abs(px + .45) < .2 and abs(pz - 2.35) < .12:
        return g((196, 54, 44), pos, 7, .03)  # ribbon bar
    if part in ('Body', 'Neck'):
        return g(OLIVE_DARK, pos, 9, .05)  # officer's coat
    if part == 'Head':
        return g((228, 226, 220), pos, 6, .04)
    return feathers(OLIVE, pos, n, rows=6)


def major_props(P):
    P.mat('cap', OLIVE_DARK, .7); P.mat('cap band', (196, 54, 44), .7); P.mat('visor', INK, .5)
    P.mat('brass', HAZARD, .3, .8); P.mat('steel', STEEL, .3, .8); P.mat('rivet', (200, 204, 212), .3, .8)
    P.mat('cane', TIMBER_DARK, .7); P.mat('monocle', (170, 220, 255), .1, 0, .6)
    beak_plate(P, 'steel', 'brass')
    # Peaked officer's cap with a red band and an iron-beak badge.
    P.box('cap band', (0, HEAD_Y, HEAD_TOP + .1), (1.52, 1.52, .2), 'Head', 'cap band')
    P.box('cap top', (0, HEAD_Y + .12, HEAD_TOP + .3), (1.8, 1.8, .2), 'Head', 'cap')
    P.box('cap visor', (0, HEAD_Y - .92, HEAD_TOP + .02), (1.24, .46, .06), 'Head', 'visor', (-10, 0, 0))
    P.box('cap badge', (0, HEAD_Y - .78, HEAD_TOP + .22), (.3, .04, .22), 'Head', 'brass')
    P.box('cap badge beak', (0, HEAD_Y - .8, HEAD_TOP + .18), (.12, .06, .08), 'Head', 'steel')
    # Monocle over the right eye.
    P.box('monocle', (.45, -1.58, 3.75), (.4, .04, .4), 'Head', 'monocle')
    P.box('monocle rim', (.45, -1.57, 3.98), (.42, .05, .06), 'Head', 'brass')
    # Gold shoulder boards and a riding crop.
    for s in (-1, 1):
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        P.box(f'shoulder board {s}', (s * 1.2, -.05, 2.74), (.36, .7, .12), wing, 'brass')
    P.seg('crop', (1.38, .3, 1.5), (1.38, -1.2, 3.1), .1, .1, 'Wing_R', 'cane')
    P.box('crop tip', (1.38, -1.26, 3.18), (.14, .14, .14), 'Wing_R', 'brass')


ROOST = 'Fort Roost guard (camp 2)'
IRON = 'Ironbeak HQ guard (camp 3)'
SPECS = {
    'CampRoostWarden': dict(name='Roost Warden', paint=warden_paint, props=warden_props, rarity='Camp', zone='Fort Roost',
                            earn='enemy only', role='Bucket', ortho=7.4, vfx='None.'),
    'CampRoostArcher': dict(name='Roost Archer', paint=archer_paint, props=archer_props, rarity='Camp', zone='Fort Roost',
                            earn='enemy only', role='Sailor', ortho=7.4, vfx='None.'),
    'CampRoostRecruit': dict(name='Roost Recruit', paint=recruit_paint, props=recruit_props, rarity='Camp', zone='Fort Roost',
                             earn='enemy only', role='Mallard', ortho=7.4, vfx='None.'),
    'CampIronGrunt': dict(name='Ironbeak Grunt', paint=grunt_paint, props=grunt_props, rarity='Camp', zone='Ironbeak HQ',
                          earn='enemy only', role='Bucket', ortho=7.4, vfx='None.'),
    'CampIronSapper': dict(name='Ironbeak Sapper', paint=sapper_paint, props=sapper_props, rarity='Camp', zone='Ironbeak HQ',
                           earn='enemy only', role='Sailor', ortho=7.4, vfx='None.'),
    'CampIronMajor': dict(name='Ironbeak Major', paint=major_paint, props=major_props, rarity='Camp', zone='Ironbeak HQ',
                          earn='enemy only', role='Viking', ortho=7.4, glow=1.0, vfx='None.'),
}
