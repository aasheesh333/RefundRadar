#!/usr/bin/env python3
"""Pure-Python RGBA PNG resizer (box-filter downscale, premultiplied alpha)."""
import zlib, struct, sys

def read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    pos, idat, w, h = 8, b'', None, None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos+4])[0]
        tag = data[pos+4:pos+8]
        if tag == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', data[pos+8:pos+18])
            assert depth == 8 and ctype == 6, 'need RGBA8'
        elif tag == b'IDAT':
            idat += data[pos+8:pos+8+ln]
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    px = bytearray(w * h * 4)
    prev = bytearray(stride)
    off = 0
    for y in range(h):
        filt = raw[off]; off += 1
        line = bytearray(raw[off:off+stride]); off += stride
        if filt == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i-4]) & 255
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif filt == 3:
            for i in range(stride):
                a = line[i-4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif filt == 4:
            for i in range(stride):
                a = line[i-4] if i >= 4 else 0
                b = prev[i]
                c = prev[i-4] if i >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        px[y*stride:(y+1)*stride] = line
        prev = line
    return w, h, px

def write_png(path, w, h, px):
    stride = w * 4
    rows = []
    for y in range(h):
        rows.append(b'\x00' + bytes(px[y*stride:(y+1)*stride]))
    raw = b''.join(rows)
    comp = zlib.compress(raw, 6)
    def chunk(tag, payload):
        c = struct.pack('>I', len(payload)) + tag + payload
        return c + struct.pack('>I', zlib.crc32(tag + payload) & 0xffffffff)
    out = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBB', w, h, 8, 6) + b'\x00\x00\x00')
           + chunk(b'IDAT', comp)
           + chunk(b'IEND', b''))
    open(path, 'wb').write(out)

def resize_box(w, h, px, nw, nh):
    """Box-filter downscale with premultiplied alpha (crisp, no halos)."""
    out = bytearray(nw * nh * 4)
    xscale = w / nw
    yscale = h / nh
    for oy in range(nh):
        y0 = oy * yscale
        y1 = y0 + yscale
        iy0 = int(y0)
        iy1 = min(int(y1) + (1 if y1 % 1 else 0), h)
        for ox in range(nw):
            x0 = ox * xscale
            x1 = x0 + xscale
            ix0 = int(x0)
            ix1 = min(int(x1) + (1 if x1 % 1 else 0), w)
            r = g = b = a = 0.0
            tot = 0.0
            for sy in range(iy0, iy1):
                wy = min(sy + 1, y1) - max(sy, y0)
                if wy <= 0:
                    continue
                rowbase = sy * w * 4
                for sx in range(ix0, ix1):
                    wx = min(sx + 1, x1) - max(sx, x0)
                    if wx <= 0:
                        continue
                    wgt = wx * wy
                    idx = rowbase + sx * 4
                    pa = px[idx+3] / 255.0
                    r += px[idx]   * pa * wgt
                    g += px[idx+1] * pa * wgt
                    b += px[idx+2] * pa * wgt
                    a += px[idx+3] * wgt
                    tot += wgt
            oidx = (oy * nw + ox) * 4
            if a > 0.5:
                sa = a / 255.0
                out[oidx]   = int(r / sa / tot / 255.0 * 255.0 + 0.5) if False else min(255, int(r * 255.0 / a + 0.5))
                out[oidx+1] = min(255, int(g * 255.0 / a + 0.5))
                out[oidx+2] = min(255, int(b * 255.0 / a + 0.5))
                out[oidx+3] = min(255, int(a / tot + 0.5))
            else:
                out[oidx:oidx+4] = b'\x00\x00\x00\x00'
    return out

if __name__ == '__main__':
    src, dst, ns = sys.argv[1], sys.argv[2], int(sys.argv[3])
    w, h, px = read_png(src)
    out = resize_box(w, h, px, ns, ns)
    write_png(dst, ns, ns, out)
    print(f'{dst}: {w}x{h} -> {ns}x{ns}')
