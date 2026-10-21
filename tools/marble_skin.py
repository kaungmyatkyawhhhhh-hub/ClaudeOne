# Draws the "Trainer_Marble" skin (prompt 25, Atlas the Eternal trainer: polished white marble with gold veins) as
# 1024 x 1024 color / normal / roughness / metalness maps into clothing_templates/trainers/marble_<map>.png.
# Run from the repo root:  python tools/marble_skin.py   (PIL only). Upload the four PNGs, put the ids in
# Config/SkinStages.Trainer (Marble) and run tools/builders/SkinStages BuildTrainerSkins() in Studio.
import os
import random
from PIL import Image, ImageChops, ImageFilter, ImageOps

OUT = os.path.join("clothing_templates", "trainers")
os.makedirs(OUT, exist_ok=True)
SIZE = 1024
random.seed(25)


def noise(cells):
    # smooth value noise: random cells blown up with bicubic smoothing
    small = Image.new("L", (cells, cells))
    small.putdata([random.randint(0, 255) for _ in range(cells * cells)])
    return small.resize((SIZE, SIZE), Image.BICUBIC)


def fractal(base, octaves, falloff=0.5):
    out = noise(base)
    weight = 1.0
    total = 1.0
    for i in range(1, octaves):
        weight *= falloff
        total += weight
        out = Image.blend(out, noise(base * 2 ** i), weight / total)
    return out


def contour(field, level, width, soft):
    # thin lines where the field crosses `level` (marble veins are the contour lines of a turbulent field)
    lut = []
    for v in range(256):
        dist = abs(v - level)
        lut.append(255 if dist <= width else max(0, int(255 * (1 - (dist - width) / soft))) if dist <= width + soft else 0)
    return field.point(lut)


clouds = ImageOps.autocontrast(fractal(6, 5))
gold_field = ImageOps.autocontrast(fractal(4, 6, 0.55))
grey_field = ImageOps.autocontrast(fractal(5, 6, 0.55))
gold = contour(gold_field, 128, 3, 4).filter(ImageFilter.GaussianBlur(0.8))
gold2 = contour(gold_field, 70, 1, 3).filter(ImageFilter.GaussianBlur(0.6)).point(lambda v: v * 0.85)
gold = ImageChops.lighter(gold, gold2.convert("L"))
grey = contour(grey_field, 110, 2, 10).filter(ImageFilter.GaussianBlur(2.5)).point(lambda v: v * 0.18)

# color: warm white, faint grey clouds and veins, gold veins
white = Image.new("RGB", (SIZE, SIZE), (246, 243, 236))
cloud_tint = Image.new("RGB", (SIZE, SIZE), (218, 214, 208))
color = Image.composite(cloud_tint, white, clouds.point(lambda v: int(v * 0.35)))
color = Image.composite(Image.new("RGB", (SIZE, SIZE), (178, 174, 170)), color, grey.convert("L"))
color = Image.composite(Image.new("RGB", (SIZE, SIZE), (232, 176, 48)), color, gold)
color.save(os.path.join(OUT, "marble_color.png"))

# normal: flat, the gold veins a touch inlaid
height = ImageChops.lighter(gold, grey).filter(ImageFilter.GaussianBlur(1.2))
dx = height.filter(ImageFilter.Kernel((3, 3), [-1, 0, 1, -2, 0, 2, -1, 0, 1], 8, 128))
dy = height.filter(ImageFilter.Kernel((3, 3), [-1, -2, -1, 0, 0, 0, 1, 2, 1], 8, 128))
normal = Image.merge("RGB", (dx, dy, Image.new("L", (SIZE, SIZE), 255)))
normal.save(os.path.join(OUT, "marble_normal.png"))

# roughness: polished stone (low), the veins a little rougher; metalness: the gold veins
rough = Image.composite(Image.new("L", (SIZE, SIZE), 90), Image.new("L", (SIZE, SIZE), 38), gold)
rough.save(os.path.join(OUT, "marble_roughness.png"))
metal = gold.point(lambda v: int(v * 0.95))
metal.save(os.path.join(OUT, "marble_metalness.png"))
print("marble maps written")
