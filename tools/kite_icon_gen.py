#!/usr/bin/env python3
"""Refund Radar — Patang (kite) launcher icon generator.

Pure-Python SDF rasterizer (no PIL/numpy needed): renders the Makar
Sankranti kite + ₹ design into crisp PNGs at every Android density.
"""
import zlib, struct, math, os, sys

SQRT2 = math.sqrt(2.0)
COS45 = math.cos(math.radians(45))
SIN45 = math.sin(math.radians(45))

def hex2rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

SKY_TOP  = hex2rgb('#d9f2ff')
SKY_BOT  = hex2rgb('#7cc4ef')
GOLD     = hex2rgb('#f59e0b')
CRIMSON  = hex2rgb('#d92b2b')
NAVY     = hex2rgb('#0f2f57')
WHITE    = (255, 255, 255)
BOW_GOLD = hex2rgb('#ffd54f')
BOW_EDGE = hex2rgb('#d97706')

def smooth01(x):
    t = 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)
    return t * t * (3.0 - 2.0 * t)

def sd_seg(px, py, ax, ay, bx, by):
    vx = bx - ax; vy = by - ay
    wx = px - ax; wy = py - ay
    c1 = vx * vx + vy * vy
    t = 0.0 if c1 == 0.0 else (wx * vx + wy * vy) / c1
    if t < 0.0: t = 0.0
    elif t > 1.0: t = 1.0
    dx = wx - t * vx; dy = wy - t * vy
    return math.sqrt(dx * dx + dy * dy)

def quad_pts(p0, c, p1, n=48):
    pts = []
    for i in range(n + 1):
        t = i / n; mt = 1.0 - t
        pts.append((mt*mt*p0[0] + 2*mt*t*c[0] + t*t*p1[0],
                    mt*mt*p0[1] + 2*mt*t*c[1] + t*t*p1[1]))
    return pts

def cubic_pts(p0, c1, c2, p1, n=72):
    pts = []
    for i in range(n + 1):
        t = i / n; mt = 1.0 - t
        a = mt*mt*mt; b = 3*mt*mt*t; cc = 3*mt*t*t; d = t*t*t
        pts.append((a*p0[0] + b*c1[0] + cc*c2[0] + d*p1[0],
                    a*p0[1] + b*c1[1] + cc*c2[1] + d*p1[1]))
    return pts

def cubic_pos(p0, c1, c2, p1, t):
    mt = 1.0 - t
    a = mt*mt*mt; b = 3*mt*mt*t; cc = 3*mt*t*t; d = t*t*t
    return (a*p0[0] + b*c1[0] + cc*c2[0] + d*p1[0],
            a*p0[1] + b*c1[1] + cc*c2[1] + d*p1[1])

def sd_poly(px, py, pts):
    best = 1e9
    x0, y0 = pts[0]
    for i in range(1, len(pts)):
        x1, y1 = pts[i]
        d = sd_seg(px, py, x0, y0, x1, y1)
        if d < best: best = d
        x0, y0 = x1, y1
    return best

def sd_rrect(dx, dy, hw, hh, r):
    qx = abs(dx) - (hw - r); qy = abs(dy) - (hh - r)
    ax = qx if qx > 0.0 else 0.0
    ay = qy if qy > 0.0 else 0.0
    outer = math.sqrt(ax * ax + ay * ay)
    inner = qx if qx > qy else qy
    if inner > 0.0: inner = 0.0
    return outer + inner - r

# ---------------------------------------------------------------- design ----
# All coordinates normalised (0..1 of canvas). y grows downward.
LEGACY = dict(
    mask=True, gradient=True,
    kcx=0.36, kcy=0.31, a=0.145, kr=0.045, kbw=0.030,
    J=(0.74, 0.60),
    tail=((0.74, 0.60), (0.62, 0.78), (0.94, 0.86), (0.80, 1.04)),
    tail_w=0.014, str_w=0.010,
    bow_ts=(0.32, 0.56, 0.78), bow_r=0.030,
)
FOREGROUND = dict(   # adaptive-icon foreground: keep inside safe zone
    mask=False, gradient=False,
    kcx=0.44, kcy=0.40, a=0.115, kr=0.036, kbw=0.026,
    J=(0.66, 0.62),
    tail=((0.66, 0.62), (0.55, 0.76), (0.75, 0.80), (0.60, 0.80)),
    tail_w=0.013, str_w=0.009,
    bow_ts=(0.35, 0.62, 0.85), bow_r=0.028,
)

def build_geometry(cfg):
    """Precompute polylines once in normalised coords."""
    kcx, kcy, a = cfg['kcx'], cfg['kcy'], cfg['a']
    # kite corners (square rotated 45 deg)
    B = (kcx, kcy + a * SQRT2)
    R = (kcx + a * SQRT2, kcy)
    J = cfg['J']
    tail_pts = cubic_pts(*cfg['tail'])
    # bows positions along tail
    bows = [cubic_pos(*cfg['tail'], t) for t in cfg['bow_ts']]
    # rupee strokes in kite-LOCAL coords (units of a, y down)
    bar1 = [(-0.45 * a, -0.34 * a), (0.45 * a, -0.34 * a)]
    bar2 = [(-0.45 * a, -0.12 * a), (0.45 * a, -0.12 * a)]
    bowl = quad_pts((-0.45 * a, -0.34 * a), (0.85 * a, -0.30 * a),
                    (-0.05 * a, 0.18 * a))
    leg = [(-0.05 * a, 0.18 * a), (0.40 * a, 0.55 * a)]
    rupee_w = 0.075 * a
    # bounding boxes (normalised) for cheap rejection
    def bbox_of(pts, pad):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        return (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
    tail_bb = bbox_of(tail_pts, cfg['tail_w'] + 0.06)
    kite_bb = (kcx - a * SQRT2 - 0.01, kcy - a * SQRT2 - 0.01,
               kcx + a * SQRT2 + 0.01, kcy + a * SQRT2 + 0.01)
    str_bb = (min(B[0], R[0], J[0]) - 0.02, min(B[1], R[1], J[1]) - 0.02,
              max(B[0], R[0], J[0]) + 0.02, max(B[1], R[1], J[1]) + 0.02)
    return dict(B=B, R=R, J=J, tail=tail_pts, bows=bows,
                rupee=[bar1, bar2, bowl, leg], rupee_w=rupee_w,
                tail_bb=tail_bb, kite_bb=kite_bb, str_bb=str_bb)

def render(S, cfg, geo):
    aa = 1.4 / S
    kcx, kcy, a = cfg['kcx'], cfg['kcy'], cfg['a']
    kr, kbw = cfg['kr'], cfg['kbw']
    tail_w, str_w = cfg['tail_w'], cfg['str_w']
    bow_r = cfg['bow_r']
    B, R, J = geo['B'], geo['R'], geo['J']
    tail_pts, bows = geo['tail'], geo['bows']
    rupee, rupee_w = geo['rupee'], geo['rupee_w']
    tail_bb, kite_bb, str_bb = geo['tail_bb'], geo['kite_bb'], geo['str_bb']
    sqrt = math.sqrt

    buf = bytearray()
    for y in range(S):
        v = (y + 0.5) / S
        buf.append(0)  # PNG filter byte
        for x in range(S):
            u = (x + 0.5) / S
            # premultiplied accumulator
            Cr = Cg = Cb = A = 0.0

            # 1. background gradient
            if cfg['gradient']:
                t = v
                br = SKY_TOP[0] + (SKY_BOT[0] - SKY_TOP[0]) * t
                bg_ = SKY_TOP[1] + (SKY_BOT[1] - SKY_TOP[1]) * t
                bb = SKY_TOP[2] + (SKY_BOT[2] - SKY_TOP[2]) * t
                Cr, Cg, Cb, A = br, bg_, bb, 1.0

            def paint(col, d, w):
                nonlocal Cr, Cg, Cb, A
                cov = 1.0 - smooth01((d - w) / (aa * 2.0) + 0.5)
                if cov <= 0.0: return
                ia = 1.0 - cov
                Cr = col[0] * cov + Cr * ia
                Cg = col[1] * cov + Cg * ia
                Cb = col[2] * cov + Cb * ia
                A = cov + A * ia

            # 2. strings (behind kite)
            if (str_bb[0] <= u <= str_bb[2] and str_bb[1] <= v <= str_bb[3]):
                d = min(sd_seg(u, v, B[0], B[1], J[0], J[1]),
                        sd_seg(u, v, R[0], R[1], J[0], J[1]))
                paint(NAVY, d, str_w * 0.5)

            # 3. tail
            if (tail_bb[0] <= u <= tail_bb[2] and tail_bb[1] <= v <= tail_bb[3]):
                d = sd_poly(u, v, tail_pts)
                paint(NAVY, d, tail_w * 0.5)
                # 4. bows (diamond: |du|+|dv| <= r)
                for bx_, by_ in bows:
                    dd = (abs(u - bx_) + abs(v - by_) - bow_r) * 0.7071
                    if dd < bow_r * 0.30:
                        paint(BOW_GOLD, dd, 0.004)
                    paint(BOW_EDGE, abs(dd) - 0.0, 0.006)

            # 5. kite body (rotated square) + border
            if (kite_bb[0] <= u <= kite_bb[2] and kite_bb[1] <= v <= kite_bb[3]):
                dx = u - kcx; dy = v - kcy
                lx = dx * COS45 + dy * SIN45
                ly = -dx * SIN45 + dy * COS45
                dk = sd_rrect(lx, ly, a, a, kr)
                kcov = 1.0 - smooth01(dk / (aa * 2.0) + 0.5)
                if kcov > 0.0:
                    # base: white fill with gold inner border
                    if dk > -kbw:
                        kcol = GOLD
                    else:
                        kcol = WHITE
                    # 6. rupee on top (local coords, tilted with kite)
                    dr = 1e9
                    for st in rupee:
                        dd = sd_poly(lx, ly, st)
                        if dd < dr: dr = dd
                    rcov = 1.0 - smooth01((dr - rupee_w * 0.5) / (aa * 2.0) + 0.5)
                    if rcov > 0.0:
                        kcol = (int(kcol[0] + (CRIMSON[0] - kcol[0]) * rcov),
                                int(kcol[1] + (CRIMSON[1] - kcol[1]) * rcov),
                                int(kcol[2] + (CRIMSON[2] - kcol[2]) * rcov))
                    ia = 1.0 - kcov
                    Cr = kcol[0] * kcov + Cr * ia
                    Cg = kcol[1] * kcov + Cg * ia
                    Cb = kcol[2] * kcov + Cb * ia
                    A = kcov + A * ia

            # 7. rounded-square icon mask
            if cfg['mask']:
                dm = sd_rrect(u - 0.5, v - 0.5, 0.5, 0.5, 0.225)
                mcov = 1.0 - smooth01(dm / (aa * 2.0) + 0.5)
                A *= mcov

            if A <= 0.003:
                buf += b'\x00\x00\x00\x00'
            else:
                buf += bytes((min(255, int(Cr / A + 0.5)),
                              min(255, int(Cg / A + 0.5)),
                              min(255, int(Cb / A + 0.5)),
                              min(255, int(A * 255 + 0.5))))
    return buf

def write_png(path, S, buf):
    def chunk(tag, data):
        c = tag + data
        return (struct.pack('>I', len(data)) + c +
                struct.pack('>I', zlib.crc32(c) & 0xffffffff))
    ihdr = struct.pack('>IIBBBBB', S, S, 8, 6, 0, 0, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(bytes(buf), 6)))
        f.write(chunk(b'IEND', b''))
    print('wrote', path, S, 'x', S, flush=True)

def main():
    res = 'android/app/src/main/res'
    geo_l = build_geometry(LEGACY)
    geo_f = build_geometry(FOREGROUND)
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96,
                 'xxhdpi': 144, 'xxxhdpi': 192}
    fg_sizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216,
                'xxhdpi': 324, 'xxxhdpi': 432}
    for d, s in densities.items():
        write_png(f'{res}/mipmap-{d}/ic_launcher.png', s, render(s, LEGACY, geo_l))
    for d, s in fg_sizes.items():
        write_png(f'{res}/mipmap-{d}/ic_launcher_foreground.png', s,
                  render(s, FOREGROUND, geo_f))
    write_png('logos/kite-icon-512.png', 512, render(512, LEGACY, geo_l))
    print('ALL DONE', flush=True)

if __name__ == '__main__':
    main()
