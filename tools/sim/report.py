# report.py <runs dir>: unlock tables (medians per profile), play minutes per rank, daily droughts,
# inside-a-run table for the fast seeds. Profiles: fast-*, casual-*, daily120-*, daily45-*.
import json, sys, glob, os, statistics
d = sys.argv[1]
groups = {"fast": "Fast, nonstop", "casual": "Casual, nonstop", "daily120": "2 h a day", "daily45": "45 min a day"}
def load(prefix):
    out = []
    for f in sorted(glob.glob(os.path.join(d, prefix + "-*.json"))):
        j = json.load(open(f))
        for run, probe in zip(j["runs"], j["probes"]):
            out.append((run, probe, j))
    return out
def med(vals): return statistics.median(vals) if vals else None
def when(minutes, login):
    if minutes is None: return None
    if minutes < 90: return "%.0f min" % minutes
    if login: return "day %d" % (int(minutes // 1440) + 1)
    return "%.1f h" % (minutes / 60)
def cell(vals, n, login, rank=None):
    vals = [v for v in vals if v is not None]
    if not vals: return "never"
    s = when(med(vals), login)
    if rank: s += " (R%d)" % round(med(rank))
    if len(vals) < n: s += " (%d/%d)" % (len(vals), n)
    return s
def row(label, getter, rankGetter=None):
    cells = []
    for key, name in groups.items():
        runs = load(key)
        if not runs: cells.append("-"); continue
        login = runs[0][2]["options"].get("playMinutes") is not None
        vals = [getter(r, p) for r, p, _ in runs]
        ranks = [rankGetter(r, p) for r, p, _ in runs if rankGetter] if rankGetter else None
        ranks = [x for x in ranks if x is not None] if ranks else None
        cells.append(cell(vals, len(runs), login, ranks if ranks else None))
    print("| " + label + " | " + " | ".join(cells) + " |")
def ms(r, key): m = r["milestones"].get(key); return m["minutes"] if m else None
def ft(p, node): f = p["firstTier"].get(node); return f["minutes"] if f else None
def ftr(p, node): f = p["firstTier"].get(node); return f["rank"] if f else None
print("| Milestone | " + " | ".join(groups.values()) + " |")
print("|---|" + "---|" * len(groups))
def r12(r, p):
    a, b = ms(r, "Rebirth1"), ms(r, "Rebirth2")
    return None if a is None or b is None else a
row("Rebirth 1", lambda r, p: ms(r, "Rebirth1")); row("Rebirth 2", lambda r, p: ms(r, "Rebirth2"))
for k in (5, 10, 20, 30, 40, 50): row("Rebirth %d%s" % (k, " (max)" if k == 50 else ""), lambda r, p, k=k: ms(r, "Rebirth%d" % k))
row("Gem board complete", lambda r, p: ms(r, "GemBoardDone"))
row("All 3 camps", lambda r, p: ms(r, "AllCamps")); row("King", lambda r, p: ms(r, "King"))
for rar in ("Legendary", "Mythic", "Secret"):
    row("First %s owned" % rar, lambda r, p, rar=rar: (p["owned"].get(rar) or {}).get("minutes"), lambda r, p, rar=rar: (p["owned"].get(rar) or {}).get("rank"))
row("First Secret offer", lambda r, p: (p["seen"].get("Secret") or {}).get("minutes"), lambda r, p: (p["seen"].get("Secret") or {}).get("rank"))
for label, node in (("All 8 podiums", "RollSlot7"), ("All 4 Mutations", "Mutation4"), ("Luck IV (x3)", "Luck4"), ("Egg Speed IV", "EggSpeed4"),
        ("Egg Value IV", "EggValue4"), ("Super Luck IV (x5)", "Luck8"), ("Flock Size 15", "Flock8"), ("Mega Luck IV (x10)", "Luck12")):
    row(label, lambda r, p, node=node: ft(p, node), lambda r, p, node=node: ftr(p, node))
print()
# Play minutes per rank bands
bands = [(1, 5), (6, 10), (11, 15), (16, 20), (21, 30), (31, 40), (41, 50)]
print("| Ranks | " + " | ".join(groups.values()) + " |"); print("|---|" + "---|" * len(groups))
for lo, hi in bands:
    cells = []
    for key in groups:
        runs = load(key)
        if not runs: cells.append("-"); continue
        meds, longest = [], 0
        for rank in range(lo, hi + 1):
            gaps = []
            for r, _, _ in runs:
                a, b = r["milestones"].get("Rebirth%d" % rank), r["milestones"].get("Rebirth%d" % (rank - 1)) if rank > 1 else {"played": 0}
                if a and b: gaps.append(a["played"] - b["played"])
            if gaps: meds.append(med(gaps)); longest = max(longest, max(gaps))
        cells.append("%.0f–%.0f (%.0f)" % (min(meds), max(meds), longest) if meds else "-")
    print("| %d–%d | " % (lo, hi) + " | ".join(cells) + " |")
print()
# Daily droughts
for key in ("daily45", "daily120"):
    for r, p, j in load(key):
        days = sorted(set(int(r["milestones"]["Rebirth%d" % k]["minutes"] // 1440) + 1 for k in range(1, 51) if "Rebirth%d" % k in r["milestones"]))
        last = max(days); dry = [dday for dday in range(12, last + 1) if dday not in days]
        longest, cur = 0, 0
        for dday in range(12, last + 1):
            cur = cur + 1 if dday not in days else 0; longest = max(longest, cur)
        print("%s seed %d: Rebirth %d on day %d; %d of days 12–%d without a Rebirth; longest drought %d day(s)" % (key, r["seed"], r["final"]["rank"], last, len(dry), last, longest))
print()
# Inside a run (fast seeds): median across seeds
runs = load("fast")
print("| Rebirth | cost | income before the reset | next run's tree | tree in minutes of that income | tree / next Rebirth | hexes owned | play min this rank |")
print("|---|---|---|---|---|---|---|---|")
def incomeBefore(r, rank):
    # last trace sample of the run that ends in this Rebirth (its rank is rank-1)
    best = None
    for t in r.get("trace") or []:
        if t["rank"] == rank - 1 and (best is None or t["minutes"] > best["minutes"]): best = t
    return best["income"] if best else None
def fmt(n):
    for u, s in ((1e15, "Qa"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if n >= u: return "%.3g%s" % (n / u, s)
    return "%.0f" % n
for rank in (3, 5, 8, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50):
    rows = []
    for r, p, j in runs:
        m = r["milestones"].get("Rebirth%d" % rank); prev = r["milestones"].get("Rebirth%d" % (rank - 1)) if rank > 1 else {"played": 0}
        snap = next((s for s in p["rebirths"] if s["rank"] == rank), None)
        if not m or not snap: continue
        tree = snap.get("nextTreeTotal") or j["tree"]["total"]
        nextCost = snap.get("nextCost") or (j["options"] and None)
        income = incomeBefore(r, rank) or m["income"]
        rows.append((m["cost"], income, tree, tree / income / 60 if income else None, tree / nextCost if nextCost else None, snap["treeOwned"], m["played"] - prev["played"]))
    if not rows: continue
    cols = list(zip(*rows))
    print("| %d | %s | %s/s | %s | %s | %s | %d | %.0f |" % (rank, fmt(med(cols[0])), fmt(med(cols[1])), fmt(med(cols[2])),
        "%.1f" % med(cols[3]) if cols[3][0] is not None else "-", "%.0f%%" % (100 * med(cols[4])) if cols[4][0] is not None else "-", round(med(cols[5])), med(cols[6])))
