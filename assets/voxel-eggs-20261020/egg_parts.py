"""Reusable egg patterns (layers), front marks and voxel accessories.

Layers take a Cell (see render_eggs.Cell) and return a color, (color, glow) or
None. Marks are drawn on the camera-facing side in (u, w) voxel units: u runs
across the front (0 = centre, + = screen right), w is height from the middle
(about -9 bottom .. +9 top). Accessories return {voxel: (color, glow)}.
"""
import math
import numpy as np
from render_eggs import rgb, mix, W, H, FRONT_THETA, radius, Noise

# ---------------- layers ----------------
def solid(c):
    c = rgb(c); return lambda s: c

def grad(top, bottom):
    t, b = rgb(top), rgb(bottom)
    return lambda s: mix(b, t, (s.v + 1) / 2)

def speck(c, d, glow=False, vmin=-2, vmax=2):
    c = rgb(c)
    def f(s):
        if vmin <= s.v <= vmax and s.ctx["rnd"].random() < d: return (c, glow)
    return f

def confetti(colors, d, glow=False, vmin=-2, vmax=2):
    cs = [rgb(c) for c in colors]
    def f(s):
        r = s.ctx["rnd"]
        if vmin <= s.v <= vmax and r.random() < d: return (cs[r.randrange(len(cs))], glow)
    return f

def stripes(c, n, wave=0.0, duty=0.5, phase=0.0, vmin=-2, vmax=2, glow=False):
    c = rgb(c)
    def f(s):
        if not (vmin <= s.v <= vmax): return None
        t = ((s.v + 1) / 2 * n + wave * math.sin(s.th * 3) + phase) % 1
        if t < duty: return (c, glow)
    return f

def vstripes(c, n, duty=0.5, twist=0.0, wobble=0.0, vmin=-2, vmax=2, glow=False):
    c = rgb(c)
    def f(s):
        if not (vmin <= s.v <= vmax): return None
        t = (s.th / (2 * math.pi) * n + s.v * twist + wobble * math.sin(s.v * 9 + s.th * 2)) % 1
        if t < duty: return (c, glow)
    return f

def band(c, v0, v1, glow=False):
    c = rgb(c)
    def f(s):
        if v0 <= s.v <= v1: return (c, glow)
    return f

def cap(c, v0, wave=0.0, waves=5, glow=False):
    c = rgb(c)
    def f(s):
        if s.v > v0 + wave * math.sin(s.th * waves + 1): return (c, glow)
    return f

def bottom(c, v1, wave=0.0, waves=5, glow=False):
    c = rgb(c)
    def f(s):
        if s.v < v1 + wave * math.sin(s.th * waves): return (c, glow)
    return f

def drip(c, v0, depth=0.45, n=9, glow=False, seed=0):
    """A coat over the top with uneven drips running down."""
    c = rgb(c)
    def f(s):
        k = int((s.th + math.pi) / (2 * math.pi) * n) % n
        length = depth * (0.35 + 0.65 * ((math.sin(k * 12.9898 + seed * 3.7) * 43758.5453) % 1))
        edge = v0 - (length if ((s.th + math.pi) / (2 * math.pi) * n) % 1 < 0.55 else 0.06)
        if s.v > edge: return (c, glow)
    return f

def patches(c, thr=0.12, freq=0.85, salt=0, glow=False, vmin=-2, vmax=2):
    c = rgb(c)
    store = {}
    def f(s):
        if not (vmin <= s.v <= vmax): return None
        n = store.get("n")
        if n is None: n = store["n"] = Noise(int(s.ctx["seed"]) * 31 + salt * 977 + 11, freq=freq)
        if n(s.p * np.array([1, 0.9, 1])) > thr: return (c, glow)
    return f

def blend(c, amount=0.7, freq=0.6, salt=0, glow=False, mode="soft"):
    """Mix toward c by a noise field on top of whatever is below (uses s.prev)."""
    c = rgb(c)
    store = {}
    def f(s):
        n = store.get("n")
        if n is None: n = store["n"] = Noise(int(s.ctx["seed"]) * 17 + salt * 131 + 5, freq=freq)
        t = max(0.0, n(s.p)) * 1.6 * amount
        if mode == "veins": t = amount if abs(n(s.p)) < 0.07 else 0
        if t <= 0: return None
        return ("blend", c, min(1.0, t), glow)
    return f

def facets(amount=0.12):
    def f(s):
        return ("tint", 1 + s.ctx["rnd"].uniform(-amount, amount))
    return f

def checker(c, size=2, vmin=-2, vmax=2):
    c = rgb(c)
    def f(s):
        if not (vmin <= s.v <= vmax): return None
        i, j, k = (math.floor((q + 50) / size) for q in (s.x, s.y, s.z))
        if (i + j + k) % 2 == 0: return c
    return f

def plaid(c1, c2, size=4):
    a, b = rgb(c1), rgb(c2)
    def f(s):
        cu = (math.floor(s.u + 50) % size) < 1.5
        cw = (math.floor(s.w + 50) % size) < 1.5
        if cu and cw: return b
        if cu or cw: return mix(a, b, 0.55)
    return f

def dots(c, n=26, r=1.25, vmin=-2, vmax=2, glow=False):
    """Polka dots at Fibonacci points on the shell."""
    c = rgb(c)
    golden = math.pi * (3 - math.sqrt(5))
    pts = []
    for i in range(n):
        yy = 1 - (i + 0.5) / n * 2
        rr = math.sqrt(1 - yy * yy)
        pts.append((math.cos(golden * i) * rr, yy, math.sin(golden * i) * rr))
    def f(s):
        if not (vmin <= s.v <= vmax): return None
        q = np.array([s.x / (W / 2), s.v, s.z / (W / 2)])
        q /= max(1e-6, np.linalg.norm(q))
        for p in pts:
            if np.dot(q, p) > math.cos(r / 7.0): return (c, glow)
    return f

def hexcells(edge, size=2.6):
    e = rgb(edge)
    def f(s):
        q = (s.u * 2 / 3) / size
        r = (-s.u / 3 + math.sqrt(3) / 3 * s.w) / size
        # cube round
        x, z = q, r; y = -x - z
        rx, ry, rz = round(x), round(y), round(z)
        dx, dy, dz = abs(rx - x), abs(ry - y), abs(rz - z)
        if max(dx, dy, dz) > 0.36: return e
    return f

def scales(c, size=2.0):
    c = rgb(c)
    def f(s):
        row = math.floor((s.w + 50) / size)
        off = (row % 2) * size / 2
        cu = ((s.u + off + 50) % size) / size
        cw = ((s.w + 50) % size) / size
        if cw < 0.3 + 0.4 * abs(cu - 0.5) * 2 - 0.25: return c
    return f

def rainbow(sat=0.75, light=0.6, bands=6, glow=False):
    import colorsys
    def f(s):
        k = int((1 - (s.v + 1) / 2) * bands)
        r, g, b = colorsys.hls_to_rgb(k / bands * 0.83, light, sat)
        return (np.array([r, g, b]) * 255, glow)
    return f

def lightning_net(c, width=0.07, freq=0.7, salt=0, glow=True):
    """Glowing crack network (magma, toxic, runes)."""
    c = rgb(c)
    store = {}
    def f(s):
        n = store.get("n")
        if n is None: n = store["n"] = Noise(int(s.ctx["seed"]) * 23 + salt * 71 + 3, freq=freq)
        if abs(n(s.p)) < width: return (c, glow)
    return f

def glitch(colors, rows=0.22):
    cs = [rgb(c) for c in colors]
    def f(s):
        j = int(s.y)
        h = (math.sin(j * 91.7 + s.ctx["seed"]) * 43758.5) % 1
        if h < rows:
            shift = int(h * 40) % 5
            if ((int(s.th * 4) + shift) % 3) == 0: return (cs[int(h * 97) % len(cs)], True)
    return f

def rays(c, n=12, duty=0.35, glow=True):
    """Rays bursting out from the front centre."""
    c = rgb(c)
    def f(s):
        if abs(s.a) > 1.55: return None
        t = (math.atan2(s.w, s.u) / (2 * math.pi) * n) % 1
        if t < duty and math.hypot(s.u, s.w) > 1.2: return (c, glow)
    return f

# ---------------- marks on the front ----------------
def mark(c, shape, glow=False):
    c = rgb(c)
    def f(s):
        if abs(s.a) < 1.45 and shape(s.u, s.w): return (c, glow)
    return f

def circle(u0, w0, r): return lambda u, w: (u - u0) ** 2 + (w - w0) ** 2 <= r * r
def ellipse(u0, w0, rx, ry): return lambda u, w: ((u - u0) / rx) ** 2 + ((w - w0) / ry) ** 2 <= 1
def ring(u0, w0, r0, r1): return lambda u, w: r0 * r0 <= (u - u0) ** 2 + (w - w0) ** 2 <= r1 * r1
def rect(u0, w0, hw, hh): return lambda u, w: abs(u - u0) <= hw and abs(w - w0) <= hh
def union(*shapes): return lambda u, w: any(sh(u, w) for sh in shapes)
def minus(a, b): return lambda u, w: a(u, w) and not b(u, w)

def line(points, t=0.7):
    def seg(u, w, a, b):
        (x1, y1), (x2, y2) = a, b
        dx, dy = x2 - x1, y2 - y1
        L = dx * dx + dy * dy or 1e-9
        k = max(0, min(1, ((u - x1) * dx + (w - y1) * dy) / L))
        return math.hypot(u - (x1 + k * dx), w - (y1 + k * dy))
    return lambda u, w: min(seg(u, w, points[i], points[i + 1]) for i in range(len(points) - 1)) <= t

def poly(points):
    def inside(u, w):
        c = False; n = len(points)
        for i in range(n):
            (x1, y1), (x2, y2) = points[i], points[(i + 1) % n]
            if (y1 > w) != (y2 > w) and u < (x2 - x1) * (w - y1) / (y2 - y1 + 1e-12) + x1: c = not c
        return c
    return inside

def star(u0, w0, r, inner=0.45, n=5):
    pts = []
    for i in range(n * 2):
        a = math.pi / 2 + i * math.pi / n
        rr = r if i % 2 == 0 else r * inner
        pts.append((u0 + math.cos(a) * rr, w0 + math.sin(a) * rr))
    return poly(pts)

def heart(u0, w0, s):
    return union(circle(u0 - s * 0.5, w0 + s * 0.25, s * 0.55), circle(u0 + s * 0.5, w0 + s * 0.25, s * 0.55),
                 poly([(u0 - s * 1.02, w0 + s * 0.1), (u0 + s * 1.02, w0 + s * 0.1), (u0, w0 - s * 1.1)]))

def bolt(u0, w0, s):
    return poly([(u0 + 0.2 * s, w0 + 1.6 * s), (u0 - 0.9 * s, w0 - 0.1 * s), (u0 - 0.05 * s, w0 - 0.1 * s),
                 (u0 - 0.4 * s, w0 - 1.6 * s), (u0 + 0.9 * s, w0 + 0.35 * s), (u0 + 0.05 * s, w0 + 0.35 * s)])

def cross(u0, w0, s, t): return union(rect(u0, w0, s, t), rect(u0, w0, t, s))
def xmark(u0, w0, s, t=0.6): return union(line([(u0 - s, w0 - s), (u0 + s, w0 + s)], t), line([(u0 - s, w0 + s), (u0 + s, w0 - s)], t))
def eyes(w0, spread=2.2, r=0.9, ry=None): return union(ellipse(-spread, w0, r, ry or r), ellipse(spread, w0, r, ry or r))
def smile(w0, width=2.2, t=0.6, depth=0.9):
    return line([(-width, w0 + depth * 0.6), (-width * 0.5, w0), (width * 0.5, w0), (width, w0 + depth * 0.6)], t)

# ---------------- accessories ----------------
def _key(x, y, z): return (int(math.floor(x + W / 2)), int(math.floor(y)), int(math.floor(z + W / 2)))

def _put(out, x, y, z, c, glow=False):
    out[_key(x, y, z)] = (rgb(c) if isinstance(c, str) else c, glow)

def top_y(vox, x, z):
    i, _, k = _key(x, 0, z)
    ys = [j for (a, j, b) in vox if a == i and b == k]
    return max(ys) if ys else None

def _disc(out, j, r0, r1, c, glow=False, cx=0.0, cz=0.0, arc=None):
    for i in range(-6, W + 6):
        for k in range(-6, W + 6):
            x, z = i - W / 2 + 0.5 - cx, k - W / 2 + 0.5 - cz
            r = math.hypot(x, z)
            if r0 <= r <= r1:
                if arc and abs(_ang(math.atan2(z, x), FRONT_THETA)) > arc: continue
                out[(i, j, k)] = (rgb(c) if isinstance(c, str) else c, glow)

def _ang(a, b): return (a - b + math.pi) % (2 * math.pi) - math.pi

def dirv(t): return math.cos(t), math.sin(t)
SIDE_L, SIDE_R = FRONT_THETA + math.pi / 2, FRONT_THETA - math.pi / 2   # screen left / right

def acc(fn):
    """Wrap an accessory builder so recipes can call it with parameters."""
    def make(*a, **k):
        return lambda vox, ctx: fn(vox, ctx, *a, **k)
    return make

@acc
def hat_cone(vox, ctx, c, h=7, r0=3.8, base=15, band=None, tip=None, brim=None, stripes_c=None, lean=0.0):
    out = {}
    if brim: _disc(out, base, 0, brim[1], brim[0])
    for n in range(h):
        j = base + 1 + n if brim else base + n
        r = max(0.55, r0 * (1 - n / h))
        cx, cz = dirv(SIDE_R); off = lean * n * n / h
        col = stripes_c if (stripes_c and n % 2 == 1) else c
        if band and n == 0: col = band
        _disc(out, j, 0, r, col, cx=cx * off, cz=cz * off)
    if tip:
        cx, cz = dirv(SIDE_R); off = lean * h
        _put(out, cx * off, base + h + (1 if brim else 0), cz * off, tip[0], tip[1] if len(tip) > 1 else False)
    return out

@acc
def hat_brim(vox, ctx, c, crown_h=3, brim_r=6.0, crown_r=3.2, base=15, band=None, curl=True, crown_c=None):
    out = {}
    _disc(out, base, 0, brim_r, c)
    if curl: _disc(out, base + 1, brim_r - 0.9, brim_r, c)
    for n in range(crown_h):
        _disc(out, base + 1 + n, 0, crown_r, band if (band and n == 0) else (crown_c or c))
    return out

@acc
def chef_hat(vox, ctx, c="#FFFFFF"):
    out = {}
    for n in range(3): _disc(out, 16 + n, 0, 3.2, c)
    _disc(out, 19, 0, 4.4, c); _disc(out, 20, 0, 4.2, c); _disc(out, 21, 0, 3.0, c)
    return out

@acc
def beret(vox, ctx, c):
    out = {}
    cx, cz = dirv(SIDE_R)
    _disc(out, 16, 0, 4.6, c, cx=cx * 0.8, cz=cz * 0.8); _disc(out, 17, 0, 3.6, c, cx=cx * 0.8, cz=cz * 0.8)
    _put(out, 0, 18, 0, c)
    return out

@acc
def cap_visor(vox, ctx, c, visor, badge=None, base=14):
    out = {}
    _disc(out, base, 0, 4.9, c); _disc(out, base + 1, 0, 4.4, c); _disc(out, base + 2, 0, 3.8, c); _disc(out, base + 3, 0, 2.8, c)
    _disc(out, base - 1, 4.0, 6.6, visor, arc=1.0)
    if badge:
        fx, fz = dirv(FRONT_THETA); _put(out, fx * 4.6, base + 1, fz * 4.6, badge, True)
    return out

@acc
def tall_hat(vox, ctx, c, h=9, r=4.0, base=14, fluffy=True):
    out = {}
    for n in range(h):
        rr = r if n < h - 2 else r - (n - h + 3) * 0.9
        _disc(out, base + n, 0, rr, c)
    return out

@acc
def horns(vox, ctx, c, spread=0.95, length=4, out_step=0.55, base=14, tip=None, thick=True, curl=0.0):
    out = {}
    for t in (FRONT_THETA + spread, FRONT_THETA - spread):
        r = radius((base + 0.5) / H * 2 - 1, ctx["girth"]) - 0.4
        dx, dz = dirv(t)
        x, y, z = dx * r, base + 0.5, dz * r
        for n in range(length):
            col = tip if (tip and n >= length - 1) else c
            _put(out, x, y, z, col)
            if thick and n < length / 2:
                _put(out, x - dx, y, z - dz, col)
                _put(out, x, y - 1, z, col)
            step = out_step * (1 - curl * n / max(1, length))
            x += dx * step; z += dz * step; y += 1
    return out

@acc
def unicorn_horn(vox, ctx, c="#FFD94A", c2="#FFF3B0", h=6):
    out = {}
    fx, fz = dirv(FRONT_THETA)
    for n in range(h):
        x, z = fx * (1.2 + n * 0.15), fz * (1.2 + n * 0.15)
        _put(out, x, 17 + n, z, c2 if n % 2 else c, n % 2 == 1)
        if n < 2: _put(out, x - fx, 17 + n, z - fz, c)
    return out

@acc
def ears(vox, ctx, c, inner=None, spread=1.0, length=3, base=14):
    out = {}
    for t in (FRONT_THETA + spread, FRONT_THETA - spread):
        r = radius((base + 1.5) / H * 2 - 1, ctx["girth"]) + 0.5
        dx, dz = dirv(t)
        for n in range(length):
            w = max(0, length - 1 - n)
            for m in range(-w, w + 1):
                px, pz = -dz * m * 0.8, dx * m * 0.8
                col = inner if (inner and n < length - 1 and abs(m) < w) else c
                _put(out, dx * (r + n * 0.35) + px, base + 1 + n, dz * (r + n * 0.35) + pz, col)
    return out

@acc
def halo(vox, ctx, c="#FFE45C", j=21, r0=2.6, r1=4.0):
    out = {}; _disc(out, j, r0, r1, c, glow=True); return out

@acc
def sprout(vox, ctx, c="#4CB648", stem=None, leaves=2, h=2):
    out = {}
    stem = stem or c
    for n in range(h): _put(out, 0, 18 + n, 0, stem)
    lx, lz = dirv(SIDE_L); rx, rz = dirv(SIDE_R)
    top = 18 + h
    for m in (1, 2):
        _put(out, lx * m, top - 1 + (m == 2), lz * m, c)
        if leaves > 1: _put(out, rx * m, top - 1 + (m == 2), rz * m, c)
    _put(out, 0, top, 0, c)
    return out

@acc
def mohawk(vox, ctx, c, h=3, span=4, c2=None, colors=None):
    out = {}
    fx, fz = dirv(SIDE_L)
    for d in range(-span, span + 1):
        x, z = fx * d * 0.85, fz * d * 0.85
        y0 = top_y(vox, x, z)
        if y0 is None: continue
        hh = max(1, h - abs(d) // 2)
        for n in range(hh):
            col = colors[(d + span) % len(colors)] if colors else (c2 if (c2 and n == hh - 1) else c)
            _put(out, x, y0 + 1 + n, z, col)
    return out

@acc
def flames(vox, ctx, c1="#FF7A1A", c2="#FFE14A", n=7, h=4, ring_r=3.0, base=16):
    out = {}
    for m in range(n):
        t = FRONT_THETA + m * 2 * math.pi / n
        dx, dz = dirv(t)
        hh = h - (m % 2)
        for q in range(hh):
            col = mix(rgb(c1), rgb(c2), q / max(1, hh - 1))
            rr = ring_r * (1 - q / (hh + 1))
            _put(out, dx * rr, base + q, dz * rr, col, True)
    for q in range(h + 1):
        _put(out, 0, base + q, 0, mix(rgb(c1), rgb(c2), q / h), True)
    return out

@acc
def wings(vox, ctx, c, tip=None, length=4, rows=(8, 13), sweep=1):
    out = {}
    for t in (SIDE_L, SIDE_R):
        dx, dz = dirv(t)
        lo, hi = rows
        for j in range(lo, hi + 1):
            r = radius((j + 0.5) / H * 2 - 1, ctx["girth"])
            span = int(length - abs(j - (lo + hi) / 2) * 0.8 + (j - lo) * 0.25 * sweep)
            for n in range(1, max(1, span) + 1):
                col = tip if (tip and n >= span - 0) else c
                _put(out, dx * (r + n - 0.4) - 0.6 * math.cos(FRONT_THETA), j + n // 2 * sweep,
                     dz * (r + n - 0.4) - 0.6 * math.sin(FRONT_THETA), col)
    return out

@acc
def tentacles(vox, ctx, c, tip=None, n=6, length=4):
    out = {}
    for m in range(n):
        t = FRONT_THETA + m * 2 * math.pi / n + 0.3
        dx, dz = dirv(t)
        r = radius((2.5) / H * 2 - 1, ctx["girth"])
        for q in range(length):
            col = tip if (tip and q == length - 1) else c
            _put(out, dx * (r + q * 0.9), 1 + (q * q) // 4, dz * (r + q * 0.9), col)
    return out

@acc
def bumps(vox, ctx, c, density=0.12, vmin=-1, vmax=1, colors=None):
    """Puffs / spines: random surface voxels get an outward voxel."""
    out = {}
    rnd = ctx["rnd"]
    cs = [rgb(x) for x in colors] if colors else None
    for (i, j, k) in list(vox):
        x, z = i - W / 2 + 0.5, k - W / 2 + 0.5
        v = (j + 0.5) / H * 2 - 1
        if not (vmin <= v <= vmax): continue
        r = math.hypot(x, z)
        if r < radius(v, ctx["girth"]) - 1.1: continue
        if rnd.random() < density:
            d = max(1e-6, r)
            nx, nz = x / d, z / d
            key = _key(x + nx * 1.0, j + (0.5 if v > 0.6 else 0) + 0.0, z + nz * 1.0)
            if key not in vox: out[key] = (cs[rnd.randrange(len(cs))] if cs else rgb(c), False)
    return out

@acc
def antenna(vox, ctx, c, tip, h=3, pair=False, glow=True):
    out = {}
    spots = [(0, 0)] if not pair else [dirv(SIDE_L), dirv(SIDE_R)]
    for (sx, sz) in spots:
        x, z = sx * 1.6, sz * 1.6
        y0 = top_y(vox, x, z) or 17
        for n in range(h): _put(out, x * (1 + n * 0.15), y0 + 1 + n, z * (1 + n * 0.15), c)
        _put(out, x * (1 + h * 0.15), y0 + 1 + h, z * (1 + h * 0.15), tip, glow)
    return out

@acc
def petals(vox, ctx, c, n=10, j=15, r0=4.0, r1=6.4, c2=None):
    out = {}
    for i in range(-8, W + 8):
        for k in range(-8, W + 8):
            x, z = i - W / 2 + 0.5, k - W / 2 + 0.5
            r = math.hypot(x, z)
            a = math.atan2(z, x)
            if r0 <= r <= r1 and abs(math.sin(a * n / 2)) > 0.35:
                out[(i, j, k)] = (rgb(c2 if (c2 and r > r1 - 1) else c), False)
    return out

@acc
def laurel(vox, ctx, c="#4FA43A", berry=None, j=15):
    out = {}
    for i in range(-6, W + 6):
        for k in range(-6, W + 6):
            x, z = i - W / 2 + 0.5, k - W / 2 + 0.5
            r = math.hypot(x, z)
            a = _ang(math.atan2(z, x), FRONT_THETA)
            if 4.2 <= r <= 5.4 and abs(a) > 0.35:
                out[(i, j + (1 if (int(a * 4) % 2) else 0), k)] = (rgb(c), False)
    if berry:
        fx, fz = dirv(FRONT_THETA + 0.6); _put(out, fx * 4.8, j + 1, fz * 4.8, berry, True)
        fx, fz = dirv(FRONT_THETA - 0.6); _put(out, fx * 4.8, j + 1, fz * 4.8, berry, True)
    return out

@acc
def nose(vox, ctx, c, j=9, length=2, width=1, flat=False):
    out = {}
    fx, fz = dirv(FRONT_THETA); sx, sz = dirv(SIDE_R)
    r = radius((j + 0.5) / H * 2 - 1, ctx["girth"]) - 0.2
    for n in range(length):
        w = width if not flat else width
        for m in range(-w + 1, w):
            for dy in ((0,) if flat else ((0, 1) if n == 0 and width > 1 else (0,))):
                _put(out, fx * (r + n) + sx * m * 0.75, j + dy - (n if (not flat and length > 2) else 0) * 0.5,
                     fz * (r + n) + sz * m * 0.75, c)
    return out

@acc
def headphones(vox, ctx, c, cup):
    out = {}
    sx, sz = dirv(SIDE_L)
    for d in range(-5, 6):
        x, z = sx * d * 0.95, sz * d * 0.95
        y0 = top_y(vox, x, z)
        if y0 is None:
            y0 = 13 if abs(d) >= 5 else None
        if y0 is not None: _put(out, x * 1.08, y0 + 1, z * 1.08, c)
    for side in (-1, 1):
        r = radius((11.5) / H * 2 - 1, ctx["girth"])
        for dj in (-1, 0, 1):
            for m in (-1, 0, 1):
                fx, fz = dirv(FRONT_THETA)
                _put(out, sx * side * (r + 0.6) + fx * m * 0.8, 11 + dj, sz * side * (r + 0.6) + fz * m * 0.8, cup)
    return out

@acc
def bow(vox, ctx, c, knot=None):
    out = {}
    sx, sz = dirv(SIDE_L)
    for d, hs in ((1, (18, 19)), (2, (18, 19, 20)), (-1, (18, 19)), (-2, (18, 19, 20))):
        for j in hs: _put(out, sx * d, j, sz * d, c)
    _put(out, 0, 18, 0, knot or c)
    return out

@acc
def planet_ring(vox, ctx, c, c2=None, j=9, r0=8.0, r1=9.6):
    out = {}
    for i in range(-8, W + 8):
        for k in range(-8, W + 8):
            x, z = i - W / 2 + 0.5, k - W / 2 + 0.5
            r = math.hypot(x, z)
            if r0 <= r <= r1:
                out[(i, j, k)] = (rgb(c2 if (c2 and r > (r0 + r1) / 2) else c), True)
    return out

@acc
def collar(vox, ctx, c, j=6, h=3):
    out = {}
    for n in range(h):
        r = radius((j + 0.5) / H * 2 - 1, ctx["girth"]) + 0.6 + n * 0.5
        _disc(out, j + n, r - 0.9, r + 0.2, c)
    return out

@acc
def antlers(vox, ctx, c, tip=None):
    out = horns(c, spread=1.0, length=5, out_step=0.7, base=15, tip=tip)(vox, ctx)
    for t in (FRONT_THETA + 1.0, FRONT_THETA - 1.0):
        dx, dz = dirv(t)
        for n in range(2):
            _put(out, dx * (4.4 + n), 18 + n, dz * (4.4 + n), tip or c)
            _put(out, dx * 3.2 - dz * (n + 1) * 0.6, 19 + n, dz * 3.2 + dx * (n + 1) * 0.6, tip or c)
    return out

@acc
def spikes_top(vox, ctx, c, n=5, h=3, r=2.4, glow=False, c2=None):
    out = {}
    for m in range(n):
        t = FRONT_THETA + m * 2 * math.pi / n
        dx, dz = dirv(t)
        for q in range(h + (m % 2)):
            _put(out, dx * r * (1 - q * 0.2), 17 + q, dz * r * (1 - q * 0.2), c2 if (c2 and q >= h - 1) else c, glow)
    _put(out, 0, 18, 0, c, glow); _put(out, 0, 19, 0, c, glow)
    return out

@acc
def ridge(vox, ctx, c, h=2, step=2):
    """Back spikes running over the top from front to back (dragon/dino)."""
    out = {}
    sx, sz = dirv(SIDE_L)
    for d in range(-6, 7, step):
        x, z = sx * d * 0.0 + math.cos(FRONT_THETA + math.pi) * d * 0.0, 0
        fx, fz = dirv(SIDE_L)
        x, z = fx * d * 0.8, fz * d * 0.8
        y0 = top_y(vox, x, z)
        if y0 is None: continue
        for q in range(h): _put(out, x * (1 + q * 0.12), y0 + 1 + q, z * (1 + q * 0.12), c)
    return out

@acc
def floating(vox, ctx, items):
    """Free voxels: [(u_offset, y, out_offset, color, glow)] in front space."""
    out = {}
    fx, fz = dirv(FRONT_THETA); sx, sz = dirv(SIDE_R)
    for (u, y, o, c, g) in items:
        _put(out, sx * u + fx * o, y, sz * u + fz * o, c, g)
    return out
