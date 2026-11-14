r"""Minimal CR2W (Witcher 3 binary resource) reader and text dumper.

CR2W is the format of .w2ent, .journal, .w2scene, .w2phase, .w2beh,
.w2behtree, .w2comm and most other binary game resources. This dumps every
object (chunk) with its serialized properties as indented text, recursing into
structs, arrays and nested CR2W blobs (flatCompiledData, embedded files).
Values it cannot decode are shown as hex; long ones are shortened but carry a
hash, so any change still shows up when two dumps are compared. A scene script
block's call parameters (CStorySceneScript: a second property list after the
properties) are shown as `params (after properties):`.

Reads legacy (CR2W 162/163) and 5.0 (164) files. It is a reader only; it
cannot write files. It is also git's text converter for these files (see the
"cr2w" diff driver in .gitattributes and docs/tools.md), so `git diff` and
`git log -p` show binary resources as text.

Usage:
    python tools/cr2w_dump.py <file>
    python tools/cr2w_dump.py --rev <git-ref> <repo path>
        e.g. --rev vanilla-5.x modPreparations/files/<path>.w2ent
"""
import hashlib
import re
import struct
import subprocess
import sys

# Classes whose chunk holds a second property list after its properties: the parameters of the script
# function it calls (a scene's script block: CStorySceneScript.functionName and its arguments).
PARAM_CLASSES = {"CStorySceneScript"}

PRIM = {"Int8": "<b", "Uint8": "<B", "Int16": "<h", "Uint16": "<H", "Int32": "<i", "Uint32": "<I",
        "Int64": "<q", "Uint64": "<Q", "Float": "<f", "Double": "<d", "Bool": "<?"}


def hexpreview(b, n):
    """First n bytes as hex; when cut short, add a hash so any change stays visible in diffs."""
    b = bytes(b)
    if len(b) <= n:
        return b.hex()
    return f"{b[:n].hex()}... sha1:{hashlib.sha1(b).hexdigest()[:12]}"


class ParseError(Exception):
    pass


class CR2W:
    def __init__(self, data, label=""):
        self.d = data
        self.label = label
        magic, self.version, self.flags, _ts, _build, self.file_size, self.buffer_size, _crc, _n = \
            struct.unpack_from("<4sIIQIIIII", data, 0)
        if magic != b"CR2W":
            raise ValueError("not CR2W")
        self.tables = [struct.unpack_from("<III", data, 40 + 12 * i) for i in range(10)]
        soff, ssize, _ = self.tables[0]
        self.strings = data[soff:soff + ssize]
        noff, ncount, _ = self.tables[1]
        self.names = [self.string(struct.unpack_from("<I", data, noff + 8 * i)[0]) for i in range(ncount)]
        ioff, icount, _ = self.tables[2]
        self.imports = []
        for i in range(icount):
            p, cls, fl = struct.unpack_from("<IHH", data, ioff + 8 * i)
            self.imports.append((self.string(p), self.names[cls]))
        coff, ccount, _ = self.tables[4]
        self.chunks = []
        for i in range(ccount):
            cls, oflags, parent, size, off, tmpl, crc = struct.unpack_from("<HHIIIII", data, coff + 24 * i)
            self.chunks.append(dict(cls=self.names[cls], parent=parent, size=size, off=off))
        eoff, ecount, _ = self.tables[6]
        self.embedded = []
        for i in range(ecount):
            imp, path, phash, doff, dsize = struct.unpack_from("<IIQII", data, eoff + 24 * i)
            self.embedded.append(dict(imp=imp, path=self.string(path), off=doff, size=dsize))

    def string(self, off):
        end = self.strings.index(b"\0", off)
        return self.strings[off:end].decode("latin-1")

    def name(self, i):
        if i >= len(self.names):
            raise ParseError(f"name index {i}")
        return self.names[i]

    # ---- value decoding -------------------------------------------------
    def props(self, d, pos, end, out, indent):
        """Read a property list at d[pos:end]; returns position after terminator."""
        while pos + 2 <= end:
            ni = struct.unpack_from("<H", d, pos)[0]
            if ni == 0:
                return pos + 2
            ti, size = struct.unpack_from("<HI", d, pos + 2)
            pname, ptype = self.name(ni), self.name(ti)
            vstart, vend = pos + 8, pos + 4 + size
            if size < 4 or vend > end:
                raise ParseError(f"bad size for {pname}")
            self.value(ptype, pname, d, vstart, vend, out, indent)
            pos = vend
        raise ParseError("unterminated property list")

    def value(self, ptype, pname, d, start, end, out, indent):
        pad = "  " * indent
        try:
            lines = []
            used = self.decode(ptype, d, start, end, lines, indent + 1)
            if used != end:
                raise ParseError(f"used {used - start} of {end - start}")
            if len(lines) == 1 and not lines[0].startswith("  " * (indent + 1) + "["):
                out.append(f"{pad}{pname} ({ptype}) = {lines[0].strip()}")
            else:
                out.append(f"{pad}{pname} ({ptype}):")
                out.extend(lines)
        except (ParseError, struct.error, UnicodeDecodeError, ValueError, IndexError) as e:
            out.append(f"{pad}{pname} ({ptype}) = <raw {end - start} bytes: {hexpreview(d[start:end], 48)}>")

    def decode(self, t, d, pos, end, out, indent):
        pad = "  " * indent
        if t in PRIM:
            fmt = PRIM[t]
            v = struct.unpack_from(fmt, d, pos)[0]
            out.append(pad + (f"{v:.6g}" if isinstance(v, float) else str(v)))
            return pos + struct.calcsize(fmt)
        if t == "CName":
            out.append(pad + self.name(struct.unpack_from("<H", d, pos)[0]))
            return pos + 2
        if t in ("String", "StringAnsi"):
            return self.decode_string(d, pos, out, pad)
        if t == "LocalizedString":
            out.append(pad + f"loc#{struct.unpack_from('<I', d, pos)[0]}")
            return pos + 4
        if t == "TagList":
            n = d[pos]
            names = [self.name(struct.unpack_from("<H", d, pos + 1 + 2 * i)[0]) for i in range(n)]
            out.append(pad + "[" + ", ".join(names) + "]")
            return pos + 1 + 2 * n
        if t == "CGUID":
            out.append(pad + d[pos:pos + 16].hex())
            return pos + 16
        if t.startswith("handle:") or t.startswith("ptr:"):
            v = struct.unpack_from("<i", d, pos)[0]
            out.append(pad + (f"-> chunk {v}" if v > 0 else ("null" if v == 0 else f"-> import {-v}")))
            return pos + 4
        if t.startswith("soft:"):
            v = struct.unpack_from("<H", d, pos)[0]
            out.append(pad + (self.imports[v - 1][0] if 0 < v <= len(self.imports) else f"import#{v}"))
            return pos + 2
        if t.startswith("array:"):
            inner = t.split(",", 2)[2]
            n = struct.unpack_from("<I", d, pos)[0]
            pos += 4
            if inner == "Uint8":
                blob = d[pos:pos + n]
                if blob[:4] == b"CR2W":
                    out.append(pad + f"<embedded CR2W, {n} bytes>")
                    dump(CR2W(blob), out, indent + 1)
                else:
                    out.append(pad + f"<{n} bytes: {hexpreview(blob, 32)}>")
                return pos + n
            for i in range(n):
                sub = []
                pos = self.decode(inner, d, pos, end, sub, indent + 1)
                if len(sub) == 1:
                    out.append(pad + f"[{i}] " + sub[0].strip())
                else:
                    out.append(pad + f"[{i}]")
                    out.extend(sub)
            return pos
        if t.startswith("static:"):
            _, rest = t.split(":", 1)
            count, inner = rest.split(",", 1)
            n = struct.unpack_from("<I", d, pos)[0]
            pos += 4
            for i in range(n):
                sub = []
                pos = self.decode(inner, d, pos, end, sub, indent + 1)
                out.append(pad + f"[{i}] " + " ".join(s.strip() for s in sub))
            return pos
        if t in ("DeferredDataBuffer", "SharedDataBuffer"):
            out.append(pad + f"buffer#{struct.unpack_from('<H', d, pos)[0]}")
            return pos + 2
        if t.startswith("E") and end - pos == 2:
            # enums are stored as a CName of the value
            out.append(pad + self.name(struct.unpack_from("<H", d, pos)[0]))
            return pos + 2
        # structs: nested property list, usually preceded by a zero byte
        if d[pos] == 0:
            try:
                sub = []
                p = self.props(d, pos + 1, end, sub, indent)
                out.extend(sub)
                return p
            except (ParseError, struct.error, IndexError):
                pass
        return self.props(d, pos, end, out, indent)

    def decode_string(self, d, pos, out, pad):
        b = d[pos]
        n = b & 0x3F
        shift = 6
        p = pos + 1
        if b & 0x40:
            while True:
                c = d[p]
                p += 1
                n |= (c & 0x7F) << shift
                shift += 7
                if not c & 0x80:
                    break
        if b & 0x80:  # ansi
            s = d[p:p + n].decode("latin-1")
            p += n
        else:
            s = d[p:p + 2 * n].decode("utf-16le")
            p += 2 * n
        out.append(pad + repr(s))
        return p


def dump(f, out, indent=0):
    pad = "  " * indent
    for i, c in enumerate(f.chunks, 1):
        out.append(f"{pad}#{i} {c['cls']} (parent {c['parent']})")
        d, start, end = f.d, c["off"], c["off"] + c["size"]
        pos = start + 1 if d[start] == 0 else start  # leading zero byte before the property list
        try:
            pos = f.props(d, pos, end, out, indent + 1)
            if pos < end:
                extra = d[pos:end]
                params = []
                if c["cls"] in PARAM_CLASSES:
                    try:
                        if f.props(d, pos, end, params, indent + 2) != end:
                            params = []
                    except (ParseError, struct.error, IndexError):
                        params = []
                if params:
                    # a scene script call's parameters: a second property list after the properties
                    out.append(f"{pad}  params (after properties):")
                    out.extend(params)
                else:
                    out.append(f"{pad}  <+{len(extra)} bytes after properties: {hexpreview(extra, 32)}>")
        except (ParseError, struct.error) as e:
            out.append(f"{pad}  <unparsed ({e}): {hexpreview(d[start:end], 48)}>")
    def label(e):
        return f.imports[e["imp"] - 1][0] if 0 < e["imp"] <= len(f.imports) else f"import#{e['imp']}"
    for e in sorted(f.embedded, key=lambda e: (label(e), e["size"])):
        blob = f.d[e["off"]:e["off"] + e["size"]]
        out.append(f"{pad}embedded {label(e)} ({e['size']} bytes)")
        if blob[:4] == b"CR2W":
            try:
                dump(CR2W(blob), out, indent + 1)
            except Exception as ex:
                out.append(f"{pad}  <embedded parse failed: {ex}>")


def dump_file(path_or_bytes):
    data = path_or_bytes if isinstance(path_or_bytes, bytes) else open(path_or_bytes, "rb").read()
    f = CR2W(data)
    out = [f"CR2W version {f.version}", "imports:"] + [f"  {p} ({c})" for p, c in f.imports]
    dump(f, out)
    return out


def flatten(lines):
    """Turn a dump into 'object/path.property = value' facts.

    Array indices and chunk numbers are dropped, so two versions of a file can
    be compared as multisets of facts even when objects were reordered.
    """
    facts = []
    stack = []  # (indent level, label)
    for line in lines:
        ind, body = re.match(r"^(\s*)(.*)$", line).groups()
        lvl = len(ind) // 2
        while stack and stack[-1][0] >= lvl:
            stack.pop()
        m = re.match(r"#\d+ (\S+) \(parent \d+\)", body)
        if m:
            stack.append((lvl, m.group(1)))
            continue
        m = re.match(r"embedded (.*) \(\d+ bytes\)", body)
        if m:
            stack.append((lvl, "embedded:" + m.group(1)))
            continue
        m = re.match(r"(\[\d+\] )?(\w+) \(([^)]*)\)( = (.*)|:)$", body)
        if m:
            name, val = m.group(2), m.group(5)
            if val is None:
                stack.append((lvl, name))
                continue
        else:
            m2 = re.match(r"\[\d+\]\s*(.*)$", body)
            if m2 is not None and m2.group(1) == "":
                continue
            name, val = "", (m2.group(1) if m2 else body)
        val = re.sub(r"-> chunk \d+", "-> chunk", val)
        path = "/".join(label for _, label in stack) + ("." + name if name else "")
        facts.append(f"{path} = {val}")
    return facts


def read_rev(rev, path, repo=None):
    cmd = ["git"] + (["-C", repo] if repo else []) + ["show", f"{rev}:{path}"]
    return subprocess.check_output(cmd)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--rev":
        data = read_rev(args[1], args[2])
    elif len(args) == 1:
        data = args[0]
    else:
        sys.exit(__doc__)
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    try:
        print("\n".join(dump_file(data)))
    except (BrokenPipeError, OSError):  # output piped into head/less and closed early
        sys.exit(0)
