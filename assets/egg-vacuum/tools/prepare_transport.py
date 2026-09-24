from pathlib import Path
from PIL import Image
import json
art=Path(__file__).resolve().parents[1]
items=[]
for path in sorted((art/'textures').glob('*.jpg')):
    image=Image.open(path).convert('RGBA')
    # Studio EditableImage max side is 1024; original full-res textures stay packed in Blender.
    image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
    key=path.stem.split('_part_')[-1].split('_')[0]
    (art/'export'/('image-'+key+'.rgba')).write_bytes(image.tobytes())
    items.append({'key':key,'file':path.name,'width':image.width,'height':image.height})
(art/'export/images.json').write_text(json.dumps(items,indent=2))
print(items)
