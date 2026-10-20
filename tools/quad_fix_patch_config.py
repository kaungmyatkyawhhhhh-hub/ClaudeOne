# quad_fix_patch_config (19 Oct): writes the fixed thigh stage meshes' bounding boxes (bounds.json from
# tools/quad_fix_lowpoly.py) into src/ReplicatedStorage/Shared/Config/BodyStages.luau (center / size of each BS_*Leg_* entry;
# the importer centres a mesh on its bounds, so Shared.BodyStages needs them). Run from the repo root AFTER the import.
# Usage: python -I tools/quad_fix_patch_config.py <bounds.json> [--with-g000]
# (--with-g000, 20 Oct torso back / cap set: its g000 meshes changed too)
import json
import re
import sys

PATH = "src/ReplicatedStorage/Shared/Config/BodyStages.luau"
WITH_G000 = "--with-g000" in sys.argv[2:]
bounds = json.load(open(sys.argv[1], encoding="utf-8"))
text = open(PATH, encoding="utf-8").read()
count = 0
for name, b in bounds.items():
    if name.endswith("_g000") and not WITH_G000:
        continue  # (unchanged: no growth at look 0)
    pattern = r'(file = "%s", center = )Vector3\.new\([^)]*\)(, size = )Vector3\.new\([^)]*\)' % re.escape(name)
    c, s = b["center"], b["size"]
    new = r"\g<1>Vector3.new(%.4f, %.4f, %.4f)\g<2>Vector3.new(%.4f, %.4f, %.4f)" % (c[0], c[1], c[2], s[0], s[1], s[2])
    text, n = re.subn(pattern, new, text)
    count += n
open(PATH, "w", encoding="utf-8", newline="").write(text)
print("patched", count, "entries")
