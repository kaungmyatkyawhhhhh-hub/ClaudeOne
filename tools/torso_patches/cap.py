# re-mesh the torso's top cap: same rim, same number of interior points (51) and triangles (300), spread evenly
import numpy as np, re
from scipy.spatial import Delaunay
from load import load

def point_in_poly(p, poly):
    x, y = p; inside = False; n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1: inside = not inside
    return inside

def inside_tris(allp, S, poly):
    # only the triangles inside the rim polygon (the rim has small dents: plain Delaunay fills them)
    keep = [s for s in S if point_in_poly(allp[s].mean(0), poly)]
    return np.array(keep)

def remesh(m, seed=1):
    b, t = m['base'], m['tris']
    interior = np.where(b[:, 1] > 0.888)[0]
    slots = np.where(np.isin(t, interior).any(1))[0]
    capT = t[slots]
    rim = np.array(sorted(set(capT.ravel()) - set(interior)))
    centre = b[interior[np.argmax(b[interior, 1])]]
    rxz = b[rim][:, [0, 2]]
    ang = np.arctan2(rxz[:, 1] - centre[2], rxz[:, 0] - centre[0])
    order = np.argsort(ang); rim = rim[order]; rxz = rxz[order]; ang = ang[order]
    # distance to the rim along a direction (polygon through the ordered rim)
    def rim_dist(theta):
        dirv = np.array([np.cos(theta), np.sin(theta)])
        best = np.inf
        for i in range(len(rxz)):
            a, c = rxz[i] - centre[[0, 2]], rxz[(i + 1) % len(rxz)] - centre[[0, 2]]
            M = np.array([dirv, a - c]).T
            if abs(np.linalg.det(M)) < 1e-12: continue
            s, w = np.linalg.solve(M, a)
            if s > 0 and -1e-9 <= w <= 1 + 1e-9: best = min(best, s)
        return best
    # interior points: a hex lattice inside the rim (shrunk), thinned / grown to exactly len(interior)
    target = len(interior)
    def lattice(spacing):
        pts = []
        for j, z in enumerate(np.arange(-0.6, 0.6, spacing * np.sqrt(3) / 2)):
            for x in np.arange(-1.1, 1.1, spacing) + (spacing / 2 if j % 2 else 0):
                th = np.arctan2(z - centre[2], x - centre[0]); r = np.hypot(x - centre[0], z - centre[2])
                if r < rim_dist(th) - spacing * 0.55: pts.append((x, z))
        return np.array(pts)
    lo, hi = 0.05, 0.4
    for _ in range(40):
        s = (lo + hi) / 2; n = len(lattice(s))
        if n > target: lo = s
        else: hi = s
    pts = lattice(lo)
    while len(pts) > target:  # drop the point closest to the rim
        r = [rim_dist(np.arctan2(p[1] - centre[2], p[0] - centre[0])) - np.hypot(p[0] - centre[0], p[1] - centre[2]) for p in pts]
        pts = np.delete(pts, int(np.argmin(r)), 0)
    assert len(pts) == target, (len(pts), target)
    # relax (Laplacian over the Delaunay neighbours, rim fixed)
    for _ in range(30):
        allp = np.vstack([rxz, pts])
        nb = [set() for _ in range(len(allp))]
        for s in inside_tris(allp, Delaunay(allp).simplices, rxz):
            for i in range(3):
                for k in range(3):
                    if i != k: nb[s[i]].add(s[k])
        new = pts.copy()
        for i in range(len(pts)):
            q = np.mean(allp[list(nb[len(rxz) + i])], 0)
            new[i] = pts[i] * 0.5 + q * 0.5
        pts = new
    allp = np.vstack([rxz, pts])
    S = inside_tris(allp, Delaunay(allp).simplices, rxz)
    assert len(S) == len(slots), (len(S), len(slots))
    assert len(np.unique(S)) == len(allp), "a point was left out"
    # global ids: rim keeps its ids, the interior points take the old interior ids
    gid = np.concatenate([rim, interior])
    newT = gid[S]
    # height: the rim's height along that direction toward the old centre height, a dome (1 - r^2)
    P = np.zeros((target, 3))
    for i, (x, z) in enumerate(pts):
        th = np.arctan2(z - centre[2], x - centre[0]); r = np.hypot(x - centre[0], z - centre[2]) / rim_dist(th)
        # rim height in that direction: interpolate between the rim points around th
        k = np.searchsorted(ang, th) % len(ang); k0 = k - 1
        ry = (b[rim[k0], 1] + b[rim[k], 1]) / 2
        t_ = np.clip((r - 0.15) / 0.6, 0, 1); P[i] = (x, ry + (centre[1] - ry) * (1 - t_ * t_ * (3 - 2 * t_)), z)  # (flat at the rim's height near it: no scallops)
    # every triangle facing up (the cap's winding: keep the old cap's orientation)
    oldn = np.cross(b[capT[:, 1]] - b[capT[:, 0]], b[capT[:, 2]] - b[capT[:, 0]])[:, 1].mean()
    pos = b.copy(); pos[interior] = P
    nn = np.cross(pos[newT[:, 1]] - pos[newT[:, 0]], pos[newT[:, 2]] - pos[newT[:, 0]])[:, 1]
    flip = np.sign(nn) != np.sign(oldn)
    newT[flip] = newT[flip][:, [0, 2, 1]]
    return dict(interior=interior, slots=slots, rim=rim, newT=newT, P=P, oldT=capT)

def interp_old(m, cap, values_full):
    # barycentric interpolation (in XZ) of a per-vertex field over the OLD cap triangles, at the new interior points
    b = m['base']; out = np.zeros((len(cap['P']), values_full.shape[1]))
    T = cap['oldT']; A = b[T][:, :, [0, 2]]
    for i, p in enumerate(cap['P'][:, [0, 2]]):
        best = None
        for k in range(len(T)):
            a, bb, c = A[k]
            M = np.array([bb - a, c - a]).T
            if abs(np.linalg.det(M)) < 1e-12: continue
            u, v = np.linalg.solve(M, p - a); w = 1 - u - v
            err = max(0, -u) + max(0, -v) + max(0, -w)
            if best is None or err < best[0]: best = (err, k, (w, u, v))
        _, k, (w, u, v) = best
        out[i] = values_full[T[k, 0]] * w + values_full[T[k, 1]] * u + values_full[T[k, 2]] * v
    return out

RIM_REACH = 0.25
def apply_cap(m, cap):
    # returns a new data dict with the cap re-meshed (old interior ids reused, same triangle slots)
    import copy
    n = copy.deepcopy(m)
    I = cap['interior']
    for key in ('morph', 'vein'):
        if key in n: n[key][I] = interp_old(m, cap, m[key])
    # each muscle's growth on the rim reaches a little into the cap (fading out by RIM_REACH of the way in), so the rim
    # never bulges against its new neighbours
    rimP = m['base'][cap['rim']][:, [0, 2]]
    centre = m['base'][I[np.argmax(m['base'][I, 1])]][[0, 2]]
    P = cap['P'][:, [0, 2]]
    dist_rim = np.array([np.min(np.linalg.norm(rimP - p, axis=1)) for p in P])
    reach = np.clip(1 - dist_rim / RIM_REACH, 0, 1); reach = reach * reach * (3 - 2 * reach)
    W = np.array([1 / np.maximum(np.linalg.norm(rimP - p, axis=1), 1e-4) ** 2 for p in P])
    W /= W.sum(1, keepdims=True)
    for name, mu in n['muscles'].items():
        full = np.zeros_like(m['base']); full[mu['idx']] = mu['disp']
        vals = interp_old(m, cap, full) * (1 - reach[:, None]) + (W @ full[cap['rim']]) * reach[:, None]
        keep = ~np.isin(mu['idx'], I)
        idx = np.concatenate([mu['idx'][keep], I]); disp = np.vstack([mu['disp'][keep], vals])
        nz = np.abs(disp).max(1) > 1e-6
        mu['idx'], mu['disp'] = idx[nz], disp[nz]
    n['base'] = m['base'].copy(); n['base'][I] = cap['P']
    n['tris'] = m['tris'].copy(); n['tris'][cap['slots']] = cap['newT']
    # base normals of the cap: from the new surface (cap triangles plus the band around the rim)
    from render import vertex_normals
    vn = vertex_normals(n['base'], n['tris'])
    n['nbase'] = m['nbase'].copy(); n['nbase'][I] = vn[I]
    return n
