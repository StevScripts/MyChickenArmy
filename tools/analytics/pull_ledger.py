#!/usr/bin/env python3
"""Pull the My Chicken Army analytics ledger through Roblox Open Cloud (no Studio needed).

Agents: read docs/analytics/AGENT_GUIDE.md first. This script fetches known keys
directly (d/<day>/<shard>, r/<day>, j/<day>/<shard>) so it does not depend on list
filters. Output: analytics-data/ledger_<from>_<to>_<env>.json with
  {"days": {day: {"source": ..., "shards": n, "v": {version: bucket}}},
   "journeys": {day: [...]}, "summary": {...}}
Bucket shape and every name are documented in the guide and AnalyticsSchema.luau.

Setup: create an Open Cloud API key with DataStore read access (entry read) for
universe 10765467283, then: export ROBLOX_OPEN_CLOUD_KEY=...
Usage: python3 tools/analytics/pull_ledger.py --days 7 [--env live|studio] [--journeys]
       [--players [--players-limit 200] [--players-sort robux|play|lastSeen]]
--players also lists analytics player profiles (p/<userId> in PetRollAnalyticsPlayers_v1)
into analytics-data/players_<env>.json; the key then also needs "list entry keys" access.
Endpoints verified 2026-10-09 (v2 Get Data Store Entry, v1 fallback). The response
shape was not exercised against a real key yet: if parsing fails, print the raw body.
"""
import argparse
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UNIVERSE = 10765467283
LEDGER = "PetRollAnalytics_v1"
STUDIO_SUFFIX = "_Studio"
SHARDS = 16  # must match Schema.Shards
TOP_CAP = 150
# Schema.Onboarding (schema 15, October 24): the onboarding funnel, ledger keys ob.*
# (reach, reach|platform, t, exit). It replaced the schema 11-14 Tutorial funnel (tf.*,
# old days only). Must match the schema (id, Roblox label); see ONBOARDING_FUNNEL.md.
ONBOARDING = [
    ("Joined", "Joined the game"),
    ("Loaded", "Save loaded"),
    ("Rolled", "Pulled the lever (1/7)"),
    ("ChickenTaken", "Took the chicken (2/7)"),
    ("Egg1", "1st egg clicked"),
    ("Eggs3", "3 eggs clicked (3/7)"),
    ("Sold", "Sold eggs on the pad (4/7)"),
    ("StartClaimed", "Claimed Start (5/7)"),
    ("PlotExpanded", "Expanded the plot (6/7)"),
    ("RolledAgain", "Tutorial done: lever again (7/7)"),
    ("Rebirth0", "Rebirth 0 done"),
    ("Chickens3", "Owns 3 chickens"),
    ("VacuumBought", "Bought the Egg Vacuum"),
    ("CluckCampWon", "Won Cluck Camp"),
    ("Rebirth1", "Rebirth 1"),
]
PLAYERS = "PetRollAnalyticsPlayers_v1"
# Schema.FeatureFunnels step ids, in order (NN = index). Must match the schema; funnels
# found in the data but missing here still appear with numbered steps.
FEATURE_FUNNELS = {
    "Roll": ["Pulled", "OfferAffordable", "Recruited", "Recruited10", "RareOrBetter", "EpicOrBetter", "LegendaryOrBetter"],
    "RollSlots": ["Unlocked2", "Unlocked4", "Unlocked8"],
    "AutoRoll": ["Available", "Enabled", "Stopped"],
    "Upgrades": ["MenuOpened", "Inspected", "FirstBuy", "Buys10", "Buys50"],
    "Army": ["ArmyOpened", "Selected", "Deployed", "Won", "CallArmy", "Rally", "Formation"],
    "Route": ["Camp1", "Camp2", "Camp3", "AllCamps", "King"],
    "Sell": ["Opened", "Sold"],
    "Index": ["Opened", "Inspected"],
    "Shop": ["Opened", "TabViewed", "Prompted", "PromptShown", "Purchased", "Repeat"],
    "Crate": ["Viewed", "Prompted", "Bought", "Opened"],
    "Pass": ["Prompted", "Bought", "Toggled"],
    "Rebirth": ["Eligible", "Opened", "Rebirthed", "Rebirth2", "Rebirth5", "Rebirth10"],
    "Mission": ["Spawned", "Opened", "Started", "Won", "Won5"],
    "Daily": ["Available", "Opened", "Claimed", "Streak3", "Streak7"],
    "Offline": ["Shown", "Claimed"],
    "Hill": ["Entered", "Held", "Won"],
    "Settings": ["Opened", "Changed"],
    "Leaderboard": ["Viewed"],
    # Version 12: the October 20 overhaul systems.
    "Flock": ["Tier1", "Tier4", "Tier6", "Max"],
    "Vacuum": ["Owned", "CapacityUp", "RangeUp"],
    "Feed": ["Owned", "Fed", "Fed10", "MaxLevelUp"],
    "GoldRolls": ["GoldMachine", "GoldRoll", "DiamondMachine", "DiamondRoll", "PrismMachine", "PrismRoll"],
    "Mutations": ["Unlocked", "Offered", "Bought"],
    "Gems": ["Earned", "Bought", "Bought5"],
    "PlaytimeRewards": ["Claimed", "Tile6", "Tile12"],
}
DEVICE_TIERS = ["Low", "Mid", "High", "Unknown"]  # must match Schema.DeviceTiers
PLATFORMS = ["Desktop", "Mobile", "Tablet", "Console", "VR", "Unknown"]


def get_entry(key, store, entry):
    quoted = urllib.parse.quote(entry, safe="")
    urls = [
        f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/data-stores/{urllib.parse.quote(store)}/entries/{quoted}",
        f"https://apis.roblox.com/datastores/v1/universes/{UNIVERSE}/standard-datastores/datastore/entries/entry"
        f"?datastoreName={urllib.parse.quote(store)}&entryKey={quoted}",
    ]
    for index, url in enumerate(urls):
        request = urllib.request.Request(url, headers={"x-api-key": key})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    body = json.loads(response.read().decode("utf-8"))
                    # v2 wraps the stored value; v1 returns it raw.
                    return body.get("value", body) if index == 0 and isinstance(body, dict) and "value" in body else body
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    return None
                if error.code == 429 or error.code >= 500:
                    time.sleep(1.5 * (attempt + 1))
                    continue
                if index == 0:
                    break  # try v1
                raise SystemExit(f"Open Cloud error {error.code} for {entry}: {error.read().decode('utf-8', 'replace')}")
    return None


def get_json(key, url):
    """GET with retries. Returns (status, body); status 0 means retries ran out."""
    request = urllib.request.Request(url, headers={"x-api-key": key})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return 200, json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            if error.code == 429 or error.code >= 500:
                time.sleep(1.5 * (attempt + 1))
                continue
            return error.code, error.read().decode("utf-8", "replace")
    return 0, None


def list_keys(key, store, prefix, limit):
    """Key names starting with prefix: v2 List Data Store Entries (filter id.startsWith), v1 prefix fallback."""
    base_v2 = f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/data-stores/{urllib.parse.quote(store)}/entries"
    keys, token = [], ""
    while len(keys) < limit:
        query = {"maxPageSize": min(256, limit - len(keys)), "filter": f'id.startsWith("{prefix}")'}
        if token:
            query["pageToken"] = token
        status, body = get_json(key, base_v2 + "?" + urllib.parse.urlencode(query))
        if status != 200 or not isinstance(body, dict):
            break
        keys.extend(entry.get("id", "") for entry in body.get("dataStoreEntries", []))
        token = body.get("nextPageToken") or ""
        if not token:
            return [k for k in keys if k.startswith(prefix)][:limit]
    if keys:
        return [k for k in keys if k.startswith(prefix)][:limit]
    keys, cursor = [], ""
    while len(keys) < limit:
        query = {"datastoreName": store, "prefix": prefix, "limit": min(100, limit - len(keys))}
        if cursor:
            query["cursor"] = cursor
        status, body = get_json(key, "https://apis.roblox.com/datastores/v1/universes/"
                                f"{UNIVERSE}/standard-datastores/datastore/entries?" + urllib.parse.urlencode(query))
        if status != 200 or not isinstance(body, dict):
            raise SystemExit(f"Open Cloud list error {status} for {store}: {body}")
        keys.extend(entry.get("key", "") for entry in body.get("keys", []))
        cursor = body.get("nextPageCursor") or ""
        if not cursor:
            break
    return [k for k in keys if k.startswith(prefix)][:limit]


def player_row(entry, profile):
    dev = profile.get("dev") if isinstance(profile.get("dev"), dict) else {}
    return {"userId": entry[2:], "first": profile.get("first"), "lastSeen": profile.get("lastSeen"),
            "days": profile.get("days"), "sessions": profile.get("sessions", 0), "play": profile.get("play", 0),
            "active": profile.get("active"), "idle": profile.get("idle"),
            # Launch-price estimate: v1 `robux` and v5 `robuxEstimate` count the same purchases.
            "robux": max(profile.get("robux") or 0, profile.get("robuxEstimate") or 0),
            "robuxActual": profile.get("robuxActual") or 0, "purchases": profile.get("purchases") or 0,
            "lastPurchase": profile.get("lastPurchase"), "firstPurchaseDevice": profile.get("firstPurchaseDevice"),
            "platform": dev.get("platform"), "tier": dev.get("tier"), "os": dev.get("os"), "input": dev.get("input"),
            "geo": profile.get("geo"), "premium": profile.get("premium"), "age": profile.get("age"),
            "joinSource": profile.get("joinSource"), "friendsInServer": profile.get("friendsInServer"),
            "rebirths": profile.get("rebirths"), "onboardingMax": max((int(k) for k in (profile.get("ob") or {}) if str(k).isdigit()), default=None), "lastExit": profile.get("lastExit"),
            "snap": profile.get("snap"), "life": profile.get("life"), "funN": profile.get("funN")}


def pull_players(key, env, limit, sort_by):
    """Same shape as AnalyticsReport.Players (rows + totals by tier/platform/geo)."""
    store = PLAYERS + (STUDIO_SUFFIX if env == "studio" else "")
    entries = list_keys(key, store, "p/", limit)
    rows, failures = [], 0
    for index, entry in enumerate(entries, start=1):
        profile = get_entry(key, store, entry)
        if isinstance(profile, dict):
            rows.append(player_row(entry, profile))
        else:
            failures += 1
        if index % 50 == 0:
            print(f"players: {index}/{len(entries)}", file=sys.stderr)
    spend = lambda r: max(r["robuxActual"] or 0, r["robux"] or 0)
    sorters = {"robux": lambda r: (-spend(r), -(r["play"] or 0)), "play": lambda r: -(r["play"] or 0),
               "lastSeen": lambda r: -(r["lastSeen"] or 0)}
    rows.sort(key=sorters.get(sort_by, sorters["robux"]))
    totals = {"players": len(rows), "payers": 0, "revenue": 0, "revenueEstimate": 0, "byTier": {}, "byPlatform": {},
              "byGeo": {}}
    for row in rows:
        paid = (row["purchases"] or 0) > 0 or (row["robuxActual"] or 0) > 0
        totals["payers"] += 1 if paid else 0
        totals["revenue"] += row["robuxActual"] or 0
        totals["revenueEstimate"] += row["robux"] or 0
        for group, value in (("byTier", row["tier"]), ("byPlatform", row["platform"]), ("byGeo", row["geo"])):
            bucket = totals[group].setdefault(str(value or "Unknown"), {"players": 0, "payers": 0, "revenue": 0, "play": 0})
            bucket["players"] += 1
            bucket["payers"] += 1 if paid else 0
            bucket["revenue"] += row["robuxActual"] or 0
            bucket["play"] += row["play"] or 0
    totals["payerRate"] = pct(totals["payers"], totals["players"])
    totals["arppu"] = round(totals["revenue"] / totals["payers"], 1) if totals["payers"] else None
    return {"env": env, "sortBy": sort_by, "scanned": len(entries), "readFailures": failures, "totals": totals,
            "players": rows}


def new_bucket():
    return {"c": {}, "h": {}, "m": {}, "t": {}, "x": {}}


def merge(into, frm):
    for name, value in frm.get("c", {}).items():
        into["c"][name] = into["c"].get(name, 0) + value
    for name, buckets in frm.get("h", {}).items():
        target = into["h"].setdefault(name, {})
        for label, count in buckets.items():
            target[label] = target.get(label, 0) + count
    for name, value in frm.get("m", {}).items():
        into["m"][name] = max(into["m"].get(name, value), value)
    for name, entries in frm.get("t", {}).items():
        target = into["t"].setdefault(name, {})
        for key, count in entries.items():
            if key in target or len(target) < TOP_CAP:
                target[key] = target.get(key, 0) + count
            else:
                target["(other)"] = target.get("(other)", 0) + count
    for day, counters in frm.get("x", {}).items():
        target = into["x"].setdefault(day, {})
        for name, value in counters.items():
            target[name] = target.get(name, 0) + value
    return into


def edge(label):
    if label.startswith("gt"):
        return float(label[2:]) + 0.5
    try:
        return float(label[2:])
    except ValueError:
        return float("inf")


def percentile(hist, p):
    if not hist:
        return None
    total = sum(hist.values())
    running = 0
    for label in sorted(hist, key=edge):
        running += hist[label]
        if running >= total * p:
            return label
    return None


def pct(a, b):
    return round(a / b * 100, 1) if a is not None and b else None


def prefixed(mapping, prefix):
    return {k[len(prefix):]: v for k, v in mapping.items() if k.startswith(prefix)}


def top(mapping, limit):
    return sorted((mapping or {}).items(), key=lambda kv: -kv[1])[:limit]


def feature_funnels(c, h):
    names = dict(FEATURE_FUNNELS)
    for key in c:
        parts = key.split(".")
        if len(parts) == 4 and parts[0] == "fun" and parts[1] not in names:
            names[parts[1]] = []
    rows = []
    for funnel, ids in names.items():
        count = len(ids)
        for key in c:
            parts = key.split(".")
            if len(parts) == 4 and parts[0] == "fun" and parts[1] == funnel and parts[3].isdigit():
                count = max(count, int(parts[3]))
        steps, previous = [], None
        for index in range(1, count + 1):
            nn = f"{index:02d}"
            players = c.get(f"fun.{funnel}.p.{nn}", 0)
            steps.append({"id": ids[index - 1] if index <= len(ids) else nn, "nn": nn,
                          "sessions": c.get(f"fun.{funnel}.s.{nn}", 0), "players": players,
                          "conversionFromPrev": pct(players, previous),
                          "timeP50": percentile(h.get(f"fun.{funnel}.t.{nn}"), 0.5),
                          "lastStepSessions": c.get(f"fun.{funnel}.last.{nn}", 0)})
            previous = players
        rows.append({"funnel": funnel, "steps": steps})
    return rows


def devices(c, t):
    tiers = []
    for tier in DEVICE_TIERS + sorted(prefixed(c, "seg.session.tier.")):
        if tier in [row["segment"] for row in tiers]:
            continue
        payers, revenue = c.get(f"robux.payer.tier.{tier}", 0), c.get(f"robux.actual.tier.{tier}", 0)
        tiers.append({"segment": tier, "sessions": c.get(f"seg.session.tier.{tier}", 0), "payers": payers,
                      "revenue": revenue, "arppu": round(revenue / payers, 1) if payers else None})
    platforms = []
    for platform in PLATFORMS:
        sessions, payers = c.get(f"session.count|{platform}", 0), c.get(f"robux.payer|{platform}", 0)
        revenue = c.get(f"robux.actual|{platform}", 0)
        if sessions or payers or revenue:
            platforms.append({"segment": platform, "sessions": sessions, "payers": payers, "revenue": revenue,
                              "arppu": round(revenue / payers, 1) if payers else None})
    return {"byTier": tiers, "byPlatform": platforms, "viewports": top(t.get("client.viewport"), 30),
            "locales": top(t.get("client.locale"), 30), "quality": prefixed(c, "client.quality."),
            "inset": prefixed(c, "client.inset."), "geo": top(t.get("seg.geo"), 30),
            "payersByGeo": top(t.get("robux.payer.geo"), 30),
            "note": "Tier is a proxy (viewport, memory, FPS, graphics quality); Roblox exposes no device model."}


def robux_actual(c, h):
    by_key = {k: v for k, v in prefixed(c, "robux.actual.").items()
              if k != "n" and not k.startswith("tier.") and not k.startswith("premium.")}
    payers = sum(prefixed(c, "robux.payer.tier.").values())
    total = c.get("robux.actual", 0)
    return {"total": total, "purchases": c.get("robux.actual.n", 0), "byKey": top(by_key, 50),
            "purchaseSizeP50": percentile(h.get("robux.purchase"), 0.5), "newPayers": payers,
            "arppu": round(total / payers, 1) if payers else None, "estimate": c.get("robux.estimate", 0)}


def summarize(days):
    total = new_bucket()
    for entry in days.values():
        for bucket in entry["v"].values():
            merge(total, bucket)
    c, h = total["c"], total["h"]
    onboarding, previous = [], None
    first = c.get("ob.reach.01")
    for index, (step_id, label) in enumerate(ONBOARDING, start=1):
        code = f"{index:02d}"
        reached = c.get(f"ob.reach.{code}", 0)
        onboarding.append({"step": f"{code} {label}", "id": step_id, "reached": reached, "ofJoined": pct(reached, first),
                           "ofPrevious": pct(reached, previous), "timeP50": percentile(h.get(f"ob.t.{code}"), 0.5),
                           "exitsHere": c.get(f"ob.exit.{code}", 0)})
        previous = reached
    exits = sorted(({"step": k[len("ob.exit."):], "n": v} for k, v in c.items() if k.startswith("ob.exit.")),
                   key=lambda e: -e["n"])
    cohorts = []
    for day, counters in sorted(total["x"].items()):
        size = counters.get("cohort.size", 0)
        cohorts.append({"cohort": day, "size": size,
                        "retention": {k[4:]: {"n": v, "pct": pct(v, size)} for k, v in counters.items() if k.startswith("ret.d")},
                        })
    sessions = c.get("session.count", 0)
    return {
        "totals": {"unique": c.get("players.unique", 0), "new": c.get("players.new", 0), "sessions": sessions,
                   "avgSessionSec": round(c.get("session.seconds", 0) / sessions) if sessions else None,
                   "sessionP50": percentile(h.get("session.seconds"), 0.5)},
        "onboarding": onboarding, "onboardingExits": exits, "cohorts": cohorts,
        "economy": {"sourceTotal": c.get("econ.srcTotal", 0), "sinkTotal": c.get("econ.sinkTotal", 0)},
        "rolls": {"count": c.get("roll.count", 0), "anyAffordablePct": pct(c.get("roll.anyAffordable"), c.get("roll.count"))},
        "featureFunnels": feature_funnels(c, h),
        "robuxActual": robux_actual(c, h),
        "devices": devices(c, total["t"]),
        "uiPrompts": {"shown": c.get("ui.prompt.shown", 0), "bought": c.get("ui.prompt.bought", 0),
                      "cancel": c.get("ui.prompt.cancel", 0),
                      "cancelRate": pct(c.get("ui.prompt.cancel", 0),
                                        c.get("ui.prompt.bought", 0) + c.get("ui.prompt.cancel", 0)),
                      "byResult": top(total["t"].get("ui.prompt.result"), 30)},
        "errors": {"server": c.get("err.server", 0), "client": c.get("err.client", 0),
                   "topServer": sorted(total["t"].get("err.server", {}).items(), key=lambda kv: -kv[1])[:10],
                   "topClient": sorted(total["t"].get("err.client", {}).items(), key=lambda kv: -kv[1])[:10]},
        "note": "Lite summary. AnalyticsReport.luau (Studio) computes the full one with flags.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--to", help="last UTC day YYYY-MM-DD (default today)")
    parser.add_argument("--env", choices=["live", "studio"], default="live")
    parser.add_argument("--journeys", action="store_true", help="also fetch sampled journeys")
    parser.add_argument("--out", default="analytics-data")
    parser.add_argument("--players", action="store_true", help="also list player profiles (p/<userId>)")
    parser.add_argument("--players-limit", type=int, default=200)
    parser.add_argument("--players-sort", choices=["robux", "play", "lastSeen"], default="robux")
    args = parser.parse_args()
    key = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    if not key:
        sys.exit("Set ROBLOX_OPEN_CLOUD_KEY (Open Cloud API key with DataStore read access).")
    store = LEDGER + (STUDIO_SUFFIX if args.env == "studio" else "")
    last = dt.date.fromisoformat(args.to) if args.to else dt.datetime.now(dt.timezone.utc).date()
    today = dt.datetime.now(dt.timezone.utc).date()
    day_list = [(last - dt.timedelta(days=i)).isoformat() for i in range(args.days - 1, -1, -1)]
    days, journeys = {}, {}
    for day in day_list:
        rollup = get_entry(key, store, f"r/{day}") if day < today.isoformat() else None
        if isinstance(rollup, dict) and rollup.get("v"):
            days[day] = {"source": "rollup", "shards": rollup.get("shards", 0), "v": rollup["v"]}
        else:
            merged, shards = {}, 0
            for shard in range(SHARDS):
                record = get_entry(key, store, f"d/{day}/{shard}")
                if isinstance(record, dict) and isinstance(record.get("v"), dict):
                    shards += 1
                    for version, bucket in record["v"].items():
                        merged[version] = merge(merged.get(version, new_bucket()), bucket)
            days[day] = {"source": "shards" if shards else "empty", "shards": shards, "v": merged}
        if args.journeys:
            entries = []
            for shard in range(SHARDS):
                record = get_entry(key, store, f"j/{day}/{shard}")
                if isinstance(record, dict):
                    entries.extend(record.get("list", []))
            journeys[day] = entries
        print(f"{day}: {days[day]['source']} ({days[day]['shards']} shards)", file=sys.stderr)
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, f"ledger_{day_list[0]}_{day_list[-1]}_{args.env}.json")
    with open(path, "w") as handle:
        json.dump({"pulledAt": dt.datetime.now(dt.timezone.utc).isoformat(), "env": args.env, "days": days,
                   "journeys": journeys, "summary": summarize(days)}, handle, indent=1)
    print(path)
    if args.players:
        players = pull_players(key, args.env, args.players_limit, args.players_sort)
        players_path = os.path.join(args.out, f"players_{args.env}.json")
        with open(players_path, "w") as handle:
            json.dump(dict(players, pulledAt=dt.datetime.now(dt.timezone.utc).isoformat()), handle, indent=1)
        print(players_path)


if __name__ == "__main__":
    main()
