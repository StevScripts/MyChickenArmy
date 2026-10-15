"""Pure-Python paint helpers shared by every batch spec (no bpy).

Paint functions receive (part, normal, pos, x, y, w, h):
  part   one of lib.PARTS (eyes are handled separately)
  normal integer face normal, e.g. (0,-1,0) = front (the chicken faces -Y), (0,0,1) = top
  pos    rest-space sample (+Z up). Key anatomy: body x±1.08 y-1.22..1.46 z1.0..2.92;
         head x±0.7 y-1.51..-0.08 z2.69..4.29; eyes z3.5..4.0 x±0.22..0.67;
         beak y-2.18..-1.46 z2.82..3.38; wattle z2.24..2.83; wings x±1.08..1.27 y-0.86..1.22 z1.23..2.75
and return rgb or (rgb, emission_rgb).
"""
import math

OFF = (0, 0, 0)
BEAK = (249, 184, 52)
WATTLE = (216, 41, 26)
FEET = (242, 137, 29)

def hexc(h):
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def h(x, y, z=0):
    n = (int(x) * 374761393 + int(y) * 668265263 + int(z) * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967295

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(c * (1 - t) + d * t) for c, d in zip(a, b))

def shade(c, f):
    return tuple(max(0, min(255, round(v * f))) for v in c)

def grain(pos, seed=0, amount=0.07):
    """Two-to-three pixel brightness variation anchored in rest space."""
    px, py, pz = pos
    n = h(math.floor(px * 4), math.floor(py * 4), math.floor(pz * 4) + seed)
    return 1.0 + (round(n * 3) / 3 - 0.5) * amount

def g(c, pos, seed=0, amount=0.07):
    return shade(c, grain(pos, seed, amount))

def field(pos, scale, seed):
    p = [v * scale for v in pos]; cell = [math.floor(v) for v in p]
    f = [v - i for v, i in zip(p, cell)]; f = [v * v * (3 - 2 * v) for v in f]
    total = 0.0
    for dz in (0, 1):
        for dy in (0, 1):
            for dx in (0, 1):
                w = (f[0] if dx else 1 - f[0]) * (f[1] if dy else 1 - f[1]) * (f[2] if dz else 1 - f[2])
                total += w * h(cell[0] + dx, cell[1] + dy, cell[2] + dz + seed)
    return total

def plane(normal, pos):
    """2D coordinates on the face: (horizontal, vertical-or-depth)."""
    px, py, pz = pos
    if normal[2]:
        return px, py
    if normal[0]:
        return py, pz
    return px, pz

def feet(part):
    return part.startswith(('Leg', 'Foot', 'Toe'))

def is_front(normal):
    return normal[1] < 0

def is_back(normal):
    return normal[1] > 0

def is_side(normal):
    return normal[0] != 0

def is_top(normal):
    return normal[2] > 0

def stars(u, v, cell, seed, density=.35):
    """True where a small plus-shaped star sits in a jittered grid."""
    cu, cv = math.floor(u / cell), math.floor(v / cell)
    if h(cu, cv, seed) > density:
        return False
    sx = (cu + .25 + h(cu, cv, seed + 1) * .5) * cell; sy = (cv + .25 + h(cu, cv, seed + 2) * .5) * cell
    du, dv = abs(u - sx), abs(v - sy); r = cell * .17
    return (du < r * .55 and dv < r * 1.6) or (dv < r * .55 and du < r * 1.6)

def dots(u, v, cell, seed, radius=.22, density=.6):
    cu, cv = math.floor(u / cell), math.floor(v / cell)
    if h(cu, cv, seed) > density:
        return False
    sx = (cu + .3 + h(cu, cv, seed + 1) * .4) * cell; sy = (cv + .3 + h(cu, cv, seed + 2) * .4) * cell
    return (u - sx) ** 2 + (v - sy) ** 2 < (cell * radius) ** 2

def tri_wave(t):
    return abs((t % 2) - 1)
