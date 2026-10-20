import numpy as np
def load(path):
    d = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            key, _, rest = line.rstrip("\n").partition(" ")
            d[key] = rest
    out = {"muscles": {}, "shapes": {}}
    def vec(s): return np.array([[float(x) for x in t.split()] for t in s.split(";")])
    out["base"] = vec(d["base"]); out["nbase"] = vec(d["nbase"]); out["uv"] = vec(d["uv"])
    out["tris"] = np.array([int(x) for x in d["tris"].split()]).reshape(-1, 3)
    for k in ("morph", "vein"):
        if k in d: out[k] = vec(d[k])
    out["extra"] = float(d.get("extra", 0))
    for key in d:
        for pre, bucket in (("m_", "muscles"), ("s_", "shapes")):
            if key.startswith(pre) and key.endswith("_idx"):
                name = key[len(pre):-4]
                out[bucket][name] = {"idx": np.array([int(x) - 1 for x in d[key].split()]),
                                     "disp": vec(d[pre + name + "_disp"]),
                                     "monster": float(d[pre + name + "_monster"])}
    return out
def pos_at(m, g, shapes=True):
    p = m["base"].copy()
    for name, mu in m["muscles"].items():
        s = g if g <= 1 else mu["monster"] * (1 + m["extra"])
        np.add.at(p, mu["idx"], mu["disp"] * s)
    if shapes:
        for name, sh in m["shapes"].items():
            s = g if g <= 1 else sh["monster"] * (1 + m["extra"])
            np.add.at(p, sh["idx"], sh["disp"] * s)
    if "morph" in m:
        w = 1 - min(g, 1)
        p += m["morph"] * w
    return p
