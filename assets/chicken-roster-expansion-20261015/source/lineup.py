"""Labeled batch lineup from the real model renders: python3 lineup.py BATCH [--title "..."]
Reads batches/<BATCH>-manifest.json; writes batches/<BATCH>-lineup.png."""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ST = Path(__file__).resolve().parent.parent
batch = sys.argv[1]
title = sys.argv[sys.argv.index('--title') + 1] if '--title' in sys.argv else None
data = json.loads((ST / 'batches' / f'{batch}-manifest.json').read_text())
items = data['chickens']; n = len(items)
cols = n if n <= 5 else (5 if n % 5 == 0 or n > 8 else 4)
rows = (n + cols - 1) // cols
T, LABEL, TOP = 520, 92, (110 if title else 30)
COLORS = {'Common': (130, 150, 128), 'Uncommon': (52, 170, 40), 'Rare': (30, 150, 210), 'Epic': (160, 80, 220),
          'Legendary': (215, 160, 10), 'Mythic': (230, 60, 110)}
canvas = Image.new('RGB', (cols * T, TOP + rows * (T + LABEL) + 20), (236, 238, 242))
d = ImageDraw.Draw(canvas)
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', 34)
small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', 24)
if title:
    big = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', 52)
    d.text((cols * T / 2, 58), title, font=big, fill=(40, 44, 52), anchor='mm')
for k, it in enumerate(items):
    r, c = divmod(k, cols)
    im = Image.open(ST / it['preview']).convert('RGB')
    w, h = im.size; crop = int(w * .9); im = im.crop(((w - crop) // 2, (h - crop) // 2 - int(h * .04), (w + crop) // 2, (h + crop) // 2 - int(h * .04)))
    im = im.resize((T, T), Image.LANCZOS)
    x0 = c * T + (T * (cols * (rows) - n) // 2 if r == rows - 1 and n % cols else 0) // max(1, rows) * 0
    if r == rows - 1 and n % cols:
        x0 = c * T + (cols - n % cols) * T // 2
    else:
        x0 = c * T
    y0 = TOP + r * (T + LABEL)
    canvas.paste(im, (x0, y0))
    d.text((x0 + T / 2, y0 + T + 26), it['name'], font=font, fill=(36, 40, 48), anchor='mm')
    rar = it.get('rarity') or ''
    d.text((x0 + T / 2, y0 + T + 64), rar, font=small, fill=COLORS.get(rar, (90, 90, 90)), anchor='mm')
canvas.save(ST / 'batches' / f'{batch}-lineup.png', optimize=True)
print(ST / 'batches' / f'{batch}-lineup.png', canvas.size)
