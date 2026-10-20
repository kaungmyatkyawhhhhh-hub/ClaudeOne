# new texture coordinates for the top band (and the whole back): per shirt-template panel, u from the panel's own linear map,
# v = the panel's v-by-height map applied to the height UNROLLED along the surface (at the reference shape), so the texture
# keeps the chest's density on the raised yoke and the sculpted back. Per triangle corner (the live meshes use per-face uvs).
import numpy as np
W, H = 585.0, 559.0
PANELS = {"L": (165, 229), "F": (231, 359), "R": (361, 425), "B": (427, 555)}

def panel_of_u(upx):
    for k, (a, b) in PANELS.items():
        if a - 1 <= upx <= b + 1: return k
    return None

def fits(base, uv):
    upx, vpx = uv[:, 0] * W, uv[:, 1] * H
    lowmask = base[:, 1] < 0.3
    out = {}
    for k, (a, b) in PANELS.items():
        sel = lowmask & (upx >= a - 1) & (upx <= b + 1)
        coord = base[sel, 0] if k in "FB" else base[sel, 2]
        A = np.vstack([coord, np.ones(sel.sum())]).T
        out[k] = np.linalg.lstsq(A, upx[sel], rcond=None)[0]
    sel = lowmask
    out["v"] = np.linalg.lstsq(np.vstack([base[sel, 1], np.ones(sel.sum())]).T, vpx[sel], rcond=None)[0]
    return out

def classify(base, ns, tris):
    # per triangle: its panel from the (smoothed) surface direction: sides where it faces left / right more than front /
    # back and up; everything else front / back by the side of the body it is on (the cap splits there too)
    cls = []
    for t in tris:
        n = ns[t].mean(0); c = base[t].mean(0)
        if abs(n[0]) > abs(n[2]) and abs(n[0]) > n[1]:
            cls.append("R" if n[0] > 0 else "L")
        else:
            cls.append("F" if c[2] < 0 else "B")
    return cls

def unrolled(P, base, verts, kind, Y0, bin_=0.04):
    y0_ = Y0
    # per vertex: the height measured along the surface from Y0 (at the reference positions P), by columns
    # front / back: columns by base X, profile in (Y, Z); sides: columns by base Z, profile in (Y, X)
    out = {}
    verts = np.array(sorted(verts))
    col = base[verts, 0] if kind in "FB" else base[verts, 2]
    if kind == "F": piv = np.array([Y0 - 0.3, 0.25]); other = lambda p: -(p[:, 2] - piv[1])
    elif kind == "B": piv = np.array([Y0 - 0.3, -0.25]); other = lambda p: (p[:, 2] - piv[1])
    elif kind == "R": piv = np.array([Y0 - 0.3, -0.4]); other = lambda p: (p[:, 0] - piv[1])
    else: piv = np.array([Y0 - 0.3, 0.4]); other = lambda p: -(p[:, 0] - piv[1])
    zc = P[verts, 2] if kind in "FB" else P[verts, 0]
    theta_all = np.arctan2(P[verts, 1] - piv[0], other(P[verts]))
    sval = np.zeros(len(verts))
    for c in np.arange(col.min() - bin_, col.max() + bin_, bin_ / 2):
        sel = np.abs(col - c) < bin_
        if sel.sum() < 4: continue
        th = theta_all[sel]
        r = np.hypot(P[verts[sel], 1] - piv[0], zc[sel] - (piv[1] if kind in "FB" else piv[1]))
        # the profile as distance from the pivot per angle (averaged in angle steps), then its arc length
        steps = np.linspace(th.min(), th.max(), max(int((th.max() - th.min()) / 0.02), 2) + 1)
        rr = np.array([r[np.abs(th - a) <= 0.02].mean() if (np.abs(th - a) <= 0.02).any() else np.nan for a in steps])
        ok = ~np.isnan(rr); rr = np.interp(steps, steps[ok], rr[ok])
        ker = np.exp(-0.5 * (np.arange(-3, 4) / 1.5) ** 2); ker /= ker.sum()
        rr = np.convolve(np.pad(rr, 3, mode="edge"), ker, mode="valid")
        yy = piv[0] + rr * np.sin(steps); xx = rr * np.cos(steps)
        s = np.concatenate([[0], np.cumsum(np.hypot(np.diff(yy), np.diff(xx)))])
        s0 = np.interp(y0_, yy, s) if np.all(np.diff(yy) > 0) else s[np.argmin(np.abs(yy - y0_))]
        vals = y0_ + (np.interp(th, steps, s) - s0)
        # columns overlap (bin_/2 step): average
        idx = np.where(sel)[0]
        sval[idx] += vals * np.exp(-((col[idx] - c) / (bin_ / 2)) ** 2)
        out.setdefault("w", np.zeros(len(verts)))[idx] += np.exp(-((col[idx] - c) / (bin_ / 2)) ** 2)
    w = out.get("w", np.ones(len(verts)))
    return dict(zip(verts, sval / np.maximum(w, 1e-9)))

def new_face_uv(base, uv, tris, cap_ids, P, Y0=-0.95):
    from lscm import charts, merge_scraps
    F = fits(base, uv)
    cls = merge_scraps(charts(base, uv, tris, cap_ids), tris)
    tris = np.asarray(tris)
    fuv = np.zeros((len(tris), 3, 2))
    cv, dv = F["v"]
    for kind in "FBLR":
        ks = [k for k, c in enumerate(cls) if c == kind]
        if not ks: continue
        a, b = F[kind]
        if kind in "FB":
            h = unrolled(P, base, set(tris[ks].ravel()), kind, Y0)
        for k in ks:
            for j, v in enumerate(tris[k]):
                if kind in "FB":
                    fuv[k, j] = ((a * base[v, 0] + b) / W, (cv * h[v] + dv) / H)
                else:
                    fuv[k, j] = ((a * base[v, 2] + b) / W, (cv * base[v, 1] + dv) / H)
    return fuv, cls, F
