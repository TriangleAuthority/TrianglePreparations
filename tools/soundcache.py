"""Read and write The Witcher 3 sound caches (soundspc.cache, magic CS3W).

  python tools/soundcache.py list <cache>
  python tools/soundcache.py extract <cache> <out_dir>
  python tools/soundcache.py pack <out.cache> <file> [<file> ...]

`pack` writes format version 2, the one 5.x's own content0\\soundspc.cache uses.
`list` and `extract` read versions 1 (legacy, e.g. legacy Ghost Mode's cache) and 2.

Version 2 layout (decoded from the 5.0 cache): a 64-byte header, the files back
to back from 0x40, then the names (NUL-terminated), then the file table
(u64 name offset, u64 data offset, u64 size per file).
Header: "CS3W", u32 version, u64 unknown (written as 0), u64 table offset,
u64 file count, u64 names offset, u64 names size, u64 buffer size (largest file
rounded up to 4 KiB), u64 checksum = FNV-1a 64 over the names followed by the table.
Version 1: a 48-byte header with u32 fields and a 12-byte table entry.
"""
import struct
import sys
from pathlib import Path

MAGIC = b"CS3W"


def fnv1a64(data: bytes) -> int:
    h = 0xCBF29CE484222325
    for c in data:
        h ^= c
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return h


def read_entries(path: Path) -> list[tuple[str, int, int]]:
    """(name, data offset, size) for every file in a version 1 or 2 cache."""
    with open(path, "rb") as f:
        head = f.read(0x40)
        if head[:4] != MAGIC:
            raise ValueError(f"{path}: not a sound cache")
        version = struct.unpack_from("<I", head, 4)[0]
        if version == 1:
            table, count, names, names_size = struct.unpack_from("<IIII", head, 0x10)
            fmt, entry = "<III", 12
        elif version == 2:
            table, count, names, names_size = struct.unpack_from("<QQQI", head, 0x10)
            fmt, entry = "<QQQ", 24
        else:
            raise ValueError(f"{path}: unknown version {version}")
        f.seek(names)
        name_blob = f.read(names_size)
        f.seek(table)
        rows = f.read(count * entry)
    out = []
    for i in range(count):
        name_off, off, size = struct.unpack_from(fmt, rows, i * entry)
        name = name_blob[name_off:name_blob.index(b"\0", name_off)].decode()
        out.append((name, off, size))
    return out


def pack(out: Path, files: list[Path]) -> None:
    data = bytearray(0x40)
    names = bytearray()
    table = bytearray()
    for p in files:
        blob = p.read_bytes()
        table += struct.pack("<QQQ", len(names), len(data), len(blob))
        names += p.name.encode() + b"\0"
        data += blob
    names_off = len(data)
    table_off = names_off + len(names)
    biggest = max(p.stat().st_size for p in files)
    buffer_size = (biggest + 0xFFF) & ~0xFFF
    header = MAGIC + struct.pack("<IQQQQQQQ", 2, 0, table_off, len(files), names_off, len(names),
                                 buffer_size, fnv1a64(bytes(names + table)))
    data[:0x40] = header
    out.write_bytes(bytes(data + names + table))


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "list":
        for name, off, size in read_entries(Path(argv[1])):
            print(f"{name}\t{off:#x}\t{size}")
        return 0
    if len(argv) == 3 and argv[0] == "extract":
        src, out_dir = Path(argv[1]), Path(argv[2])
        out_dir.mkdir(parents=True, exist_ok=True)
        with open(src, "rb") as f:
            for name, off, size in read_entries(src):
                f.seek(off)
                (out_dir / name).write_bytes(f.read(size))
        return 0
    if len(argv) >= 3 and argv[0] == "pack":
        pack(Path(argv[1]), [Path(a) for a in argv[2:]])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
