"""Difference-matte two viewport captures (black/white backdrop) into 512px transparent portraits,
then add the approved 7px black silhouette border (alpha >= 128), like the Sept 25 refresh.
python3 process.py BATCH"""
import json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image
P = Path(__file__).resolve().parent
batch = sys.argv[1]
info = json.loads((P / 'batches.json').read_text())[batch]
black = np.asarray(Image.open(P / 'shots' / f'{batch}-black.png').convert('RGB')).astype(np.float32)
white = np.asarray(Image.open(P / 'shots' / f'{batch}-white.png').convert('RGB')).astype(np.float32)
H, W, _ = black.shape
scale = W / info['viewport'][0]
cols, rows = 4, 2
RADIUS, SIZE, FILL = 7, 512, 0.9
for i, cid in enumerate(info['ids']):
    col, row = i % cols, i // cols
    # Cells are evenly spaced; centre/half from the Setup projection at 1920x1078 points.
    cx = (280.75 + col * 452.83) * scale; cy = (312.59 + row * 452.83) * scale; half = 226.42 * scale
    x0, x1, y0, y1 = int(cx - half), int(cx + half), int(cy - half), int(cy + half)
    b = black[y0:y1, x0:x1]; w = white[y0:y1, x0:x1]
    corners = np.concatenate([b[:6, :6].reshape(-1, 3), b[-6:, -6:].reshape(-1, 3)])
    bb = np.median(corners, axis=0)
    cw = np.concatenate([w[:6, :6].reshape(-1, 3), w[-6:, -6:].reshape(-1, 3)])
    bw = np.median(cw, axis=0)
    diff = (w - b) / np.maximum(bw - bb, 1)
    alpha = np.clip(1 - diff.mean(axis=2), 0, 1)
    alpha[alpha < 0.04] = 0
    a3 = np.maximum(alpha[..., None], 1e-4)
    color = np.clip((b - (1 - alpha[..., None]) * bb) / a3, 0, 255)
    rgba = np.dstack([color, alpha * 255]).astype(np.uint8)
    ys, xs = np.nonzero(alpha > 0.5)
    assert len(xs), cid
    bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    if bx0 <= 1 or by0 <= 1 or bx1 >= alpha.shape[1] - 1 or by1 >= alpha.shape[0] - 1: print('EDGE', cid)
    side = max(bx1 - bx0, by1 - by0) / FILL
    mx, my = (bx0 + bx1) / 2, (by0 + by1) / 2
    img = Image.fromarray(rgba, 'RGBA')
    crop = img.crop((int(mx - side / 2), int(my - side / 2), int(mx + side / 2), int(my + side / 2)))
    # Premultiplied resize keeps dark halos out of the antialiased edge.
    arr = np.asarray(crop).astype(np.float32); arr[..., :3] *= arr[..., 3:4] / 255
    pm = Image.fromarray(arr.astype(np.uint8), 'RGBA').resize((SIZE, SIZE), Image.LANCZOS)
    arr = np.asarray(pm).astype(np.float32); a = arr[..., 3:4]
    arr[..., :3] = np.where(a > 0, np.clip(arr[..., :3] * 255 / np.maximum(a, 1), 0, 255), 0)
    source = arr.astype(np.uint8)
    visible = source[:, :, 3] >= 128
    expanded = np.zeros((SIZE, SIZE), dtype=np.uint8)
    for dy in range(-RADIUS, RADIUS + 1):
        for dx in range(-RADIUS, RADIUS + 1):
            coverage = round(255 * max(0, min(1, RADIUS + 0.5 - math.hypot(dx, dy))))
            if not coverage:
                continue
            sy, sx = slice(max(0, -dy), min(SIZE, SIZE - dy)), slice(max(0, -dx), min(SIZE, SIZE - dx))
            ty, tx = slice(max(0, dy), min(SIZE, SIZE + dy)), slice(max(0, dx), min(SIZE, SIZE + dx))
            np.maximum(expanded[ty, tx], visible[sy, sx].astype(np.uint8) * coverage, out=expanded[ty, tx])
    base = np.zeros_like(source); base[:, :, 3] = expanded
    result = Image.alpha_composite(Image.fromarray(base), Image.fromarray(source))
    r = np.asarray(result)
    assert not r[0, :, 3].any() and not r[-1, :, 3].any() and not r[:, 0, 3].any() and not r[:, -1, 3].any(), 'clipped ' + cid
    result.save(P / 'outlined' / f'{cid}.png')
    (P / 'serve' / f'{cid}.rgba').write_bytes(result.tobytes())
    print(cid, 'ok', round(side))
