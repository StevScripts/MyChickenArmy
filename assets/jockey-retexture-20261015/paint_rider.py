"""Original 64x32 rider skin for the Chicken Jockey (October 15, 2026).
Painted pixel by pixel here (no source texture): green skin, purple shirt,
teal trousers, brown shoes, own face. Pasted 8x into the rider area of the
existing 1024 atlas (x 512-1024, y 0-256); the chicken area is untouched."""
import sys
from pathlib import Path
from PIL import Image

def h(x, y, s):
    n = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535

def shade(c, f):
    return tuple(max(0, min(255, round(v * f))) for v in c)

def grain(c, x, y, s, amt=.14):
    return shade(c, 1 + (round(h(x, y, s) * 4) / 4 - .5) * amt)

SKIN, SKIN_DARK = (112, 166, 70), (82, 128, 50)
SHIRT, SHIRT_DARK = (118, 70, 196), (84, 46, 150)
PANTS, PANTS_DARK = (40, 170, 170), (26, 124, 128)
SHOE, SHOE_DARK = (104, 72, 44), (74, 50, 30)
EYE, PUPIL, MOUTH = (34, 40, 30), (236, 240, 214), (56, 74, 40)

def boxes():
    # name, origin, (dx, dy, dz) - the classic 64x32 skin box layout the mesh UVs use.
    return [("Head", (0, 0), (8, 8, 8)), ("Torso", (16, 16), (8, 12, 4)),
            ("Arm", (40, 16), (4, 12, 4)), ("Leg", (0, 16), (4, 12, 4))]

def regions(origin, dims):
    ox, oy = origin; dx, dy, dz = dims
    yield "top", ox + dz, oy, dx, dz
    yield "bottom", ox + dz + dx, oy, dx, dz
    yield "right", ox, oy + dz, dz, dy
    yield "front", ox + dz, oy + dz, dx, dy
    yield "left", ox + dz + dx, oy + dz, dz, dy
    yield "back", ox + 2 * dz + dx, oy + dz, dx, dy

def skin(x, y):
    patch = h(x // 2, y // 2, 7) > .78
    return grain(SKIN_DARK if patch else SKIN, x, y, 3)

def paint():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    px = img.load()
    for name, origin, dims in boxes():
        for face, x0, y0, w, hh in regions(origin, dims):
            for j in range(hh):
                for i in range(w):
                    x, y = x0 + i, y0 + j
                    if name == "Head":
                        c = skin(x, y)
                        if face == "top" or (face in ("back", "left", "right") and j < 2):
                            c = grain(SKIN_DARK, x, y, 5)  # darker scalp
                        if face == "front":
                            if j == 2 and i in (1, 2, 5, 6):
                                c = shade(SKIN_DARK, .85)  # brows
                            if j in (3, 4) and i in (1, 2, 5, 6):
                                c = EYE
                            if j == 3 and i in (2, 5):
                                c = PUPIL  # one bright pixel per eye, looking in
                            if j == 6 and i in (3, 4):
                                c = MOUTH
                            if j == 5 and i in (0, 7):
                                c = shade(SKIN, .9)
                    elif name == "Torso":
                        c = grain(SHIRT if (i + j) % 5 else SHIRT_DARK, x, y, 9, .1)
                        if j == dims[1] - 1:
                            c = grain(SHOE_DARK, x, y, 11)  # belt
                        if face == "front" and j < 2 and i in (3, 4) and j + abs(i - 3.5) < 2:
                            c = skin(x, y)  # neck opening
                        if face == "front" and j == 5 and i in (2, 5):
                            c = shade(SHIRT_DARK, .9)  # buttons
                    elif name == "Arm":
                        sleeve = face == "top" or (face not in ("bottom",) and j < 4)
                        c = grain(SHIRT, x, y, 13, .1) if sleeve else skin(x, y)
                        if face not in ("top", "bottom") and j == 3:
                            c = SHIRT_DARK  # cuff
                    else:  # Leg: hip at the top rows, shoe at the bottom rows
                        c = grain(PANTS if (i + j) % 4 else PANTS_DARK, x, y, 17, .1)
                        if face == "bottom" or (face != "top" and j >= dims[1] - 2):
                            c = grain(SHOE if j < dims[1] - 1 else SHOE_DARK, x, y, 19)
                    px[x, y] = (*c, 255)
    return img

if __name__ == "__main__":
    atlas_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    rider = paint()
    rider.save(out_dir / "rider-64x32.png")
    atlas = Image.open(atlas_path).convert("RGBA")
    big = rider.resize((512, 256), Image.NEAREST)
    region = atlas.crop((512, 0, 1024, 256))
    # Keep the atlas's own transparent gaps; replace only texels the old rider used.
    mask = region.split()[3].point(lambda a: 255 if a > 0 else 0)
    atlas.paste(big, (512, 0), mask)
    atlas.save(out_dir / "color.png")
    print("ok", atlas.size)
