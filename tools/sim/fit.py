# fit.py targets.json measured.json costs_in.json costs_out.json [damp=0.8] [smooth=5]
# targets/measured are gaps.py outputs ({"gaps": [...50], "seeds": [...50]}).
# New cost[r] = cost[r] * (target gap[r] / measured gap[r])^damp, log-smoothed over `smooth`
# ranks, clamped to the ratio bands (x3-20 through Rebirth 10, x1.1-3 after), rounded to three
# figures. Ranks 1-5 (their runs pay base tree prices) and 50 are fixed. Ranks without a measured gap keep the previous
# adjustment (the last fitted rank's factor).
import json, sys, math
targets = json.load(open(sys.argv[1]))["gaps"]
measured = json.load(open(sys.argv[2])); meas, n = measured["gaps"], measured["seeds"]
costs = json.load(open(sys.argv[3]))
damp = float(next((a[5:] for a in sys.argv if a.startswith("damp=")), 0.8))
smooth = int(next((a[7:] for a in sys.argv if a.startswith("smooth=")), 5))
logf = [0.0]*50
last = 0.0
for r in range(50):
    rank = r+1
    if rank <= 5 or rank == 50: logf[r] = 0.0; continue
    if targets[r] is None or meas[r] is None or n[r] < 1 or meas[r] <= 0:
        logf[r] = last; continue
    logf[r] = damp * math.log(targets[r] / meas[r]); last = logf[r]
sm = logf[:]
h = smooth // 2
for r in range(2, 49):
    lo, hi = max(2, r-h), min(48, r+h)
    sm[r] = sum(logf[lo:hi+1]) / (hi-lo+1)
new = costs[:]
for r in range(5, 49): new[r] = costs[r] * math.exp(sm[r])
def round3(x):
    e = math.floor(math.log10(x)) - 2
    return round(x / 10**e) * 10**e
# ratio bands, forward then backward against the fixed R50
for r in range(5, 49):
    rank = r+1
    lo, hi = (3, 20) if rank <= 10 else (1.1, 3)
    new[r] = min(max(new[r], new[r-1]*lo), new[r-1]*hi)
for r in range(48, 5, -1):
    rank = r+1
    lo, hi = (3, 20) if rank <= 10 else (1.1, 3)
    # new[r] must be within [new[r+1]/hi, new[r+1]/lo]
    new[r-1] = min(max(new[r-1], new[r]/hi), new[r]/lo)
for r in range(5, 49): new[r] = round3(new[r])
# Rounding may nudge a ratio outside its band: round the offender up (or down) to three figures.
def ceil3(x):
    e = math.floor(math.log10(x)) - 2
    return math.ceil(x / 10**e - 1e-9) * 10**e
def floor3(x):
    e = math.floor(math.log10(x)) - 2
    return math.floor(x / 10**e + 1e-9) * 10**e
for r in range(5, 49):
    rank = r+1
    lo, hi = (3, 20) if rank <= 10 else (1.1, 3)
    if new[r] < new[r-1]*lo: new[r] = ceil3(new[r-1]*lo)
    if new[r] > new[r-1]*hi: new[r] = floor3(new[r-1]*hi)
assert new[49] >= new[48]*1.1 and new[49] <= new[48]*3, "Rebirth 50 band"
json.dump(new, open(sys.argv[4], "w"))
for r in range(50):
    t = targets[r]; m = meas[r]
    print("R%-2d target %6s meas %6s (%d) f=%.3f sm=%.3f  %.3g -> %.3g  x%.2f" % (r+1,
        "%.0f" % t if t is not None else "-", "%.0f" % m if m is not None else "-", n[r], math.exp(logf[r]), math.exp(sm[r]), costs[r], new[r], new[r]/new[r-1] if r else 0))
