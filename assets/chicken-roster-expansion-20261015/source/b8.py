"""Batch 8 — round two: Rare, Epic and two Legendary chickens."""
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

def voxel_disc(P, label, x, y, zc, mat, bone, rim=None, scale=1.0):
    for k, (w, dz) in enumerate([(.56, -.42), (.86, -.22), (1.0, 0), (.86, .22), (.56, .42)]):
        if rim:
            P.box(f'{label} rim {k}', (x - .05, y, zc + dz * scale), (.08, (w + .12) * scale, .24 * scale), bone, rim)
        P.box(f'{label} {k}', (x, y, zc + dz * scale), (.08, w * scale, .22 * scale), bone, mat)

# ------------------------------------------------------------------ Police
def police_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(34, 34, 38))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and abs(pz - 1.42) < .08:
        return (24, 24, 28) if not (is_front(n) and abs(px) < .12) else (236, 192, 64)
    if part == 'Body' and is_front(n) and abs(px) < .04 and pz > 1.5:
        return (20, 26, 52)
    return g((34, 46, 92), pos, 7, .04)

def police_props(P):
    P.mat('navy', (30, 40, 82), .55); P.mat('visor', (20, 20, 24), .25); P.mat('gold', (240, 196, 64), .3, .7)
    P.mat('radio', (36, 36, 40), .5); P.mat('check', (250, 250, 250), .6)
    P.box('cap', (0, HEAD_Y, HEAD_TOP + .14), (1.52, 1.52, .28), 'Head', 'navy')
    P.box('cap top', (0, HEAD_Y + .04, HEAD_TOP + .3), (1.66, 1.74, .1), 'Head', 'navy')
    for k in range(6):
        P.box(f'cap check {k}', (-.62 + k * .25, HEAD_Y - .77, HEAD_TOP + .1), (.12, .03, .1), 'Head', 'check')
    P.box('cap visor', (0, HEAD_Y - .92, HEAD_TOP + .02), (1.12, .42, .06), 'Head', 'visor')
    P.box('cap badge', (0, HEAD_Y - .78, HEAD_TOP + .22), (.22, .05, .2), 'Head', 'gold')
    P.box('chest star a', (-.52, -1.26, 2.12), (.26, .05, .26), 'Body', 'gold')
    P.box('chest star b', (-.52, -1.26, 2.12), (.26, .05, .26), 'Body', 'gold', (0, 45, 0))
    P.box('radio', (.82, -.9, 2.98), (.24, .2, .32), 'Body', 'radio')
    P.box('radio antenna', (.88, -.9, 3.24), (.05, .05, .24), 'Body', 'radio')

# ------------------------------------------------------------------ Doctor
def doctor_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(236, 236, 240))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px) < .12 + (2.9 - pz) * .18:
        return g((62, 172, 172), pos, 7)  # scrubs in the open coat
    if part == 'Body' and is_front(n) and abs(px - .62) < .2 and abs(pz - 2.2) < .03:
        return (200, 204, 210)  # pocket seam
    return g((250, 250, 250), pos, 8, .02)

def doctor_props(P):
    P.mat('band', (70, 72, 80), .5); P.mat('mirror', (214, 220, 228), .1, .9); P.mat('tube', (50, 52, 58), .5)
    P.mat('steel', (190, 196, 204), .2, .9); P.mat('pen', (40, 90, 200), .4)
    P.box('mirror band', (0, HEAD_Y, 4.14), (1.46, 1.46, .1), 'Head', 'band')
    P.box('head mirror', (.24, -1.56, 4.15), (.36, .06, .36), 'Head', 'mirror')
    P.box('head mirror b', (.24, -1.56, 4.15), (.36, .06, .36), 'Head', 'mirror', (0, 45, 0))
    for s in (-1, 1):
        P.seg(f'stetho {s}', (s * .5, -.9, 2.92), (s * .38, -1.28, 2.35), .08, .08, 'Body', 'tube')
    P.seg('stetho low', (-.38, -1.28, 2.35), (.15, -1.3, 2.0), .07, .07, 'Body', 'tube')
    P.box('stetho piece', (.2, -1.32, 1.96), (.2, .06, .2), 'Body', 'steel')
    P.box('pen', (.55, -1.25, 2.3), (.05, .05, .26), 'Body', 'pen')

# ------------------------------------------------------------------ Ghost
def ghost_paint(part, n, pos, *a):
    px, py, pz = pos
    base = (176, 242, 252)
    if feet(part):
        c = (120, 210, 236)
        return c, shade(c, .5)
    if part in ('Beak', 'Wattle'):
        c = (150, 230, 246)
        return g(c, pos, 4, .03), shade(c, .6)
    u, v = plane(n, pos)
    c = base
    if part == 'Body' or part.startswith('Wing'):
        flame = 1.32 + .16 * abs(math.sin(u * 4.2))
        if pz < flame:
            c = (110, 214, 240)
    if field(pos, 2.4, 5) > .6:
        c = shade(c, 1.05)
    return g(c, pos, 6, .03), shade(c, .62)

def ghost_eye(part):
    if 'Highlight' in part:
        return (40, 60, 110)
    return (18, 24, 56)

def ghost_props(P):
    P.mat('wisp', (140, 226, 246), .4, 0, 2.5)
    for k, (x, y, z, s) in enumerate([(-.6, 1.2, .95, .3), (.2, 1.4, .82, .26), (.7, 1.0, .9, .22), (-.1, 1.62, .7, .18)]):
        P.box(f'wisp {k}', (x, y, z), (s, s, s * 1.3), 'Body', 'wisp', (k * 10, k * 20, 0))
    P.box('ghost tail', (0, 1.62, 1.3), (1.0, .3, .5), 'Body', 'wisp')
    P.box('ghost tail tip', (0, 1.86, 1.05), (.5, .26, .3), 'Body', 'wisp')

# ------------------------------------------------------------------ Archer
GREEN = (62, 112, 52)

def archer_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(104, 70, 40))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and abs(pz - 1.55) < .07:
        return g((110, 72, 40), pos, 7)
    return g(GREEN, pos, 8, .06)

def archer_props(P):
    P.mat('hood', (56, 102, 46), .85); P.mat('hood dark', (44, 82, 36), .85); P.mat('leather', (124, 80, 42), .7)
    P.mat('wood', (150, 100, 52), .7); P.mat('string', (236, 232, 220), .6); P.mat('fletch', (250, 250, 248), .7)
    P.mat('arrow', (190, 150, 96), .7)
    P.box('hood top', (0, HEAD_Y + .05, HEAD_TOP + .1), (1.6, 1.62, .22), 'Head', 'hood')
    P.box('hood back', (0, HEAD_Y + .84, 3.6), (1.6, .14, 1.6), 'Head', 'hood dark')
    for s in (-1, 1):
        P.box(f'hood side {s}', (s * .82, HEAD_Y + .2, 3.75), (.14, 1.2, 1.2), 'Head', 'hood')
    P.seg('hood point', (0, HEAD_Y + .7, HEAD_TOP + .1), (0, HEAD_Y + 1.25, HEAD_TOP - .3), .4, .3, 'Head', 'hood dark')
    P.box('quiver', (.4, 1.6, 2.6), (.42, .38, 1.3), 'Body', 'leather', (0, 18, 0))
    for k, x in enumerate((.22, .4, .58)):
        P.seg(f'arrow {k}', (x + .1, 1.6, 3.1), (x + .3, 1.62, 3.75), .05, .05, 'Body', 'arrow')
        P.box(f'fletch {k}', (x + .3, 1.62, 3.72), (.12, .04, .2), 'Body', 'fletch', (0, 18, 0))
    pts = [(1.42, -.55, 1.15), (1.42, -.78, 1.8), (1.42, -.8, 2.5), (1.42, -.55, 3.1)]
    for k in range(3):
        P.seg(f'bow {k}', pts[k], pts[k + 1], .11, .11, 'Wing_R', 'wood')
    P.seg('bow string', pts[0], pts[-1], .03, .03, 'Wing_R', 'string')

# ------------------------------------------------------------------ Rockstar
def rock_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(28, 28, 32))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and is_front(n) and abs(px) < .36:
        if abs(px - (pz - 2.0) * .3) < .07 and 1.5 < pz < 2.5:
            return (224, 36, 44)  # lightning stripe on the tee
        return g((244, 244, 244), pos, 7)
    u, v = plane(n, pos)
    if (part.startswith('Wing') and pz > 2.45) or (part == 'Body' and pz > 2.72):
        if (math.floor(u * 9) % 3 == 0) and (math.floor(v * 9) % 3 == 0):
            return (200, 204, 212)  # studs
    return g((34, 34, 38), pos, 8, .05)

def rock_props(P):
    P.mat('hair', (24, 22, 26), .5); P.mat('shades', (14, 14, 18), .15, .3); P.mat('guitar', (210, 30, 40), .25)
    P.mat('neck', (120, 80, 44), .6); P.mat('pick guard', (250, 250, 250), .4); P.mat('metal', (200, 204, 212), .2, .9)
    P.box('hair base', (0, HEAD_Y + .05, HEAD_TOP + .08), (1.5, 1.5, .16), 'Head', 'hair')
    for k, (x, y, tz, lean) in enumerate([(-.4, -.4, .7, -.3), (0, -.45, .85, 0), (.4, -.4, .7, .3), (-.2, .2, .65, -.2), (.25, .25, .7, .25)]):
        P.seg(f'spike {k}', (x, HEAD_Y + y, HEAD_TOP + .1), (x + lean * .4, HEAD_Y + y + .35, HEAD_TOP + tz), .26, .26, 'Head', 'hair')
    for s in (-1, 1):
        P.box(f'lens {s}', (s * .445, -1.56, 3.78), (.52, .06, .36), 'Head', 'shades')
    P.box('shades bridge', (0, -1.56, 3.86), (.4, .06, .08), 'Head', 'shades')
    P.box('guitar body', (.15, 1.6, 1.9), (.95, .16, .8), 'Body', 'guitar', (0, 25, 0))
    P.box('guitar guard', (.2, 1.69, 1.85), (.4, .04, .3), 'Body', 'pick guard', (0, 25, 0))
    P.seg('guitar neck', (-.05, 1.62, 2.25), (-.55, 1.62, 3.45), .14, .1, 'Body', 'neck')
    P.box('guitar head', (-.6, 1.62, 3.56), (.2, .12, .26), 'Body', 'metal', (0, 25, 0))

# ------------------------------------------------------------------ Yeti
def yeti_paint(part, n, pos, *a):
    px, py, pz = pos
    if feet(part):
        return g((120, 180, 240), pos, 3), (20, 50, 90)
    if part == 'Beak':
        return g((176, 196, 220), pos, 4)
    if part == 'Wattle':
        return g((150, 190, 232), pos, 5)
    if part == 'Head' and is_front(n) and pz < 4.08 and abs(px) < .62:
        return g((150, 192, 232), pos, 6, .04)
    u, v = plane(n, pos)
    strand = h(math.floor(u * 9), 0, 7 + len(part))
    c = mix((236, 244, 252), (196, 214, 236), strand * .7 if (v * 2.2 + strand) % 1 < .5 else .1)
    return g(c, pos, 7, .04)

def yeti_props(P):
    P.mat('fur', (238, 244, 252), .95); P.mat('fur shade', (206, 222, 240), .95); P.mat('horn', (236, 230, 210), .5)
    for s in (-1, 1):
        P.seg(f'horn a {s}', (s * .72, HEAD_Y + .1, 4.1), (s * 1.0, HEAD_Y + .1, 4.42), .2, .2, 'Head', 'horn')
        P.seg(f'horn b {s}', (s * .98, HEAD_Y + .1, 4.4), (s * .9, HEAD_Y - .15, 4.62), .14, .14, 'Head', 'horn')
        for k in range(4):
            P.box(f'wing shag {s} {k}', (s * 1.3, -.6 + k * .5, 1.18), (.1, .36, .3 + (k % 2) * .12), f'Wing_{"L" if s < 0 else "R"}', 'fur shade')
    P.box('head shag', (0, HEAD_Y + .08, HEAD_TOP + .12), (1.56, 1.5, .26), 'Head', 'fur')
    for k, x in enumerate((-.5, -.15, .2, .55)):
        P.box(f'brow shag {k}', (x, -1.56, 4.18), (.3, .1, .2 + (k % 2) * .1), 'Head', 'fur shade')
    for k, (x, y) in enumerate([(-.6, -.6), (.6, -.5), (-.5, .6), (.5, .8)]):
        P.box(f'back shag {k}', (x, y, 3.02), (.6, .6, .24), 'Body', 'fur' if k % 2 else 'fur shade')

# ------------------------------------------------------------------ Mimic
def mimic_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, foot=(92, 60, 34))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    u, v = plane(n, pos)
    if not part.startswith('Wing') and abs(abs(u) - .62) < .1 and not is_side(n):
        return g((232, 186, 60), pos, 7)  # gold bands
    if part == 'Body' and is_front(n):
        if abs(px) < .2 and 1.25 < pz < 1.62:
            return (24, 18, 14) if abs(px) < .05 and pz < 1.5 else g((240, 196, 66), pos, 8)  # keyhole plate
        if 1.82 < pz < 2.18:
            tooth = (math.floor(px * 6) % 2 == 0 and pz > 2.0) or (math.floor(px * 6 + .5) % 2 == 0 and pz < 2.0)
            return (250, 250, 244) if tooth and abs(pz - 2.0) > .03 else (60, 10, 20)
    c = (146, 92, 50) if math.floor(pz * 4) % 2 else (128, 80, 42)
    if abs((pz * 4) % 1) < .1:
        c = (90, 56, 30)
    return g(c, pos, 9, .05)

def mimic_props(P):
    P.mat('lid', (140, 88, 48), .7); P.mat('gold', (240, 196, 66), .3, .7); P.mat('coin', (252, 210, 70), .25, .8)
    P.mat('tongue', (190, 40, 70), .5); P.mat('tooth', (250, 250, 244), .4)
    # Lid hinged at the back edge and propped open, with fangs along its front lip.
    hinge_y, hinge_z, ang = 1.46, 2.95, math.radians(32)
    def lid_point(y_off, z_off):
        return (hinge_y - y_off * math.cos(ang) - z_off * math.sin(ang) * -1, hinge_z + y_off * math.sin(ang) + z_off * math.cos(ang))
    cy, cz = lid_point(.78, .17)
    P.box('lid', (0, cy, cz), (2.3, 1.56, .34), 'Body', 'lid', (math.degrees(ang), 0, 0))
    for x in (-.62, .62):
        P.box(f'lid band {x}', (x, cy, cz), (.2, 1.6, .38), 'Body', 'gold', (math.degrees(ang), 0, 0))
    fy, fz = lid_point(1.5, -.05)
    for k in range(6):
        P.box(f'lid tooth {k}', (-.85 + k * .34, fy, fz - .1), (.14, .1, .22), 'Body', 'tooth', (math.degrees(ang), 0, 0))
    for k, (x, y) in enumerate([(-.5, .3), (.1, .4), (.55, .2), (-.15, .15)]):
        P.box(f'coin {k}', (x, y, 2.98), (.24, .24, .06), 'Body', 'coin', (0, 0, k * 25))
    P.box('tongue', (.1, -1.25, 1.9), (.4, .14, .4), 'Body', 'tongue', (20, 0, 0))

# ------------------------------------------------------------------ Gladiator
BRONZE = (204, 144, 62)

def glad_paint(part, n, pos, *a):
    px, py, pz = pos
    if part.startswith('Leg'):
        return g((110, 72, 40), pos, 3) if math.floor(pz * 6) % 2 else g(FEET, pos, 3)
    b = basic(part, pos, foot=(120, 80, 44))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g(WHITE_HEAD, pos, 6, .04)
    if part == 'Body' and pz < 1.45:
        u, _ = plane(n, pos)
        return g((140, 92, 50) if math.floor(u * 4.5) % 2 else (112, 72, 38), pos, 7)
    if part == 'Body' and (is_front(n) or is_top(n)):
        if is_front(n) and (abs(px) < .03 or abs(pz - 2.05) < .03):
            return shade(BRONZE, .7)
        return g(BRONZE, pos, 8, .05)
    if part.startswith('Wing') and abs(pz - 2.4) < .08:
        return g(BRONZE, pos, 9)
    return g(WHITE_HEAD, pos, 10, .04)

def glad_props(P):
    P.mat('bronze', BRONZE, .3, .7); P.mat('plume', (210, 30, 40), .8); P.mat('shield', (190, 130, 56), .35, .7)
    P.mat('shield red', (180, 30, 40), .5)
    P.box('helmet', (0, HEAD_Y + .04, HEAD_TOP + .14), (1.56, 1.56, .3), 'Head', 'bronze')
    P.box('helmet brow', (0, HEAD_Y - .8, HEAD_TOP - .04), (1.56, .12, .16), 'Head', 'bronze')
    for s in (-1, 1):
        P.box(f'cheek guard {s}', (s * .8, HEAD_Y - .3, 3.75), (.1, .7, .7), 'Head', 'bronze')
    for k in range(7):
        y = HEAD_Y - .6 + k * .2
        P.box(f'plume {k}', (0, y, HEAD_TOP + .58 + .22 * math.sin(math.pi * k / 6)), (.26, .22, .7), 'Head', 'plume')
    voxel_disc(P, 'shield', 1.43, -.05, 1.95, 'shield', 'Wing_R', rim='bronze', scale=1.1)
    P.box('shield boss', (1.49, -.05, 1.95), (.06, .3, .3), 'Wing_R', 'shield red')

# ------------------------------------------------------------------ Olympian
def olymp_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(250, 206, 70), wattle=(250, 200, 120), foot=(240, 196, 70))
    if b:
        return b
    if part in ('Head', 'Neck'):
        return g((252, 250, 244), pos, 6, .03)
    if part == 'Body' and not is_side(n) and abs(px - (pz - 2.0) * .85) < .1:
        return (244, 198, 70), (80, 60, 10)  # gold sash line
    if part.startswith('Wing') and pz < 1.5:
        return (244, 198, 70), (80, 60, 10)
    u, _ = plane(n, pos)
    return g((252, 250, 242) if math.floor(u * 7) % 3 else (232, 228, 214), pos, 7, .03), (30, 30, 26)

def olymp_props(P):
    P.mat('laurel', (236, 196, 70), .3, .6); P.mat('bolt', (255, 220, 80), .2, 0, 5)
    for k in range(14):
        a = 2 * math.pi * k / 14
        if abs(math.sin(a) + 1) < .25:
            continue  # gap at the front
        P.box(f'laurel {k}', (.78 * math.cos(a), HEAD_Y + .78 * math.sin(a), HEAD_TOP - .02), (.26, .14, .14), 'Head', 'laurel',
              (0, 25, math.degrees(a) + 90))
    pts = [(1.44, -.3, 3.25), (1.44, .12, 2.65), (1.44, -.18, 2.5), (1.44, .22, 1.7)]
    for k in range(3):
        P.seg(f'bolt {k}', pts[k], pts[k + 1], .16, .1, 'Wing_R', 'bolt')

# ------------------------------------------------------------------ Aurora
RIBBONS = [(80, 255, 170), (60, 220, 230), (170, 110, 255)]

def aurora_paint(part, n, pos, *a):
    px, py, pz = pos
    b = basic(part, pos, beak=(236, 230, 250), wattle=(120, 230, 200), foot=(30, 40, 86))
    if b:
        return b
    u, v = plane(n, pos)
    if is_top(n):
        v = py * .6 + 3
    for k, c in enumerate(RIBBONS):
        center = 1.6 + k * .55 + .22 * math.sin(u * 2.4 + k * 1.7)
        d = abs(v - center)
        if d < .16:
            cc = mix(c, (255, 255, 255), .25 * (1 - d / .16))
            return cc, shade(cc, .7)
    if h(math.floor(u * 9), math.floor(v * 9), 51) > .975:
        return (255, 255, 240), (160, 160, 140)
    return g((16, 24, 58), pos, 6, .05)

SPECS = {
    'Police': dict(name='Police Chicken', paint=police_paint, props=police_props, rarity='Rare', band=4, vfx='None required. Optional: radio chirp sound.'),
    'Doctor': dict(name='Doctor Chicken', paint=doctor_paint, props=doctor_props, rarity='Rare', band=4,
                   vfx='Head-mirror glint (Glitter, rate 0.5) — optional.'),
    'Ghost': dict(name='Ghost Chicken', paint=ghost_paint, eye=ghost_eye, props=ghost_props, rarity='Rare', band=5, glow=2.2, rough=.5,
                  vfx='Set MeshPart Transparency ≈0.25 at import; slow bob tween (±0.15, 2 s); faint cyan Smoke wisps (rate 2) under the body.'),
    'Archer': dict(name='Archer Chicken', paint=archer_paint, props=archer_props, rarity='Rare', band=5, zone='Watchtower Fort',
                   vfx='None required. Optional: arrow-whoosh sound on Peck.'),
    'Rockstar': dict(name='Rockstar Chicken', paint=rock_paint, props=rock_props, rarity='Rare', band=5,
                     vfx='Music-note burst (Note) on Celebrate; guitar riff sound.'),
    'Yeti': dict(name='Yeti Chicken', paint=yeti_paint, props=yeti_props, rarity='Epic', band=6, rough=.95,
                 vfx='Frost sparkles (Star pale blue, rate 2) and a breath puff on Celebrate.'),
    'Mimic': dict(name='Mimic Chicken', paint=mimic_paint, props=mimic_props, rarity='Epic', band=6, zone='Pirate Cove',
                  vfx='Lid snap (small rotation tween on the lid part) + gold Glitter burst on Celebrate.'),
    'Gladiator': dict(name='Gladiator Chicken', paint=glad_paint, props=glad_props, rarity='Epic', band=6, ortho=7.2,
                      vfx='Shield clang Spark on Hit; crowd-cheer sound on Celebrate (optional).'),
    'Olympian': dict(name='Olympian Chicken', paint=olymp_paint, props=olymp_props, rarity='Legendary', band=7, glow=1.4,
                     vfx='Lightning bolt glow pulse (tween); small Spark arcs around the bolt; divine Glitter on Celebrate.'),
    'Aurora': dict(name='Aurora Chicken', paint=aurora_paint, rarity='Legendary', band=7, glow=2.2,
                   vfx='Slow aurora shimmer: tween the emission strength 1.5↔2.5 (4 s); soft green PointLight.'),
}
