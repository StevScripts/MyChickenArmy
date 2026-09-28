import json,struct
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).parent;OUT=ROOT/'transport';OUT.mkdir(exist_ok=True)
manifest=json.loads((ROOT/'runtime/manifest.json').read_text())
for name,info in manifest.items():
 raw=(ROOT/'runtime'/f'{name}.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);blob=raw[28+n:]
 def acc(i):
  a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dt=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
  return np.ndarray((a['count'],dim),dt,blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dim*dt.itemsize),dt.itemsize)).copy()
 assert len(g['skins'])==1 and len(g['meshes'])==1 and len(g['meshes'][0]['primitives'])==1
 skin=g['skins'][0];joints=skin['joints'];parents={c:i for i,node in enumerate(g['nodes']) for c in node.get('children',[])}
 binds=np.linalg.inv(acc(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1))
 bones=[{'name':g['nodes'][j]['name'],'parent':joints.index(parents[j])+1 if parents.get(j) in joints else 0,'cf':np.round(np.r_[binds[i][:3,3],binds[i][:3,:3].flatten()],7).tolist()} for i,j in enumerate(joints)]
 prim=g['meshes'][0]['primitives'][0];attrs=prim['attributes']
 data={'id':name,'bones':bones,'positions':acc(attrs['POSITION']).round(7).tolist(),'normals':acc(attrs['NORMAL']).round(7).tolist(),'uvs':acc(attrs['TEXCOORD_0']).round(7).tolist(),'joints':(acc(attrs['JOINTS_0'])+1).tolist(),'weights':acc(attrs['WEIGHTS_0']).round(7).tolist(),'indices':(acc(prim['indices']).flatten()+1).tolist()}
 assert all(abs(sum(w)-1)<1e-5 for w in data['weights'])
 (OUT/f'{name}.json').write_text(json.dumps(data,separators=(',',':')))
 im=Image.open(ROOT/'runtime'/f'{name}.png').convert('RGBA');(OUT/f'{name}.rgba').write_bytes(im.tobytes())
 print(name,len(data['positions']),len(data['indices'])//3,len(bones))
