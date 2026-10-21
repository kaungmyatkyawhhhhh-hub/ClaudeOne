# Draws the prompt 25 trainers' clothes as classic Shirt / Pants templates (585 x 559 PNG) into
# clothing_templates/trainers/<name>.png. Run from the repo root:  python tools/trainer_clothes.py
# Same layout as tools/clothing_templates.ps1 (torso rects F/B/R/L/U, arm rects per side; on the 128 px tall faces the upper
# torso uses 0-80 %, the lower torso 80-100 %; arm / leg rects: upper 0-45 %, lower 45-85 %, hand / foot 85-100 %; a Pants
# template puts the legs where a Shirt has the arms). Trainer clothes are fully opaque: the trainer's skin is painted under
# the clothes (TrainerFollowClient hides the muscle stages' separate skin layer on clothed trainers).
# Plain designs, no logos, no brands. Upload the PNGs (Studio upload_image) and put the ids in Config/Trainers look.shirt / pants.
import os
from PIL import Image, ImageDraw

OUT = os.path.join("clothing_templates", "trainers")
os.makedirs(OUT, exist_ok=True)

TORSO = {"F": (231, 74, 128, 128), "B": (427, 74, 128, 128), "R": (165, 74, 64, 128), "L": (361, 74, 64, 128), "U": (231, 8, 128, 64)}
RARM = {"F": (217, 355, 64, 128), "B": (85, 355, 64, 128), "R": (151, 355, 64, 128), "L": (19, 355, 64, 128), "U": (217, 289, 64, 64)}
LARM = {"F": (308, 355, 64, 128), "B": (440, 355, 64, 128), "L": (374, 355, 64, 128), "R": (506, 355, 64, 128), "U": (308, 289, 64, 64)}
SIDES = ("F", "B", "R", "L")


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def band(d, rect, t0, t1, color):
    x, y, w, h = rect
    d.rectangle([x, y + int(h * t0), x + w - 1, y + int(h * t1) - 1], fill=color)


def torso(d, color, top=0.0, bottom=1.0):
    for k in SIDES:
        band(d, TORSO[k], top, bottom, color)
    if top == 0:
        band(d, TORSO["U"], 0, 1, color)
        # the gutters between and above the torso faces too (the trap and delt meshes stretch into them)
        band(d, (160, 60, 425, 14), 0, 1, color)
    band(d, (160, 74, 425, 128), top, bottom, color)


def limbs(d, color, t0, t1, cap=True):
    for arm in (RARM, LARM):
        for k in SIDES:
            band(d, arm[k], t0, t1, color)
        if cap and t0 == 0:
            band(d, arm["U"], 0, 1, color)
    band(d, (0, 350, 585, 128), t0, t1, color)


def trim(d, sets, keys, at, thick, color):
    for s in sets:
        for k in keys:
            band(d, s[k], at - thick, at, color)


def vline(d, rect, fx, t0, t1, color, width=2):
    x, y, w, h = rect
    cx = x + int(w * fx)
    d.rectangle([cx - width // 2, y + int(h * t0), cx + (width - 1) // 2, y + int(h * t1) - 1], fill=color)


def hline(d, rect, fy, f0, f1, color, width=2):
    x, y, w, h = rect
    cy = y + int(h * fy)
    d.rectangle([x + int(w * f0), cy - width // 2, x + int(w * f1) - 1, cy + (width - 1) // 2], fill=color)


def new(skin):
    img = Image.new("RGBA", (585, 559), hexc(skin))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


# 5) Duke Ironside: a black sleeveless hoodie with gold trim (deep armholes: big traps and delts show), drawstrings, a pouch
DUKE_SKIN, BLACK, GOLD = "#D29A72", "#141418", "#E8B53A"
img, d = new(DUKE_SKIN)
torso(d, hexc(BLACK), 0, 1)
for k in ("R", "L"):  # the armholes: the top third of the sides open
    band(d, TORSO[k], 0, 0.34, hexc(DUKE_SKIN))
    hline(d, TORSO[k], 0.34, 0, 1, hexc(GOLD), 3)
for k in ("F", "B"):  # the armhole edges on the front and back panels
    vline(d, TORSO[k], 0.03, 0, 0.36, hexc(GOLD), 3)
    vline(d, TORSO[k], 0.97, 0, 0.36, hexc(GOLD), 3)
trim(d, [TORSO], SIDES, 0.8, 0.04, hexc(GOLD))  # the hem
f = TORSO["F"]
d.line([f[0] + 52, f[1] + 2, f[0] + 50, f[1] + 34], fill=hexc(GOLD), width=2)  # drawstrings
d.line([f[0] + 76, f[1] + 2, f[0] + 78, f[1] + 34], fill=hexc(GOLD), width=2)
d.line([f[0] + 30, f[1] + 70, f[0] + 98, f[1] + 70], fill=hexc("#2A2A30"), width=2)  # the pouch
d.line([f[0] + 30, f[1] + 70, f[0] + 24, f[1] + 98], fill=hexc("#2A2A30"), width=2)
d.line([f[0] + 98, f[1] + 70, f[0] + 104, f[1] + 98], fill=hexc("#2A2A30"), width=2)
hline(d, TORSO["U"], 0.62, 0.12, 0.88, hexc(GOLD), 3)  # the hood seam across the shoulders
save(img, "duke_shirt")

# Duke's shorts: black lifting shorts to above the knee, a gold side stripe
img, d = new(DUKE_SKIN)
torso(d, hexc(BLACK), 0, 1)
limbs(d, hexc(BLACK), 0, 0.42)
for arm in (RARM, LARM):
    for k in ("R", "L"):
        vline(d, arm[k], 0.5, 0, 0.42, hexc(GOLD), 4)
trim(d, [RARM, LARM], SIDES, 0.42, 0.04, hexc("#2A2A30"))
save(img, "duke_pants")

# 6) Volta: a black training top (open shoulders) with purple piping and a red stripe
VOLTA_SKIN, RED, PURPLE = "#A86B45", "#D8283E", "#8A3AD0"
img, d = new(VOLTA_SKIN)
torso(d, hexc("#16161A"), 0, 1)
for k in ("R", "L"):
    band(d, TORSO[k], 0, 0.26, hexc(VOLTA_SKIN))
    vline(d, TORSO[k], 0.5, 0.26, 0.8, hexc(PURPLE), 3)
for k in ("F", "B"):
    vline(d, TORSO[k], 0.04, 0, 0.3, hexc(PURPLE), 3)
    vline(d, TORSO[k], 0.96, 0, 0.3, hexc(PURPLE), 3)
hline(d, TORSO["F"], 0.36, 0.06, 0.94, hexc(RED), 4)
trim(d, [TORSO], SIDES, 0.8, 0.04, hexc(PURPLE))
save(img, "volta_shirt")

# Volta's leggings: black to mid-calf, a red side stripe with purple edges
img, d = new(VOLTA_SKIN)
torso(d, hexc("#16161A"), 0, 1)
limbs(d, hexc("#16161A"), 0, 0.66)
for arm in (RARM, LARM):
    for k in ("R", "L"):
        vline(d, arm[k], 0.5, 0, 0.66, hexc(RED), 6)
        vline(d, arm[k], 0.38, 0, 0.66, hexc(PURPLE), 2)
        vline(d, arm[k], 0.62, 0, 0.66, hexc(PURPLE), 2)
save(img, "volta_pants")

# 7) The Shadow: a black top with short sleeves and faint purple seams
SHADOW_SKIN, DARK, SEAM = "#7A5A48", "#0E0E11", "#3E2A5E"
img, d = new(SHADOW_SKIN)
torso(d, hexc(DARK), 0, 1)
limbs(d, hexc(DARK), 0, 0.4)
for k in ("R", "L"):
    vline(d, TORSO[k], 0.5, 0, 0.8, hexc(SEAM), 2)
vline(d, TORSO["F"], 0.5, 0.05, 0.8, hexc(SEAM), 2)
hline(d, TORSO["F"], 0.5, 0.15, 0.85, hexc(SEAM), 2)
hline(d, TORSO["U"], 0.5, 0, 1, hexc(SEAM), 2)
trim(d, [RARM, LARM], SIDES, 0.4, 0.03, hexc(SEAM))
trim(d, [TORSO], SIDES, 0.8, 0.02, hexc(SEAM))
save(img, "shadow_shirt")

# The Shadow's pants: black, long, purple side seams
img, d = new(SHADOW_SKIN)
torso(d, hexc(DARK), 0, 1)
limbs(d, hexc(DARK), 0, 0.86)
for arm in (RARM, LARM):
    for k in ("R", "L"):
        vline(d, arm[k], 0.5, 0, 0.86, hexc(SEAM), 2)
    for k in SIDES:
        band(d, arm[k], 0.86, 1, hexc(DARK))  # (the feet: dark too, under the shoes)
save(img, "shadow_pants")
