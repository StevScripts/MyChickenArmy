"""Prepare the October 20 gold coin art for Roblox upload (EditableImage path).

Cleans near-zero alpha specks, snaps the generator's ~253 subject alpha to opaque,
adds a small transparent margin so outlines are never clipped by the canvas edge,
resizes with premultiplied alpha (no colored fringes) to at most 1024 px, and
writes both a PNG and the raw RGBA bytes that Studio reads over localhost.
Usage: python3 prepare_upload.py OUT_DIR NAME=SOURCE.png [NAME=SOURCE.png ...]
"""
import sys
from pathlib import Path
from PIL import Image

MAX_SIDE = 1024
MARGIN = 0.025


def prepare(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 0 if a <= 5 else (255 if a >= 245 else a))
    image.putalpha(alpha)
    width, height = image.size
    pad_x, pad_y = round(width * MARGIN), round(height * MARGIN)
    canvas = Image.new("RGBA", (width + 2 * pad_x, height + 2 * pad_y), (0, 0, 0, 0))
    canvas.paste(image, (pad_x, pad_y))
    scale = min(1.0, MAX_SIDE / max(canvas.size))
    size = (max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale)))
    resized = canvas.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    # Fully transparent texels carry black so mip levels never haze the dark outlines.
    pixels = resized.load()
    for y in range(resized.height):
        for x in range(resized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return resized


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for pair in sys.argv[2:]:
        name, source = pair.split("=", 1)
        image = prepare(Path(source))
        image.save(out / f"{name}.png")
        (out / f"{name}.rgba").write_bytes(image.tobytes())
        print(f"{name} {image.width}x{image.height} {len(image.tobytes())} bytes")


if __name__ == "__main__":
    main()
