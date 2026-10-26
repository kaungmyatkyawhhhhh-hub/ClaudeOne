# Draws the BODY ALTER READY popup backgrounds for alters 6-15 (Tier 2 Stone, Tier 3 Metal), 26 Oct: 1200 x 480, no text,
# no bodies, abstract like Tier 1's (Downloads\gym_arc_alters\ui_tier1: a heartbeat line, light streaks, sun rays, veins,
# a gold burst). Dark base, glowing shapes in each alter's accent (Config/AlterThemes colors).
# Run:  python tools/alter_backgrounds.py   (numpy + PIL) -> Downloads\gym_arc_alters\for_group_bg. Import them to the group,
# put the ids in Config/AlterThemes `bg` (themes 6-15).
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1200, 480
OUT = os.path.join(os.path.expanduser("~"), "Downloads", "gym_arc_alters", "for_group_bg")
os.makedirs(OUT, exist_ok=True)
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)


def noise(seed, beta, low=2.0):
    # smooth fractal noise (FFT-shaped white noise), 0..1
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((H, W))
    fy = np.fft.fftfreq(H)[:, None] * H
    fx = np.fft.rfftfreq(W)[None, :] * W
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    amp = 1 / f ** beta
    amp[f < low] = 0
    out = np.fft.irfft2(np.fft.rfft2(white) * amp, s=(H, W))
    out -= out.min()
    return out / out.max()


def base(dark, accent, glow_at=(0.5, 1.15), glow_size=0.9, strength=0.55):
    # the dark base with the accent glowing up from below (like the tier colour washes)
    gx, gy = glow_at
    d = np.sqrt(((XX / W - gx) * 1.6) ** 2 + (YY / H - gy) ** 2)
    g = np.clip(1 - d / glow_size, 0, 1) ** 2 * strength
    img = rgb(dark)[None, None] * (1 - g[..., None]) + rgb(accent)[None, None] * g[..., None]
    return img


def vignette(img):
    d = np.sqrt(((XX / W - 0.5) * 1.3) ** 2 + ((YY / H - 0.5) * 1.1) ** 2)
    return img * np.clip(1.15 - d * 0.9, 0.35, 1)[..., None]


def add_glow(img, mask, color, blur=8, strength=1.0):
    # a mask drawn sharp, plus a soft blurred halo, added in the colour
    m = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    halo = np.asarray(m.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255
    core = np.asarray(m.filter(ImageFilter.GaussianBlur(1)), dtype=np.float32) / 255
    light = np.clip(core + halo * 1.3, 0, 1) * strength
    return img + rgb(color)[None, None] * light[..., None]


def lines_mask(draw_fn):
    im = Image.new("L", (W, H), 0)
    draw_fn(ImageDraw.Draw(im))
    return np.asarray(im, dtype=np.float32) / 255


def cracks(seed, count, width):
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * [W, H]
    d1 = np.full((H, W), 1e9, np.float32)
    d2 = np.full((H, W), 1e9, np.float32)
    for px, py in pts:
        d = np.sqrt((XX - px) ** 2 + (YY - py) ** 2)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        d1 = np.where(closer, d, d1)
    return np.clip(1 - (d2 - d1) / width, 0, 1)


def save(name, img):
    Image.fromarray(np.clip(vignette(img), 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + "_bg.png"))
    print(name)


rng = np.random.default_rng(26)

# 06 Clay: glowing cracks in dark terracotta, embers of heat
img = base("#2A1810", "#C9845E", strength=0.45) * (0.85 + 0.3 * noise(601, 1.5)[..., None])
img = add_glow(img, cracks(602, 38, 3.0), "#FF9A5A", blur=6, strength=0.9)
save("alter06_clay", img)

# 07 Sandstone: layered dune bands under a warm sun
img = base("#2E2414", "#E3BE7E", glow_at=(0.72, 0.15), glow_size=0.7, strength=0.6)
warp = noise(701, 1.9) * 40
bands = np.sin((YY + warp) / H * np.pi * 9) * 0.5 + 0.5
img = img * (0.75 + 0.35 * bands[..., None])
dunes = lines_mask(lambda d: [d.line([(x, H * (0.62 + 0.08 * k) + 26 * np.sin(x / 140 + k)) for x in range(0, W + 10, 10)], fill=255, width=2) for k in range(4)])
img = add_glow(img, dunes, "#F4DDA8", blur=5, strength=0.7)
save("alter07_sandstone", img)

# 08 Granite: a dark slab, light flecks, two shards of light breaking through
img = base("#1C1C1E", "#A8A6A4", strength=0.35) * (0.8 + 0.3 * noise(801, 1.2)[..., None])
flecks = (noise(802, 0.2, 60) > 0.66).astype(np.float32)
img = img + flecks[..., None] * 60
shards = lines_mask(lambda d: [d.polygon(p, fill=255) for p in ([(820, 0), (860, 0), (700, 480), (680, 480)], [(300, 0), (322, 0), (180, 480), (168, 480)])])
img = add_glow(img, shards * 0.7, "#E2E0DE", blur=14, strength=0.8)
save("alter08_granite", img)

# 09 Marble: soft white veins glowing over a dark stone
field = noise(901, 2.3)
turb = noise(902, 2.1)
v = (field + turb * 0.35)
v = (v - v.min()) / (v.max() - v.min())
veins = np.clip(1 - np.abs(v - 0.5) / 0.012, 0, 1) + np.clip(1 - np.abs(v - 0.35) / 0.007, 0, 1) * 0.6
img = base("#24221F", "#F2EEE6", strength=0.3)
img = add_glow(img, np.clip(veins, 0, 1), "#FFFFFF", blur=7, strength=0.85)
save("alter09_marble", img)

# 10 Obsidian: black glass shards with violet edges
img = base("#0A080E", "#8E6BD8", strength=0.4)
def shard_draw(d):
    for _ in range(14):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(40, 140)
        pts = [(cx + r * np.cos(a), cy + r * 0.6 * np.sin(a)) for a in np.sort(rng.uniform(0, 2 * np.pi, 3))]
        d.polygon(pts, outline=255, width=2)
img = add_glow(img, lines_mask(shard_draw), "#B9A3F0", blur=6, strength=0.8)
save("alter10_obsidian", img)

# 11 Bronze: a forge: warm glow from below and sparks flying up
img = base("#24140A", "#D08A48", glow_at=(0.5, 1.2), glow_size=1.0, strength=0.7)
def sparks(d):
    for _ in range(90):
        x, y = rng.uniform(0, W), rng.uniform(H * 0.2, H)
        ln = rng.uniform(8, 30)
        a = rng.uniform(-2.2, -0.9)
        d.line([(x, y), (x + ln * np.cos(a), y + ln * np.sin(a))], fill=int(rng.uniform(120, 255)), width=2)
img = add_glow(img, lines_mask(sparks), "#F2BE86", blur=4, strength=0.9)
save("alter11_bronze", img)

# 12 Iron: dark plate with rows of rivets and a hot seam
img = base("#141416", "#8E9098", strength=0.3) * (0.85 + 0.25 * noise(1201, 0.9, 6)[..., None])
rivets = lines_mask(lambda d: [d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=200) for y in (60, 420) for x in range(40, W, 80)])
img = add_glow(img, rivets, "#C6C8CE", blur=3, strength=0.6)
seam = lines_mask(lambda d: d.line([(0, 250), (W, 230)], fill=255, width=3))
img = add_glow(img, seam, "#FF7A2A", blur=12, strength=0.9)
save("alter12_iron", img)

# 13 Steel: brushed lines and cold blades of light (like SHREDDED's slices)
img = base("#12161A", "#B8C6D4", strength=0.35)
brushed = np.repeat(np.random.default_rng(1301).random((H, 1)), W, axis=1)
img = img * (0.85 + 0.25 * brushed[..., None])
blades = lines_mask(lambda d: [d.line([(x, 0), (x - 180, H)], fill=255, width=w) for x, w in ((300, 3), (360, 1), (900, 3), (950, 1), (1010, 2))])
img = add_glow(img, blades, "#EEF3F8", blur=8, strength=0.9)
save("alter13_steel", img)

# 14 Chrome: mirror sweeps of light
img = base("#101418", "#E6F0FA", strength=0.35)
sweep = np.clip(1 - np.abs(((XX - YY * 1.2) % 520) - 260) / 40, 0, 1)
img = img + rgb("#E6F0FA")[None, None] * (sweep * 0.35)[..., None]
img = add_glow(img, lines_mask(lambda d: d.line([(150, H), (650, 0)], fill=255, width=3)), "#FFFFFF", blur=16, strength=0.9)
save("alter14_chrome", img)

# 15 Gold: a gold burst with rays and dust (end of Tier 3, like PEAK)
img = base("#1A1204", "#FFD36B", glow_at=(0.5, 0.95), glow_size=0.8, strength=0.6)
ang = np.arctan2(YY - H * 0.95, XX - W * 0.5)
rays = (np.cos(ang * 18) * 0.5 + 0.5) ** 6 * np.clip(1 - np.sqrt((XX - W * 0.5) ** 2 + (YY - H * 0.95) ** 2) / 650, 0, 1)
img = img + rgb("#FFD36B")[None, None] * (rays * 0.6)[..., None]
dust = (np.random.default_rng(1501).random((H, W)) > 0.9985).astype(np.float32)
img = add_glow(img, dust, "#FFF3C4", blur=2, strength=1.0)
save("alter15_gold", img)
