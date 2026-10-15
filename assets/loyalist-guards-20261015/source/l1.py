"""Loyalist tier 1 (Veteran): Scout Landing, Iron Drop, Veteran Assault guards.
Enemy-only mission guards; never rollable."""
import math, sys
sys.modules.pop('loyal', None)
from loyal import *

# ------------------------------------------------------------------ Crate Scout (Scout Landing, tank)
SCOUT_TAN = (206, 168, 112)

def cratescout_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Neck' or (part == 'Body' and pz > 2.62):
        return g(CRIMSON, pos, 6, .05)  # scout scarf
    t = tabard((150, 112, 66), (110, 78, 44), GOLD, half=.6)(part, n, pos)
    if t:
        return t
    if part == 'Head':
        return g((236, 222, 196), pos, 6, .04)
    return feathers(SCOUT_TAN, pos, n)

def cratescout_props(P):
    P.mat('plank', (178, 128, 70), .85); P.mat('plank dark', (138, 94, 50), .85); P.mat('band', IRON, .4, .5)
    P.mat('cap', CRIMSON, .8); P.mat('cap dark', CRIMSON_DARK, .8); P.mat('badge', GOLD, .3, .7)
    # Crate-lid shield on the right wing: three planks, two iron bands, a stencilled X brace.
    for k, z in enumerate((1.5, 1.86, 2.22)):
        P.box(f'lid plank {k}', (1.42, -.05, z), (.1, 1.2, .34), 'Wing_R', 'plank' if k % 2 else 'plank dark')
    for y in (-.5, .4):
        P.box(f'lid band {y}', (1.48, y, 1.86), (.06, .1, 1.12), 'Wing_R', 'band')
    P.seg('lid brace', (1.49, -.42, 1.42), (1.49, .32, 2.3), .05, .1, 'Wing_R', 'plank dark')
    # Soft scout cap with a short brim and a gold badge.
    P.box('cap crown', (0, HEAD_Y + .05, HEAD_TOP + .14), (1.46, 1.46, .28), 'Head', 'cap')
    P.box('cap top', (0, HEAD_Y + .1, HEAD_TOP + .32), (1.1, 1.1, .1), 'Head', 'cap dark')
    P.box('cap brim', (0, HEAD_Y - .86, HEAD_TOP + .02), (1.2, .5, .06), 'Head', 'cap dark')
    P.box('cap badge', (0, HEAD_Y - .74, HEAD_TOP + .16), (.22, .04, .2), 'Head', 'badge')
    # Small supply crate on the back.
    P.box('back crate', (0, 1.62, 2.1), (1.1, .4, .9), 'Body', 'plank')
    P.box('back crate band', (0, 1.84, 2.1), (1.14, .04, .12), 'Body', 'band')

# ------------------------------------------------------------------ Spyglass Scout (Scout Landing, fighter)
def spyglass_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    t = tabard(CRIMSON, GOLD_DARK, GOLD, half=.7)(part, n, pos)
    if t:
        return t
    if part in ('Head', 'Neck'):
        return g((226, 226, 230), pos, 6, .04)
    if part == 'Body' and pz < 1.5:
        return g((96, 74, 52), pos, 10, .05)  # belt line
    return feathers((196, 198, 206), pos, n, rows=8)

def spyglass_props(P):
    P.mat('brass', (226, 172, 64), .3, .8); P.mat('brass dark', (170, 120, 40), .35, .8); P.mat('lens', (150, 210, 255), .1, 0, 1.2)
    P.mat('hat', (52, 44, 40), .8); P.mat('feather', CRIMSON, .8); P.mat('strap', (96, 66, 42), .8); P.mat('leather', (128, 88, 52), .8)
    # Spyglass raised in the right wing.
    P.seg('spyglass tube', (1.36, -.2, 2.0), (1.1, -1.7, 3.0), .26, .26, 'Wing_R', 'brass')
    P.seg('spyglass grip', (1.36, -.2, 2.0), (1.3, -.62, 2.28), .32, .32, 'Wing_R', 'brass dark')
    P.box('spyglass ring', (1.14, -1.45, 2.84), (.34, .1, .34), 'Wing_R', 'brass dark', (22, 0, 0))
    P.box('spyglass ring b', (1.24, -.95, 2.51), (.32, .08, .32), 'Wing_R', 'brass dark', (22, 0, 0))
    P.box('spyglass lens', (1.09, -1.73, 3.03), (.2, .04, .2), 'Wing_R', 'lens', (22, 0, 0))
    # Wide-brim scout hat with a crimson feather.
    P.box('hat brim', (0, HEAD_Y, HEAD_TOP + .03), (1.95, 1.95, .08), 'Head', 'hat')
    P.box('hat crown', (0, HEAD_Y, HEAD_TOP + .26), (1.2, 1.2, .4), 'Head', 'hat')
    P.box('hat band', (0, HEAD_Y, HEAD_TOP + .12), (1.24, 1.24, .1), 'Head', 'feather')
    P.seg('hat feather', (.55, HEAD_Y + .3, HEAD_TOP + .3), (.85, HEAD_Y + .9, HEAD_TOP + 1.0), .14, .3, 'Head', 'feather')
    # Satchel on a cross strap.
    P.seg('satchel strap', (.7, -1.24, 2.85), (-.75, -1.24, 1.35), .14, .05, 'Body', 'strap')
    P.box('satchel', (-.92, -.6, 1.4), (.36, .7, .5), 'Body', 'leather')

# ------------------------------------------------------------------ Drop Trooper (Iron Drop, tank)
def trooper_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(96, 100, 108))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((214, 210, 202), pos, 6, .04)
    if part == 'Body' and is_front(n) and (abs(abs(px) - .5) < .09 or abs(pz - 1.55) < .07):
        return g((70, 56, 40), pos, 7, .04)  # drop harness straps
    t = tabard(IRON_DARK, CRIMSON, CRIMSON, half=.78)(part, n, pos)
    if t:
        return t
    return feathers((160, 160, 166), pos, n)

def trooper_props(P):
    P.mat('iron', IRON, .45, .6); P.mat('iron dark', IRON_DARK, .5, .6); P.mat('rivet', (196, 200, 208), .3, .8)
    P.mat('canvas', (126, 120, 88), .9); P.mat('canvas dark', (96, 90, 64), .9); P.mat('red', CRIMSON, .7)
    # Riveted iron pot helmet with a chin strap.
    P.box('pot rim', (0, HEAD_Y, HEAD_TOP - .02), (1.68, 1.68, .16), 'Head', 'iron dark')
    P.box('pot body', (0, HEAD_Y, HEAD_TOP + .22), (1.5, 1.5, .4), 'Head', 'iron')
    P.box('pot lid', (0, HEAD_Y, HEAD_TOP + .48), (1.06, 1.06, .12), 'Head', 'iron dark')
    for k in range(6):
        a = k / 6 * math.tau
        P.box(f'rivet {k}', (.76 * math.cos(a), HEAD_Y + .76 * math.sin(a), HEAD_TOP + .22), (.1, .1, .1), 'Head', 'rivet')
    P.box('pot stripe', (0, HEAD_Y - .76, HEAD_TOP + .3), (.5, .04, .12), 'Head', 'red')
    for s in (-1, 1):
        P.box(f'chin strap {s}', (s * .72, HEAD_Y - .2, 3.3), (.04, .1, 1.0), 'Head', 'canvas dark')
    # Drop pack with folded chute and a ripcord handle.
    P.box('drop pack', (0, 1.66, 2.05), (1.4, .5, 1.3), 'Body', 'canvas')
    P.box('drop pack flap', (0, 1.94, 2.45), (1.3, .08, .5), 'Body', 'canvas dark')
    P.box('ripcord', (.68, -1.25, 2.3), (.16, .1, .26), 'Body', 'red')
    # Round iron buckler on the right wing.
    for k, (w, z) in enumerate([(.4, 1.5), (.72, 1.68), (.82, 1.9), (.72, 2.12), (.4, 2.3)]):
        P.box(f'buckler {k}', (1.4, -.1, z), (.08, w, .22), 'Wing_R', 'iron')
    P.box('buckler boss', (1.46, -.1, 1.9), (.06, .26, .26), 'Wing_R', 'rivet')

# ------------------------------------------------------------------ Anvil Brute (Iron Drop, heavy)
def anvil_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(84, 84, 90))
    if b:
        return b
    if part == 'Body' and (is_front(n)) and abs(px) < .78 and pz < 2.5:
        if abs(px) > .7 or pz < 1.12:
            return g((70, 46, 30), pos, 7, .04)
        if crown(px, pz, cz=1.7):
            return g(GOLD, pos, 8)
        return g((112, 76, 46), pos, 9, .06)  # smith's apron
    if part in ('Head', 'Neck'):
        return g((180, 176, 172), pos, 6, .05)
    return feathers((96, 96, 104), pos, n, rows=6, dark=.86)

def anvil_props(P):
    P.mat('iron', IRON, .45, .65); P.mat('iron dark', IRON_DARK, .5, .65); P.mat('haft', (110, 72, 40), .85)
    P.mat('wrap', CRIMSON, .8); P.mat('gold', GOLD, .3, .8); P.mat('ember', (255, 120, 40), .4, 0, 2.5)
    # Big anvil-headed war hammer held upright in the right wing.
    P.seg('hammer haft', (1.42, -.2, .9), (1.42, -.55, 4.2), .2, .2, 'Wing_R', 'haft')
    P.seg('hammer wrap', (1.42, -.27, 1.55), (1.42, -.33, 2.1), .26, .26, 'Wing_R', 'wrap')
    P.box('anvil base', (1.42, -.58, 4.25), (.66, .9, .3), 'Wing_R', 'iron dark', (-6, 0, 0))
    P.box('anvil waist', (1.42, -.6, 4.5), (.5, .6, .24), 'Wing_R', 'iron dark', (-6, 0, 0))
    P.box('anvil face', (1.42, -.66, 4.78), (.72, 1.5, .36), 'Wing_R', 'iron', (-6, 0, 0))
    P.box('anvil horn', (1.42, -1.62, 4.84), (.4, .5, .22), 'Wing_R', 'iron', (-6, 0, 0))
    P.box('anvil horn tip', (1.42, -2.0, 4.86), (.22, .3, .14), 'Wing_R', 'iron', (-6, 0, 0))
    P.box('anvil hot edge', (1.42, -.66, 4.97), (.74, 1.3, .04), 'Wing_R', 'ember', (-6, 0, 0))
    # Heavy iron pauldrons and a brow guard.
    pauldrons(P, 'iron dark', 'gold', z=2.6, w=.7)
    P.box('brow guard', (0, HEAD_Y - .2, HEAD_TOP + .04), (1.56, 1.3, .2), 'Head', 'iron dark')
    P.box('brow ridge', (0, HEAD_Y - .2, HEAD_TOP + .2), (.2, 1.3, .14), 'Head', 'gold')

# ------------------------------------------------------------------ Veteran Sergeant (Veteran Assault, heavy)
def sergeant_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Head':
        if is_front(n) and abs(px - .38) < .05 and 3.1 < pz < 3.9:
            return (150, 70, 70)  # old scar
        return g((236, 230, 220), pos, 6, .04)
    if part == 'Body' and pz < 1.32:
        return g((40, 34, 32), pos, 10, .04)  # belt
    if part == 'Body' and is_front(n) and abs(px) < .07:
        return g(GOLD, pos, 7, .03)  # coat buttons line
    if part in ('Body', 'Neck'):
        return g(CRIMSON, pos, 9, .05)
    return feathers(CRIMSON_DARK, pos, n, rows=6)

def sergeant_props(P):
    P.mat('gold', GOLD, .3, .8); P.mat('gold dark', GOLD_DARK, .35, .8); P.mat('cap', (34, 30, 40), .7)
    P.mat('patch', (24, 22, 24), .8); P.mat('ribbon', (60, 120, 210), .7); P.mat('silver', (210, 214, 222), .3, .8)
    # Peaked officer cap.
    P.box('cap band', (0, HEAD_Y, HEAD_TOP + .1), (1.5, 1.5, .2), 'Head', 'gold dark')
    P.box('cap top', (0, HEAD_Y + .1, HEAD_TOP + .3), (1.7, 1.7, .2), 'Head', 'cap')
    P.box('cap visor', (0, HEAD_Y - .9, HEAD_TOP + .02), (1.2, .45, .06), 'Head', 'cap', (-10, 0, 0))
    P.box('cap crown', (0, HEAD_Y - .78, HEAD_TOP + .14), (.3, .04, .22), 'Head', 'gold')
    # Eyepatch over the left eye.
    P.box('eyepatch', (.45, -1.6, 3.75), (.5, .08, .52), 'Head', 'patch')
    P.seg('eyepatch strap', (.7, -1.57, 4.02), (-.72, -1.56, 3.6), .08, .06, 'Head', 'patch')
    P.box('eyepatch strap side', (-.73, -1.0, 3.6), (.06, 1.1, .08), 'Head', 'patch')
    # Gold epaulettes with fringe, two medals.
    for s in (-1, 1):
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        P.box(f'epaulette {s}', (s * 1.2, -.05, 2.72), (.36, .66, .14), wing, 'gold')
        for k in range(4):
            P.box(f'fringe {s} {k}', (s * 1.38, -.32 + k * .18, 2.58), (.05, .07, .22), wing, 'gold dark')
    for k, (x, rib) in enumerate([(.42, 'ribbon'), (.7, 'silver')]):
        P.box(f'medal ribbon {k}', (x, -1.26, 2.42), (.2, .06, .22), 'Body', rib)
        P.box(f'medal {k}', (x, -1.29, 2.18), (.2, .06, .2), 'Body', 'gold')
    P.seg('sash', (-.95, -1.25, 2.8), (.95, -1.25, 1.3), .2, .05, 'Body', 'gold dark')
    P.mat('blade', (220, 226, 236), .25, .85)
    P.seg('sabre blade', (1.38, .1, 1.7), (1.38, -1.5, 3.3), .08, .16, 'Wing_R', 'blade')
    P.box('sabre guard', (1.38, .02, 1.78), (.12, .2, .36), 'Wing_R', 'gold', (-45, 0, 0))
    P.seg('sabre grip', (1.38, .02, 1.78), (1.38, .32, 1.48), .12, .12, 'Wing_R', 'cap')

# ------------------------------------------------------------------ Assault Lancer (Veteran Assault, fighter)
def lancer_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(150, 154, 164))
    if b:
        return b
    t = tabard(CRIMSON, GOLD, GOLD, half=.72)(part, n, pos)
    if t:
        return t
    if part in ('Head', 'Neck'):
        return g((238, 234, 226), pos, 6, .04)
    u, v = plane(n, pos)
    mail = (math.floor(u * 9) + math.floor(v * 9)) % 2
    return g((158, 164, 172) if mail else (128, 134, 142), pos, 10, .04)

def lancer_props(P):
    P.mat('steel', (178, 184, 194), .3, .7); P.mat('steel dark', (118, 124, 134), .35, .7); P.mat('red', CRIMSON, .7)
    P.mat('shaft', (150, 104, 60), .8); P.mat('gold', GOLD, .3, .8)
    # Half-helm with a cheek guard and a crimson plume.
    P.box('helm', (0, HEAD_Y + .1, HEAD_TOP + .16), (1.52, 1.4, .32), 'Head', 'steel')
    P.box('helm back', (0, HEAD_Y + .72, 3.65), (1.5, .14, 1.1), 'Head', 'steel dark')
    for s in (-1, 1):
        P.box(f'cheek {s}', (s * .74, HEAD_Y + .2, 3.55), (.1, .9, .8), 'Head', 'steel dark')
    for i in range(5):
        P.box(f'plume {i}', (0, HEAD_Y + .2 + i * .14, HEAD_TOP + .42 + i * .2), (.22, .5 - i * .05, .26), 'Head', 'red')
    # Lance raised at a forward slant, with a vamplate and a pennant.
    P.seg('lance', (1.4, .7, 1.2), (1.4, -1.5, 4.9), .2, .2, 'Wing_R', 'shaft')
    P.seg('lance tip', (1.4, -1.5, 4.9), (1.4, -1.78, 5.5), .16, .16, 'Wing_R', 'steel')
    for k, w in enumerate((.66, .5, .34)):
        P.box(f'vamplate {k}', (1.4, -.12 - k * .1, 2.35 + k * .17), (w, .14, w), 'Wing_R', 'steel dark', (-31, 0, 0))
    P.box('pennant', (1.4, -1.0, 4.35), (.04, .7, .44), 'Wing_R', 'red', (-31, 0, 0))
    P.box('pennant tail', (1.4, -.62, 4.0), (.04, .3, .24), 'Wing_R', 'red', (-31, 0, 0))
    P.box('pennant crown', (1.43, -1.0, 4.35), (.03, .26, .18), 'Wing_R', 'gold', (-31, 0, 0))

# ------------------------------------------------------------------ Mortar Hen (Veteran Assault, splash)
def mortar_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos)
    if b:
        return b
    if part == 'Body' and is_front(n) and abs(pz - 1.95) < .14:
        return g((92, 70, 40), pos, 7, .04)  # shell bandolier
    t = tabard((92, 98, 70), CRIMSON, GOLD, half=.76)(part, n, pos)
    if t:
        return t
    if part in ('Head', 'Neck'):
        return g((214, 136, 72), pos, 6, .05)
    return feathers((190, 112, 58), pos, n)

def mortar_props(P):
    P.mat('tube', (104, 120, 84), .5, .4); P.mat('tube dark', (66, 76, 54), .5, .4); P.mat('brass', (226, 172, 64), .3, .8)
    P.mat('lens', (255, 196, 90), .1, 0, 1.0); P.mat('strap', (70, 52, 36), .8); P.mat('shell', (200, 160, 70), .35, .7)
    P.mat('glow', (255, 140, 50), .3, 0, 2.2)
    # Mortar tube on a shoulder cradle, angled up and forward.
    P.box('cradle', (.95, .55, 2.75), (.5, .9, .32), 'Body', 'tube dark')
    P.seg('mortar tube', (.95, 1.2, 2.6), (.95, -.35, 4.3), .56, .56, 'Body', 'tube')
    P.seg('mortar band', (.95, .6, 3.27), (.95, .45, 3.43), .64, .64, 'Body', 'brass')
    P.seg('mortar muzzle', (.95, -.25, 4.19), (.95, -.45, 4.41), .7, .7, 'Body', 'tube dark')
    P.box('muzzle glow', (.95, -.47, 4.43), (.42, .04, .42), 'Body', 'glow', (-48, 0, 0))
    # Shells on the bandolier.
    for k, x in enumerate((-.55, -.28, 0, .28, .55)):
        P.box(f'shell {k}', (x, -1.27, 1.95), (.14, .08, .26), 'Body', 'shell')
    # Brass goggles pushed up on the head.
    P.box('goggle strap', (0, HEAD_Y, HEAD_TOP - .05), (1.5, 1.5, .14), 'Head', 'strap')
    for s in (-1, 1):
        P.box(f'goggle {s}', (s * .32, HEAD_Y - .72, HEAD_TOP + .02), (.42, .2, .34), 'Head', 'brass')
        P.box(f'goggle lens {s}', (s * .32, HEAD_Y - .83, HEAD_TOP + .02), (.28, .04, .22), 'Head', 'lens')

VET = 'Veteran (tier 1 mission guard)'
SPECS = {
    'LoyalCrateScout': dict(name='Crate Scout', paint=cratescout_paint, props=cratescout_props, rarity='Loyalist', zone='Scout Landing',
                            earn='enemy only', role='Bucket', tier=1, ortho=7.0, vfx='None.'),
    'LoyalSpyglassScout': dict(name='Spyglass Scout', paint=spyglass_paint, props=spyglass_props, rarity='Loyalist', zone='Scout Landing',
                               earn='enemy only', role='Viking', tier=1, ortho=7.0, vfx='None.'),
    'LoyalDropTrooper': dict(name='Drop Trooper', paint=trooper_paint, props=trooper_props, rarity='Loyalist', zone='Iron Drop',
                             earn='enemy only', role='Bucket', tier=1, ortho=7.0, vfx='None.'),
    'LoyalAnvilBrute': dict(name='Anvil Brute', paint=anvil_paint, props=anvil_props, rarity='Loyalist', zone='Iron Drop',
                            earn='enemy only', role='Knight', tier=1, ortho=8.4, glow=2.0,
                            vfx='Ember sparks from the hot anvil edge on Attack (burst).'),
    'LoyalSergeant': dict(name='Veteran Sergeant', paint=sergeant_paint, props=sergeant_props, rarity='Loyalist', zone='Veteran Assault',
                          earn='enemy only', role='Knight', tier=1, ortho=7.0, vfx='None.'),
    'LoyalLancer': dict(name='Assault Lancer', paint=lancer_paint, props=lancer_props, rarity='Loyalist', zone='Veteran Assault',
                        earn='enemy only', role='Viking', tier=1, ortho=8.6, vfx='None.'),
    'LoyalMortarHen': dict(name='Mortar Hen', paint=mortar_paint, props=mortar_props, rarity='Loyalist', zone='Veteran Assault',
                           earn='enemy only', role='Wizard', tier=1, ortho=7.8, glow=2.0,
                           vfx='Smoke puff + Ember burst from the muzzle on Attack.'),
}
