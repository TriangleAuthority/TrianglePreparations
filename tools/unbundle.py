r"""Extract every file from Witcher 3 .bundle files, in pure Python.

Reads legacy (1.32) and 5.x bundles, including mod bundles such as a packed
mod's content\blob0.bundle. Supports every compression the game uses: stored,
zlib, Doboz (legacy game bundles) and LZ4/LZ4HC. (The REDkit wcc_lite updated
for 5.x no longer reads legacy bundles at all.)

Usage:
    python tools/unbundle.py <bundle-or-directory> <out_dir> [--list]
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_vanilla import read_toc  # noqa: E402

STORED, ZLIB, SNAPPY, DOBOZ, LZ4, LZ4HC = 0, 1, 2, 3, 4, 5

# Doboz match encodings, indexed by the low 3 bits of the match word:
# (mask, offset shift, length mask, length shift, encoded size in bytes)
DOBOZ_MATCH = [
    (0xFF, 2, 0, 0, 1),
    (0xFFFF, 2, 0, 0, 2),
    (0xFFFF, 6, 15, 2, 2),
    (0xFFFFFF, 8, 31, 3, 3),
    (0xFF, 2, 0, 0, 1),
    (0xFFFF, 2, 0, 0, 2),
    (0xFFFF, 6, 15, 2, 2),
    (0xFFFFFFFF, 11, 255, 3, 4),
]
DOBOZ_MIN_MATCH = 3


def doboz(src, size):
    """Decompress a Doboz buffer (header + data), as written by the Doboz library."""
    attributes = src[0]
    version, size_bytes, stored = attributes & 7, ((attributes >> 3) & 7) + 1, attributes & 0x80
    if version != 0:
        raise ValueError(f"Doboz: unsupported version {version}")
    out_size = int.from_bytes(src[1:1 + size_bytes], "little")
    i = 1 + 2 * size_bytes  # header: attributes, uncompressed size, compressed size
    if stored:
        data = bytes(src[i:i + out_size])
    else:
        src = bytes(src) + b"\0" * 4  # the decoder reads whole 32-bit words
        dst = bytearray()
        control = 1
        while len(dst) < out_size:
            if control == 1:  # only the sentinel bit is left: fetch the next control word
                control = struct.unpack_from("<I", src, i)[0]
                i += 4
            if control & 1 == 0:  # literal byte
                dst.append(src[i])
                i += 1
            else:  # match
                word = struct.unpack_from("<I", src, i)[0]
                mask, off_shift, len_mask, len_shift, enc = DOBOZ_MATCH[word & 7]
                offset = (word & mask) >> off_shift
                length = ((word >> len_shift) & len_mask) + DOBOZ_MIN_MATCH
                i += enc
                start = len(dst) - offset
                if offset >= length:
                    dst += dst[start:start + length]
                else:  # overlapping copy repeats the last `offset` bytes
                    pattern = bytes(dst[start:])
                    dst += (pattern * (length // offset + 1))[:length]
            control >>= 1
        data = bytes(dst[:out_size])
    if len(data) != size:
        raise ValueError(f"Doboz: got {len(data)} bytes, expected {size}")
    return data


def lz4_block(src, size):
    """Decompress one raw LZ4 block (no frame header)."""
    dst = bytearray()
    i, n = 0, len(src)
    while i < n:
        token = src[i]
        i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        dst += src[i:i + lit]
        i += lit
        if i >= n:
            break
        offset = src[i] | (src[i + 1] << 8)
        i += 2
        match = token & 15
        if match == 15:
            while True:
                b = src[i]
                i += 1
                match += b
                if b != 255:
                    break
        match += 4
        start = len(dst) - offset
        if offset >= match:
            dst += dst[start:start + match]
        else:  # overlapping copy repeats the last `offset` bytes
            pattern = bytes(dst[start:])
            dst += (pattern * (match // offset + 1))[:match]
    if len(dst) != size:
        raise ValueError(f"LZ4: got {len(dst)} bytes, expected {size}")
    return bytes(dst)


def read_entry(f, e):
    f.seek(e.offset)
    data = f.read(e.zsize)
    if e.compression == STORED:
        pass
    elif e.compression == ZLIB:
        data = zlib.decompress(data)
    elif e.compression == DOBOZ:
        data = doboz(data, e.size)
    elif e.compression in (LZ4, LZ4HC):
        data = lz4_block(data, e.size)
    else:
        raise ValueError(f"{e.name}: unsupported compression {e.compression}")
    if len(data) != e.size:
        raise ValueError(f"{e.name}: size mismatch")
    return data


def bundles(path):
    if os.path.isfile(path):
        return [path]
    return sorted(os.path.join(r, f) for r, _, fs in os.walk(path) for f in fs if f.endswith(".bundle"))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit(__doc__)
    src, out = args
    count = 0
    for b in bundles(src):
        entries = list(read_toc(b))
        with open(b, "rb") as f:
            for e in entries:
                if "--list" in sys.argv:
                    print(f"{e.name}\t{e.size}\t{e.compression}")
                    continue
                dst = os.path.join(out, e.name)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with open(dst, "wb") as o:
                    o.write(read_entry(f, e))
                count += 1
    if "--list" not in sys.argv:
        print(f"extracted {count} files to {out}")


if __name__ == "__main__":
    main()
