"""
Turns build/models/cars.json (from tools/export_models.luau) into .glb files
for Roblox Studio's 3D Importer:

  build/models/CityLegendsCars.glb   every car in one file (cars side by side)
  build/models/cars/<id>.glb         one file per car

Each car is a node named after its id holding:
  Paint, Accent, Trim, Chrome, Glass, Lamp, Tail, Drl, Plate, Interior
      body layers (a layer over 18k triangles is split: Paint, Paint2, ...)
  WheelTire, WheelRim, WheelCaliper
      the front-right wheel; the game copies it to all four corners
  Mark_Origin, Mark_RefX, Mark_RefZ, Mark_Hub, Mark_Plate, Mark_Exhaust1..n
      tiny marker meshes. The game reads the car's frame, scale and the
      wheel / plate / exhaust positions from them, so it does not matter
      where the importer puts the model or which unit scale it uses.

Usage (from the repo root):  python3 tools/make_glb.py
"""

import json
import os
import struct

SRC = "build/models/cars.json"
OUT = "build/models"
MAX_TRIS = 18000
SPACING = 9.0  # studs between cars in the combined file

REF = 4.0  # Mark_RefX / Mark_RefZ sit this far from Mark_Origin (studs)


def material_for(layer, car):
    def rgb255(c):
        return [c[0] / 255, c[1] / 255, c[2] / 255]

    m = {"name": layer, "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.6}}
    pbr = m["pbrMetallicRoughness"]
    if layer in ("Paint", "Accent"):
        pbr["baseColorFactor"] = (car["color"] if layer == "Paint" else car["accent"]) + [1]
        pbr["metallicFactor"], pbr["roughnessFactor"] = 0.4, 0.3
    elif layer == "Trim":
        pbr["baseColorFactor"] = [0.06, 0.06, 0.07, 1]
    elif layer == "Chrome":
        pbr["baseColorFactor"] = [0.77, 0.78, 0.82, 1]
        pbr["metallicFactor"], pbr["roughnessFactor"] = 1.0, 0.15
    elif layer == "Glass":
        pbr["baseColorFactor"] = [0.05, 0.06, 0.09, 0.75]
        pbr["roughnessFactor"] = 0.05
        m["alphaMode"] = "BLEND"
    elif layer == "Lamp":
        pbr["baseColorFactor"] = [0.93, 0.95, 1, 1]
        m["emissiveFactor"] = [0.93, 0.95, 1]
    elif layer == "Tail":
        pbr["baseColorFactor"] = [0.59, 0, 0.02, 1]
        m["emissiveFactor"] = [0.59, 0, 0.02]
    elif layer == "Drl":
        c = rgb255(car["drl"])
        pbr["baseColorFactor"] = c + [1]
        m["emissiveFactor"] = c
    elif layer == "Plate":
        pbr["baseColorFactor"] = [0.91, 0.91, 0.89, 1]
    elif layer == "Interior":
        pbr["baseColorFactor"] = [0.09, 0.09, 0.1, 1]
    elif layer == "Tire":
        pbr["baseColorFactor"] = [0.08, 0.08, 0.09, 1]
        pbr["roughnessFactor"] = 0.9
    elif layer == "Rim":
        pbr["baseColorFactor"] = rgb255(car["rim"]) + [1]
        pbr["metallicFactor"], pbr["roughnessFactor"] = 0.8, 0.3
    elif layer == "Caliper":
        pbr["baseColorFactor"] = rgb255(car["caliper"]) + [1]
    else:  # markers
        pbr["baseColorFactor"] = [1, 0, 1, 1]
    return m


def octahedron(p, r=0.06):
    x, y, z = p
    v = [(x + r, y, z), (x - r, y, z), (x, y + r, z), (x, y - r, z), (x, y, z + r), (x, y, z - r)]
    n = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    t = [0, 2, 4, 4, 2, 1, 1, 2, 5, 5, 2, 0, 4, 3, 0, 1, 3, 4, 5, 3, 1, 0, 3, 5]
    return [c for q in v for c in q], [c for q in n for c in q], t


def split(layer):
    """Yield (verts, normals, tris0) chunks of at most MAX_TRIS triangles, 0-based."""
    v, n, t = layer["v"], layer["n"], [i - 1 for i in layer["t"]]
    tris = len(t) // 3
    for start in range(0, tris, MAX_TRIS):
        idx = t[start * 3:(start + MAX_TRIS) * 3]
        remap = {}
        cv, cn, ct = [], [], []
        for i in idx:
            j = remap.get(i)
            if j is None:
                j = len(remap)
                remap[i] = j
                cv.extend(v[i * 3:i * 3 + 3])
                cn.extend(n[i * 3:i * 3 + 3])
            ct.append(j)
        yield cv, cn, ct


class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.gltf = {
            "asset": {"version": "2.0", "generator": "City Legends make_glb.py"},
            "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
            "materials": [], "accessors": [], "bufferViews": [], "buffers": [],
        }

    def _view(self, data, target):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin.extend(data)
        self.gltf["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(self.gltf["bufferViews"]) - 1

    def _accessor(self, view, ctype, count, typ, mn=None, mx=None):
        a = {"bufferView": view, "componentType": ctype, "count": count, "type": typ}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        self.gltf["accessors"].append(a)
        return len(self.gltf["accessors"]) - 1

    def mesh_node(self, name, verts, normals, tris, material, offset):
        ox, oy, oz = offset
        pos = [verts[i] + (ox, oy, oz)[i % 3] for i in range(len(verts))]
        count = len(pos) // 3
        mn = [min(pos[k::3]) for k in range(3)]
        mx = [max(pos[k::3]) for k in range(3)]
        pv = self._view(struct.pack("<%df" % len(pos), *pos), 34962)
        nv = self._view(struct.pack("<%df" % len(normals), *normals), 34962)
        iv = self._view(struct.pack("<%dI" % len(tris), *tris), 34963)
        prim = {
            "attributes": {
                "POSITION": self._accessor(pv, 5126, count, "VEC3", mn, mx),
                "NORMAL": self._accessor(nv, 5126, count, "VEC3"),
            },
            "indices": self._accessor(iv, 5125, len(tris), "SCALAR"),
            "material": material,
        }
        self.gltf["meshes"].append({"name": name, "primitives": [prim]})
        self.gltf["nodes"].append({"name": name, "mesh": len(self.gltf["meshes"]) - 1})
        return len(self.gltf["nodes"]) - 1

    def material(self, m):
        self.gltf["materials"].append(m)
        return len(self.gltf["materials"]) - 1

    def group(self, name, children):
        self.gltf["nodes"].append({"name": name, "children": children})
        return len(self.gltf["nodes"]) - 1

    def save(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.gltf["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(self.gltf, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


def add_car(g, car_id, car, offset):
    children = []
    mats = {}

    def mat(layer):
        if layer not in mats:
            mats[layer] = g.material(material_for(layer, car))
        return mats[layer]

    for layer, data in sorted(car["body"].items()):
        for k, (v, n, t) in enumerate(split(data)):
            name = layer if k == 0 else "%s%d" % (layer, k + 1)
            children.append(g.mesh_node(name, v, n, t, mat(layer), offset))
    hub = car["hub"]
    for layer, data in sorted(car["wheel"].items()):
        for k, (v, n, t) in enumerate(split(data)):
            name = "Wheel" + layer + ("" if k == 0 else str(k + 1))
            wo = (offset[0] + hub[0], offset[1] + hub[1], offset[2] + hub[2])
            children.append(g.mesh_node(name, v, n, t, mat(layer), wo))
    marks = [("Mark_Origin", (0, 0, 0)), ("Mark_RefX", (REF, 0, 0)), ("Mark_RefZ", (0, 0, REF)), ("Mark_Hub", tuple(hub))]
    if car.get("plate"):
        marks.append(("Mark_Plate", tuple(car["plate"])))
    for i, p in enumerate(car.get("exhausts") or []):
        marks.append(("Mark_Exhaust%d" % (i + 1), tuple(p)))
    for name, p in marks:
        v, n, t = octahedron(p)
        children.append(g.mesh_node(name, v, n, t, mat("Marker"), offset))
    return g.group(car_id, children)


def main():
    with open(SRC) as f:
        cars = json.load(f)
    os.makedirs(os.path.join(OUT, "cars"), exist_ok=True)
    combined = Glb()
    for i, (car_id, car) in enumerate(cars.items()):
        node = add_car(combined, car_id, car, (i * SPACING, 0, 0))
        combined.gltf["scenes"][0]["nodes"].append(node)
        single = Glb()
        single.gltf["scenes"][0]["nodes"].append(add_car(single, car_id, car, (0, 0, 0)))
        single.save(os.path.join(OUT, "cars", car_id + ".glb"))
        print(car_id)
    combined.gltf["scenes"][0]["nodes"] = [combined.group("CarModels", combined.gltf["scenes"][0]["nodes"])]
    combined.save(os.path.join(OUT, "CityLegendsCars.glb"))


if __name__ == "__main__":
    main()
