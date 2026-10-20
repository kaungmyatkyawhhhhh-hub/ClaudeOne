# torso top re-mesh, dense (20 Oct, prompt 15 part 3: "the depth must be in the geometry"): the generator closed the
# torso's whole top (shoulder to shoulder, front to back) with one lid of 300 triangles, about 100 times bigger than the
# triangles on the back, so the traps could only be flat planes there. This lid is re-meshed as an even triangle grid
# (SPACING apart): the 51 old lid vertices keep their ids, the new ones are added after the data's last vertex, the 300
# old triangle slots are reused and the rest added at the end. Every new vertex takes the old lid's values under it (muscle
# growth, normal change, waist morph, veins), with each muscle's growth on the rim reaching a little in (RIM_REACH).
# Writes MuscleData.UpperTorso__Unified__cap (read by MuscleMeshes applyCapPatch; parts _1.. when it is big).
# Usage: python cap2.py <raw dump (load.py format, with n_<muscle> entries)> <out .luau>
import sys
import numpy as np
from scipy.spatial import Delaunay, cKDTree

SPACING = 0.035
RIM_REACH = 0.45
MAX_CHARS = 190000


def load_raw(path):
    d = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            key, _, rest = line.rstrip("\n").partition(" ")
            d[key] = rest
    vec = lambda s: np.array([[float(x) for x in t.split()] for t in s.split(";")])
    m = {"base": vec(d["base"]), "nbase": vec(d["nbase"]), "uv": vec(d["uv"]), "morph": vec(d["morph"]), "vein": vec(d["vein"])}
    m["tris"] = np.array([int(x) for x in d["tris"].split()]).reshape(-1, 3)
    m["muscles"], m["normals"] = {}, {}
    for key in d:
        for pre, bucket in (("m_", "muscles"), ("n_", "normals")):
            if key.startswith(pre) and key.endswith("_idx"):
                name = key[len(pre):-4]
                m[bucket][name] = (np.array([int(x) - 1 for x in d[key].split()]), vec(d[pre + name + "_disp"]))
    return m


def point_in_poly(p, poly):
    x, y = p
    inside = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def remesh(m):
    b, t = m["base"], m["tris"]
    interior = np.where(b[:, 1] > 0.888)[0]
    slots = np.where(np.isin(t, interior).any(1))[0]
    capT = t[slots]
    rim = np.array(sorted(set(capT.ravel()) - set(interior)))
    centre = b[interior[np.argmax(b[interior, 1])]]
    rxz = b[rim][:, [0, 2]]
    ang = np.arctan2(rxz[:, 1] - centre[2], rxz[:, 0] - centre[0])
    order = np.argsort(ang)
    rim, rxz, ang = rim[order], rxz[order], ang[order]
    # interior points: a hex lattice inside the rim polygon, kept SPACING * 0.6 from the rim, relaxed
    pts = []
    for j, z in enumerate(np.arange(-0.7, 0.7, SPACING * np.sqrt(3) / 2)):
        for x in np.arange(-1.2, 1.2, SPACING) + (SPACING / 2 if j % 2 else 0):
            pts.append((x, z))
    pts = np.array(pts)
    pts = pts[[point_in_poly(p, rxz) for p in pts]]
    near, _ = cKDTree(rxz).query(pts)
    pts = pts[near > SPACING * 0.6]

    def inside_tris(allp, S):
        return np.array([s for s in S if point_in_poly(allp[s].mean(0), rxz)])

    for _ in range(20):
        allp = np.vstack([rxz, pts])
        S = inside_tris(allp, Delaunay(allp).simplices)
        acc = np.zeros_like(allp)
        cnt = np.zeros(len(allp))
        for i in range(3):
            for k in range(3):
                if i != k:
                    np.add.at(acc, S[:, i], allp[S[:, k]])
                    np.add.at(cnt, S[:, i], 1)
        q = acc[len(rxz):] / np.maximum(cnt[len(rxz):], 1)[:, None]
        pts = pts * 0.5 + q * 0.5
    allp = np.vstack([rxz, pts])
    S = inside_tris(allp, Delaunay(allp).simplices)
    assert len(np.unique(S)) == len(allp), "a point was left out"
    # ids: the rim keeps its ids, the first 51 interior points take the old lid ids, the rest new ids after the last vertex
    n_old = len(b)
    extra = len(pts) - len(interior)
    ids = np.concatenate([interior, np.arange(n_old, n_old + extra)])
    gid = np.concatenate([rim, ids])
    newT = gid[S]
    # height: the rim's height in that direction, rising toward the old lid's centre height as a flat dome
    P = np.zeros((len(pts), 3))
    for i, (x, z) in enumerate(pts):
        th = np.arctan2(z - centre[2], x - centre[0])
        k = np.searchsorted(ang, th) % len(ang)
        ry = (b[rim[k - 1], 1] + b[rim[k], 1]) / 2
        rd = np.hypot(rxz[k, 0] - centre[0], rxz[k, 1] - centre[2])
        r = np.hypot(x - centre[0], z - centre[2]) / max(rd, 1e-6)
        s = np.clip((r - 0.15) / 0.6, 0, 1)
        P[i] = (x, ry + (centre[1] - ry) * (1 - s * s * (3 - 2 * s)), z)
    # every triangle facing up like the old lid
    oldn = np.cross(b[capT[:, 1]] - b[capT[:, 0]], b[capT[:, 2]] - b[capT[:, 0]])[:, 1].mean()
    pos = np.vstack([b, np.zeros((extra, 3))])
    pos[ids] = P
    nn = np.cross(pos[newT[:, 1]] - pos[newT[:, 0]], pos[newT[:, 2]] - pos[newT[:, 0]])[:, 1]
    flip = np.sign(nn) != np.sign(oldn)
    newT[flip] = newT[flip][:, [0, 2, 1]]
    return dict(interior=interior, ids=ids, slots=slots, rim=rim, newT=newT, P=P, oldT=capT, n_old=n_old, extra=extra)


def old_bary(m, cap):
    # for each new point: the OLD lid triangle under it (in XZ) and its barycentric weights
    b = m["base"]
    T = cap["oldT"]
    A = b[T][:, :, [0, 2]]
    a0 = A[:, 0]
    M = np.stack([A[:, 1] - a0, A[:, 2] - a0], -1)  # (T, 2, 2): columns = edges
    det = np.linalg.det(M)
    ok = np.abs(det) > 1e-12
    inv = np.zeros_like(M)
    inv[ok] = np.linalg.inv(M[ok])
    ks, ws = [], []
    for p in cap["P"][:, [0, 2]]:
        uv = np.einsum("tij,tj->ti", inv, p - a0)
        u, v = uv[:, 0], uv[:, 1]
        w = 1 - u - v
        err = np.maximum(0, -u) + np.maximum(0, -v) + np.maximum(0, -w)
        err[~ok] = np.inf
        k = int(np.argmin(err))
        ks.append(k)
        ws.append((w[k], u[k], v[k]))
    return T[np.array(ks)], np.array(ws)


def interp_old(m, cap, full):
    T, w = cap["bary"]
    return full[T[:, 0]] * w[:, :1] + full[T[:, 1]] * w[:, 1:2] + full[T[:, 2]] * w[:, 2:3]


def vertex_normals(pos, tris):
    n = np.zeros_like(pos)
    f = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
    for j in range(3):
        np.add.at(n, tris[:, j], f)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def build(m, cap):
    b = m["base"]
    P = cap["P"]
    cap["bary"] = old_bary(m, cap)
    rimP = b[cap["rim"]][:, [0, 2]]
    d_rim, _ = cKDTree(rimP).query(P[:, [0, 2]])
    reach = np.clip(1 - d_rim / RIM_REACH, 0, 1)
    reach = reach * reach * (3 - 2 * reach)
    W = np.array([1 / np.maximum(np.linalg.norm(rimP - p, axis=1), 1e-4) ** 2 for p in P[:, [0, 2]]])
    W /= W.sum(1, keepdims=True)

    def field(full):
        return interp_old(m, cap, full) * (1 - reach[:, None]) + (W @ full[cap["rim"]]) * reach[:, None]

    out = {"morph": field(m["morph"]), "vein": field(m["vein"]), "muscles": {}, "normals": {}}
    for bucket in ("muscles", "normals"):
        for name, (idx, disp) in m[bucket].items():
            full = np.zeros_like(b)
            full[idx] = disp
            vals = field(full)
            keep = np.abs(vals).max(1) > 1e-6
            out[bucket][name] = (cap["ids"][keep], vals[keep])
    pos = np.vstack([b, np.zeros((cap["extra"], 3))])
    pos[cap["ids"]] = P
    tris = m["tris"].copy()
    tris[cap["slots"]] = cap["newT"][: len(cap["slots"])]
    tris = np.vstack([tris, cap["newT"][len(cap["slots"]):]])
    out["nbase"] = vertex_normals(pos, tris)[cap["ids"]]
    # texture coordinates of the new points: the nearest rim point's (the torso's texture patch replaces them)
    _, near = cKDTree(rimP).query(P[:, [0, 2]])
    out["uv"] = m["uv"][cap["rim"][near]]
    return out


def write(cap, out, path):
    f = lambda a, fmt="%.5f": ",".join(fmt % x for x in np.asarray(a).ravel())
    lists = {
        "ids": f(cap["ids"], "%d"), "base": f(cap["P"]), "nbase": f(out["nbase"]), "uv": f(out["uv"]),
        "morph": f(out["morph"]), "vein": f(out["vein"]), "tris": f(cap["newT"], "%d"),
    }
    for bucket in ("muscles", "normals"):
        for name, (idx, vals) in out[bucket].items():
            lists[bucket + "." + name] = ",".join("%d,%.5f,%.5f,%.5f" % (i, *v) for i, v in zip(idx, vals))
    # parts: each holds whole lists, under MAX_CHARS
    parts, cur, size = [], [], 0
    for key, text in lists.items():
        if cur and size + len(text) > MAX_CHARS:
            parts.append(cur)
            cur, size = [], 0
        cur.append((key, text))
        size += len(text)
    parts.append(cur)
    stem = path[: -len(".luau")]
    NL = chr(10)
    for i, part in enumerate(parts, 1):
        body = []
        for key, text in part:
            bucket, _, name = key.partition(".")
            body.append(("[%r] = {%s}" % (key, text)).replace("'", '"'))
        with open("%s_%d.luau" % (stem, i), "w", encoding="utf-8", newline=NL) as fh:
            fh.write("return {" + NL + ("," + NL).join(body) + NL + "}" + NL)
    main = [
        "-- generated by tools/torso_patches/cap2.py: the torso's top lid re-meshed as an even grid (see MuscleMeshes",
        "-- applyCapPatch); the lists are in the modules <this name>_1 .. _%d beside it" % len(parts),
        "local out = { mesh = \"UpperTorso__Unified\", verts = %d, addVerts = %d, triStart = %d, triCount = %d, muscles = {}, normals = {} }"
        % (cap["n_old"], cap["extra"], int(cap["slots"][0]), len(cap["slots"])),
        "for i = 1, %d do" % len(parts),
        "\tfor key, list in pairs(require(script.Parent:WaitForChild(script.Name .. \"_\" .. i))) do",
        "\t\tlocal bucket, name = string.match(key, \"^(%a+)%.(.+)$\")",
        "\t\tif bucket then out[bucket][name] = list else out[key] = list end",
        "\tend",
        "end",
        "return out",
    ]
    with open(path, "w", encoding="utf-8", newline=NL) as fh:
        fh.write(NL.join(main) + NL)
    return len(parts)


if __name__ == "__main__":
    m = load_raw(sys.argv[1])
    cap = remesh(m)
    slots = cap["slots"]
    assert np.all(np.diff(slots) == 1), "the lid's triangle slots are not one block"
    out = build(m, cap)
    n = write(cap, out, sys.argv[2])
    print("interior points", len(cap["P"]), "(new", cap["extra"], ") triangles", len(cap["newT"]), "parts", n)
