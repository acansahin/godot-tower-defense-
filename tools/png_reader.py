"""Minimal PNG reader: enough to get RGB pixels out of a 8-bit truecolour file."""
import struct
import zlib


class Png:
    def __init__(self, path):
        blob = open(path, "rb").read()
        assert blob[:8] == b"\x89PNG\r\n\x1a\n", "not a png"
        pos = 8
        idat = b""
        self.width = self.height = 0
        self.depth = self.colour = 0
        while pos < len(blob):
            length, kind = struct.unpack_from(">I4s", blob, pos)
            data = blob[pos + 8: pos + 8 + length]
            if kind == b"IHDR":
                (self.width, self.height, self.depth, self.colour,
                 _comp, _filt, _inter) = struct.unpack(">IIBBBBB", data)
            elif kind == b"IDAT":
                idat += data
            elif kind == b"IEND":
                break
            pos += 12 + length
        assert self.depth == 8, f"depth {self.depth} unsupported"
        channels = {0: 1, 2: 3, 4: 2, 6: 4}[self.colour]
        raw = zlib.decompress(idat)
        stride = self.width * channels
        out = bytearray(stride * self.height)
        prev = bytearray(stride)
        pos = 0
        for y in range(self.height):
            filt = raw[pos]
            pos += 1
            line = bytearray(raw[pos:pos + stride])
            pos += stride
            if filt == 1:
                for i in range(channels, stride):
                    line[i] = (line[i] + line[i - channels]) & 0xFF
            elif filt == 2:
                for i in range(stride):
                    line[i] = (line[i] + prev[i]) & 0xFF
            elif filt == 3:
                for i in range(stride):
                    left = line[i - channels] if i >= channels else 0
                    line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
            elif filt == 4:
                for i in range(stride):
                    a = line[i - channels] if i >= channels else 0
                    b = prev[i]
                    c = prev[i - channels] if i >= channels else 0
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                    line[i] = (line[i] + pred) & 0xFF
            out[y * stride:(y + 1) * stride] = line
            prev = line
        self.channels = channels
        self.pixels = bytes(out)

    def rgb(self, x, y):
        i = (y * self.width + x) * self.channels
        return self.pixels[i], self.pixels[i + 1], self.pixels[i + 2]
