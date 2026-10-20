"""Build review-sheet.png: every S6 icon inside a mock tree hex / Gem card at about real
size, plus a 64 px strip on dark, Upgrades blue, bought green and light backgrounds.
Hex colours, names and the tier numeral are mock-ups of S9's live UI, not part of the art.

Usage: python3 review_sheet.py   (reads upload/<Key>.png, falling back to <Key>.png)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
HEX = Image.open(REPO / "assets/research-20261002/icons/research-hex-mask.png").getchannel("A")
RALLY = REPO / "assets/generated/rally-icon-20261016/rally-horn-20261016-031355.png"
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"

INK = (16, 23, 18)
BG = (18, 25, 20)
TEXT = (247, 250, 244)
MUTED = (160, 172, 162)
BLUE = ((63, 186, 255), (22, 119, 223))
GREEN = ((163, 255, 0), (0, 211, 0))
ORANGE = ((255, 214, 0), (255, 149, 0))
RED = ((255, 82, 104), (219, 18, 57))
PURPLE = ((168, 94, 242), (116, 49, 196))

# (key, label, note, tier numeral or "", container colours or None)
GROUPS = [
    ("Main tree", [
        ("EggSpeed", "Egg Speed", "I–IV", "II", BLUE),
        ("EggValue", "Egg Value", "I–IV", "II", BLUE),
        ("Luck", "Luck", "I–IV · Gem Extra Luck", "II", BLUE),
        ("FlockSize", "Flock Size", "ladder", "II", BLUE),
        ("ArmySize", "Army Size", "I–IV", "II", BLUE),
        ("RollSlot", "Roll Slot", "I–VII", "II", BLUE),
        ("RollSpeed", "Roll Speed", "I–III · Gem Roll Speed", "II", BLUE),
        ("GoldMachine", "Gold Machine", "", "", BLUE),
        ("GoldRate", "Gold Rate", "I–II", "II", BLUE),
        ("DiamondMachine", "Diamond Machine", "", "", BLUE),
        ("RainbowMachine", "Rainbow Machine", "working name", "", BLUE),
    ]),
    ("Category hexes", [
        ("OpenTools", "Tools", "Open", "", ORANGE),
        ("OpenPlayer", "Player", "Open", "", ORANGE),
        ("OpenArmy", "Army", "Open", "", ORANGE),
        ("Back", "Back", "", "", RED),
    ]),
    ("Tools", [
        ("EggVacuum", "Egg Vacuum", "tool", "", BLUE),
        ("VacuumCapacity", "Vacuum Capacity", "I–IV · Gem too", "II", BLUE),
        ("VacuumRange", "Vacuum Range", "I–II", "II", BLUE),
        ("ChickenFeed", "Chicken Feed", "tool", "", BLUE),
    ]),
    ("Player", [
        ("WalkSpeed", "Walk Speed", "", "", BLUE),
        ("ClickRange", "Click Range", "", "", BLUE),
        ("OfflineTime", "Offline Time", "", "", BLUE),
    ]),
    ("Army", [
        ("Damage", "Damage", "", "", BLUE),
        ("Health", "Health", "", "", BLUE),
        ("MarchSpeed", "March Speed", "", "", BLUE),
        ("Armor", "Armor", "", "", BLUE),
        ("Recovery", "Recovery", "", "", BLUE),
        ("BossDamage", "Boss Damage", "", "", BLUE),
        ("Bounty", "Bounty", "", "", BLUE),
        ("CaptureSpeed", "Capture Speed", "", "", BLUE),
    ]),
    ("Gem Upgrades", [
        ("RollSpeed", "Roll Speed", "tree icon", "", PURPLE),
        ("Luck", "Extra Luck", "tree icon", "", PURPLE),
        ("VacuumCapacity", "Vacuum Capacity", "tree icon", "", PURPLE),
        ("AutoRoll", "Auto Roll", "", "", PURPLE),
        ("CoinBoost", "Coin Boost", "", "", PURPLE),
        ("AutoRebirth", "Auto Rebirth", "", "", PURPLE),
        ("TimeSkip", "Time Skip", "", "", PURPLE),
        ("MoreGems", "More Gems", "", "", PURPLE),
        ("KeepUpgrades", "Keep Upgrades", "", "", PURPLE),
        ("Rally", "Rally", "in game already", "", PURPLE),
        ("MutationLuck", "Mutation Luck", "", "", PURPLE),
        ("OfflineCoins", "Offline Coins", "", "", PURPLE),
        ("ArmyPower", "Army Power", "", "", PURPLE),
        ("RebirthChickenOdds", "Rebirth Chicken Odds", "", "", PURPLE),
    ]),
    ("Currency and HUD", [
        ("Gems", "Gems", "currency", "", None),
        ("FriendBoost", "Friend Boost", "HUD", "", None),
        ("GoldRush", "Gold Rush", "HUD event", "", None),
    ]),
]

ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII"]
W, MARGIN = 2400, 48
CELL_W, CELL_H = 196, 268
HEX_W, HEX_H = 160, 182
ICON = 108


def font(size, path=FONT):
    return ImageFont.truetype(path, size)


def load(key):
    if key == "Rally":
        path = RALLY
    else:
        path = HERE / "upload" / f"{key}.png"
        if not path.exists():
            path = HERE / f"{key}.png"
    if not path.exists():
        return None
    image = Image.open(path).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    image = image.crop(bbox)
    side = round(max(image.size) / 0.86)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return square


def gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return column.resize((w, h))


def outlined(draw, xy, text, size, fill=TEXT, stroke=4, path=FONT, anchor="mm"):
    draw.text(xy, text, font=font(size, path), fill=fill, stroke_width=stroke, stroke_fill=INK, anchor=anchor)


def container(colours):
    """A tree hex (or a rounded Gem card) with an ink edge and a gradient fill."""
    if colours is PURPLE:
        shape = Image.new("L", (HEX_W, HEX_W), 0)
        ImageDraw.Draw(shape).rounded_rectangle((0, 0, HEX_W - 1, HEX_W - 1), 18, fill=255)
    else:
        shape = HEX.resize((HEX_W, HEX_H), Image.LANCZOS)
    w, h = shape.size
    tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tile.paste(Image.new("RGBA", (w, h), INK + (255,)), (0, 0), shape)
    inner = shape.resize((round(w * 0.92), round(h * 0.92)), Image.LANCZOS)
    fill = gradient(inner.size, *colours)
    ox, oy = (w - inner.width) // 2, (h - inner.height) // 2
    tile.paste(fill, (ox, oy), inner)
    return tile


def cell(sheet, x, y, entry):
    key, label, note, numeral, colours = entry
    draw = ImageDraw.Draw(sheet)
    icon = load(key)
    cx = x + CELL_W // 2
    if colours is None:
        top = y + 8
        glow = Image.new("RGBA", (HEX_W, HEX_W), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((0, 0, HEX_W - 1, HEX_W - 1), fill=(0, 0, 0, 90))
        sheet.alpha_composite(glow, (cx - HEX_W // 2, top))
        icon_box, icon_xy, numeral_xy, bottom = 132, (cx - 66, top + 14), None, top + HEX_W
    else:
        tile = container(colours)
        top = y + 8
        sheet.alpha_composite(tile, (cx - tile.width // 2, top))
        icon_box = ICON
        icon_xy = (cx - ICON // 2, top + (tile.height - ICON) // 2 - 6)
        numeral_xy = (cx + 40, top + tile.height - 40)
        bottom = top + tile.height
    if icon is None:
        outlined(draw, (cx, icon_xy[1] + icon_box // 2), "missing", 22, fill=(255, 120, 132))
    else:
        sheet.alpha_composite(icon.resize((icon_box, icon_box), Image.LANCZOS), icon_xy)
    if numeral and numeral_xy:
        outlined(draw, numeral_xy, str(ROMAN.index(numeral) + 1), 40, stroke=5, path=BLACK)
        label = f"{label} {numeral}"
    outlined(draw, (cx, bottom + 24), label, 21, stroke=3)
    if note:
        draw.text((cx, bottom + 52), note, font=font(17), fill=MUTED, anchor="mm")


def strip_keys():
    seen = []
    for _, entries in GROUPS:
        for entry in entries:
            if entry[0] not in seen and entry[0] != "Rally":
                seen.append(entry[0])
    return seen


def main():
    per_row = (W - 2 * MARGIN) // CELL_W
    rows = sum(-(-len(entries) // per_row) for _, entries in GROUPS)
    keys = strip_keys()
    small, gap = 64, 12
    strip_per_row = (W - 2 * MARGIN - 220) // (small + gap)
    strip_rows = -(-len(keys) // strip_per_row)
    backgrounds = [("dark", (28, 32, 30)), ("Upgrades blue", BLUE[1]), ("bought green", GREEN[1]), ("light", (235, 235, 230))]
    height = 190 + len(GROUPS) * 62 + rows * CELL_H + 110 + len(backgrounds) * (strip_rows * (small + gap) + 30) + MARGIN
    sheet = Image.new("RGBA", (W, height), BG + (255,))
    draw = ImageDraw.Draw(sheet)
    outlined(draw, (MARGIN, 64), "My Chicken Army · upgrade icons · Oct 20 overhaul (S6 review)", 46, anchor="lm")
    draw.text((MARGIN, 120), "43 new icons, plus the Rally horn already in the game. Hex colours, names and the tier "
              "number are mock-ups of S9's live UI (tier shown as II); numbers are live text, not part of the art.",
              font=font(22), fill=MUTED, anchor="lm")
    y = 170
    for title, entries in GROUPS:
        outlined(draw, (MARGIN, y + 30), title, 32, anchor="lm")
        y += 62
        for index, entry in enumerate(entries):
            row, col = divmod(index, per_row)
            cell(sheet, MARGIN + col * CELL_W, y + row * CELL_H, entry)
        y += -(-len(entries) // per_row) * CELL_H
    y += 20
    outlined(draw, (MARGIN, y + 30), "Real size: 64 px on dark, Upgrades blue, bought green and light", 32, anchor="lm")
    y += 80
    for name, colour in backgrounds:
        band_h = strip_rows * (small + gap) + gap
        draw.rectangle((MARGIN, y, W - MARGIN, y + band_h), fill=colour)
        draw.text((MARGIN + 16, y + band_h // 2), name, font=font(22), fill=TEXT if name != "light" else INK, anchor="lm")
        for index, key in enumerate(keys):
            icon = load(key)
            if icon is None:
                continue
            row, col = divmod(index, strip_per_row)
            sheet.alpha_composite(icon.resize((small, small), Image.LANCZOS),
                                  (MARGIN + 220 + col * (small + gap), y + gap + row * (small + gap)))
        y += band_h + 30
    sheet.convert("RGB").save(HERE / "review-sheet.png", optimize=True)
    print(f"review-sheet.png {W}x{height}")


if __name__ == "__main__":
    main()
