# chest_lowpoly (21 Oct, owner's prompt 9 part 3 "fuller chest"): applies the live torso's chest sculpt (Shared.MuscleMeshes
# addChestSculpt) to the low-poly torso FRONT stage meshes, keeping their vertex / triangle counts and texture map.
# Input: the export of tools/torso_back_stage_corrections.luau with MuscleMeshes_old = the torso before the chest sculpt
# (old_<stage>.txt / new_<stage>.txt: the whole high-res torso per stage, same vertex order), and the low-poly torso OBJs
# the chest change goes onto (Downloads\gym_arc_meshes_lowpoly_trapsback\other_player_stages: the newest torso, not
# imported yet; its back halves are copied unchanged, so one import of the output brings both prompt 15 and prompt 9).
#   * position: each low-poly front vertex moves by the inverse-distance mix of its 4 nearest high-res vertices' change
#     (the low-poly mesh lies on the same surface). Vertices shared with the back half (the seam) never move.
#   * normals: the new high-res surface's smooth normals (as tools/torso_back_lowpoly.py), so the seam stays seamless.
#   * texture coordinates and faces: kept exactly.
# Writes the OBJs + bounds.json (each object's bounding box centre / size, part-local; for the BodyStages config).
# Needs numpy + scipy. Usage: python -I chest_lowpoly.py <export dir> <low-poly OBJ dir> <out dir>
import json
import os
import shutil
import sys

import numpy as np
from scipy.spatial import cKDTree

STAGES = ["g000", "g020", "g040", "g060", "g080", "g100", "gmon"]


def read_obj(path):
    lines = open(path, encoding="utf-8").read().splitlines()
    V = np.array([[float(x) for x in l.split()[1:4]] for l in lines if l.startswith("v ")])
    return lines, V


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


def main(export_dir, lowpoly_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    faces = np.loadtxt(os.path.join(export_dir, "faces.txt"))
    T = faces[:, :3].astype(int) - 1
    old_bounds = os.path.join(os.path.dirname(lowpoly_dir.rstrip("\\/")), "bounds.json")
    bounds = json.load(open(old_bounds)) if os.path.exists(old_bounds) else {}
    for tag in STAGES:
        O = np.loadtxt(os.path.join(export_dir, "old_%s.txt" % tag))
        N = np.loadtxt(os.path.join(export_dir, "new_%s.txt" % tag))
        D = N - O
        tree = cKDTree(O)
        normals = smooth_normals(N, T)
        n_tree = cKDTree(N)
        # the back half: copied as it is; its vertices mark the seam the front must keep
        back_name = "BS_Torso_Back_%s" % tag
        shutil.copy(os.path.join(lowpoly_dir, back_name + ".obj"), os.path.join(out_dir, back_name + ".obj"))
        _, back_V = read_obj(os.path.join(lowpoly_dir, back_name + ".obj"))
        back_tree = cKDTree(back_V)
        name = "BS_Torso_Front_%s" % tag
        lines, V = read_obj(os.path.join(lowpoly_dir, name + ".obj"))
        dist, idx = tree.query(V, k=4)
        w = 1 / np.maximum(dist, 1e-6) ** 2
        move = (D[idx] * w[..., None]).sum(1) / w.sum(1, keepdims=True)
        seam_d, _ = back_tree.query(V)
        seam = seam_d < 1e-4
        move[seam] = 0
        moved = V + move
        _, ni = n_tree.query(moved)
        # keep the old normal on the seam and where nothing moved (bit-identical to the back half there)
        old_vn = [l for l in lines if l.startswith("vn ")]
        vi = ni_i = 0
        out = ["# GYM ARC: chest_lowpoly (21 Oct): fuller chest (prompt 9)"]
        for l in lines:
            if l.startswith("v "):
                out.append("v %.5f %.5f %.5f" % tuple(moved[vi]))
                vi += 1
            elif l.startswith("vn "):
                if ni_i < len(moved) and not seam[ni_i] and np.linalg.norm(move[ni_i]) > 1e-5:
                    out.append("vn %.5f %.5f %.5f" % tuple(normals[ni[ni_i]]))
                else:
                    out.append(old_vn[ni_i])
                ni_i += 1
            else:
                out.append(l)
        with open(os.path.join(out_dir, name + ".obj"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(out) + "\n")
        lo, hi = moved.min(0), moved.max(0)
        bounds[name] = {"center": list((lo + hi) / 2), "size": list(hi - lo)}
        print("%-22s moved up to %.4f, %d seam vertices kept, %d vertices" % (name, np.linalg.norm(move, axis=1).max(), seam.sum(), len(V)))
    with open(os.path.join(out_dir, "bounds.json"), "w", encoding="utf-8") as fh:
        json.dump(bounds, fh, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
