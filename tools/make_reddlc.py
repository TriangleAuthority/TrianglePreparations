r"""Write a DLC definition (.reddlc) file: a minimal CR2W writer.

A DLC mod needs a `dlc\<name>\<name>.reddlc` that lists its mounters, e.g. a
CR4DefinitionsDLCMounter that makes the game load the DLC's XML definitions (see
docs/development.md, "DLC and mounters"). REDkit can create one in its editor; this
script writes one from the command line instead.

The writer handles what DLC definitions use: objects (chunks) whose properties are
CName, String, Bool, or arrays of pointers to other chunks. It follows the layout of
the game's own files closely enough to rebuild vanilla .reddlc files byte for byte,
apart from the timestamp and build number in the header (`--selftest` checks this
against the REDkit depot).

Usage:
    python tools/make_reddlc.py <out.reddlc> --id dlc_ghostmode --xml dlc\dlcghostmode\data\gameplay\abilities\
        --xml-ngplus dlc\dlcghostmode\data\gameplay\abilities_plus\
    python tools/make_reddlc.py --selftest

--xml may be given several times; each becomes a CR4DefinitionsDLCMounter. --xml-ngplus
likewise becomes a CR4DefinitionsNGPlusDLCMounter, which loads New Game+ definitions (vanilla
DLCs mount their abilities_plus\ and items_plus\ folders this way). A path ending in a
backslash mounts every XML file in that folder.
"""
import argparse
import struct
import sys
import zlib
from pathlib import Path

from paths import redkit_dir

CR2W_VERSION = 164
HEADER_CRC_FILL = 0xDEADBEEF  # the header CRC is computed with this in its own field


def name_hash(s: str) -> int:
    """FNV-1a 32 over the name and its NUL terminator; 0 for the empty name."""
    if not s:
        return 0
    h = 0x811C9DC5
    for c in s.encode("latin-1") + b"\0":
        h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF
    return h


def encode_string(s: str) -> bytes:
    """CR2W String: length prefix (0x80 = 8-bit chars, 0x40 = more length bytes follow)."""
    data = s.encode("latin-1")
    n = len(data)
    if n < 0x40:
        return bytes([0x80 | n]) + data
    out = bytearray([0x80 | 0x40 | (n & 0x3F)])
    n >>= 6
    while True:
        byte = n & 0x7F
        n >>= 7
        out.append(byte | (0x80 if n else 0))
        if not n:
            break
    return bytes(out) + data


class Chunk:
    """One serialized object: class name, parent chunk (1-based, 0 = none), properties.

    Properties are (name, type, value): type "CName" (str), "String" (str), "Bool"
    (bool), or "array:2,0,ptr:<class>" (list of 1-based chunk numbers).
    """

    def __init__(self, cls, props, parent=0, flags=0):
        self.cls, self.props, self.parent, self.flags = cls, props, parent, flags


def write_cr2w(chunks: list[Chunk], timestamp: int = 0, build: int = 0) -> bytes:
    names: list[str] = [""]

    def name_index(s):
        if s not in names:
            names.append(s)
        return names.index(s)

    # Register names in the order the game's serializer does: depth-first, following
    # pointers into the chunks they point to.
    seen = set()

    def register(i):
        if i in seen:
            return
        seen.add(i)
        c = chunks[i - 1]
        name_index(c.cls)
        for pname, ptype, value in c.props:
            name_index(pname)
            name_index(ptype)
            if ptype == "CName":
                name_index(value)
            elif ptype.startswith("array:") and ",ptr:" in ptype:
                for target in value:
                    register(target)

    for i in range(1, len(chunks) + 1):
        register(i)

    def serialize(c):
        out = bytearray(b"\0")
        for pname, ptype, value in c.props:
            if ptype == "CName":
                v = struct.pack("<H", name_index(value))
            elif ptype == "String":
                v = encode_string(value)
            elif ptype == "Bool":
                v = struct.pack("<?", value)
            elif ptype.startswith("array:") and ",ptr:" in ptype:
                v = struct.pack("<I", len(value)) + b"".join(struct.pack("<i", t) for t in value)
            else:
                raise ValueError(f"unsupported property type {ptype}")
            out += struct.pack("<HHI", name_index(pname), name_index(ptype), 4 + len(v)) + v
        out += b"\0\0"
        return bytes(out)

    chunk_data = [serialize(c) for c in chunks]

    strings = bytearray()
    string_offsets = {}
    for n in names:
        string_offsets[n] = len(strings)
        strings += n.encode("latin-1") + b"\0"

    names_table = b"".join(struct.pack("<II", string_offsets[n], name_hash(n)) for n in names)
    props_table = bytes(16)  # one empty entry, as in the game's files

    off_strings = 160
    off_names = off_strings + len(strings)
    off_props = off_names + len(names_table)
    off_chunks = off_props + len(props_table)
    off_data = off_chunks + 24 * len(chunks)

    chunks_table = bytearray()
    pos = off_data
    for c, data in zip(chunks, chunk_data):
        chunks_table += struct.pack("<HHIIIII", name_index(c.cls), c.flags, c.parent, len(data), pos, 0,
                                    zlib.crc32(data))
        pos += len(data)
    file_size = pos

    tables = [
        (off_strings, len(strings), zlib.crc32(strings)),
        (off_names, len(names), zlib.crc32(names_table)),
        (0, 0, 0),
        (off_props, 1, zlib.crc32(props_table)),
        (off_chunks, len(chunks), zlib.crc32(chunks_table)),
    ] + [(0, 0, 0)] * 5

    header = bytearray(struct.pack("<4sIIQIIIII", b"CR2W", CR2W_VERSION, 0, timestamp, build,
                                   file_size, file_size, HEADER_CRC_FILL, 6))
    for t in tables:
        header += struct.pack("<III", *t)
    struct.pack_into("<I", header, 32, zlib.crc32(header))

    return bytes(header) + bytes(strings) + names_table + props_table + bytes(chunks_table) + b"".join(chunk_data)


def dlc_definition(dlc_id: str, xml_paths: list[str], ngplus_paths: list[str] = ()) -> list[Chunk]:
    mounters = [Chunk(cls, [("definitionXmlFilePath", "String", p)], parent=1, flags=8)
                for cls, paths in (("CR4DefinitionsDLCMounter", xml_paths),
                                   ("CR4DefinitionsNGPlusDLCMounter", ngplus_paths))
                for p in paths]
    root = Chunk("CDLCDefinition", [
        ("id", "CName", dlc_id),
        ("mounters", "array:2,0,ptr:IGameplayDLCMounter", list(range(2, 2 + len(mounters)))),
        ("visibleInDLCMenu", "Bool", False),
        ("requiredByGameSave", "Bool", False),
    ])
    return [root] + mounters


def selftest() -> None:
    """Rebuild vanilla dlc8.reddlc and compare, ignoring timestamp, build and header CRC."""
    path = redkit_dir() / "r4data" / "dlc" / "dlc8" / "dlc8.reddlc"
    vanilla = path.read_bytes()
    chunks = [
        Chunk("CDLCDefinition", [
            ("id", "CName", "dlc_008_001"),
            ("localizedNameKey", "String", "dlc_gwent_cards"),
            ("localizedDescriptionKey", "String", "dlc_gwent_cards_desc"),
            ("mounters", "array:2,0,ptr:IGameplayDLCMounter", [2]),
            ("initiallyEnabled", "Bool", False),
        ]),
        Chunk("CR4ScaleformContentDLCMounter",
              [("scaleformDirectoryPath", "String", "dlc\\dlc8\\data\\gameplay\\gui_new\\")], parent=1, flags=8),
    ]
    timestamp, build = struct.unpack_from("<QI", vanilla, 12)
    ours = write_cr2w(chunks, timestamp, build)
    if ours == vanilla:
        print(f"selftest OK: rebuilt {path.name} byte for byte ({len(ours)} bytes)")
        return
    diffs = [i for i in range(min(len(ours), len(vanilla))) if ours[i] != vanilla[i]]
    print(f"selftest FAILED: {len(ours)} vs {len(vanilla)} bytes, first differences at {diffs[:10]}")
    sys.exit(1)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", nargs="?", type=Path, help="output .reddlc file")
    ap.add_argument("--id", help="DLC id (a CName), e.g. dlc_ghostmode")
    ap.add_argument("--xml", action="append", default=[], help="definitions XML file or folder (depot path)")
    ap.add_argument("--xml-ngplus", action="append", default=[], help="New Game+ definitions XML file or folder (depot path)")
    ap.add_argument("--selftest", action="store_true", help="rebuild a vanilla .reddlc and compare")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return
    if not args.out or not args.id or not args.xml:
        ap.error("out, --id and at least one --xml are required")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(write_cr2w(dlc_definition(args.id, args.xml, args.xml_ngplus)))
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
