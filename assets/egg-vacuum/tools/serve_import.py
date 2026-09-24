from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
CODE=ROOT.parents[1]
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  name=self.path.split('?',1)[0].lstrip('/')
  p=(ROOT/name).resolve()
  if ROOT not in p.parents or not p.is_file() or p.suffix not in ('.json','.luau','.rgba'):
   self.send_error(404);return
  data=p.read_bytes();self.send_response(200);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_POST(self):
  if self.path not in ['/export/receipts.json','/export/studio-before.json','/export/checks.json','/export/runtime.json']:
   self.send_error(403);return
  length=int(self.headers.get('Content-Length',0))
  if length>20000000:self.send_error(413);return
  body=self.rfile.read(length);packet=json.loads(body)
  target=ROOT/self.path.lstrip('/')
  if self.path=='/export/studio-before.json' and isinstance(packet,dict) and 'batch' in packet:
   prior=json.loads(target.read_text()) if target.exists() and packet['batch']>0 else []
   prior.extend(packet['items']);body=json.dumps(prior).encode()
  target.write_bytes(body);self.send_response(200);self.end_headers();self.wfile.write(b'ok')
 def log_message(self,*args):pass
print('Vacuum-only transport 127.0.0.1:18794',flush=True)
ThreadingHTTPServer(('127.0.0.1',18794),Handler).serve_forever()
