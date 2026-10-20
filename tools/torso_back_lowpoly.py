# torso_back_lowpoly (20 Oct, owner's prompt 15 "upper traps texture and back shape"): applies the new torso (re-meshed top
# cap, back sculpt, new texture map) to the owner's LOW-POLY torso stage meshes, keeping their vertex / triangle counts.
# Input: the export of tools/torso_back_stage_corrections.luau (old_<stage>.txt / new_<stage>.txt: the whole high-res torso
# per stage as it was and as it is now; faces.txt: its triangles with the texture corners the live body draws), and the
# low-poly OBJs now in the game (g000 from Downloads\gym_arc_meshes_lowpoly, g020..gmon from ..._trapsbig).
#   * position: each low-poly vertex moves by the inverse-distance mix of its 4 nearest high-res vertices' change (the
#     low-poly mesh is a decimation of the high-res one, so it lies on the same surface). The old top cap had other vertices
#     (a fan; since the dense re-mesh it also has more vertices), so a low-poly vertex there moves with the cap's rim
#     sideways and takes the new cap's height there.
#   * texture: each triangle corner takes the new map of the high-res surface under it (the nearest high-res triangle on the
#     same texture panel as the low-poly triangle's middle), so the low-poly torso shows the shirt / skin like the live one.
#   * normals: the new high-res surface's smooth normals (both halves share them, so the front / back split stays seamless).
# Writes the OBJs + bounds.json (each object's bounding box centre / size, part-local; for tools/quad_fix_patch_config.py).
# Needs numpy + scipy. Usage: python -I torso_back_lowpoly.py <export dir> <g000 OBJ dir> <g020..gmon OBJ dir> <out dir>
import json
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

STAGES = ["g000", "g020", "g040", "g060", "g080", "g100", "gmon"]
SEAM_UV = 0.035


def read_obj(path):
    head, V, F = [], [], []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                V.append([float(x) for x in p[1:4]])
            elif p[0] == "f":
                F.append([int(c.split("/")[0]) - 1 for c in p[1:4]])
            elif p[0] not in ("vt", "vn") and not V:
                head.append(line.rstrip("\n"))
    return head, np.array(V), np.array(F)


def smooth_normals(P, T):
    # area-weighted vertex normals; vertices at the same spot (texture seams) share one
    key = np.round(P * 1e4).astype(np.int64)
    _, spot = np.unique(key, axis=0, return_inverse=True)
    spot = spot.ravel()
    n = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    acc = np.zeros((spot.max() + 1, 3))
    for j in range(3):
        np.add.at(acc, spot[T[:, j]], n)
    acc /= np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-12)
    return acc[spot]


def closest_on_triangle(p, a, b, c):
    # barycentric weights of the point of triangle abc closest to p (Ericson, Real-Time Collision Detection 5.1.5)
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = ab @ ap, ac @ ap
    if d1 <= 0 and d2 <= 0:
        return np.array([1.0, 0, 0])
    bp = p - b
    d3, d4 = ab @ bp, ac @ bp
    if d3 >= 0 and d4 <= d3:
        return np.array([0, 1.0, 0])
    vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0:
        v = d1 / (d1 - d3)
        return np.array([1 - v, v, 0])
    cp = p - c
    d5, d6 = ab @ cp, ac @ cp
    if d6 >= 0 and d5 <= d6:
        return np.array([0, 0, 1.0])
    vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0:
        w = d2 / (d2 - d6)
        return np.array([1 - w, 0, w])
    va = d3 * d6 - d5 * d4
    if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0:
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return np.array([0, 1 - w, w])
    den = 1 / (va + vb + vc)
    v, w = vb * den, vc * den
    return np.array([1 - v - w, v, w])


def main(export_dir, g000_dir, stage_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rows = np.loadtxt(os.path.join(export_dir, "faces.txt"))
    T = rows[:, :3].astype(int) - 1
    FUV = rows[:, 3:].reshape(-1, 3, 2)
    old0 = np.loadtxt(os.path.join(export_dir, "old_g000.txt"))
    new0 = np.loadtxt(os.path.join(export_dir, "new_g000.txt"))
    n_old = len(old0)
    # the re-meshed lid's vertices: the old ids that moved, and every vertex the lid added after them
    cap = np.ones(len(new0), bool)
    cap[:n_old] = np.linalg.norm(new0[:n_old] - old0, axis=1) > 1e-4
    cap_faces = cap[T].any(1)
    rim = np.zeros(len(cap), bool)
    rim[np.unique(T[cap_faces])] = True
    rim &= ~cap
    bounds, report = {}, []
    for tag in STAGES:
        O = np.loadtxt(os.path.join(export_dir, "old_%s.txt" % tag))
        N = np.loadtxt(os.path.join(export_dir, "new_%s.txt" % tag))
        D = N[:n_old] - O
        keep = np.where(~cap[:n_old])[0]
        tree_old = tree = cKDTree(O[keep])
        rim_ids = np.where(rim)[0]
        rim_tree = cKDTree(O[rim_ids][:, [0, 2]])
        cap_top = T[cap_faces]  # the new cap (with its rim) as a height field over x / z
        cent = N[T].mean(1)
        cent_tree = cKDTree(cent)
        normals = smooth_normals(N, T)
        n_tree = cKDTree(N)
        for half in ("Front", "Back"):
            name = "BS_Torso_%s_%s" % (half, tag)
            src = os.path.join(g000_dir if tag == "g000" else stage_dir, name + ".obj")
            head, V, F = read_obj(src)
            # positions
            dist, idx = tree_old.query(V, k=4)
            w = 1 / np.maximum(dist, 1e-6) ** 2
            moved = V + (D[keep[idx]] * w[..., None]).sum(1) / w.sum(1, keepdims=True)
            in_cap = 0
            for i, q in enumerate(V):
                if dist[i, 0] < 0.03 or q[1] < O[rim_ids, 1].min():
                    continue
                # inside the old cap: sideways with the nearest rim points, then the new cap's height there
                in_cap += 1
                rd, ri = rim_tree.query(q[[0, 2]], k=4)
                rw = 1 / np.maximum(rd, 1e-6) ** 2
                shift = (D[rim_ids[ri]] * rw[:, None]).sum(0) / rw.sum()
                x, z = q[0] + shift[0], q[2] + shift[2]
                best, y = np.inf, q[1] + shift[1]
                for t in cap_top:
                    a, b, c = N[t][:, [0, 2]]
                    m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
                    if abs(np.linalg.det(m)) < 1e-12:
                        continue
                    s, r = np.linalg.solve(m, [x - a[0], z - a[1]])
                    out = max(-s, -r, s + r - 1, 0)
                    if out < best:
                        best, y = out, N[t[0], 1] * (1 - s - r) + N[t[1], 1] * s + N[t[2], 1] * r
                moved[i] = [x, y, z]
            # texture corners and normals
            uvs, uv_id, corners = [], {}, []
            for f in F:
                mid = moved[f].mean(0)
                _, cand = cent_tree.query(mid, k=12)
                ref, ref_d = None, np.inf
                for k in cand:
                    bc = closest_on_triangle(mid, *N[T[k]])
                    d = np.linalg.norm(bc @ N[T[k]] - mid)
                    if d < ref_d:
                        ref, ref_d, ref_uv = k, d, bc @ FUV[k]
                face = []
                for v in f:
                    p = moved[v]
                    _, cand = cent_tree.query(p, k=16)
                    best, pick = np.inf, None
                    for k in [ref] + list(cand):
                        bc = closest_on_triangle(p, *N[T[k]])
                        uv = bc @ FUV[k]
                        if np.linalg.norm(uv - ref_uv) > 3 * SEAM_UV and k != ref:
                            continue  # (another texture panel)
                        d = np.linalg.norm(bc @ N[T[k]] - p)
                        if d < best - 1e-9:
                            best, pick = d, uv
                    key = (round(pick[0], 5), round(pick[1], 5))
                    if key not in uv_id:
                        uv_id[key] = len(uvs)
                        uvs.append(key)
                    face.append(uv_id[key])
                corners.append(face)
            _, ni = n_tree.query(moved)
            vn = normals[ni]
            lines = head + ["# GYM ARC: torso_back_lowpoly (20 Oct): new back, top cap and texture map"]
            lines += ["v %.5f %.5f %.5f" % tuple(p) for p in moved]
            lines += ["vt %.5f %.5f" % (u, 1 - v) for u, v in uvs]
            lines += ["vn %.5f %.5f %.5f" % tuple(n) for n in vn]
            lines += ["f " + " ".join("%d/%d/%d" % (v + 1, t + 1, v + 1) for v, t in zip(f, c)) for f, c in zip(F, corners)]
            with open(os.path.join(out_dir, name + ".obj"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write("\n".join(lines) + "\n")
            lo, hi = moved.min(0), moved.max(0)
            bounds[name] = {"center": list((lo + hi) / 2), "size": list(hi - lo)}
            report.append("%-22s moved up to %.3f, %d cap vertices, %d vt, faces %d"
                          % (name, np.linalg.norm(moved - V, axis=1).max(), in_cap, len(uvs), len(F)))
            print(report[-1], flush=True)
    with open(os.path.join(out_dir, "bounds.json"), "w", encoding="utf-8") as fh:
        json.dump(bounds, fh, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:5])
