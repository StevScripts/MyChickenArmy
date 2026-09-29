"""Cash-price experiment, not a human playtest or runtime game rule.

Inputs are exported from current Luau Config/Rules/Catalog. Level-one recruiting
and replacing weak reserves model a player who does not optimize fusion. Manual
collection is batched; paid benefits, offline earnings and combat awards are zero.
A configurable share of deposits is mentally reserved for slots; the rest funds
recruits, plot capacity, Luck, Egg Speed and Egg Value. No in-game purse/time gate.
"""
import argparse
import bisect
import collections
import json
import math
from pathlib import Path
import random
import statistics

ROOT = Path(__file__).resolve().parent
DATA = json.loads((ROOT / "economy-inputs.json").read_text())
SPECIES = DATA["species"]
BY_ID = {s["id"]: s for s in SPECIES}
CUMULATIVE = []
for odds in DATA["odds"]:
    running = 0
    row = []
    for species in SPECIES:
        running += odds[species["id"]]
        row.append(running)
    CUMULATIVE.append(row)

SCENARIOS = {
    "reference": {"roll_interval": 20, "deposit_interval": 60, "slot_share": .25, "home_fraction": .8},
    "focused": {"roll_interval": 10, "deposit_interval": 30, "slot_share": .35, "home_fraction": 1},
    "relaxed": {"roll_interval": 30, "deposit_interval": 90, "slot_share": .20, "home_fraction": .7},
}

def run(seed, prices, scenario="reference", max_hours=16):
    policy = SCENARIOS[scenario]
    rng = random.Random(seed)
    # Starter offer costs $600, separately from ordinary $2,400 recruit copies.
    flock = [BY_ID[x] for x in DATA["starter"]] + [BY_ID["Duck"]]
    growth_cash = DATA["startingCoins"] - 600
    slot_cash = 0.0
    carry = 0.0
    earned = 0.0
    value_level = speed_level = luck = plot = 0
    slots = 1
    unlocked = [0]
    snapshots = []
    investments = collections.Counter({"recruits": 600})
    for t in range(10, int(max_hours * 3600) + 1, 10):
        base = sum(s["income"] for s in flock)
        multiplier = (4 + value_level) / 4 * DATA["eggSpeedRates"][speed_level]
        rate = base * multiplier * policy["home_fraction"]
        carry += rate * 10
        if t % policy["deposit_interval"] == 0:
            receipt = math.floor(carry)
            carry -= receipt
            earned += receipt
            slot_cash += receipt * policy["slot_share"]
            growth_cash += receipt * (1 - policy["slot_share"])
            while slots < 8 and slot_cash >= prices[slots - 1]:
                slot_cash -= prices[slots - 1]
                slots += 1
                unlocked.append(t)
        if t % policy["roll_interval"] == 0:
            offers = [SPECIES[min(bisect.bisect(CUMULATIVE[luck], rng.random()), len(SPECIES)-1)] for _ in range(slots)]
            # Keep the best affordable result from each current offer batch.
            for offer in sorted(offers, key=lambda s: s["income"], reverse=True):
                if growth_cash < offer["price"]:
                    continue
                capacity = 25 + 5 * plot
                if len(flock) >= capacity:
                    weakest = min(flock, key=lambda s: s["income"])
                    if offer["income"] <= weakest["income"] * 1.5:
                        continue
                    # Weak reserves are outside the strongest selected army.
                    flock.remove(weakest)
                    growth_cash += math.floor(weakest["price"] * .5)
                    investments["resale"] += math.floor(weakest["price"] * .5)
                growth_cash -= offer["price"]
                investments["recruits"] += offer["price"]
                flock.append(offer)
        if t % 30 == 0:
            if plot < len(DATA["plotPrices"]) and len(flock) >= 25 + 5 * plot - 2:
                cost = DATA["plotPrices"][plot]
                if growth_cash >= cost:
                    growth_cash -= cost
                    investments["plot"] += cost
                    plot += 1
            # Compare income upgrades by marginal payback; preserve recruit money
            # while the yard still has room for relatively cheap growing flocks.
            base = sum(s["income"] for s in flock)
            candidates = []
            if value_level < 25:
                gain = base / 4 * DATA["eggSpeedRates"][speed_level] * policy["home_fraction"]
                candidates.append((DATA["incomePrices"][value_level] / gain, "value", DATA["incomePrices"][value_level]))
            if speed_level < 25:
                gain = base * (4 + value_level) / 4 * (DATA["eggSpeedRates"][speed_level + 1] - DATA["eggSpeedRates"][speed_level]) * policy["home_fraction"]
                candidates.append((DATA["incomePrices"][speed_level] / gain, "speed", DATA["incomePrices"][speed_level]))
            if candidates:
                payback, kind, cost = min(candidates)
                recruit_payback = 600 / ((4 + value_level) / 4 * DATA["eggSpeedRates"][speed_level] * policy["home_fraction"])
                if growth_cash >= cost and (payback <= recruit_payback or len(flock) >= 25 + 5 * plot):
                    growth_cash -= cost
                    investments[kind] += cost
                    if kind == "value":
                        value_level += 1
                    else:
                        speed_level += 1
            if len(flock) >= 20 and luck < len(DATA["luckPrices"]):
                cost = DATA["luckPrices"][luck]
                if growth_cash >= cost * 3:
                    growth_cash -= cost
                    investments["luck"] += cost
                    luck += 1
        if t % 1800 == 0 or slots == 8:
            snapshots.append({"hours": t / 3600, "rate": round(rate), "earned": round(earned),
                              "flock": len(flock), "value": value_level, "speed": speed_level,
                              "luck": luck, "plot": plot, "slots": slots,
                              "growth_cash": round(growth_cash), "slot_cash": round(slot_cash)})
        if slots == 8:
            break
    return {"seed": seed, "scenario": scenario, "hours": t/3600 if slots==8 else None,
            "milestone_hours": [round(x/3600, 4) for x in unlocked], "earned": round(earned),
            "investments": investments, "snapshots": snapshots}

def summary(runs):
    hours = [r["hours"] for r in runs if r["hours"] is not None]
    ordered = sorted(hours)
    percentile = lambda fraction: ordered[min(len(ordered)-1, int((len(ordered)-1)*fraction))] if ordered else None
    return {"complete": len(hours), "runs": len(runs), "median": statistics.median(hours) if hours else None,
            "p10": percentile(.1), "p90": percentile(.9),
            "milestones": [statistics.median([r["milestone_hours"][i] for r in runs if len(r["milestone_hours"])>i]) for i in range(min(map(lambda r:len(r["milestone_hours"]), runs)))]}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prices", default="1200,4800,120000,6000000,150000000,300000000,500000000")
    parser.add_argument("--seeds", type=int, default=24)
    parser.add_argument("--scenarios", default="reference,focused,relaxed")
    parser.add_argument("--output")
    args = parser.parse_args()
    prices = list(map(int, args.prices.split(",")))
    assert len(prices)==7 and all(b>a for a,b in zip(prices,prices[1:]))
    runs = [run(290900 + seed, prices, scenario) for scenario in args.scenarios.split(",") for seed in range(args.seeds)]
    summaries = {name: summary([r for r in runs if r["scenario"]==name]) for name in args.scenarios.split(",")}
    result={"prices": prices, "policies": SCENARIOS, "summary": summaries, "runs": runs}
    if args.output:
        Path(args.output).write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps({"prices":prices,"summary":summaries},indent=2))
