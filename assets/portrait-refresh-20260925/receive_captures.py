"""Local-only Photobooth RGBA export: lossless PNG encoding, no image restyling."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs
import json
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parent

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        path = urlparse(self.path)
        match = re.fullmatch(r'/pixels/([A-Za-z][A-Za-z0-9_]*)', path.path)
        if not match:
            self.send_error(404)
            return
        dims = parse_qs(path.query)
        width, height = int(dims['w'][0]), int(dims['h'][0])
        size = int(self.headers['Content-Length'])
        if not (1 <= width <= 2048 and 1 <= height <= 2048 and size == width * height * 4):
            self.send_error(400)
            return
        rgba = self.rfile.read(size)
        stride = width * 4
        scanlines = b''.join(b'\x00' + rgba[i:i+stride] for i in range(0, size, stride))
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
        png += chunk(b'IDAT', zlib.compress(scanlines, 6)) + chunk(b'IEND', b'')
        name = match.group(1)
        output = ROOT / 'png' / (name + '.png')
        output.parent.mkdir(exist_ok=True)
        output.write_bytes(png)
        alphas = rgba[3::4]
        visible = sum(a > 0 for a in alphas)
        response = json.dumps(dict(name=name, width=width, height=height, visiblePixels=visible, bytes=len(png))).encode()
        (ROOT / 'png' / (name + '.json')).write_bytes(response)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)

if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 18794), Handler).serve_forever()
