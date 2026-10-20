"""Export each egg's voxels as greedy-merged coloured quads for 3D egg meshes.

python3 export_meshes.py [Id ...]  ->  mesh/<Id>.json
Each file: {"id", "palette": [[r,g,b],...], "quads": [[axis, dir, slice, u0, v0, du, dv, colour, glow], ...]}
axis 0/1/2 = x/y/z normal, dir +1/-1, slice = voxel layer of the face plane,
(u0, v0, du, dv) span the other two axes in order (y,z) / (x,z) / (x,y).
Coordinates are voxel units with the egg bottom at y=0 and centred on x/z.
"""
import json, os, random, sys
import render_eggs as E
import build_eggs as B

HERE = os.path.dirname(os.path.abspath(__file__))

STEP = 14  # merge near-identical shades so gradients mesh into fewer faces

def quant(c):
    return tuple(int(min(255, round(float(x) / STEP) * STEP)) for x in c)

def voxels(r):
    seed = sum(map(ord, r["id"])); rnd = random.Random(seed)
    vox = E.egg_voxels(r.get("girth", 1.0))
    ctx = {"girth": r.get("girth", 1.0), "seed": seed, "rnd": rnd, "noise": E.Noise(seed),
           "noise2": E.Noise(seed * 7 + 3, freq=1.1), "noise3": E.Noise(seed * 13 + 5, freq=0.85)}
    for fn in r.get("carve", []):
        for k in list(vox):
            if fn(*E.info(k)): del vox[k]
    extra = {}
    for fn in r.get("extras", []): extra.update(fn(vox, ctx))
    paint = r.get("paint") or E.layered(r["layers"])
    out = {}
    for k in vox:
        c, g = paint(ctx, *E.info(k)); out[k] = (quant(c), bool(g))
    for k, (c, g) in extra.items(): out[k] = (quant(c), bool(g))
    return out

def greedy(vox):
    pal, pindex, quads = [], {}, []
    def colour(c):
        if c not in pindex: pindex[c] = len(pal); pal.append(list(c))
        return pindex[c]
    keys = list(vox)
    lo = [min(k[a] for k in keys) for a in range(3)]
    hi = [max(k[a] for k in keys) for a in range(3)]
    for axis in range(3):
        ua, va = [a for a in range(3) if a != axis]
        for d in (1, -1):
            for s in range(lo[axis], hi[axis] + 1):
                mask = {}
                for k, (c, g) in vox.items():
                    if k[axis] != s: continue
                    nb = list(k); nb[axis] += d
                    if tuple(nb) in vox: continue
                    mask[(k[ua], k[va])] = (colour(c), g)
                while mask:
                    (u0, v0) = min(mask)
                    m = mask[(u0, v0)]
                    du = 1
                    while mask.get((u0 + du, v0)) == m: du += 1
                    dv = 1
                    while all(mask.get((u0 + x, v0 + dv)) == m for x in range(du)): dv += 1
                    for x in range(du):
                        for y in range(dv): del mask[(u0 + x, v0 + y)]
                    plane = s + (1 if d > 0 else 0)
                    quads.append([axis, d, plane, u0, v0, du, dv, m[0], 1 if m[1] else 0])
    return pal, quads

def main(only):
    rs = B.recipes()
    os.makedirs(os.path.join(HERE, "mesh"), exist_ok=True)
    total = 0
    for row in B.ROWS:
        cid = row["Id"]
        if only and cid not in only: continue
        r = rs[cid]
        vox = voxels(r)
        # centre on x/z (voxel index i covers [i, i+1]; egg spans 0..W)
        shifted = {(i - E.W // 2, j, k - E.W // 2): v for (i, j, k), v in vox.items()}
        pal, quads = greedy(shifted)
        json.dump({"id": cid, "palette": pal, "quads": quads}, open(os.path.join(HERE, "mesh", cid + ".json"), "w"), separators=(",", ":"))
        total += len(quads)
        print(cid, len(quads), "quads", len(pal), "colours")
    print("total quads", total)

if __name__ == "__main__":
    main(set(sys.argv[1:]))
