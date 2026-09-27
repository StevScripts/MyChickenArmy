"""Local-only raw pixel bridge and durable receipts for the authorized uploads."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "portrait-manifest.json"

class Handler(BaseHTTPRequestHandler):
    def reply(self, data, kind="application/json"):
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def row(self, species):
        manifest = json.loads(MANIFEST.read_text())
        return manifest, next((p for p in manifest["portraits"] if p["species"] == species), None)

    def do_GET(self):
        match = re.fullmatch(r"/(metadata|pixels)/([A-Za-z0-9]+)", self.path)
        if not match:
            self.send_error(404); return
        kind, species = match.groups()
        _, row = self.row(species)
        if not row:
            self.send_error(404); return
        if kind == "metadata":
            self.reply(json.dumps(row).encode()); return
        data = (ROOT / "upload-pixels" / (species + ".rgba")).read_bytes()
        assert len(data) == 512*512*4 and hashlib.sha256(data).hexdigest() == row["rgbaSha256"]
        self.reply(data, "application/octet-stream")

    def do_POST(self):
        match = re.fullmatch(r"/receipt/([A-Za-z0-9]+)", self.path)
        length = int(self.headers.get("Content-Length", "0"))
        if not match or not 0 < length < 4000:
            self.send_error(400); return
        manifest, row = self.row(match.group(1))
        receipt = json.loads(self.rfile.read(length))
        if (not row or receipt.get("sha256") != row["outlinedSha256"]
                or receipt.get("creatorGroupId") != 778575811
                or not str(receipt.get("assetId", "")).isdigit()):
            self.send_error(400); return
        asset_id = str(receipt["assetId"])
        if row.get("outlinedAssetId") not in (None, asset_id):
            self.send_error(409); return
        row["outlinedAssetId"] = asset_id
        uploaded = sum("outlinedAssetId" in p for p in manifest["portraits"])
        manifest["status"] = f"{uploaded}/10 outlined portraits uploaded"
        temporary = MANIFEST.with_suffix(".tmp")
        temporary.write_text(json.dumps(manifest, indent=2) + "\n")
        temporary.replace(MANIFEST)
        self.reply(json.dumps({"saved": True, "uploaded": uploaded}).encode())

if __name__ == "__main__":
    print("Army portrait bridge listening on 127.0.0.1:18826", flush=True)
    HTTPServer(("127.0.0.1", 18826), Handler).serve_forever()
