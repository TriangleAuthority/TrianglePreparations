r"""Extract vanilla (unmodded) Witcher 3 files that are relevant to the mod.

Produces a tree that mirrors the mod layout:
    <out>/scripts/...   all vanilla .ws scripts (content/content0/scripts)
    <out>/files/...     every gameplay .xml/.csv from the game bundles (under
                        gameplay/ and game/, for the base game and each DLC),
                        plus every file (w2ent, journal, ...) present in
                        the mod's files folder (<MOD>/files, or --mod-files)

Bundles are read directly (their tables of contents are uncompressed) and
decompressed in pure Python by unbundle.py, for both legacy (1.32) and 5.x
bundles, so no REDkit is needed.

Files are written in the game's own encoding unless --utf8 is given, which
converts UTF-16/BOM text to plain UTF-8 (see to_utf8.py). The legacy baseline
was extracted with --utf8; 5.0 files are kept exactly as shipped.

Where a file exists in several bundles the one loaded last wins:
content0..contentN, then patch0, patch1, then DLC (DLC\<name>\content\bundles,
legacy only). In 5.x everything, the expansions and DLC included, is in
content0\bundles (duplicates are identical); 5.0's last separate DLC folder
(dlc\dlc20) went into dlc0.bundle with build 1090142, and dlc-tombstones\ holds
only empty marker files. The DLC data keeps its depot paths (dlc\<name>\...).

Usage:
    python tools/extract_vanilla.py <out_dir> [--utf8] [--game DIR] [--mod-files DIR]

The legacy game copy used for the legacy baseline is described in docs/tools.md.
"""
import argparse
import collections
import os
import re
import shutil
import struct
import sys

from paths import MOD, game_dir
from to_utf8 import convert_tree

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD_FILES = os.path.join(REPO, MOD, "files")

MAGIC = b"POTATO70"
LEGACY_ENTRY_SIZE = 0x140
V5_ENTRY_SIZE = 0x130
DATA_EXTS = {".xml", ".csv"}
# Gameplay data; skips editor/engine config, level layers, sound, QA, test and console files.
DATA_ROOT = re.compile(r"^(dlc\\[^\\]+\\data\\)?(gameplay|game)\\")

Entry = collections.namedtuple("Entry", "name raw bundle size zsize offset compression v5")


def natural_key(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def bundle_load_order(game):
    content = os.path.join(game, "content")
    dirs = sorted((d for d in os.listdir(content) if d.startswith("content")), key=natural_key)
    dirs += sorted((d for d in os.listdir(content) if d.startswith("patch")), key=natural_key)
    paths = [os.path.join(content, d, "bundles") for d in dirs]
    dlc = os.path.join(game, "DLC")
    if os.path.isdir(dlc):
        paths += [os.path.join(dlc, d, "content", "bundles") for d in sorted(os.listdir(dlc), key=natural_key)]
    for p in paths:
        if os.path.isdir(p):
            for b in sorted(os.listdir(p), key=natural_key):
                if b.endswith(".bundle"):
                    yield os.path.join(p, b)


def read_toc(path):
    with open(path, "rb") as f:
        header = f.read(0x20)
        if header[:8] != MAGIC:
            raise ValueError(f"{path}: not a bundle")
        toc_size = struct.unpack_from("<I", header, 16)[0]
        v5 = struct.unpack_from("<H", header, 20)[0] == 5
        toc = f.read(toc_size)
    entry_size = V5_ENTRY_SIZE if v5 else LEGACY_ENTRY_SIZE
    for i in range(0, toc_size - entry_size + 1, entry_size):
        raw = toc[i:i + entry_size]
        name = raw[:0x100].split(b"\0")[0].decode("latin-1")
        if v5:
            offset, size, zsize, _crc, compression = struct.unpack_from("<QIIII", raw, 0x110)
        else:
            size, zsize, offset = struct.unpack_from("<III", raw, 0x114)
            compression = struct.unpack_from("<I", raw, 0x13C)[0]
        yield Entry(name, raw, path, size, zsize, offset, compression, v5)


def extract(selected, files_out):
    import unbundle  # imported here: unbundle.py imports read_toc from this module

    handles = {}
    try:
        for e in selected.values():
            src = handles.get(e.bundle) or handles.setdefault(e.bundle, open(e.bundle, "rb"))
            data = unbundle.read_entry(src, e)
            dst = os.path.join(files_out, e.name)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(data)
    finally:
        for h in handles.values():
            h.close()


def mod_overridden_paths(mod_files=MOD_FILES):
    """Depot paths (lowercase, backslashes) of files under the mod's files folder."""
    wanted = set()
    for root, _, files in os.walk(mod_files):
        for fn in files:
            rel = os.path.relpath(os.path.join(root, fn), mod_files)
            wanted.add(rel.replace("/", "\\").lower())
    return wanted


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--utf8", action="store_true", help="convert UTF-16/BOM text files to plain UTF-8")
    ap.add_argument("--game", help="game install folder (default: W3_GAME_DIR or Steam's, see paths.py)")
    ap.add_argument("--mod-files", default=MOD_FILES,
                    help="folder whose files (at depot paths) are extracted too, whatever their type (default: <MOD>/files of this checkout)")
    args = ap.parse_args()
    args.game = args.game or str(game_dir())

    out = os.path.abspath(args.out)
    wanted = mod_overridden_paths(args.mod_files)

    selected = {}  # lowercase depot path -> Entry (last loaded wins)
    overridden = collections.Counter()
    for bundle in bundle_load_order(args.game):
        for e in read_toc(bundle):
            key = e.name.lower()
            if key in wanted or (os.path.splitext(key)[1] in DATA_EXTS and DATA_ROOT.match(key)):
                if key in selected:
                    overridden[os.path.relpath(bundle, args.game)] += 1
                selected[key] = e

    missing = sorted(wanted - selected.keys())
    print(f"selected {len(selected)} files from bundles")
    for b, n in overridden.items():
        print(f"  {n} earlier copies overridden by {b}")
    if missing:
        print(f"{len(missing)} files in {args.mod_files} do not exist in this game version:")
        for m in missing:
            print("   ", m)

    files_out = os.path.join(out, "files")
    scripts_out = os.path.join(out, "scripts")
    for d in (files_out, scripts_out):
        if os.path.exists(d):
            shutil.rmtree(d)

    extract(selected, files_out)

    shutil.copytree(os.path.join(args.game, "content", "content0", "scripts"), scripts_out)
    if args.utf8:
        print(f"converted {convert_tree(out)} text files to UTF-8")
    print(f"done: {out}")


if __name__ == "__main__":
    main()
