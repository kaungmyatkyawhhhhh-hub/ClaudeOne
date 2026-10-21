# Makes the trainers' pictures (prompt 25) from Studio screen captures taken with tools/trainer_photos.luau:
#   <id>_icon.png  256 x 256  chest up, in a Black + Gold frame in the rarity color (odds lists, Trainers tab, boards)
#   <id>_art.png   340 x 300  full body in his own pose on a clear background (the roll reveal card)
#   secret_icon.png           the Secret trainer as a black silhouette in a grey frame (before you own him)
# Usage:  python tools/trainer_icons.py <manifest.json> <out dir>
# manifest: { "<id>": { "bust": capture.jpg, "full": capture.jpg, "key": "green" | "blue" | "magenta", "color": "#rarity",
#             "secret": true for the silhouette } , ... }
# The captures are chroma-keyed (the backdrop is an unlit #00FF00 / #0000FF / #FF00FF wall): the key color's distance gives the alpha,
# the edges lose the key's spill. PIL only.
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

GOLD = (246, 199, 90)
DARK = (20, 20, 23)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def key_out(path, key):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if key == "green":
                spill = g - max(r, b)          # how much greener than the rest
                a = 255 if spill < 40 else (0 if spill > 110 else int(255 * (110 - spill) / 70))
                if a < 255:
                    g = min(g, max(r, b) + 8)  # despill
            elif key == "blue":
                spill = b - max(r, g)
                a = 255 if spill < 40 else (0 if spill > 110 else int(255 * (110 - spill) / 70))
                if a < 255:
                    b = min(b, max(r, g) + 8)
            else:  # magenta
                spill = min(r, b) - g
                a = 255 if spill < 50 else (0 if spill > 130 else int(255 * (130 - spill) / 80))
                if a < 255:
                    m = g + 8
                    r, b = min(r, max(m, r - spill)), min(b, max(m, b - spill))
            op[x, y] = (r, g, b, a)
    # a soft 1 px edge
    alpha = out.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    out.putalpha(alpha)
    return out


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def gradient(size, top, bottom):
    g = Image.new("RGB", size)
    d = ImageDraw.Draw(g)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        d.line([(0, y), (size[0], y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def icon(cut, color, secret=False, size=256):
    # the cutout: a centred square of the capture (chest up), bottom aligned
    w, h = cut.size
    side = min(w, h)
    sq = cut.crop(((w - side) // 2, h - side, (w - side) // 2 + side, h))
    inner = size - 20
    sq = sq.resize((inner, inner), Image.LANCZOS)
    if secret:
        alpha = sq.getchannel("A")
        black = Image.new("RGBA", sq.size, (6, 6, 8, 255))
        black.putalpha(alpha)
        rim = alpha.filter(ImageFilter.MaxFilter(5))
        rim_img = Image.new("RGBA", sq.size, (142, 142, 154, 255))
        rim_img.putalpha(ImageChops.subtract(rim, alpha))
        sq = Image.alpha_composite(rim_img, black)
        top, bottom = (74, 74, 84), (28, 28, 33)
        frame = (142, 142, 154)
    else:
        # (a light rarity color, Eternal's cream, gets a darker card so the white marble stands out)
        light = (color[0] * 0.3 + color[1] * 0.59 + color[2] * 0.11) > 180
        top, bottom = lerp(color, DARK, 0.72 if light else 0.45), DARK
        frame = color
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # the frame: the rarity color, a gold line inside it, the dark graphite card with a glow of the rarity color
    base.paste(Image.new("RGBA", (size, size), frame + (255,)), (0, 0), rounded_mask((size, size), 34))
    gold = Image.new("RGBA", (size - 12, size - 12), GOLD + (255,))
    base.paste(gold, (6, 6), rounded_mask((size - 12, size - 12), 29))
    card = gradient((size - 18, size - 18), top, bottom).convert("RGBA")
    glow = Image.new("L", card.size, 0)
    ImageDraw.Draw(glow).ellipse([card.size[0] * 0.1, card.size[1] * 0.02, card.size[0] * 0.9, card.size[1] * 0.75], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    tint = Image.new("RGBA", card.size, (frame if secret else color) + (255,))
    card = Image.composite(tint, card, glow)
    card.alpha_composite(sq, ((card.size[0] - inner) // 2, card.size[1] - inner))
    base.paste(card, (9, 9), rounded_mask(card.size, 26))
    return base


def art(cut, size=(340, 300)):
    box = cut.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    c = cut.crop(box) if box else cut
    scale = min((size[1] - 6) / c.size[1], (size[0] - 6) / c.size[0])
    c = c.resize((max(1, int(c.size[0] * scale)), max(1, int(c.size[1] * scale))), Image.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(c, ((size[0] - c.size[0]) // 2, size[1] - c.size[1]))
    return out


def main():
    manifest = json.load(open(sys.argv[1]))
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for tid, spec in manifest.items():
        color = hexc(spec["color"])
        bust = key_out(spec["bust"], spec.get("key", "green"))
        icon(bust, color).save(os.path.join(out_dir, tid + "_icon.png"))
        if spec.get("secret"):
            icon(bust, color, secret=True).save(os.path.join(out_dir, "secret_icon.png"))
        if spec.get("full"):
            art(key_out(spec["full"], spec.get("key", "green"))).save(os.path.join(out_dir, tid + "_art.png"))
        print("made", tid)


if __name__ == "__main__":
    main()
