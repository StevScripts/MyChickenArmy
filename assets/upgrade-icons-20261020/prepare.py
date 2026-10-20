"""Make upload copies of the chosen icon masters (October 20 overhaul, session S6).

For every <Key>.png master in this folder: clear the outer EDGE pixels (one edit came back
with a faint frame line there), clean near-zero alpha specks, snap the generator's ~250
subject alpha to opaque, restore the listed generator holes and outlines, trim to the artwork, re-centre
it on a square canvas so its longest side fills OCCUPANCY of the width (every icon then has
the same apparent size in a hex), resize with premultiplied alpha (no coloured fringes) and
write upload/<Key>.png. Fully transparent texels carry black so mip levels never haze the
outlines. --rgba also writes upload/<Key>.rgba, the raw bytes the Studio EditableImage
upload path reads (see assets/gold-coins-20261020/README.md).

Usage: python3 prepare.py [--rgba] [KEY ...]
"""
import math
import sys
from collections import deque
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
SIZE = 512
OCCUPANCY = 0.86
EDGE = 6
# The generator keyed out these enclosed parts (the breastplate's inside, Mutation Luck's
# sparkle fills, the Rainbow Machine's slot and window), leaving see-through holes inside
# the outline. Their colour is intact, so only the alpha comes back.
FILL_HOLES = {"Armor", "MutationLuck", "RainbowMachine"}
# Every approved in-game icon carries a heavy near-black contour about 2.2% of its longest
# side. These masters came back with thin, grey or coloured edges, so the same contour is
# laid under the artwork. AutoRebirth (an edit of the Re-enlist icon) also drops a stray
# hairline that floats ~20 px outside its ring.
OUTLINE = 0.022
STROKE = {"AutoRebirth", "Armor", "ArmyPower", "BossDamage", "Bounty", "CoinBoost", "Damage", "DiamondMachine",
          "EggVacuum", "FriendBoost", "GoldMachine", "GoldRate", "GoldRush", "KeepUpgrades", "MutationLuck",
          "OpenArmy", "OpenTools", "RainbowMachine", "RebirthChickenOdds", "RollSpeed", "VacuumCapacity"}
CLIP_HAIRLINE = {"AutoRebirth"}
INK = (16, 23, 18)


def fill_enclosed(image: Image.Image) -> None:
    """Make transparent regions that do not touch the canvas edge opaque again."""
    width, height = image.size
    clear = bytearray(1 if v < 128 else 0 for v in image.getchannel("A").tobytes())
    outside = bytearray(len(clear))
    queue = deque(i for i in range(len(clear)) if clear[i] and (
        i < width or i >= width * (height - 1) or i % width in (0, width - 1)))
    for i in queue:
        outside[i] = 1
    while queue:
        i = queue.popleft()
        x = i % width
        for j in (i - 1 if x else -1, i + 1 if x < width - 1 else -1, i - width, i + width):
            if 0 <= j < len(clear) and clear[j] and not outside[j]:
                outside[j] = 1
                queue.append(j)
    alpha = bytearray(image.getchannel("A").tobytes())
    for i in range(len(alpha)):
        if clear[i] and not outside[i]:
            alpha[i] = 255
    image.putalpha(Image.frombytes("L", image.size, bytes(alpha)))


def stroke(image: Image.Image, clip: bool) -> Image.Image:
    """Lay a crisp near-black outline under the artwork, grown from its solid shape."""
    solid = image.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    box = solid.getbbox()
    radius = OUTLINE * max(box[2] - box[0], box[3] - box[1])
    opening = 7 if clip else 3  # drop hairlines (clip) or single-pixel specks
    solid = solid.filter(ImageFilter.MinFilter(opening)).filter(ImageFilter.MaxFilter(opening))
    grown = solid.copy()
    for r in (radius, radius * 2 / 3, radius / 3):
        steps = max(12, int(2 * math.pi * r / 3))
        for k in range(steps):
            t = 2 * math.pi * k / steps
            grown = ImageChops.lighter(grown, ImageChops.offset(solid, round(r * math.cos(t)), round(r * math.sin(t))))
    grown = grown.filter(ImageFilter.GaussianBlur(1.0))
    if clip:
        image.putalpha(ImageChops.darker(image.getchannel("A"), grown))
    under = Image.new("RGBA", image.size, INK + (0,))
    under.putalpha(grown)
    under.alpha_composite(image)
    return under


def prepare(key: str) -> Image.Image:
    image = Image.open(HERE / f"{key}.png").convert("RGBA")
    width, height = image.size
    alpha = image.getchannel("A").point(lambda a: 0 if a <= 5 else (255 if a >= 245 else a))
    border = Image.new("L", image.size, 0)
    border.paste(alpha.crop((EDGE, EDGE, width - EDGE, height - EDGE)), (EDGE, EDGE))
    image.putalpha(border)
    if key in FILL_HOLES:
        fill_enclosed(image)
    if key in STROKE:
        image = stroke(image, key in CLIP_HAIRLINE)
    image = image.crop(image.getchannel("A").getbbox())
    side = round(max(image.size) / OCCUPANCY)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    resized = canvas.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
    pixels = resized.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return resized


def main() -> None:
    args = sys.argv[1:]
    rgba = "--rgba" in args
    keys = [a for a in args if a != "--rgba"] or sorted(p.stem for p in HERE.glob("*.png") if p.stem[0].isupper())
    out = HERE / "upload"
    out.mkdir(exist_ok=True)
    for key in keys:
        image = prepare(key)
        image.save(out / f"{key}.png", optimize=True)
        if rgba:
            (out / f"{key}.rgba").write_bytes(image.tobytes())
        print(f"{key} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
