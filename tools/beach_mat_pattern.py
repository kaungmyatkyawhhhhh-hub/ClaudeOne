# Beach mat pattern (owner, 26 Oct: "put some patterns on the beach gym mats", "the hexagon doesn't fit the beach theme"):
# a seamless tile of soft waves, white on transparent, tinted per mat by the Texture's Color3 in Studio.
# Output: Downloads/gym_arc_beach/beach_waves.png (512 x 256, tiles left-right and top-bottom).
import math
from PIL import Image, ImageDraw

W, H = 512, 256
SCALE = 4  # drawn big, scaled down for smooth edges
img = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
rows = 4
for r in range(rows):
    y0 = (r + 0.5) * H / rows
    phase = 0 if r % 2 == 0 else math.pi  # every other row shifted half a wave
    pts = []
    for i in range(0, W * SCALE + 1, 4):
        x = i / SCALE
        y = y0 + 9 * math.sin(2 * math.pi * x / (W / 2) + phase)  # two waves across the tile: seamless
        pts.append((i, y * SCALE))
    d.line(pts, fill=(255, 255, 255, 255), width=7 * SCALE, joint="curve")
    # a thinner echo line under each wave
    pts2 = [(x, y + 16 * SCALE) for x, y in pts]
    d.line(pts2, fill=(255, 255, 255, 150), width=3 * SCALE, joint="curve")
img = img.resize((W, H), Image.LANCZOS)
img.save(r"C:\Users\kaung\Downloads\gym_arc_beach\beach_waves.png")
print("saved")
