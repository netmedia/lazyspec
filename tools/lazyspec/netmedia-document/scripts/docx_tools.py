"""Safe edits for Netmedia Word documents (python-docx). Part of the netmedia-document plugin; used by
netmedia_document.py and AIToolbelt's document builds.

Three things break a Word document silently when edited with python-docx:
- Run.text = ... replaces everything in the run, including a page break that shares the run (the cover page then
  merges with the table of contents). Edit the w:t elements instead: replace_text().
- Elements in word/settings.xml have a fixed order; an element appended at the end makes Word report an error.
  Use set_update_fields().
- A cloned paragraph carries the bookmarks and paragraph ids of its source; duplicates make Word report an error.
  Use clean_clone().
"""
import copy

from docx.oxml import OxmlElement
from docx.oxml.ns import qn

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W14_NS = "http://schemas.microsoft.com/office/word/2010/wordml"

# CT_Settings children that come after w:updateFields (ECMA-376, in schema order).
_AFTER_UPDATE_FIELDS = {
    "hdrShapeDefaults", "footnotePr", "endnotePr", "compat", "docVars", "rsids", "mathPr", "attachedSchema",
    "themeFontLang", "clrSchemeMapping", "doNotIncludeSubdocsInStats", "doNotAutoCompressPictures", "forceUpgrade",
    "captions", "readModeInkLockDown", "smartTagType", "schemaLibrary", "shapeDefaults", "doNotEmbedSmartTags",
    "decimalSymbol", "listSeparator",
}


def replace_text(paragraph, old, new):
    """Replaces text inside the paragraph's w:t elements only; breaks, tabs and fields stay."""
    for t in paragraph._p.iter(qn("w:t")):
        if t.text and old in t.text:
            t.text = t.text.replace(old, new)


def set_update_fields(document):
    """Asks Word to update fields (the table of contents) when the file is opened, at the schema position."""
    settings = document.settings.element
    existing = settings.find(qn("w:updateFields"))
    if existing is not None:
        settings.remove(existing)
    element = OxmlElement("w:updateFields")
    element.set(qn("w:val"), "true")
    for child in settings:
        namespace, _, local = child.tag[1:].partition("}")
        if namespace != W_NS or local in _AFTER_UPDATE_FIELDS:
            child.addprevious(element)
            return
    settings.append(element)


def clean_clone(element):
    """A copy of a paragraph or table without bookmarks and w14 paragraph ids, safe to insert again."""
    clone = copy.deepcopy(element)
    for tag in ("w:bookmarkStart", "w:bookmarkEnd"):
        for bookmark in list(clone.iter(qn(tag))):
            bookmark.getparent().remove(bookmark)
    for node in clone.iter():
        for attribute in ("paraId", "textId"):
            node.attrib.pop(f"{{{W14_NS}}}{attribute}", None)
    return clone


def remove_update_fields(document):
    """Removes the "update fields on open" setting, so Word opens the document without asking."""
    settings = document.settings.element
    existing = settings.find(qn("w:updateFields"))
    if existing is not None:
        settings.remove(existing)


def toc_field_paragraphs(style_source, entries, instruction=' TOC \\o "1-1" \\h \\z \\u '):
    """Paragraphs holding a TOC field whose current result lists the entries (headings) without page numbers, followed
    by a paragraph with the field end and a page break. Word replaces the result with page numbers when the field is
    updated (click the table, F9). style_source gives the paragraph properties of the entries."""
    properties = style_source._p.find(qn("w:pPr"))

    def paragraph():
        p = OxmlElement("w:p")
        if properties is not None:
            p.append(copy.deepcopy(properties))
        return p

    def run(*children):
        r = OxmlElement("w:r")
        for child in children:
            r.append(child)
        return r

    def fld(kind):
        e = OxmlElement("w:fldChar")
        e.set(qn("w:fldCharType"), kind)
        return e

    def text(value):
        t = OxmlElement("w:t")
        t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
        t.text = value
        return t

    instr = OxmlElement("w:instrText")
    instr.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
    instr.text = instruction
    paragraphs = []
    for index, entry in enumerate(entries or ["(no headings)"]):
        p = paragraph()
        if index == 0:
            for r in (run(fld("begin")), run(instr), run(fld("separate"))):
                p.append(r)
        p.append(run(text(entry)))
        paragraphs.append(p)

    closing = OxmlElement("w:p")
    page_break = OxmlElement("w:br")
    page_break.set(qn("w:type"), "page")
    closing.append(run(fld("end")))
    closing.append(run(page_break))
    paragraphs.append(closing)
    return paragraphs


def check(document):
    """Problems Word would report or show: returns a list of strings, empty when the document is clean."""
    problems = []
    body = document.element.body
    ids = [b.get(qn("w:id")) for b in body.iter(qn("w:bookmarkStart"))]
    names = [b.get(qn("w:name")) for b in body.iter(qn("w:bookmarkStart"))]
    if len(ids) != len(set(ids)) or len(names) != len(set(names)):
        problems.append("duplicate bookmarks")
    depth = 0
    for fld in body.iter(qn("w:fldChar")):
        kind = fld.get(qn("w:fldCharType"))
        depth += 1 if kind == "begin" else -1 if kind == "end" else 0
        if depth < 0:
            problems.append("field end without begin")
            break
    if depth > 0:
        problems.append("field begin without end")
    children = [c.tag[1:].partition("}") for c in document.settings.element]
    names_in_order = [local for ns, _, local in children]
    if "updateFields" in names_in_order:
        position = names_in_order.index("updateFields")
        if any(ns != W_NS or local in _AFTER_UPDATE_FIELDS for ns, _, local in children[:position]):
            problems.append("updateFields out of schema order")
    cover = document.paragraphs[:20]
    if not any('w:type="page"' in p._p.xml for p in cover):
        problems.append("no page break after the cover")
    return problems


def update_toc_with_word(paths):
    """Lets Word fill in the table of contents (dot leaders, page numbers) through update-docx-toc.ps1 next to this file.
    Returns False when Word is not available (not Windows, or the script fails); the TOC then lists the headings only
    and needs one F9 in Word."""
    import subprocess
    import sys as _sys
    from pathlib import Path as _Path
    if _sys.platform != "win32":
        return False
    script = _Path(__file__).resolve().parent / "update-docx-toc.ps1"
    result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                             *[str(p) for p in paths]], capture_output=True, text=True)
    print(result.stdout.strip())
    if result.returncode != 0:
        print(f"Word could not update the tables of contents ({result.stderr.strip()[:200]}); "
              "open each document, click the table of contents and press F9.")
        return False
    return True
