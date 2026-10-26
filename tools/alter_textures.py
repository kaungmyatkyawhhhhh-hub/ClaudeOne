# Draws the Body Alter skins for Tier 2 (Stone) and Tier 3 (Metal) (26 Oct): 1024 x 1024 tileable color / normal
# (OpenGL, Y up) / roughness / metalness maps into Downloads\gym_arc_alters\tier<n>_<name>. Our own procedural textures.
# Run:  python tools/alter_textures.py   (numpy + PIL). Upload the PNGs, put the ids in Config/Alters `textures` and run
# tools/builders/SkinStages BuildAlters() in Studio.
# Detail rule (Body Alters note): one texture spans ~10-14 studs of body, so features are small and lines high contrast.
# These alters wear their own colors (Config/Alters tone = "Raw": no skin tint), so the color maps are the real colors.
import os
import numpy as np
from PIL import Image

SIZE = 1024
ROOT = os.path.join(os.path.expanduser("~"), "Downloads", "gym_arc_alters")


def spectral(seed, beta, low=2.0, high=None):
    # tileable fractal noise: white noise shaped by 1/f^beta in frequency space (periodic by construction), 0..1
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((SIZE, SIZE))
    fy = np.fft.fftfreq(SIZE)[:, None] * SIZE
    fx = np.fft.rfftfreq(SIZE)[None, :] * SIZE
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    amp = 1 / f ** beta
    amp[f < low] = 0
    if high:
        amp *= np.exp(-(f / high) ** 2)
    out = np.fft.irfft2(np.fft.rfft2(white) * amp, s=(SIZE, SIZE))
    out -= out.min()
    return out / out.max()


def norm01(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def normal_from_height(h, strength):
    # periodic central differences -> OpenGL normal map
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def ridge(field, level, width):
    # thin lines where a field crosses `level` (veins, cracks)
    return np.clip(1 - np.abs(field - level) / width, 0, 1)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def rgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


def save(folder, name, color, height, strength, rough, metal):
    os.makedirs(folder, exist_ok=True)
    Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)).save(os.path.join(folder, f"{name}_color.png"))
    Image.fromarray(normal_from_height(height, strength)).save(os.path.join(folder, f"{name}_normal.png"))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, f"{name}_roughness.png"))
    Image.fromarray((np.clip(metal, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, f"{name}_metalness.png"))
    mean = color.reshape(-1, 3).mean(0)
    print(f"{name}: mean = {{ {int(mean[0])}, {int(mean[1])}, {int(mean[2])} }}")


def cells(seed, count):
    # tileable Voronoi edge distance (cracks / plates): distance to nearest minus second nearest seed, wrapped
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * SIZE
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d1 = np.full((SIZE, SIZE), 1e9, np.float32)
    d2 = np.full((SIZE, SIZE), 1e9, np.float32)
    for px, py in pts:
        dx = np.abs(xx - px)
        dx = np.minimum(dx, SIZE - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, SIZE - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        d1 = np.where(closer, d, d1)
    return d2 - d1


Z = np.zeros((SIZE, SIZE))
ONE = np.ones((SIZE, SIZE))

# ---------------------------------------------------------------- Tier 2: Stone
stone = os.path.join(ROOT, "tier2_stone")

# 06 Clay: warm terracotta, soft blotches, fine dry cracks, matte
blot = spectral(601, 1.6, 3)
grain = spectral(602, 0.6, 40)
crack = np.clip(1 - cells(603, 90) / 3.0, 0, 1)
color = mix(rgb("#B5704E")[None, None] * ONE[..., None], rgb("#8E4F35")[None, None] * ONE[..., None], blot * 0.7)
color = color * (0.92 + 0.16 * grain[..., None])
color = mix(color, rgb("#5E3021")[None, None] * ONE[..., None], crack * 0.8)
height = blot * 0.4 + grain * 0.25 - crack * 0.9
save(stone, "alter06_clay", color, height, 6, 0.85 + 0.1 * grain, Z)

# 07 Sandstone: wavy layered bands, sandy grain
warp = spectral(701, 1.8, 2) * 60
yy = np.mgrid[0:SIZE, 0:SIZE][0]
bands = 0.5 + 0.5 * np.sin((yy + warp) / SIZE * 2 * np.pi * 12)
fine = spectral(702, 0.3, 80)
color = mix(rgb("#E3C48E")[None, None] * ONE[..., None], rgb("#B98C55")[None, None] * ONE[..., None], bands * 0.65)
color = color * (0.88 + 0.22 * fine[..., None])
height = bands * 0.5 + fine * 0.5
save(stone, "alter07_sandstone", color, height, 5, 0.9 * ONE, Z)

# 08 Granite: grey with black, white and pink flecks
base = spectral(801, 1.2, 4)
f1 = spectral(802, 0.2, 60, 260)
f2 = spectral(803, 0.2, 60, 260)
f3 = spectral(804, 0.2, 60, 260)
color = mix(rgb("#8D8A88")[None, None] * ONE[..., None], rgb("#6E6B6A")[None, None] * ONE[..., None], base)
color = mix(color, rgb("#1E1C1C")[None, None] * ONE[..., None], np.clip((f1 - 0.62) * 6, 0, 1))
color = mix(color, rgb("#E9E6E2")[None, None] * ONE[..., None], np.clip((f2 - 0.64) * 6, 0, 1))
color = mix(color, rgb("#B98478")[None, None] * ONE[..., None], np.clip((f3 - 0.66) * 6, 0, 1) * 0.8)
height = f1 * 0.3 + f2 * 0.3 + base * 0.2
save(stone, "alter08_granite", color, height, 4, 0.45 + 0.2 * f1, Z)

# 09 Marble: polished white, soft grey clouds, dark grey veins
field = spectral(901, 2.3, 2)
turb = spectral(902, 2.1, 3)
veins = ridge(norm01(field + turb * 0.35), 0.5, 0.012) + ridge(norm01(field * 0.6 + turb), 0.42, 0.006) * 0.6
veins = np.clip(veins, 0, 1)
clouds = spectral(903, 1.4, 3)
color = mix(rgb("#F2EFEA")[None, None] * ONE[..., None], rgb("#D6D2CC")[None, None] * ONE[..., None], clouds * 0.5)
color = mix(color, rgb("#5F5D5E")[None, None] * ONE[..., None], veins * 0.85)
height = -veins * 0.4 + clouds * 0.1
save(stone, "alter09_marble", color, height, 3, 0.18 + 0.15 * veins, Z)

# 10 Obsidian: black volcanic glass, purple-blue sheen, conchoidal ripples, very glossy
ripple_field = spectral(1001, 1.7, 3)
ripples = 0.5 + 0.5 * np.sin(ripple_field * 2 * np.pi * 9)
sheen = spectral(1002, 1.5, 2)
color = mix(rgb("#1E1A26")[None, None] * ONE[..., None], rgb("#55407A")[None, None] * ONE[..., None], np.clip(sheen - 0.3, 0, 1) * 1.4)
color = color * (0.85 + 0.3 * ripples[..., None])
height = ripples * 0.6
save(stone, "alter10_obsidian", color, height, 4, 0.08 + 0.08 * ripples, Z + 0.15)

# ---------------------------------------------------------------- Tier 3: Metal
metal = os.path.join(ROOT, "tier3_metal")

# 11 Bronze: warm bronze, green-teal patina in the hollows, hammered dents
dents = spectral(1101, 1.3, 20, 120)
patina_mask = np.clip((spectral(1102, 1.5, 3) - 0.6) * 3, 0, 1) * np.clip((0.55 - dents) * 3, 0, 1)
color = mix(rgb("#B07A3E")[None, None] * ONE[..., None], rgb("#8A5A2B")[None, None] * ONE[..., None], dents * 0.5)
color = mix(color, rgb("#4FA38A")[None, None] * ONE[..., None], patina_mask)
save(metal, "alter11_bronze", color, dents * 0.8, 6, 0.35 + 0.5 * patina_mask, 0.9 - 0.85 * patina_mask)

# 12 Iron: dark grey, rough cast surface, faint rust in spots
cast = spectral(1201, 0.9, 6)
rust = np.clip((spectral(1202, 1.6, 3) - 0.62) * 3, 0, 1) * cast
color = mix(rgb("#5A5B5F")[None, None] * ONE[..., None], rgb("#3C3D41")[None, None] * ONE[..., None], cast)
color = mix(color, rgb("#7A4527")[None, None] * ONE[..., None], rust * 0.8)
save(metal, "alter12_iron", color, cast * 0.9, 6, 0.6 + 0.3 * rust, 0.8 - 0.6 * rust)

# 13 Steel: brushed lines across the body, cool grey
rng = np.random.default_rng(1301)
lines = rng.standard_normal((SIZE, 1)) * np.ones((1, SIZE))
lines = norm01(np.fft.irfft2(np.fft.rfft2(lines) * (1 / (1 + (np.fft.fftfreq(SIZE)[:, None] * SIZE / 200) ** 2)), s=(SIZE, SIZE)))
wobble = spectral(1302, 1.4, 3)
color = rgb("#A7B0BA")[None, None] * (0.85 + 0.25 * lines[..., None]) * (0.95 + 0.1 * wobble[..., None])
save(metal, "alter13_steel", color, lines * 0.35, 3, 0.3 + 0.15 * lines, 0.95 * ONE)

# 14 Chrome: mirror bright, almost no detail, a faint polish swirl
swirl = spectral(1401, 1.8, 2)
color = rgb("#DDE3EA")[None, None] * (0.92 + 0.12 * swirl[..., None])
save(metal, "alter14_chrome", color, swirl * 0.05, 2, 0.06 + 0.05 * swirl, ONE)

# 15 Gold: polished gold, soft hammered dents (end of tier 3)
dents = spectral(1501, 1.3, 16, 100)
color = mix(rgb("#F6C75A")[None, None] * ONE[..., None], rgb("#C98A12")[None, None] * ONE[..., None], dents * 0.6)
save(metal, "alter15_gold", color, dents * 0.7, 5, 0.18 + 0.12 * dents, ONE)
