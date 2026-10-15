"""Shared look for the Loyalist armada (mission-territory guards, October 15, 2026).

Every guard wears the King's colours somewhere: a crimson/gold crown crest on the chest
or tabard. Tier palettes: Veteran = iron + crimson, Elite = shadow navy + violet,
Royal = ivory + gold + crimson.
"""
import math
from pal import *

HEAD_Y, HEAD_TOP = -0.794, 4.29
WHITE_HEAD = (244, 242, 236)
CRIMSON = (176, 30, 44)
CRIMSON_DARK = (124, 18, 32)
GOLD = (236, 186, 58)
GOLD_DARK = (190, 140, 40)
IRON = (118, 124, 134)
IRON_DARK = (78, 82, 92)
NAVY = (34, 40, 76)
VIOLET = (116, 70, 196)
IVORY = (244, 236, 214)


def basic(part, pos, beak=BEAK, wattle=WATTLE, foot=FEET):
    if feet(part):
        return g(foot, pos, 3)
    if part == 'Beak':
        return g(beak, pos, 4)
    if part == 'Wattle':
        return g(wattle, pos, 5)
    return None


def crown(px, pz, cx=0.0, cz=1.62, s=1.0):
    """True inside the small crown crest (chest-front coordinates)."""
    x = (px - cx) / s; z = (pz - cz) / s
    if abs(x) < .34 and 0 <= z < .16:
        return True
    if .16 <= z < .44:
        for p in (-.27, 0, .27):
            top = .5 if p == 0 else .4
            if abs(x - p) < .075 and z < top:
                return True
    return False


def tabard(cloth, trim, emblem=GOLD, emblem_bg=None, half=.8, low=1.14):
    """Front/back tabard painter: returns colour or None outside the cloth."""
    def paint(part, n, pos):
        px, py, pz = pos
        if part != 'Body' or not (is_front(n) or is_back(n)) or abs(px) >= half:
            return None
        if abs(px) > half - .08 or pz < low:
            return g(trim, pos, 7, .04)
        if is_front(n) and crown(px, pz):
            return g(emblem, pos, 8, .03)
        if is_front(n) and emblem_bg and abs(px) < .46 and 1.5 < pz < 2.2:
            return g(emblem_bg, pos, 9, .04)
        return g(cloth, pos, 9, .05)
    return paint


def feathers(c, pos, n, seed=11, rows=7, dark=.9):
    """Soft scalloped feather rows."""
    u, v = plane(n, pos)
    k = math.floor(v * rows + .5 * (math.floor(u * 3) % 2))
    return g(c if k % 2 else shade(c, dark), pos, seed, .05)


def plume(P, label, base, height, mat, bone='Head', lean=(0, .12)):
    """Stacked plume rising from a helmet."""
    for i in range(4):
        P.box(f'{label} {i}', (base[0], base[1] + lean[1] * i, base[2] + .1 + i * height / 4),
              (.16 - i * .02, .3 - i * .03, height / 4 + .02), bone, mat)


def pauldrons(P, mat, trim=None, z=2.62, w=.62):
    for s in (-1, 1):
        wing = 'Wing_L' if s < 0 else 'Wing_R'
        P.box(f'pauldron {s}', (s * 1.22, -.05, z), (.34, w + .2, .22), wing, mat)
        P.box(f'pauldron top {s}', (s * 1.14, -.05, z + .14), (.3, w, .12), wing, mat)
        if trim:
            P.box(f'pauldron rim {s}', (s * 1.4, -.05, z - .02), (.04, w + .24, .14), wing, trim)
