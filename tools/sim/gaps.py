# Per-rank played-minute gaps from unlock_probe / sim run JSONs (runs[i].milestones.RebirthN.played)
# or cost_fit rows (list of per-seed rank arrays). Prints medians and writes targets JSON.
import json, sys, statistics
def load(path):
    d = json.load(open(path))
    rows = []
    if isinstance(d, list):
        for row in d: rows.append([None if v is None or v < 0 else v for v in row])
    else:
        for run in d["runs"]:
            m = run["milestones"]
            rows.append([ (m.get("Rebirth%d" % r) or {}).get("played") for r in range(1, 51)])
    return rows
def gaps(rows):
    out = []
    for row in rows:
        g = [None]*50; prev = 0
        for i, v in enumerate(row):
            if v is None: break
            g[i] = v - prev; prev = v
        out.append(g)
    return out
def medians(gapRows):
    med, n = [], []
    for r in range(50):
        vals = [g[r] for g in gapRows if g[r] is not None]
        med.append(statistics.median(vals) if vals else None); n.append(len(vals))
    return med, n
if __name__ == "__main__":
    files = [a for a in sys.argv[1:] if not a.startswith("out=") and not a.startswith("scale=")]
    out = next((a[4:] for a in sys.argv[1:] if a.startswith("out=")), None)
    rows = []
    for f in files: rows += load(f)
    med, n = medians(gaps(rows))
    cum = 0
    for r in range(50):
        if med[r] is None: print("R%-2d  gap   -  (0 seeds)" % (r+1)); continue
        cum += med[r]
        print("R%-2d  gap %6.1f min  cum %6.1f h  (%d seeds)" % (r+1, med[r], cum/60, n[r]))
    if out: json.dump({"gaps": med, "seeds": n}, open(out, "w"))
