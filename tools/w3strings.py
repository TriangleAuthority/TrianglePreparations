r"""Encode and decode Witcher 3 string tables (.w3strings).

A mod's localized text (menu labels, descriptions, tutorials) ships as
`<lang>.w3strings` files in the mod's content folder. Scripts look strings up by
key (`GetLocStringByKeyExt("panel_ghost_mode")`) or by numeric id.

The source format is the CSV used by the community w3strings encoder (this repository:
`modPreparations/localization/<lang>.csv`):

    ;meta[language=en]
    ; id      |key(hex)|key(str)| text
    2110992001|        |panel_ghost_mode|Ghost Mode

Lines starting with ';' are comments (one must carry the language). Each row is
id|key hash in hex (optional; computed from key(str) when empty)|key|text; the text
may contain '|'.

The binary format: "RTSW", u32 version, u16 key1, then three blocks whose counts use
a variable-length int (6 bits in the first byte, then 7 bits per byte): string ids
(xor a per-language magic) with offsets and lengths, key hashes with ids, and the
text, each string obfuscated with a key derived from the language magic and its
length. A u16 key2 ends the file. key1/key2 and the magic depend on the language.
Version 164 (5.0) stores the text as UTF-8, with offsets, lengths and the text
block size in bytes and a 1-byte terminator per string; version 162 (legacy)
stored UTF-16 and counted in 16-bit units.

Usage:
    python tools/w3strings.py encode <in.csv> <out.w3strings> [--version 164]
    python tools/w3strings.py decode <in.w3strings> <out.csv>
    python tools/w3strings.py --selftest     # decode and re-encode the game's own string tables
"""
import argparse
import struct
import sys
from pathlib import Path

from paths import game_dir

VERSION = 164  # 5.0's string tables; legacy (1.32) used 162

# language: (key, magic). key1 = key >> 16 is written after the version, key2 = key & 0xffff
# ends the file.
LANGUAGES = {
    "pl": (0x83496237, 0x73946816), "en": (0x43975139, 0x79321793), "de": (0x75886138, 0x42791159),
    "it": (0x45931894, 0x12375973), "fr": (0x23863176, 0x75921975), "cz": (0x24987354, 0x21793217),
    "es": (0x18796651, 0x42387566), "zh": (0x18632176, 0x16875467), "ru": (0x63481486, 0x42386347),
    "hu": (0x42378932, 0x67823218), "jp": (0x54834893, 0x59825646),
    # Not obfuscated: key and magic 0, so the file does not say which language it is.
    "ar": (0, 0), "br": (0, 0), "cn": (0, 0), "esmx": (0, 0), "kr": (0, 0), "tr": (0, 0), "ua": (0, 0),
}


def utf16_units(text: str) -> list[int]:
    raw = text.encode("utf-16-le")
    return list(struct.unpack(f"<{len(raw) // 2}H", raw))


def key_hash(key: str) -> int:
    """Hash of a string key: h = h * 31 + unit over the lower-cased UTF-16 units."""
    h = 0
    for unit in utf16_units(key.lower()):
        h = (h * 31 + unit) & 0xFFFFFFFF
    return h


def write_varint(n: int) -> bytes:
    out = bytearray([n & 0x3F])
    n >>= 6
    if n:
        out[0] |= 0x40
    while n:
        b = n & 0x7F
        n >>= 7
        out.append(b | (0x80 if n else 0))
    return bytes(out)


def read_varint(d: bytes, pos: int) -> tuple[int, int]:
    b = d[pos]
    n, shift, pos = b & 0x3F, 6, pos + 1
    more = b & 0x40
    while more:
        b = d[pos]
        pos += 1
        n |= (b & 0x7F) << shift
        shift += 7
        more = b & 0x80
    return n, pos


def crypt(units: list[int], magic: int, mask: int) -> list[int]:
    """Obfuscate or deobfuscate one string (xor, so it is its own inverse).

    units are UTF-8 bytes (mask 0xFF, version 164) or UTF-16 code units (mask 0xFFFF,
    version 162). The 16-bit key rotates left by one bit per unit.
    """
    key = (magic >> 8) & 0xFFFF
    out = []
    for u in units:
        out.append(u ^ (((len(units) + 1) * key) & mask))
        key = ((key << 1) | (key >> 15)) & 0xFFFF
    return out


def language_of(key1: int, key2: int, hint: str | None) -> str:
    key = (key1 << 16) | key2
    if key == 0:
        if hint and LANGUAGES.get(hint, (1,))[0] == 0:
            return hint
        raise ValueError("unobfuscated file: pass the language (e.g. from the file name)")
    for lang, (k, _) in LANGUAGES.items():
        if k == key:
            return lang
    raise ValueError(f"unknown language key {key:#010x}")


def decode(data: bytes, lang_hint: str | None = None) -> tuple[str, int, list[tuple[int, str]], list[tuple[int, int]]]:
    """Return (language, version, strings, keys).

    strings: [(id, text)] in the order the texts are stored; keys: [(key hash, id)]
    (several keys may name the same id).
    """
    if data[:4] != b"RTSW":
        raise ValueError("not a .w3strings file")
    version, key1 = struct.unpack_from("<IH", data, 4)
    (key2,) = struct.unpack_from("<H", data, len(data) - 2)
    lang = language_of(key1, key2, lang_hint)
    magic = LANGUAGES[lang][1]
    utf8 = version >= 164

    count, pos = read_varint(data, 10)
    ids = []
    for _ in range(count):
        sid, off, length = struct.unpack_from("<III", data, pos)
        ids.append((off, sid ^ magic, length))
        pos += 12
    count, pos = read_varint(data, pos)
    keys = []
    for _ in range(count):
        h, sid = struct.unpack_from("<II", data, pos)
        keys.append((h, sid ^ magic))
        pos += 8
    _size, pos = read_varint(data, pos)

    strings = []
    for off, sid, length in sorted(ids):
        if utf8:
            # surrogateescape keeps malformed UTF-8 (a few vanilla Arabic strings) intact
            text = bytes(crypt(list(data[pos + off:pos + off + length]), magic, 0xFF)).decode("utf-8", "surrogateescape")
        else:
            units = crypt(list(struct.unpack_from(f"<{length}H", data, pos + 2 * off)), magic, 0xFFFF)
            text = struct.pack(f"<{length}H", *units).decode("utf-16-le")
        strings.append((sid, text))
    return lang, version, strings, keys


def encode(lang: str, strings: list[tuple[int, str]], keys: list[tuple[int, int]], version: int = VERSION) -> bytes:
    """strings: [(id, text)], stored in the order given; keys: [(key hash, id)]."""
    key, magic = LANGUAGES[lang]
    utf8 = version >= 164
    unit_size = 1 if utf8 else 2
    texts = bytearray()
    entries = []
    for sid, text in strings:
        if utf8:
            units = crypt(list(text.encode("utf-8", "surrogateescape")), magic, 0xFF)
            coded = bytes(units) + b"\x00"
        else:
            units = crypt(utf16_units(text), magic, 0xFFFF)
            coded = struct.pack(f"<{len(units)}H", *units) + b"\x00\x00"
        entries.append((sid ^ magic, len(texts) // unit_size, len(units)))
        texts += coded
    # Like the game's files: the id table sorted by obfuscated id, the key table by hash.
    id_table = b"".join(struct.pack("<III", *e) for e in sorted(entries))
    key_table = b"".join(struct.pack("<II", h, sid ^ magic) for h, sid in sorted(keys, key=lambda k: k[0]))
    return (b"RTSW" + struct.pack("<IH", version, key >> 16)
            + write_varint(len(entries)) + id_table
            + write_varint(len(keys)) + key_table
            + write_varint(len(texts) // unit_size) + bytes(texts)
            + struct.pack("<H", key & 0xFFFF))


def read_csv(path: Path) -> tuple[str, list[tuple[int, str]], list[tuple[int, int]]]:
    """Read the community CSV format; a row repeating an id adds another key for it."""
    lang = None
    strings, keys, seen = [], [], set()
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith(";"):
            if "meta[language=" in line:
                lang = line.split("meta[language=", 1)[1].split("]", 1)[0].strip().lower()
            continue
        if not line.strip():
            continue
        sid, khex, key, text = line.split("|", 3)
        sid = int(sid)
        if sid not in seen:
            seen.add(sid)
            strings.append((sid, text))
        h = int(khex, 16) if khex.strip() else (key_hash(key.strip()) if key.strip() else 0)
        if h:
            keys.append((h, sid))
    if lang not in LANGUAGES:
        raise ValueError(f"{path}: missing or unknown ';meta[language=..]' line")
    return lang, strings, keys


def write_csv(path: Path, lang: str, strings: list[tuple[int, str]], keys: list[tuple[int, int]]) -> None:
    """Write the community CSV format. Key names are not stored in .w3strings, only their hashes."""
    by_id = {}
    for h, sid in keys:
        by_id.setdefault(sid, []).append(h)
    lines = [f";meta[language={lang}]", "; id      |key(hex)|key(str)| text"]
    for sid, text in strings:
        for h in by_id.get(sid, [0]):
            lines.append(f"{sid}|{h:08x}||{text}" if h else f"{sid}|        ||{text}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def selftest() -> None:
    """Decode the game's own string tables and re-encode them; they must match byte for byte."""
    failed = False
    for f in sorted((game_dir() / "content" / "content0").glob("*.w3strings")):
        data = f.read_bytes()
        try:
            lang, version, strings, keys = decode(data, f.stem.lower())
        except ValueError as e:
            print(f"  {f.name}: skipped ({e})")
            continue
        ok = encode(lang, strings, keys, version) == data
        failed |= not ok
        sample = next((t for _, t in strings if t.strip()), "")[:40]
        print(f"  {f.name}: {len(strings)} strings, {len(keys)} keys, version {version}, "
              f"{'OK' if ok else 'MISMATCH'}  e.g. {ascii(sample)}")
    if failed:
        print("selftest FAILED")
        sys.exit(1)
    print("selftest OK")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", nargs="?", choices=["encode", "decode"])
    ap.add_argument("input", nargs="?", type=Path)
    ap.add_argument("output", nargs="?", type=Path)
    ap.add_argument("--version", type=int, default=VERSION, help=f"format version to write (default {VERSION})")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        selftest()
    elif args.command == "encode" and args.input and args.output:
        lang, strings, keys = read_csv(args.input)
        args.output.write_bytes(encode(lang, strings, keys, args.version))
        print(f"wrote {args.output} ({lang}, {len(strings)} strings, {len(keys)} keys)")
    elif args.command == "decode" and args.input and args.output:
        lang, version, strings, keys = decode(args.input.read_bytes(), args.input.stem.lower())
        write_csv(args.output, lang, strings, keys)
        print(f"wrote {args.output} ({lang}, version {version}, {len(strings)} strings, {len(keys)} keys)")
    else:
        ap.error("give encode|decode with input and output, or --selftest")


if __name__ == "__main__":
    main()
