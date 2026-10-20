"""Render every chicken's egg. python3 build_eggs.py [only_id ...]
Writes png/<Id>.png (512, review) and png256/<Id>.png (game sprite), plus
sheets/<Rarity>.png contact sheets for review."""
import csv, os, sys
from PIL import Image
import render_eggs as E
from egg_recipes import RECIPES as MORE

HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = list(csv.DictReader(open(os.path.join(HERE, "chickens.csv"))))
SPARKS = [(0.27, 0.30, 14), (0.75, 0.25, 17), (0.77, 0.70, 11), (0.25, 0.72, 12)]
LADDER = {  # rarity -> (shine, sparkle count, aura strength)
    "Common": (False, 0, 0), "Uncommon": (False, 0, 0), "Rare": (True, 0, 0), "Epic": (True, 1, 0),
    "Legendary": (True, 2, 0.45), "Mythic": (True, 3, 0.8), "Secret": (True, 4, 0.95)}

def recipes():
    out = {r["id"]: dict(r) for r in E.RECIPES}
    for k, r in MORE.items():
        assert k not in out, k
        out[k] = dict(r, id=k)
    return out

def main(only):
    rs = recipes()
    ids = [row["Id"] for row in ROWS]
    missing = [i for i in ids if i not in rs]
    extra = [i for i in rs if i not in ids]
    assert not missing and not extra, (missing, extra)
    for d in ("png", "png256", "sheets"): os.makedirs(os.path.join(HERE, d), exist_ok=True)
    done = {}
    for row in ROWS:
        cid, rarity, main = row["Id"], row["Rarity"], row["Main color (hex)"]
        if only and cid not in only: continue
        r = rs[cid]
        shine, sparks, aura = LADDER[rarity]
        r.setdefault("shine", shine)
        r.setdefault("shine_color", "#%02X%02X%02X" % tuple(int(x) for x in E.mix(E.rgb(main), E.rgb("#FFFFFF"), 0.7)))
        r.setdefault("sparkles", SPARKS[:sparks])
        if "aura" not in r and aura: r["aura"], r["aura_strength"] = main, aura
        if r.get("aura") and "aura_strength" not in r: r["aura_strength"] = aura or 0.6
        img = E.render(r, os.path.join(HERE, "png", cid + ".png"))
        img.resize((256, 256), Image.LANCZOS).save(os.path.join(HERE, "png256", cid + ".png"), optimize=True)
        done.setdefault(rarity, []).append(img)
        print("ok", cid)
    for rarity, imgs in done.items():
        cols = 6; rows = (len(imgs) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 200, rows * 200), (94, 155, 67, 255))
        for n, im in enumerate(imgs):
            sheet.alpha_composite(im.resize((200, 200), Image.LANCZOS), ((n % cols) * 200, (n // cols) * 200))
        sheet.save(os.path.join(HERE, "sheets", rarity + ".png"))

if __name__ == "__main__":
    main(set(sys.argv[1:]))
