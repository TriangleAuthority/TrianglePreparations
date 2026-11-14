"""Convert UTF-16 / BOM-prefixed text files to plain UTF-8 (no BOM), in place.

Files without a BOM (ASCII or UTF-8 already) are left untouched. XML
declarations claiming encoding="UTF-16" are rewritten to UTF-8.

Usage:
    python tools/to_utf8.py <dir-or-file> [...]
"""
import codecs
import os
import re
import sys

TEXT_EXTS = {".ws", ".xml", ".csv", ".txt"}
XML_DECL = re.compile(r'^(<\?xml[^>]*encoding=["\'])utf-16(["\'])', re.IGNORECASE)


def convert(path):
    """Returns True if the file was rewritten."""
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
        text = data.decode("utf-16")
    elif data.startswith(codecs.BOM_UTF8):
        text = data[len(codecs.BOM_UTF8):].decode("utf-8")
    else:
        return False
    text = XML_DECL.sub(r"\1UTF-8\2", text)
    with open(path, "wb") as f:
        f.write(text.encode("utf-8"))
    return True


def convert_tree(root):
    count = 0
    if os.path.isfile(root):
        return int(convert(root))
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if os.path.splitext(fn)[1].lower() in TEXT_EXTS:
                count += convert(os.path.join(dirpath, fn))
    return count


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        print(f"{arg}: converted {convert_tree(arg)} files")
