# Offline decoder written for inspection. Does not run embedded Roblox scripts.
from pathlib import Path
import struct,json
p=Path(__file__).parent
b=(p/'ViewportFrame_Masking_Examples.rbxl').read_bytes()
def lz4(buf):
 out=bytearray();i=0
 while i<len(buf):
  token=buf[i];i+=1;n=token>>4
  if n==15:
   while True:
    z=buf[i];i+=1;n+=z
    if z<255:break
  out.extend(buf[i:i+n]);i+=n
  if i>=len(buf):break
  off=buf[i]|buf[i+1]<<8;i+=2;n=(token&15)+4
  if token&15==15:
   while True:
    z=buf[i];i+=1;n+=z
    if z<255:break
  for _ in range(n):out.append(out[-off])
 return bytes(out)
def string(b,o):
 n=struct.unpack_from('<I',b,o)[0];o+=4;return b[o:o+n].decode('utf8',errors='replace'),o+n
def ints(b,n):return [int.from_bytes(bytes(b[i+j*n] for j in range(4)),'big') for i in range(n)]
def signed(b,n):return [(z>>1)^-(z&1) for z in ints(b,n)]
def floats(b,n):return [struct.unpack('<f',struct.pack('<I',(z>>1)|((z&1)<<31)))[0] for z in ints(b,n)]
def refs(b,n):
 out=[];v=0
 for z in signed(b,n):v+=z;out.append(v)
 return out
classes={};instances={};props=[];chunks=[];pos=32
while pos<len(b):
 typ,cl,ul,res=struct.unpack_from('<4sIII',b,pos);pos+=16;data=b[pos:pos+(cl or ul)];pos+=cl or ul
 data=lz4(data) if cl else data;assert len(data)==ul;chunks.append((typ,data))
for typ,data in chunks:
 if typ==b'INST':
  cid=struct.unpack_from('<I',data)[0];name,o=string(data,4);n=struct.unpack_from('<I',data,o+1)[0];ids=refs(data[o+5:],n);classes[cid]={'class':name,'ids':ids}
  for iid in ids:instances[iid]={'class':name,'id':iid}
 elif typ==b'PROP':
  cid=struct.unpack_from('<I',data)[0];name,o=string(data,4);t=data[o];props.append((cid,name,t,data[o+1:]))
 elif typ==b'PRNT':
  n=struct.unpack_from('<I',data,1)[0];ids=refs(data[5:5+4*n],n);parents=refs(data[5+4*n:],n)
  for iid,parent in zip(ids,parents):instances[iid]['parent']=parent
for cid,name,t,data in props:
 ids=classes[cid]['ids'];n=len(ids)
 if t==1:
  vals=[];o=0
  for _ in range(n):v,o=string(data,o);vals.append(v)
 elif t==2:vals=[bool(v) for v in data]
 elif t==3:vals=signed(data,n)
 elif t==4:vals=floats(data,n)
 elif t==5:vals=list(struct.unpack('<'+'d'*n,data))
 elif t in (12,13,14):
  count=2 if t==13 else 3
  xyz=[floats(data[k*n*4:(k+1)*n*4],n) for k in range(count)];vals=[list(v) for v in zip(*xyz)]
 elif t==7:
  xs=floats(data[:4*n],n);ys=floats(data[4*n:8*n],n);xo=signed(data[8*n:12*n],n);yo=signed(data[12*n:],n);vals=[{'xs':a,'ys':b,'xo':c,'yo':d} for a,b,c,d in zip(xs,ys,xo,yo)]
 elif t==0x12:vals=ints(data,n)
 elif t==0x13:vals=refs(data,n)
 elif t==0x1a:vals=[[data[i+j*n] for j in range(3)] for i in range(n)]
 else:continue
 for iid,v in zip(ids,vals):instances[iid][name]=v

def path(i):
 e=instances[i];par=e.get('parent',-1);return (path(par)+'/' if par in instances else '')+e.get('Name',e['class'])
for i,e in instances.items():e['path']=path(i)
(p/'instances-decoded.json').write_text(json.dumps(list(instances.values()),indent=2))
selected=[e for e in instances.values() if e['path']=='ServerStorage/Character2Viewport' or e['path']=='StarterGui/MaskGui' or e['path'].startswith('ServerStorage/Character2Viewport/GalaxyMask')]
(p/'character2-decoded.json').write_text(json.dumps(selected,indent=2))
for e in selected:
 print({k:e[k] for k in ['path','class','Size','size','Transparency','BackgroundColor3','BackgroundTransparency','ImageTransparency','Ambient','LightColor','LightDirection','Position','MeshId','ColorMap','AlphaMode','TextureID','DoubleSided','Anchored','Color3uint8','Material','IgnoreGuiInset','ScreenInsets','ZIndex','CurrentCamera'] if k in e})
