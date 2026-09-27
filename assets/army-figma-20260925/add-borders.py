"""User-authorized PNG border pass. Preserve every source pixel with nonzero alpha."""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
RADIUS = 7
manifest_path = ROOT / "portrait-manifest.json"
manifest = json.loads(manifest_path.read_text())
assert not any(p.get("outlinedAssetId") for p in manifest["portraits"]), "Do not regenerate uploaded assets"
output = ROOT / "outlined-portraits"
output.mkdir(exist_ok=True)
raw = ROOT / "upload-pixels"
raw.mkdir(exist_ok=True)
checks = []
for portrait in manifest["portraits"]:
    source_path = ROOT / portrait["originalPng"]
    assert hashlib.sha256(source_path.read_bytes()).hexdigest() == portrait["sha256"]
    source = np.array(Image.open(source_path).convert("RGBA"))
    assert source.shape == (512, 512, 4)
    visible = source[:, :, 3] > 0
    expanded = np.zeros((512, 512), dtype=np.uint8)
    # Circular dilation with a one-pixel antialiased outer edge, no resampling.
    for dy in range(-RADIUS, RADIUS + 1):
        for dx in range(-RADIUS, RADIUS + 1):
            coverage = round(255 * max(0, min(1, RADIUS + 0.5 - math.hypot(dx, dy))))
            if not coverage:
                continue
            sy, sx = slice(max(0, -dy), min(512, 512-dy)), slice(max(0, -dx), min(512, 512-dx))
            ty, tx = slice(max(0, dy), min(512, 512+dy)), slice(max(0, dx), min(512, 512+dx))
            np.maximum(expanded[ty, tx], visible[sy, sx].astype(np.uint8) * coverage, out=expanded[ty, tx])
    result = np.zeros_like(source)
    result[:, :, 3] = expanded
    result[visible] = source[visible]
    assert np.array_equal(result[visible], source[visible]), "Original artwork changed"
    assert not result[0, :, 3].any() and not result[-1, :, 3].any()
    assert not result[:, 0, 3].any() and not result[:, -1, 3].any(), "Clipped border"
    border = (~visible) & (result[:, :, 3] > 0)
    assert border.any() and not result[:, :, :3][border].any(), "Expected black outer border"
    path = output / (portrait["species"] + ".png")
    Image.fromarray(result).save(path)
    pixels = result.tobytes()
    (raw / (portrait["species"] + ".rgba")).write_bytes(pixels)
    portrait.update(outlinedPng=str(path.relative_to(ROOT)), outlinedSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                    rgbaSha256=hashlib.sha256(pixels).hexdigest(), borderRadiusPixels=RADIUS)
    checks.append(dict(species=portrait["species"], originalPixelsPreserved=int(visible.sum()), addedBorderPixels=int(border.sum()), unclipped=True))

manifest.update(status="31 outlined PNGs ready; not uploaded", methodDecision="User approved direct PNG borders: Yes add border",
                borderMethod="7px circular alpha expansion, antialiased exterior; every original nontransparent RGBA pixel retained")
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
(ROOT / "border-checks.json").write_text(json.dumps(checks, indent=2) + "\n")
for page in range(2):
    sheet = Image.new("RGB", (896, 976), (22, 35, 43))
    draw = ImageDraw.Draw(sheet)
    for index, portrait in enumerate(manifest["portraits"][page*16:(page+1)*16]):
        x, y = (index % 4)*224, (index//4)*244
        draw.rectangle((x+3, y+3, x+221, y+241), fill=(43, 61, 72), outline=(80, 115, 133))
        preview = Image.open(ROOT / portrait["outlinedPng"]).resize((216, 216), Image.Resampling.LANCZOS)
        sheet.paste(preview, (x+4, y+2), preview)
        draw.text((x+12, y+224), portrait["species"], fill="white")
    sheet.save(ROOT / f"outlined-contact-sheet-{page+1}.png")
print(f"Prepared {len(checks)} outlined PNGs; original pixels preserved; no clipping.")
