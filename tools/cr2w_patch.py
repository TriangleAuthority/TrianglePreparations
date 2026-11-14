"""Edit properties of a CR2W resource (.w2ent, .w2scene, .w2phase, ...): set values, remove properties,
add and remove array entries (struct entries too), adding names to the file's name table as needed.

Each edit names a chunk class and a property path (struct fields and array entries separated by dots: a
path that crosses an array of structs applies to every entry, e.g. W3CraftsmanComponent.craftsmanData.level):

    CLASS.PATH=OLD:NEW    set the property (integer, float, CName or enum value) that has OLD now to NEW
    CLASS.PATH-=VALUE     remove the property if it has VALUE; on an array, remove the entries equal to VALUE
    CLASS.PATH-=*         remove the property, whatever its value
    CLASS.PATH+=VALUE     append VALUE to the array
    CLASS.PATH:TYPE+=VALUE  add the property (of TYPE, e.g. Uint32) to chunks that do not have it

A PATH starting with @ names a parameter of the script call the chunk makes instead of a property: a scene's
script block (CStorySceneScript) stores its function's arguments as a second property list after its
properties (e.g. CStorySceneScript.@rewardName=mh308_final:mh307_02_minion_killed_completed, ECON-12).
Values: integers, floats, booleans, CNames, enums and Strings (one byte per character where Latin-1).

A struct entry is written FIELD=V,FIELD=V (e.g. containers+=name=loot_x,chance=-1.0): removing matches the
entries having those fields with those values; appending writes them in that order, each field with the
type an existing entry of the array gives it, or FIELD:TYPE=V. Values with a decimal point are floats.

CLASS#N edits only the class's Nth chunk (from 0, counted in each file: the file and each embedded file).
Every chunk of the class is edited, also in the CR2W files embedded in byte-array properties (an entity
template's compiled copy, flatCompiledData). Same-size number edits are written in place (`patch`); the
other edits rebuild the file: the property, struct and array sizes, the chunk sizes and offsets, the table
offsets and sizes are recomputed, a new name is appended to the string and name tables (name hash: FNV-1a
32 of the name and its terminating zero), and the chunk, table and header CRCs are recomputed (chunk: CRC32
of its data; table: CRC32 of the table; header: CRC32 of the 160-byte header and table headers with the CRC
field set to 0xDEADBEEF). Rebuilding reproduces an unchanged file byte for byte; files with buffers or
embedded-file tables are refused (none of the entity files edited so far has them).

    python tools/cr2w_patch.py FILE EDIT [...] [--check]
    python tools/cr2w_patch.py --roundtrip FILE [...]   rebuild each file unchanged and compare
    python tools/cr2w_patch.py --selftest               the String and @parameter edits on ECON-12's scenes

Prints each change; fails if an edit matches nothing. --check changes nothing and fails if an edit would
still change something (the file is not patched yet).
"""
import argparse, re, struct, sys, zlib, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cr2w_dump

FORMATS = {"Int32": "<i", "Uint32": "<I", "Int16": "<h", "Uint16": "<H", "Int8": "<b", "Uint8": "<B", "Float": "<f"}
SIZES = {"Int8": 1, "Uint8": 1, "Int16": 2, "Uint16": 2, "Int32": 4, "Uint32": 4, "Int64": 8, "Uint64": 8,
         "Float": 4, "Double": 8, "Bool": 1, "CName": 2, "CGUID": 16}


# ---- same-size number edits in place (ENCH-02, ALCH-15) --------------------------------------------

def find_props(f, d, pos, end):
    """Yields (name, type, value offset, value end) for the property list at d[pos:end]."""
    if d[pos] == 0:  # chunks and structs start with a zero byte before the property list
        pos += 1
    while pos + 2 <= end:
        ni = struct.unpack_from("<H", d, pos)[0]
        if ni == 0:
            return
        ti, size = struct.unpack_from("<HI", d, pos + 2)
        yield f.name(ni), f.name(ti), pos + 8, pos + 4 + size
        pos = pos + 4 + size


def edit_props(f, d, pos, end, path, old, new, label):
    """Applies one edit to the property list at d[pos:end] (path: the property, or the struct fields to it)."""
    out = []
    for pname, ptype, vs, ve in find_props(f, d, pos, end):
        if pname != path[0]:
            continue
        if len(path) > 1:
            out += edit_props(f, d, vs, ve, path[1:], old, new, label)
            continue
        if ptype not in FORMATS or ve - vs != struct.calcsize(FORMATS[ptype]):
            raise SystemExit("%s is %s, not an integer or float" % (label, ptype))
        fmt = FORMATS[ptype]
        v = struct.unpack_from(fmt, d, vs)[0]
        if (abs(v - old) > 1e-6) if ptype == "Float" else (v != old):
            continue
        struct.pack_into(fmt, d, vs, float(new) if ptype == "Float" else int(new))
        out.append("%s: %s -> %s" % (label, old, new))
    return out


def embedded_blobs(f, d, pos, end):
    """Yields (offset, size) of the CR2W files embedded in byte-array properties of a property list."""
    for pname, ptype, vs, ve in find_props(f, d, pos, end):
        if ptype.startswith("array:") and ptype.endswith(",Uint8") and bytes(d[vs + 4:vs + 8]) == b"CR2W":
            yield vs + 4, struct.unpack_from("<I", d, vs)[0]


def patch(data, edits, label=""):
    """Same-size number edits [(class, property path, old, new)]. Returns (new data, list of changes, set of
    the indexes of the edits that matched)."""
    d = bytearray(data)
    f = cr2w_dump.CR2W(bytes(d))
    coff = f.tables[4][0]
    changes = []
    hit = set()
    for i, ch in enumerate(f.chunks):
        start, end = ch["off"], ch["off"] + ch["size"]
        for eo, es in list(embedded_blobs(f, d, start, end)):
            sub, subchanges, subhit = patch(bytes(d[eo:eo + es]), edits, "%schunk %d embedded: " % (label, i))
            d[eo:eo + es] = sub
            changes += subchanges
            hit |= subhit
        for k, (cls, prop, old, new) in enumerate(edits):
            if ch["cls"] == cls:
                c = edit_props(f, d, start, end, prop.split("."), old, new, "%schunk %d %s.%s" % (label, i, cls, prop))
                if c:
                    hit.add(k)
                changes += c
        struct.pack_into("<I", d, coff + 24 * i + 20, zlib.crc32(bytes(d[start:end])))
    off, count, _ = f.tables[4]
    struct.pack_into("<I", d, 40 + 12 * 4 + 8, zlib.crc32(bytes(d[off:off + 24 * count])))
    struct.pack_into("<I", d, 32, 0xDEADBEEF)
    struct.pack_into("<I", d, 32, zlib.crc32(bytes(d[:160])))
    return bytes(d), changes, hit


def check_crcs(data):
    """True if the header, export table and chunk CRCs are consistent, also in embedded CR2W files."""
    f = cr2w_dump.CR2W(data)
    coff, count, tcrc = f.tables[4]
    ok = all(struct.unpack_from("<I", data, coff + 24 * i + 20)[0] == zlib.crc32(data[c["off"]:c["off"] + c["size"]])
             for i, c in enumerate(f.chunks))
    ok = ok and tcrc == zlib.crc32(data[coff:coff + 24 * count])
    h = bytearray(data[:160])
    struct.pack_into("<I", h, 32, 0xDEADBEEF)
    ok = ok and struct.unpack_from("<I", data, 32)[0] == zlib.crc32(bytes(h))
    for c in f.chunks:
        for eo, es in embedded_blobs(f, data, c["off"], c["off"] + c["size"]):
            ok = ok and check_crcs(bytes(data[eo:eo + es]))
    return ok


# ---- structural edits: a file rebuilt from its parts ----------------------------------------------

def name_hash(s):
    """The name table's hash: FNV-1a 32 of the name and its terminating zero (0 for the empty name)."""
    if not s:
        return 0
    h = 0x811C9DC5
    for b in s.encode("latin-1") + b"\0":
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return h


TABLE_ENTRY = {1: 8, 2: 8, 3: 16, 4: 24}


class File:
    """A CR2W file as its parts: the string, name, import and property tables, and the chunks' data.
    `build()` lays them out again (header, table headers, tables 0-4, chunk data) with new sizes, offsets
    and CRCs."""

    def __init__(self, data, readonly=False):
        self.data = data
        self.f = f = cr2w_dump.CR2W(data)
        self.readonly = readonly
        if readonly:
            self.names = list(f.names)
            self.chunks = [data[c["off"]:c["off"] + c["size"]] for c in f.chunks]
            self.classes = [c["cls"] for c in f.chunks]
            return
        if any(f.tables[i][1] for i in range(5, 10)):
            raise ValueError("file has buffers or embedded files: rebuilding not supported")
        pos = 160
        for i in range(5):
            off, count, _ = f.tables[i]
            if count == 0 and off == 0:
                continue
            if off != pos:
                raise ValueError("unexpected layout: table %d at %d, expected %d" % (i, off, pos))
            pos += count if i == 0 else TABLE_ENTRY[i] * count
        for c in f.chunks:
            if c["off"] != pos:
                raise ValueError("unexpected layout: chunk data not contiguous")
            pos += c["size"]
        if pos != len(data) or f.file_size != len(data) or f.buffer_size != len(data):
            raise ValueError("unexpected layout: data after the chunks or sizes differ")
        soff, ssize, _ = f.tables[0]
        self.strings = bytearray(data[soff:soff + ssize])
        noff, ncount, _ = f.tables[1]
        self.name_entries = [data[noff + 8 * i:noff + 8 * i + 8] for i in range(ncount)]
        self.names = list(f.names)
        self.index = {}
        for i, n in enumerate(self.names):
            self.index.setdefault(n, i)
        self.raw_tables = {i: data[f.tables[i][0]:f.tables[i][0] + TABLE_ENTRY[i] * f.tables[i][1]] for i in (2, 3)}
        coff = f.tables[4][0]
        self.chunk_entries = [bytearray(data[coff + 24 * i:coff + 24 * i + 24]) for i in range(len(f.chunks))]
        self.chunks = [data[c["off"]:c["off"] + c["size"]] for c in f.chunks]
        self.classes = [c["cls"] for c in f.chunks]
        self.added_names = []

    def name(self, i):
        return self.names[i]

    def name_index(self, s):
        """The index of name `s`, appended to the string and name tables if the file has none."""
        if self.readonly:
            raise ValueError("file opened read-only")
        if s not in self.index:
            off = len(self.strings)
            self.strings += s.encode("latin-1") + b"\0"
            self.name_entries.append(struct.pack("<II", off, name_hash(s)))
            self.names.append(s)
            self.index[s] = len(self.names) - 1
            self.added_names.append(s)
        return self.index[s]

    def build(self):
        tables = [bytes(self.strings), b"".join(self.name_entries), self.raw_tables[2], self.raw_tables[3]]
        counts = [len(tables[0]), len(self.name_entries), self.f.tables[2][1], self.f.tables[3][1], len(self.chunks)]
        offs, pos = [], 160
        for t in tables:
            offs.append(pos)
            pos += len(t)
        offs.append(pos)
        pos += 24 * len(self.chunks)
        entries = []
        for e, c in zip(self.chunk_entries, self.chunks):
            e = bytearray(e)
            struct.pack_into("<III", e, 8, len(c), pos, 0)
            struct.pack_into("<I", e, 20, zlib.crc32(c))
            entries.append(bytes(e))
            pos += len(c)
        tables.append(b"".join(entries))
        head = bytearray(self.data[:160])
        struct.pack_into("<II", head, 24, pos, pos)  # file size, buffer size
        for i in range(5):
            o = offs[i] if counts[i] or self.f.tables[i][0] else 0
            struct.pack_into("<III", head, 40 + 12 * i, o, counts[i], zlib.crc32(tables[i]))
        struct.pack_into("<I", head, 32, 0xDEADBEEF)
        struct.pack_into("<I", head, 32, zlib.crc32(bytes(head)))
        return bytes(head) + b"".join(tables) + b"".join(self.chunks)


# A property list as [lead, [[name index, type index, value bytes], ...], terminator, tail]

def parse_list(d, pos, end, chunk=False):
    lead = b""
    if pos < end and d[pos] == 0:
        lead, pos = d[pos:pos + 1], pos + 1
    props = []
    while pos + 2 <= end:
        ni = struct.unpack_from("<H", d, pos)[0]
        if ni == 0:
            return [lead, props, d[pos:pos + 2], d[pos + 2:end]], pos + 2
        ti, size = struct.unpack_from("<HI", d, pos + 2)
        if size < 4 or pos + 4 + size > end:
            raise ValueError("bad property size")
        props.append([ni, ti, d[pos + 8:pos + 4 + size]])
        pos += 4 + size
    if not chunk:
        raise ValueError("unterminated property list")
    return [lead, props, b"", d[pos:end]], end


def build_list(pl):
    lead, props, term, tail = pl
    return lead + b"".join(struct.pack("<HHI", ni, ti, len(v) + 4) + v for ni, ti, v in props) + term + tail


def element_size(t):
    if t in SIZES:
        return SIZES[t]
    if t.startswith(("handle:", "ptr:")):
        return 4
    if t.startswith("soft:"):
        return 2
    if t.startswith("E"):
        return 2  # enums are stored as a CName of the value
    return None


def parse_array(v, inner):
    """[count-free list of element bytes], is struct."""
    n = struct.unpack_from("<I", v, 0)[0]
    size = element_size(inner)
    out, pos = [], 4
    for _ in range(n):
        if size is not None:
            out.append(v[pos:pos + size])
            pos += size
        else:
            _, p = parse_list(v, pos, len(v))
            out.append(v[pos:p])
            pos = p
    if pos != len(v):
        raise ValueError("array of %s: %d bytes left" % (inner, len(v) - pos))
    return out, size is None


def build_array(elems):
    return struct.pack("<I", len(elems)) + b"".join(elems)


def inner_type(t):
    return t.split(",", 2)[2] if t.startswith("array:") else None


def decode(fo, t, v):
    """A scalar value as Python: int, float, bool or name string; None if not a scalar."""
    if t in FORMATS and len(v) == struct.calcsize(FORMATS[t]):
        return struct.unpack(FORMATS[t], v)[0]
    if t == "Bool" and len(v) == 1:
        return bool(v[0])
    if (t == "CName" or t.startswith("E")) and len(v) == 2:
        return fo.name(struct.unpack("<H", v)[0])
    if t == "String":
        try:
            s, n = decode_string(v)
        except (IndexError, UnicodeDecodeError):
            return None
        return s if n == len(v) else None
    return None


def decode_string(v, pos=0):
    """A CR2W String at v[pos:]: (text, end). First byte: 0x80 one byte per character (else UTF-16), 0x40 a
    longer length follows, the low 6 bits the length's start; then 7 bits per byte while 0x80 is set."""
    b = v[pos]
    n, shift, p = b & 0x3F, 6, pos + 1
    if b & 0x40:
        while True:
            c = v[p]
            p += 1
            n |= (c & 0x7F) << shift
            shift += 7
            if not c & 0x80:
                break
    if b & 0x80:
        return v[p:p + n].decode("latin-1"), p + n
    return v[p:p + 2 * n].decode("utf-16le"), p + 2 * n


def encode_string(s):
    """A CR2W String: one byte per character where the text is Latin-1, else UTF-16 (decode_string's layout)."""
    try:
        data, flag, n = s.encode("latin-1"), 0x80, len(s)
    except UnicodeEncodeError:
        data, flag = s.encode("utf-16le"), 0
        n = len(data) // 2
    out = bytearray([flag | (n & 0x3F) | (0x40 if n > 0x3F else 0)])
    n >>= 6
    while n:
        out.append((n & 0x7F) | (0x80 if n > 0x7F else 0))
        n >>= 7
    return bytes(out) + data


def encode(fo, t, s):
    if t in FORMATS:
        return struct.pack(FORMATS[t], float(s) if t in ("Float",) else int(s))
    if t == "Bool":
        return b"\1" if s.lower() in ("1", "true") else b"\0"
    if t == "CName" or t.startswith("E"):
        return struct.pack("<H", fo.name_index(s))
    if t == "String":
        return encode_string(s)
    raise ValueError("cannot write a %s" % t)


def equal(fo, t, v, s):
    x = decode(fo, t, v)
    if x is None:
        return False
    if isinstance(x, float):
        return abs(x - float(s)) <= 1e-6
    if isinstance(x, bool):
        return x == (s.lower() in ("1", "true"))
    if isinstance(x, int):
        try:
            return x == int(s)
        except ValueError:
            return False
    return x == s


def struct_fields(fo, elem):
    pl, _ = parse_list(elem, 0, len(elem))
    return {fo.name(ni): (fo.name(ti), v) for ni, ti, v in pl[1]}


def struct_matches(fo, elem, spec):
    fields = struct_fields(fo, elem)
    return all(k in fields and equal(fo, fields[k][0], fields[k][1], s) for k, (_, s) in spec.items())


def parse_spec(s):
    """'name=x,chance=-1.0' -> {field: (type or None, value)}; a plain value -> None."""
    if "=" not in s:
        return None
    out = {}
    for part in s.split(","):
        k, v = part.split("=", 1)
        k, _, t = k.partition(":")
        out[k] = (t or None, v)
    return out


class Op:
    """One edit, parsed from CLASS.PATH=OLD:NEW, CLASS.PATH-=VALUE, CLASS.PATH+=VALUE or
    CLASS.PATH:TYPE+=VALUE. A PATH component that crosses an array of structs may select entries:
    containers[name=_store__x].chance=-1.0:0.0."""

    def __init__(self, text):
        self.text = text
        depth, opat = 0, None
        for i, ch in enumerate(text):
            depth += ch == "["
            depth -= ch == "]"
            if depth == 0 and ch == "=":
                opat = i - 1 if i and text[i - 1] in "+-" else i
                break
        if opat is None:
            raise ValueError("bad edit: %s" % text)
        target, kind, value = text[:opat], text[opat:text.index("=", opat) + 1], text[text.index("=", opat) + 1:]
        m = re.match(r"^(\w+)(?:#(\d+))?\.(.+?)(?::(\w+))?$", target)
        if not m:
            raise ValueError("bad edit: %s" % text)
        self.cls, nth, path, self.type = m.groups()
        self.nth = int(nth) if nth is not None else None
        self.path = []
        for comp in re.findall(r"(@?\w+)(?:\[([^\]]*)\])?\.?", path):
            self.path.append((comp[0], parse_spec(comp[1]) if comp[1] else None))
        if "".join(c[0] for c in self.path) != re.sub(r"\[[^\]]*\]|\.", "", path):
            raise ValueError("bad path: %s" % text)
        if kind == "=":
            if ":" not in value:
                raise ValueError("bad edit (OLD:NEW): %s" % text)
            self.kind = "set"
            self.old, self.new = value.split(":", 1)
        else:
            self.kind = "add" if kind == "+=" else "del"
            self.value = value
            self.spec = parse_spec(value)

    def __repr__(self):
        return self.text


def edit_list(fo, pl, path, op, label, out):
    """Applies `op` (its remaining `path`) to the parsed property list `pl`; returns True if it changed."""
    changed = False
    props = pl[1]
    found = False
    if path[0][0].startswith("@"):
        # a parameter of the script call a chunk makes (CStorySceneScript): the second property list, after
        # the chunk's properties (`pl`'s tail)
        tail = pl[3]
        try:
            tpl, end = parse_list(tail, 0, len(tail))
        except ValueError:
            return False
        if end != len(tail):
            return False
        if edit_list(fo, tpl, [(path[0][0][1:], path[0][1])] + path[1:], op, label + " params", out):
            pl[3] = build_list(tpl)
            return True
        return False
    for entry in list(props):
        ni, ti, v = entry
        pname, select = path[0]
        if fo.name(ni) != pname:
            continue
        found = True
        t = fo.name(ti)
        it = inner_type(t)
        if len(path) > 1:
            if it is not None:
                elems, is_struct = parse_array(v, it)
                if not is_struct:
                    continue
                new_elems = []
                for j, e in enumerate(elems):
                    if select and not struct_matches(fo, e, select):
                        new_elems.append(e)
                        continue
                    epl, _ = parse_list(e, 0, len(e))
                    if edit_list(fo, epl, path[1:], op, "%s.%s[%d]" % (label, pname, j), out):
                        e = build_list(epl)
                        changed = True
                    new_elems.append(e)
                entry[2] = build_array(new_elems)
            else:
                try:
                    spl, _ = parse_list(v, 0, len(v))
                except ValueError:
                    continue
                if edit_list(fo, spl, path[1:], op, "%s.%s" % (label, pname), out):
                    entry[2] = build_list(spl)
                    changed = True
            continue
        where = "%s.%s" % (label, pname)
        if op.kind == "set":
            if equal(fo, t, v, op.old):
                entry[2] = encode(fo, t, op.new)
                out.append("%s: %s -> %s" % (where, op.old, op.new))
                changed = True
        elif op.kind == "del" and (it is None or op.value == "*"):
            if op.value == "*" or equal(fo, t, v, op.value):
                props[:] = [p for p in props if p is not entry]
                out.append("%s: %s removed" % (where, op.value))
                changed = True
        elif op.kind == "del":
            elems, is_struct = parse_array(v, it)
            keep = [e for e in elems if not (struct_matches(fo, e, op.spec) if is_struct and op.spec
                                             else (not is_struct and equal(fo, it, e, op.value)))]
            if len(keep) != len(elems):
                entry[2] = build_array(keep)
                out.append("%s: %d entr%s %s removed" % (where, len(elems) - len(keep),
                                                         "y" if len(elems) - len(keep) == 1 else "ies", op.value))
                changed = True
        elif op.kind == "add" and it is not None and not op.type:
            elems, is_struct = parse_array(v, it)
            if is_struct:
                if op.spec is None:
                    raise SystemExit("%s: entries are structs, write FIELD=V,..." % where)
                known = {}
                for e in elems:
                    for fname, (ft, _) in struct_fields(fo, e).items():
                        known.setdefault(fname, ft)
                lead = elems[0][:1] if elems and elems[0][:1] == b"\0" else b"\0"
                fields = []
                for fname, (ft, s) in op.spec.items():
                    ft = ft or known.get(fname)
                    if ft is None:
                        raise SystemExit("%s: no entry gives the type of %s; write %s:TYPE=..." % (where, fname, fname))
                    fields.append([fo.name_index(fname), fo.name_index(ft), encode(fo, ft, s)])
                elems.append(build_list([lead, fields, b"\0\0", b""]))
            else:
                elems.append(encode(fo, it, op.value))
            entry[2] = build_array(elems)
            out.append("%s: %s added" % (where, op.value))
            changed = True
    if op.kind == "add" and op.type and len(path) == 1 and not found:
        props.append([fo.name_index(path[0][0]), fo.name_index(op.type), encode(fo, op.type, op.value)])
        out.append("%s.%s: %s %s added" % (label, path[0][0], op.type, op.value))
        changed = True
    return changed


def apply(data, ops, label=""):
    """Structural edits (a list of Op). Returns (new data, list of changes, set of the indexes of the ops
    that matched). Unchanged chunks keep their bytes; an unchanged file comes back byte for byte."""
    fo = File(data)
    changes, hit = [], set()
    nth = {}
    for i, cls in enumerate(fo.classes):
        n = nth[cls] = nth.get(cls, -1) + 1
        d = fo.chunks[i]
        pl, _ = parse_list(d, 0, len(d), chunk=True)
        changed = False
        for k, (ni, ti, v) in enumerate(pl[1]):
            t = fo.name(ti)
            if t.startswith("array:") and t.endswith(",Uint8") and v[4:8] == b"CR2W":
                sub, subchanges, subhit = apply(v[4:], ops, "%schunk %d %s embedded: " % (label, i, fo.name(ni)))
                if sub != v[4:]:
                    pl[1][k][2] = struct.pack("<I", len(sub)) + sub
                    changed = True
                changes += subchanges
                hit |= subhit
        for k, op in enumerate(ops):
            if op.cls == cls and op.nth in (None, n) and edit_list(fo, pl, op.path, op, "%schunk %d %s" % (label, i, cls), changes):
                hit.add(k)
                changed = True
        if changed:
            fo.chunks[i] = build_list(pl)
    for n in fo.added_names:
        changes.append("%sname added: %s" % (label, n))
    return fo.build(), changes, hit


def roundtrip(data):
    """Rebuilds a file (and its embedded files) unchanged; returns True if the bytes are identical."""
    out, _, _ = apply(data, [])
    return out == data


# --selftest works only in the TriangleGhostMode repository (its files below); kept for reference.
# ECON-12 (econ.md): the Apiarian Phantom's two scenes name the White Lady's reward; legacy's fix
SELFTEST_FILES = ["modGhostMode/files/quests/generic_quests/novigrad/quest_files/mh307_minion/scenes/mh307_01_halflings.w2scene",
                  "modGhostMode/files/quests/generic_quests/novigrad/quest_files/mh307_minion/scenes/mh307_05_halflings_closing.w2scene"]
SELFTEST_EDITS = ["CStorySceneScript.comment=mh308_final:mh307_02_minion_killed_completed",
                  "CStorySceneScript.@rewardName=mh308_final:mh307_02_minion_killed_completed"]


def selftest():
    """The String encoding round trip; then ECON-12's edits on vanilla-5.x's two mh307 scenes: the edited
    script blocks must come out byte for byte as legacy's (legacy-GM, the same edit made in W3Edit), every
    other chunk 5.x's, CRCs valid, and the file must decode; a second run must change nothing."""
    import subprocess
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = 0
    for n in (0, 1, 11, 32, 63, 64, 200, 9000):
        for s in ("a" * n, "Ł" * n):
            enc = encode_string(s)
            got, end = decode_string(enc)
            if got != s or end != len(enc):
                print("FAIL string round trip, length %d" % n)
                bad += 1
    for path in SELFTEST_FILES:
        show = lambda ref: subprocess.run(["git", "-C", repo, "show", "%s:%s" % (ref, path)], capture_output=True, check=True).stdout
        v5, leg = show("vanilla-5.x"), show("legacy-GM")
        ops = [Op(e) for e in SELFTEST_EDITS]
        out, changes, hit = apply(v5, ops)
        a, b, lg = File(v5, readonly=True), File(out, readonly=True), File(leg, readonly=True)
        scripts = [i for i, c in enumerate(b.classes) if c == "CStorySceneScript" and b.chunks[i] != a.chunks[i]]
        same_legacy = all(b.chunks[i] == lg.chunks[i] for i in scripts)
        others = all(b.chunks[i] == a.chunks[i] for i in range(len(b.chunks)) if i not in scripts)
        again, more, _ = apply(out, ops)
        ok = len(hit) == len(ops) and scripts and same_legacy and others and check_crcs(out) and again == out and not more
        cr2w_dump.dump_file(out)
        print("%s %s: %d script blocks edited (%s), as legacy's: %s, other chunks 5.x's: %s, names added %s" % (
            "ok  " if ok else "FAIL", os.path.basename(path), len(scripts), ", ".join(map(str, scripts)),
            same_legacy, others, [c for c in changes if "name added" in c]))
        bad += not ok
    print("selftest:", "FAILED" if bad else "passed")
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", nargs="?")
    ap.add_argument("edits", nargs="*", help="CLASS.PATH=OLD:NEW, CLASS.PATH-=VALUE, CLASS.PATH+=VALUE")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--roundtrip", nargs="+", metavar="FILE")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(1 if selftest() else 0)
    if a.roundtrip:
        bad = 0
        for p in a.roundtrip:
            ok = roundtrip(open(p, "rb").read())
            print("%s %s" % ("same" if ok else "DIFFERENT", p))
            bad += not ok
        sys.exit(1 if bad else 0)
    if not a.file or not a.edits:
        ap.error("FILE and at least one edit are needed")
    ops = [Op(e) for e in a.edits]
    data = open(a.file, "rb").read()
    if not check_crcs(data):
        raise SystemExit("%s: CRCs inconsistent before patching; not touching it" % a.file)
    numeric = all(o.kind == "set" and o.nth is None and all(spec is None for _, spec in o.path)
                  and re.fullmatch(r"-?[\d.]+", o.old) and re.fullmatch(r"-?[\d.]+", o.new) for o in ops)
    if numeric:
        num = lambda o, s: float(s) if ("." in o.old or "." in o.new) else int(s)
        out, changes, hit = patch(data, [(o.cls, ".".join(c for c, _ in o.path), num(o, o.old), num(o, o.new)) for o in ops])
    else:
        out, changes, hit = apply(data, ops)
    missing = ["NO MATCH %s" % o for k, o in enumerate(ops) if k not in hit]
    if a.check:
        print("\n".join(changes) or "already patched")
        sys.exit(1 if changes else 0)
    if missing:
        print("\n".join(changes + missing))
        raise SystemExit("an edit matched nothing; file not written")
    if not check_crcs(out):
        raise SystemExit("CRC recomputation failed; file not written")
    cr2w_dump.dump_file(out)  # must decode
    open(a.file, "wb").write(out)
    print("\n".join(changes))


if __name__ == "__main__":
    main()
