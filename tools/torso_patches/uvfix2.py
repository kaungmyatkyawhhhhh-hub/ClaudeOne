# uvfix with the v shift only above Y0 (the chest's own layout stays: shifting it made zebra stripes on the pec sides),
# and the side panels unrolled too (their tops on the shoulder corners were stretched)
import numpy as np
from unroll import fits, unrolled, W, H
from lscm import charts, merge_scraps
from uvfix import smooth_uv

def face_uv(base, uv, tris, cap_ids, P, Y0=0.35, RAMP=0.15, U0=0.5, URAMP=0.2):
    tris = np.asarray(tris)
    F = fits(base, uv)
    cls = merge_scraps(charts(base, uv, tris, cap_ids), tris)
    capset = np.zeros(len(base), bool); capset[cap_ids] = True
    suv = smooth_uv(uv, tris, fixed=capset)
    cv, dv = F["v"]
    fuv = suv[tris].copy()
    cap_tri = np.isin(tris, cap_ids).any(1)
    rimv = np.setdiff1d(np.unique(tris[cap_tri]), cap_ids)
    for kind in "FBLR":
        ks = np.array([k for k, c in enumerate(cls) if c == kind])
        verts = set(tris[ks].ravel())
        # (the template's "R" panel is on the body's -X side: unroll by the side the chart is actually on)
        ukind = kind if kind in "FB" else ("R" if base[list(verts), 0].mean() > 0 else "L")
        h = unrolled(P, base, verts, ukind, Y0)
        a, b = F[kind]
        for k in ks:
            for j, v in enumerate(tris[k]):
                y = base[v, 1]
                w = np.clip((y - Y0) / RAMP, 0, 1); w = w * w * (3 - 2 * w)
                extra = max(h[v] - y, 0) * w
                if capset[v]:
                    u_plain = (a * base[v, 0] + b) / W
                    side = rimv[(base[rimv, 2] < 0) == (kind == "F")]
                    dist = np.linalg.norm(base[side][:, [0, 2]] - base[v, [0, 2]], axis=1)
                    near = side[np.argsort(dist)[:4]]; wts = 1 / np.maximum(np.sort(dist)[:4], 1e-4) ** 2
                    u_rim = (suv[near, 0] * wts).sum() / wts.sum()
                    # the rim's own v differs a little from the plain v map: carry that difference into the cap
                    rim_dv = ((suv[near, 1] - (cv * base[near, 1] + dv) / H) * wts).sum() / wts.sum()
                    t = np.clip(1 - np.sort(dist)[0] / 0.3, 0, 1); t = t * t * (3 - 2 * t)
                    fuv[k, j] = (u_plain * (1 - t) + u_rim * t, (cv * h[v] + dv) / H)  # (the rim is on the plain map too)
                else:
                    # up on the slope the old left-right layout is uneven: blend into the panel's plain map
                    wu = np.clip((y - U0) / URAMP, 0, 1); wu = wu * wu * (3 - 2 * wu)
                    u_plain = (a * (base[v, 0] if kind in "FB" else base[v, 2]) + b) / W
                    v_plain = (cv * (h[v] if y > Y0 else y) + dv) / H
                    fuv[k, j] = (suv[v, 0] * (1 - wu) + u_plain * wu, (suv[v, 1] + cv * extra / H) * (1 - wu) + v_plain * wu)
    return fuv, cls, F, suv
