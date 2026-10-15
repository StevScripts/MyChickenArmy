"""Independent export check (no Blender): python3 verify_exports.py -> export-review.json"""
import json, struct, glob
from pathlib import Path
ST = Path(__file__).resolve().parent.parent
CLIPS = {'Chicken_Idle','Chicken_Walk','Chicken_Peck','Chicken_Hit','Chicken_Defeat','Chicken_Celebrate'}
BAD = ('FX_', 'Studio', 'Backdrop', 'Label', 'Lineup', 'softbox', 'Camera')
ids = []
for b in sorted(glob.glob(str(ST / 'batches' / 'b*-manifest.json'))):
    ids += [c['id'] for c in json.loads(Path(b).read_text())['chickens']]
out = []
for cid in ids:
    raw = (ST / 'models' / f'{cid}.glb').read_bytes()
    n = struct.unpack_from('<I', raw, 12)[0]; doc = json.loads(raw[20:20 + n])
    names = [nd.get('name', '') for nd in doc['nodes']]
    meshes = [nd for nd in doc['nodes'] if 'mesh' in nd]
    prims = [p for m in doc['meshes'] for p in m['primitives']]
    anims = {a['name'] for a in doc.get('animations', [])}
    chans = all(len(a['channels']) > 0 for a in doc.get('animations', []))
    r = {'id': cid,
         'skins': len(doc.get('skins', [])), 'joints': [len(s['joints']) for s in doc.get('skins', [])],
         'meshNodes': len(meshes), 'allSkinned': all('skin' in m for m in meshes),
         'weights': all('JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes'] for p in prims),
         'clips': sorted(anims), 'clipsOk': anims == CLIPS and chans,
         'embeddedImages': sum(1 for i in doc.get('images', []) if 'bufferView' in i),
         'previewLeak': [x for x in names if any(t in x for t in BAD)],
         'fbxBytes': (ST / 'models' / f'{cid}-Bind.fbx').stat().st_size}
    r['ok'] = (r['skins'] >= 1 and all(j == 18 for j in r['joints']) and r['allSkinned'] and r['weights'] and r['clipsOk']
               and r['embeddedImages'] >= 1 and not r['previewLeak'] and r['fbxBytes'] > 10000)
    out.append(r)
(ST / 'export-review.json').write_text(json.dumps({'checked': len(out), 'allOk': all(r['ok'] for r in out), 'chickens': out}, indent=1))
print(len(out), 'checked; all ok =', all(r['ok'] for r in out), [r['id'] for r in out if not r['ok']])
