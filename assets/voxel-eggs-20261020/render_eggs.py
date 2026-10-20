"""Voxel egg renderer for My Chicken Army (October 20 test batch).

One fixed camera, light and outline for every egg; each chicken is a small
recipe (colors, pattern, extras). Run: python3 render_eggs.py [out_dir]
Writes <Id>.png (512x512, transparent) per recipe.
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512            # final sprite
SS = 2                # supersample factor
W, H = 14, 18         # egg voxel grid (x/z width, height)
ELEV, YAW = math.radians(28), math.radians(45)
OUTLINE = 11          # black stroke, px at final size
FRAME = 0.62          # bare egg's share of the sprite; leaves room for hats/wings

# ---------- helpers ----------
def rgb(h):
    h = h.lstrip("#"); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], float)

def mix(a, b, t): return a + (b - a) * t

def shade(c, f): return np.clip(c * f, 0, 255)

class Noise:
    def __init__(self, seed, waves=6, freq=0.55):
        r = random.Random(seed)
        self.w = [(np.array([r.uniform(-1, 1) for _ in range(3)]) * freq * r.uniform(0.6, 1.4), r.uniform(0, 6.28)) for _ in range(waves)]
    def __call__(self, p):
        return sum(math.sin(float(np.dot(p, k)) + ph) for k, ph in self.w) / len(self.w)  # ~[-1,1]

# ---------- egg shape ----------
def radius(v, girth=1.0):
    return W / 2 * math.sqrt(max(0.0, 1 - v * v)) * (1 - 0.16 * v) * 1.04 * girth

def egg_voxels(girth=1.0):
    vox = {}
    for j in range(H):
        v = (j + 0.5) / H * 2 - 1                       # -1 bottom .. 1 top
        r = radius(v, girth)
        for i in range(-3, W + 3):
            for k in range(-3, W + 3):
                x, z = i - W / 2 + 0.5, k - W / 2 + 0.5
                if x * x + z * z <= r * r:
                    vox[(i, j, k)] = None
    return vox

def layered(layers):
    # Each layer returns (color, emissive) or None; the last hit wins.
    def paint(ctx, x, y, z, v, th):
        out = (rgb("#FF00FF"), False)
        cell = Cell(ctx, x, y, z, v, th)
        for layer in layers:
            hit = layer(cell)
            if hit is None: continue
            if isinstance(hit, tuple) and isinstance(hit[0], str):
                if hit[0] == "blend": out = (mix(out[0], hit[1], hit[2]), out[1] or hit[3])
                elif hit[0] == "tint": out = (np.clip(out[0] * hit[1], 0, 255), out[1])
            else:
                out = hit if isinstance(hit, tuple) else (hit, False)
        return out
    return paint

class Cell:
    __slots__ = ("ctx", "x", "y", "z", "v", "th", "a", "u", "w", "p")
    def __init__(self, ctx, x, y, z, v, th):
        self.ctx, self.x, self.y, self.z, self.v, self.th = ctx, x, y, z, v, th
        self.a = ang(th, FRONT_THETA)                     # 0 = facing the camera
        self.u = self.a * max(1.0, radius(v, ctx["girth"]))  # arc distance across the front
        self.w = y - H / 2                                # height from the middle, voxels
        self.p = np.array([x, y, z])

def info(key):
    i, j, k = key
    x, y, z = i - W / 2 + 0.5, j + 0.5, k - W / 2 + 0.5
    v = y / H * 2 - 1
    theta = math.atan2(z, x)                           # 0 faces +x
    front = math.atan2(z - 0, x - 0)
    return x, y, z, v, theta

# camera
VIEW = np.array([math.cos(ELEV) * math.sin(YAW), math.sin(ELEV), math.cos(ELEV) * math.cos(YAW)])
FWD = -VIEW
RIGHT = np.cross(FWD, [0, 1, 0]); RIGHT /= np.linalg.norm(RIGHT)
CUP = np.cross(RIGHT, FWD)
# the side facing the camera is theta = 45deg (between +x and +z)
FRONT_THETA = math.radians(45)

def ang(a, b):
    d = (a - b + math.pi) % (2 * math.pi) - math.pi
    return d

FACES = {  # normal: corner offsets (counter-clockwise), light factor
    (0, 1, 0): ([(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)], 1.10),
    (1, 0, 0): ([(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], 0.90),
    (0, 0, 1): ([(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], 0.74),
}

def render(recipe, out_path):
    seed = sum(map(ord, recipe["id"]))
    rnd = random.Random(seed)
    vox = egg_voxels(recipe.get("girth", 1.0))
    ctx = {"girth": recipe.get("girth", 1.0), "seed": seed, "rnd": rnd, "noise": Noise(seed), "noise2": Noise(seed * 7 + 3, freq=1.1), "noise3": Noise(seed * 13 + 5, freq=0.85)}
    # carve (e.g. bite marks) before coloring
    for fn in recipe.get("carve", []):
        for key in list(vox):
            if fn(*info(key)):
                del vox[key]
    extra = {}
    for fn in recipe.get("extras", []):
        extra.update(fn(vox, ctx))
    # color every voxel
    glow = set()
    paint = recipe.get("paint") or layered(recipe["layers"])
    for key in vox:
        c, emissive = paint(ctx, *info(key))
        vox[key] = c
        if emissive: glow.add(key)
    for key, (c, emissive) in extra.items():
        vox[key] = np.array(c, float) if not isinstance(c, np.ndarray) else c
        if emissive: glow.add(key)

    # fixed framing from the bare egg, so hats and wings never shrink the egg
    pts = []
    for (i, j, k) in BARE:
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    p = np.array([i + dx - W / 2, j + dy, k + dz - W / 2])
                    pts.append((float(p @ RIGHT), float(-(p @ CUP))))
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    big = SIZE * SS
    scale = big * FRAME / span
    ox = big / 2 - (max(xs) + min(xs)) / 2 * scale
    oy = big * 0.56 - (max(ys) + min(ys)) / 2 * scale
    def proj(p): return (float(p @ RIGHT) * scale + ox, float(-(p @ CUP)) * scale + oy)

    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    order = sorted(vox, key=lambda key: float(np.array([key[0] - W / 2 + .5, key[1] + .5, key[2] - W / 2 + .5]) @ VIEW))
    hx, hy = recipe.get("shine_at", (0.36, 0.30))
    shine_col = rgb(recipe.get("shine_color", "#FFFFFF"))
    for key in order:
        i, j, k = key
        base = vox[key]
        cx, cy = proj(np.array([i + .5 - W / 2, j + .5, k + .5 - W / 2]))
        # glossy highlight in screen space (rare and up)
        if recipe.get("shine"):
            d = math.hypot(cx / big - hx, (cy / big - hy) * 0.85)
            if d < 0.075: base = mix(base, shine_col, 0.6 if d < 0.04 else 0.3)
        height = 0.88 + 0.12 * (j / H)                  # slightly darker near the ground
        for n, (corners, light) in FACES.items():
            nb = (i + n[0], j + n[1], k + n[2])
            if nb in vox: continue
            f = 1.0 if key in glow else light * height
            c = shade(base, f)
            poly = [proj(np.array([i + a - W / 2, j + b, k + cz - W / 2])) for a, b, cz in corners]
            edge = shade(c, 0.86)
            draw.polygon(poly, fill=tuple(int(x) for x in c) + (255,), outline=tuple(int(x) for x in edge) + (255,), width=SS)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    alpha = np.array(img)[:, :, 3] > 110
    stroke = dilate(alpha, OUTLINE)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    if recipe.get("aura"):
        halo = dilate(alpha, OUTLINE + 18).astype(np.uint8) * 255
        halo = Image.fromarray(halo).filter(ImageFilter.GaussianBlur(14))
        a = (np.array(halo).astype(float) * recipe.get("aura_strength", 0.75)).astype(np.uint8)
        col = Image.new("RGBA", (SIZE, SIZE), tuple(int(x) for x in rgb(recipe["aura"])) + (255,))
        col.putalpha(Image.fromarray(a))
        out = Image.alpha_composite(out, col)
    s = np.zeros((SIZE, SIZE, 4), np.uint8); s[stroke] = (18, 14, 20, 255)
    sm = Image.fromarray(s).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.alpha_composite(out, sm)
    out = Image.alpha_composite(out, img)
    for (sx, sy, sz) in recipe.get("sparkles", []):
        sparkle(out, sx * SIZE, sy * SIZE, sz)
    out.save(out_path)
    return out

def dilate(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out

def sparkle(img, x, y, s):
    d = ImageDraw.Draw(img)
    def star(rad, col):
        pts = []
        for n in range(8):
            a = n * math.pi / 4
            rr = rad if n % 2 == 0 else rad * 0.28
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        d.polygon(pts, fill=col)
    star(s + 6, (18, 14, 20, 255))
    star(s, (255, 255, 255, 255))

# ---------- recipes ----------
def p_classic(ctx, x, y, z, v, th):
    base = mix(rgb("#FFF3D6"), rgb("#F4DDB0"), (1 - v) * 0.35)
    if ctx["rnd"].random() < 0.07: return rgb("#B07A45"), False
    return base, False

def p_cow(ctx, x, y, z, v, th):
    n = ctx["noise3"](np.array([x, y * 0.9, z]))
    if n > 0.12: return rgb("#25222A"), False
    if v < -0.82: return rgb("#F7A9B8"), False     # pink bottom tip
    return rgb("#FAF7F0"), False

def p_bee(ctx, x, y, z, v, th):
    band = int((v + 1) * 3.6 + 0.15 * math.sin(th * 3)) % 2
    return (rgb("#2A2430") if band else rgb("#FFD72E")), False

def bee_wings(*_):
    out = {}
    wing = rgb("#E8F6FF")
    for side in (-1, 1):
        for a in range(3):
            for b in range(3 - (a == 2)):
                # wings poke out of the back-left/back-right, high on the egg
                i = W // 2 + side * (W // 2 + a) - (1 if side < 0 else 0)
                out[(i, H - 7 + b, 3)] = (wing, False)
    return out

def p_zombie(ctx, x, y, z, v, th):
    n = ctx["noise"](np.array([x, y, z]))
    base = mix(rgb("#8DBF5A"), rgb("#5E8A3C"), max(0, n) * 1.2)
    crack = 0.18 + 0.16 * abs(((ang(th, FRONT_THETA) * 3.0) % 2) - 1)
    if abs(v - crack) < 0.065 and abs(ang(th, FRONT_THETA)) < 1.2: return rgb("#2B3A22"), False
    if abs(ang(th, FRONT_THETA) - 0.45) < 0.08 and -0.55 < v < -0.15: return rgb("#3A2B2B"), False   # stitch
    if abs(ang(th, FRONT_THETA) - 0.45) < 0.32 and abs(v + 0.35) < 0.05: return rgb("#3A2B2B"), False
    return base, False

def zombie_bite(x, y, z, v, th):
    # a bite out of the upper right rim
    # on the screen-right outline (theta -45deg) so the notch reads in silhouette
    t = FRONT_THETA - math.pi / 2 + 0.25
    c = np.array([6.6 * math.cos(t), H * 0.70, 6.6 * math.sin(t)])
    return float(np.linalg.norm(np.array([x, y, z]) - c)) < 3.0

def p_frost(ctx, x, y, z, v, th):
    if v > 0.38 + 0.12 * math.sin(th * 5 + 1) or (v > 0.2 and abs(math.sin(th * 5 + 1)) > 0.96):
        return rgb("#FFFFFF"), False
    base = mix(rgb("#4FB8EE"), rgb("#A8E6FF"), (v + 1) / 2)
    if ctx["rnd"].random() < 0.05: return rgb("#E9FBFF"), False
    return base, False

def p_gold(ctx, x, y, z, v, th):
    base = mix(rgb("#D9850F"), rgb("#F7BE2E"), (v + 1) / 2)
    if -0.08 < v < 0.09:
        if int(round(ang(th, 0) / (math.pi / 4))) % 2 == 0 and abs(((ang(th, 0) / (math.pi / 4)) % 1) - 0.5) > 0.32:
            return rgb("#E8243C"), True
        return rgb("#B8740F"), False
    return base, False

def crown(*_):
    out = {}
    gold, dark, gem = rgb("#FFF06A"), rgb("#9E5A0A"), rgb("#3FA9FF")
    cx, base = W / 2, H - 2
    for i in range(W):
        for k in range(W):
            x, z = i - cx + 0.5, k - cx + 0.5
            r = math.hypot(x, z)
            if not (2.0 <= r <= 3.7): continue
            a = math.atan2(z, x)
            out[(i, base, k)] = (dark, False)
            out[(i, base + 1, k)] = (gold, False)
            out[(i, base + 2, k)] = (gold, False)
            seg = (a / (2 * math.pi / 5)) % 1                # five points
            if abs(seg - 0.5) < 0.22:
                out[(i, base + 3, k)] = (gold, False)
                if abs(seg - 0.5) < 0.1: out[(i, base + 4, k)] = (gold, False)
    for t in (FRONT_THETA, FRONT_THETA + 1.25, FRONT_THETA - 1.25):
        out[(int(cx + 3.4 * math.cos(t)), base + 1, int(cx + 3.4 * math.sin(t)))] = (gem if t == FRONT_THETA else rgb("#E8243C"), True)
    return out

def p_galaxy(ctx, x, y, z, v, th):
    n = ctx["noise"](np.array([x, y, z]))
    n2 = ctx["noise2"](np.array([x, y, z]))
    base = mix(rgb("#1B1446"), rgb("#5B2FB8"), max(0, n) * 1.6)
    base = mix(base, rgb("#2E7BE0"), max(0, n2) * 0.9)
    r = ctx["rnd"].random()
    if r < 0.045: return rgb("#FFFFFF"), True
    if r < 0.065: return rgb("#FFE78A"), True
    return base, False

def p_rift(ctx, x, y, z, v, th):
    a = ang(th, FRONT_THETA)
    zig = 0.32 * (abs(((v + 1) * 2.4) % 2 - 1) - 0.5)
    d = abs(a - zig)
    if d < 0.12: return rgb("#FFE6FB"), True
    if d < 0.26: return rgb("#FF3FD6"), True
    n = ctx["noise"](np.array([x, y, z]))
    base = mix(rgb("#140A1E"), rgb("#3B1252"), max(0, n) * 1.4)
    if ctx["rnd"].random() < 0.03: return rgb("#FF8BEA"), True
    return base, False

RECIPES = [
    {"id": "Duck", "paint": p_classic},
    {"id": "Cow", "paint": p_cow},
    {"id": "Bee", "paint": p_bee, "extras": [bee_wings]},
    {"id": "Zombie", "paint": p_zombie, "carve": [zombie_bite], "shine": True, "shine_color": "#D9F2B0"},
    {"id": "Frost", "paint": p_frost, "shine": True, "sparkles": [(0.74, 0.30, 12)]},
    {"id": "Dragon", "paint": p_gold, "extras": [crown], "shine": True,
     "sparkles": [(0.25, 0.28, 16), (0.77, 0.58, 11)], "aura": "#FFD84A", "aura_strength": 0.45},
    {"id": "StormDuck", "paint": p_galaxy, "shine": True, "shine_color": "#B7A2FF",
     "sparkles": [(0.22, 0.34, 14), (0.79, 0.24, 18), (0.80, 0.72, 10)], "aura": "#8A5CFF", "aura_strength": 0.8},
    {"id": "RiftWalker", "paint": p_rift, "shine": True, "shine_color": "#B8669F",
     "sparkles": [(0.20, 0.25, 18), (0.81, 0.40, 13), (0.24, 0.74, 10), (0.74, 0.80, 15)], "aura": "#FF3FD6", "aura_strength": 0.95},
]

BARE = egg_voxels()

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "png")
    os.makedirs(out_dir, exist_ok=True)
    for r in RECIPES:
        render(r, os.path.join(out_dir, r["id"] + ".png"))
        print("wrote", r["id"])
