# small numpy rasterizer: orthographic view, Gouraud-shaded (smooth normals by position), optional texture-density coloring
import numpy as np
from PIL import Image

def vertex_normals(pos, tris):
    # share normals between vertices at the same spot (UV seams)
    key = np.round(pos * 1e4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.ravel()
    fn = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
    acc = np.zeros((inv.max() + 1, 3))
    for k in range(3): np.add.at(acc, inv[tris[:, k]], fn)
    n = acc[inv]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    return n

def view_matrix(yaw_deg, pitch_deg):
    y, p = np.radians(yaw_deg), np.radians(pitch_deg)
    # camera looks along -forward; yaw 0 = looking at the FRONT (camera at -Z looking +Z)
    fwd = np.array([np.sin(y) * np.cos(p), -np.sin(p), np.cos(y) * np.cos(p)])  # direction camera looks
    up0 = np.array([0, 1.0, 0])
    right = np.cross(up0, fwd); right /= np.linalg.norm(right)
    up = np.cross(fwd, right)
    return right, up, fwd

def render(pos, tris, yaw=0, pitch=0, size=700, scale=None, center=None, colors=None, light=None, out=None):
    right, up, fwd = view_matrix(yaw, pitch)
    n = vertex_normals(pos, tris)
    if light is None: light = -fwd + up * 0.6 + right * 0.3
    light = light / np.linalg.norm(light)
    shade = np.clip(n @ light, 0, 1) * 0.75 + 0.25
    spec = np.clip(n @ (light - fwd) / np.linalg.norm(light - fwd), 0, 1) ** 40 * 0.35
    base = np.ones((len(pos), 3)) * np.array([0.85, 0.66, 0.5]) if colors is None else colors
    vcol = np.clip(base * shade[:, None] + spec[:, None], 0, 1)
    sx, sy, sz = pos @ right, pos @ up, pos @ fwd
    if center is None: center = np.array([(sx.min() + sx.max()) / 2, (sy.min() + sy.max()) / 2])
    if scale is None: scale = 0.9 * size / max(sx.max() - sx.min(), sy.max() - sy.min())
    px = (sx - center[0]) * scale + size / 2
    py = size / 2 - (sy - center[1]) * scale
    img = np.full((size, size, 3), 0.12); zb = np.full((size, size), np.inf)
    for a, b, c in tris:
        # back-face cull (camera looks along +fwd: visible if normal points toward -fwd)
        e1 = np.array([px[b] - px[a], py[b] - py[a]]); e2 = np.array([px[c] - px[a], py[c] - py[a]])
        den = e1[0] * e2[1] - e1[1] * e2[0]
        if abs(den) < 1e-9: continue
        x0 = int(max(min(px[a], px[b], px[c]), 0)); x1 = int(min(max(px[a], px[b], px[c]) + 1, size - 1))
        y0 = int(max(min(py[a], py[b], py[c]), 0)); y1 = int(min(max(py[a], py[b], py[c]) + 1, size - 1))
        if x1 < x0 or y1 < y0: continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        dx, dy = X - px[a], Y - py[a]
        w1 = (dx * e2[1] - dy * e2[0]) / den
        w2 = (e1[0] * dy - e1[1] * dx) / den
        w0 = 1 - w1 - w2
        m = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not m.any(): continue
        z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        m &= z < sub
        if not m.any(): continue
        sub[m] = z[m]
        col = w0[..., None] * vcol[a] + w1[..., None] * vcol[b] + w2[..., None] * vcol[c]
        img[y0:y1 + 1, x0:x1 + 1][m] = col[m]
    im = Image.fromarray((img * 255).astype(np.uint8))
    if out: im.save(out)
    return im, (center, scale)

def grid(images, cols, out):
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows))
    for i, im in enumerate(images): sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(out)


def render_uv(pos, tris, face_uv, yaw=0, pitch=0, size=500, scale=None, center=None, tex=None, out=None):
    # like render, but each pixel takes a texture lookup from per-corner uv (face_uv: (T, 3, 2), in 0..1)
    right, up, fwd = view_matrix(yaw, pitch)
    n = vertex_normals(pos, tris)
    light = -fwd + up * 0.6 + right * 0.3; light /= np.linalg.norm(light)
    shade = np.clip(n @ light, 0, 1) * 0.7 + 0.3
    sx, sy, sz = pos @ right, pos @ up, pos @ fwd
    if center is None: center = np.array([(sx.min() + sx.max()) / 2, (sy.min() + sy.max()) / 2])
    if scale is None: scale = 0.9 * size / max(sx.max() - sx.min(), sy.max() - sy.min())
    px = (sx - center[0]) * scale + size / 2; py = size / 2 - (sy - center[1]) * scale
    img = np.full((size, size, 3), 0.12); zb = np.full((size, size), np.inf)
    th, tw = tex.shape[:2]
    for k, (a, b, c) in enumerate(tris):
        e1 = np.array([px[b] - px[a], py[b] - py[a]]); e2 = np.array([px[c] - px[a], py[c] - py[a]])
        den = e1[0] * e2[1] - e1[1] * e2[0]
        if abs(den) < 1e-9: continue
        x0 = int(max(min(px[a], px[b], px[c]), 0)); x1 = int(min(max(px[a], px[b], px[c]) + 1, size - 1))
        y0 = int(max(min(py[a], py[b], py[c]), 0)); y1 = int(min(max(py[a], py[b], py[c]) + 1, size - 1))
        if x1 < x0 or y1 < y0: continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        dx, dy = X - px[a], Y - py[a]
        w1 = (dx * e2[1] - dy * e2[0]) / den; w2 = (e1[0] * dy - e1[1] * dx) / den; w0 = 1 - w1 - w2
        msk = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not msk.any(): continue
        z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
        sub = zb[y0:y1 + 1, x0:x1 + 1]; msk &= z < sub
        if not msk.any(): continue
        sub[msk] = z[msk]
        uv = w0[..., None] * face_uv[k, 0] + w1[..., None] * face_uv[k, 1] + w2[..., None] * face_uv[k, 2]
        tx = np.clip((uv[..., 0] * tw).astype(int), 0, tw - 1); ty = np.clip((uv[..., 1] * th).astype(int), 0, th - 1)
        s = w0 * shade[a] + w1 * shade[b] + w2 * shade[c]
        col = tex[ty, tx] * s[..., None]
        img[y0:y1 + 1, x0:x1 + 1][msk] = col[msk]
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    if out: im.save(out)
    return im

def checker(w=585, h=559, cell=8):
    y, x = np.mgrid[0:h, 0:w]
    c = ((x // cell + y // cell) % 2).astype(float)
    tex = np.stack([0.55 + 0.4 * c, 0.5 + 0.3 * c, 0.45 + 0.2 * c], -1)
    tex[(x % 64 == 0) | (y % 64 == 0)] = (0.9, 0.2, 0.2)
    return tex
