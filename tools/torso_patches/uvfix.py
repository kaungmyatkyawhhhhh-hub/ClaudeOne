# hybrid texture coordinates for the torso (per triangle corner):
#   * the old layout, its noise smoothed (Laplacian within a panel, never across a seam)
#   * front / back panels: v moved by the extra surface length the yoke / back sculpt add beyond the plain height (unrolled
#     along the surface at the reference shape), so a raised slope keeps the chest's density; vertical parts don't change
#   * the cap: u from the rim's old u blended toward the plain left-right map in the middle; v unrolled like the rest
import numpy as np
from unroll import fits, unrolled, W, H, panel_of_u
from lscm import charts, merge_scraps

SEAM = 0.035  # (MuscleRig's SEAM_UV: neighbours further apart than this in uv are across a seam)

def smooth_uv(uv, tris, fixed, iters=25, lam=0.6):
    n = len(uv)
    e = np.vstack([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]); e = np.vstack([e, e[:, ::-1]]); e = np.unique(e, axis=0)
    out = uv.copy()
    same = np.linalg.norm(uv[e[:, 0]] - uv[e[:, 1]], axis=1) < SEAM
    e = e[same]
    deg = np.bincount(e[:, 0], minlength=n)
    for _ in range(iters):
        acc = np.zeros_like(out); np.add.at(acc, e[:, 0], out[e[:, 1]])
        avg = np.where(deg[:, None] > 0, acc / np.maximum(deg, 1)[:, None], out)
        step = lam * (avg - out); step[fixed] = 0
        out = out + step
    return out

def face_uv(base, uv, tris, cap_ids, P, Y0=-0.95):
    tris = np.asarray(tris)
    F = fits(base, uv)
    cls = merge_scraps(charts(base, uv, tris, cap_ids), tris)
    capset = np.zeros(len(base), bool); capset[cap_ids] = True
    # 1) smooth the old layout (the cap's copied rim values are replaced below anyway)
    suv = smooth_uv(uv, tris, fixed=capset)
    cv, dv = F["v"]
    fuv = suv[tris].copy()
    # the cap's rim (the band's top row): its smoothed old u per side, to blend the cap's u into near the rim
    cap_tri = np.isin(tris, cap_ids).any(1)
    rimv = np.setdiff1d(np.unique(tris[cap_tri]), cap_ids)
    for kind in "FB":
        ks = np.array([k for k, c in enumerate(cls) if c == kind])
        verts = set(tris[ks].ravel())
        h = unrolled(P, base, verts, kind, Y0)
        a, b = F[kind]
        for k in ks:
            for j, v in enumerate(tris[k]):
                extra = h[v] - base[v, 1]                     # surface length beyond the plain height
                if capset[v]:
                    # the cap: u blends from the plain map in the middle toward the nearest rim point's smoothed u
                    u_plain = (a * base[v, 0] + b) / W
                    side = rimv[(base[rimv, 2] < 0) == (kind == "F")]
                    dist = np.linalg.norm(base[side][:, [0, 2]] - base[v, [0, 2]], axis=1)
                    near = side[np.argsort(dist)[:4]]; wts = 1 / np.maximum(np.sort(dist)[:4], 1e-4) ** 2
                    u_rim = (suv[near, 0] * wts).sum() / wts.sum()
                    t = np.clip(1 - np.sort(dist)[0] / 0.3, 0, 1); t = t * t * (3 - 2 * t)
                    fuv[k, j] = (u_plain * (1 - t) + u_rim * t, (cv * h[v] + dv) / H)
                else:
                    fuv[k, j] = (suv[v, 0], suv[v, 1] + cv * extra / H)
    return fuv, cls, F, suv
