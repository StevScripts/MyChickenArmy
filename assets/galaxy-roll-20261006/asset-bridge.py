from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from PIL import Image
import json,hashlib,re
ROOT=Path(__file__).resolve().parent
manifest={}
for p in (ROOT/'art').glob('*.png'):
 im=Image.open(p).convert('RGBA');im.thumbnail((1024,1024),Image.Resampling.LANCZOS)
 raw=im.tobytes();(ROOT/'art'/f'{p.stem}.rgba').write_bytes(raw)
 manifest[p.stem]={'width':im.width,'height':im.height,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
mp=ROOT/'image-assets.json'
if mp.exists():
 for name,row in json.loads(mp.read_text()).items():
  if name in manifest and row['sha256']==manifest[name]['sha256']:manifest[name].update(row)
mp.write_text(json.dumps(manifest,indent=2))
class H(BaseHTTPRequestHandler):
 def send(self,data,kind='application/json'):
  self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_GET(self):
  m=re.fullmatch(r'/(metadata|pixels)/([A-Za-z]+)',self.path)
  if m and m[2] in manifest:
   return self.send(json.dumps(manifest[m[2]]).encode() if m[1]=='metadata' else (ROOT/'art'/f'{m[2]}.rgba').read_bytes())
  self.send_error(404)
 def do_POST(self):
  m=re.fullmatch(r'/receipt/([A-Za-z]+)',self.path)
  if not m or m[1] not in manifest:return self.send_error(404)
  data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  assert data['sha256']==manifest[m[1]]['sha256'] and str(data['assetId']).isdigit()
  manifest[m[1]]['assetId']=str(data['assetId']);mp.write_text(json.dumps(manifest,indent=2));self.send(b'{"saved":true}')
print('Galaxy image bridge 18826',flush=True)
HTTPServer(('127.0.0.1',18826),H).serve_forever()
