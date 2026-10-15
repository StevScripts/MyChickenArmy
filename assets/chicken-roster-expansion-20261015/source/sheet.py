"""Contact sheet: python3 sheet.py OUT.jpg ID [ID...] (previews + concept side by side if --ref)."""
import sys
from pathlib import Path
from PIL import Image
ST = Path(__file__).resolve().parent.parent
out, ids = sys.argv[1], [a for a in sys.argv[2:] if not a.startswith('--')]
ref = '--ref' in sys.argv
S = 384; cols = 4 if ref else 4
tiles = []
for i in ids:
    tiles.append(Image.open(ST/'previews'/f'{i}.png').convert('RGB').resize((S, S)))
    if ref and (ST/'concepts'/f'{i}.png').exists():
        tiles.append(Image.open(ST/'concepts'/f'{i}.png').convert('RGB').resize((S, S)))
rows = (len(tiles) + cols - 1) // cols
c = Image.new('RGB', (cols*S, rows*S), 'white')
for k, t in enumerate(tiles):
    c.paste(t, ((k % cols)*S, (k//cols)*S))
c.save(out, quality=88)
