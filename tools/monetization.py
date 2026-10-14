#!/usr/bin/env python3
"""Manage My Chicken Army game passes and developer products through Roblox Open Cloud.

The game is owned by the Kiru Experiences group, so the API key must be a group key
with game-pass and developer-product read/write. It is read from ROBLOX_API_KEY or
~/.config/roblox/api_key (chmod 600) and is never printed.

  python3 tools/monetization.py status
      Read-only: live passes/products next to src/shared/ShopCatalog.luau
      (name, Robux price, for sale, icon), with mismatches flagged.
  python3 tools/monetization.py create-pass --name N --price 199 --description D --icon icon.png [--for-sale]
  python3 tools/monetization.py create-product --name N --price 49 --description D --icon icon.png [--for-sale]
  python3 tools/monetization.py update-pass ID [--name N] [--price P] [--description D] [--icon F] [--for-sale|--off-sale]
  python3 tools/monetization.py update-product ID [same options]

Every create/update only prints what it would send unless --yes is given. Prices and
sale state are live for players: show the dry run to the owner before using --yes.
Open Cloud has no delete; take an item off sale instead. Rate limits: 5 writes/s for
passes, 3 writes/s for products (one write per command here).
"""
import argparse
import json
import mimetypes
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

UNIVERSE_ID = 10765467283  # Place 96683186622050 (My Chicken Army)
API = "https://apis.roblox.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "src", "shared", "ShopCatalog.luau")


def api_key():
	key = os.environ.get("ROBLOX_API_KEY")
	if not key:
		path = os.path.expanduser("~/.config/roblox/api_key")
		if os.path.exists(path):
			with open(path) as handle:
				key = handle.read().strip()
	if not key:
		sys.exit("No API key: set ROBLOX_API_KEY or write ~/.config/roblox/api_key (chmod 600).")
	return key


def request(method, path, fields=None, files=None):
	url = API + path
	headers = {"x-api-key": api_key()}
	body = None
	if fields is not None or files:
		boundary = uuid.uuid4().hex
		parts = []
		for name, value in (fields or {}).items():
			parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
		for name, path_on_disk in (files or {}).items():
			with open(path_on_disk, "rb") as handle:
				data = handle.read()
			mime = mimetypes.guess_type(path_on_disk)[0] or "application/octet-stream"
			filename = os.path.basename(path_on_disk)
			parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
				f"Content-Type: {mime}\r\n\r\n".encode() + data + b"\r\n")
		parts.append(f"--{boundary}--\r\n".encode())
		body = b"".join(parts)
		headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
	req = urllib.request.Request(url, data=body, method=method, headers=headers)
	try:
		with urllib.request.urlopen(req, timeout=60) as response:
			text = response.read().decode() or "{}"
			return json.loads(text)
	except urllib.error.HTTPError as error:
		sys.exit(f"{method} {path} failed: HTTP {error.code} {error.read().decode()[:500]}")


def list_all(path, key):
	items, token = [], None
	while True:
		query = "?pageSize=100" + (f"&pageToken={token}" if token else "")
		page = request("GET", path + query)
		items += page.get(key, [])
		token = page.get("nextPageToken")
		if not token:
			return items


def catalog_entries():
	"""Pass and product entries from ShopCatalog: key, kind, id, name, proposedPrice."""
	text = open(CATALOG).read()
	entries = []
	starts = [m for m in re.finditer(r"^\t\t(\w+)\s*=\s*\{", text, re.M)]
	for i, match in enumerate(starts):
		end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
		chunk = text[match.start():end]
		ident = re.search(r"\b(passId|productId)\s*=\s*(\d+)", chunk)
		if not ident:
			continue
		name = re.search(r'\bname\s*=\s*"([^"]*)"', chunk)
		price = re.search(r"\bproposedPrice\s*=\s*(\d+)", chunk)
		entries.append({"key": match.group(1), "kind": "pass" if ident.group(1) == "passId" else "product",
			"id": int(ident.group(2)), "name": name and name.group(1), "price": price and int(price.group(1))})
	return entries


def status(_args):
	passes = list_all(f"/game-passes/v1/universes/{UNIVERSE_ID}/game-passes/creator", "gamePasses")
	products = list_all(f"/developer-products/v2/universes/{UNIVERSE_ID}/developer-products/creator", "developerProducts")
	live = {("pass", p["gamePassId"]): p for p in passes}
	live.update({("product", p["productId"]): p for p in products})
	seen = set()
	print(f"Universe {UNIVERSE_ID}: {len(passes)} game passes, {len(products)} developer products live.\n")
	header = f"{'kind':8} {'id':>11}  {'catalog key':18} {'live name':28} {'live R$':>7} {'catalog R$':>10} {'sale':5}  notes"
	print(header)
	print("-" * len(header))
	for entry in catalog_entries():
		item = live.get((entry["kind"], entry["id"]))
		seen.add((entry["kind"], entry["id"]))
		if not item:
			print(f"{entry['kind']:8} {entry['id']:>11}  {entry['key']:18} {'(not found live)':28} {'':>7} {entry['price'] or '':>10}")
			continue
		price = (item.get("priceInformation") or {}).get("defaultPriceInRobux")
		notes = []
		if entry["price"] is not None and price != entry["price"]:
			notes.append("PRICE DIFFERS")
		if entry["name"] and item["name"] != entry["name"]:
			notes.append(f'catalog name "{entry["name"]}"')
		icon = item.get("iconAssetId") or item.get("iconImageAssetId")
		print(f"{entry['kind']:8} {entry['id']:>11}  {entry['key']:18} {item['name'][:28]:28} {price if price is not None else '-':>7} "
			f"{entry['price'] if entry['price'] is not None else '-':>10} {'yes' if item.get('isForSale') else 'no':5}  "
			f"{'; '.join(notes)}{'' if icon else ' NO ICON'}")
	extra = [(k, v) for k, v in live.items() if k not in seen]
	if extra:
		print("\nLive but not in ShopCatalog:")
		for (kind, ident), item in extra:
			price = (item.get("priceInformation") or {}).get("defaultPriceInRobux")
			print(f"  {kind:8} {ident:>11}  {item['name']}  R${price}  sale={'yes' if item.get('isForSale') else 'no'}")


def write(args, kind, ident=None):
	fields = {}
	if args.name is not None: fields["name"] = args.name
	if args.description is not None: fields["description"] = args.description
	if args.price is not None: fields["price"] = str(args.price)
	if args.sale is not None: fields["isForSale"] = "true" if args.sale else "false"
	files = {}
	if args.icon:
		if not os.path.exists(args.icon): sys.exit(f"Icon not found: {args.icon}")
		# Create uses imageFile; the pass update endpoint names the field `file`.
		files["file" if (kind == "pass" and ident) else "imageFile"] = args.icon
	if ident is None and not args.name:
		sys.exit("--name is required to create.")
	if kind == "pass":
		path = f"/game-passes/v1/universes/{UNIVERSE_ID}/game-passes" + (f"/{ident}" if ident else "")
	else:
		path = f"/developer-products/v2/universes/{UNIVERSE_ID}/developer-products" + (f"/{ident}" if ident else "")
	method = "PATCH" if ident else "POST"
	print(f"{method} {path}")
	for key, value in fields.items(): print(f"  {key} = {value}")
	for key, value in files.items(): print(f"  {key} <- {value}")
	if not args.yes:
		print("Dry run: nothing sent. Re-run with --yes to apply.")
		return
	result = request(method, path, fields, files)
	print(json.dumps(result, indent=2))


def main():
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = parser.add_subparsers(dest="command", required=True)
	sub.add_parser("status").set_defaults(run=status)
	for command, kind, update in [("create-pass", "pass", False), ("create-product", "product", False),
			("update-pass", "pass", True), ("update-product", "product", True)]:
		p = sub.add_parser(command)
		if update: p.add_argument("id", type=int)
		p.add_argument("--name"); p.add_argument("--description"); p.add_argument("--price", type=int)
		p.add_argument("--icon", help="PNG/JPG icon (square, 512x512 recommended)")
		sale = p.add_mutually_exclusive_group()
		sale.add_argument("--for-sale", dest="sale", action="store_const", const=True)
		sale.add_argument("--off-sale", dest="sale", action="store_const", const=False)
		p.add_argument("--yes", action="store_true", help="Actually send the change")
		p.set_defaults(sale=None, run=lambda a, kind=kind, update=update: write(a, kind, a.id if update else None))
	args = parser.parse_args()
	args.run(args)


if __name__ == "__main__":
	main()
