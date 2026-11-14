r"""Property-level diff of binary (CR2W) game files between two git refs.

For every .w2ent/.journal/.w2scene/.w2phase/.w2beh/.w2behtree/.w2comm file
under the mod folder (paths.MOD) that differs between BASE and OTHER, prints the property
values removed (-) and added (+). Re-save noise is filtered out by default:
the CR2W version number, cooked effect buffers, regenerated proxy GUIDs and
the duplicate copy of each object inside flatCompiledData.

Examples:
    # What the legacy mod changed in its binary files
    python tools/bindiff.py vanilla-1.32 legacy-PREP
    # What CDPR changed in the same files for 5.x
    python tools/bindiff.py vanilla-1.32 vanilla-5.x
    # One file or folder, and a per-property summary
    python tools/bindiff.py vanilla-1.32 legacy-PREP modPreparations/files --summary

Usage:
    python tools/bindiff.py BASE OTHER [PATH_PREFIX ...] [--summary] [--keep-noise]
"""
import collections
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cr2w_dump  # noqa: E402
from paths import MOD  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BINARY_EXTS = (".w2ent", ".journal", ".w2scene", ".w2phase", ".w2beh", ".w2behtree", ".w2comm")
NOISE = re.compile(r"^(CR2W version|.*cookedEffects\.buffer|.*attachmentReplacements|"
                   r".*flatCompiledData = <embedded|.*streamingDataBuffer|.*\.guid = |.*<\+\d+ bytes after)")


def git(*args):
    return subprocess.check_output(["git", "-C", REPO, *args])


def tree(rev):
    files = {}
    for line in git("ls-tree", "-r", "-z", rev, "--", MOD).split(b"\0"):
        if line:
            meta, path = line.split(b"\t", 1)
            files[path.decode()] = meta.split()[2].decode()
    return files


def facts(blob, keep_noise):
    lines = cr2w_dump.dump_file(blob)
    header, body = lines[:1], lines[1:]
    out = [f"CR2W version = {header[0].split()[-1]}"] if keep_noise else []
    for fact in cr2w_dump.flatten(body):
        fact = fact.replace("CEntityTemplate/flatCompiledData/", "")
        if keep_noise or not NOISE.match(fact):
            out.append(fact)
    return collections.Counter(out)


def diff_file(base_blob, other_blob, keep_noise):
    a, b = facts(base_blob, keep_noise), facts(other_blob, keep_noise)
    removed, added = a - b, b - a
    changes = [("-", f) for f in sorted(set(removed.elements()))] + [("+", f) for f in sorted(set(added.elements()))]
    return changes


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) < 2:
        sys.exit(__doc__)
    base_rev, other_rev, prefixes = args[0], args[1], args[2:]
    keep_noise = "--keep-noise" in flags
    base, other = tree(base_rev), tree(other_rev)

    def wanted(p):
        return p.endswith(BINARY_EXTS) and (not prefixes or any(p.startswith(x) for x in prefixes))

    changed = sorted(p for p in other if wanted(p) and p in base and base[p] != other[p])
    added = sorted(p for p in other if wanted(p) and p not in base)
    deleted = sorted(p for p in base if wanted(p) and p not in other)

    summary = collections.Counter()
    for p in changed:
        try:
            changes = diff_file(git("cat-file", "blob", base[p]), git("cat-file", "blob", other[p]), keep_noise)
        except Exception as e:  # keep going; report the file
            print(f"## {p}\n  <could not parse: {e}>\n")
            continue
        if "--summary" in flags:
            for key in {f.split(" = ", 1)[0] for _, f in changes}:
                summary[key] += 1
            continue
        print(f"## {p}")
        if not changes:
            print("  (only re-save noise)")
        for sign, fact in changes:
            print(f"  {sign} {fact}")
        print()

    if "--summary" in flags:
        print(f"{len(changed)} files changed; files touching each property:")
        for key, n in summary.most_common():
            print(f"{n:6}  {key}")
    for label, lst in (("added", added), ("deleted", deleted)):
        if lst:
            print(f"\n{len(lst)} files {label}:")
            for p in lst:
                print(f"  {p}")


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, OSError):  # output piped into head/less and closed early
        sys.exit(0)
