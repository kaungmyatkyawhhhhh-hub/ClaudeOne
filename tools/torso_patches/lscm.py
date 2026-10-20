# per-chart least squares conformal maps, aligned (similarity) to the old shirt-template mapping
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import lsqr, spsolve
from scipy.sparse.csgraph import connected_components
from unroll import fits, panel_of_u, W, H

def lscm(P, tris):
    verts = np.unique(tris); vid = {v: i for i, v in enumerate(verts)}; n = len(verts)
    rows, cols, vals = [], [], []
    for t_i, (a, b, c) in enumerate(tris):
        p0, p1, p2 = P[a], P[b], P[c]
        e1 = p1 - p0; e2 = p2 - p0
        x_ax = e1 / max(np.linalg.norm(e1), 1e-12)
        nrm = np.cross(e1, e2); area2 = np.linalg.norm(nrm)
        if area2 < 1e-12: continue
        y_ax = np.cross(nrm / area2, x_ax)
        q = [np.array([0.0, 0.0]), np.array([e1 @ x_ax, e1 @ y_ax]), np.array([e2 @ x_ax, e2 @ y_ax])]
        s = 1 / np.sqrt(area2)
        ids = [vid[a], vid[b], vid[c]]
        for j in range(3):
            k, l = (j + 1) % 3, (j + 2) % 3
            wr, wi = (q[l][0] - q[k][0]) * s, (q[l][1] - q[k][1]) * s
            # complex row t: sum_j (wr + i wi)(u_j + i v_j) = 0 -> real: wr u - wi v ; imag: wi u + wr v
            rows += [2 * t_i, 2 * t_i, 2 * t_i + 1, 2 * t_i + 1]
            cols += [ids[j], n + ids[j], ids[j], n + ids[j]]
            vals += [wr, -wi, wi, wr]
    A = coo_matrix((vals, (rows, cols)), shape=(2 * len(tris), 2 * n)).tocsr()
    # pin two far-apart vertices
    d0 = np.argmax(P[verts, 1]); d1 = np.argmin(P[verts, 1])
    pins = {d0: (0.0, 0.0), d1: (0.0, -np.linalg.norm(P[verts[d0]] - P[verts[d1]]))}
    free = np.ones(2 * n, bool); x = np.zeros(2 * n)
    for i, (u, v) in pins.items(): free[i] = free[n + i] = False; x[i] = u; x[n + i] = v
    rhs = -A[:, ~free] @ x[~free]
    Af = A[:, free].tocsc()
    sol = spsolve((Af.T @ Af).tocsc(), Af.T @ rhs)
    x[free] = sol
    return verts, np.stack([x[:n], x[n:]], 1)

def align(uv2d, target, weights):
    # similarity (scale, rotation, translation) taking uv2d onto target, weighted least squares
    w = weights / weights.sum()
    mu_a = (uv2d * w[:, None]).sum(0); mu_b = (target * w[:, None]).sum(0)
    A = uv2d - mu_a; B = target - mu_b
    a = (w * (A[:, 0] * B[:, 0] + A[:, 1] * B[:, 1])).sum(); b = (w * (A[:, 0] * B[:, 1] - A[:, 1] * B[:, 0])).sum()
    den = (w * (A ** 2).sum(1)).sum()
    s_cos, s_sin = a / den, b / den
    R = np.array([[s_cos, -s_sin], [s_sin, s_cos]])
    return (A @ R.T) + mu_b, np.hypot(s_cos, s_sin), np.degrees(np.arctan2(s_sin, s_cos))

def charts(base, uv, tris, cap_ids):
    upx = uv[:, 0] * W
    capset = set(cap_ids)
    cls = []
    for t in tris:
        c = base[t].mean(0)
        if any(v in capset for v in t):
            cls.append("F" if c[2] < 0 else "B"); continue
        votes = [panel_of_u(upx[v]) for v in t]
        p = max(set(votes), key=votes.count)
        cls.append(p if p else ("F" if c[2] < 0 else "B"))
    return cls

def merge_scraps(cls, tris):
    # a chart's small disconnected bits join the neighbouring chart they share the most vertices with
    tris = np.asarray(tris)
    for _ in range(3):
        changed = False
        for kind in "FBLR":
            ks = np.array([k for k, c in enumerate(cls) if c == kind])
            if len(ks) == 0: continue
            T = tris[ks]; verts = np.unique(T); vid = {v: i for i, v in enumerate(verts)}
            e = np.array([[vid[a], vid[b]] for t in T for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0]))])
            G = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(len(verts),) * 2)
            nc, lab = connected_components(G, directed=False)
            if nc == 1: continue
            main = np.argmax(np.bincount(lab))
            vert_cls = {}
            for k, t in enumerate(tris):
                for v in t: vert_cls.setdefault(v, []).append(cls[k])
            for k in ks:
                comp = lab[vid[tris[k][0]]]
                if comp == main: continue
                votes = [c for v in tris[k] for c in vert_cls[v] if c != kind]
                if votes:
                    cls[k] = max(set(votes), key=votes.count); changed = True
        if not changed: break
    return cls

def new_face_uv(base, uv, tris, cap_ids, P):
    F = fits(base, uv)
    cls = merge_scraps(charts(base, uv, tris, cap_ids), tris)
    fuv = np.zeros((len(tris), 3, 2)); info = {}
    tris = np.asarray(tris)
    for kind in "FBLR":
        ks = np.array([k for k, c in enumerate(cls) if c == kind])
        verts, flat = lscm(P, tris[ks])
        a, b = F[kind]; cv, dv = F["v"]
        coord = base[verts, 0] if kind in "FB" else base[verts, 2]
        target = np.stack([a * coord + b, cv * base[verts, 1] + dv], 1)
        wts = np.where(base[verts, 1] < 0.3, 1.0, 1e-3)    # line up on the part below the yoke
        al, scale, rot = align(flat, target, wts)
        info[kind] = (len(ks), round(scale, 2), round(rot, 2))
        pos = {v: al[i] for i, v in enumerate(verts)}
        for k in ks:
            for j, v in enumerate(tris[k]): fuv[k, j] = (pos[v][0] / W, pos[v][1] / H)
    return fuv, cls, info
