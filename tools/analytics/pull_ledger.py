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
ONBOARDING = ["Joined", "ProfileLoaded", "IntroStarted", "IntroEnded", "ControlReady", "FirstEgg", "Collect",
              "Sell", "Roll", "Recruit", "Grow", "Expand", "Select", "Deploy", "Win", "GuideComplete",
              "Camp2", "Camp3", "King"]  # must match Schema.Onboarding


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


def summarize(days):
    total = new_bucket()
    for entry in days.values():
        for bucket in entry["v"].values():
            merge(total, bucket)
    c, h = total["c"], total["h"]
    funnel, previous = [], None
    first = c.get("onb.reach.01")
    for index, step in enumerate(ONBOARDING, start=1):
        code = f"{index:02d}"
        reached = c.get(f"onb.reach.{code}", 0)
        funnel.append({"step": f"{code} {step}", "reached": reached, "ofJoined": pct(reached, first),
                       "ofPrevious": pct(reached, previous), "timeP50": percentile(h.get(f"onb.t.{code}"), 0.5)})
        previous = reached
    exits = sorted(({"guideStep": k[len("onb.exit."):], "n": v} for k, v in c.items() if k.startswith("onb.exit.")),
                   key=lambda e: -e["n"])
    cohorts = []
    for day, counters in sorted(total["x"].items()):
        size = counters.get("cohort.size", 0)
        cohorts.append({"cohort": day, "size": size,
                        "retention": {k[4:]: {"n": v, "pct": pct(v, size)} for k, v in counters.items() if k.startswith("ret.d")},
                        "steps": {k[4:]: v for k, v in counters.items() if k.startswith("onb.")}})
    sessions = c.get("session.count", 0)
    return {
        "totals": {"unique": c.get("players.unique", 0), "new": c.get("players.new", 0), "sessions": sessions,
                   "avgSessionSec": round(c.get("session.seconds", 0) / sessions) if sessions else None,
                   "sessionP50": percentile(h.get("session.seconds"), 0.5)},
        "onboardingFunnel": funnel, "onboardingExits": exits, "cohorts": cohorts,
        "economy": {"sourceTotal": c.get("econ.srcTotal", 0), "sinkTotal": c.get("econ.sinkTotal", 0)},
        "rolls": {"count": c.get("roll.count", 0), "anyAffordablePct": pct(c.get("roll.anyAffordable"), c.get("roll.count"))},
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


if __name__ == "__main__":
    main()
