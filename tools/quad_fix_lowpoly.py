# quad_fix_lowpoly (19 Oct, owner's bug "inner quad bulge"): applies the quad fix to the owner's LOW-POLY thigh stage
# meshes. Input: the corrections from tools/quad_fix_stage_corrections.luau (per high-res stage vertex: old position +
# correction), the owner's low-poly OBJs (Downloads\gym_arc_meshes_lowpoly\other_player_stages). Each low-poly vertex moves by
# the inverse-distance mix of the corrections of its 4 nearest high-res vertices (the low-poly mesh is a decimation of the
# high-res one, so it lies on the same surface). Everything else in the OBJ (uv, faces, comments) is kept as it is.
# Writes the fixed OBJs to the output folder and bounds.json (each object's new bounding box centre / size, part-local).
# Usage: python -I quad_fix_lowpoly.py <corrections dir> <low-poly dir> <out dir>
import json
import math
import os
import sys

CELL = 0.08  # grid cell (studs) for the nearest-vertex search


def read_corrections(path):
    pts, fix = [], []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) == 6:
                pts.append(tuple(map(float, parts[:3])))
                fix.append(tuple(map(float, parts[3:])))
    return pts, fix


def build_grid(pts):
    grid = {}
    for i, p in enumerate(pts):
        grid.setdefault(tuple(math.floor(c / CELL) for c in p), []).append(i)
    return grid


def nearest(grid, pts, q, k=4):
    cx, cy, cz = (math.floor(c / CELL) for c in q)
    for reach in range(1, 6):
        found = []
        for dx in range(-reach, reach + 1):
            for dy in range(-reach, reach + 1):
                for dz in range(-reach, reach + 1):
                    for i in grid.get((cx + dx, cy + dy, cz + dz), ()):
                        found.append((math.dist(pts[i], q), i))
        if len(found) >= k:
            found.sort()
            return found[:k]
    found.sort()
    return found[:k]


def main(corr_dir, low_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    bounds, report = {}, []
    for name in sorted(os.listdir(corr_dir)):
        if not name.endswith(".txt"):
            continue
        obj = name[:-4]
        pts, fix = read_corrections(os.path.join(corr_dir, name))
        grid = build_grid(pts)
        src = os.path.join(low_dir, obj + ".obj")
        with open(src, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        lo, hi = [math.inf] * 3, [-math.inf] * 3
        moved, far, out = 0.0, 0.0, []
        for line in lines:
            if line.startswith("v "):
                parts = line.split()
                q = tuple(map(float, parts[1:4]))
                near = nearest(grid, pts, q)
                far = max(far, near[0][0])
                if near[0][0] < 1e-6:
                    d = fix[near[0][1]]
                else:
                    wsum, d = 0.0, [0.0, 0.0, 0.0]
                    for dist, i in near:
                        w = 1.0 / (dist * dist)
                        wsum += w
                        for c in range(3):
                            d[c] += fix[i][c] * w
                    d = [c / wsum for c in d]
                p = [q[c] + d[c] for c in range(3)]
                moved = max(moved, math.sqrt(sum(c * c for c in d)))
                for c in range(3):
                    lo[c], hi[c] = min(lo[c], p[c]), max(hi[c], p[c])
                out.append("v %.5f %.5f %.5f%s" % (p[0], p[1], p[2], "".join(" " + x for x in parts[4:])))
            else:
                out.append(line)
        with open(os.path.join(out_dir, obj + ".obj"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(out))
        bounds[obj] = {"center": [(lo[c] + hi[c]) / 2 for c in range(3)], "size": [hi[c] - lo[c] for c in range(3)]}
        report.append("%-26s moved up to %.3f, furthest low-poly vertex from the high-res surface %.4f" % (obj, moved, far))
    with open(os.path.join(out_dir, "bounds.json"), "w", encoding="utf-8") as fh:
        json.dump(bounds, fh, indent=1)
    print("\n".join(report))


if __name__ == "__main__":
    main(*sys.argv[1:4])
