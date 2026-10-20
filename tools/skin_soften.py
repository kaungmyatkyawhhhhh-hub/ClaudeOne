# skin_soften (20 Oct, owner prompt 15 part 3): makes the softer stage 4 / 5 skin maps (uploaded, ids in Config/SkinStages).
# Usage: python -I tools/skin_soften.py <Downloads/skin_textures> <out dir>
# calmer mass monster skin maps: normal map at STRENGTH (fine detail only), large dark patches taken out of the color map,
# roughness never below stage 3's (no shinier than the full-look skin)
import sys, numpy as np
from PIL import Image, ImageFilter
SRC, OUT = sys.argv[1], sys.argv[2]
STRENGTH = {"stage4_rock_start": 0.35, "stage5_mass_monster_rock": 0.3}
ref_rough = np.asarray(Image.open(SRC + "/stage3_max_ripped_shiny_roughness.png").convert("L"), float) / 255
for stem, k in STRENGTH.items():
    n = np.asarray(Image.open(SRC + "/%s_normal.png" % stem).convert("RGB"), float) / 255 * 2 - 1
    # remove the big lumps too: subtract a blurred copy's tilt (keeps the fine grain)
    blur = np.asarray(Image.fromarray(((n + 1) / 2 * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)), float) / 255 * 2 - 1
    xy = (n[..., :2] - blur[..., :2] * 0.7) * k
    z = np.sqrt(np.clip(1 - (xy ** 2).sum(-1), 0.05, 1))
    out = np.dstack([xy, z])
    Image.fromarray(((out + 1) / 2 * 255).round().clip(0, 255).astype(np.uint8)).save(OUT + "/%s_normal_soft.png" % stem)
    c = np.asarray(Image.open(SRC + "/%s_color.png" % stem).convert("RGB"), float)
    cb = np.asarray(Image.open(SRC + "/%s_color.png" % stem).convert("RGB").filter(ImageFilter.GaussianBlur(40)), float)
    c2 = c - (cb - cb.mean((0, 1))) * 0.85
    Image.fromarray(c2.clip(0, 255).astype(np.uint8)).save(OUT + "/%s_color_soft.png" % stem)
    r = np.asarray(Image.open(SRC + "/%s_roughness.png" % stem).convert("L"), float) / 255
    r2 = np.maximum(r, ref_rough.mean())
    Image.fromarray((r2 * 255).astype(np.uint8)).save(OUT + "/%s_roughness_soft.png" % stem)
    print(stem, "rough mean %.2f -> %.2f (stage3 %.2f)" % (r.mean(), r2.mean(), ref_rough.mean()),
          "color std %.1f -> %.1f" % (c.std(), c2.std()))
